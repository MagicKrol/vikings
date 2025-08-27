extends Sprite2D
class_name Army

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
# - Visual representation as map sprite
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
var player_id: int = 1
var movement_points: int = GameParameters.MOVEMENT_POINTS_PER_TURN
var number: String = ""
var efficiency: int = 100  # Efficiency percentage (10-100), affects hit chances in battle

# Army composition - soldiers in this army
var composition: ArmyComposition

func _init():
	# Set up the army sprite with default warrior image (will be updated in setup)
	texture = load("res://images/warrior_1.png")  # Default to player 1 warrior
	scale = Vector2(0.06, 0.06)
	z_index = 125

func setup_army(new_player_id: int, roman_number: String) -> void:
	"""Setup the army with player ID and default composition"""
	player_id = new_player_id
	movement_points = GameParameters.MOVEMENT_POINTS_PER_TURN
	efficiency = 100  # Start with full efficiency
	composition = ArmyComposition.new()
	number = roman_number
	
	# Set player-specific warrior texture
	_set_warrior_texture(player_id)
	
	# Start with a basic army composition
	composition.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, 20)
	composition.set_soldier_count(SoldierTypeEnum.Type.KNIGHTS, 1)
	
	z_index = 125 + player_id

func setup_raised_army(new_player_id: int, roman_number: String) -> void:
	"""Setup a newly raised army with 0 movement points and no soldiers"""
	print("[Army] setup_raised_army called for player ", new_player_id)
	player_id = new_player_id
	movement_points = 0
	efficiency = 100  # Start with full efficiency
	composition = ArmyComposition.new()
	number = roman_number
	
	# Set player-specific warrior texture
	_set_warrior_texture(player_id)
	
	# Raised armies start empty - no soldiers
	# Players need to recruit soldiers separately
	
	z_index = 125 + player_id
	print("[Army] Raised army setup complete - movement_points: ", movement_points, ", soldiers: ", composition.get_total_soldiers())

func reset_movement_points() -> void:
	"""Reset movement points for a new turn"""
	movement_points = GameParameters.MOVEMENT_POINTS_PER_TURN

func spend_movement_points(cost: int) -> void:
	"""Spend movement points for a move"""
	movement_points -= cost

func make_camp() -> void:
	"""Make camp - reduces movement points and restores efficiency"""
	# Spend 1 movement point for making camp
	if movement_points > 0:
		movement_points -= 1
	
	# Restore 10 efficiency (capped at 100%)
	restore_efficiency(10)
	
	print("[Army] ", name, " made camp - efficiency restored to ", efficiency, "%")

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

func get_soldier_count(soldier_type: SoldierTypeEnum.Type) -> int:
	"""Get count of specific soldier type"""
	return composition.get_soldier_count(soldier_type)

func add_soldiers(soldier_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Add soldiers to the army"""
	composition.add_soldiers(soldier_type, count)

func remove_soldiers(soldier_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Remove soldiers from the army"""
	composition.remove_soldiers(soldier_type, count)

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

func _set_warrior_texture(player_number: int) -> void:
	"""Set the warrior texture based on player number"""
	var texture_path = "res://images/warrior_" + str(player_number) + ".png"
	var new_texture = load(texture_path)
	
	if new_texture != null:
		texture = new_texture
		print("[Army] Set warrior texture for Player ", player_number, " to: ", texture_path)
	else:
		print("[Army] Warning: Could not load warrior texture for Player ", player_number, " at: ", texture_path)
		# Fallback to default warrior image
		texture = load("res://images/warrior_1.png")
