extends Node2D
class_name Army

signal movement_points_changed(army: Army, new_points: int)

# ============================================================================
# ARMY
# ============================================================================
# 
# Purpose: Individual army entity with movement and composition management
# 
# Core Responsibilities:
# - Army properties storage (player ID, movement points, composition)
# - Movement point tracking for turn-based systems
# - Army composition integration and soldier management
# - Visual representation as animated map icon
# - Player ownership and identification
# 
# Required Functions:
# - setup_army(): Initialize army with player and composition
# - move_to_region(): Movement with cost validation
# - get/set_movement_points(): Turn-based movement management
# - get_composition(): Access to army unit composition
# - is_army_destroyed(): Check for army elimination
# 
# Integration Points:
# - ArmyManager: Army lifecycle and movement coordination
# - ArmyComposition: Unit composition and combat calculations
# - GameParameters: Movement points and army defaults
# - Region containers: Positioning and visual display
# ============================================================================

# Army properties - all data here
const WARRIOR_SCENE_PATHS: Dictionary = {
	1: "res://scenes/warrior_1.tscn",
	2: "res://scenes/warrior_2.tscn",
	3: "res://scenes/warrior_3.tscn",
	4: "res://scenes/warrior_4.tscn",
	5: "res://scenes/warrior_5.tscn",
	6: "res://scenes/warrior_6.tscn"
}

var player_id: int = 1
var movement_points: int = GameParameters.MOVEMENT_POINTS_PER_TURN
var number: String = ""
var efficiency: int = 100  # Efficiency percentage (10-100), affects hit chances in battle

enum RecruitmentMoveState {
	NORMAL,
	TRANSFER_TO_CLOSEST,
	RECRUIT_OR_DEFEND
}

# Recruitment system
var recruitment_requested: bool = false  # Flag for requesting recruitment budget
var assigned_budget: BudgetComposition = null  # Budget allocated for this army's recruitment
var just_raised: bool = false  # Marks freshly raised AI armies for instant recruitment bypass
var recruitment_move_state: RecruitmentMoveState = RecruitmentMoveState.NORMAL
var _recruitment_threshold_base_roll: int = 10

# Army composition - soldiers in this army
var composition: ArmyComposition
var wounded_composition: ArmyComposition
var _animations: AnimatedSprite2D
var _victory: AnimatedSprite2D
var _animation_speed_scale: float = 1.0
var _victory_speed_scale: float = 1.0

func _init() -> void:
	z_index = 125
	scale = Vector2(0.5, 0.5)

func apply_map_size_scaling(map_generator: MapGenerator) -> void:
	"""Apply map size scaling to the army visual"""
	var map_size_scale: float = Utils.get_map_size_icon_scale(map_generator.map_size)
	scale = Vector2.ONE * map_size_scale * 0.4

func setup_army(new_player_id: int, roman_number: String, starting_composition: Dictionary = {}) -> void:
	"""Setup the army with player ID and default composition"""
	player_id = new_player_id
	movement_points = GameParameters.MOVEMENT_POINTS_PER_TURN
	efficiency = 100  # Start with full efficiency
	composition = ArmyComposition.new()
	wounded_composition = ArmyComposition.new()
	number = roman_number
	just_raised = false
	recruitment_move_state = RecruitmentMoveState.NORMAL
	
	# Set player-specific warrior visual
	_set_warrior_visual(player_id)
	
	# Start with a basic army composition
	var starting_comp = starting_composition
	if starting_comp.is_empty():
		starting_comp = GameParameters.get_starting_army_composition_human()
	for unit_type in starting_comp.keys():
		composition.set_soldier_count(unit_type, starting_comp[unit_type])
	
	z_index = 125 + player_id

func setup_raised_army(new_player_id: int, roman_number: String) -> void:
	"""Setup a newly raised army with 0 movement points and no soldiers"""
	DebugLogger.log("ArmyManagement", "[Army] setup_raised_army called for player " + str(new_player_id))
	player_id = new_player_id
	movement_points = 0
	efficiency = 100  # Start with full efficiency
	composition = ArmyComposition.new()
	wounded_composition = ArmyComposition.new()
	number = roman_number
	just_raised = true
	recruitment_move_state = RecruitmentMoveState.NORMAL
	
	# Set player-specific warrior visual
	_set_warrior_visual(player_id)
	composition.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, 1)
	
	z_index = 125 + player_id
	DebugLogger.log("ArmyManagement", "[Army] Raised army setup complete - movement_points: " + str(movement_points) + ", soldiers: " + str(composition.get_total_soldiers()))

func _emit_movement_points_changed() -> void:
	emit_signal("movement_points_changed", self, movement_points)

func reset_movement_points() -> void:
	"""Reset movement points for a new turn"""
	movement_points = GameParameters.MOVEMENT_POINTS_PER_TURN
	_emit_movement_points_changed()

func spend_movement_points(cost: int) -> void:
	"""Spend movement points for a move"""
	movement_points -= cost
	_emit_movement_points_changed()

func make_camp() -> void:
	"""Make camp - reduces movement points and restores efficiency"""
	if movement_points <= 0:
		return
	# Spend 1 movement point for making camp
	movement_points -= 1
	_emit_movement_points_changed()
	
	# Restore 10 efficiency (capped at 100%)
	restore_efficiency(10)
	# Attempt to heal wounded units using per-unit chance
	heal_army(false)
	
	DebugLogger.log("ArmyManagement", "[Army] " + str(name) + " made camp - efficiency restored to " + str(efficiency) + "%")

func heal_army(force_at_least_one: bool = false) -> void:
	"""Attempt to heal wounded across all unit types using CAMP_HEAL_CHANCE per unit.
	If force_at_least_one is true and there are wounded but none healed randomly, heal one guaranteed.
	"""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var healed_total: int = 0
	# Iterate unit types to keep logic simple and deterministic by type order
	for unit_type in SoldierTypeEnum.get_all_types():
		var wc: int = wounded_composition.get_soldier_count(unit_type)
		if wc <= 0:
			continue
		var to_heal: int = 0
		for i in wc:
			if rng.randf() < float(GameParameters.CAMP_HEAL_CHANCE):
				to_heal += 1
		if to_heal > 0:
			wounded_composition.remove_soldiers(unit_type, to_heal)
			composition.add_soldiers(unit_type, to_heal)
			healed_total += to_heal
	# Ensure at least one is healed when requested
	if force_at_least_one and healed_total == 0 and wounded_composition.get_total_soldiers() > 0:
		for unit_type in SoldierTypeEnum.get_all_types():
			var wc2: int = wounded_composition.get_soldier_count(unit_type)
			if wc2 > 0:
				wounded_composition.remove_soldiers(unit_type, 1)
				composition.add_soldiers(unit_type, 1)
				break

func get_player_id() -> int:
	"""Get the player ID"""
	return player_id

func get_movement_points() -> int:
	"""Get current movement points"""
	return movement_points

func get_efficiency() -> int:
	"""Get current efficiency percentage"""
	return efficiency

func set_efficiency(value: int) -> void:
	"""Set efficiency, clamped to 10-100 range"""
	efficiency = clamp(value, 10, 100)

func reduce_efficiency(amount: int) -> void:
	"""Reduce efficiency by amount, minimum 10%"""
	efficiency = max(10, efficiency - amount)

func restore_efficiency(amount: int) -> void:
	"""Restore efficiency by amount, maximum 100%"""
	efficiency = min(100, efficiency + amount)

# Army composition methods
func get_composition() -> ArmyComposition:
	"""Get the army composition"""
	return composition

func get_wounded_composition() -> ArmyComposition:
	"""Get the wounded army composition"""
	return wounded_composition

func get_soldier_count(soldier_type: SoldierTypeEnum.Type) -> int:
	"""Get count of specific soldier type"""
	return composition.get_soldier_count(soldier_type)

func add_soldiers(soldier_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Add soldiers to the army"""
	composition.add_soldiers(soldier_type, count)

func remove_soldiers(soldier_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Remove soldiers from the army"""
	composition.remove_soldiers(soldier_type, count)

func spawn_minimal_peasant_token() -> void:
	"""Leave a single peasant behind after transferring troops"""
	for soldier_type in SoldierTypeEnum.get_all_types():
		if soldier_type == SoldierTypeEnum.Type.PEASANTS:
			composition.set_soldier_count(soldier_type, 1)
		else:
			composition.set_soldier_count(soldier_type, 0)
	if wounded_composition != null:
		for soldier_type in SoldierTypeEnum.get_all_types():
			wounded_composition.set_soldier_count(soldier_type, 0)

func get_total_soldiers() -> int:
	"""Get total number of soldiers in the army"""
	return composition.get_total_soldiers()

func get_army_strength() -> int:
	"""Get total combat strength of the army"""
	return composition.get_total_attack()

func get_army_power() -> int:
	"""Calculate and return total power of the army (sum of unit power * quantity)"""
	var total_power := 0
	
	# Iterate through all soldier types and sum their power * quantity
	for soldier_type in SoldierTypeEnum.get_all_types():
		var quantity := composition.get_soldier_count(soldier_type)
		if quantity > 0:
			var unit_power: int = GameParameters.get_unit_stat(soldier_type, "power")
			total_power += unit_power * quantity
	
	return total_power

func get_army_composition_string() -> String:
	"""Get army composition as a readable string"""
	return composition.get_composition_string()

func get_display_name() -> String:
	"""Get a stable label for logging/UI, falling back to roman number when the node name is default"""
	var label := String(name)
	if label == "" or label.begins_with("@") or label.begins_with("Sprite2D") or label.begins_with("Node2D"):
		if number != "":
			return "Army " + str(number)
		return "Army"
	return label

func animate_move_to(target_pos: Vector2, duration: float, use_global: bool = false) -> Tween:
	"""Animate the army icon moving smoothly to target_pos over duration seconds.
	If use_global is true, animates global_position instead of local position."""
	DebugLogger.log("Animation", "Animating army %s to %s (duration=%.2f, global=%s)" % [name, str(target_pos), duration, str(use_global)])
	var tween := create_tween()
	if use_global:
		tween.tween_property(self, "global_position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		DebugLogger.log("Animation", "Animation finished for army %s" % name, 1)
	)
	return tween

func _set_warrior_visual(player_number: int) -> void:
	"""Set the warrior visual scene based on player number"""
	for child: Node in get_children():
		child.queue_free()
	var scene_path: String = WARRIOR_SCENE_PATHS.get(player_number, WARRIOR_SCENE_PATHS[1])
	var warrior_scene: PackedScene = load(scene_path) as PackedScene
	var warrior_instance: Node2D = warrior_scene.instantiate() as Node2D
	add_child(warrior_instance)
	_animations = warrior_instance.get_node("Animations") as AnimatedSprite2D
	_victory = warrior_instance.get_node("Victory") as AnimatedSprite2D
	_animation_speed_scale = _animations.speed_scale
	_victory_speed_scale = _victory.speed_scale
	_animations.visible = true
	_victory.visible = false
	var hidden_modulate: Color = _animations.modulate
	hidden_modulate.a = 0.0
	_victory.modulate = hidden_modulate
	_victory.animation_finished.connect(_on_victory_animation_finished)
	_animations.play("idle")
	DebugLogger.log("ArmyManagement", "[Army] Set warrior scene for Player " + str(player_number) + " to: " + str(scene_path))

func play_walking(speed_multiplier: float) -> void:
	_animations.visible = true
	_victory.visible = false
	_animations.speed_scale = _animation_speed_scale * speed_multiplier
	_animations.play("walking")

func play_idle() -> void:
	_animations.visible = true
	_victory.visible = false
	_animations.speed_scale = _animation_speed_scale
	_animations.play("idle")

func play_victory() -> void:
	_animations.visible = false
	_victory.visible = true
	_victory.speed_scale = _victory_speed_scale
	var victory_modulate: Color = _animations.modulate
	victory_modulate.a = 1.0
	_victory.modulate = victory_modulate
	_victory.play("victory")

func _on_victory_animation_finished() -> void:
	play_idle()

# Recruitment system methods
func request_recruitment() -> void:
	"""Flag this army as needing recruitment"""
	recruitment_requested = true

func clear_recruitment_request() -> void:
	"""Clear the recruitment request flag"""
	recruitment_requested = false
	assigned_budget = null
	_recruitment_threshold_base_roll = 10

func is_recruitment_requested() -> bool:
	"""Check if army has requested recruitment"""
	return recruitment_requested

func assign_recruitment_budget(budget: BudgetComposition) -> void:
	"""Assign a budget for this army's recruitment"""
	assigned_budget = budget

func get_assigned_budget() -> BudgetComposition:
	"""Get the budget assigned to this army"""
	return assigned_budget

func set_recruitment_move_state(state: RecruitmentMoveState) -> void:
	recruitment_move_state = state

func get_recruitment_move_state() -> RecruitmentMoveState:
	return recruitment_move_state

func get_recruitment_threshold(turn_number: int = 1, roll: bool = false, minimal: bool = false, maximum: bool = false) -> float:
	var effective_turn_number: int = turn_number
	if effective_turn_number > 40:
		effective_turn_number = 40
	if roll:
		_recruitment_threshold_base_roll = randi_range(10, 20)
	var base_roll: int = _recruitment_threshold_base_roll
	if minimal:
		base_roll = 10
	elif maximum:
		base_roll = 20
	var peasant_power: int = GameParameters.get_unit_stat(SoldierTypeEnum.Type.PEASANTS, "power")
	return float(base_roll) * (1.0 + 0.03 * float(effective_turn_number)) * float(peasant_power) * 2.0

func needs_recruitment(turn_number: int = 1, roll: bool = false, minimal: bool = false, maximum: bool = false) -> bool:
	"""Check if this army needs recruitment based on power threshold.
	Use roll=true only during the army turn-start refresh.
	All mid-turn checks should use roll=false (or read recruitment_requested directly) to avoid rerolling.
	"""
	var threshold: float = get_recruitment_threshold(turn_number, roll, minimal, maximum)
	DebugLogger.log("AIRecruitment", "[Army] " + str(name) + " needs recruitment: Army " + str(get_army_power()) + " vs threshold " + str(threshold))
	return float(get_army_power()) < threshold

func get_peasant_ratio() -> float:
	"""Get the current peasant proportion in the army"""
	var total_soldiers = get_total_soldiers()
	if total_soldiers == 0:
		return 0.0
	var peasant_count = get_soldier_count(SoldierTypeEnum.Type.PEASANTS)
	return float(peasant_count) / float(total_soldiers)

func compute_peasant_need(target_prop: float) -> int:
	"""Calculate how many peasants are needed to reach target proportion"""
	var total_soldiers = get_total_soldiers()
	var current_peasants = get_soldier_count(SoldierTypeEnum.Type.PEASANTS)
	var non_peasants = total_soldiers - current_peasants
	
	if total_soldiers == 0:
		# Army has no soldiers - need at least 1 peasant to achieve any proportion
		return 1
	
	# Calculate needed peasants: peasants / (peasants + non_peasants) = target_prop
	# Solving for peasants: peasants = target_prop * non_peasants / (1 - target_prop)
	if target_prop >= 1.0:
		# Can't achieve 100% peasants if we have non-peasants
		return 0
	
	var needed_peasants = int(ceil(target_prop * float(non_peasants) / (1.0 - target_prop)))
	var additional_needed = max(0, needed_peasants - current_peasants)
	
	return additional_needed
