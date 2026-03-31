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
var _castle_threat_level_snapshot_by_region: Dictionary = {}
var _castle_threat_registry_snapshot_by_region: Dictionary = {}
var _unknown_threat_defended_by_region: Dictionary = {}
var _threat_direct_block_by_army: Dictionary = {}
var _ai_mode_for_turn: int = 0
var _frontier_hard_regions: Array[int] = []
var _frontier_soft_regions: Array[int] = []
var _army_role_by_id: Dictionary = {}
var _main_army_ids: Dictionary = {}
var _latest_candidate_rejections: Array[Dictionary] = []
const AI_RESOURCE_TARGETS := {
	ResourcesEnum.Type.WOOD: 30,
	ResourcesEnum.Type.STONE: 30,
	ResourcesEnum.Type.IRON: 10
}
const AI_TARGET_CANDIDATE_LOG_LIMIT: int = 10
const AI_PATH_UNREACHABLE_COST: int = 999999
const AI_THREAT_RESPONSE_MIN_LEVEL: int = 2
const AI_RECRUITMENT_BREAKTHROUGH_MAX_EXPLORED_NODES: int = 120
const AI_RECRUITMENT_BREAKTHROUGH_MAX_NON_FRIENDLY_REGIONS: int = 3
const AI_RECRUITMENT_HALF_THRESHOLD_RATIO: float = 0.5

enum AIMode {
	EXPANSION,
	WAR
}

enum ArmyRole {
	MAIN,
	RAIDER,
	SUPPORT
}

enum FrontierBucketType {
	HARD,
	SOFT
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
	if game_manager.has_victory_been_declared():
		return
	current_player_id = player_id
	moved_armies.clear()
	_castle_threat_level_snapshot_by_region.clear()
	_castle_threat_registry_snapshot_by_region.clear()
	_unknown_threat_defended_by_region.clear()
	_threat_direct_block_by_army.clear()
	_frontier_hard_regions.clear()
	_frontier_soft_regions.clear()
	_army_role_by_id.clear()
	_main_army_ids.clear()
	_ai_mode_for_turn = AIMode.EXPANSION

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
	var pre_move_econ_result: Dictionary = econ.run_pre_move_economy_with_reserve_lock(player_id, turn_number)
	var threat_snapshot: Dictionary = econ.get_castle_threat_snapshot(player_id)
	_castle_threat_level_snapshot_by_region = threat_snapshot.get("threat_levels_by_region", {})
	_castle_threat_registry_snapshot_by_region = threat_snapshot.get("threat_registry_by_region", {})
	_assign_ai_mode_and_roles(player_id)
	_log_turn_intro(player_id, turn_number, pre_move_econ_result)
	_log_economy_plan(pre_move_econ_result)
	var army_recruitment: Dictionary = pre_move_econ_result.get("army_recruitment", {})
	var assigned_count = int(army_recruitment.get("budgets_assigned", 0))
	var raise_result = pre_move_econ_result.get("raise", {"raised": false})
	DebugLogger.log("AITurnManager", "[TurnController] EconomyAIManager assigned recruitment budgets to " + str(assigned_count) + " armies at castles")
	if raise_result.get("raised", false):
		DebugLogger.log("AITurnManager", "[TurnController] EconomyAIManager raised new army at region " + str(raise_result.get("region_id", -1)))
	
	emit_signal("turn_started", player_id)
	DebugLogger.log("AITurnManager", "[TurnController] Starting turn for Player " + str(player_id))
	
	await _process_army_turns(player_id)
	var post_move_econ_result: Dictionary = econ.run_post_move_castle_recruitment(player_id, turn_number)
	_log_post_move_castle_recruitment(post_move_econ_result)
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
		if game_manager.has_victory_been_declared():
			return
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

func _assign_ai_mode_and_roles(player_id: int) -> void:
	_army_role_by_id.clear()
	_main_army_ids.clear()

	_refresh_frontier_buckets_for_player(player_id)

	var all_armies: Array[Army] = army_manager.get_player_armies(player_id)
	if all_armies.is_empty():
		return
	if _ai_mode_for_turn == AIMode.EXPANSION:
		for army in all_armies:
			_set_army_role_for_turn(army, ArmyRole.RAIDER)
		return

	var sorted_desc: Array[Army] = all_armies.duplicate()
	sorted_desc.sort_custom(func(a: Army, b: Army) -> bool:
		var a_power: int = a.get_army_power()
		var b_power: int = b.get_army_power()
		if a_power != b_power:
			return a_power > b_power
		var a_region_id: int = _get_army_region_id_for_role_sort(a)
		var b_region_id: int = _get_army_region_id_for_role_sort(b)
		if a_region_id != b_region_id:
			return a_region_id < b_region_id
		return a.get_instance_id() < b.get_instance_id()
	)

	var main_slots: int = _calculate_main_slots(_frontier_hard_regions.size(), sorted_desc.size())
	main_slots = mini(main_slots, sorted_desc.size())
	var frontier_total_count: int = _frontier_hard_regions.size() + _frontier_soft_regions.size()
	var raider_slots: int = _calculate_raider_slots(frontier_total_count, sorted_desc.size(), main_slots)

	var unassigned: Array[Army] = []
	for i in range(sorted_desc.size()):
		var army: Army = sorted_desc[i]
		if i < main_slots:
			_set_army_role_for_turn(army, ArmyRole.MAIN)
			continue
		unassigned.append(army)

	unassigned.sort_custom(func(a: Army, b: Army) -> bool:
		var a_power: int = a.get_army_power()
		var b_power: int = b.get_army_power()
		if a_power != b_power:
			return a_power < b_power
		var a_region_id: int = _get_army_region_id_for_role_sort(a)
		var b_region_id: int = _get_army_region_id_for_role_sort(b)
		if a_region_id != b_region_id:
			return a_region_id < b_region_id
		return a.get_instance_id() < b.get_instance_id()
	)

	for i in range(unassigned.size()):
		var army: Army = unassigned[i]
		if i < raider_slots:
			_set_army_role_for_turn(army, ArmyRole.RAIDER)
		else:
			_set_army_role_for_turn(army, ArmyRole.SUPPORT)

func _refresh_frontier_buckets_for_player(player_id: int) -> void:
	_frontier_hard_regions.clear()
	_frontier_soft_regions.clear()
	var has_enemy_frontier: bool = false
	var frontier_regions: Array[int] = region_manager.get_frontier_regions(player_id)
	for region_id in frontier_regions:
		var owner_id: int = region_manager.get_region_owner(region_id)
		if owner_id == player_id:
			continue
		if owner_id != -1:
			has_enemy_frontier = true
		var has_castle: bool = region_manager.get_castle_level(region_id) > 0
		var has_enemy_army: bool = _frontier_region_has_enemy_army(region_id, player_id)
		if has_castle or has_enemy_army:
			_frontier_hard_regions.append(region_id)
		else:
			_frontier_soft_regions.append(region_id)
	_frontier_hard_regions.sort()
	_frontier_soft_regions.sort()
	_ai_mode_for_turn = AIMode.WAR if has_enemy_frontier else AIMode.EXPANSION

func _frontier_region_has_enemy_army(region_id: int, player_id: int) -> bool:
	var region: Region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
	var armies_in_region: Array[Army] = army_manager.get_armies_in_region(region)
	for region_army in armies_in_region:
		if region_army.get_player_id() != player_id:
			return true
	return false

func _calculate_main_slots(hard_target_count: int, army_count: int) -> int:
	var main_slots: int = 0
	if hard_target_count > 0:
		main_slots = 1
	if hard_target_count >= 3 and army_count >= 4:
		main_slots = 2
	if hard_target_count >= 5 and army_count >= 7:
		main_slots = 3
	if hard_target_count >= 7 and army_count >= 10:
		main_slots = 4
	return main_slots

func _calculate_raider_slots(frontier_total_count: int, army_count: int, main_slots: int) -> int:
	var remaining_after_main: int = maxi(0, army_count - main_slots)
	if remaining_after_main <= 0:
		return 0
	if main_slots <= 0:
		return remaining_after_main
	if frontier_total_count <= 0:
		return 0
	var raider_cap: int = int(ceil(float(frontier_total_count) / 4.0))
	raider_cap = maxi(0, raider_cap)
	return mini(remaining_after_main, raider_cap)

func _get_army_region_id_for_role_sort(army: Army) -> int:
	var region: Region = army.get_parent() as Region
	return region.get_region_id()

func _set_army_role_for_turn(army: Army, role: int) -> void:
	var army_id: int = army.get_instance_id()
	_army_role_by_id[army_id] = role
	if role == ArmyRole.MAIN:
		_main_army_ids[army_id] = true

func _get_army_role_for_turn(army: Army) -> int:
	var army_id: int = army.get_instance_id()
	if _army_role_by_id.has(army_id):
		return int(_army_role_by_id.get(army_id, ArmyRole.SUPPORT))
	return ArmyRole.SUPPORT

func _handle_role_behavior_cycle(army: Army, turn_number: int) -> bool:
	_refresh_frontier_buckets_for_player(army.get_player_id())
	var role: int = _get_army_role_for_turn(army)
	var mode_label: String = _get_ai_mode_label(_ai_mode_for_turn)
	var role_label: String = _get_army_role_label(role)
	_log_decision_tree_branch(army, "mode_" + mode_label + "_role_" + role_label, "post_threat")
	match role:
		ArmyRole.MAIN:
			return await _handle_main_role_cycle(army)
		ArmyRole.RAIDER:
			return await _handle_raider_role_cycle(army, turn_number)
		_:
			return await _handle_support_role_cycle(army, turn_number)

func _handle_main_role_cycle(army: Army) -> bool:
	if not _ensure_vigor_before_move(army):
		return true
	if await _try_execute_frontier_role_bucket(army, _frontier_hard_regions, FrontierBucketType.HARD, "role_main_attack", "hard_targets", true):
		return true
	if await _try_execute_frontier_role_bucket(army, _frontier_soft_regions, FrontierBucketType.SOFT, "role_main_attack", "soft_targets"):
		return true
	_log_decision_tree_branch(army, "role_main_camp", "no_reachable_targets")
	_spend_all_on_camp(army)
	return true

func _handle_raider_role_cycle(army: Army, turn_number: int) -> bool:
	if not _ensure_vigor_before_move(army):
		return true
	var raider_move: Dictionary = _select_raider_scored_move(army)
	if not raider_move.is_empty():
		var branch: String = String(raider_move.get("raider_branch", "role_raider_expand"))
		var reason: String = String(raider_move.get("raider_reason", "scored_target"))
		_log_decision_tree_branch(army, branch, reason)
		return await _execute_frontier_move_choice(army, raider_move)
	if _main_army_ids.is_empty():
		_log_decision_tree_branch(army, "role_raider_camp", "no_raid_target_no_main")
		_spend_all_on_camp(army)
		return true
	_log_decision_tree_branch(army, "role_raider_to_support", "no_raid_target")
	return await _handle_support_role_cycle(army, turn_number)

func _handle_support_role_cycle(army: Army, turn_number: int) -> bool:
	var current_region: Region = army.get_parent() as Region
	var current_region_id: int = current_region.get_region_id()
	var merge_target: Dictionary = _select_support_main_merge_target(army, current_region_id)
	if not merge_target.is_empty():
		var main_army: Army = merge_target.get("army", null) as Army
		var main_region_id: int = int(merge_target.get("region_id", -1))
		if main_region_id == current_region_id:
			var local_transferred: bool = army_manager.transfer_all_soldiers(army, main_army)
			if local_transferred:
				_log_decision_tree_branch(army, "role_support_merge_main", "local_transfer")
				_log_army_transfer(army, main_army)
				army.spawn_minimal_peasant_token()
				army.request_recruitment()
			return true
		_log_decision_tree_branch(army, "role_support_merge_main", "to " + _get_region_name_by_id(main_region_id))
		await _move_army_to_region(army, main_region_id, "support_merge", {})
		if is_instance_valid(army) and is_instance_valid(main_army):
			var army_region: Region = army.get_parent() as Region
			var support_region: Region = main_army.get_parent() as Region
			if army_region.get_region_id() == support_region.get_region_id():
				var transferred: bool = army_manager.transfer_all_soldiers(army, main_army)
				if transferred:
					_log_army_transfer(army, main_army)
					army.spawn_minimal_peasant_token()
					army.request_recruitment()
		return true

	if not army.is_recruitment_requested():
		army.request_recruitment()
	var recruitment_handled: bool = await _handle_recruitment_cycle(army, turn_number)
	if recruitment_handled:
		_log_decision_tree_branch(army, "role_support_recruit", "recruitment_fallback")
		return true
	_log_decision_tree_branch(army, "role_support_camp", "no_merge_no_recruit")
	_spend_all_on_camp(army)
	return true

func _try_execute_frontier_role_bucket(army: Army, frontier_targets: Array[int], bucket_type: int, branch: String, reason: String, require_reachable_this_turn: bool = false) -> bool:
	if frontier_targets.is_empty():
		return false
	var current_region: Region = army.get_parent() as Region
	var current_region_id: int = current_region.get_region_id()
	var live_targets: Array[int] = _get_live_frontier_targets_for_bucket(army.get_player_id(), frontier_targets, bucket_type, current_region_id)
	if live_targets.is_empty():
		return false
	var move: Dictionary = {}
	if require_reachable_this_turn:
		move = _select_frontier_reachable_move_for_targets(army, live_targets)
	else:
		move = _select_frontier_move_for_targets(army, live_targets)
	if move.is_empty():
		return false
	_log_decision_tree_branch(army, branch, reason)
	return await _execute_frontier_move_choice(army, move)

func _select_frontier_reachable_move_for_targets(army: Army, targets: Array[int]) -> Dictionary:
	if targets.is_empty():
		return {}
	var moves: Array = _get_sorted_frontier_moves(army, targets)
	if moves.is_empty():
		_log_rejected_candidates(_copy_latest_candidate_rejections())
		return {}
	_log_target_candidates(moves)
	var rejected_candidates: Array[Dictionary] = _copy_latest_candidate_rejections()
	var best_halt: Dictionary = {}
	for move_variant in moves:
		var move: Dictionary = move_variant as Dictionary
		if not bool(move.get("can_reach_now", false)):
			_append_rejected_candidate(
				rejected_candidates,
				int(move.get("target_id", -1)),
				"unreachable_this_turn",
				float(move.get("final_score", 0.0)),
				true
			)
			continue
		var target_region_id: int = int(move.get("target_id", -1))
		if target_region_id < 0:
			continue
		var enemy_info: Dictionary = _build_enemy_info(target_region_id, army.get_player_id(), army)
		var decision: String = _evaluate_merge_policy(army, enemy_info)
		if decision == "halt":
			if best_halt.is_empty():
				best_halt = {
					"target_id": target_region_id,
					"enemy_info": enemy_info
				}
			_append_rejected_candidate(
				rejected_candidates,
				target_region_id,
				"merge_policy_halt",
				float(move.get("final_score", 0.0)),
				true
			)
			continue
		if not move.has("goal"):
			move["goal"] = "attack"
		move["enemy_info"] = enemy_info
		move["merge_decision"] = decision
		_log_rejected_candidates(rejected_candidates)
		return move
	if not best_halt.is_empty():
		_log_rejected_candidates(rejected_candidates)
		return {
			"goal": "halt",
			"target_id": int(best_halt.get("target_id", -1)),
			"enemy_info": best_halt.get("enemy_info", {})
		}
	_log_rejected_candidates(rejected_candidates)
	return {}

func _get_live_frontier_targets_for_bucket(player_id: int, frontier_targets: Array[int], bucket_type: int, current_region_id: int) -> Array[int]:
	var result: Array[int] = []
	for target_region_id in frontier_targets:
		if target_region_id == current_region_id:
			continue
		var owner_id: int = region_manager.get_region_owner(target_region_id)
		var has_castle: bool = region_manager.get_castle_level(target_region_id) > 0
		var has_enemy_army: bool = _frontier_region_has_enemy_army(target_region_id, player_id)
		match bucket_type:
			FrontierBucketType.HARD:
				if owner_id == -1 or owner_id == player_id:
					continue
				if not has_castle and not has_enemy_army:
					continue
			FrontierBucketType.SOFT:
				if owner_id == player_id:
					continue
				if has_castle or has_enemy_army:
					continue
			_:
				continue
		result.append(target_region_id)
	return result

func _execute_frontier_move_choice(army: Army, move: Dictionary) -> bool:
	if move.is_empty():
		return false
	if move.get("goal", "") == "halt":
		var defense_info: Dictionary = move.get("enemy_info", _build_enemy_info(move["target_id"], army.get_player_id(), army))
		_log_movement_header()
		_log_target_choice(army, move["target_id"], defense_info)
		_log_defense_todo(army, move["target_id"], defense_info)
		_spend_all_on_camp(army)
		return true
	var enemy_info: Dictionary = move.get("enemy_info", _build_enemy_info(move["target_id"], army.get_player_id(), army))
	_log_movement_header()
	_log_target_choice(army, move["target_id"], enemy_info)
	var merge_decision: String = move.get("merge_decision", _evaluate_merge_policy(army, enemy_info))
	if merge_decision == "halt":
		_log_defense_todo(army, move["target_id"], enemy_info)
		_spend_all_on_camp(army)
		return true
	if merge_decision == "merge":
		_merge_local_armies_into(army)
	await _execute_move_to_target(army, move)
	return true

func _select_raider_scored_move(army: Army) -> Dictionary:
	var current_region: Region = army.get_parent() as Region
	var current_region_id: int = current_region.get_region_id()
	var player_id: int = army.get_player_id()
	var soft_targets: Array[int] = _get_live_frontier_targets_for_bucket(player_id, _frontier_soft_regions, FrontierBucketType.SOFT, current_region_id)
	var hard_targets: Array[int] = _get_live_frontier_targets_for_bucket(player_id, _frontier_hard_regions, FrontierBucketType.HARD, current_region_id)
	var merged_targets: Array[int] = []
	for target_id in soft_targets:
		if not merged_targets.has(target_id):
			merged_targets.append(target_id)
	for target_id in hard_targets:
		if not merged_targets.has(target_id):
			merged_targets.append(target_id)
	if merged_targets.is_empty():
		return {}
	var moves: Array = _get_sorted_frontier_moves(army, merged_targets)
	if moves.is_empty():
		_log_rejected_candidates(_copy_latest_candidate_rejections())
		return {}
	_log_target_candidates(moves)
	var rejected_candidates: Array[Dictionary] = _copy_latest_candidate_rejections()
	for move_variant in moves:
		var move: Dictionary = move_variant as Dictionary
		var target_region_id: int = int(move.get("target_id", -1))
		if target_region_id < 0:
			continue
		var enemy_info: Dictionary = _build_enemy_info(target_region_id, player_id, army)
		var target_has_enemy_army: bool = _frontier_region_has_enemy_army(target_region_id, player_id)
		var target_has_castle: bool = int(enemy_info.get("castle_level", 0)) > 0
		var is_hard_target: bool = target_has_enemy_army or target_has_castle
		var raider_branch: String = "role_raider_expand"
		if is_hard_target:
			if not bool(enemy_info.get("known", false)):
				_append_rejected_candidate(
					rejected_candidates,
					target_region_id,
					"raider_unknown_hard_target",
					float(move.get("final_score", 0.0)),
					true
				)
				continue
			var enemy_power: int = int(enemy_info.get("power", 0))
			if enemy_power <= 0:
				enemy_power = 1
			var army_power: int = army.get_army_power()
			if target_has_castle:
				if float(army_power) < float(enemy_power) * 2.0:
					_append_rejected_candidate(
						rejected_candidates,
						target_region_id,
						"raider_castle_threshold",
						float(move.get("final_score", 0.0)),
						true
					)
					continue
				raider_branch = "role_raider_hard_known_castle"
			else:
				if float(army_power) < float(enemy_power) * 1.2:
					_append_rejected_candidate(
						rejected_candidates,
						target_region_id,
						"raider_army_threshold",
						float(move.get("final_score", 0.0)),
						true
					)
					continue
				raider_branch = "role_raider_hard_known_army"
		var merge_decision: String = _evaluate_merge_policy(army, enemy_info)
		if merge_decision == "halt":
			_append_rejected_candidate(
				rejected_candidates,
				target_region_id,
				"merge_policy_halt",
				float(move.get("final_score", 0.0)),
				true
			)
			continue
		move["goal"] = "attack"
		move["enemy_info"] = enemy_info
		move["merge_decision"] = merge_decision
		move["raider_branch"] = raider_branch
		move["raider_reason"] = "to " + _get_region_name_by_id(target_region_id)
		_log_rejected_candidates(rejected_candidates)
		return move
	_log_rejected_candidates(rejected_candidates)
	return {}

func _select_support_main_merge_target(army: Army, current_region_id: int) -> Dictionary:
	if _main_army_ids.is_empty():
		return {}
	var candidates: Array[Dictionary] = []
	for main_army_id_key in _main_army_ids.keys():
		var main_army_id: int = int(main_army_id_key)
		var main_army: Army = _resolve_army_by_instance_id(main_army_id)
		if not is_instance_valid(main_army):
			continue
		if main_army == army:
			continue
		var main_region: Region = main_army.get_parent() as Region
		var main_region_id: int = main_region.get_region_id()
		var path_info: Dictionary = _get_path_info_for_player(army.get_player_id(), current_region_id, main_region_id, true, army.get_movement_points())
		if not bool(path_info.get("can_reach_this_turn", false)):
			continue
		var path_cost: int = int(path_info.get("cost", AI_PATH_UNREACHABLE_COST))
		candidates.append({
			"army": main_army,
			"region_id": main_region_id,
			"path_cost": path_cost,
			"army_id": main_army.get_instance_id()
		})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_cost: int = int(a.get("path_cost", AI_PATH_UNREACHABLE_COST))
		var b_cost: int = int(b.get("path_cost", AI_PATH_UNREACHABLE_COST))
		if a_cost != b_cost:
			return a_cost < b_cost
		var a_region_id: int = int(a.get("region_id", -1))
		var b_region_id: int = int(b.get("region_id", -1))
		if a_region_id != b_region_id:
			return a_region_id < b_region_id
		return int(a.get("army_id", 0)) < int(b.get("army_id", 0))
	)
	return candidates[0]

func _resolve_army_by_instance_id(instance_id: int) -> Army:
	if instance_id <= 0:
		return null
	var all_armies: Array[Army] = army_manager.get_all_armies()
	for tracked_army in all_armies:
		if tracked_army.get_instance_id() == instance_id:
			return tracked_army
	return null

func _get_ai_mode_label(mode: int) -> String:
	match mode:
		AIMode.WAR:
			return "war"
		_:
			return "expansion"

func _get_army_role_label(role: int) -> String:
	match role:
		ArmyRole.MAIN:
			return "main"
		ArmyRole.RAIDER:
			return "raider"
		_:
			return "support"

func _get_army_role_display_label(role: int) -> String:
	match role:
		ArmyRole.MAIN:
			return "Main"
		ArmyRole.RAIDER:
			return "Raider"
		_:
			return "Support"

func _get_army_number_for_log(army: Army) -> String:
	var army_number: String = army.number.strip_edges()
	if army_number != "":
		return army_number
	var display_name: String = army.get_display_name().strip_edges()
	if display_name.begins_with("Army "):
		return display_name.substr(5, display_name.length() - 5)
	return display_name

func _process_single_army(army: Army) -> void:
	if not is_instance_valid(army):
		return
	var turn_number: int = _get_current_turn()
	_log_army_separator(army)
	while is_instance_valid(army) and army.get_movement_points() > 0:
		if game_manager.has_victory_been_declared():
			return
		if await _handle_recruitment_cycle(army, turn_number):
			continue
		if await _handle_peasant_cycle(army, turn_number):
			continue
		if await _handle_threatened_castle_cycle(army):
			continue
		if await _handle_role_behavior_cycle(army, turn_number):
			continue
		_log_decision_tree_branch(army, "frontier_scoring_fallback", "role_no_action")
		_log_movement_header()
		_log_army_detail_line("No valid role action; camping")
		_spend_all_on_camp(army)
		if not is_instance_valid(army):
			break
	if not is_instance_valid(army):
		return
	if army.get_movement_points() > 0:
		_log_army_detail_line("Spending remaining %d MP on camping" % army.get_movement_points())
		_spend_all_on_camp(army)

func _handle_recruitment_cycle(army: Army, turn_number: int) -> bool:
	if army.needs_recruitment(turn_number) and not army.is_recruitment_requested():
		army.request_recruitment()
	if army.is_recruitment_requested() and not army.needs_recruitment(turn_number):
		army.clear_recruitment_request()
		_set_recruitment_move_state(army, Army.RecruitmentMoveState.NORMAL, "not_needed")
		return false
	if not army.is_recruitment_requested():
		return false
	_log_recruitment_header()
	match army.get_recruitment_move_state():
		Army.RecruitmentMoveState.TRANSFER_TO_CLOSEST:
			return await _handle_recruitment_transfer_to_closest_state(army)
		Army.RecruitmentMoveState.RECRUIT_OR_DEFEND:
			return await _handle_recruitment_recruit_or_defend_state(army, turn_number)
		_:
			return await _handle_recruitment_normal_state(army, turn_number)

func _handle_recruitment_normal_state(army: Army, turn_number: int) -> bool:
	var current_region: Region = army.get_parent() as Region
	var current_region_id: int = current_region.get_region_id()
	var best_castle: Dictionary = _find_best_recruitment_castle_pick(army, current_region_id)
	_log_recruitment_candidates(best_castle, current_region_id)
	var target_region_id: int = int(best_castle.get("best_region_id", -1))
	if target_region_id == -1:
		var breakthrough_castle: Dictionary = _find_best_recruitment_castle_pick(army, current_region_id, false)
		_log_recruitment_candidates(breakthrough_castle, current_region_id)
		var breakthrough_castle_id: int = int(breakthrough_castle.get("best_region_id", -1))
		if breakthrough_castle_id == -1:
			_log_recruitment_status_once(army, current_region_id, "no_recruit_castle")
			_log_decision_tree_branch(army, "recruit_mark_transfer_no_clean_path", "no_recruit_castle")
			_set_recruitment_move_state(army, Army.RecruitmentMoveState.TRANSFER_TO_CLOSEST, "no_recruit_castle")
			return await _handle_recruitment_transfer_to_closest_state(army)
		if _is_army_below_half_recruitment_threshold(army, turn_number):
			_log_decision_tree_branch(army, "recruit_mark_transfer_half_power", "below_half_threshold")
			_set_recruitment_move_state(army, Army.RecruitmentMoveState.TRANSFER_TO_CLOSEST, "below_half_threshold")
			return await _handle_recruitment_transfer_to_closest_state(army)
		var breakthrough_path: Array[int] = _find_clean_breakthrough_path_to_recruit_castle(army, current_region_id, breakthrough_castle_id)
		if breakthrough_path.is_empty():
			_log_decision_tree_branch(army, "recruit_mark_transfer_no_clean_path", "no_clean_path")
			_set_recruitment_move_state(army, Army.RecruitmentMoveState.TRANSFER_TO_CLOSEST, "no_clean_path")
			return await _handle_recruitment_transfer_to_closest_state(army)
		var breakthrough_target_id: int = _get_first_breakthrough_step_on_path(breakthrough_path, army.get_player_id())
		var breakthrough_goal: String = "attack"
		if breakthrough_target_id == -1:
			breakthrough_target_id = breakthrough_castle_id
			breakthrough_goal = "reinforce"
		_log_decision_tree_branch(army, "recruit_breakthrough_attack", "to " + _get_region_name_by_id(breakthrough_target_id))
		await _move_army_to_region_with_result(army, breakthrough_target_id, breakthrough_goal, {})
		return true
	if current_region_id == target_region_id:
		return _execute_recruitment_at_current_region(army, current_region)
	if _can_reach_region_this_turn(army, current_region_id, target_region_id, true):
		_log_army_detail_line("Needs recruitment moving to " + _get_region_name_by_id(target_region_id))
		await _move_army_to_region(army, target_region_id, "reinforce", best_castle)
		return true
	var rechecked_castle: Dictionary = _find_best_recruitment_castle_pick(army, current_region_id)
	var rechecked_target_region_id: int = int(rechecked_castle.get("best_region_id", -1))
	_log_recruitment_candidates(rechecked_castle, current_region_id)
	if rechecked_target_region_id == -1:
		_log_decision_tree_branch(army, "recruit_mark_transfer_no_clean_path", "no_recheck_castle")
		_set_recruitment_move_state(army, Army.RecruitmentMoveState.TRANSFER_TO_CLOSEST, "no_recheck_castle")
		return await _handle_recruitment_transfer_to_closest_state(army)
	if _can_reach_region_this_turn(army, current_region_id, rechecked_target_region_id, true):
		_log_army_detail_line("Needs recruitment moving to " + _get_region_name_by_id(rechecked_target_region_id))
		await _move_army_to_region(army, rechecked_target_region_id, "reinforce", rechecked_castle)
		return true
	if _is_army_below_half_recruitment_threshold(army, turn_number):
		_log_decision_tree_branch(army, "recruit_mark_transfer_half_power", "below_half_threshold")
		_set_recruitment_move_state(army, Army.RecruitmentMoveState.TRANSFER_TO_CLOSEST, "below_half_threshold")
		return await _handle_recruitment_transfer_to_closest_state(army)
	var clean_path: Array[int] = _find_clean_breakthrough_path_to_recruit_castle(army, current_region_id, rechecked_target_region_id)
	if clean_path.is_empty():
		_log_decision_tree_branch(army, "recruit_mark_transfer_no_clean_path", "no_clean_path")
		_set_recruitment_move_state(army, Army.RecruitmentMoveState.TRANSFER_TO_CLOSEST, "no_clean_path")
		return await _handle_recruitment_transfer_to_closest_state(army)
	var breakthrough_target_id: int = _get_first_breakthrough_step_on_path(clean_path, army.get_player_id())
	var breakthrough_goal: String = "attack"
	if breakthrough_target_id == -1:
		breakthrough_target_id = rechecked_target_region_id
		breakthrough_goal = "reinforce"
	_log_decision_tree_branch(army, "recruit_breakthrough_attack", "to " + _get_region_name_by_id(breakthrough_target_id))
	await _move_army_to_region_with_result(army, breakthrough_target_id, breakthrough_goal, {})
	return true

func _handle_recruitment_transfer_to_closest_state(army: Army) -> bool:
	var current_region: Region = army.get_parent() as Region
	var current_region_id: int = current_region.get_region_id()
	var best_castle: Dictionary = _find_best_recruitment_castle_pick(army, current_region_id)
	_log_recruitment_candidates(best_castle, current_region_id)
	var target_region_id: int = int(best_castle.get("best_region_id", -1))
	if target_region_id != -1:
		if target_region_id == current_region_id:
			return _execute_recruitment_at_current_region(army, current_region)
		if _can_reach_region_this_turn(army, current_region_id, target_region_id, true):
			_log_army_detail_line("Transfer state moving to " + _get_region_name_by_id(target_region_id))
			await _move_army_to_region(army, target_region_id, "reinforce", best_castle)
			return true
	var transfer_target: Dictionary = _select_transfer_target_from_nearby(army, current_region_id)
	if transfer_target.is_empty():
		_log_decision_tree_branch(army, "recruit_or_defend_camp", "transfer_no_friendly_target")
		_spend_all_on_camp(army)
		return true
	var friendly_army: Army = transfer_target.get("army", null) as Army
	var friendly_region_id: int = int(transfer_target.get("region_id", -1))
	if friendly_region_id == current_region_id:
		var local_transferred: bool = army_manager.transfer_all_soldiers(army, friendly_army)
		if local_transferred:
			_log_decision_tree_branch(army, "recruit_transfer_to_friendly", "local_transfer")
			_log_army_transfer(army, friendly_army)
			army.spawn_minimal_peasant_token()
			_set_recruitment_move_state(army, Army.RecruitmentMoveState.RECRUIT_OR_DEFEND, "transfer_complete")
		return true
	_log_decision_tree_branch(army, "recruit_transfer_to_friendly", "to " + _get_region_name_by_id(friendly_region_id))
	await _move_army_to_region(army, friendly_region_id, "support_merge", {})
	if is_instance_valid(army) and is_instance_valid(friendly_army):
		var army_region: Region = army.get_parent() as Region
		var support_region: Region = friendly_army.get_parent() as Region
		if army_region.get_region_id() == support_region.get_region_id():
			var transferred: bool = army_manager.transfer_all_soldiers(army, friendly_army)
			if transferred:
				_log_army_transfer(army, friendly_army)
				army.spawn_minimal_peasant_token()
				_set_recruitment_move_state(army, Army.RecruitmentMoveState.RECRUIT_OR_DEFEND, "transfer_complete")
	return true

func _handle_recruitment_recruit_or_defend_state(army: Army, turn_number: int) -> bool:
	var current_region: Region = army.get_parent() as Region
	var current_region_id: int = current_region.get_region_id()
	var best_castle: Dictionary = _find_best_recruitment_castle_pick(army, current_region_id)
	_log_recruitment_candidates(best_castle, current_region_id)
	var target_region_id: int = int(best_castle.get("best_region_id", -1))
	if target_region_id == -1:
		_log_decision_tree_branch(army, "recruit_or_defend_camp", "no_recruit_castle")
		_spend_all_on_camp(army)
		return true
	if target_region_id == current_region_id:
		return _execute_recruitment_at_current_region(army, current_region)
	if _can_reach_region_this_turn(army, current_region_id, target_region_id, true):
		_log_army_detail_line("Recruit-or-defend moving to " + _get_region_name_by_id(target_region_id))
		await _move_army_to_region(army, target_region_id, "reinforce", best_castle)
		return true
	_log_decision_tree_branch(army, "recruit_or_defend_retry_normal", "no_reachable_castle")
	_set_recruitment_move_state(army, Army.RecruitmentMoveState.NORMAL, "no_reachable_castle")
	return await _handle_recruitment_normal_state(army, turn_number)

func _execute_recruitment_at_current_region(army: Army, current_region: Region) -> bool:
	var current_region_id: int = current_region.get_region_id()
	_log_army_detail_line("Recruiting at " + _get_region_name_by_id(current_region_id))
	var assigned_budget: BudgetComposition = army.get_assigned_budget()
	if assigned_budget == null:
		_log_recruitment_status_once(army, current_region_id, "no_budget_assigned")
		_log_army_detail_line("Waiting for recruitment budget at " + _get_region_name_by_id(current_region_id))
		_spend_all_on_camp(army)
		return true
	var allow_recruit: bool = army.get_movement_points() >= 1 or army.just_raised
	if not allow_recruit:
		_log_recruitment_skip(army, current_region_id, "no_movement_points")
		_spend_all_on_camp(army)
		return true
	var recruitment_manager: RecruitmentManager = RecruitmentManager.new(region_manager, game_manager)
	var comp_before: String = _get_army_composition_suffix(army)
	var power_before: int = army.get_army_power()
	var result: Dictionary = recruitment_manager.hire_soldiers(army, true)
	if army.get_total_soldiers() > 0:
		army.just_raised = false
	if result.has("error"):
		_log_recruitment_skip(army, current_region_id, String(result.get("error", "unknown")))
	else:
		_log_recruitment_success(army, current_region_id, result, comp_before, power_before)
		_log_recruitment_detail(army, result, current_region.get_region_name())
		_set_recruitment_move_state(army, Army.RecruitmentMoveState.NORMAL, "recruited")
	return true

func _find_best_recruitment_castle_pick(army: Army, from_region_id: int, friendly_only: bool = true) -> Dictionary:
	return region_manager.find_best_recruitment_castle(from_region_id, army.get_player_id(), true, army, friendly_only)

func _can_reach_region_this_turn(army: Army, from_region_id: int, to_region_id: int, friendly_only: bool) -> bool:
	var path_info: Dictionary = _get_path_info_for_player(army.get_player_id(), from_region_id, to_region_id, friendly_only, army.get_movement_points())
	return bool(path_info.get("can_reach_this_turn", false))

func _is_army_below_half_recruitment_threshold(army: Army, turn_number: int) -> bool:
	var threshold: float = army_manager.calc_reinforcement_threshold(turn_number)
	var half_threshold: float = threshold * AI_RECRUITMENT_HALF_THRESHOLD_RATIO
	return float(army.get_army_power()) < half_threshold

func _find_clean_breakthrough_path_to_recruit_castle(army: Army, start_region_id: int, target_region_id: int) -> Array[int]:
	if target_region_id < 0:
		return []
	if start_region_id == target_region_id:
		return [start_region_id]
	var player_id: int = army.get_player_id()
	var visited: Dictionary = {}
	var distances: Dictionary = {}
	var parents: Dictionary = {}
	var heap := BinaryHeap.new()
	var start_state_key: String = _build_breakthrough_state_key(start_region_id, 0)
	distances[start_state_key] = 0
	parents[start_state_key] = ""
	heap.insert({
		"region_id": start_region_id,
		"cost": 0,
		"non_friendly_count": 0
	})
	var explored_nodes: int = 0
	while not heap.is_empty() and explored_nodes < AI_RECRUITMENT_BREAKTHROUGH_MAX_EXPLORED_NODES:
		var current: Dictionary = heap.extract_min()
		var current_region_id: int = int(current.get("region_id", -1))
		var current_non_friendly_count: int = int(current.get("non_friendly_count", 0))
		var current_state_key: String = _build_breakthrough_state_key(current_region_id, current_non_friendly_count)
		if visited.has(current_state_key):
			continue
		visited[current_state_key] = true
		explored_nodes += 1
		if current_region_id == target_region_id:
			return _reconstruct_breakthrough_path_by_state(parents, current_state_key)
		var neighbors: Array = region_manager.get_neighbor_regions(current_region_id)
		for neighbor in neighbors:
			var neighbor_id: int = int(neighbor)
			if not _is_clean_breakthrough_region(neighbor_id, player_id, target_region_id):
				continue
			var enter_cost: int = region_manager.calculate_terrain_cost(neighbor_id, player_id)
			if enter_cost < 0:
				continue
			var additional_non_friendly: int = 1 if _is_non_friendly_region(neighbor_id, player_id) else 0
			var next_non_friendly_count: int = current_non_friendly_count + additional_non_friendly
			if next_non_friendly_count > AI_RECRUITMENT_BREAKTHROUGH_MAX_NON_FRIENDLY_REGIONS:
				continue
			var neighbor_state_key: String = _build_breakthrough_state_key(neighbor_id, next_non_friendly_count)
			if visited.has(neighbor_state_key):
				continue
			var current_cost: int = int(distances.get(current_state_key, AI_PATH_UNREACHABLE_COST))
			var new_cost: int = current_cost + enter_cost
			var old_cost: int = int(distances.get(neighbor_state_key, AI_PATH_UNREACHABLE_COST))
			if not distances.has(neighbor_state_key) or new_cost < old_cost:
				distances[neighbor_state_key] = new_cost
				parents[neighbor_state_key] = current_state_key
				heap.insert({
					"region_id": neighbor_id,
					"cost": new_cost,
					"non_friendly_count": next_non_friendly_count
				})
	return []

func _build_breakthrough_state_key(region_id: int, non_friendly_count: int) -> String:
	return str(region_id) + ":" + str(non_friendly_count)

func _reconstruct_breakthrough_path_by_state(parents: Dictionary, target_state_key: String) -> Array[int]:
	var reversed_path: Array[int] = []
	var current_state_key: String = target_state_key
	while current_state_key != "":
		var state_parts: PackedStringArray = current_state_key.split(":")
		if state_parts.size() != 2:
			return []
		var region_id: int = int(state_parts[0])
		reversed_path.append(region_id)
		current_state_key = String(parents.get(current_state_key, ""))
	reversed_path.reverse()
	return reversed_path

func _is_non_friendly_region(region_id: int, player_id: int) -> bool:
	return region_manager.get_region_owner(region_id) != player_id

func _is_clean_breakthrough_region(region_id: int, player_id: int, target_region_id: int) -> bool:
	if region_id == target_region_id:
		return true
	var owner_id: int = region_manager.get_region_owner(region_id)
	if owner_id == player_id:
		return true
	if region_manager.get_castle_level(region_id) > 0:
		return false
	var region_node: Region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
	var armies_in_region: Array[Army] = army_manager.get_armies_in_region(region_node)
	return armies_in_region.is_empty()

func _reconstruct_region_path(parents: Dictionary, start_region_id: int, target_region_id: int) -> Array[int]:
	if target_region_id == start_region_id:
		return [start_region_id]
	if not parents.has(target_region_id):
		return []
	var path: Array[int] = []
	var current_region_id: int = target_region_id
	while current_region_id != -1:
		path.append(current_region_id)
		current_region_id = int(parents.get(current_region_id, -1))
	path.reverse()
	return path

func _get_first_breakthrough_step_on_path(path: Array[int], player_id: int) -> int:
	if path.size() <= 1:
		return -1
	for i in range(1, path.size()):
		var region_id: int = int(path[i])
		var owner_id: int = region_manager.get_region_owner(region_id)
		if owner_id != player_id:
			return region_id
	return -1

func _select_transfer_target_from_nearby(army: Army, current_region_id: int) -> Dictionary:
	var friendly_cache: Dictionary = army.nearby_entities.get("friendly_armies", {})
	var candidates: Array[Dictionary] = []
	for friendly_key in friendly_cache.keys():
		var friendly_entry: Dictionary = friendly_cache.get(friendly_key, {})
		var friendly_entity_id: String = String(friendly_entry.get("id", String(friendly_key)))
		var friendly_army: Army = _resolve_army_from_entity_id(friendly_entity_id)
		if not is_instance_valid(friendly_army):
			continue
		if friendly_army == army:
			continue
		var friendly_region: Region = friendly_army.get_parent() as Region
		var friendly_region_id: int = friendly_region.get_region_id()
		var path_info: Dictionary = _get_path_info_for_player(army.get_player_id(), current_region_id, friendly_region_id, true, army.get_movement_points())
		if not bool(path_info.get("success", false)):
			continue
		var path_cost: int = int(path_info.get("cost", AI_PATH_UNREACHABLE_COST))
		candidates.append({
			"army": friendly_army,
			"region_id": friendly_region_id,
			"path_cost": path_cost,
			"army_id": friendly_army.get_instance_id()
		})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a, b):
		var a_cost: int = int(a.get("path_cost", AI_PATH_UNREACHABLE_COST))
		var b_cost: int = int(b.get("path_cost", AI_PATH_UNREACHABLE_COST))
		if a_cost != b_cost:
			return a_cost < b_cost
		var a_region_id: int = int(a.get("region_id", -1))
		var b_region_id: int = int(b.get("region_id", -1))
		if a_region_id != b_region_id:
			return a_region_id < b_region_id
		return int(a.get("army_id", 0)) < int(b.get("army_id", 0))
	)
	return candidates[0]

func _set_recruitment_move_state(army: Army, state: Army.RecruitmentMoveState, reason: String = "") -> void:
	if army.get_recruitment_move_state() == state:
		return
	army.set_recruitment_move_state(state)
	if reason != "":
		_log_army_detail_line("Recruitment state -> " + _recruitment_state_to_string(state) + " (" + reason + ")")

func _recruitment_state_to_string(state: Army.RecruitmentMoveState) -> String:
	match state:
		Army.RecruitmentMoveState.TRANSFER_TO_CLOSEST:
			return "TRANSFER_TO_CLOSEST"
		Army.RecruitmentMoveState.RECRUIT_OR_DEFEND:
			return "RECRUIT_OR_DEFEND"
		_:
			return "NORMAL"

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

func _handle_threatened_castle_cycle(army: Army) -> bool:
	var castle_candidates: Array[Dictionary] = _get_threatened_castle_candidates_for_army(army)
	if castle_candidates.is_empty():
		_log_decision_tree_branch(army, "threat_no_action", "no_threatened_castles")
		return false
	var player_id: int = army.get_player_id()
	var current_region: Region = army.get_parent() as Region
	var current_region_id: int = current_region.get_region_id()
	for castle_candidate in castle_candidates:
		var castle_region_id: int = int(castle_candidate.get("region_id", -1))
		var threat_entries: Array[Dictionary] = _get_sorted_threat_entries_for_castle(castle_region_id)
		var has_active_threat: bool = false
		for threat_entry in threat_entries:
			if not _is_threat_entry_still_active(threat_entry, player_id):
				continue
			var live_threat_entry: Dictionary = _get_live_threat_entry_for_decision(threat_entry, player_id)
			has_active_threat = true
			var threat_region_id: int = int(live_threat_entry.get("region_id", -1))
			if threat_region_id < 0:
				continue
			if threat_region_id == current_region_id:
				continue
			var attack_path: Dictionary = _get_path_info_for_player(player_id, current_region_id, threat_region_id, true, army.get_movement_points())
			if not bool(attack_path.get("can_reach_this_turn", false)):
				continue
			var direct_eval: Dictionary = _evaluate_threat_direct_attack_viability(army, live_threat_entry, threat_region_id)
			if bool(direct_eval.get("can_attack", false)):
				var attack_reason: String = "to " + _get_region_name_by_id(threat_region_id)
				_log_decision_tree_branch(army, "threat_direct_attack", attack_reason)
				var attack_result: Dictionary = await _move_army_to_region_with_result(army, threat_region_id, "attack", {})
				var result_label: String = String(attack_result.get("result", "blocked"))
				if result_label == "battle_withdrawal" or result_label == "battle_defeat":
					_set_threat_direct_block(army.get_instance_id(), threat_region_id, result_label)
				return true
			var block_branch: String = String(direct_eval.get("block_branch", ""))
			if block_branch != "":
				_log_decision_tree_branch(army, block_branch, "to " + _get_region_name_by_id(threat_region_id))
			var support_candidate: Dictionary = _select_support_merge_target(army, live_threat_entry, current_region_id)
			if support_candidate.is_empty():
				continue
			var support_army: Army = support_candidate.get("friendly_army", null) as Army
			var support_region_id: int = int(support_candidate.get("region_id", -1))
			if support_region_id == current_region_id:
				var transferred_local: bool = army_manager.transfer_all_soldiers(army, support_army)
				if transferred_local:
					_log_army_transfer(army, support_army)
					army.spawn_minimal_peasant_token()
					army.request_recruitment()
					_log_decision_tree_branch(army, "threat_support_merge", "local_transfer")
					return true
				continue
			var support_reason: String = "to " + _get_region_name_by_id(support_region_id)
			_log_decision_tree_branch(army, "threat_support_merge", support_reason)
			await _move_army_to_region(army, support_region_id, "support_merge", {})
			if is_instance_valid(army) and is_instance_valid(support_army):
				var army_region: Region = army.get_parent() as Region
				var support_region: Region = support_army.get_parent() as Region
				if army_region.get_region_id() == support_region.get_region_id():
					var transferred: bool = army_manager.transfer_all_soldiers(army, support_army)
					if transferred:
						_log_army_transfer(army, support_army)
						army.spawn_minimal_peasant_token()
						army.request_recruitment()
						return true
		if not has_active_threat:
			continue
		if castle_region_id == current_region_id:
			continue
		var defend_eval: Dictionary = _evaluate_castle_defense_need(castle_region_id, player_id, threat_entries)
		var unknown_needs_defender: bool = bool(defend_eval.get("unknown_needs_defender", false))
		var known_needs_more_defenders: bool = bool(defend_eval.get("known_needs_more_defenders", false))
		if not unknown_needs_defender and not known_needs_more_defenders:
			_log_decision_tree_branch(army, "threat_castle_defended", _get_region_name_by_id(castle_region_id))
			continue
		var castle_path: Dictionary = _get_path_info_for_player(player_id, current_region_id, castle_region_id, true, army.get_movement_points())
		if not bool(castle_path.get("can_reach_this_turn", false)):
			_log_decision_tree_branch(army, "threat_reposition_skipped_unreachable", _get_region_name_by_id(castle_region_id))
			continue
		var castle_reason: String = "to " + _get_region_name_by_id(castle_region_id)
		if unknown_needs_defender and not known_needs_more_defenders:
			_log_decision_tree_branch(army, "threat_reposition_needed_unknown", castle_reason)
		else:
			_log_decision_tree_branch(army, "threat_reposition_needed_known_gap", castle_reason)
		await _move_army_to_region(army, castle_region_id, "threat_reposition", {})
		if is_instance_valid(army):
			army.request_recruitment()
			var army_region: Region = army.get_parent() as Region
			if army_region.get_region_id() == castle_region_id and bool(defend_eval.get("has_unknown_threat", false)):
				_unknown_threat_defended_by_region[castle_region_id] = true
		return true
	_log_decision_tree_branch(army, "threat_no_action", "no_reachable_threat_action")
	return false

func _evaluate_castle_defense_need(castle_region_id: int, player_id: int, threat_entries: Array[Dictionary]) -> Dictionary:
	var has_unknown_threat: bool = false
	var known_enemy_power_total: int = 0
	for threat_entry in threat_entries:
		if not _is_threat_entry_still_active(threat_entry, player_id):
			continue
		var live_threat_entry: Dictionary = _get_live_threat_entry_for_decision(threat_entry, player_id)
		var threat_known: bool = bool(live_threat_entry.get("known", false))
		if not threat_known:
			has_unknown_threat = true
			continue
		known_enemy_power_total += int(live_threat_entry.get("power", 0))
	var castle_region: Region = region_manager.map_generator.get_region_container_by_id(castle_region_id) as Region
	var current_defense_power: int = game_manager._compute_region_total_defender_power(castle_region)
	var has_friendly_army_in_castle: bool = _castle_has_friendly_army(castle_region, player_id)
	var unknown_marked_defended: bool = bool(_unknown_threat_defended_by_region.get(castle_region_id, false))
	var unknown_needs_defender: bool = has_unknown_threat and not has_friendly_army_in_castle and not unknown_marked_defended
	var known_needs_more_defenders: bool = known_enemy_power_total > current_defense_power
	return {
		"has_unknown_threat": has_unknown_threat,
		"known_enemy_power_total": known_enemy_power_total,
		"current_defense_power": current_defense_power,
		"unknown_needs_defender": unknown_needs_defender,
		"known_needs_more_defenders": known_needs_more_defenders
	}

func _castle_has_friendly_army(castle_region: Region, player_id: int) -> bool:
	var armies_in_region: Array[Army] = army_manager.get_armies_in_region(castle_region)
	for region_army in armies_in_region:
		if region_army.get_player_id() == player_id:
			return true
	return false

func _get_threatened_castle_candidates_for_army(army: Army) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var ordered_region_ids: Array[int] = []
	for region_key in _castle_threat_level_snapshot_by_region.keys():
		var region_id: int = int(region_key)
		var threat_level: int = int(_castle_threat_level_snapshot_by_region.get(region_id, 0))
		if threat_level < AI_THREAT_RESPONSE_MIN_LEVEL:
			continue
		ordered_region_ids.append(region_id)
	ordered_region_ids.sort()
	var current_region: Region = army.get_parent() as Region
	var current_region_id: int = current_region.get_region_id()
	var player_id: int = army.get_player_id()
	for region_id in ordered_region_ids:
		var threat_registry: Dictionary = _castle_threat_registry_snapshot_by_region.get(region_id, {})
		if threat_registry.is_empty():
			continue
		var path_info: Dictionary = _get_path_info_for_player(player_id, current_region_id, region_id, true, army.get_movement_points())
		var move_cost: int = int(path_info.get("cost", AI_PATH_UNREACHABLE_COST))
		var can_reach_now: bool = bool(path_info.get("can_reach_this_turn", false))
		candidates.append({
			"region_id": region_id,
			"move_cost": move_cost,
			"can_reach_this_turn": can_reach_now
		})
	candidates.sort_custom(func(a, b):
		var a_reach: bool = bool(a.get("can_reach_this_turn", false))
		var b_reach: bool = bool(b.get("can_reach_this_turn", false))
		if a_reach != b_reach:
			return a_reach
		var a_cost: int = int(a.get("move_cost", AI_PATH_UNREACHABLE_COST))
		var b_cost: int = int(b.get("move_cost", AI_PATH_UNREACHABLE_COST))
		if a_cost != b_cost:
			return a_cost < b_cost
		return int(a.get("region_id", -1)) < int(b.get("region_id", -1))
	)
	return candidates

func _get_sorted_threat_entries_for_castle(castle_region_id: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var threat_registry: Dictionary = _castle_threat_registry_snapshot_by_region.get(castle_region_id, {})
	for threat_key in threat_registry.keys():
		var threat_entry: Dictionary = threat_registry.get(threat_key, {})
		entries.append(threat_entry.duplicate(true))
	entries.sort_custom(func(a, b):
		var a_level: int = int(a.get("threat_level", 0))
		var b_level: int = int(b.get("threat_level", 0))
		if a_level != b_level:
			return a_level > b_level
		var a_region: int = int(a.get("region_id", -1))
		var b_region: int = int(b.get("region_id", -1))
		if a_region != b_region:
			return a_region < b_region
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	return entries

func _get_path_info_for_player(player_id: int, from_region_id: int, to_region_id: int, friendly_only: bool, movement_points: int) -> Dictionary:
	var path_result: Dictionary = pathfinder.find_path_to_target(from_region_id, to_region_id, player_id, friendly_only, true)
	if not bool(path_result.get("success", false)):
		return {
			"success": false,
			"cost": AI_PATH_UNREACHABLE_COST,
			"path": [],
			"can_reach_this_turn": false
		}
	var cost: int = int(path_result.get("cost", AI_PATH_UNREACHABLE_COST))
	var raw_path: Array = path_result.get("path", [])
	var path: Array[int] = []
	for path_region_id in raw_path:
		path.append(int(path_region_id))
	return {
		"success": true,
		"cost": cost,
		"path": path,
		"can_reach_this_turn": cost <= movement_points
	}

func _get_live_threat_entry_for_decision(threat_entry: Dictionary, observer_player_id: int) -> Dictionary:
	var live_entry: Dictionary = threat_entry.duplicate(true)
	var threat_id: String = String(live_entry.get("id", ""))
	if threat_id == "":
		return live_entry
	var threat_army: Army = _resolve_army_from_entity_id(threat_id)
	if is_instance_valid(threat_army):
		var threat_region: Region = threat_army.get_parent() as Region
		live_entry["region_id"] = threat_region.get_region_id()
		live_entry["player_id"] = threat_army.get_player_id()
	var tracker_key: String = _extract_tracker_key_from_entity_id(threat_id)
	if tracker_key == "":
		return live_entry
	var tracked_power: int = player_manager.get_tracked_enemy_power(observer_player_id, tracker_key)
	if tracked_power >= 0:
		live_entry["known"] = true
		live_entry["power"] = tracked_power
	else:
		live_entry["known"] = false
		live_entry["power"] = -1
	return live_entry

func _extract_tracker_key_from_entity_id(entity_id: String) -> String:
	if entity_id.begins_with("army_"):
		return entity_id.substr(5, entity_id.length() - 5)
	return entity_id

func _can_attack_threat_directly(army: Army, threat_entry: Dictionary) -> bool:
	var threat_known: bool = bool(threat_entry.get("known", false))
	if not threat_known:
		return true
	var threat_power: int = int(threat_entry.get("power", -1))
	return army.get_army_power() > threat_power

func _is_threat_direct_blocked(army_id: int, target_region_id: int) -> bool:
	if not _threat_direct_block_by_army.has(army_id):
		return false
	var army_locks: Dictionary = _threat_direct_block_by_army.get(army_id, {})
	return army_locks.has(target_region_id)

func _set_threat_direct_block(army_id: int, target_region_id: int, reason: String) -> void:
	var army_locks: Dictionary = _threat_direct_block_by_army.get(army_id, {})
	army_locks[target_region_id] = reason
	_threat_direct_block_by_army[army_id] = army_locks

func _evaluate_threat_direct_attack_viability(army: Army, threat_entry: Dictionary, threat_region_id: int) -> Dictionary:
	var army_id: int = army.get_instance_id()
	if _is_threat_direct_blocked(army_id, threat_region_id):
		return {
			"can_attack": false,
			"block_branch": "threat_direct_blocked_turn_lock"
		}
	var threat_region: Region = region_manager.map_generator.get_region_container_by_id(threat_region_id) as Region
	var has_castle: bool = threat_region.get_castle_type() != CastleTypeEnum.Type.NONE
	var threat_known: bool = bool(threat_entry.get("known", false))
	if has_castle:
		if not threat_known:
			_set_threat_direct_block(army_id, threat_region_id, "unknown_castle")
			return {
				"can_attack": false,
				"block_branch": "threat_direct_blocked_unknown_castle"
			}
		var enemy_info: Dictionary = _build_enemy_info(threat_region_id, army.get_player_id(), army)
		var decision: String = _evaluate_merge_policy(army, enemy_info)
		if decision != "proceed":
			_set_threat_direct_block(army_id, threat_region_id, "simulation")
			return {
				"can_attack": false,
				"block_branch": "threat_direct_blocked_simulation"
			}
		return {"can_attack": true}
	if _can_attack_threat_directly(army, threat_entry):
		return {"can_attack": true}
	return {
		"can_attack": false,
		"block_branch": ""
	}

func _is_threat_entry_still_active(threat_entry: Dictionary, player_id: int) -> bool:
	var threat_id: String = String(threat_entry.get("id", ""))
	var threat_region_id: int = int(threat_entry.get("region_id", -1))
	if threat_id == "" or threat_region_id < 0:
		return false
	var threat_army: Army = _resolve_army_from_entity_id(threat_id)
	if not is_instance_valid(threat_army):
		return false
	if threat_army.get_player_id() == player_id:
		return false
	var threat_region: Region = threat_army.get_parent() as Region
	return threat_region.get_region_id() == threat_region_id

func _select_support_merge_target(army: Army, threat_entry: Dictionary, current_region_id: int) -> Dictionary:
	var threat_region_id: int = int(threat_entry.get("region_id", -1))
	if threat_region_id < 0:
		return {}
	var friendly_cache: Dictionary = army.nearby_entities.get("friendly_armies", {})
	var candidates: Array[Dictionary] = []
	var threat_known: bool = bool(threat_entry.get("known", false))
	var threat_power: int = int(threat_entry.get("power", -1))
	for friendly_key in friendly_cache.keys():
		var friendly_entry: Dictionary = friendly_cache.get(friendly_key, {})
		var friendly_entity_id: String = String(friendly_entry.get("id", String(friendly_key)))
		var friendly_army: Army = _resolve_army_from_entity_id(friendly_entity_id)
		if not is_instance_valid(friendly_army):
			continue
		if friendly_army == army:
			continue
		if friendly_army.get_movement_points() <= 0:
			continue
		var friendly_region: Region = friendly_army.get_parent() as Region
		var friendly_region_id: int = friendly_region.get_region_id()
		var to_friendly: Dictionary = _get_path_info_for_player(army.get_player_id(), current_region_id, friendly_region_id, true, army.get_movement_points())
		if not bool(to_friendly.get("can_reach_this_turn", false)):
			continue
		var friendly_to_threat: Dictionary = _get_path_info_for_player(army.get_player_id(), friendly_region_id, threat_region_id, true, friendly_army.get_movement_points())
		if not bool(friendly_to_threat.get("can_reach_this_turn", false)):
			continue
		var combined_power: int = army.get_army_power() + friendly_army.get_army_power()
		if threat_known and combined_power <= threat_power:
			continue
		if not _support_merge_passes_castle_simulation(army, friendly_army, threat_region_id):
			_log_decision_tree_branch(army, "threat_support_rejected_simulation", "to " + _get_region_name_by_id(threat_region_id))
			continue
		candidates.append({
			"friendly_army": friendly_army,
			"region_id": friendly_region_id,
			"move_cost": int(to_friendly.get("cost", AI_PATH_UNREACHABLE_COST)),
			"combined_power": combined_power
		})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a, b):
		var a_cost: int = int(a.get("move_cost", AI_PATH_UNREACHABLE_COST))
		var b_cost: int = int(b.get("move_cost", AI_PATH_UNREACHABLE_COST))
		if a_cost != b_cost:
			return a_cost < b_cost
		var a_power: int = int(a.get("combined_power", 0))
		var b_power: int = int(b.get("combined_power", 0))
		if a_power != b_power:
			return a_power > b_power
		return int(a.get("region_id", -1)) < int(b.get("region_id", -1))
	)
	return candidates[0]

func _support_merge_passes_castle_simulation(acting_army: Army, friendly_army: Army, threat_region_id: int) -> bool:
	var threat_region: Region = region_manager.map_generator.get_region_container_by_id(threat_region_id) as Region
	if threat_region.get_castle_type() == CastleTypeEnum.Type.NONE:
		return true
	var merged_attackers: Array[Army] = []
	merged_attackers.append(acting_army)
	merged_attackers.append(friendly_army)
	var simulation: Dictionary = game_manager.simulate_castle_threat_battle(merged_attackers, threat_region)
	var simulation_result: String = String(simulation.get("result", "defeat"))
	return simulation_result == "victory"

func _resolve_army_from_entity_id(army_entity_id: String) -> Army:
	var instance_id: int = _extract_instance_id_from_army_entity_id(army_entity_id)
	if instance_id <= 0:
		return null
	var all_armies: Array[Army] = army_manager.get_all_armies()
	for tracked_army in all_armies:
		if tracked_army.get_instance_id() == instance_id:
			return tracked_army
	return null

func _extract_instance_id_from_army_entity_id(army_entity_id: String) -> int:
	if not army_entity_id.begins_with("army_"):
		return -1
	var suffix: String = army_entity_id.substr(5, army_entity_id.length() - 5)
	if suffix == "":
		return -1
	return int(suffix)

func _select_frontier_move(army: Army) -> Dictionary:
	var frontier: Array[int] = region_manager.get_frontier_regions(army.get_player_id())
	return _select_frontier_move_for_targets(army, frontier)

func _select_frontier_move_for_targets(army: Army, frontier: Array[int]) -> Dictionary:
	if frontier.is_empty():
		return {}
	var moves: Array = _get_sorted_frontier_moves(army, frontier)
	if moves.is_empty():
		_log_rejected_candidates(_copy_latest_candidate_rejections())
		return {}
	_log_target_candidates(moves)
	var rejected_candidates: Array[Dictionary] = _copy_latest_candidate_rejections()
	var best_halt: Dictionary = {}
	for move_variant in moves:
		var move: Dictionary = move_variant as Dictionary
		var target_region_id: int = int(move.get("target_id", -1))
		if target_region_id < 0:
			continue
		var enemy_info: Dictionary = _build_enemy_info(target_region_id, army.get_player_id(), army)
		var decision: String = _evaluate_merge_policy(army, enemy_info)
		if decision == "halt":
			if best_halt.is_empty():
				best_halt = {
					"target_id": target_region_id,
					"enemy_info": enemy_info
				}
			_append_rejected_candidate(
				rejected_candidates,
				target_region_id,
				"merge_policy_halt",
				float(move.get("final_score", 0.0)),
				true
			)
			continue
		if not move.has("goal"):
			move["goal"] = "attack"
		move["enemy_info"] = enemy_info
		move["merge_decision"] = decision
		_log_rejected_candidates(rejected_candidates)
		return move
	if not best_halt.is_empty():
		_log_rejected_candidates(rejected_candidates)
		return {
			"goal": "halt",
			"target_id": int(best_halt.get("target_id", -1)),
			"enemy_info": best_halt.get("enemy_info", {})
		}
	_log_rejected_candidates(rejected_candidates)
	return {}

func _build_enemy_info(target_region_id: int, player_id: int, attacker: Army) -> Dictionary:
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
	var simulation_result := ""
	var simulation: Dictionary = {}
	if game_manager and castle_level > 0 and has_enemy and known_strength:
		simulation = game_manager.simulate_siege_battle(attacker, target_region)
		simulation_result = String(simulation.get("result", ""))
	return {
		"has_enemy": has_enemy,
		"known": known_strength,
		"power": enemy_power,
		"armies": enemy_armies,
		"castle_level": castle_level,
		"owner": enemy_owner,
		"simulation": simulation,
		"simulation_result": simulation_result
	}

func _evaluate_merge_policy(army: Army, enemy_info: Dictionary) -> String:
	var simulation_result: String = String(enemy_info.get("simulation_result", ""))
	if simulation_result == "victory":
		return "proceed"
	if simulation_result == "defeat" or simulation_result == "withdrawal":
		return "halt"
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
	var move_result: Dictionary = await _move_army_to_region_with_result(army, target_region_id, goal, extra_log)
	return bool(move_result.get("moved", false))

func _move_army_to_region_with_result(army: Army, target_region_id: int, goal: String, extra_log: Dictionary) -> Dictionary:
	if not _ensure_vigor_before_move(army):
		return {
			"moved": false,
			"result": "blocked",
			"battle_region_id": target_region_id
		}
	var acting_player_id: int = army.get_player_id()
	var current_region: Region = army.get_parent() as Region
	var current_region_id: int = current_region.get_region_id()
	var friendly_only: bool = goal == "reinforce" or goal == "peasants" or goal == "support_merge" or goal == "threat_reposition" or goal == "attack"
	var pf: Dictionary = pathfinder.find_path_to_target(current_region_id, target_region_id, army.get_player_id(), friendly_only, true)
	if not pf["success"]:
		_spend_all_on_camp(army)
		return {
			"moved": false,
			"result": "blocked",
			"battle_region_id": current_region_id
		}
	var move: Dictionary = {
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
	var travel_result: Dictionary = await game_manager.ai_travel_to(army, target_region_id)
	var result: String = String(travel_result.get("result", "blocked"))
	var battle_region_id: int = int(travel_result.get("battle_region_id", target_region_id))
	var log_army: Army = army if is_instance_valid(army) else null
	_log_army_move_result(log_army, target_region_id, result, army_log_token, battle_region_id)
	if result == "arrived" or result == "battle_victory":
		_log_move_status(army, target_region_id)
	if result == "battle_victory":
		emit_signal("region_conquered", target_region_id, army.get_player_id())
	if result == "blocked" or result == "out_of_movement_points":
		if is_instance_valid(army):
			_spend_all_on_camp(army)
	if result == "battle_withdrawal" or result == "battle_defeat":
		if is_instance_valid(army):
			await _retreat_to_strong_friendly_region(army)
			if army.is_recruitment_requested():
				_log_decision_tree_branch(army, "recruit_mark_transfer_withdrawal", result)
				_set_recruitment_move_state(army, Army.RecruitmentMoveState.TRANSFER_TO_CLOSEST, result)
	if game_manager.check_victory_conditions_for_player(acting_player_id):
		return {
			"moved": false,
			"result": result,
			"battle_region_id": battle_region_id
		}
	if not is_instance_valid(army):
		return {
			"moved": false,
			"result": result,
			"battle_region_id": battle_region_id
		}
	return {
		"moved": army.get_movement_points() > 0,
		"result": result,
		"battle_region_id": battle_region_id
	}

func _emit_move_prepared(army: Army, target_id: int, move: Dictionary) -> void:
	var score = float(move.get("final_score", 0.0))
	emit_signal("move_prepared", army, target_id, score)

func _execute_move_to_target(army: Army, move: Dictionary) -> bool:
	var acting_player_id: int = army.get_player_id()
	var target_id: int = move["target_id"]
	move["suppress_summary"] = true
	_emit_move_prepared(army, target_id, move)
	emit_signal("move_started", army, target_id)
	_log_army_move_action(army, move)
	var army_log_token := game_manager.get_ai_battle_log_token(army)
	var travel_result: Dictionary = await game_manager.ai_travel_to(army, target_id)
	var result: String = String(travel_result.get("result", "blocked"))
	var battle_region_id: int = int(travel_result.get("battle_region_id", target_id))
	var log_army: Army = army if is_instance_valid(army) else null
	_log_army_move_result(log_army, target_id, result, army_log_token, battle_region_id)
	if result == "arrived" or result == "battle_victory":
		_log_move_status(army, target_id)
	if result == "battle_victory":
		emit_signal("region_conquered", target_id, army.get_player_id())
	if result == "battle_withdrawal" or result == "battle_defeat":
		if is_instance_valid(army):
			await _retreat_to_strong_friendly_region(army)
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
	if game_manager.check_victory_conditions_for_player(acting_player_id):
		return false
	if not is_instance_valid(army):
		return false
	return army.get_movement_points() > 0

func _spend_all_on_camp(army: Army) -> void:
	while army.get_movement_points() > 0:
		army.make_camp()
		_log_army_make_camp(army)

func _retreat_to_strong_friendly_region(army: Army) -> void:
	if army == null or not is_instance_valid(army):
		return
	var current_region := army.get_parent() as Region
	if current_region == null:
		return
	var mp_left: int = army.get_movement_points()
	if mp_left <= 0:
		return
	var player_id: int = army.get_player_id()
	var current_region_id: int = current_region.get_region_id()
	var best_region_id: int = current_region_id
	var best_power: int = game_manager._calculate_region_defender_power(current_region)
	var best_cost: int = 0
	var owned_regions: Array[int] = region_manager.get_player_regions(player_id)
	for region_id in owned_regions:
		var path_result = pathfinder.find_path_to_target(current_region_id, region_id, player_id, true, true)
		if not path_result["success"]:
			continue
		var cost: int = int(path_result.get("cost", 0))
		if cost > mp_left:
			continue
		var region_container = region_manager.map_generator.get_region_container_by_id(region_id)
		if region_container == null:
			continue
		var region = region_container as Region
		var power: int = game_manager._calculate_region_defender_power(region)
		if power > best_power or (power == best_power and cost < best_cost):
			best_power = power
			best_region_id = region_id
			best_cost = cost
	if best_region_id == current_region_id:
		return
	var retreat_path = pathfinder.find_path_to_target(current_region_id, best_region_id, player_id, true, true)
	if not retreat_path["success"]:
		return
	var path: Array[int] = retreat_path["path"]
	for i in range(1, path.size()):
		if army.get_movement_points() <= 0:
			break
		var step_region = region_manager.map_generator.get_region_container_by_id(path[i]) as Region
		if step_region == null:
			break
		var move_success = await army_manager.move_army(army, step_region)
		if not move_success:
			break
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
		if target_id == current_region_id:
			continue
		if target_scorer != null and target_scorer.is_target_overmatched_by_known_enemy(army, target_id):
			continue
		var base_score := target_scorer.score_region_base(target_id)
		if base_score <= 0.0:
			continue

		var path_result := pathfinder.find_path_to_target(current_region_id, target_id, player_id, true, true)
		if not path_result["success"]:
			continue

		var cost := int(path_result["cost"])
		var can_reach_now := cost <= mp_available
		if not can_reach_now:
			continue
		var random_mod := rng.randf() * GameParameters.AI_RANDOM_SCORE_MODIFIER
		var final_score := base_score + random_mod - float(cost)
		var components := target_scorer.get_target_components(army, target_id)

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
			"components": components
		}

		reachable.append(cand)

	if reachable.is_empty():
		return {}
		
	reachable.sort_custom(func(a, b): return a["final_score"] > b["final_score"])
	return reachable[0]

func _get_sorted_frontier_moves(army: Army, frontier: Array[int]) -> Array:
	var reachable: Array = []
	var far_targets: Array = []
	_latest_candidate_rejections.clear()
	var player_id := army.get_player_id()
	var current_region := army.get_parent()
	if not current_region or not current_region.has_method("get_region_id"):
		return []
	var current_region_id: int = current_region.get_region_id()

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var mp_available := army.get_movement_points()

	for target_id in frontier:
		if target_id == current_region_id:
			continue
		if target_scorer != null and target_scorer.is_target_overmatched_by_known_enemy(army, target_id):
			_latest_candidate_rejections.append({
				"target_id": target_id,
				"reason": "known_overmatched_filter",
				"score": 0.0,
				"has_score": false
			})
			continue
		var base_score := target_scorer.score_region_base(target_id, army.get_player_id())
		if base_score <= 0.0:
			_latest_candidate_rejections.append({
				"target_id": target_id,
				"reason": "base_score_non_positive",
				"score": base_score,
				"has_score": true
			})
			continue

		var path_result := pathfinder.find_path_to_target(current_region_id, target_id, player_id, true, true)
		if not path_result["success"]:
			_latest_candidate_rejections.append({
				"target_id": target_id,
				"reason": "no_friendly_path",
				"score": 0.0,
				"has_score": false
			})
			continue

		var cost := int(path_result["cost"])
		var can_reach_now := cost <= mp_available
		var random_mod := rng.randf() * GameParameters.AI_RANDOM_SCORE_MODIFIER
		var components := target_scorer.get_target_components(army, target_id)
		var ownership_bonus := 0.0
		var owner_id := region_manager.get_region_owner(target_id)
		if owner_id > 0 and owner_id != player_id:
			ownership_bonus = float(GameParameters.AI_ENEMY_REGION_SCORE_BONUS)
		var pursue_bonus := float(components.get("pursue_bonus", 0.0))
		var castle_bonus := float(components.get("castle_bonus", 0.0))
		var enemy_adjustment := target_scorer.get_enemy_adjustment(army, target_id)
		var final_score := base_score + ownership_bonus + random_mod + pursue_bonus + castle_bonus - float(cost) + float(enemy_adjustment.get("delta", 0.0))
		if enemy_adjustment.get("nullify", false):
			final_score = 0.0

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
			"components": components,
			"ownership_bonus": ownership_bonus,
			"pursue_bonus": pursue_bonus,
			"castle_bonus": castle_bonus
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
		var path_result = pathfinder.find_path_to_target(current_region_id, region_id, player_id, true, true)
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
	var pf := pathfinder.find_path_to_target(current_region_id, castle_id, army.get_player_id(), true, true)
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
	var upgrade_savings_gold: int = player.get_ai_castle_upgrade_savings_gold()
	game_manager.get_ai_log_manager().log_turn_intro(turn_number, player_label, player_id, resources, signals, decision, region_names, wealth_label, upgrade_savings_gold)

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
	elif goal == "support_merge":
		action = "Supports"
	elif goal == "threat_reposition":
		action = "Defends Castle"
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

func _copy_latest_candidate_rejections() -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for entry_variant in _latest_candidate_rejections:
		var entry: Dictionary = entry_variant as Dictionary
		copied.append(entry.duplicate(true))
	return copied

func _append_rejected_candidate(rejections: Array[Dictionary], target_region_id: int, reason: String, score: float = 0.0, has_score: bool = false) -> void:
	rejections.append({
		"target_id": target_region_id,
		"reason": reason,
		"score": score,
		"has_score": has_score
	})

func _log_rejected_candidates(rejections: Array[Dictionary]) -> void:
	if not _log_active_turn:
		return
	if rejections.is_empty():
		return
	var sorted: Array = rejections.duplicate()
	sorted.sort_custom(func(a, b):
		var a_has_score: bool = bool(a.get("has_score", false))
		var b_has_score: bool = bool(b.get("has_score", false))
		if a_has_score != b_has_score:
			return a_has_score
		if a_has_score and b_has_score:
			var a_score: float = float(a.get("score", 0.0))
			var b_score: float = float(b.get("score", 0.0))
			if abs(a_score - b_score) > 0.001:
				return a_score > b_score
		return int(a.get("target_id", -1)) < int(b.get("target_id", -1))
	)
	_log_army_detail_line("Rejected candidates:")
	var top_count: int = min(AI_TARGET_CANDIDATE_LOG_LIMIT, sorted.size())
	for i in range(top_count):
		var rejected: Dictionary = sorted[i]
		var region_id: int = int(rejected.get("target_id", -1))
		var reason_raw: String = String(rejected.get("reason", "unknown"))
		var reason_label: String = _format_rejected_reason(reason_raw)
		var score_label: String = "n/a"
		if bool(rejected.get("has_score", false)):
			score_label = "%.1f" % float(rejected.get("score", 0.0))
		var line := "Reason: %s Candidate %d: %s (#%d), score: %s" % [
			reason_label,
			i + 1,
			_get_region_name_by_id(region_id),
			region_id,
			score_label
		]
		_log_army_detail_line(line)

func _format_rejected_reason(reason: String) -> String:
	match reason:
		"known_overmatched_filter":
			return "known_overmatched_filter"
		"base_score_non_positive":
			return "base_score_non_positive"
		"no_friendly_path":
			return "no_friendly_path"
		"unreachable_this_turn":
			return "unreachable_this_turn"
		"merge_policy_halt":
			return "merge_policy_halt"
		"raider_unknown_hard_target":
			return "raider_unknown_hard_target"
		"raider_castle_threshold":
			return "raider_castle_threshold"
		"raider_army_threshold":
			return "raider_army_threshold"
		_:
			return reason

func _log_target_candidates(moves: Array) -> void:
	if not _log_active_turn:
		return
	if moves.is_empty():
		return
	var sorted := moves.duplicate()
	sorted.sort_custom(func(a, b):
		var a_score: float = float(a.get("final_score", 0.0))
		var b_score: float = float(b.get("final_score", 0.0))
		if abs(a_score - b_score) < 0.001:
			return int(a.get("target_id", -1)) < int(b.get("target_id", -1))
		return a_score > b_score
	)
	var top_count: int = min(AI_TARGET_CANDIDATE_LOG_LIMIT, sorted.size())
	_log_army_detail_line("Top %d candidates:" % top_count)
	for i in range(top_count):
		var move: Dictionary = sorted[i]
		var region_id: int = int(move.get("target_id", -1))
		var components: Dictionary = move.get("components", Dictionary())
		var line := "Candidate %d: %s (#%d), score: %.1f (resources: %.1f, population: %.1f, level: %d, castle_bonus: %.1f, pursue_bonus: %.1f, strategy: %.1f)" % [
			i + 1,
			_get_region_name_by_id(region_id),
			region_id,
			float(move.get("final_score", 0.0)),
			float(components.get("resources", 0.0)),
			float(components.get("population", 0.0)),
			int(components.get("level", 0)),
			float(components.get("castle_bonus", 0.0)),
			float(components.get("pursue_bonus", 0.0)),
			float(components.get("strategy", 0.0))
		]
		_log_army_detail_line(line)

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

func _log_army_move_result(army: Army, target_region_id: int, result: String, army_log_token: String, battle_region_id: int = -1) -> void:
	var actual_region_id := target_region_id
	if (result.begins_with("battle") or result == "blocked" or result == "out_of_movement_points") and battle_region_id >= 0:
		actual_region_id = battle_region_id
	var target_name = _get_region_name_by_id(actual_region_id)
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
	var pre_move_threats: Array = econ_result.get("castle_threats_pre_move", [])
	for threat_line in pre_move_threats:
		log.log_economy("Castle Threat (pre): " + String(threat_line))
	var pre_move_reserve: Array = econ_result.get("castle_reserve_pre_move", [])
	for reserve_line in pre_move_reserve:
		log.log_economy("Castle Reserve (pre): " + String(reserve_line))
	
	var raise = econ_result.get("raise", {})
	var raise_reason: String = String(raise.get("reason", "raised" if raise.get("raised", false) else "guards_failed"))
	var raise_score_text: String = String(raise.get("score_text", ""))
	if raise_score_text == "" and raise.has("score"):
		raise_score_text = "Score: %.2f" % float(raise.get("score", 0.0))
	var raise_message: String = "Raise Army: %s" % raise_reason
	if raise_score_text != "":
		raise_message += " (%s)" % raise_score_text
	log.log_economy(raise_message)
	
	var build_castle = econ_result.get("build_castle", {})
	var build_candidates: Array = build_castle.get("candidate_details", build_castle.get("details", []))
	var build_topup: Array = build_castle.get("topup_summary", [])
	var build_reason: String = String(build_castle.get("reason", "skipped"))
	var build_detail: String = String(build_castle.get("reason_detail", ""))
	if build_detail == "" and build_topup.size() > 0:
		build_detail = String(build_topup[0])
	var build_message: String = "Build Castle: %s" % build_reason
	if build_detail != "":
		build_message += " (%s)" % build_detail
	else:
		build_message += "."
	log.log_economy(build_message)
	log.log_economy_candidates("Build Castle", build_candidates)
	var build_gap: Array = build_castle.get("resource_gap", [])
	if build_gap.size() > 0:
		log.log_economy_block("Build Castle resources", build_gap)
	if build_topup.size() > 0:
		log.log_economy_block("Build Castle top-up", build_topup)
	
	var upgrade_castle = econ_result.get("upgrade_castle", {})
	var upgrade_candidates: Array = upgrade_castle.get("candidate_details", upgrade_castle.get("details", []))
	var upgrade_topup: Array = upgrade_castle.get("topup_summary", [])
	var upgrade_reason: String = String(upgrade_castle.get("reason", "skipped"))
	var upgrade_detail: String = String(upgrade_castle.get("reason_detail", ""))
	if upgrade_detail == "" and upgrade_topup.size() > 0:
		upgrade_detail = String(upgrade_topup[0])
	var upgrade_message: String = "Upgrade Castle: %s" % upgrade_reason
	if upgrade_detail != "":
		upgrade_message += " (%s)" % upgrade_detail
	else:
		upgrade_message += "."
	log.log_economy(upgrade_message)
	log.log_economy_candidates("Upgrade Castle", upgrade_candidates)
	
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
	log.log_army_movemement()

func _log_post_move_castle_recruitment(result: Dictionary) -> void:
	if not _log_active_turn:
		return
	var log := game_manager.get_ai_log_manager()
	var threat_deltas: Array = result.get("castle_threat_deltas", [])
	for delta_line in threat_deltas:
		log.log_economy("Castle Threat (post): " + String(delta_line))
	var reserve_lines: Array = result.get("castle_reserve_post_move", [])
	for reserve_line in reserve_lines:
		log.log_economy("Castle Reserve (post): " + String(reserve_line))
	var summary_reason: String = String(result.get("castle_recruitment_reason", "none"))
	var entries: Array = result.get("castle_recruitment_entries", [])
	log.log_castle_recruitment_summary("Castle Recruitment Post-Move", entries, summary_reason)

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

func _log_decision_tree_branch(army: Army, branch: String, reason: String) -> void:
	if not _log_active_turn:
		return
	game_manager.get_ai_log_manager().log_army_decision_tree(army.get_display_name(), branch, reason)

func _log_move_status(army: Army, target_region_id: int) -> void:
	if not _log_active_turn or army == null or not is_instance_valid(army):
		return
	var target_name = _get_region_name_by_id(target_region_id)
	_log_army_detail_line("Moving to %s [MP left: %d, Vigor: %d%%]" % [target_name, army.get_movement_points(), army.get_efficiency()])

func _log_army_separator(army: Army) -> void:
	if not _log_active_turn:
		return
	var role_label: String = _get_army_role_display_label(_get_army_role_for_turn(army))
	var army_number: String = _get_army_number_for_log(army)
	game_manager.get_ai_log_manager().log_army_separator(army_number, role_label)
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
