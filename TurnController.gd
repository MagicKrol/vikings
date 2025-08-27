extends Node
class_name TurnController

# ============================================================================
# TURN CONTROLLER
# ============================================================================
# 
# Purpose: Single orchestrator for the entire turn pipeline
# 
# Core Responsibilities:
# - Deterministic turn flow (Human/AI shared pipeline)
# - Move execution, battle coordination, conquest handling
# - Debug step gating and turn boundary management
# - Signal-based coordination between systems
# 
# Turn Pipeline:
# 1. Find frontier regions (non-owned neighbors of owned)
# 2. Score regions and adjust per-army (random + MP cost)
# 3. Build move queue ordered by final score
# 4. Execute moves one by one with debug gates
# 5. Handle battles, conquest, and score recalculation
# 6. Continue until no valid moves remain
# ============================================================================

# Signals for turn lifecycle
signal turn_started(player_id: int)
signal move_prepared(army: Army, target_region_id: int, score: float)
signal move_started(army: Army, target_region_id: int)
signal battle_started(army: Army, target_region_id: int)
signal battle_finished(result: String)
signal region_conquered(region_id: int, new_owner_id: int)
signal turn_finished(player_id: int)

# Manager references
var region_manager: RegionManager
var army_manager: ArmyManager
var player_manager: PlayerManagerNode
var battle_manager: BattleManager
var pathfinder: ArmyPathfinder
var target_scorer: ArmyTargetScorer
var game_manager: GameManager = null  # Optional reference for turn index

# Debug step gate reference
var debug_step_gate: DebugStepGate

# Turn state
var current_player_id: int = -1
var moved_armies: Dictionary = {}  # Army -> bool
var _needs_reinf: Dictionary = {}  # Army -> bool

func initialize(region_mgr: RegionManager, army_mgr: ArmyManager, player_mgr: PlayerManagerNode, battle_mgr: BattleManager) -> void:
	"""Initialize with manager references"""
	region_manager = region_mgr
	army_manager = army_mgr
	player_manager = player_mgr
	battle_manager = battle_mgr
	
	# Create supporting systems
	pathfinder = ArmyPathfinder.new(region_manager, army_manager)
	target_scorer = ArmyTargetScorer.new(region_manager, region_manager.map_generator)
	
	# Create debug step gate
	debug_step_gate = DebugStepGate.new()
	add_child(debug_step_gate)
	
	# Connect battle manager signals
	if battle_manager:
		battle_manager.battle_finished.connect(_on_battle_finished)
	
	# Try to get GameManager reference
	var parent = get_parent()
	if parent and parent.has_method("get_current_turn"):
		game_manager = parent
	
	print("[TurnController] Initialized with all managers")

func _get_current_turn() -> int:
	"""Get the current turn number from GameManager or default to 1"""
	if game_manager:
		return game_manager.get_current_turn()
	return 1

func start_turn(player_id: int) -> void:
	"""Start a player's turn using the unified pipeline"""
	current_player_id = player_id
	moved_armies.clear()
	_needs_reinf.clear()
	
	# Calculate reinforcement needs for all armies at turn start
	var turn_number := _get_current_turn()
	for army in army_manager.get_player_armies(player_id):
		_needs_reinf[army] = army_manager.needs_reinforcement(army, turn_number)
		if _needs_reinf[army]:
			print("[TurnController] Army ", army.name, " needs reinforcement (power: ", army.get_army_power(), ") at turn ", turn_number)
	
	emit_signal("turn_started", player_id)
	print("[TurnController] Starting turn for Player ", player_id)
	
	await _process_turn(player_id)
	
	emit_signal("turn_finished", player_id)
	print("[TurnController] Completed turn for Player ", player_id)

func _process_turn(player_id: int) -> void:
	"""Main turn processing loop - shared between Human and AI"""
	var armies := _get_available_armies(player_id)
	
	while true:
		# Step 1: Find frontier targets
		var frontier := region_manager.get_frontier_regions(player_id)
		if frontier.is_empty():
			print("[TurnController] No frontier regions available")
			break
		
		# Step 2-4: Build move candidates from all armies
		var candidates: Array = []
		var turn_number := _get_current_turn()
		
		for army in armies:
			if moved_armies.has(army):
				continue
			if army.get_movement_points() <= 0:
				continue
			
			# Check reinforcement logic
			var on_region := army.get_parent() as Region
			if not on_region:
				continue
			var region_id: int = on_region.get_region_id()
			var on_castle := region_manager.get_castle_level(region_id) >= 1
			var needs: bool = _needs_reinf.get(army, false)
			
			if needs:
				if on_castle and army.get_movement_points() >= 1:
					# Reinforce now; do not mark as moved — we still want to consider a move
					army_manager.reinforce_army_basic(army)
					# Update the flag so we don't loop forever
					_needs_reinf[army] = army_manager.needs_reinforcement(army, turn_number)
					# Continue to build normal move candidate (it still has MP left)
				else:
					# Not on castle → override target: go to nearest owned castle
					var castle_id := region_manager.find_nearest_owned_castle_region_id(region_id, army.get_player_id())
					if castle_id != -1:
						# Build a "go to castle" candidate
						var pf := pathfinder.find_path_to_target(region_id, castle_id, army.get_player_id())
						if pf["success"]:
							candidates.append({
								"army": army,
								"target_id": castle_id,
								"path": pf["path"],
								"mp_cost": pf["cost"],
								"final_score": INF,  # Force priority
								"goal": "reinforce",  # Tag for debugging
								"current_region_id": region_id,
								"can_reach_now": int(pf["cost"]) <= army.get_movement_points()
							})
							continue  # Skip normal frontier evaluation
			
			# Normal frontier scoring for armies not needing reinforcement
			var best_move := _find_best_move_for_army(army, frontier)
			if not best_move.is_empty():
				candidates.append(best_move)
		
		if candidates.is_empty():
			print("[TurnController] No valid moves available")
			break
		
		# Step 5: Order by final score (highest first)
		candidates.sort_custom(func(a, b): return a["final_score"] > b["final_score"])
		var best_move = candidates[0]
		
		# Emit signal for move preparation
		emit_signal("move_prepared", best_move["army"], best_move["target_id"], best_move["final_score"])
		
		# Step 6: Debug gate before execution
		await debug_step_gate.step()
		
		# Step 7: Execute the move
		moved_armies[best_move["army"]] = true
		var ownership_changed := await _execute_move(best_move)
		
		# Step 8: Recalculate if ownership changed, otherwise continue
		if ownership_changed:
			print("[TurnController] Ownership changed - recalculating frontier")
			# Loop continues with fresh frontier calculation
		else:
			print("[TurnController] No ownership change - continuing with remaining armies")

func _get_available_armies(player_id: int) -> Array[Army]:
	"""Get armies that can still move this turn"""
	var available: Array[Army] = []
	var player_armies = army_manager.get_player_armies(player_id)
	
	for army in player_armies:
		if army == null or not is_instance_valid(army):
			continue
		if moved_armies.has(army):
			continue
		if army.get_movement_points() <= 0:
			continue
		available.append(army)
	
	return available

func _find_best_move_for_army(army: Army, frontier: Array[int]) -> Dictionary:
	"""Find the best target for a specific army"""
	var best_move := {}
	var reachable: Array = []
	var unreachable: Array = []
	var player_id := army.get_player_id()
	var current_region := army.get_parent()
	if not current_region or not current_region.has_method("get_region_id"):
		return {}
	var current_region_id: int = current_region.get_region_id()

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(army.name + str(player_id))
	var mp_available := army.get_movement_points()

	for target_id in frontier:
		var base_score := target_scorer.score_region_base(target_id)
		if base_score <= 0.0:
			continue

		var path_result := pathfinder.find_path_to_target(current_region_id, target_id, player_id)
		if not path_result["success"]:
			continue

		var cost := int(path_result["cost"])
		var can_reach_now := cost <= mp_available
		var random_mod := rng.randf() * GameParameters.AI_RANDOM_SCORE_MODIFIER
		var final_score := base_score + random_mod - float(cost)

		var cand := {
			"army": army,
			"target_id": target_id,
			"base_score": base_score,
			"random_modifier": random_mod,
			"mp_cost": cost,
			"final_score": final_score,
			"path": path_result["path"],
			"current_region_id": current_region_id,
			"can_reach_now": can_reach_now,
		}

		if can_reach_now:
			reachable.append(cand)
		else:
			unreachable.append(cand)

	var pool := reachable if reachable.size() > 0 else unreachable
	if pool.is_empty():
		return {}

	pool.sort_custom(func(a, b): return a["final_score"] > b["final_score"])
	return pool[0]

func _execute_move(move: Dictionary) -> bool:
	"""Execute a single move through the standardized pipeline"""
	var army: Army = move["army"]
	var target_id: int = move["target_id"]
	var path: Array[int] = move["path"]

	emit_signal("move_started", army, target_id)
	print("[TurnController] Executing move: %s -> Region %d (score: %.1f)"
		% [army.name, target_id, move["final_score"]])

	# Only allow a battle if the army could afford the full cost now.
	var initial_mp := army.get_movement_points()
	var can_reach_target_now := int(move["mp_cost"]) <= initial_mp

	var moved_ok := await _execute_army_movement(army, path)
	if not moved_ok:
		return false

	if not can_reach_target_now:
		print("[TurnController] Target out of MP this turn — moved toward it, no battle.")
		return false

	# We reached the target this turn — now check ownership and possibly start battle
	var target_region: Region = region_manager.map_generator.get_region_container_by_id(target_id)
	if _should_trigger_battle(army, target_region):
		emit_signal("battle_started", army, target_id)
		battle_manager.start_battle(army, target_id)
		var result: String = await battle_manager.battle_finished
		if result == "victory":
			region_manager.set_region_ownership(target_id, army.get_player_id())
			emit_signal("region_conquered", target_id, army.get_player_id())
			return true
	else:
		# No battle - check if we arrived at a castle and need reinforcement
		var target_owner := region_manager.get_region_owner(target_id)
		var army_owner := army.get_player_id()
		if target_owner == army_owner:
			var castle_level := region_manager.get_castle_level(target_id)
			if castle_level >= 1 and army.get_movement_points() >= 1 and _needs_reinf.get(army, false):
				# Reinforce at castle
				army_manager.reinforce_army_basic(army)
				var turn_number := _get_current_turn()
				_needs_reinf[army] = army_manager.needs_reinforcement(army, turn_number)
				print("[TurnController] Army reinforced at castle after movement")

	return false

func _execute_army_movement(army: Army, path: Array[int]) -> bool:
	"""Execute army movement along the path"""
	var player_id = army.get_player_id()
	var current_mp = army.get_movement_points()
	
	# Trim path to current MP limit
	var trimmed_path = pathfinder.trim_path_to_mp_limit(path, player_id, current_mp)
	if trimmed_path.size() <= 1:
		print("[TurnController] Cannot move - no valid path within MP limit")
		return false
	
	# Move army step by step
	var current_parent = army.get_parent()
	var final_region_id = trimmed_path[trimmed_path.size() - 1]
	var final_region = region_manager.map_generator.get_region_container_by_id(final_region_id)
	
	if final_region == null:
		print("[TurnController] Error: Final region not found")
		return false
	
	# Calculate total movement cost
	var total_cost = pathfinder.calculate_path_cost(trimmed_path, player_id)
	
	# Move army to final position
	if current_parent:
		current_parent.remove_child(army)
	final_region.add_child(army)
	
	# Update army position
	var polygon: Polygon2D = final_region.get_node("Polygon")
	army.position = polygon.get_meta("center") as Vector2
	
	# Deduct movement points
	army.spend_movement_points(total_cost)
	
	print("[TurnController] Army moved successfully (cost: %d, remaining MP: %d)" % [total_cost, army.get_movement_points()])
	return true

func _should_trigger_battle(army: Army, target_region: Region) -> bool:
	"""Check if moving to this region should trigger a battle"""
	if not army or not target_region:
		return false
	
	var region_owner = region_manager.get_region_owner(target_region.get_region_id())
	var army_player = army.get_player_id()
	
	# Battle if region is owned by different player
	if region_owner != -1 and region_owner != army_player:
		return true
	
	# Battle if neutral region has a garrison
	if region_owner == -1 and target_region.has_garrison():
		return true
	
	return false

func _on_battle_finished(result: String) -> void:
	"""Handle battle completion"""
	emit_signal("battle_finished", result)
