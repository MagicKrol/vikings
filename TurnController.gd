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

func initialize(region_mgr: RegionManager, army_mgr: ArmyManager, player_mgr: PlayerManagerNode, battle_mgr: BattleManager) -> void:
	"""Initialize with manager references"""
	region_manager = region_mgr
	army_manager = army_mgr
	player_manager = player_mgr
	battle_manager = battle_mgr
	
	if player_manager == null:
		push_error("[TurnController] CRITICAL: PlayerManagerNode is null during initialization!")
	else:
		print("[TurnController] PlayerManagerNode initialized successfully")
	
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
	
	var turn_number := _get_current_turn()
	
	# Step 1: Use BudgetManager to allocate recruitment budgets at turn start (only to armies at castles)
	var player_armies := army_manager.get_player_armies(player_id)
	if not player_armies.is_empty() and player_manager != null:
		var player := player_manager.get_player(player_id)
		if player:
			var budget_manager := BudgetManager.new()
			var assigned_count := budget_manager.allocate_recruitment_budgets(player_armies, player, region_manager, turn_number)
			print("[TurnController] BudgetManager assigned budgets to ", assigned_count, " armies at castles at turn start")
		else:
			print("[TurnController] Warning: Could not get player ", player_id, " from PlayerManagerNode")
	elif player_manager == null:
		print("[TurnController] Warning: PlayerManagerNode is null - skipping budget allocation")
	
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
			
			if army.is_recruitment_requested():
				if on_castle and army.assigned_budget != null:
					if army.get_movement_points() >= 1:
						var recruitment_manager := RecruitmentManager.new()
						var result := recruitment_manager.hire_soldiers(army, true)  # Enable debug temporarily
						if result.has("error"):
							print("[TurnController] RecruitmentManager error: ", result.get("error", "unknown"))
					else:
						print("[TurnController] Army ", army.name, " has no movement points to recruit. We skip turn")

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
		
		# Step 6: Execute the move (ai_travel_to handles debug stepping internally)
		# Note: Removed redundant debug gate here since ai_travel_to has its own step-by-step gating
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

	if can_reach_target_now:
		# Army can reach target this turn - use ai_travel_to for step-by-step debug
		var result = await game_manager.ai_travel_to(army, target_id)
		if result == "blocked":
			return false
		elif result == "battle_victory":
			emit_signal("region_conquered", target_id, army.get_player_id())
			return true
		elif result == "battle_defeat":
			return false
		elif result == "arrived":
			# Peaceful arrival - no ownership change
			return false
		else:
			print("[TurnController] Unexpected ai_travel_to result: ", result)
			return false
	else:
		# Army cannot reach target this turn - use ai_travel_to for partial movement
		var result = await game_manager.ai_travel_to(army, target_id)
		if result == "battle_victory":
			emit_signal("region_conquered", target_id, army.get_player_id())
			return true
		else:
			# No ownership change for partial movement or other results
			return false

# _execute_army_movement_toward_target removed - ai_travel_to handles both full and partial movement

func _should_trigger_battle(army: Army, target_region: Region) -> bool:
	"""Check if moving to this region should trigger a battle - delegates to GameManager"""
	if game_manager and game_manager.has_method("_should_trigger_battle"):
		return game_manager._should_trigger_battle(army, target_region)
	
	# Fallback to original logic if GameManager not available
	if not army or not target_region:
		return false
	
	var region_owner = region_manager.get_region_owner(target_region.get_region_id())
	var army_player = army.get_player_id()
	
	if region_owner != -1 and region_owner != army_player:
		return true
	
	if region_owner == -1 and target_region.has_garrison():
		return true
	
	return false

func _on_battle_finished(result: String) -> void:
	"""Handle battle completion"""
	emit_signal("battle_finished", result)
