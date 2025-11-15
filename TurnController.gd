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
var _log_active_turn: bool = false
var _recruitment_status_cache: Dictionary = {}
var _turn_start_resources: Dictionary = {}

func initialize(region_mgr: RegionManager, army_mgr: ArmyManager, player_mgr: PlayerManagerNode, battle_mgr: BattleManager) -> void:
	"""Initialize with manager references"""
	region_manager = region_mgr
	army_manager = army_mgr
	player_manager = player_mgr
	battle_manager = battle_mgr
	
	if player_manager == null:
		push_error("[TurnController] CRITICAL: PlayerManagerNode is null during initialization!")
	else:
		DebugLogger.log("AITurnManager", "[TurnController] PlayerManagerNode initialized successfully")
	
	# Create supporting systems
	pathfinder = ArmyPathfinder.new(region_manager, army_manager)
	target_scorer = ArmyTargetScorer.new(region_manager, region_manager.map_generator, player_manager, null)
	
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
	if target_scorer != null:
		target_scorer.set_runtime_references(player_manager, game_manager)
	
	DebugLogger.log("AITurnManager", "[TurnController] Initialized with all managers")

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
	var is_ai_player := game_manager.is_player_ai(player_id)
	_log_active_turn = is_ai_player
	if _log_active_turn:
		game_manager.ensure_ai_log_started()
		_recruitment_status_cache.clear()
		var player = player_manager.get_player(player_id)
		if player != null:
			_turn_start_resources = player.get_all_resources()
		else:
			_turn_start_resources = {}
	else:
		_turn_start_resources = {}

	# Step 1: Use EconomyAIManager to plan economy and allocate budgets (recruitment wired-in)
	var econ := EconomyAIManager.new(region_manager, army_manager, player_manager, game_manager)
	var econ_result = econ.plan_turn(player_id, turn_number)
	_log_turn_intro(player_id, turn_number, econ_result)
	_log_economy_plan(econ_result)
	var army_recruitment: Dictionary = econ_result.get("army_recruitment", {})
	var assigned_count = int(army_recruitment.get("budgets_assigned", 0))
	var raise_result = econ_result.get("raise", {"raised": false})
	DebugLogger.log("AITurnManager", "[TurnController] EconomyAIManager assigned recruitment budgets to " + str(assigned_count) + " armies at castles")
	if raise_result.get("raised", false):
		DebugLogger.log("AITurnManager", "[TurnController] EconomyAIManager raised new army at region " + str(raise_result.get("region_id", -1)))
	
	emit_signal("turn_started", player_id)
	DebugLogger.log("AITurnManager", "[TurnController] Starting turn for Player " + str(player_id))
	
	await _process_turn(player_id)
	if player_manager != null and player_manager.has_method("update_player_wealth_status"):
		player_manager.update_player_wealth_status(player_id)
	emit_signal("turn_finished", player_id)
	DebugLogger.log("AITurnManager", "[TurnController] Completed turn for Player " + str(player_id))
	_log_turn_outro(player_id)

func _process_turn(player_id: int) -> void:
	"""Main turn processing loop - shared between Human and AI"""
	while true:
		# Refresh army list each loop to avoid referencing freed armies after battles
		var armies := _get_available_armies(player_id)
		# Step 1: Find frontier targets
		var frontier := region_manager.get_frontier_regions(player_id)
		if frontier.is_empty():
			DebugLogger.log("AITurnManager", "[TurnController] No frontier regions available")
			break
		
		# Step 2-4: Build move candidates from all armies
		var candidates: Array = []
		var turn_number := _get_current_turn()
		
		for army in armies:
			DebugLogger.log("AITurnManager", "[TurnController] Army " + str(army.name) + " Power: " + str(army.get_army_power()))
			if moved_armies.has(army):
				continue
			if army.get_movement_points() <= 0:
				continue
			# Rest rule 3: if efficiency < 75% at beginning, spend all MPs making camp
			if army.get_efficiency() < 75:
				while army.get_movement_points() > 0:
					army.make_camp()
					_log_army_make_camp(army)
				moved_armies[army] = true
				continue
			
			# Check reinforcement logic
			var on_region := army.get_parent() as Region
			if not on_region:
				continue
			var region_id: int = on_region.get_region_id()
			var on_castle := region_manager.get_castle_level(region_id) >= 1
			var needs_recruitment := army.needs_recruitment(turn_number)
			
			if army.is_recruitment_requested():
				var assigned_budget := army.get_assigned_budget()
				if assigned_budget == null:
					_log_recruitment_status_once(army, region_id, "no_budget_assigned")
					var reinforce_move := _build_reinforce_move_candidate(army, region_id)
					if reinforce_move.is_empty():
						_log_recruitment_skip(army, region_id, "no_castle_available")
						army.clear_recruitment_request()
					else:
						candidates.append(reinforce_move)
					continue
				if on_castle:
					var allow_recruit := army.get_movement_points() >= 1
					# Allow instant recruitment for freshly raised AI armies (flagged)
					if game_manager.is_player_ai(player_id) and army.just_raised:
						allow_recruit = true
					if allow_recruit:
						var recruitment_manager = RecruitmentManager.new(region_manager, game_manager)
						var comp_before = _get_army_composition_suffix(army)
						var power_before = army.get_army_power()
						var result = recruitment_manager.hire_soldiers(army, true)
						if army.get_total_soldiers() > 0:
							army.just_raised = false
						if result.has("error"):
							DebugLogger.log("AITurnManager", "[TurnController] RecruitmentManager error: " + str(result.get("error", "unknown")))
							_log_recruitment_skip(army, region_id, String(result.get("error", "unknown")))
						else:
							_log_recruitment_success(army, region_id, result, comp_before, power_before)
					else:
						DebugLogger.log("AITurnManager", "[TurnController] Army " + str(army.name) + " cannot recruit now (no MP and not fresh AI). Skipping.")
						_log_recruitment_skip(army, region_id, "no_movement_points")
				else:
					_log_recruitment_skip(army, region_id, "not_at_castle")
					var reinforce_move2 := _build_reinforce_move_candidate(army, region_id)
					if reinforce_move2.is_empty():
						_log_recruitment_skip(army, region_id, "no_castle_available")
					else:
						candidates.append(reinforce_move2)
						continue  # Skip normal frontier evaluation
			else:
				if needs_recruitment:
					_log_recruitment_status_once(army, region_id, "no_budget_assigned")
				else:
					_log_recruitment_status_once(army, region_id, "not_needed")
			
			# Check peasants-only recruitment (only if normal recruitment not needed)
			var peasant_plan = _needs_recruitment_peasants(army, turn_number)
			if peasant_plan["needed"]:
				var best_peasant_region = _find_best_owned_region_for_peasants(army)
				if best_peasant_region != -1:
					if best_peasant_region == region_id:
						# Current region is best - hire peasants immediately
						var hired = _hire_peasants_at_region(army, on_region, peasant_plan["ideal_needed"])
						if hired > 0:
							DebugLogger.log("AIRecruitment", "Army " + str(army.name) + " hired " + str(hired) + " peasants at current region")
							_log_peasant_recruitment(army, on_region, hired)
						# Continue to normal movement scoring since army can still move/fight
					else:
						# Need to move to different region for peasants
						var pf = pathfinder.find_path_to_target(region_id, best_peasant_region, army.get_player_id())
						if pf["success"]:
							candidates.append({
								"army": army,
								"target_id": best_peasant_region,
								"path": pf["path"],
								"mp_cost": pf["cost"],
								"final_score": INF - 1,  # High priority, but lower than reinforce
								"goal": "peasants",
								"current_region_id": region_id,
								"can_reach_now": int(pf["cost"]) <= army.get_movement_points(),
								"peasant_plan": peasant_plan
							})
							continue  # Skip normal frontier evaluation
			
			# Normal frontier scoring for armies not needing reinforcement
			var best_move := _find_best_move_for_army(army, frontier)
			if not best_move.is_empty():
				candidates.append(best_move)
		
		if candidates.is_empty():
			DebugLogger.log("AITurnManager", "[TurnController] No valid moves available")
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
			DebugLogger.log("AITurnManager", "[TurnController] Ownership changed - recalculating frontier")
			# Loop continues with fresh frontier calculation
		else:
			DebugLogger.log("AITurnManager", "[TurnController] No ownership change - continuing with remaining armies")

	# Rest rule 1: any remaining MPs at end of turn are spent making camp
	var all_armies := army_manager.get_player_armies(player_id)
	for a in all_armies:
		while a.get_movement_points() > 0:
			a.make_camp()
			_log_army_make_camp(a)

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
	var army_log_token := game_manager.get_ai_battle_log_token(army) if game_manager else ""
	var target_id: int = move["target_id"]
	var path: Array[int] = move["path"]

	emit_signal("move_started", army, target_id)
	DebugLogger.log("AITurnManager", "[TurnController] Executing move: %s -> Region %d (score: %.1f, goal: %s)"
		% [army.name, target_id, move["final_score"], move.get("goal", "attack")])
	_log_army_move_action(army, move)

	# Handle peasants-only moves specially
	if move.get("goal", "") == "peasants":
		var result = await game_manager.ai_travel_to(army, target_id)
		var log_army: Army = army if is_instance_valid(army) else null
		_log_army_move_result(log_army, target_id, result, army_log_token)
		if result == "arrived":
			# Hire peasants at destination
			var target_region = region_manager.map_generator.get_region_container_by_id(target_id)
			var peasant_plan = move.get("peasant_plan", {})
			var hired = _hire_peasants_at_region(army, target_region, peasant_plan.get("ideal_needed", 0))
			DebugLogger.log("AIRecruitment", "Peasants-only move completed: hired " + str(hired) + " peasants")
			if hired > 0:
				_log_peasant_recruitment(army, target_region, hired)
		return false  # No ownership change for peasants-only moves

	# Only allow a battle if the army could afford the full cost now.
	var initial_mp := army.get_movement_points()
	var can_reach_target_now := int(move["mp_cost"]) <= initial_mp

	if can_reach_target_now:
		DebugLogger.log("AITurnManager", "[TurnController] Army can reach target this turn")
		# Rest rule 2: if about to attack and efficiency < 90%, try to make camp twice (limited by MPs)
		var target_region: Region = region_manager.map_generator.get_region_container_by_id(target_id)
		if _should_trigger_battle(army, target_region):
			_rest_army_before_battle(army)
		# Army can reach target this turn - use ai_travel_to for step-by-step debug
		var result = await game_manager.ai_travel_to(army, target_id)
		var log_army: Army = army if is_instance_valid(army) else null
		_log_army_move_result(log_army, target_id, result, army_log_token)
		DebugLogger.log("AITurnManager", "[TurnController] ai_travel_to result: " + str(result))
		if result == "out_of_movement_points":
			return false
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
			DebugLogger.log("AITurnManager", "[TurnController] Unexpected ai_travel_to result: " + str(result))
			return false
	else:
		DebugLogger.log("AITurnManager", "[TurnController] Army cannot reach target this turn")
		# Army cannot reach target this turn - use ai_travel_to for partial movement
		var result = await game_manager.ai_travel_to(army, target_id)
		var log_army: Army = army if is_instance_valid(army) else null
		_log_army_move_result(log_army, target_id, result, army_log_token)
		DebugLogger.log("AITurnManager", "[TurnController] ai_travel_to result: " + str(result))
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

# Peasants-only recruitment helpers
func _needs_recruitment_peasants(army: Army, turn_number: int) -> Dictionary:
	"""Check if army needs peasants-only recruitment"""
	# Early gate: if normal recruitment is needed, skip peasants-only
	if army.needs_recruitment(turn_number):
		return {"needed": false}
	
	# Check current peasant ratio
	var current_ratio = army.get_peasant_ratio()
	if current_ratio >= GameParameters.AI_PEA_MIN_PROP_BASE:
		return {"needed": false}
	
	# Determine target proportion based on army power
	var army_power = army.get_army_power()
	var target_prop = 0.0
	if army_power < GameParameters.AI_PEA_POWER_LOW_MAX:
		target_prop = GameParameters.AI_PEA_TARGET_PROP_LOW
	elif army_power >= GameParameters.AI_PEA_POWER_HIGH_MIN:
		target_prop = GameParameters.AI_PEA_TARGET_PROP_HIGH
	else:
		target_prop = GameParameters.AI_PEA_TARGET_PROP_MID
	
	var ideal_needed = army.compute_peasant_need(target_prop)
	
	DebugLogger.log("AIRecruitment", "Army " + str(army.name) + " peasant need: current=" + str(current_ratio) + ", target=" + str(target_prop) + ", need=" + str(ideal_needed))
	
	return {
		"needed": true,
		"target_prop": target_prop,
		"ideal_needed": ideal_needed
	}

func _find_best_owned_region_for_peasants(army: Army) -> int:
	"""Find the best owned region reachable this turn for peasant recruitment"""
	var player_id = army.get_player_id()
	var current_region = army.get_parent() as Region
	if not current_region:
		return -1
	
	var current_region_id = current_region.get_region_id()
	var owned_regions = region_manager.get_player_regions(player_id)
	var candidates = []
	
	for region_id in owned_regions:
		var path_result = pathfinder.find_path_to_target(current_region_id, region_id, player_id)
		if not path_result["success"]:
			continue
		
		var cost = int(path_result["cost"])
		if cost > army.get_movement_points():
			continue  # Not reachable this turn
		
		var region_container = region_manager.map_generator.get_region_container_by_id(region_id)
		var available_recruits = region_container.get_available_recruits()
		
		candidates.append({
			"region_id": region_id,
			"available_recruits": available_recruits,
			"cost": cost
		})
	
	if candidates.is_empty():
		return -1
	
	# Sort by available recruits (highest first), then by region_id for deterministic tie-break
	candidates.sort_custom(func(a, b):
		if a["available_recruits"] == b["available_recruits"]:
			return a["region_id"] < b["region_id"]
		return a["available_recruits"] > b["available_recruits"]
	)
	
	DebugLogger.log("AIRecruitment", "Best peasant region: " + str(candidates[0]["region_id"]) + " with " + str(candidates[0]["available_recruits"]) + " recruits")

	return candidates[0]["region_id"]

func _build_reinforce_move_candidate(army: Army, current_region_id: int, include_origin: bool = false) -> Dictionary:
	var castle_pick := region_manager.find_best_recruitment_castle(current_region_id, army.get_player_id(), include_origin)
	var castle_id := int(castle_pick.get("best_region_id", -1))
	if castle_id == -1:
		return {}
	var pf := pathfinder.find_path_to_target(current_region_id, castle_id, army.get_player_id())
	if not pf["success"]:
		return {}
	return {
		"army": army,
		"target_id": castle_id,
		"path": pf["path"],
		"mp_cost": pf["cost"],
		"final_score": INF,
		"goal": "reinforce",
		"current_region_id": current_region_id,
		"can_reach_now": int(pf["cost"]) <= army.get_movement_points(),
		"castle_log": _build_castle_log_lines(castle_pick.get("candidates", []))
	}

func _build_castle_log_lines(candidates: Array) -> Array[String]:
	if candidates.is_empty():
		return []
	var sorted := candidates.duplicate()
	if sorted.size() > 1:
		sorted.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	var lines: Array[String] = []
	var max_entries: int = min(3, sorted.size())
	for i in range(max_entries):
		var entry: Dictionary = sorted[i]
		var name := String(entry.get("region_name", _get_region_name_by_id(int(entry.get("region_id", -1)))))
		var recruits := int(entry.get("recruits", 0))
		var distance := int(entry.get("distance", 0))
		var level := int(entry.get("castle_level", 0))
		var score := float(entry.get("score", 0.0))
		lines.append("Castle %s - recruits:%d, distance:%d, level:%d, score: %.1f" % [name, recruits, distance, level, score])
	return lines

func _hire_peasants_at_region(army: Army, region: Region, max_needed: int) -> int:
	"""Hire peasants at the specified region"""
	var available = region.get_available_recruits()
	var to_hire = min(available, max_needed)
	
	if to_hire > 0:
		var actual_hired = region.hire_recruits(to_hire)
		army.add_soldiers(SoldierTypeEnum.Type.PEASANTS, actual_hired)
		DebugLogger.log("AIRecruitment", "Hired " + str(actual_hired) + " peasants at region " + str(region.get_region_id()) + " (new ratio: " + str(army.get_peasant_ratio()) + ")")
		return actual_hired
	
	return 0

func _log_turn_intro(player_id: int, turn_number: int, econ_result: Dictionary) -> void:
	if not _log_active_turn:
		return
	var player = player_manager.get_player(player_id)
	var resources = player.get_all_resources()
	if _turn_start_resources.size() > 0:
		resources = _turn_start_resources.duplicate()
	var wealth_label = _describe_wealth_level(player.get_wealth_level())
	var region_ids = region_manager.get_player_regions(player_id)
	var region_names: Array[String] = []
	for region_id in region_ids:
		var region = region_manager.map_generator.get_region_container_by_id(region_id)
		region_names.append(region.get_region_name())
	var signals: Dictionary = econ_result.get("signals", {})
	var decision = String(econ_result.get("decision", ""))
	var player_label = "%s (#%d)" % [player.get_player_name(), player_id]
	game_manager.get_ai_log_manager().log_turn_intro(turn_number, player_label, player_id, resources, signals, decision, region_names, wealth_label)

func _log_turn_outro(player_id: int) -> void:
	if not _log_active_turn:
		return
	var player = player_manager.get_player(player_id)
	if player == null:
		return
	var resources = player.get_all_resources()
	game_manager.get_ai_log_manager().log_turn_outro(resources)
	_turn_start_resources = {}

func _describe_wealth_level(level: int) -> String:
	match level:
		GameParameters.WealthLevel.RICH:
			return "Rich"
		GameParameters.WealthLevel.NORMAL:
			return "Normal"
		_:
			return "Poor"

func _log_army_move_action(army: Army, move: Dictionary) -> void:
	var action = "Moves"
	var goal = String(move.get("goal", ""))
	if goal == "reinforce":
		action = "Recruits"
	var target_name = _get_region_name_by_id(move["target_id"])
	_log_army_summary(army, action, target_name)
	_log_army_move_path_preview(army, move)
	if move.has("castle_log"):
		var castle_lines: Array = move.get("castle_log", [])
		for line in castle_lines:
			_log_army_detail_line(line)

func _log_army_make_camp(army: Army) -> void:
	_log_army_detail_line("%s makes camp" % army.name)

func _log_army_move_path_preview(army: Army, move: Dictionary) -> void:
	var path: Array = move.get("path", [])
	if path.size() <= 1:
		return
	for i in range(1, path.size()):
		var step_name = _get_region_name_by_id(path[i])
		_log_army_detail_line("Moves to %s" % step_name)

func _log_army_move_result(army: Army, target_region_id: int, result: String, army_log_token: String) -> void:
	var target_name = _get_region_name_by_id(target_region_id)
	match result:
		"battle_victory":
			_log_army_detail_line("Fight at %s" % target_name)
			_log_recent_battle_details(army, army_log_token)
		"battle_defeat":
			_log_army_detail_line("Fight at %s" % target_name)
			_log_recent_battle_details(army, army_log_token)
		"battle_withdrawal":
			_log_army_detail_line("Fight at %s" % target_name)
			var withdraw_name = target_name
			if army != null and is_instance_valid(army):
				var current_region = army.get_parent() as Region
				if current_region:
					withdraw_name = current_region.get_region_name()
			_log_army_detail_line("Withdrew to %s" % withdraw_name)
			_log_recent_battle_details(army, army_log_token)
		"arrived":
			_log_army_detail_line("Arrived at %s" % target_name)
		"blocked":
			_log_army_detail_line("Movement blocked near %s" % target_name)
		"out_of_movement_points":
			_log_army_detail_line("Out of movement points before reaching %s" % target_name)
		_:
			pass

func _log_recruitment_success(army: Army, region_id: int, result: Dictionary, composition_before: String = "", power_before: int = -1) -> void:
	if not _log_active_turn:
		return
	var hired: Dictionary = result.get("hired", {})
	var total_hired = 0
	for key in hired.keys():
		total_hired += int(hired[key])
	var location = _get_region_name_by_id(region_id)
	var spent_gold = int(result.get("spent_gold", 0))
	var spent_wood = int(result.get("spent_wood", 0))
	var spent_iron = int(result.get("spent_iron", 0))
	var comp_before = composition_before if composition_before != "" else _get_army_composition_suffix(army)
	var power_for_log = power_before if power_before >= 0 else army.get_army_power()
	_log_army_summary(army, "Recruits", location, comp_before, power_for_log)
	if region_manager != null:
		var castle_pick := region_manager.find_best_recruitment_castle(region_id, army.get_player_id(), true)
		var castle_lines := _build_castle_log_lines(castle_pick.get("candidates", []))
		for line in castle_lines:
			_log_army_detail_line(line)
	var message = "Army %s recruited %d at %s (gold: %d, wood: %d, iron: %d)" % [
		army.name,
		total_hired,
		location,
		spent_gold,
		spent_wood,
		spent_iron
	]
	game_manager.get_ai_log_manager().log_recruitment(message)
	_log_army_detail_line("%s [Power: %d - %s]" % [army.name, army.get_army_power(), _get_army_composition_suffix(army)])

func _log_recruitment_skip(army: Army, region_id: int, reason: String) -> void:
	if not _log_active_turn:
		return
	if reason == "not_needed":
		return
	var location = _get_region_name_by_id(region_id)
	var message = "Army %s could not recruit at %s (reason: %s)" % [army.name, location, reason]
	game_manager.get_ai_log_manager().log_recruitment(message)

func _log_recruitment_status_once(army: Army, region_id: int, reason: String) -> void:
	if not _log_active_turn:
		return
	if reason == "not_needed":
		return
	var previous = _recruitment_status_cache.get(army, "")
	if previous == reason:
		return
	_recruitment_status_cache[army] = reason
	_log_recruitment_skip(army, region_id, reason)

func _log_peasant_recruitment(army: Army, region: Region, amount: int) -> void:
	if not _log_active_turn or amount <= 0:
		return
	var message = "Army %s raised %d peasants at %s" % [army.name, amount, region.get_region_name()]
	game_manager.get_ai_log_manager().log_recruitment(message)

func _log_economy_plan(econ_result: Dictionary) -> void:
	if not _log_active_turn:
		return
	if game_manager == null or not game_manager.has_method("get_ai_log_manager"):
		return
	var log := game_manager.get_ai_log_manager()
	var recruitment = econ_result.get("army_recruitment", {})
	var army_hires: Array = recruitment.get("army_hires", [])
	if army_hires.size() > 0:
		log.log_economy("Army hires: %s" % _join_strings(army_hires))
	var danger = int(recruitment.get("garrison_danger", 0))
	if danger > 0:
		log.log_economy("Danger castles checked: %d." % danger)
	var defense_entries: Array = recruitment.get("garrison_defense_entries", [])
	var defense_reason = String(recruitment.get("garrison_defense_reason", "none"))
	log.log_castle_recruitment_summary("Castle Defense Recruitment", defense_entries, defense_reason)
	var garrison_skip_logs: Array = recruitment.get("garrison_skip_logs", [])
	for note in garrison_skip_logs:
		log.log_economy("Castle Defense Recruitment skipped: %s" % note)
	
	var raise = econ_result.get("raise", {})
	if raise.get("raised", false):
		var region_name = _get_region_name_by_id(int(raise.get("region_id", -1)))
		log.log_economy("Raise Army: Raised at %s." % region_name)
	else:
		log.log_economy("Raise Army: %s." % String(raise.get("reason", "skipped")))
	
	var build_castle = econ_result.get("build_castle", {})
	if build_castle.get("executed", false):
		var build_region = _get_region_name_by_id(int(build_castle.get("region_id", -1)))
		log.log_economy("Build Castle: Started construction at %s." % build_region)
	else:
		log.log_economy("Build Castle: %s." % String(build_castle.get("reason", "skipped")))
	
	var upgrade_castle = econ_result.get("upgrade_castle", {})
	if upgrade_castle.get("executed", false):
		var upgrade_region_name = _get_region_name_by_id(int(upgrade_castle.get("region_id", -1)))
		log.log_economy("Upgrade Castle: Upgraded %s." % upgrade_region_name)
	else:
		log.log_economy("Upgrade Castle: %s." % String(upgrade_castle.get("reason", "skipped")))
	
	var upgrade_region = econ_result.get("upgrade_region", {})
	if upgrade_region.get("executed", false):
		var actions: Array = upgrade_region.get("actions", [])
		if actions.size() > 0:
			log.log_economy("Upgrade Region actions: %s" % _join_strings(actions))
		else:
			log.log_economy("Upgrade Region: executed.")
	else:
		log.log_economy("Upgrade Region: %s." % String(upgrade_region.get("reason", "skipped")))
	
	_log_ore_summary(log, econ_result.get("ore", {}))
	var trickle = econ_result.get("garrison_trickle", {})
	var trickle_reason = _describe_trickle_reason(String(trickle.get("reason", "success")))
	log.log_castle_recruitment_summary("Additional Castle Recruitment", trickle.get("entries", []), trickle_reason)
	log.log_army_movemement()

func _log_ore_summary(log, ore: Dictionary) -> void:
	var attempts = int(ore.get("attempts", 0))
	var discoveries = int(ore.get("discoveries", 0))
	var gold_spent = int(ore.get("gold_spent", 0))
	if attempts == 0:
		var reason = String(ore.get("reason", "none"))
		match reason:
			"no_regions":
				log.log_economy("Ore search: skipped (no eligible regions).")
			"no_gold":
				log.log_economy("Ore search: skipped (insufficient gold).")
			_:
				log.log_economy("Ore search: skipped.")
		return
	log.log_economy("Ore search: attempts=%d, discoveries=%d, gold_spent=%d." % [attempts, discoveries, gold_spent])
	var discovered_regions: Array = ore.get("discovered_regions", [])
	if discovered_regions.size() > 0:
		log.log_economy("Ore discoveries: %s" % _join_strings(discovered_regions))

func _log_army_summary(army: Army, action: String, target_region: String, composition_override: String = "", power_override: int = -1) -> void:
	if not _log_active_turn:
		return
	var comp = composition_override if composition_override != "" else _get_army_composition_suffix(army)
	var power_value = power_override if power_override >= 0 else army.get_army_power()
	var eff_value = army.get_efficiency()
	game_manager.get_ai_log_manager().log_army_action(army.name, power_value, eff_value, action, target_region, comp)

func _log_army_detail_line(text: String) -> void:
	if not _log_active_turn or text == "":
		return
	game_manager.get_ai_log_manager().log_army_detail(text)

func _log_recent_battle_details(army: Army, army_log_token: String) -> void:
	if not _log_active_turn:
		return
	var lines: Array[String] = []
	if army != null and game_manager:
		lines = game_manager.consume_ai_battle_log_for_army(army)
	if lines.is_empty() and army_log_token != "" and game_manager:
		lines = game_manager.consume_ai_battle_log_for_token(army_log_token)
	if lines.is_empty():
		return
	for line in lines:
		if line == "":
			game_manager.get_ai_log_manager().log_army_detail("")
		else:
			_log_army_detail_line(line)

func _rest_army_before_battle(army: Army) -> void:
	if army == null or not is_instance_valid(army):
		return
	while army.get_movement_points() > 0 and army.get_efficiency() < 100:
		var before_efficiency = army.get_efficiency()
		army.make_camp()
		_log_army_make_camp(army)
		if army.get_efficiency() <= before_efficiency:
			break

func _get_army_composition_suffix(army: Army) -> String:
	var comp = army.get_composition()
	if comp == null:
		return ""
	var mapping = [
		{"type": SoldierTypeEnum.Type.PEASANTS, "label": "P"},
		{"type": SoldierTypeEnum.Type.SPEARMEN, "label": "S"},
		{"type": SoldierTypeEnum.Type.ARCHERS, "label": "A"},
		{"type": SoldierTypeEnum.Type.SWORDSMEN, "label": "SW"},
		{"type": SoldierTypeEnum.Type.CROSSBOWMEN, "label": "C"},
		{"type": SoldierTypeEnum.Type.HORSEMEN, "label": "H"},
		{"type": SoldierTypeEnum.Type.KNIGHTS, "label": "K"},
		{"type": SoldierTypeEnum.Type.MOUNTED_KNIGHTS, "label": "M"},
		{"type": SoldierTypeEnum.Type.ROYAL_GUARD, "label": "R"}
	]
	var parts: Array[String] = []
	for entry in mapping:
		var count = comp.get_soldier_count(entry["type"])
		if count > 0:
			parts.append("%s:%d" % [entry["label"], count])
	if parts.size() == 0:
		return "none"
	var result = ""
	for i in range(parts.size()):
		result += parts[i]
		if i < parts.size() - 1:
			result += ", "
	return result

func _get_region_name_by_id(region_id: int) -> String:
	if region_id < 0:
		return "Unknown region"
	var region = region_manager.map_generator.get_region_container_by_id(region_id)
	if region:
		return region.get_region_name()
	return "Region %d" % region_id

func _join_strings(items: Array) -> String:
	if items.is_empty():
		return ""
	var result = ""
	for i in range(items.size()):
		result += String(items[i])
		if i < items.size() - 1:
			result += ", "
	return result

func _describe_trickle_reason(code: String) -> String:
	match code:
		"success":
			return "success"
		"no_food_surplus":
			return "no food surplus"
		"no_castles":
			return "no castles available"
		"no_recruitment_manager":
			return "recruitment unavailable"
		_:
			return code
