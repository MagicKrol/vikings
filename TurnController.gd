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
var trade_manager: TradeManager = null

# Debug step gate reference
var debug_step_gate: DebugStepGate

# Turn state
var current_player_id: int = -1
var moved_armies: Dictionary = {}  # Army -> bool
var _log_active_turn: bool = false
var _recruitment_status_cache: Dictionary = {}
var _turn_start_resources: Dictionary = {}
const AI_RESOURCE_TARGETS := {
	ResourcesEnum.Type.WOOD: 30,
	ResourcesEnum.Type.STONE: 30,
	ResourcesEnum.Type.IRON: 10
}

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
		trade_manager = game_manager.get_trade_manager()
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
	
	await _process_army_turns(player_id)
	if is_ai_player:
		_execute_ai_resource_top_up(player_id)
	if player_manager != null and player_manager.has_method("update_player_wealth_status"):
		player_manager.update_player_wealth_status(player_id)
	emit_signal("turn_finished", player_id)
	DebugLogger.log("AITurnManager", "[TurnController] Completed turn for Player " + str(player_id))
	_log_turn_outro(player_id)

func _process_army_turns(player_id: int) -> void:
	var armies := _get_available_armies(player_id)
	armies.shuffle()
	for army in armies:
		await _process_single_army(army)

func _execute_ai_resource_top_up(player_id: int) -> void:
	var player = player_manager.get_player(player_id)
	var deficits: Array[Dictionary] = []
	for resource_key in AI_RESOURCE_TARGETS.keys():
		var resource_type: ResourcesEnum.Type = resource_key
		var target_amount: int = int(AI_RESOURCE_TARGETS[resource_type])
		var current_amount: int = player.get_resource_amount(resource_type)
		var missing: int = max(0, target_amount - current_amount)
		if missing <= 0:
			continue
		var ratio: float = float(missing) / float(max(1, target_amount))
		deficits.append({
			"type": resource_type,
			"missing": missing,
			"ratio": ratio
		})
	if deficits.is_empty():
		return
	deficits.sort_custom(func(a, b): return a["ratio"] > b["ratio"])
	var gold_available: int = player.get_resource_amount(ResourcesEnum.Type.GOLD)
	var staged_net: Dictionary = {}
	var purchases: Array[Dictionary] = []
	for entry in deficits:
		if gold_available <= 0:
			break
		var resource_type: ResourcesEnum.Type = entry["type"]
		var missing: int = int(entry["missing"])
		var staged: int = int(staged_net.get(resource_type, 0))
		var estimated_cost: int = trade_manager.calculate_buy_cost(player_id, resource_type, staged, missing)
		var amount_to_buy: int = missing
		if estimated_cost > gold_available and estimated_cost > 0:
			amount_to_buy = int(floor(float(missing) * float(gold_available) / float(estimated_cost)))
		if amount_to_buy <= 0:
			continue
		var result: Dictionary = trade_manager.buy(player_id, resource_type, amount_to_buy)
		if not result.get("success", false):
			continue
		var gold_delta: int = int(result.get("gold_change", 0))
		gold_available += gold_delta
		staged_net[resource_type] = staged + amount_to_buy
		var updated_amount: int = player.get_resource_amount(resource_type)
		purchases.append({
			"type": resource_type,
			"amount": amount_to_buy,
			"gold_change": gold_delta,
			"new_total": updated_amount
		})
	_log_ai_resource_top_up_summary(purchases)

func _log_ai_resource_top_up_summary(purchases: Array[Dictionary]) -> void:
	if not _log_active_turn:
		return
	if purchases.is_empty():
		return
	var total_gold_change: int = 0
	var parts: Array[String] = []
	for entry in purchases:
		var r_type: ResourcesEnum.Type = entry["type"]
		var amount: int = int(entry.get("amount", 0))
		var gold_delta: int = int(entry.get("gold_change", 0))
		total_gold_change += gold_delta
		parts.append("%d %s" % [amount, ResourcesEnum.type_to_string(r_type)])
	var cost_abs := -total_gold_change
	var msg := "Bought: " + ", ".join(parts)
	if cost_abs != 0:
		msg += " for " + str(cost_abs) + " gold"
	DebugLogger.log("AIEconomy", msg)
	game_manager.ensure_ai_log_started()
	var ai_log = game_manager.get_ai_log_manager()
	ai_log.log_economy(msg)

func _get_available_armies(player_id: int) -> Array[Army]:
	"""Get armies that can still move this turn"""
	var available: Array[Army] = []
	var player_armies = army_manager.get_player_armies(player_id)
	
	for army in player_armies:
		if army == null or not is_instance_valid(army):
			continue
		if army.get_movement_points() <= 0:
			continue
		available.append(army)
	
	return available

func _process_single_army(army: Army) -> void:
	if not is_instance_valid(army):
		return
	var turn_number := _get_current_turn()
	_log_army_separator(army)
	while is_instance_valid(army) and army.get_movement_points() > 0:
		if await _handle_recruitment_cycle(army, turn_number):
			continue
		if await _handle_peasant_cycle(army, turn_number):
			continue
		_ensure_vigor_before_move(army)
		var move := _select_frontier_move(army)
		if move.is_empty():
			_log_movement_header()
			_log_army_detail_line("No valid targets; camping")
			_spend_all_on_camp(army)
			break
		if move.get("goal", "") == "halt":
			var defense_info: Dictionary = move.get("enemy_info", _build_enemy_info(move["target_id"], army.get_player_id()))
			_log_movement_header()
			_log_target_choice(army, move["target_id"], defense_info)
			_log_defense_todo(army, move["target_id"], defense_info)
			break
		var enemy_info: Dictionary = move.get("enemy_info", _build_enemy_info(move["target_id"], army.get_player_id()))
		_log_movement_header()
		_log_target_choice(army, move["target_id"], enemy_info)
		var merge_decision: String = move.get("merge_decision", _evaluate_merge_policy(army, enemy_info))
		if merge_decision == "halt":
			_log_defense_todo(army, move["target_id"], enemy_info)
			break
		if merge_decision == "merge":
			_merge_local_armies_into(army)
		var moved_ok = await _execute_move_to_target(army, move)
		if not moved_ok or not is_instance_valid(army):
			break
	if not is_instance_valid(army):
		return
	if army.get_movement_points() > 0:
		_log_army_detail_line("Spending remaining %d MP on camping" % army.get_movement_points())
		_spend_all_on_camp(army)

func _handle_recruitment_cycle(army: Army, turn_number: int) -> bool:
	if army.needs_recruitment(turn_number) and not army.is_recruitment_requested():
		army.request_recruitment()
	if not army.is_recruitment_requested():
		return false
	_log_recruitment_header()
	var current_region := army.get_parent() as Region
	var current_region_id: int = current_region.get_region_id()
	var best_castle := region_manager.find_best_recruitment_castle(current_region_id, army.get_player_id(), true, army)
	_log_recruitment_candidates(best_castle, current_region_id)
	var target_region_id := int(best_castle.get("best_region_id", -1))
	if target_region_id == -1:
		_log_recruitment_status_once(army, current_region_id, "no_recruit_castle")
		army.clear_recruitment_request()
		return false
	if current_region_id != target_region_id:
		_log_army_detail_line("Needs recruitment moving to " + _get_region_name_by_id(target_region_id))
		var moved = await _move_army_to_region(army, target_region_id, "reinforce", best_castle)
		return true
	_log_army_detail_line("Recruiting at " + _get_region_name_by_id(current_region_id))
	var assigned_budget := army.get_assigned_budget()
	if assigned_budget == null:
		_log_recruitment_status_once(army, current_region_id, "no_budget_assigned")
		_log_army_detail_line("Waiting for recruitment budget at " + _get_region_name_by_id(current_region_id))
		_spend_all_on_camp(army)
		return true
	var allow_recruit := army.get_movement_points() >= 1 or army.just_raised
	if not allow_recruit:
		_log_recruitment_skip(army, current_region_id, "no_movement_points")
		_spend_all_on_camp(army)
		return true
	var recruitment_manager = RecruitmentManager.new(region_manager, game_manager)
	var comp_before = _get_army_composition_suffix(army)
	var power_before = army.get_army_power()
	var result = recruitment_manager.hire_soldiers(army, true)
	if army.get_total_soldiers() > 0:
		army.just_raised = false
	if result.has("error"):
		_log_recruitment_skip(army, current_region_id, String(result.get("error", "unknown")))
	else:
		_log_recruitment_success(army, current_region_id, result, comp_before, power_before)
		_log_recruitment_detail(army, result, current_region.get_region_name())
	return true

func _handle_peasant_cycle(army: Army, turn_number: int) -> bool:
	var peasant_plan = _needs_recruitment_peasants(army, turn_number)
	if not peasant_plan.get("needed", false):
		return false
	_log_recruitment_header()
	var current_region := army.get_parent() as Region
	var current_region_id: int = current_region.get_region_id()
	var best_region_id = _find_best_owned_region_for_peasants(army, int(peasant_plan.get("ideal_needed", 0)))
	if best_region_id == -1:
		army.request_recruitment()
		_log_recruitment_status_once(army, current_region_id, "peasants_insufficient")
		return false
	if best_region_id != current_region_id:
		_log_army_detail_line("Need peasants recruitment moving to " + _get_region_name_by_id(best_region_id))
		var moved = await _move_army_to_region(army, best_region_id, "peasants", {})
		return true if moved else false
	var hired = _hire_peasants_at_region(army, current_region, peasant_plan.get("ideal_needed", 0))
	if hired > 0:
		_log_peasant_recruitment(army, current_region, hired)
		_log_army_detail_line("Hired " + str(hired) + " peasants in " + _get_region_name_by_id(current_region_id))
	return true

func _select_frontier_move(army: Army) -> Dictionary:
	var frontier := region_manager.get_frontier_regions(army.get_player_id())
	if frontier.is_empty():
		return {}
	var moves := _get_sorted_frontier_moves(army, frontier)
	if moves.is_empty():
		return {}
	var best_halt := {}
	for move in moves:
		var enemy_info := _build_enemy_info(move["target_id"], army.get_player_id())
		var decision := _evaluate_merge_policy(army, enemy_info)
		if decision == "halt":
			if best_halt.is_empty():
				best_halt = {
					"target_id": move["target_id"],
					"enemy_info": enemy_info
				}
			continue
		if not move.has("goal"):
			move["goal"] = "attack"
		move["enemy_info"] = enemy_info
		move["merge_decision"] = decision
		return move
	if not best_halt.is_empty():
		return {
			"goal": "halt",
			"target_id": best_halt.get("target_id", -1),
			"enemy_info": best_halt.get("enemy_info", {})
		}
	return {}

func _build_enemy_info(target_region_id: int, player_id: int) -> Dictionary:
	var target_region = region_manager.map_generator.get_region_container_by_id(target_region_id) as Region
	var enemy_owner = region_manager.get_region_owner(target_region_id)
	var castle_level = region_manager.get_castle_level(target_region_id)
	var garrison_power = 0
	if enemy_owner != -1 and enemy_owner != player_id and castle_level > 0:
		garrison_power = target_region.get_garrison_strength()
	var enemy_armies: Array = []
	var enemy_power = 0
	var known_strength = false
	var has_enemy = enemy_owner != -1 and enemy_owner != player_id
	for target_army in army_manager.get_armies_in_region(target_region):
		if target_army.get_player_id() == player_id:
			continue
		has_enemy = true
		var tracker_key := Player.get_enemy_tracker_key(target_army)
		var tracked_power := player_manager.get_tracked_enemy_power(player_id, tracker_key)
		if tracked_power < 0:
			continue
		enemy_armies.append(target_army)
		enemy_power += tracked_power
		known_strength = true
	var tracked_garrison := player_manager.get_tracked_enemy_garrison_power(player_id, target_region_id)
	if tracked_garrison >= 0:
		enemy_power += tracked_garrison
		known_strength = true
	else:
		enemy_power += garrison_power
	return {
		"has_enemy": has_enemy,
		"known": known_strength,
		"power": enemy_power,
		"armies": enemy_armies,
		"castle_level": castle_level,
		"owner": enemy_owner
	}

func _evaluate_merge_policy(army: Army, enemy_info: Dictionary) -> String:
	if not enemy_info.get("has_enemy", false):
		return "proceed"
	if not enemy_info.get("known", false):
		return "merge"
	var enemy_power: int = int(enemy_info.get("power", 0))
	if army.get_army_power() > enemy_power:
		return "proceed"
	var local_power = _get_local_armies_power(army)
	if local_power > enemy_power:
		return "merge"
	return "halt"

func _merge_local_armies_into(receiver: Army) -> void:
	var source_region = receiver.get_parent() as Region
	var armies_here = army_manager.get_armies_in_region(source_region)
	for donor in armies_here:
		if donor == receiver:
			continue
		if donor.get_parent() != source_region:
			continue
		var moved = army_manager.transfer_all_soldiers(donor, receiver)
		if moved:
			_log_army_transfer(donor, receiver)
			donor.spawn_minimal_peasant_token()

func _get_local_armies_power(army: Army) -> int:
	var source_region = army.get_parent() as Region
	var armies_here = army_manager.get_armies_in_region(source_region)
	var total = 0
	for a in armies_here:
		total += a.get_army_power()
	return total

func _ensure_vigor_before_move(army: Army) -> bool:
	var target_efficiency = 85
	if army.get_efficiency() >= target_efficiency:
		return true
	while army.get_efficiency() < target_efficiency and army.get_movement_points() > 0:
		army.make_camp()
		_log_army_make_camp(army)
	return army.get_movement_points() > 0

func _move_army_to_region(army: Army, target_region_id: int, goal: String, extra_log: Dictionary) -> bool:
	if not _ensure_vigor_before_move(army):
		return false
	var current_region := army.get_parent() as Region
	var current_region_id: int = current_region.get_region_id()
	var pf = pathfinder.find_path_to_target(current_region_id, target_region_id, army.get_player_id())
	if not pf["success"]:
		_spend_all_on_camp(army)
		return false
	var move := {
		"army": army,
		"target_id": target_region_id,
		"path": pf["path"],
		"mp_cost": pf["cost"],
		"final_score": 0.0,
		"goal": goal,
		"suppress_summary": true
	}
	if extra_log.has("candidates"):
		move["castle_log"] = _build_castle_log_lines(extra_log.get("candidates", []))
	_emit_move_prepared(army, target_region_id, move)
	emit_signal("move_started", army, target_region_id)
	_log_army_move_action(army, move)
	var army_log_token := game_manager.get_ai_battle_log_token(army)
	var result = await game_manager.ai_travel_to(army, target_region_id)
	var log_army: Army = army if is_instance_valid(army) else null
	_log_army_move_result(log_army, target_region_id, result, army_log_token)
	if result == "arrived" or result == "battle_victory":
		_log_move_status(army, target_region_id)
	if result == "battle_victory":
		emit_signal("region_conquered", target_region_id, army.get_player_id())
	if result == "blocked" or result == "out_of_movement_points":
		if is_instance_valid(army):
			_spend_all_on_camp(army)
	if not is_instance_valid(army):
		return false
	return army.get_movement_points() > 0

func _emit_move_prepared(army: Army, target_id: int, move: Dictionary) -> void:
	var score = float(move.get("final_score", 0.0))
	emit_signal("move_prepared", army, target_id, score)

func _execute_move_to_target(army: Army, move: Dictionary) -> bool:
	var target_id: int = move["target_id"]
	move["suppress_summary"] = true
	_emit_move_prepared(army, target_id, move)
	emit_signal("move_started", army, target_id)
	_log_army_move_action(army, move)
	var army_log_token := game_manager.get_ai_battle_log_token(army)
	var result = await game_manager.ai_travel_to(army, target_id)
	var log_army: Army = army if is_instance_valid(army) else null
	_log_army_move_result(log_army, target_id, result, army_log_token)
	if result == "arrived" or result == "battle_victory":
		_log_move_status(army, target_id)
	if result == "battle_victory":
		emit_signal("region_conquered", target_id, army.get_player_id())
	if result == "battle_defeat":
		return false
	if result == "blocked":
		if is_instance_valid(army):
			_spend_all_on_camp(army)
		return false
	if result == "out_of_movement_points":
		if is_instance_valid(army):
			_spend_all_on_camp(army)
		return false
	if not is_instance_valid(army):
		return false
	return army.get_movement_points() > 0

func _spend_all_on_camp(army: Army) -> void:
	while army.get_movement_points() > 0:
		army.make_camp()
		_log_army_make_camp(army)
func _find_best_move_for_army(army: Army, frontier: Array[int]) -> Dictionary:
	"""Find the best target for a specific army"""
	var best_move := {}
	var reachable: Array = []
	var far_targets: Array = []
	var player_id := army.get_player_id()
	var current_region := army.get_parent()
	if not current_region or not current_region.has_method("get_region_id"):
		return {}
	var current_region_id: int = current_region.get_region_id()

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var mp_available := army.get_movement_points()

	for target_id in frontier:
		if target_scorer != null and target_scorer.is_target_overmatched_by_known_enemy(army, target_id):
			continue
		var base_score := target_scorer.score_region_base(target_id)
		if base_score <= 0.0:
			continue

		var path_result := pathfinder.find_path_to_target(current_region_id, target_id, player_id)
		if not path_result["success"]:
			continue

		var cost := int(path_result["cost"])
		var can_reach_now := cost <= mp_available
		if not can_reach_now:
			continue
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
			"can_reach_now": can_reach_now
		}

		reachable.append(cand)

	if reachable.is_empty():
		return {}
		
	reachable.sort_custom(func(a, b): return a["final_score"] > b["final_score"])
	return reachable[0]

func _get_sorted_frontier_moves(army: Army, frontier: Array[int]) -> Array:
	var reachable: Array = []
	var far_targets: Array = []
	var player_id := army.get_player_id()
	var current_region := army.get_parent()
	if not current_region or not current_region.has_method("get_region_id"):
		return []
	var current_region_id: int = current_region.get_region_id()

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var mp_available := army.get_movement_points()

	for target_id in frontier:
		if target_scorer != null and target_scorer.is_target_overmatched_by_known_enemy(army, target_id):
			continue
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
			"can_reach_now": can_reach_now
		}

		if can_reach_now:
			reachable.append(cand)
		else:
			far_targets.append(cand)

	if not reachable.is_empty():
		reachable.sort_custom(func(a, b): return a["final_score"] > b["final_score"])
		return reachable
	if far_targets.is_empty():
		return []
	far_targets.sort_custom(func(a, b):
		if a["mp_cost"] == b["mp_cost"]:
			return a["final_score"] > b["final_score"]
		return a["mp_cost"] < b["mp_cost"]
	)
	return far_targets

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
	if army.needs_recruitment(turn_number):
		return {"needed": false}
	
	var player_id = army.get_player_id()
	var player = player_manager.get_player(player_id)
	var wealth_level = player.get_wealth_level()
	if wealth_level == GameParameters.WealthLevel.RICH:
		return {"needed": false}
	
	var min_ratio = GameParameters.get_ai_peasant_min_prop_for_wealth(wealth_level)
	
	var food_growth = player_manager.get_player_food_growth(player_id)
	if food_growth <= 0.0:
		return {"needed": false}
	
	var current_ratio = army.get_peasant_ratio()
	if current_ratio >= min_ratio:
		return {"needed": false}
	
	var army_power = army.get_army_power()
	var target_prop = 0.0
	if army_power < GameParameters.AI_PEA_POWER_LOW_MAX:
		target_prop = GameParameters.get_ai_peasant_target_prop_low_for_wealth(wealth_level)
	elif army_power >= GameParameters.AI_PEA_POWER_HIGH_MIN:
		target_prop = GameParameters.get_ai_peasant_target_prop_high_for_wealth(wealth_level)
	else:
		target_prop = GameParameters.get_ai_peasant_target_prop_mid_for_wealth(wealth_level)
	
	var ideal_needed = army.compute_peasant_need(target_prop)
	DebugLogger.log(
		"AIRecruitment",
			"Army " + army.get_display_name() + " peasant need: current=" + str(current_ratio) + ", target=" + str(target_prop) + ", need=" + str(ideal_needed)
	)
	
	return {
		"needed": true,
		"target_prop": target_prop,
		"ideal_needed": ideal_needed
	}

func _find_best_owned_region_for_peasants(army: Army, min_required: int) -> int:
	"""Find the best owned region for peasant recruitment (allows multi-turn travel)"""
	var player_id = army.get_player_id()
	var current_region = army.get_parent() as Region
	if not current_region:
		return -1
	
	var current_region_id = current_region.get_region_id()
	var owned_regions = region_manager.get_player_regions(player_id)
	var candidates = []
	var min_recruits = max(1, min_required)
	
	for region_id in owned_regions:
		var path_result = pathfinder.find_path_to_target(current_region_id, region_id, player_id)
		if not path_result["success"]:
			continue
		
		var cost = int(path_result["cost"])
		var region_container = region_manager.map_generator.get_region_container_by_id(region_id)
		var available_recruits = region_container.get_available_recruits()
		if available_recruits < min_recruits:
			continue
		
		var adjusted_distance = cost + 1
		var score = float(available_recruits) / float(adjusted_distance)
		candidates.append({
			"region_id": region_id,
			"available_recruits": available_recruits,
			"cost": cost,
			"score": score
		})
	
	if candidates.is_empty():
		return -1
	
	candidates.sort_custom(func(a, b):
		if a["score"] == b["score"]:
			return a["region_id"] < b["region_id"]
		return a["score"] > b["score"]
	)
	
	var best = candidates[0]
	DebugLogger.log(
		"AIRecruitment",
		"Best peasant region: " + str(best["region_id"]) + " score=" + str(best["score"]) + " recruits=" + str(best["available_recruits"]) + " cost=" + str(best["cost"])
	)

	return best["region_id"]

func _army_transfers_check(player_id: int) -> void:
	"""Merge armies sharing a border-front region before movement"""
	if army_manager == null or region_manager == null:
		return
	var current_turn = _get_current_turn()
	if current_turn <= 1:
		return
	var armies := army_manager.get_player_armies(player_id)
	if armies.size() < 2:
		return
	var grouped: Dictionary = {}
	for army in armies:
		if army == null or not is_instance_valid(army):
			continue
		if army.is_recruitment_requested():
			continue
		var region = army.get_parent()
		if not (region is Region):
			continue
		var region_id = (region as Region).get_region_id()
		if region_id == -1:
			continue
		if not grouped.has(region_id):
			grouped[region_id] = []
		grouped[region_id].append(army)
	for region_id in grouped.keys():
		var group: Array = grouped[region_id]
		if group.size() < 2:
			continue
		if not _region_borders_enemy(int(region_id), player_id):
			continue
		group.sort_custom(func(a, b): return _army_number_value(a) < _army_number_value(b))
		var receiver: Army = group[0]
		for i in range(1, group.size()):
			var donor: Army = group[i]
			if donor == null or not is_instance_valid(donor):
				continue
			var moved = army_manager.transfer_all_soldiers(donor, receiver)
			if moved:
				donor.spawn_minimal_peasant_token()

func _merge_attack_stack_if_needed(army: Army, target_region_id: int) -> void:
	if not _target_has_enemy_force(target_region_id, army.get_player_id()):
		return
	var source_region = army.get_parent() as Region
	var armies_here = army_manager.get_armies_in_region(source_region)
	if armies_here.size() < 2:
		return
	for donor in armies_here:
		if donor == army:
			continue
		var moved = army_manager.transfer_all_soldiers(donor, army)
		if moved:
			_log_army_transfer(donor, army)
			donor.spawn_minimal_peasant_token()

func _target_has_enemy_force(target_region_id: int, player_id: int) -> bool:
	var target_region = region_manager.map_generator.get_region_container_by_id(target_region_id)
	var armies_in_target = army_manager.get_armies_in_region(target_region)
	for target_army in armies_in_target:
		if target_army.get_player_id() != player_id:
			return true
	var target_owner = region_manager.get_region_owner(target_region_id)
	if target_owner == player_id or target_owner == -1:
		return false
	return region_manager.get_castle_level(target_region_id) > 0

func _region_borders_enemy(region_id: int, player_id: int) -> bool:
	var neighbors = region_manager.get_neighbor_regions(region_id)
	for neighbor_id in neighbors:
		var owner = region_manager.get_region_owner(neighbor_id)
		if owner != -1 and owner != player_id:
			return true
	return false

func _army_number_value(army: Army) -> int:
	if army == null:
		return INF
	var roman = army.number
	if roman == "":
		return army.get_instance_id()
	var value = _roman_to_int(roman)
	if value <= 0:
		return army.get_instance_id()
	return value

func _roman_to_int(roman: String) -> int:
	var mapping = {
		"I": 1,
		"V": 5,
		"X": 10,
		"L": 50,
		"C": 100,
		"D": 500,
		"M": 1000
	}
	var upper = roman.to_upper()
	var total = 0
	var i = 0
	while i < upper.length():
		var curr_char = upper[i]
		var curr = mapping.get(curr_char, 0)
		if curr == 0:
			i += 1
			continue
		var next = 0
		if i + 1 < upper.length():
			var next_char = upper[i + 1]
			next = mapping.get(next_char, 0)
		if curr < next:
			total += next - curr
			i += 2
		else:
			total += curr
			i += 1
	return total

func _build_reinforce_move_candidate(army: Army, current_region_id: int, include_origin: bool = false) -> Dictionary:
	var castle_pick := region_manager.find_best_recruitment_castle(current_region_id, army.get_player_id(), include_origin, army)
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
		var needs_recruitment_armies := int(entry.get("needs_recruitment_armies", 0))
		var score := float(entry.get("score", 0.0))
		lines.append("Castle %s - recruits:%d, distance:%d, level:%d, needs_recruitment_armies:%d, score: %.1f" % [name, recruits, distance, level, needs_recruitment_armies, score])
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
	if not move.get("suppress_summary", false):
		_log_army_summary(army, action, target_name)
	_log_army_move_path_preview(army, move)

func _log_army_make_camp(army: Army) -> void:
		_log_army_detail_line("%s makes camp [MP left: %d, Vigor: %d%%]" % [army.get_display_name(), army.get_movement_points(), army.get_efficiency()])

func _log_recruitment_detail(army: Army, result: Dictionary, region_name: String) -> void:
	if not _log_active_turn:
		return
	var hired: Dictionary = result.get("hired", {})
	if hired.is_empty():
		return
	var parts: Array[String] = []
	for soldier_type in hired.keys():
		var count = int(hired[soldier_type])
		if count <= 0:
			continue
		var label = SoldierTypeEnum.type_to_string(soldier_type)
		if label.length() > 0:
			label = label.substr(0, 1).to_upper()
		parts.append("%s:%d" % [label, count])
	if parts.is_empty():
		return
	var line = "Hired soldiers " + ", ".join(parts) + " in " + region_name
	_log_army_detail_line(line)

func _log_target_choice(army: Army, target_region_id: int, enemy_info: Dictionary) -> void:
	if not _log_active_turn:
		return
	var target_name = _get_region_name_by_id(target_region_id)
	var status = "no enemy"
	if enemy_info.get("has_enemy", false):
		var owner_id = int(enemy_info.get("owner", -1))
		var enemy_label = "Player " + str(owner_id)
		var detail := _build_known_enemy_detail(army.get_player_id(), target_region_id, enemy_info.get("known", false))
		status = enemy_label + " (" + detail + ")"
	_log_army_detail_line("Best target: " + target_name + " (" + status + ")")

func _build_known_enemy_detail(observer_id: int, region_id: int, known_flag: bool) -> String:
	var region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
	var known_parts: Array[String] = []
	var total_known: int = 0
	var unknown_armies: int = 0
	var enemy_armies = army_manager.get_armies_in_region(region)
	for enemy in enemy_armies:
		if enemy.get_player_id() == observer_id:
			continue
		var key := Player.get_enemy_tracker_key(enemy)
		var tracked: int = player_manager.get_tracked_enemy_power(observer_id, key)
		if tracked >= 0:
			var label := enemy.get_display_name()
			known_parts.append("%s:%d" % [label, tracked])
			total_known += tracked
		else:
			unknown_armies += 1
	var tracked_garrison: int = player_manager.get_tracked_enemy_garrison_power(observer_id, region_id)
	if tracked_garrison >= 0:
		known_parts.append("Garrison:%d" % tracked_garrison)
		total_known += tracked_garrison
	if unknown_armies > 0:
		known_parts.append("UnknownArmies:%d" % unknown_armies)
	var prefix := "known" if known_flag else "unknown"
	if not known_parts.is_empty():
		var joined := ", ".join(known_parts)
		return "%s - %s (total:%d)" % [prefix, joined, total_known]
	return prefix

func _log_defense_todo(army: Army, target_region_id: int, enemy_info: Dictionary) -> void:
	if not _log_active_turn:
		return
	var target_name = _get_region_name_by_id(target_region_id)
	var enemy_power = int(enemy_info.get("power", 0))
	_log_army_detail_line("Defense TODO for attack on " + target_name + " (enemy power " + str(enemy_power) + ")")

func _log_army_transfer(donor: Army, receiver: Army) -> void:
	_log_army_detail_line("Transfering units from %s to %s" % [donor.name, receiver.name])

func _log_army_move_path_preview(army: Army, move: Dictionary) -> void:
	var path: Array = move.get("path", [])
	if path.size() <= 1:
		return
	var preview_mp = army.get_movement_points()
	var preview_eff = army.get_efficiency()
	for i in range(1, path.size()):
		var step_name = _get_region_name_by_id(path[i])
		var target_region = region_manager.map_generator.get_region_container_by_id(path[i])
		var step_cost = army_manager.get_terrain_cost(target_region, army.get_player_id())
		if step_cost > preview_mp:
			_log_army_detail_line("Out of movement points before reaching %s" % step_name)
			break
		preview_mp = max(0, preview_mp - step_cost)
		preview_eff = max(0, preview_eff - 5)
		_log_army_detail_line("Moves to %s [MP left: %d, Vigor: %d%%]" % [step_name, preview_mp, preview_eff])

func _log_army_move_result(army: Army, target_region_id: int, result: String, army_log_token: String) -> void:
	var target_name = _get_region_name_by_id(target_region_id)
	match result:
		"battle_victory":
			_log_battle_header()
			_log_army_detail_line("Fight at %s" % target_name)
			_log_recent_battle_details(army, army_log_token)
		"battle_defeat":
			_log_battle_header()
			_log_army_detail_line("Fight at %s" % target_name)
			_log_recent_battle_details(army, army_log_token)
		"battle_withdrawal":
			_log_battle_header()
			_log_army_detail_line("Fight at %s" % target_name)
			if army != null and is_instance_valid(army):
				var current_region = army.get_parent() as Region
				if current_region and current_region.get_region_id() == target_region_id:
					pass
				elif current_region:
					_log_army_detail_line("Withdrew to " + current_region.get_region_name())
				else:
					_log_army_detail_line("Withdrew")
			else:
				_log_army_detail_line("Withdrew")
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
		var castle_pick := region_manager.find_best_recruitment_castle(region_id, army.get_player_id(), true, army)
		var castle_lines := _build_castle_log_lines(castle_pick.get("candidates", []))
		for line in castle_lines:
			_log_army_detail_line(line)
	var message = "Army %s recruited %d at %s (gold: %d, wood: %d, iron: %d)" % [
		army.get_display_name(),
		total_hired,
		location,
		spent_gold,
		spent_wood,
		spent_iron
	]
	game_manager.get_ai_log_manager().log_recruitment(message)
	_log_army_detail_line("%s [Power: %d - %s]" % [army.get_display_name(), army.get_army_power(), _get_army_composition_suffix(army)])

func _log_recruitment_skip(army: Army, region_id: int, reason: String) -> void:
	if not _log_active_turn:
		return
	if reason == "not_needed":
		return
	var location = _get_region_name_by_id(region_id)
	var message = "Army %s could not recruit at %s (reason: %s)" % [army.get_display_name(), location, reason]
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
	var message = "Army %s raised %d peasants at %s" % [army.get_display_name(), amount, region.get_region_name()]
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
	game_manager.get_ai_log_manager().log_army_action(army.get_display_name(), power_value, eff_value, action, target_region, comp)

func _log_army_detail_line(text: String) -> void:
	if not _log_active_turn or text == "":
		return
	game_manager.get_ai_log_manager().log_army_detail(text)

func _log_move_status(army: Army, target_region_id: int) -> void:
	if not _log_active_turn or army == null or not is_instance_valid(army):
		return
	var target_name = _get_region_name_by_id(target_region_id)
	_log_army_detail_line("Moving to %s [MP left: %d, Vigor: %d%%]" % [target_name, army.get_movement_points(), army.get_efficiency()])

func _log_army_separator(army: Army) -> void:
	if not _log_active_turn:
		return
	_log_army_detail_line("-------------- ARMY " + army.get_display_name() + " -------------")
	_log_army_detail_line("%s [Power: %d, E: %d - %s]" % [army.get_display_name(), army.get_army_power(), army.get_efficiency(), _get_army_composition_suffix(army)])

func _log_recruitment_header() -> void:
	if _log_active_turn:
		_log_army_detail_line("[RECRUITMENT]")

func _log_recruitment_candidates(best_castle: Dictionary, current_region_id: int) -> void:
	if not _log_active_turn:
		return
	var candidates: Array = best_castle.get("candidates", [])
	if candidates.is_empty():
		_log_army_detail_line("No recruit castles available from " + _get_region_name_by_id(current_region_id))
		return
	_log_army_detail_line("Recruitment castle candidates:")
	for cand in candidates:
		var name := String(cand.get("region_name", _get_region_name_by_id(int(cand.get("region_id", -1)))))
		var distance := int(cand.get("distance", 0))
		var recruits := int(cand.get("recruits", 0))
		var needs_recruitment_armies := int(cand.get("needs_recruitment_armies", 0))
		var score := float(cand.get("score", 0.0))
		_log_army_detail_line("- %s (dist:%d, recruits:%d, needs_recruitment_armies:%d, score: %.1f)" % [name, distance, recruits, needs_recruitment_armies, score])
	var pick_id := int(best_castle.get("best_region_id", -1))
	if pick_id != -1:
		_log_army_detail_line("Selected castle: " + _get_region_name_by_id(pick_id))

func _log_movement_header() -> void:
	if _log_active_turn:
		_log_army_detail_line("[MOVEMENT]")

func _log_battle_header() -> void:
	if _log_active_turn:
		_log_army_detail_line("[BATTLE]")

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
		"first_turn_skip":
			return "skipped (first turn)"
		"no_food_surplus":
			return "no food surplus"
		"no_castles":
			return "no castles available"
		"no_recruitment_manager":
			return "recruitment unavailable"
		_:
			return code
