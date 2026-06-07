extends RefCounted
class_name EconomyAIManager

# Foundation for AI economy planning. KISS: keep recruitment wired, stub others.

var region_manager: RegionManager
var army_manager: ArmyManager
var player_manager: PlayerManagerNode
var game_manager: GameManager
var budget_manager: BudgetManager
var recruitment_manager: RecruitmentManager
var trade_manager: TradeManager
var signals: Dictionary
var garrison_requests: Array = []
var garrison_skip_logs: Array = []
var castle_threat_registry_by_region: Dictionary = {}
var castle_total_threat_value_by_region: Dictionary = {}
var castle_threat_level_by_region: Dictionary = {}
var castle_reserved_budget_by_region: Dictionary = {}
var castle_threat_scan_entries_by_region: Dictionary = {}
var reserved_recruitment_lock: Dictionary = {}

const BUILD_CASTLE_TYPE := CastleTypeEnum.Type.OUTPOST
const STRATEGIC_SCORE_SCALE := 10.0
const FRIENDLY_NEIGHBOR_VALUE := 15.0
const NEUTRAL_NEIGHBOR_VALUE := 5.0
const ENEMY_NEIGHBOR_PENALTY := 10.0
const ADJACENT_CASTLE_NEIGHBOR_PENALTY := 45.0
const CASTLE_SCORE_THRESHOLD := 100.0
const SMALL_CASTLE_TOPUP_LIMIT := 5
const MAX_DISTANCE := 9999
const THREAT_CASTLE_SAFE := "castle_safe"
const THREAT_NEEDS_ARMY := "needs_army"
const THREAT_UNKNOWN := "unknown"
const THREAT_BIG := "big"
const THREAT_VALUE_CASTLE_SAFE := 1
const THREAT_VALUE_NEEDS_ARMY := 2
const THREAT_VALUE_UNKNOWN := 2
const THREAT_VALUE_BIG := 4
const THREAT_LEVEL_NONE := 0
const THREAT_LEVEL_CASTLE_SAFE := 1
const THREAT_LEVEL_NEEDS_ARMY := 2
const THREAT_LEVEL_UNKNOWN := 3
const THREAT_LEVEL_BIG := 4
const THREAT_POWER_CHANGE_THRESHOLD := 0.15
const AI_UPGRADE_BANK_DEPOSIT_RATIO := 0.10
const CASTLE_RESERVE_GOLD_PER_RECRUIT := 10.0
const CASTLE_RESERVE_WOOD_PER_RECRUIT := 0.5
const CASTLE_RESERVE_IRON_PER_RECRUIT := 0.5
const UNIT_LOG_ORDER := [
	SoldierTypeEnum.Type.PEASANTS,
	SoldierTypeEnum.Type.SPEARMEN,
	SoldierTypeEnum.Type.ARCHERS,
	SoldierTypeEnum.Type.SWORDSMEN,
	SoldierTypeEnum.Type.CROSSBOWMEN,
	SoldierTypeEnum.Type.HORSEMEN,
	SoldierTypeEnum.Type.KNIGHTS,
	SoldierTypeEnum.Type.MOUNTED_KNIGHTS,
	SoldierTypeEnum.Type.ROYAL_GUARD
]
const UNIT_LOG_CODES := {
	SoldierTypeEnum.Type.PEASANTS: "P",
	SoldierTypeEnum.Type.SPEARMEN: "S",
	SoldierTypeEnum.Type.ARCHERS: "A",
	SoldierTypeEnum.Type.SWORDSMEN: "SW",
	SoldierTypeEnum.Type.CROSSBOWMEN: "C",
	SoldierTypeEnum.Type.HORSEMEN: "H",
	SoldierTypeEnum.Type.KNIGHTS: "K",
	SoldierTypeEnum.Type.MOUNTED_KNIGHTS: "MK",
	SoldierTypeEnum.Type.ROYAL_GUARD: "RG"
}

static var _region_distance_cache: Dictionary = {}
static var _cached_region_count: int = 0

func _init(_region_manager: RegionManager, _army_manager: ArmyManager, _player_manager: PlayerManagerNode, _game_manager: GameManager = null) -> void:
	region_manager = _region_manager
	army_manager = _army_manager
	player_manager = _player_manager
	game_manager = _game_manager
	budget_manager = BudgetManager.new()
	recruitment_manager = RecruitmentManager.new(region_manager, game_manager)
	trade_manager = game_manager.get_trade_manager()
	_reset_castle_threat_state()

func plan_turn(player_id: int, turn_number: int) -> Dictionary:
	return run_pre_move_economy_with_reserve_lock(player_id, turn_number)

func run_pre_move_economy_with_reserve_lock(player_id: int, turn_number: int) -> Dictionary:
	DebugLogger.log("AIEconomy", "\n=== AI ECONOMY TURN PLANNING (Player %d, Turn %d) ===" % [player_id, turn_number])
	
	# Snapshot signals and initialize per-turn threat/reserve cache.
	signals = _compute_signals(player_id, turn_number)
	garrison_skip_logs = []
	garrison_requests = []
	_reset_castle_threat_state()
	analyze_castle_threats_pre_move(player_id)

	var summary: Dictionary = {
		"decision": "sequential",
		"signals": signals
	}
	
	# Step 1: Deposit persistent upgrade savings bank at turn start (AI-only, turn>1).
	var upgrade_bank_result: Dictionary = _deposit_castle_upgrade_bank(player_id, turn_number)
	summary["castle_upgrade_bank"] = upgrade_bank_result

	# Step 2: Deposit persistent raise reserve bank (AI-only, dynamic activation).
	var raise_reserve_bank_result: Dictionary = _deposit_raise_army_reserve_bank(player_id)
	summary["raise_army_reserve_bank"] = raise_reserve_bank_result

	# Step 3: Army recruitment budgets (army flow unchanged)
	var army_recruitment = army_recruitments(player_id, turn_number)
	summary["army_recruitment"] = army_recruitment
	summary["castle_threats_pre_move"] = _format_castle_threat_summary_lines(player_id)
	summary["castle_reserve_pre_move"] = _format_castle_reserve_summary_lines(player_id)
	
	# Step 4: Sell surplus resources before castle upgrade decision.
	var trade_sell_result: Dictionary = _execute_ai_trade_sell_surplus(player_id)
	summary["trade_sell"] = trade_sell_result

	# Step 5: Upgrade castles (can use savings bank).
	var upgrade_castle = _evaluate_upgrade_castle(player_id, turn_number)
	summary["upgrade_castle"] = upgrade_castle
	
	# Step 6: Raise armies when allowed.
	var raise_res = decide_and_raise_army(player_id, turn_number)
	summary["raise"] = raise_res

	# Step 7: Build castles.
	var build_castle = _evaluate_build_castle(player_id, turn_number)
	summary["build_castle"] = build_castle

	# Step 8: Repair damaged castles
	var repair_castle = _evaluate_repair_castle(player_id)
	summary["repair_castle"] = repair_castle
	
	# Step 9: Upgrade regions
	var upgrade_region = _evaluate_upgrade_region(player_id, turn_number)
	summary["upgrade_region"] = upgrade_region
	
	# Step 10: Ore searches
	var ore_result = ore_checks(player_id)
	summary["ore"] = ore_result
	
	# Step 11: Buy food deficit after all economy actions.
	var trade_buy_food_result: Dictionary = _execute_ai_trade_buy_food_deficit(player_id)
	summary["trade_buy_food"] = trade_buy_food_result
	summary["trade"] = _merge_trade_results(trade_sell_result, trade_buy_food_result)
	
	summary["recruitment_candidates"] = army_recruitment["candidates"]
	DebugLogger.log("AIEconomy", "=== END AI ECONOMY TURN PLANNING ===\n")
	return summary

func run_post_move_castle_recruitment(player_id: int, turn_number: int) -> Dictionary:
	var _unused_turn_number: int = turn_number
	var threat_refresh: Dictionary = _refresh_castle_threats_after_movement(player_id)
	_recalculate_castle_reserve_budgets(player_id)
	var recruitment_result: Dictionary = _execute_reserved_castle_recruitment(player_id)
	var result: Dictionary = {
		"castle_threats_post_move": _format_castle_threat_summary_lines(player_id),
		"castle_reserve_post_move": _format_castle_reserve_summary_lines(player_id),
		"castle_threat_deltas": threat_refresh.get("deltas", []),
		"castle_recruitment_entries": recruitment_result.get("entries", []),
		"castle_recruitment_reason": String(recruitment_result.get("reason", "none")),
		"castle_recruitment_processed": int(recruitment_result.get("processed", 0)),
		"castle_recruitment_recruited": int(recruitment_result.get("recruited", 0))
	}
	_clear_reserved_recruitment_lock()
	return result

func analyze_castle_threats_pre_move(player_id: int) -> Dictionary:
	var refresh: Dictionary = _refresh_castle_threats_for_player(player_id, false)
	return {
		"castles_checked": int(refresh.get("castles_checked", 0)),
		"deltas": refresh.get("deltas", [])
	}

func get_castle_threat_snapshot(player_id: int) -> Dictionary:
	var threat_levels_by_region: Dictionary = {}
	var threat_registry_by_region: Dictionary = {}
	var ordered_regions: Array[int] = []
	for region_key in castle_threat_level_by_region.keys():
		ordered_regions.append(int(region_key))
	ordered_regions.sort()
	for region_id in ordered_regions:
		if region_manager.get_region_owner(region_id) != player_id:
			continue
		threat_levels_by_region[region_id] = int(castle_threat_level_by_region.get(region_id, THREAT_LEVEL_NONE))
		var region_registry: Dictionary = castle_threat_registry_by_region.get(region_id, {})
		var copied_registry: Dictionary = {}
		for threat_key in region_registry.keys():
			var threat_entry: Dictionary = region_registry.get(threat_key, {})
			copied_registry[threat_key] = threat_entry.duplicate(true)
		threat_registry_by_region[region_id] = copied_registry
	return {
		"threat_levels_by_region": threat_levels_by_region,
		"threat_registry_by_region": threat_registry_by_region
	}

func _evaluate_repair_castle(player_id: int) -> Dictionary:
	var player = player_manager.get_player(player_id)
	if player == null:
		return {"executed": false, "reason": "no_player", "repairs": []}
	var regions = region_manager.get_regions_with_castles(player_id)
	var repairs: Array = []
	for region in regions:
		if region.has_castle_damage() and not region.is_castle_under_repair():
			var cost = region.get_castle_repair_cost()
			if cost.is_empty():
				continue
			if not _can_afford_cost_with_reserve(player, cost):
				repairs.append({"region_id": region.get_region_id(), "reason": "no_resources"})
				continue
			if region_manager.try_repair_castle(region, player):
				repairs.append({"region_id": region.get_region_id(), "reason": "started"})
				DebugLogger.log("AIEconomy", "   REPAIR CASTLE: Started repair at region %s" % [region.get_region_name()])
				return {"executed": true, "repairs": repairs, "reason": "repair_started"}
	return {"executed": false, "repairs": repairs, "reason": "no_repair_started"}

func army_recruitments(player_id, turn_number):
	var armies_need = _find_recruitment_armies_at_castles(player_id, turn_number)
	var castle_requests: Array = _build_shared_castle_recruitment_requests(player_id)
	garrison_requests = castle_requests
	var recruitment_candidates_desc = _describe_recruitment_candidates(armies_need)
	var army_recruitment: Dictionary = {
		"needs": armies_need.size(),
		"candidates": recruitment_candidates_desc,
		"garrison_danger": 0,
		"garrison_skip_logs": []
	}
	var assigned_budgets = _allocate_recruitment(player_id, turn_number, castle_requests)
	assigned_budgets = _ensure_recruitment_budgets_assigned(player_id, turn_number, armies_need, assigned_budgets)
	assigned_budgets = _prioritize_army_recruitment_budgets_for_minimum_power(player_id, turn_number, armies_need, assigned_budgets)
	_sync_castle_reserved_budget_from_requests(castle_requests)
	army_recruitment["budgets_assigned"] = assigned_budgets
	var army_hires = _execute_army_recruitment(player_id, armies_need, turn_number)
	army_recruitment["army_hires"] = army_hires
	army_recruitment["garrison_defense_entries"] = []
	army_recruitment["garrison_defense_reason"] = "deferred_to_post_move"
	return army_recruitment

func _prioritize_army_recruitment_budgets_for_minimum_power(player_id: int, turn_number: int, armies_need: Array[Army], assigned_count: int) -> int:
	recruitment_manager.clear_committed_army_recruitment_plans()
	var candidates: Array[Dictionary] = _build_recruitment_budget_candidates(player_id, turn_number, armies_need)
	if candidates.size() <= 1:
		return assigned_count
	var resource_pool: Dictionary = _build_army_recruitment_resource_pool(candidates)
	var recruit_pool_by_region: Dictionary = _build_army_recruitment_recruit_pool_by_region(candidates)
	var active_candidates: Array[Dictionary] = candidates.duplicate()
	var final_simulation: Dictionary = {}
	while active_candidates.size() > 1:
		final_simulation = _simulate_recruitment_candidate_subset(active_candidates, resource_pool, recruit_pool_by_region, turn_number)
		if bool(final_simulation.get("all_pass", false)):
			break
		var remove_candidate: Dictionary = final_simulation.get("remove_candidate", {})
		if remove_candidate.is_empty():
			break
		_remove_recruitment_candidate_by_id(active_candidates, int(remove_candidate.get("army_id", 0)))
	if active_candidates.size() == 1:
		final_simulation = _simulate_recruitment_candidate_subset(active_candidates, resource_pool, recruit_pool_by_region, turn_number)
	_commit_prioritized_recruitment_candidates(candidates, active_candidates, final_simulation)
	return active_candidates.size()

func _build_recruitment_budget_candidates(player_id: int, turn_number: int, armies_need: Array[Army]) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for army in armies_need:
		if army.get_assigned_budget() == null:
			continue
		var region: Region = army.get_parent() as Region
		if region_manager.get_region_owner(region.get_region_id()) != player_id:
			continue
		var current_power: int = army.get_army_power()
		var threshold: float = army.get_recruitment_threshold(turn_number, false, true, false)
		candidates.append({
			"army": army,
			"army_id": army.get_instance_id(),
			"region_id": region.get_region_id(),
			"current_power": current_power,
			"threshold": threshold,
			"initial_shortfall": max(0.0, threshold - float(current_power))
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_shortfall: float = float(a.get("initial_shortfall", 0.0))
		var b_shortfall: float = float(b.get("initial_shortfall", 0.0))
		if abs(a_shortfall - b_shortfall) > 0.001:
			return a_shortfall < b_shortfall
		var a_power: int = int(a.get("current_power", 0))
		var b_power: int = int(b.get("current_power", 0))
		if a_power != b_power:
			return a_power > b_power
		var a_region_id: int = int(a.get("region_id", -1))
		var b_region_id: int = int(b.get("region_id", -1))
		if a_region_id != b_region_id:
			return a_region_id < b_region_id
		return int(a.get("army_id", 0)) < int(b.get("army_id", 0))
	)
	return candidates

func _build_army_recruitment_resource_pool(candidates: Array[Dictionary]) -> Dictionary:
	var pool: Dictionary = {
		ResourcesEnum.Type.GOLD: 0,
		ResourcesEnum.Type.WOOD: 0,
		ResourcesEnum.Type.IRON: 0
	}
	for candidate in candidates:
		var army: Army = candidate.get("army")
		var budget: BudgetComposition = army.get_assigned_budget()
		pool[ResourcesEnum.Type.GOLD] = int(pool.get(ResourcesEnum.Type.GOLD, 0)) + budget.gold
		pool[ResourcesEnum.Type.WOOD] = int(pool.get(ResourcesEnum.Type.WOOD, 0)) + budget.wood
		pool[ResourcesEnum.Type.IRON] = int(pool.get(ResourcesEnum.Type.IRON, 0)) + budget.iron
	return pool

func _build_army_recruitment_recruit_pool_by_region(candidates: Array[Dictionary]) -> Dictionary:
	var pool_by_region: Dictionary = {}
	for candidate in candidates:
		var army: Army = candidate.get("army")
		var budget: BudgetComposition = army.get_assigned_budget()
		var region_id: int = int(candidate.get("region_id", -1))
		pool_by_region[region_id] = int(pool_by_region.get(region_id, 0)) + budget.available_recruits
	return pool_by_region

func _simulate_recruitment_candidate_subset(candidates: Array[Dictionary], resource_pool: Dictionary, recruit_pool_by_region: Dictionary, turn_number: int) -> Dictionary:
	var budgets_by_army_id: Dictionary = _build_recruitment_budgets_for_candidate_subset(candidates, resource_pool, recruit_pool_by_region)
	var evaluations: Array[Dictionary] = []
	var all_pass: bool = true
	var remove_candidate: Dictionary = {}
	for candidate in candidates:
		var army: Army = candidate.get("army")
		var army_id: int = int(candidate.get("army_id", 0))
		var budget: BudgetComposition = budgets_by_army_id.get(army_id)
		var plan: Dictionary = recruitment_manager.preview_army_recruitment(army, budget)
		var projected_power: int = int(plan.get("projected_power", army.get_army_power()))
		var threshold: float = float(candidate.get("threshold", army.get_recruitment_threshold(turn_number, false, true, false)))
		var projected_shortfall: float = max(0.0, threshold - float(projected_power))
		var passed: bool = projected_shortfall <= 0.001
		var evaluation: Dictionary = {
			"army": army,
			"army_id": army_id,
			"budget": budget,
			"plan": plan,
			"projected_power": projected_power,
			"projected_shortfall": projected_shortfall,
			"passed": passed
		}
		evaluations.append(evaluation)
		if not passed:
			all_pass = false
			if remove_candidate.is_empty() or _is_recruitment_defer_candidate_worse(evaluation, remove_candidate):
				remove_candidate = evaluation
	return {
		"all_pass": all_pass,
		"evaluations": evaluations,
		"remove_candidate": remove_candidate
	}

func _build_recruitment_budgets_for_candidate_subset(candidates: Array[Dictionary], resource_pool: Dictionary, recruit_pool_by_region: Dictionary) -> Dictionary:
	var budgets_by_army_id: Dictionary = {}
	var count: int = candidates.size()
	var gold_split: Array[int] = _split_amount_by_order(int(resource_pool.get(ResourcesEnum.Type.GOLD, 0)), count)
	var wood_split: Array[int] = _split_amount_by_order(int(resource_pool.get(ResourcesEnum.Type.WOOD, 0)), count)
	var iron_split: Array[int] = _split_amount_by_order(int(resource_pool.get(ResourcesEnum.Type.IRON, 0)), count)
	var recruit_split_by_index: Dictionary = _split_recruit_caps_by_candidate_region(candidates, recruit_pool_by_region)
	for idx in range(candidates.size()):
		var candidate: Dictionary = candidates[idx]
		var army_id: int = int(candidate.get("army_id", 0))
		budgets_by_army_id[army_id] = BudgetComposition.new(
			int(gold_split[idx]),
			int(wood_split[idx]),
			int(iron_split[idx]),
			int(recruit_split_by_index.get(idx, 0))
		)
	return budgets_by_army_id

func _split_recruit_caps_by_candidate_region(candidates: Array[Dictionary], recruit_pool_by_region: Dictionary) -> Dictionary:
	var indices_by_region: Dictionary = {}
	for idx in range(candidates.size()):
		var region_id: int = int(candidates[idx].get("region_id", -1))
		if not indices_by_region.has(region_id):
			indices_by_region[region_id] = []
		var indices: Array = indices_by_region.get(region_id, [])
		indices.append(idx)
		indices_by_region[region_id] = indices
	var split_by_index: Dictionary = {}
	var ordered_regions: Array = indices_by_region.keys()
	ordered_regions.sort()
	for region_id in ordered_regions:
		var region_indices: Array = indices_by_region.get(region_id, [])
		var shares: Array[int] = _split_amount_by_order(int(recruit_pool_by_region.get(region_id, 0)), region_indices.size())
		for local_idx in range(region_indices.size()):
			split_by_index[int(region_indices[local_idx])] = int(shares[local_idx])
	return split_by_index

func _split_amount_by_order(total_amount: int, recipient_count: int) -> Array[int]:
	var result: Array[int] = []
	if recipient_count <= 0:
		return result
	var base_amount: int = 0
	var remainder: int = 0
	if total_amount > 0:
		base_amount = int(total_amount / recipient_count)
		remainder = total_amount % recipient_count
	for idx in range(recipient_count):
		var amount: int = base_amount
		if idx < remainder:
			amount += 1
		result.append(amount)
	return result

func _is_recruitment_defer_candidate_worse(candidate: Dictionary, current_worst: Dictionary) -> bool:
	var candidate_shortfall: float = float(candidate.get("projected_shortfall", 0.0))
	var current_shortfall: float = float(current_worst.get("projected_shortfall", 0.0))
	if abs(candidate_shortfall - current_shortfall) > 0.001:
		return candidate_shortfall > current_shortfall
	var candidate_army: Army = candidate.get("army")
	var current_army: Army = current_worst.get("army")
	var candidate_power: int = candidate_army.get_army_power()
	var current_power: int = current_army.get_army_power()
	if candidate_power != current_power:
		return candidate_power < current_power
	return int(candidate.get("army_id", 0)) > int(current_worst.get("army_id", 0))

func _remove_recruitment_candidate_by_id(candidates: Array[Dictionary], army_id: int) -> void:
	for idx in range(candidates.size() - 1, -1, -1):
		if int(candidates[idx].get("army_id", 0)) == army_id:
			candidates.remove_at(idx)
			return

func _commit_prioritized_recruitment_candidates(all_candidates: Array[Dictionary], accepted_candidates: Array[Dictionary], simulation: Dictionary) -> void:
	var accepted_ids: Dictionary = {}
	for candidate in accepted_candidates:
		accepted_ids[int(candidate.get("army_id", 0))] = true
	for candidate in all_candidates:
		var army: Army = candidate.get("army")
		var army_id: int = int(candidate.get("army_id", 0))
		if accepted_ids.has(army_id):
			continue
		army.assigned_budget = null
		army.request_recruitment()
		DebugLogger.log("AIRecruitment", "Deferred " + army.get_display_name() + " from recruitment budget (reason: deferred_minimum_power_budget)")
	var evaluations: Array = simulation.get("evaluations", [])
	for evaluation in evaluations:
		var army: Army = evaluation.get("army")
		var budget: BudgetComposition = evaluation.get("budget")
		var plan: Dictionary = evaluation.get("plan", {})
		army.assign_recruitment_budget(budget)
		recruitment_manager.commit_army_recruitment_plan(army, plan)

func ore_checks(player_id: int) -> Dictionary:
	var player := player_manager.get_player(player_id)
	var owned_regions := region_manager.get_player_regions(player_id)
	var search_cost := GameParameters.get_ore_search_cost()
	var attempts := 0
	var successes := 0
	var gold_spent := 0
	var discovered_regions: Array[String] = []
	var had_candidates := false
	for region_id in owned_regions:
		if _get_spendable_resource(player, ResourcesEnum.Type.GOLD) < search_cost:
			break
		var region := region_manager.map_generator.get_region_container_by_id(region_id) as Region
		if region.can_search_for_ore():
			had_candidates = true
			var result = region.search_for_ore()
			player.remove_resources(ResourcesEnum.Type.GOLD, search_cost)
			attempts += 1
			gold_spent += search_cost
			if result.get("success", false):
				successes += 1
				discovered_regions.append(region.get_region_name())
	var reason = "none"
	if attempts == 0:
		reason = "no_gold" if had_candidates else "no_regions"
	return {
		"attempts": attempts,
		"discoveries": successes,
		"gold_spent": gold_spent,
		"discovered_regions": discovered_regions,
		"reason": reason
	}

# Signals summarize state. Extended for raise army decisions.
func _compute_signals(player_id: int, turn_number: int) -> Dictionary:
	var owned_regions = region_manager.get_player_regions(player_id)
	var frontier_regions = region_manager.get_frontier_regions(player_id)
	var armies = army_manager.get_player_armies(player_id)
	var player = player_manager.get_player(player_id)
	
	# Calculate frontier pressure
	var frontier_pressure = 0.0
	if owned_regions.size() > 0:
		frontier_pressure = float(frontier_regions.size()) / float(owned_regions.size())
	
	# Calculate underpowered ratio
	var underpowered_count = 0
	var target_power = GameParameters.AI_TARGET_ARMY_POWER
	for army in armies:
		if army.get_army_power() < target_power:
			underpowered_count += 1
	var underpowered_ratio = 0.0
	if armies.size() > 0:
		underpowered_ratio = float(underpowered_count) / float(armies.size())
	
	# Calculate castle spacing (average distance between castles)
	var castle_regions = []
	for region_id in owned_regions:
		if region_manager.get_castle_level(region_id) >= 1:
			castle_regions.append(region_id)
	var castle_spacing = 0.0
	if castle_regions.size() > 0:
		castle_spacing = float(owned_regions.size()) / float(castle_regions.size())
	
	# Calculate bank ratio (current gold vs a target reserve)
	var bank_ratio = 0.0
	var target_bank = 50  # Target gold reserve
	bank_ratio = min(1.0, float(player.get_resource_amount(ResourcesEnum.Type.GOLD)) / float(target_bank))
	
	# Calculate normalized power gap (simplified)
	var power_gap_norm = 0.0
	if armies.size() > 0:
		var avg_power = 0
		for army in armies:
			avg_power += army.get_army_power()
		avg_power = avg_power / armies.size()
		power_gap_norm = max(0.0, (target_power - avg_power) / target_power)
	
	DebugLogger.log("AIEconomy", "Signals: " + str({
		"frontier_pressure": frontier_pressure,
		"underpowered_ratio": underpowered_ratio,
		"castle_spacing": castle_spacing,
		"bank_ratio": bank_ratio,
		"power_gap_norm": power_gap_norm,
		"army_power_gap": 0.0,
		"resource_scarcity": {},
		"recruit_abundance": 0.0,
		"turn_index": float(turn_number)
	}))	

	return {
		"frontier_pressure": frontier_pressure,
		"underpowered_ratio": underpowered_ratio,
		"castle_spacing": castle_spacing,
		"bank_ratio": bank_ratio,
		"power_gap_norm": power_gap_norm,
		"army_power_gap": 0.0,
		"resource_scarcity": {},
		"recruit_abundance": 0.0,
		"turn_index": float(turn_number)
	}

# Turn signals to weights per category. Stub: recruit always enabled.
func _score_categories(signals: Dictionary) -> Dictionary:
	# Kept for potential future bucket weighting; not used in priority flow
	return {"recruit": 1.0}

# Pick active categories (weight > 0). Deterministic order.
func _pick_categories(weights: Dictionary) -> Array:
	# Deprecated for current flow; present for API stability
	return ["recruit"]

# Delegate to existing BudgetManager to keep compatibility with recruitment flow.
func _allocate_recruitment(player_id: int, turn_number: int, castle_garrison_requests: Array = []) -> int:
	var player = player_manager.get_player(player_id)
	var armies: Array[Army] = army_manager.get_player_armies(player_id)
	var resource_caps: Dictionary = {
		ResourcesEnum.Type.GOLD: _get_spendable_resource(player, ResourcesEnum.Type.GOLD),
		ResourcesEnum.Type.WOOD: _get_spendable_resource(player, ResourcesEnum.Type.WOOD),
		ResourcesEnum.Type.IRON: _get_spendable_resource(player, ResourcesEnum.Type.IRON)
	}
	return budget_manager.allocate_recruitment_budgets(armies, player, region_manager, turn_number, castle_garrison_requests, resource_caps)

func _ensure_recruitment_budgets_assigned(player_id: int, _turn_number: int, armies_need: Array[Army], assigned_count: int) -> int:
	var missing_armies: Array[Army] = []
	for army in armies_need:
		var army_region: Region = army.get_parent() as Region
		if region_manager.get_region_owner(army_region.get_region_id()) != player_id:
			continue
		if army.get_assigned_budget() == null:
			missing_armies.append(army)
	if missing_armies.is_empty():
		return assigned_count
	var total_assigned: int = assigned_count
	for army in missing_armies:
		if army.get_assigned_budget() != null:
			continue
		var army_region: Region = army.get_parent() as Region
		if region_manager.get_region_owner(army_region.get_region_id()) != player_id:
			continue
		var recruits_available: int = _get_castle_recruit_source_total(army_region.get_region_id(), player_id)
		army.assign_recruitment_budget(BudgetComposition.new(0, 0, 0, recruits_available))
		total_assigned += 1
		DebugLogger.log("AIRecruitment", "Fallback budget applied for %s at %s" % [
			army.get_display_name(),
			army_region.get_region_name()
		])
	return total_assigned

func _build_shared_castle_recruitment_requests(player_id: int) -> Array:
	var requests: Array = []
	var ordered_regions: Array[int] = []
	for region_key in castle_total_threat_value_by_region.keys():
		ordered_regions.append(int(region_key))
	ordered_regions.sort()
	for region_id in ordered_regions:
		if region_manager.get_region_owner(region_id) != player_id:
			continue
		var region: Region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
		if not region.has_castle():
			continue
		var threat_level: int = int(castle_threat_level_by_region.get(region_id, THREAT_LEVEL_NONE))
		var total_threat_value: int = int(castle_total_threat_value_by_region.get(region_id, 0))
		if threat_level <= THREAT_LEVEL_CASTLE_SAFE or total_threat_value <= 0:
			continue
		requests.append({
			"region_id": region_id,
			"region": region,
			"assigned_budget": null,
			"weight": 1.0
		})
	return requests

func _sync_castle_reserved_budget_from_requests(castle_requests: Array) -> void:
	castle_reserved_budget_by_region.clear()
	_clear_reserved_recruitment_lock()
	var lock_gold: int = 0
	var lock_wood: int = 0
	var lock_iron: int = 0
	for request_variant in castle_requests:
		var request: Dictionary = request_variant
		var region_id: int = int(request.get("region_id", -1))
		if region_id < 0:
			continue
		var assigned_budget: BudgetComposition = request.get("assigned_budget", null)
		if assigned_budget == null:
			continue
		var capped_budget: BudgetComposition = _apply_castle_reserve_resource_caps(assigned_budget, assigned_budget.available_recruits)
		castle_reserved_budget_by_region[region_id] = capped_budget
		lock_gold += capped_budget.gold
		lock_wood += capped_budget.wood
		lock_iron += capped_budget.iron
	reserved_recruitment_lock = {
		ResourcesEnum.Type.GOLD: lock_gold,
		ResourcesEnum.Type.WOOD: lock_wood,
		ResourcesEnum.Type.IRON: lock_iron
	}

func _get_upgrade_bank_gold_cap() -> int:
	var stronghold_cost: Dictionary = GameParameters.get_castle_building_cost(CastleTypeEnum.Type.STRONGHOLD)
	var stronghold_gold_cost: int = max(0, int(stronghold_cost.get(ResourcesEnum.Type.GOLD, 0)))
	if stronghold_gold_cost <= 0:
		return 0
	return int(ceil(float(stronghold_gold_cost) * 1.25))

func _get_upgrade_bank_locked_gold(player: Player) -> int:
	var cap: int = _get_upgrade_bank_gold_cap()
	return clampi(player.get_ai_castle_upgrade_savings_gold(), 0, cap)

func _deposit_castle_upgrade_bank(player_id: int, turn_number: int) -> Dictionary:
	var player: Player = player_manager.get_player(player_id)
	var cap: int = _get_upgrade_bank_gold_cap()
	if not player.is_computer():
		return {"added": 0, "bank": player.get_ai_castle_upgrade_savings_gold(), "cap": cap, "reason": "not_ai"}
	if turn_number <= 1:
		_log_trade("Castle Upgrade Bank: skipped (turn_1)")
		return {"added": 0, "bank": player.get_ai_castle_upgrade_savings_gold(), "cap": cap, "reason": "turn_1"}
	if cap <= 0:
		return {"added": 0, "bank": player.get_ai_castle_upgrade_savings_gold(), "cap": cap, "reason": "no_cap"}
	var current_bank: int = _get_upgrade_bank_locked_gold(player)
	if current_bank >= cap:
		_log_trade("Castle Upgrade Bank: skipped (at_cap, bank:%d cap:%d)" % [current_bank, cap])
		return {"added": 0, "bank": current_bank, "cap": cap, "reason": "at_cap"}
	var spendable_gold: int = _get_spendable_resource(player, ResourcesEnum.Type.GOLD)
	var planned_add: int = int(floor(float(spendable_gold) * AI_UPGRADE_BANK_DEPOSIT_RATIO))
	var max_add: int = max(0, cap - current_bank)
	var add_amount: int = min(planned_add, max_add)
	if add_amount <= 0:
		_log_trade("Castle Upgrade Bank: skipped (no_spendable_gold)")
		return {"added": 0, "bank": current_bank, "cap": cap, "reason": "no_spendable_gold"}
	var new_bank: int = player.add_ai_castle_upgrade_savings_gold(add_amount)
	if new_bank > cap:
		player.set_ai_castle_upgrade_savings_gold(cap)
		new_bank = cap
	_log_trade("Castle Upgrade Bank: added:%d bank:%d cap:%d" % [add_amount, new_bank, cap])
	return {"added": add_amount, "bank": new_bank, "cap": cap, "reason": "deposited"}

func _spend_castle_upgrade_bank_for_gold_cost(player: Player, gold_cost_paid: int) -> int:
	if gold_cost_paid <= 0:
		return 0
	var used_from_bank: int = player.spend_ai_castle_upgrade_savings_gold(gold_cost_paid)
	if used_from_bank > 0:
		var remaining_bank: int = player.get_ai_castle_upgrade_savings_gold()
		var cap: int = _get_upgrade_bank_gold_cap()
		_log_trade("Castle Upgrade Bank: used:%d remaining:%d cap:%d" % [used_from_bank, remaining_bank, cap])
	return used_from_bank

func _release_castle_upgrade_bank(player: Player, release_reason: String) -> int:
	var released_gold: int = _get_upgrade_bank_locked_gold(player)
	if released_gold <= 0:
		return 0
	player.set_ai_castle_upgrade_savings_gold(0)
	var cap: int = _get_upgrade_bank_gold_cap()
	_log_trade("Castle Upgrade Bank: released:%d bank:%d cap:%d reason:%s" % [released_gold, 0, cap, release_reason])
	return released_gold

func _get_raise_army_reserve_gold_cap() -> int:
	return max(0, int(GameParameters.RAISE_ARMY_COST))

func _get_raise_army_reserve_locked_gold(player: Player) -> int:
	var cap: int = _get_raise_army_reserve_gold_cap()
	return clampi(player.get_ai_raise_army_savings_gold(), 0, cap)

func _has_severe_castle_threats(player_id: int) -> bool:
	for region_key in castle_threat_level_by_region.keys():
		var region_id: int = int(region_key)
		if region_manager.get_region_owner(region_id) != player_id:
			continue
		var threat_level: int = int(castle_threat_level_by_region.get(region_id, THREAT_LEVEL_NONE))
		if threat_level >= THREAT_LEVEL_NEEDS_ARMY:
			return true
	return false

func _has_raise_intent_opportunity(player_id: int) -> bool:
	var armies_count: int = army_manager.get_player_armies(player_id).size()
	if armies_count == 0:
		return true
	var candidate: Dictionary = pick_best_raise_region(player_id)
	if not candidate.is_empty():
		return true
	return _has_raise_savings_opportunity(player_id)

func _has_raise_savings_opportunity(player_id: int) -> bool:
	var owned_regions: Array[int] = region_manager.get_player_regions(player_id)
	for region_id in owned_regions:
		if region_manager.get_castle_level(region_id) < 2:
			continue
		var region_container: Region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
		if army_manager.is_region_at_army_cap(region_container):
			continue
		return true
	return false

func _deposit_raise_army_reserve_bank(player_id: int) -> Dictionary:
	var player: Player = player_manager.get_player(player_id)
	var cap: int = _get_raise_army_reserve_gold_cap()
	if not player.is_computer():
		return {"added": 0, "bank": player.get_ai_raise_army_savings_gold(), "cap": cap, "reason": "not_ai"}
	if cap <= 0:
		return {"added": 0, "bank": player.get_ai_raise_army_savings_gold(), "cap": cap, "reason": "no_cap"}
	var current_bank: int = _get_raise_army_reserve_locked_gold(player)
	if _has_severe_castle_threats(player_id):
		var released_gold: int = _release_raise_army_reserve(player, "severe_castle_threat")
		if released_gold > 0:
			return {"added": 0, "bank": player.get_ai_raise_army_savings_gold(), "cap": cap, "reason": "severe_castle_threat_release", "released": released_gold}
		_log_trade("Raise Army Reserve: skipped (severe_castle_threat)")
		return {"added": 0, "bank": current_bank, "cap": cap, "reason": "severe_castle_threat"}
	if not _has_raise_intent_opportunity(player_id):
		_log_trade("Raise Army Reserve: skipped (no_raise_intent)")
		return {"added": 0, "bank": current_bank, "cap": cap, "reason": "no_raise_intent"}
	if current_bank >= cap:
		_log_trade("Raise Army Reserve: skipped (at_cap, bank:%d cap:%d)" % [current_bank, cap])
		return {"added": 0, "bank": current_bank, "cap": cap, "reason": "at_cap"}
	var spendable_gold: int = _get_spendable_resource(player, ResourcesEnum.Type.GOLD)
	var add_amount: int = min(max(0, cap - current_bank), spendable_gold)
	if add_amount <= 0:
		_log_trade("Raise Army Reserve: skipped (no_spendable_gold)")
		return {"added": 0, "bank": current_bank, "cap": cap, "reason": "no_spendable_gold"}
	var new_bank: int = player.add_ai_raise_army_savings_gold(add_amount)
	if new_bank > cap:
		player.set_ai_raise_army_savings_gold(cap)
		new_bank = cap
	_log_trade("Raise Army Reserve: added:%d bank:%d cap:%d" % [add_amount, new_bank, cap])
	return {"added": add_amount, "bank": new_bank, "cap": cap, "reason": "deposited"}

func _spend_raise_army_reserve_for_gold_cost(player: Player, gold_cost_paid: int) -> int:
	if gold_cost_paid <= 0:
		return 0
	var used_from_reserve: int = player.spend_ai_raise_army_savings_gold(gold_cost_paid)
	if used_from_reserve > 0:
		var remaining_reserve: int = player.get_ai_raise_army_savings_gold()
		var cap: int = _get_raise_army_reserve_gold_cap()
		_log_trade("Raise Army Reserve: used:%d remaining:%d cap:%d" % [used_from_reserve, remaining_reserve, cap])
	return used_from_reserve

func _release_raise_army_reserve(player: Player, release_reason: String) -> int:
	var released_gold: int = _get_raise_army_reserve_locked_gold(player)
	if released_gold <= 0:
		return 0
	player.set_ai_raise_army_savings_gold(0)
	var cap: int = _get_raise_army_reserve_gold_cap()
	_log_trade("Raise Army Reserve: released:%d bank:%d cap:%d reason:%s" % [released_gold, 0, cap, release_reason])
	return released_gold

func _execute_army_recruitment(player_id: int, armies: Array[Army], turn_number: int) -> Array[String]:
	var entries: Array[String] = []
	if recruitment_manager == null:
		return entries
	for army in armies:
		if army == null or not is_instance_valid(army):
			continue
		var location := army.get_parent() as Region
		if location == null:
			continue
		if region_manager.get_region_owner(location.get_region_id()) != player_id:
			continue
		var budget = army.assigned_budget
		if budget == null:
			continue
		var result = recruitment_manager.hire_soldiers(army, false)
		var total := int(result.get("total_recruited", 0))
		if total > 0:
			var entry = _format_army_hire_entry(army, location, result)
			entries.append(entry)
		if army.needs_recruitment(turn_number, false, true, false):
			army.request_recruitment()
			DebugLogger.log("AIRecruitment", "Army " + army.get_display_name() + " remains below minimal recruitment threshold after recruitment")
	return entries

# Find armies at castles that need recruitment
func _find_recruitment_armies_at_castles(player_id: int, turn_number: int) -> Array[Army]:
	var out: Array[Army] = []
	var armies = army_manager.get_player_armies(player_id)
	var force_first_turn_recruitment: bool = turn_number <= 1
	for a in armies:
		var needs_recruit: bool = force_first_turn_recruitment or a.is_recruitment_requested()
		if not needs_recruit:
			continue
		a.request_recruitment()
		var r: Region = a.get_parent()
		var rid = r.get_region_id()
		if region_manager.get_region_owner(rid) != player_id:
			continue
		if region_manager.get_castle_level(rid) >= 1:
			out.append(a)
	return out

# Main orchestrator for raise army decision
func decide_and_raise_army(player_id: int, turn_number: int) -> Dictionary:
	DebugLogger.log("AIEconomy", "   Evaluating raise army decision...")
	var candidate = pick_best_raise_region(player_id)
	var player = player_manager.get_player(player_id)
	
	if candidate.is_empty():
		if _has_raise_savings_opportunity(player_id):
			DebugLogger.log("AIEconomy", "   Decision: NO - Waiting for raise recruits")
			return {"raised": false, "reason": "waiting_for_recruits", "score_text": "", "score": 0.0}
		var released_raise_reserve_gold: int = _release_raise_army_reserve(player, "no_candidate")
		DebugLogger.log("AIEconomy", "   Decision: NO - No valid castle regions with sufficient recruits")
		return {"raised": false, "reason": "no_candidate", "score_text": "", "score": 0.0, "released_raise_reserve_gold": released_raise_reserve_gold}
	
	DebugLogger.log("AIEconomy", "   Best candidate: Region %d (recruits: %d, score: %.1f)" % [candidate["region_id"], candidate["recruits_total"], candidate["score"]])
	
	var raise_eval: Dictionary = should_raise_army(candidate, player)
	var should_raise: bool = bool(raise_eval.get("decision", false))
	var score_text: String = String(raise_eval.get("score_text", ""))
	var raise_reason: String = String(raise_eval.get("reason", "guards_failed"))
	if should_raise:
		DebugLogger.log("AIEconomy", "   Decision: YES - All constraints satisfied")
		var success = execute_raise_army(player_id, candidate["region_id"])
		if success:
			DebugLogger.log("AIEconomy", "   Execution: SUCCESS - Army raised at region %d" % candidate["region_id"])
			return {"raised": true, "region_id": candidate["region_id"], "score_text": score_text, "score": float(raise_eval.get("score", 0.0)), "reason": "raised"}
		else:
			DebugLogger.log("AIEconomy", "   Execution: FAILED - Could not deduct gold cost")
			return {"raised": false, "reason": "execution_failed", "score_text": score_text, "score": float(raise_eval.get("score", 0.0))}
	else:
		return {"raised": false, "reason": raise_reason, "score_text": score_text, "score": float(raise_eval.get("score", 0.0))}

# Pick the best castle region to raise an army at
func pick_best_raise_region(player_id: int) -> Dictionary:
	DebugLogger.log("AIEconomy", "   Searching for castle regions with sufficient recruits...")
	var owned_regions = region_manager.get_player_regions(player_id)
	var armies_count: int = army_manager.get_player_armies(player_id).size()
	var is_first_army_bootstrap: bool = armies_count == 0
	var candidates = []
	var max_recruits_seen = 1
	var castles_checked = 0
	
	# Gather candidates
	for region_id in owned_regions:
		if region_manager.get_castle_level(region_id) < 2:
			continue
		castles_checked += 1
		var region_container := region_manager.map_generator.get_region_container_by_id(region_id)
		if army_manager.is_region_at_army_cap(region_container):
			continue
		
		# Calculate total recruits from region and neighbors
		var recruits_total = _sum_castle_recruits(region_id, player_id)
		
		DebugLogger.log("AIEconomy", "   Castle %d: %d recruits (min: %d)" % [region_id, recruits_total, GameParameters.AI_MIN_RECRUITS_FOR_RAISING])
		
		if not is_first_army_bootstrap and recruits_total < GameParameters.AI_MIN_RECRUITS_FOR_RAISING:
			continue
		
		max_recruits_seen = max(max_recruits_seen, recruits_total)
		
		# Check if this region is on the frontier
		var neighbors = region_manager.get_neighbor_regions(region_id)
		var frontier_near = 0
		var travel_hint = 0
		
		for neighbor_id in neighbors:
			var neighbor_owner = region_manager.get_region_owner(neighbor_id)
			if neighbor_owner != player_id:
				frontier_near = 1
				travel_hint = 1
				break
		
		# If not directly on frontier, check if any frontier exists (for travel hint)
		if travel_hint == 0:
			var frontier_regions = region_manager.get_frontier_regions(player_id)
			if frontier_regions.size() > 0:
				travel_hint = 1

		var free_garrison_bonus: float = _get_raise_free_garrison_bonus(region_id, player_id)
		
		candidates.append({
			"region_id": region_id,
			"recruits_total": recruits_total,
			"frontier_near": frontier_near,
			"travel_hint": travel_hint,
			"free_garrison_bonus": free_garrison_bonus
		})
	
	DebugLogger.log("AIEconomy", "   Checked %d castles, found %d valid candidates" % [castles_checked, candidates.size()])
	
	if candidates.is_empty():
		return {}
	
	# Score candidates
	for candidate in candidates:
		var recruits_norm = float(candidate["recruits_total"]) / float(max_recruits_seen)
		var score = GameParameters.AI_CAND_W_RECRUITS * recruits_norm
		score += GameParameters.AI_CAND_W_FRONTIER_NEAR * candidate["frontier_near"]
		score += GameParameters.AI_CAND_W_TRAVEL * candidate["travel_hint"]
		score += float(candidate.get("free_garrison_bonus", 0.0))
		candidate["score"] = score
		DebugLogger.log("AIEconomy", "   Candidate %d: score %.1f (recruits: %.2f*%.1f, frontier: %d*%.1f, travel: %d*%.1f, free_garrison: %.1f)" % [
			candidate["region_id"], score,
			recruits_norm, GameParameters.AI_CAND_W_RECRUITS,
			candidate["frontier_near"], GameParameters.AI_CAND_W_FRONTIER_NEAR,
			candidate["travel_hint"], GameParameters.AI_CAND_W_TRAVEL,
			float(candidate.get("free_garrison_bonus", 0.0))
		])
	
	# Pick highest score with deterministic tie-break
	candidates.sort_custom(func(a, b): 
		if abs(a["score"] - b["score"]) < 0.001:
			return a["region_id"] < b["region_id"]  # Tie-break by region_id
		return a["score"] > b["score"]
	)

	DebugLogger.log("AIEconomy", "   Winner: Region %d (score: %.1f)" % [candidates[0]["region_id"], candidates[0]["score"]])
	
	return candidates[0]

func _get_raise_free_garrison_bonus(region_id: int, player_id: int) -> float:
	var region: Region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
	var needy_armies: int = _count_recruitment_requested_armies_in_region(region, player_id)
	if needy_armies > 0:
		return 0.0
	var enemy_army_ids: Dictionary = region.castle_nearby_entities.get("enemy_army_ids", {})
	if not enemy_army_ids.is_empty():
		return 0.0
	return float(region.get_garrison_strength()) / 4.0

func _count_recruitment_requested_armies_in_region(region: Region, player_id: int) -> int:
	var count: int = 0
	var armies_in_region: Array[Army] = army_manager.get_armies_in_region(region)
	for region_army in armies_in_region:
		if region_army.get_player_id() != player_id:
			continue
		if region_army.is_recruitment_requested():
			count += 1
	return count

# Decide whether to raise an army this turn
func should_raise_army(candidate: Dictionary, player: Player) -> Dictionary:
	# New normalized model: region/army ratio, avg distance (MP), recruits, gold
	if candidate.is_empty():
		DebugLogger.log("AIEconomy", "   Constraint: NO_CANDIDATE")
		return {"decision": false, "reason": "no_candidate", "score_text": "", "score": 0.0}
	
	var regions := region_manager.get_player_regions(player.get_player_id()).size()
	var armies_arr := army_manager.get_player_armies(player.get_player_id())
	var armies_count := armies_arr.size()
	
	# Average MP distance from existing armies to the candidate castle
	var castle_id: int = candidate["region_id"]
	var avg_dist := _compute_avg_distance_to_castle(armies_arr, castle_id, player.get_player_id())
	var recruits_total := int(candidate["recruits_total"])
	var gold := _get_spendable_resource(player, ResourcesEnum.Type.GOLD, false, true)
	var frontier_regions_count: int = region_manager.get_frontier_regions(player.get_player_id()).size()
	var frontier_ratio: float = 0.0
	if armies_count > 0:
		frontier_ratio = float(frontier_regions_count) / float(armies_count)
	
	# Hard gates
	var gold_after := gold - GameParameters.RAISE_ARMY_COST
	var gate_failed: bool = false
	var decline_reasons: Array[String] = []
	if armies_count > 0 and gold_after < GameParameters.AI_RESERVE_GOLD_MIN:
		DebugLogger.log("AIEconomy", "   Gate FAIL: GOLD_RESERVE (current: %d, after: %d, min: %d)" % [gold, gold_after, GameParameters.AI_RESERVE_GOLD_MIN])
		gate_failed = true
		decline_reasons.append("not enough gold reserve after raise (%d vs %d)" % [gold_after, GameParameters.AI_RESERVE_GOLD_MIN])
	if armies_count > 0 and recruits_total < GameParameters.AI_MIN_RECRUITS_FOR_RAISING:
		DebugLogger.log("AIEconomy", "   Gate FAIL: RECRUITS_MIN (%d < %d)" % [recruits_total, GameParameters.AI_MIN_RECRUITS_FOR_RAISING])
		gate_failed = true
		decline_reasons.append("not enough recruits (%d vs %d)" % [recruits_total, GameParameters.AI_MIN_RECRUITS_FOR_RAISING])
	if armies_count > 0 and frontier_ratio < GameParameters.AI_RAISE_FRONTIER:
		decline_reasons.append("frontier pressure too low (%.2f vs %.2f)" % [frontier_ratio, GameParameters.AI_RAISE_FRONTIER])
	
	var score_value: float = RaiseArmyDecision.score(regions, armies_count, avg_dist, recruits_total, gold, frontier_regions_count)
	var score_text: String = _format_raise_score(score_value, regions, armies_count, avg_dist, recruits_total, gold, frontier_regions_count)
	DebugLogger.log("AIEconomy", score_text)
	_log_recruitment(score_text)
	var decision: bool = false
	if not gate_failed:
		decision = RaiseArmyDecision.should_raise_army_simple(regions, armies_count, avg_dist, recruits_total, gold, frontier_regions_count)
		if not decision:
			decline_reasons.append("score below threshold (%.2f vs %.2f)" % [score_value, GameParameters.AI_RAISE_THRESHOLD_NORM])
	DebugLogger.log("AIEconomy", "   Decision: %s" % ("RAISE" if decision else "DECLINE"))
	var reason: String = "raised" if decision else "guards_failed"
	if not decision and not decline_reasons.is_empty():
		reason = "; ".join(decline_reasons)
	return {
		"decision": decision,
		"reason": reason,
		"score_text": score_text,
		"score": score_value
	}

func _format_raise_score(score_value: float, regions: int, armies_count: int, avg_dist: float, recruits_total: int, gold: int, frontier_size: int) -> String:
	var frontier_ratio_for_log: float = 0.0
	if armies_count > 0:
		frontier_ratio_for_log = float(frontier_size) / float(armies_count)
	return "Score: %.2f (r=%d, a=%d, dist=%.1f, rec=%d, gold=%d) vs thr=%.2f; Frontier2Army=%.2f" % [
		score_value, regions, armies_count, avg_dist, recruits_total, gold, GameParameters.AI_RAISE_THRESHOLD_NORM, frontier_ratio_for_log
	]

func _compute_avg_distance_to_castle(armies_arr: Array[Army], castle_region_id: int, player_id: int) -> float:
	if armies_arr.size() == 0:
		return float(GameParameters.AI_RAISE_DIST_MAX)
	var pf := ArmyPathfinder.new(region_manager, army_manager)
	var total := 0.0
	var count := 0
	for a in armies_arr:
		var on_region := a.get_parent() as Region
		if not on_region:
			continue
		var src := on_region.get_region_id()
		var res := pf.find_path_to_target(src, castle_region_id, player_id)
		var cost := float(GameParameters.AI_RAISE_DIST_MAX)
		if res.get("success", false):
			cost = float(res.get("cost", int(GameParameters.AI_RAISE_DIST_MAX)))
		total += cost
		count += 1
	if count == 0:
		return float(GameParameters.AI_RAISE_DIST_MAX)
	return total / float(count)

# Execute the army raising at the specified region
func execute_raise_army(player_id: int, region_id: int) -> bool:
	var player = player_manager.get_player(player_id)
	var region_container = region_manager.map_generator.get_region_container_by_id(region_id)
	if army_manager.is_region_at_army_cap(region_container):
		DebugLogger.log("AIEconomy", "Recruitment: is_region_at_army_cap")
		return false
	
	# Check and deduct cost
	if _get_spendable_resource(player, ResourcesEnum.Type.GOLD, false, true) < GameParameters.RAISE_ARMY_COST:
		DebugLogger.log("AIEconomy", "Recruitment: reserve lock blocks raise army")
		return false
	if not player.remove_resources(ResourcesEnum.Type.GOLD, GameParameters.RAISE_ARMY_COST):
		DebugLogger.log("AIEconomy", "Recruitment: cannot remove resources")
		return false
	
	# Create the army
	var new_army := army_manager.create_army(region_container, player_id, true)
	if new_army == null:
		player.add_resources(ResourcesEnum.Type.GOLD, GameParameters.RAISE_ARMY_COST)
		DebugLogger.log("AIEconomy", "Recruitment: army creation failed")
		return false
	_spend_raise_army_reserve_for_gold_cost(player, GameParameters.RAISE_ARMY_COST)
	DebugLogger.log("AIEconomy", "Recruitment: army creation successfully")
	return true

# Post-movement economy pass: spend leftovers on region economy only
func _evaluate_build_castle(player_id: int, turn_number: int) -> Dictionary:
	var player = player_manager.get_player(player_id)
	if player == null:
		return {"executed": false, "reason": "no_player"}
	var topup_result: Dictionary = {}
	var candidate_info = _pick_castle_build_candidate(player_id)
	var candidate_id = int(candidate_info.get("best_region_id", -1))
	var detail_entries: Array = candidate_info.get("details", [])
	var detail_summary = _limit_candidate_details(detail_entries)
	if candidate_id == -1:
		return {
			"executed": false,
			"reason": "no_viable_candidate",
			"details": detail_summary,
			"candidate_details": detail_entries
		}
	var cost = GameParameters.get_castle_building_cost(BUILD_CASTLE_TYPE)
	if cost.is_empty():
		return {"executed": false, "reason": "no_cost_data", "details": detail_summary, "candidate_details": detail_entries}
	if not _can_afford_cost_with_reserve(player, cost):
		topup_result = _attempt_small_castle_topup(player_id, cost, "build")
		if not bool(topup_result.get("success", false)) or not _can_afford_cost_with_reserve(player, cost):
			if topup_result.has("reason"):
				_log_trade("Could not buy needed resources for build: " + String(topup_result.get("reason", "")))
			_log_trade("Insufficient funds to build " + CastleTypeEnum.type_to_string(BUILD_CASTLE_TYPE) + ".")
			var topup_summary: Array[String] = _format_topup_summary(topup_result)
			return {
				"executed": false,
				"reason": "insufficient_resources",
				"details": detail_summary,
				"candidate_details": detail_entries,
				"resource_gap": _describe_resource_gap(cost, player),
				"resources": _snapshot_player_resources(player),
				"cost": cost,
				"topup_summary": topup_summary,
				"reason_detail": _extract_topup_reason(topup_summary)
			}
	var region = region_manager.map_generator.get_region_container_by_id(candidate_id) as Region
	if region == null:
		return {"executed": false, "reason": "region_missing", "details": detail_summary, "candidate_details": detail_entries}
	if not _pay_cost_with_reserve(player, cost):
		return {"executed": false, "reason": "deduction_failed", "details": detail_summary, "candidate_details": detail_entries}
	if bool(topup_result.get("success", false)):
		_log_castle_topup_purchase("build", BUILD_CASTLE_TYPE, topup_result)
	region.start_castle_construction(BUILD_CASTLE_TYPE)
	DebugLogger.log("AIEconomy", "   BUILD CASTLE: Started %s at region %s" % [
		CastleTypeEnum.type_to_string(BUILD_CASTLE_TYPE),
		region.get_region_name()
	])
	return {
		"executed": true,
		"region_id": candidate_id,
		"details": detail_summary,
		"candidate_details": detail_entries,
		"reason": "built",
		"topup_summary": _format_topup_summary(topup_result)
	}

func _attempt_small_castle_topup(player_id: int, cost: Dictionary, label: String, allow_upgrade_bank_spend: bool = false) -> Dictionary:
	var player = player_manager.get_player(player_id)
	var gold_available := _get_spendable_resource(player, ResourcesEnum.Type.GOLD, allow_upgrade_bank_spend)
	var staged_net: Dictionary = {}
	var purchased_any := false
	var purchases: Array[Dictionary] = []
	var total_gold_delta: int = 0
	for resource_key in cost.keys():
		var resource_type: ResourcesEnum.Type = resource_key
		if resource_type == ResourcesEnum.Type.GOLD:
			continue
		var required: int = int(cost.get(resource_type, 0)) - player.get_resource_amount(resource_type)
		if required <= 0:
			continue
		if required > SMALL_CASTLE_TOPUP_LIMIT:
			return {"success": false, "reason": "needed resources beyond acceptable threshold"}
		var staged := int(staged_net.get(resource_type, 0))
		var estimated_cost := trade_manager.calculate_buy_cost(player_id, resource_type, staged, required)
		var amount_to_buy := required
		if estimated_cost > gold_available and estimated_cost > 0:
			amount_to_buy = int(floor(float(required) * float(gold_available) / float(estimated_cost)))
		if amount_to_buy <= 0:
			return {"success": false, "reason": "insufficient gold for top-up"}
		var result := trade_manager.buy(player_id, resource_type, amount_to_buy)
		if not result.get("success", false):
			return {"success": false, "reason": "top-up trade failed"}
		var gold_delta := int(result.get("gold_change", 0))
		gold_available += gold_delta
		total_gold_delta += gold_delta
		staged_net[resource_type] = staged + amount_to_buy
		purchased_any = true
		purchases.append({
			"type": resource_type,
			"amount": amount_to_buy,
			"gold_change": gold_delta
		})
	if not purchased_any:
		return {"success": false, "reason": "no purchases made"}
	return {
		"success": true,
		"purchases": purchases,
		"gold_change": total_gold_delta
	}

func _log_castle_topup_purchase(label: String, castle_type: CastleTypeEnum.Type, topup_result: Dictionary) -> void:
	var purchases: Array = topup_result.get("purchases", [])
	if purchases.is_empty():
		return
	var parts: Array[String] = []
	var total_gold_delta: int = int(topup_result.get("gold_change", 0))
	for entry in purchases:
		var r_type: ResourcesEnum.Type = entry["type"]
		var amount: int = int(entry.get("amount", 0))
		parts.append("%d %s" % [amount, ResourcesEnum.type_to_string(r_type)])
	var cost_abs := -total_gold_delta
	var msg := "Bought " + ", ".join(parts) + " and " + label + " " + CastleTypeEnum.type_to_string(castle_type)
	if cost_abs != 0:
		msg += " (gold change " + str(total_gold_delta) + ")"
	_log_trade(msg)

func _pick_castle_build_candidate(player_id: int) -> Dictionary:
	_maybe_reset_distance_cache()
	var map_gen = region_manager.map_generator
	var owned_regions = region_manager.get_player_regions(player_id)
	var detail_entries: Array = []
	if owned_regions.is_empty():
		return {"best_region_id": -1, "details": detail_entries}
	var friendly_castles = _get_player_castle_regions(player_id)
	var enemy_castles = _get_enemy_castle_regions(player_id)
	var enemy_baseline = _compute_enemy_castle_baseline(friendly_castles, enemy_castles)
	var excluded_regions = _build_castle_exclusion_set()
	var best_region_id = -1
	var best_score = -1.0
	for region_id in owned_regions:
		if excluded_regions.has(region_id):
			continue
		var region = map_gen.get_region_container_by_id(region_id) as Region
		if region == null:
			continue
		if not region.can_build_castle():
			continue
		var strategic_score = region.get_strategic_point_score() * STRATEGIC_SCORE_SCALE
		var neighbor_score = _compute_neighbor_support_score(region_id, player_id)
		var total_score = strategic_score + neighbor_score
		var distance_info = _evaluate_forward_requirement(region_id, enemy_castles, enemy_baseline)
		var entry = {
			"region_id": region_id,
			"name": region.get_region_name(),
			"strategic_score": strategic_score,
			"neighbor_score": neighbor_score,
			"total_score": total_score,
			"distance_status": String(distance_info.get("label", "Not Checked")),
			"score_pass": total_score >= CASTLE_SCORE_THRESHOLD,
			"score_threshold": CASTLE_SCORE_THRESHOLD
		}

		detail_entries.append(entry)
		if total_score >= CASTLE_SCORE_THRESHOLD and bool(distance_info.get("passed", false)):
			if total_score > best_score:
				best_score = total_score
				best_region_id = region_id
	detail_entries.sort_custom(func(a, b): return a["total_score"] > b["total_score"])
	return {"best_region_id": best_region_id, "details": detail_entries}

func _pick_castle_upgrade_candidate(player_id: int) -> Dictionary:
	_maybe_reset_distance_cache()
	var map_gen = region_manager.map_generator
	var friendly_castles = _get_player_castle_regions(player_id)
	var enemy_castles = _get_enemy_castle_regions(player_id)
	var detail_entries: Array = []
	if friendly_castles.is_empty():
		return {"best_region_id": -1, "details": detail_entries}
	var best_recruits = 0
	for region_id in friendly_castles:
		var region = map_gen.get_region_container_by_id(region_id) as Region
		if region == null:
			continue
		if region.is_castle_under_construction():
			continue
		if not CastleTypeEnum.can_upgrade(region.get_castle_type()):
			continue
		var recruits_total = _sum_castle_recruits(region_id, player_id)
		best_recruits = max(best_recruits, recruits_total)
		var distance = _calculate_distance_to_enemy_castles(region_id, enemy_castles)
		detail_entries.append({
			"region_id": region_id,
			"name": region.get_region_name(),
			"recruits_total": recruits_total,
			"distance": distance,
			"next_type": CastleTypeEnum.get_next_level(region.get_castle_type())
		})
	if detail_entries.is_empty():
		return {"best_region_id": -1, "details": []}
	var min_distance = MAX_DISTANCE
	for entry in detail_entries:
		min_distance = min(min_distance, int(entry.get("distance", MAX_DISTANCE)))
	for entry in detail_entries:
		var recruits_total = float(entry.get("recruits_total", 0))
		var recruit_score = 0.0
		if best_recruits > 0:
			recruit_score = clampf((recruits_total / float(best_recruits)) * 100.0, 0.0, 100.0)
		var distance_value = int(entry.get("distance", MAX_DISTANCE))
		var distance_score = 0.0
		if min_distance < MAX_DISTANCE and distance_value > 0:
			distance_score = clampf((float(min_distance) / float(distance_value)) * 100.0, 0.0, 100.0)
		elif distance_value == 0:
			distance_score = 100.0
		entry["recruit_score"] = recruit_score
		entry["distance_score"] = distance_score
		entry["total_score"] = (recruit_score + distance_score) * 0.5
	detail_entries.sort_custom(func(a, b): return a["total_score"] > b["total_score"])
	var best_region_id = -1
	if detail_entries.size() > 0:
		best_region_id = int(detail_entries[0]["region_id"])
	return {"best_region_id": best_region_id, "details": detail_entries}

func _pick_region_upgrade_candidates(player_id: int) -> Dictionary:
	var map_gen = region_manager.map_generator
	var owned_regions = region_manager.get_player_regions(player_id)
	var details: Array = []
	for region_id in owned_regions:
		var region = map_gen.get_region_container_by_id(region_id) as Region
		if region == null:
			continue
		var current_level = region.get_region_level()
		if current_level >= RegionLevelEnum.Level.L5:
			continue
		var next_level = int(current_level) + 1
		var cost = GameParameters.get_promotion_cost(next_level)
		if cost.is_empty():
			continue
		var score_data = _score_region_for_upgrade(region, player_id)
		var entry = {
			"region_id": region_id,
			"name": region.get_region_name(),
			"score": float(score_data.get("score", 0.0)),
			"castle_level": int(score_data.get("castle_level", 0)),
			"neighbor_bonus": int(score_data.get("neighbor_bonus", 0)),
			"recruit_status": String(score_data.get("recruit_status", "partial")),
			"recruit_bonus": int(score_data.get("recruit_bonus", 0)),
			"population": region.get_population(),
			"level": current_level,
			"next_level": next_level,
			"cost": cost
		}
		details.append(entry)
	details.sort_custom(func(a, b): return a["score"] > b["score"])
	var best_region_id = -1
	if details.size() > 0:
		best_region_id = int(details[0]["region_id"])
	return {"best_region_id": best_region_id, "details": details}

func _score_region_for_castle(region_id: int, player_id: int) -> float:
	var region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
	if region == null:
		return 0.0
	var heat_score = region.get_strategic_point_score() * STRATEGIC_SCORE_SCALE
	var neighbor_score = _compute_neighbor_support_score(region_id, player_id)
	return heat_score + neighbor_score

func _compute_neighbor_support_score(region_id: int, player_id: int) -> float:
	var neighbor_ids = region_manager.get_neighbor_regions(region_id)
	var score: float = 0.0
	var has_adjacent_castle: bool = false
	for neighbor_id in neighbor_ids:
		if region_manager.get_castle_level(neighbor_id) > 0:
			has_adjacent_castle = true
		var owner_id = region_manager.get_region_owner(neighbor_id)
		if owner_id == player_id:
			score += FRIENDLY_NEIGHBOR_VALUE
		elif owner_id == -1:
			score += NEUTRAL_NEIGHBOR_VALUE
		else:
			score -= ENEMY_NEIGHBOR_PENALTY
	if has_adjacent_castle:
		score -= ADJACENT_CASTLE_NEIGHBOR_PENALTY
	return score

func _evaluate_forward_requirement(region_id: int, enemy_castles: Array[int], enemy_baseline: Dictionary) -> Dictionary:
	if enemy_castles.is_empty():
		return {"passed": true, "label": "Not Checked"}
	for enemy_id in enemy_castles:
		var current_best = int(enemy_baseline.get(enemy_id, MAX_DISTANCE))
		var candidate_dist = _get_region_distance(region_id, enemy_id)
		if candidate_dist < current_best:
			return {"passed": true, "label": "True"}
	return {"passed": false, "label": "False"}

func _get_player_castle_regions(player_id: int) -> Array[int]:
	var out: Array[int] = []
	for rid in region_manager.map_generator.region_container_by_id.keys():
		var region = region_manager.map_generator.get_region_container_by_id(int(rid)) as Region
		if region == null:
			continue
		if region.get_castle_type() != CastleTypeEnum.Type.NONE and region_manager.get_region_owner(region.get_region_id()) == player_id:
			out.append(region.get_region_id())
	return out

func _get_enemy_castle_regions(player_id: int) -> Array[int]:
	var out: Array[int] = []
	for rid in region_manager.map_generator.region_container_by_id.keys():
		var region = region_manager.map_generator.get_region_container_by_id(int(rid)) as Region
		if region == null:
			continue
		var owner_id = region_manager.get_region_owner(region.get_region_id())
		if owner_id != -1 and owner_id != player_id and region.get_castle_type() != CastleTypeEnum.Type.NONE:
			out.append(region.get_region_id())
	return out

func _compute_enemy_castle_baseline(friendly_castles: Array[int], enemy_castles: Array[int]) -> Dictionary:
	var baseline: Dictionary = {}
	for enemy_id in enemy_castles:
		var best = MAX_DISTANCE
		for friendly_id in friendly_castles:
			var dist = _get_region_distance(enemy_id, friendly_id)
			if dist < best:
				best = dist
		baseline[enemy_id] = best
	return baseline

func _build_castle_exclusion_set() -> Dictionary:
	var excluded: Dictionary = {}
	for rid in region_manager.map_generator.region_container_by_id.keys():
		var region = region_manager.map_generator.get_region_container_by_id(int(rid)) as Region
		if region == null:
			continue
		if region.get_castle_type() != CastleTypeEnum.Type.NONE:
			excluded[int(rid)] = true
	return excluded

func _limit_candidate_details(all_details: Array) -> Array:
	var limited: Array = []
	var max_entries = min(3, all_details.size())
	for i in range(max_entries):
		limited.append(all_details[i])
	return limited

func _describe_resource_gap(cost: Dictionary, player: Player) -> Array[String]:
	var lines: Array[String] = []
	for resource_key in cost.keys():
		var resource_type: ResourcesEnum.Type = resource_key
		var required: int = int(cost.get(resource_type, 0))
		var available: int = player.get_resource_amount(resource_type)
		var shortfall: int = max(0, required - available)
		lines.append("%s need:%d have:%d short:%d" % [
			ResourcesEnum.type_to_string(resource_type),
			required,
			available,
			shortfall
		])
	return lines

func _snapshot_player_resources(player: Player) -> Dictionary:
	var snapshot: Dictionary = {}
	for resource_type in ResourcesEnum.get_all_types():
		snapshot[resource_type] = player.get_resource_amount(resource_type)
	return snapshot

func _format_topup_summary(topup_result: Dictionary) -> Array[String]:
	if topup_result.is_empty():
		return []
	if not topup_result.get("success", false):
		return ["Top-up failed: %s" % String(topup_result.get("reason", "unknown"))]
	var purchases: Array = topup_result.get("purchases", [])
	if purchases.is_empty():
		return ["Top-up completed with no purchases"]
	var parts: Array[String] = []
	for entry in purchases:
		var res_type: ResourcesEnum.Type = entry.get("type", ResourcesEnum.Type.GOLD)
		var amount: int = int(entry.get("amount", 0))
		var gold_delta: int = int(entry.get("gold_change", 0))
		parts.append("%d %s (gold %d)" % [amount, ResourcesEnum.type_to_string(res_type), gold_delta])
	var total_gold: int = int(topup_result.get("gold_change", 0))
	return ["Top-up purchases: " + ", ".join(parts) + " | total gold change: " + str(total_gold)]

func _extract_topup_reason(topup_summary: Array[String]) -> String:
	if topup_summary.is_empty():
		return ""
	return topup_summary[0]

func _get_region_distance(a: int, b: int) -> int:
	if a == b:
		return 0
	var key_a = min(a, b)
	var key_b = max(a, b)
	var key = "%d|%d" % [key_a, key_b]
	if _region_distance_cache.has(key):
		return int(_region_distance_cache[key])
	var dist = _bfs_region_distance(key_a, key_b)
	_region_distance_cache[key] = dist
	return dist

func _bfs_region_distance(start_id: int, target_id: int) -> int:
	var queue: Array = []
	var visited: Dictionary = {}
	queue.append({"id": start_id, "dist": 0})
	visited[start_id] = true
	while not queue.is_empty():
		var current = queue.pop_front()
		var cid = int(current["id"])
		var dist = int(current["dist"])
		if cid == target_id:
			return dist
		var neighbors = region_manager.get_neighbor_regions(cid)
		for neighbor_id in neighbors:
			if visited.has(neighbor_id):
				continue
			var region = region_manager.map_generator.get_region_container_by_id(neighbor_id) as Region
			if region == null:
				continue
			if region.is_ocean_region():
				continue
			visited[neighbor_id] = true
			queue.append({"id": neighbor_id, "dist": dist + 1})
	return MAX_DISTANCE

func _maybe_reset_distance_cache() -> void:
	var region_count = region_manager.map_generator.region_container_by_id.size()
	if region_count != _cached_region_count:
		_region_distance_cache.clear()
		_cached_region_count = region_count

func _describe_recruitment_candidates(armies: Array) -> Array[String]:
	var descriptions: Array[String] = []
	for army in armies:
		var region = army.get_parent() as Region
		var region_name = "Unknown region"
		if region:
			region_name = region.get_region_name()
		descriptions.append("%s (%s)" % [army.name, region_name])
	return descriptions

func _calculate_distance_to_enemy_castles(region_id: int, enemy_castles: Array[int]) -> int:
	if enemy_castles.is_empty():
		return MAX_DISTANCE
	var best = MAX_DISTANCE
	for enemy_id in enemy_castles:
		var dist = _get_region_distance(region_id, enemy_id)
		if dist < best:
			best = dist
	return best

func _sum_castle_recruits(region_id: int, player_id: int) -> int:
	var sources = region_manager.get_available_recruits_from_region_and_neighbors(region_id, player_id)
	var total = 0
	for src in sources:
		total += int(src.amount)
	return total

func _score_region_for_upgrade(region: Region, player_id: int) -> Dictionary:
	var region_id = region.get_region_id()
	var castle_level = region_manager.get_castle_level(region_id)
	var castle_bonus = castle_level * 2
	var population_bonus = int(region.get_population() / 100)
	var neighbor_bonus = _compute_neighbor_castle_bonus(region_id, player_id)
	var available_recruits = region.get_available_recruits()
	var max_recruits = GameParameters.calculate_max_recruits(region.get_population(), region.get_castle_type())
	var recruit_bonus = 0
	var recruit_status = "partial"
	if available_recruits <= 0:
		recruit_status = "empty"
		recruit_bonus = 2
	elif available_recruits >= max_recruits:
		recruit_status = "full"
		recruit_bonus = -2
	else:
		recruit_status = "partial"
		recruit_bonus = 1
	var level_int = RegionLevelEnum.level_to_number(region.get_region_level())
	var score = float(castle_bonus + population_bonus + neighbor_bonus + recruit_bonus - level_int)
	return {
		"score": score,
		"castle_level": castle_level,
		"neighbor_bonus": neighbor_bonus,
		"recruit_status": recruit_status,
		"recruit_bonus": recruit_bonus
	}

func _compute_neighbor_castle_bonus(region_id: int, player_id: int) -> int:
	var neighbors = region_manager.get_neighbor_regions(region_id)
	var bonus = 0
	for neighbor_id in neighbors:
		if region_manager.get_region_owner(neighbor_id) != player_id:
			continue
		var level = region_manager.get_castle_level(neighbor_id)
		if level > 0:
			bonus += level
	return bonus

func _evaluate_upgrade_castle(player_id: int, turn_number: int) -> Dictionary:
	var player = player_manager.get_player(player_id)
	if player == null:
		return {"executed": false, "reason": "no_player", "details": []}
	var topup_result: Dictionary = {}
	var candidate_info = _pick_castle_upgrade_candidate(player_id)
	var candidate_id = int(candidate_info.get("best_region_id", -1))
	var detail_entries: Array = candidate_info.get("details", [])
	var detail_summary = _limit_candidate_details(detail_entries)
	if candidate_id == -1:
		var released_bank_gold: int = _release_castle_upgrade_bank(player, "no_upgrade_candidates")
		return {
			"executed": false,
			"reason": "no_upgrade_candidates",
			"details": detail_summary,
			"candidate_details": detail_entries,
			"released_upgrade_bank_gold": released_bank_gold
		}
	var region = region_manager.map_generator.get_region_container_by_id(candidate_id) as Region
	if region == null:
		return {"executed": false, "reason": "region_missing", "details": detail_summary, "candidate_details": detail_entries}
	if region.is_castle_under_construction():
		return {"executed": false, "reason": "castle_under_construction", "details": detail_summary, "candidate_details": detail_entries}
	var current_type = region.get_castle_type()
	var next_type = CastleTypeEnum.get_next_level(current_type)
	if next_type == CastleTypeEnum.Type.NONE:
		return {"executed": false, "reason": "max_level_reached", "details": detail_summary, "candidate_details": detail_entries}
	var cost = GameParameters.get_castle_building_cost(next_type)
	if cost.is_empty():
		return {"executed": false, "reason": "no_cost_data", "details": detail_summary, "candidate_details": detail_entries}
	if not _can_afford_cost_with_reserve(player, cost, true):
		topup_result = _attempt_small_castle_topup(player_id, cost, "upgrade", true)
		if not bool(topup_result.get("success", false)) or not _can_afford_cost_with_reserve(player, cost, true):
			if topup_result.has("reason"):
				_log_trade("Could not buy needed resources for upgrade: " + String(topup_result.get("reason", "")))
			_log_trade("Insufficient funds to upgrade " + CastleTypeEnum.type_to_string(current_type) + ".")
			var topup_summary_upgrade: Array[String] = _format_topup_summary(topup_result)
			return {
				"executed": false,
				"reason": "insufficient_resources",
				"details": detail_summary,
				"candidate_details": detail_entries,
				"resource_gap": _describe_resource_gap(cost, player),
				"resources": _snapshot_player_resources(player),
				"cost": cost,
				"topup_summary": topup_summary_upgrade,
				"reason_detail": _extract_topup_reason(topup_summary_upgrade)
			}
	if not _pay_cost_with_reserve(player, cost, true):
		return {"executed": false, "reason": "deduction_failed", "details": detail_summary, "candidate_details": detail_entries}
	if bool(topup_result.get("success", false)):
		_log_castle_topup_purchase("upgrade", next_type, topup_result)
	region.start_castle_construction(next_type)
	DebugLogger.log("AIEconomy", "   UPGRADE CASTLE: Started %s at region %s" % [
		CastleTypeEnum.type_to_string(next_type),
		region.get_region_name()
	])
	return {
		"executed": true,
		"region_id": candidate_id,
		"details": detail_summary,
		"candidate_details": detail_entries,
		"reason": "upgrade_started",
		"topup_summary": _format_topup_summary(topup_result)
	}

func _evaluate_upgrade_region(player_id: int, turn_number: int) -> Dictionary:
	var player = player_manager.get_player(player_id)
	if player == null:
		return {"executed": false, "reason": "no_player", "details": [], "actions": [], "action_entries": []}
	# Quick affordability check for the cheapest upgrade (L1 -> L2)
	var min_upgrade_cost: Dictionary = GameParameters.REGION_PROMOTION_COSTS.get(RegionLevelEnum.Level.L2, {})
	if not min_upgrade_cost.is_empty() and not _can_afford_cost_with_reserve(player, min_upgrade_cost):
		return {"executed": false, "reason": "insufficient_for_min_upgrade", "details": [], "actions": [], "action_entries": []}
	var upgrades: Array[String] = []
	var action_entries: Array = []
	var reason = "no_candidate"
	var skip_reasons: Array[String] = []
	var last_details: Array = []
	var candidate_info = _pick_region_upgrade_candidates(player_id)
	var details: Array = candidate_info.get("details", [])
	last_details = details
	if candidate_info.get("best_region_id", -1) == -1 or details.is_empty():
		reason = "no_candidate"
	else:
		for detail in details:
			var region_id: int = int(detail.get("region_id", -1))
			var score: float = float(detail.get("score", 0.0))
			if region_id == -1 or score <= 0.0:
				skip_reasons.append("Region %d: low_score" % region_id)
				continue
			var next_level: int = int(detail.get("next_level", RegionLevelEnum.Level.L1))
			var cost: Dictionary = detail.get("cost", {})
			if cost.is_empty():
				skip_reasons.append("Region %d: no_cost_data" % region_id)
				continue
			var region: Region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
			if region == null:
				skip_reasons.append("Region %d: region_missing" % region_id)
				continue
			if region.get_promotion_cooldown() > 0:
				skip_reasons.append("Region %d: cooldown_active" % region_id)
				continue
			var food_cost: int = int(cost.get(ResourcesEnum.Type.FOOD, 0))
			if not player_manager.meets_food_upgrade_safeguard(player_id, food_cost):
				skip_reasons.append("Region %d: food_safeguard" % region_id)
				continue
			var growth_guard_reason: String = _get_region_promotion_growth_guard_reason(player_id, next_level)
			if growth_guard_reason != "":
				skip_reasons.append("Region %d: %s" % [region_id, growth_guard_reason])
				continue
			if not _can_afford_cost_with_reserve(player, cost):
				skip_reasons.append("Region %d: insufficient_resources" % region_id)
				continue
			if not _pay_cost_with_reserve(player, cost):
				skip_reasons.append("Region %d: deduction_failed" % region_id)
				continue
			region.set_region_level(next_level)
			region_manager.generate_region_resources(region)
			region.set_promotion_cooldown(3)
			var level_name = RegionLevelEnum.level_to_string(next_level)
			var msg = "Upgrading %s to %s (score: %.1f)" % [region.get_region_name(), level_name, score]
			upgrades.append(msg)
			action_entries.append({
				"action": "upgrade_region",
				"region_id": region_id,
				"details": detail
			})
			reason = "upgrades_completed"
			# Stop if we run out of resources for further upgrades
			continue
	var final_reason = reason
	if upgrades.is_empty() and not skip_reasons.is_empty():
		final_reason = "skipped_all"
	var actions_final: Array = upgrades
	if upgrades.is_empty() and not skip_reasons.is_empty():
		actions_final = skip_reasons
	return {
		"executed": upgrades.size() > 0,
		"reason": final_reason,
		"details": _limit_candidate_details(last_details),
		"actions": actions_final,
		"action_entries": action_entries
	}

func _get_region_promotion_growth_guard_reason(player_id: int, target_level: int) -> String:
	var min_growth: float = GameParameters.AI_REGION_PROMOTION_MIN_RESOURCE_GROWTH
	if target_level == RegionLevelEnum.Level.L3:
		var wood_growth: float = player_manager.get_player_resource_growth(player_id, ResourcesEnum.Type.WOOD)
		if wood_growth < min_growth:
			return "wood_growth_below_min %.1f/%.1f" % [wood_growth, min_growth]
		var food_growth: float = player_manager.get_player_resource_growth(player_id, ResourcesEnum.Type.FOOD)
		if food_growth < min_growth:
			return "food_growth_below_min %.1f/%.1f" % [food_growth, min_growth]
	if target_level == RegionLevelEnum.Level.L4:
		var stone_growth: float = player_manager.get_player_resource_growth(player_id, ResourcesEnum.Type.STONE)
		if stone_growth < min_growth:
			return "stone_growth_below_min %.1f/%.1f" % [stone_growth, min_growth]
	return ""

func execute_garrison_recruitment(player_id: int) -> Dictionary:
	if recruitment_manager == null:
		return {"processed": 0, "recruited": 0, "entries": []}
	var processed := 0
	var recruited := 0
	var entries: Array[String] = []
	for request in garrison_requests:
		var budget: BudgetComposition = request.get("assigned_budget", null)
		if budget == null:
			continue
		var region: Region = request.get("region")
		if budget.available_recruits <= 0:
			budget.available_recruits = region.get_available_recruits()
		var result = recruitment_manager.hire_garrison(region, budget, player_id)
		var hired = int(result.get("total_recruited", 0))
		if hired > 0:
			processed += 1
			recruited += hired
			entries.append(_format_castle_hire_entry(region.get_region_name(), result))
		request["hired"] = hired
	return {"processed": processed, "recruited": recruited, "entries": entries}

func perform_garrison_trickle(player_id: int, turn_number: int) -> Dictionary:
	if turn_number == 1:
		return {"processed": 0, "recruited": 0, "reason": "first_turn_skip", "entries": []}
	var average_power: float = max(game_manager.get_average_army_power(), 1.0)
	var wood_positive: bool = player_manager.get_player_resource_growth(player_id, ResourcesEnum.Type.WOOD) > 0.0
	var iron_positive: bool = player_manager.get_player_resource_growth(player_id, ResourcesEnum.Type.IRON) > 0.0
	var owned_regions: Array[int] = region_manager.get_player_regions(player_id)
	var processed: int = 0
	var added: int = 0
	var entries: Array[String] = []
	for region_id in owned_regions:
		var region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
		if not region.has_castle():
			continue
		var units_to_add: int = GameParameters.get_garrison_trickle_units(region.get_castle_type())
		if units_to_add <= 0:
			continue
		var garrison_power: int = region.get_garrison_strength()
		var planned_units: int = 0
		if garrison_power < average_power:
			planned_units = units_to_add
		elif garrison_power <= average_power * 1.25:
			planned_units = int(ceil(float(units_to_add) / 2.0))
		if planned_units <= 0:
			entries.append("%s: skipped (garrison %d vs avg %.1f)" % [region.get_region_name(), garrison_power, average_power])
			continue
		for i in range(planned_units):
			var unit_type = _pick_trickle_unit(region.get_castle_type(), wood_positive, iron_positive)
			region.add_soldiers_to_garrison(unit_type, 1)
			added += 1
		processed += 1
		entries.append(region.get_region_name() + ": +" + str(planned_units))
	var reason = "success" if processed > 0 else "no_castles"
	return {"processed": processed, "recruited": added, "reason": reason, "entries": entries}

func _execute_ai_trade_sell_surplus(player_id: int) -> Dictionary:
	var player = player_manager.get_player(player_id)
	var sold: Array = []
	var actions: Array[String] = []
	var gold_change: int = 0
	var resources_to_sell = [
		ResourcesEnum.Type.WOOD,
		ResourcesEnum.Type.FOOD,
		ResourcesEnum.Type.STONE,
		ResourcesEnum.Type.IRON
	]
	for resource_type in resources_to_sell:
		var growth = player_manager.get_player_resource_growth(player_id, resource_type)
		if growth > 0.0:
			var threshold = GameParameters.get_ai_trade_threshold(resource_type)
			var current_amount = player.get_resource_amount(resource_type)
			var surplus = max(0, current_amount - threshold)
			if surplus > 0:
				var result = trade_manager.sell(player_id, resource_type, surplus)
				var entry = {
					"resource": ResourcesEnum.type_to_string(resource_type),
					"amount": surplus,
					"success": result.get("success", false)
				}
				if result.get("success", false):
					var delta_gold = int(result.get("gold_change", 0))
					entry["gold_change"] = delta_gold
					gold_change += delta_gold
					var msg = "Sold %d %s for %d gold" % [surplus, ResourcesEnum.type_to_string(resource_type), delta_gold]
					actions.append(msg)
					_log_trade(msg)
				else:
					var reason = String(result.get("reason", "fail"))
					entry["reason"] = reason
					var fail_msg = "Sell %s failed (%s)" % [ResourcesEnum.type_to_string(resource_type), reason]
					actions.append(fail_msg)
					_log_trade(fail_msg)
				sold.append(entry)
	return {
		"executed": not actions.is_empty(),
		"actions": actions,
		"sold": sold,
		"bought": [],
		"gold_change": gold_change
	}

func _execute_ai_trade_buy_food_deficit(player_id: int) -> Dictionary:
	var player = player_manager.get_player(player_id)
	var bought: Array = []
	var actions: Array[String] = []
	var gold_change: int = 0
	var food_growth = player_manager.get_player_resource_growth(player_id, ResourcesEnum.Type.FOOD)
	if food_growth < 0.0:
		var deficit = int(ceil(-food_growth))
		if deficit > 0:
			var spendable_gold: int = _get_spendable_resource(player, ResourcesEnum.Type.GOLD)
			var estimated_cost: int = trade_manager.calculate_buy_cost(player_id, ResourcesEnum.Type.FOOD, 0, deficit)
			var amount_to_buy: int = deficit
			if estimated_cost > spendable_gold and estimated_cost > 0:
				amount_to_buy = int(floor(float(deficit) * float(spendable_gold) / float(estimated_cost)))
			if amount_to_buy <= 0:
				actions.append("Buy Food skipped (reserve lock)")
				bought.append({
					"resource": ResourcesEnum.type_to_string(ResourcesEnum.Type.FOOD),
					"amount": 0,
					"success": false,
					"reason": "reserve_lock"
				})
				return {
					"executed": not actions.is_empty(),
					"actions": actions,
					"sold": [],
					"bought": bought,
					"gold_change": gold_change
				}
			var buy_result = trade_manager.buy(player_id, ResourcesEnum.Type.FOOD, amount_to_buy)
			var buy_entry = {
				"resource": ResourcesEnum.type_to_string(ResourcesEnum.Type.FOOD),
				"amount": amount_to_buy,
				"success": buy_result.get("success", false)
			}
			if buy_result.get("success", false):
				var delta_gold_buy = int(buy_result.get("gold_change", 0))
				buy_entry["gold_change"] = delta_gold_buy
				gold_change += delta_gold_buy
				var buy_msg = "Bought %d Food (gold change %d)" % [amount_to_buy, delta_gold_buy]
				actions.append(buy_msg)
				_log_trade(buy_msg)
			else:
				var buy_reason = String(buy_result.get("reason", "fail"))
				buy_entry["reason"] = buy_reason
				var buy_fail_msg = "Buy Food failed (%s)" % [buy_reason]
				actions.append(buy_fail_msg)
				_log_trade(buy_fail_msg)
			bought.append(buy_entry)
	return {
		"executed": not actions.is_empty(),
		"actions": actions,
		"sold": [],
		"bought": bought,
		"gold_change": gold_change
	}

func _merge_trade_results(sell_result: Dictionary, buy_result: Dictionary) -> Dictionary:
	var actions: Array = []
	var sold: Array = []
	var bought: Array = []
	var sell_actions: Array = sell_result.get("actions", [])
	var buy_actions: Array = buy_result.get("actions", [])
	actions.append_array(sell_actions)
	actions.append_array(buy_actions)
	var sell_entries: Array = sell_result.get("sold", [])
	var buy_entries: Array = buy_result.get("bought", [])
	sold.append_array(sell_entries)
	bought.append_array(buy_entries)
	var gold_change: int = int(sell_result.get("gold_change", 0)) + int(buy_result.get("gold_change", 0))
	return {
		"executed": not actions.is_empty(),
		"actions": actions,
		"sold": sold,
		"bought": bought,
		"gold_change": gold_change
	}

func _pick_trickle_unit(castle_type: CastleTypeEnum.Type, wood_positive: bool, iron_positive: bool) -> SoldierTypeEnum.Type:
	var composition = GameParameters.get_ideal_castle_garrison(castle_type)
	var pool: Array = []
	for key in composition.keys():
		var weight = int(composition[key])
		if weight <= 0:
			continue
		var unit_type = _trickle_key_to_type(key)
		if not wood_positive and (unit_type == SoldierTypeEnum.Type.ARCHERS or unit_type == SoldierTypeEnum.Type.CROSSBOWMEN):
			continue
		if not iron_positive and (unit_type == SoldierTypeEnum.Type.KNIGHTS or unit_type == SoldierTypeEnum.Type.ROYAL_GUARD):
			continue
		pool.append({"type": unit_type, "weight": weight})
	if pool.is_empty():
		return SoldierTypeEnum.Type.PEASANTS
	var total_weight := 0
	for entry in pool:
		total_weight += entry["weight"]
	var roll = randi_range(1, total_weight)
	var running = 0
	for entry in pool:
		running += entry["weight"]
		if roll <= running:
			return entry["type"]
	return pool[0]["type"]

func _trickle_key_to_type(key: String) -> SoldierTypeEnum.Type:
	match key:
		"peasants":
			return SoldierTypeEnum.Type.PEASANTS
		"spearmen":
			return SoldierTypeEnum.Type.SPEARMEN
		"swordsmen":
			return SoldierTypeEnum.Type.SWORDSMEN
		"archers":
			return SoldierTypeEnum.Type.ARCHERS
		"crossbowmen":
			return SoldierTypeEnum.Type.CROSSBOWMEN
		"horsemen":
			return SoldierTypeEnum.Type.HORSEMEN
		"knights":
			return SoldierTypeEnum.Type.KNIGHTS
		"mounted_knights":
			return SoldierTypeEnum.Type.MOUNTED_KNIGHTS
		"royal_guard":
			return SoldierTypeEnum.Type.ROYAL_GUARD
		_:
			return SoldierTypeEnum.Type.PEASANTS
	
func _build_garrison_requests(player_id: int) -> Array:
	var requests: Array = []
	var owned_regions = region_manager.get_player_regions(player_id)
	var enemy_presence = _build_enemy_army_presence(player_id)
	for region_id in owned_regions:
		var region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
		if not region.has_castle():
			continue
		if _castle_needs_garrison(region, enemy_presence):
			requests.append({
				"region_id": region_id,
				"region": region,
				"assigned_budget": null
			})
	return requests

func _castle_needs_garrison(region: Region, enemy_presence: Dictionary) -> bool:
	var castle_type = region.get_castle_type()
	if castle_type == CastleTypeEnum.Type.NONE:
		return false
	if not _has_enemy_threat(region.get_region_id(), enemy_presence):
		return false
	var safe_power = GameParameters.get_safe_garrison_power(castle_type)
	var current_power = region.get_garrison_strength()
	if current_power >= safe_power:
		var note = "%s: in danger but has minimal garrison power (Power: %d / %d)" % [
			region.get_region_name(),
			current_power,
			safe_power
		]
		garrison_skip_logs.append(note)
		return false
	return true

func _build_enemy_army_presence(player_id: int) -> Dictionary:
	var presence: Dictionary = {}
	var armies = army_manager.get_all_armies()
	for army in armies:
		if army == null or not is_instance_valid(army):
			continue
		if army.get_player_id() == player_id:
			continue
		var location := army.get_parent() as Region
		if location == null:
			continue
		var rid := location.get_region_id()
		if rid < 0:
			continue
		presence[rid] = true
	return presence

func _has_enemy_threat(region_id: int, enemy_presence: Dictionary) -> bool:
	if enemy_presence.has(region_id):
		return true
	var threat_regions = _collect_regions_within_steps(region_id, 2)
	for rid in threat_regions.keys():
		if enemy_presence.has(rid):
			return true
	return false

func _collect_regions_within_steps(region_id: int, steps: int) -> Dictionary:
	var visited: Dictionary = {}
	var frontier: Array = [region_id]
	for i in range(steps):
		var next_frontier: Array = []
		for current_id in frontier:
			var neighbors = region_manager.get_neighbor_regions(current_id)
			for neighbor_id in neighbors:
				if neighbor_id == region_id:
					continue
				if visited.has(neighbor_id):
					continue
				visited[neighbor_id] = true
				next_frontier.append(neighbor_id)
		frontier = next_frontier
		if frontier.is_empty():
			break
	return visited

func _reset_castle_threat_state() -> void:
	castle_threat_registry_by_region.clear()
	castle_total_threat_value_by_region.clear()
	castle_threat_level_by_region.clear()
	castle_reserved_budget_by_region.clear()
	castle_threat_scan_entries_by_region.clear()
	_clear_reserved_recruitment_lock()

func _clear_reserved_recruitment_lock() -> void:
	reserved_recruitment_lock = {
		ResourcesEnum.Type.GOLD: 0,
		ResourcesEnum.Type.WOOD: 0,
		ResourcesEnum.Type.IRON: 0
	}

func _get_reserved_resource(resource_type: ResourcesEnum.Type) -> int:
	return int(reserved_recruitment_lock.get(resource_type, 0))

func _get_spendable_resource(player: Player, resource_type: ResourcesEnum.Type, allow_upgrade_bank_spend: bool = false, allow_raise_reserve_spend: bool = false) -> int:
	var total_amount: int = player.get_resource_amount(resource_type)
	if resource_type == ResourcesEnum.Type.GOLD or resource_type == ResourcesEnum.Type.WOOD or resource_type == ResourcesEnum.Type.IRON:
		var locked_amount: int = _get_reserved_resource(resource_type)
		if resource_type == ResourcesEnum.Type.GOLD and not allow_upgrade_bank_spend:
			locked_amount += _get_upgrade_bank_locked_gold(player)
		if resource_type == ResourcesEnum.Type.GOLD and not allow_raise_reserve_spend:
			locked_amount += _get_raise_army_reserve_locked_gold(player)
		return max(0, total_amount - locked_amount)
	return total_amount

func _can_afford_cost_with_reserve(player: Player, cost: Dictionary, allow_upgrade_bank_spend: bool = false, allow_raise_reserve_spend: bool = false) -> bool:
	for resource_key in cost.keys():
		var resource_type: ResourcesEnum.Type = resource_key
		var required: int = int(cost.get(resource_type, 0))
		if required <= 0:
			continue
		if _get_spendable_resource(player, resource_type, allow_upgrade_bank_spend, allow_raise_reserve_spend) < required:
			return false
	return true

func _pay_cost_with_reserve(player: Player, cost: Dictionary, allow_upgrade_bank_spend: bool = false, allow_raise_reserve_spend: bool = false) -> bool:
	if not _can_afford_cost_with_reserve(player, cost, allow_upgrade_bank_spend, allow_raise_reserve_spend):
		return false
	var paid: bool = player.pay_cost(cost)
	if not paid:
		return false
	if allow_upgrade_bank_spend:
		var gold_cost_paid: int = int(cost.get(ResourcesEnum.Type.GOLD, 0))
		_spend_castle_upgrade_bank_for_gold_cost(player, gold_cost_paid)
	if allow_raise_reserve_spend:
		var raise_gold_cost_paid: int = int(cost.get(ResourcesEnum.Type.GOLD, 0))
		_spend_raise_army_reserve_for_gold_cost(player, raise_gold_cost_paid)
	return true

func _refresh_castle_threats_after_movement(player_id: int) -> Dictionary:
	return _refresh_castle_threats_for_player(player_id, true)

func _refresh_castle_threats_for_player(player_id: int, post_move_refresh: bool) -> Dictionary:
	var owned_regions: Array[int] = region_manager.get_player_regions(player_id)
	var active_castles: Dictionary = {}
	var deltas: Array[String] = []
	var castles_checked: int = 0
	for region_id in owned_regions:
		var region: Region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
		if not region.has_castle():
			continue
		castles_checked += 1
		active_castles[region_id] = true
		var previous_registry: Dictionary = castle_threat_registry_by_region.get(region_id, {})
		var previous_total: int = int(castle_total_threat_value_by_region.get(region_id, 0))
		var previous_level: int = int(castle_threat_level_by_region.get(region_id, THREAT_LEVEL_NONE))
		var evaluated: Dictionary = _evaluate_castle_threat_for_region(region, player_id, previous_registry, post_move_refresh)
		castle_threat_registry_by_region[region_id] = evaluated.get("registry", {})
		castle_total_threat_value_by_region[region_id] = int(evaluated.get("total_threat_value", 0))
		castle_threat_level_by_region[region_id] = int(evaluated.get("threat_level", THREAT_LEVEL_NONE))
		castle_threat_scan_entries_by_region[region_id] = evaluated.get("scan_entries", [])
		if post_move_refresh:
			var current_total: int = int(castle_total_threat_value_by_region.get(region_id, 0))
			var current_level: int = int(castle_threat_level_by_region.get(region_id, THREAT_LEVEL_NONE))
			if current_total != previous_total or current_level != previous_level:
				deltas.append("%s: threat %d->%d, level %d->%d" % [
					region.get_region_name(),
					previous_total,
					current_total,
					previous_level,
					current_level
				])
	for tracked_region_id in castle_threat_registry_by_region.keys():
		var region_id_int: int = int(tracked_region_id)
		if active_castles.has(region_id_int):
			continue
		castle_threat_registry_by_region.erase(region_id_int)
		castle_total_threat_value_by_region.erase(region_id_int)
		castle_threat_level_by_region.erase(region_id_int)
		castle_reserved_budget_by_region.erase(region_id_int)
		castle_threat_scan_entries_by_region.erase(region_id_int)
		if post_move_refresh:
			deltas.append("Castle #%d: threat removed" % region_id_int)
	return {
		"castles_checked": castles_checked,
		"deltas": deltas
	}

func _evaluate_castle_threat_for_region(castle_region: Region, player_id: int, previous_registry: Dictionary, post_move_refresh: bool) -> Dictionary:
	var enemy_cache: Dictionary = castle_region.castle_nearby_entities.get("enemy_army_ids", {})
	var observations_by_army_id: Dictionary = {}
	var scan_entries: Array[Dictionary] = []
	var pathfinder: ArmyPathfinder = ArmyPathfinder.new(region_manager, army_manager)
	var castle_region_id: int = castle_region.get_region_id()
	var has_defender_army_in_castle: bool = _castle_has_defender_army_in_region(castle_region, player_id)
	for enemy_key in enemy_cache.keys():
		var army_entity_id: String = String(enemy_key)
		var enemy_army: Army = army_manager.get_army_by_entity_id(army_entity_id)
		if not is_instance_valid(enemy_army):
			scan_entries.append(_build_threat_scan_entry(army_entity_id, -1, false, -1, false, "not_in_tracking", -1))
			continue
		var enemy_region: Region = enemy_army.get_parent() as Region
		var enemy_region_id: int = enemy_region.get_region_id()
		var enemy_player_id: int = enemy_army.get_player_id()
		var tracker_key: String = _extract_tracker_key_from_entity_id(army_entity_id)
		var tracked_power: int = player_manager.get_tracked_enemy_power(player_id, tracker_key)
		var reachability: Dictionary = _get_castle_reachability_in_one_turn(pathfinder, enemy_region_id, castle_region_id, enemy_player_id)
		var can_reach: bool = bool(reachability.get("can_reach", false))
		var reach_reason: String = String(reachability.get("reason", "no_path"))
		var reach_cost: int = int(reachability.get("cost", -1))
		scan_entries.append(_build_threat_scan_entry(army_entity_id, enemy_region_id, tracked_power >= 0, tracked_power if tracked_power >= 0 else -1, can_reach, reach_reason, reach_cost))
		if not can_reach:
			continue
		var observation: Dictionary = {
			"id": army_entity_id,
			"region_id": enemy_region_id,
			"player_id": enemy_player_id,
			"known": tracked_power >= 0,
			"power": tracked_power if tracked_power >= 0 else -1
		}
		observations_by_army_id[army_entity_id] = observation
	var registry: Dictionary = {}
	var total_threat_value: int = 0
	var threat_level: int = THREAT_LEVEL_NONE
	var known_groups: Dictionary = {}
	for army_entity_id in observations_by_army_id.keys():
		var observation: Dictionary = observations_by_army_id[army_entity_id]
		var is_known: bool = bool(observation.get("known", false))
		if not is_known:
			var unknown_entry: Dictionary = _build_threat_entry(observation, THREAT_UNKNOWN, "n/a", "n/a")
			registry[army_entity_id] = unknown_entry
			total_threat_value += int(unknown_entry.get("threat_value", 0))
			threat_level = max(threat_level, int(unknown_entry.get("threat_level", THREAT_LEVEL_NONE)))
			continue
		var region_id: int = int(observation.get("region_id", -1))
		if not known_groups.has(region_id):
			known_groups[region_id] = []
		known_groups[region_id].append(army_entity_id)
	for region_id_key in known_groups.keys():
		var grouped_ids: Array = known_groups.get(region_id_key, [])
		var requires_simulation: bool = not post_move_refresh
		if post_move_refresh:
			for grouped_army_id in grouped_ids:
				var current_obs: Dictionary = observations_by_army_id.get(grouped_army_id, {})
				var previous_entry: Dictionary = previous_registry.get(grouped_army_id, {})
				if previous_entry.is_empty():
					requires_simulation = true
					break
				if not bool(previous_entry.get("known", false)):
					requires_simulation = true
					break
				if int(previous_entry.get("region_id", -1)) != int(current_obs.get("region_id", -1)):
					requires_simulation = true
					break
				var previous_power: int = int(previous_entry.get("power", -1))
				var current_power: int = int(current_obs.get("power", -1))
				if previous_power <= 0:
					requires_simulation = true
					break
				var power_delta: float = abs(float(current_power - previous_power)) / max(1.0, float(previous_power))
				if power_delta > THREAT_POWER_CHANGE_THRESHOLD:
					requires_simulation = true
					break
		var threat_label: String = THREAT_CASTLE_SAFE
		var sim_castle_only_label: String = "n/a"
		var sim_with_army_label: String = "n/a"
		if requires_simulation:
			var grouped_armies: Array[Army] = []
			for grouped_army_id in grouped_ids:
				var grouped_army_entity_id: String = String(grouped_army_id)
				var grouped_army: Army = army_manager.get_army_by_entity_id(grouped_army_entity_id)
				if is_instance_valid(grouped_army):
					grouped_armies.append(grouped_army)
			if not grouped_armies.is_empty():
				var castle_only_sim: Dictionary = game_manager.simulate_castle_threat_battle(grouped_armies, castle_region, false, false)
				var castle_only_attacker_wins: bool = _is_attacker_victory_in_threat_simulation(castle_only_sim)
				var with_army_attacker_wins: bool = castle_only_attacker_wins
				if has_defender_army_in_castle:
					var with_army_sim: Dictionary = game_manager.simulate_castle_threat_battle(grouped_armies, castle_region, false, true)
					with_army_attacker_wins = _is_attacker_victory_in_threat_simulation(with_army_sim)
				sim_castle_only_label = _format_threat_sim_result_label(castle_only_attacker_wins)
				sim_with_army_label = _format_threat_sim_result_label(with_army_attacker_wins)
				if with_army_attacker_wins:
					threat_label = THREAT_BIG
				elif castle_only_attacker_wins:
					threat_label = THREAT_NEEDS_ARMY
				else:
					threat_label = THREAT_CASTLE_SAFE
		else:
			var previous_group_entry: Dictionary = previous_registry.get(grouped_ids[0], {})
			threat_label = String(previous_group_entry.get("threat", THREAT_CASTLE_SAFE))
			sim_castle_only_label = String(previous_group_entry.get("sim_castle_only", "n/a"))
			sim_with_army_label = String(previous_group_entry.get("sim_with_army", "n/a"))
		for grouped_army_id in grouped_ids:
			var known_observation: Dictionary = observations_by_army_id.get(grouped_army_id, {})
			var known_entry: Dictionary = _build_threat_entry(known_observation, threat_label, sim_castle_only_label, sim_with_army_label)
			registry[grouped_army_id] = known_entry
			total_threat_value += int(known_entry.get("threat_value", 0))
			threat_level = max(threat_level, int(known_entry.get("threat_level", THREAT_LEVEL_NONE)))
	return {
		"registry": registry,
		"total_threat_value": total_threat_value,
		"threat_level": threat_level,
		"scan_entries": scan_entries
	}

func _get_castle_reachability_in_one_turn(_pathfinder: ArmyPathfinder, enemy_region_id: int, castle_region_id: int, enemy_player_id: int) -> Dictionary:
	var mp_limit: int = GameParameters.MOVEMENT_POINTS_PER_TURN
	if enemy_region_id == castle_region_id:
		return {
			"can_reach": true,
			"reason": "reachable",
			"cost": 0
		}
	var best_cost_by_region: Dictionary = {}
	var open_nodes: Array[Dictionary] = []
	best_cost_by_region[enemy_region_id] = 0
	open_nodes.append({
		"region_id": enemy_region_id,
		"cost": 0
	})
	var best_target_cost: int = -1
	while not open_nodes.is_empty():
		var best_index: int = 0
		var best_cost: int = int(open_nodes[0].get("cost", 0))
		for i in range(1, open_nodes.size()):
			var candidate_cost: int = int(open_nodes[i].get("cost", 0))
			if candidate_cost < best_cost:
				best_cost = candidate_cost
				best_index = i
		var current_node: Dictionary = open_nodes[best_index]
		open_nodes.remove_at(best_index)
		var current_region_id: int = int(current_node.get("region_id", -1))
		var current_cost: int = int(current_node.get("cost", 0))
		var known_best_cost: int = int(best_cost_by_region.get(current_region_id, -1))
		if known_best_cost != -1 and current_cost > known_best_cost:
			continue
		if current_region_id == castle_region_id:
			best_target_cost = current_cost
			break
		var neighbors: Array = region_manager.get_neighbor_regions(current_region_id)
		for neighbor_variant in neighbors:
			var neighbor_id: int = int(neighbor_variant)
			var enter_cost: int = region_manager.calculate_terrain_cost(neighbor_id, enemy_player_id)
			if enter_cost < 0:
				continue
			if neighbor_id != castle_region_id:
				var neighbor_has_castle: bool = region_manager.get_castle_level(neighbor_id) > 0
				if neighbor_has_castle:
					var neighbor_owner_id: int = region_manager.get_region_owner(neighbor_id)
					if neighbor_owner_id != enemy_player_id:
						continue
			var next_cost: int = current_cost + enter_cost
			var previous_cost: int = int(best_cost_by_region.get(neighbor_id, -1))
			if previous_cost != -1 and next_cost >= previous_cost:
				continue
			best_cost_by_region[neighbor_id] = next_cost
			open_nodes.append({
				"region_id": neighbor_id,
				"cost": next_cost
			})
	if best_target_cost < 0:
		return {
			"can_reach": false,
			"reason": "no_path",
			"cost": -1
		}
	if best_target_cost > mp_limit:
		return {
			"can_reach": false,
			"reason": "insufficient_mp",
			"cost": best_target_cost
		}
	return {
		"can_reach": true,
		"reason": "reachable",
		"cost": best_target_cost
	}

func _build_threat_scan_entry(army_entity_id: String, region_id: int, known: bool, power: int, accepted: bool, reason: String, path_cost: int) -> Dictionary:
	return {
		"id": army_entity_id,
		"region_id": region_id,
		"known": known,
		"power": power,
		"accepted": accepted,
		"reason": reason,
		"path_cost": path_cost
	}

func _castle_has_defender_army_in_region(castle_region: Region, player_id: int) -> bool:
	var armies_in_region: Array[Army] = army_manager.get_armies_in_region(castle_region)
	for army in armies_in_region:
		if army.get_player_id() == player_id:
			return true
	return false

func _extract_tracker_key_from_entity_id(army_entity_id: String) -> String:
	if army_entity_id.begins_with("army_"):
		return army_entity_id.substr(5, army_entity_id.length() - 5)
	return army_entity_id

func _build_threat_entry(observation: Dictionary, threat_label: String, sim_castle_only: String, sim_with_army: String) -> Dictionary:
	return {
		"id": String(observation.get("id", "")),
		"region_id": int(observation.get("region_id", -1)),
		"player_id": int(observation.get("player_id", -1)),
		"known": bool(observation.get("known", false)),
		"power": int(observation.get("power", -1)),
		"threat": threat_label,
		"threat_value": _get_threat_value(threat_label),
		"threat_level": _get_threat_level(threat_label),
		"sim_castle_only": sim_castle_only,
		"sim_with_army": sim_with_army
	}

func _get_threat_value(threat_label: String) -> int:
	match threat_label:
		THREAT_CASTLE_SAFE:
			return THREAT_VALUE_CASTLE_SAFE
		THREAT_NEEDS_ARMY:
			return THREAT_VALUE_NEEDS_ARMY
		THREAT_UNKNOWN:
			return THREAT_VALUE_UNKNOWN
		THREAT_BIG:
			return THREAT_VALUE_BIG
		_:
			return 0

func _get_threat_level(threat_label: String) -> int:
	match threat_label:
		THREAT_CASTLE_SAFE:
			return THREAT_LEVEL_CASTLE_SAFE
		THREAT_NEEDS_ARMY:
			return THREAT_LEVEL_NEEDS_ARMY
		THREAT_UNKNOWN:
			return THREAT_LEVEL_UNKNOWN
		THREAT_BIG:
			return THREAT_LEVEL_BIG
		_:
			return THREAT_LEVEL_NONE

func _is_attacker_victory_in_threat_simulation(simulation: Dictionary) -> bool:
	var result: String = String(simulation.get("result", "defeat"))
	return result == "victory"

func _format_threat_sim_result_label(attacker_wins: bool) -> String:
	return "lose" if attacker_wins else "hold"

func _recalculate_castle_reserve_budgets(player_id: int) -> void:
	castle_reserved_budget_by_region.clear()
	_clear_reserved_recruitment_lock()
	var player: Player = player_manager.get_player(player_id)
	var weighted_castles: Dictionary = {}
	var ordered_castles: Array[int] = []
	for region_key in castle_total_threat_value_by_region.keys():
		var region_id: int = int(region_key)
		if region_manager.get_region_owner(region_id) != player_id:
			continue
		var region: Region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
		if not region.has_castle():
			continue
		var level: int = int(castle_threat_level_by_region.get(region_id, THREAT_LEVEL_NONE))
		var total_value: int = int(castle_total_threat_value_by_region.get(region_id, 0))
		if level <= THREAT_LEVEL_CASTLE_SAFE or total_value <= 0:
			continue
		weighted_castles[region_id] = float(total_value)
		ordered_castles.append(region_id)
	if ordered_castles.is_empty():
		return
	ordered_castles.sort()
	var gold_split: Dictionary = _split_weighted_int(_get_spendable_resource(player, ResourcesEnum.Type.GOLD), weighted_castles)
	var wood_split: Dictionary = _split_weighted_int(_get_spendable_resource(player, ResourcesEnum.Type.WOOD), weighted_castles)
	var iron_split: Dictionary = _split_weighted_int(_get_spendable_resource(player, ResourcesEnum.Type.IRON), weighted_castles)
	var lock_gold: int = 0
	var lock_wood: int = 0
	var lock_iron: int = 0
	for region_id in ordered_castles:
		var recruits_available: int = _get_castle_recruit_source_total(region_id, player_id)
		var raw_budget := BudgetComposition.new(
			int(gold_split.get(region_id, 0)),
			int(wood_split.get(region_id, 0)),
			int(iron_split.get(region_id, 0)),
			recruits_available
		)
		var capped_budget: BudgetComposition = _apply_castle_reserve_resource_caps(raw_budget, recruits_available)
		castle_reserved_budget_by_region[region_id] = capped_budget
		lock_gold += capped_budget.gold
		lock_wood += capped_budget.wood
		lock_iron += capped_budget.iron
	reserved_recruitment_lock = {
		ResourcesEnum.Type.GOLD: lock_gold,
		ResourcesEnum.Type.WOOD: lock_wood,
		ResourcesEnum.Type.IRON: lock_iron
	}

func _split_weighted_int(total_amount: int, weights: Dictionary) -> Dictionary:
	var split: Dictionary = {}
	var ordered_keys: Array = weights.keys()
	ordered_keys.sort()
	for key in ordered_keys:
		split[key] = 0
	if total_amount <= 0 or ordered_keys.is_empty():
		return split
	var sum_weights: float = 0.0
	for key in ordered_keys:
		sum_weights += max(0.0, float(weights.get(key, 0.0)))
	if sum_weights <= 0.0:
		return split
	var remainders: Array[Dictionary] = []
	var taken: int = 0
	for key in ordered_keys:
		var weight: float = max(0.0, float(weights.get(key, 0.0)))
		var raw_share: float = float(total_amount) * weight / sum_weights
		var floor_share: int = int(floor(raw_share))
		split[key] = floor_share
		taken += floor_share
		remainders.append({
			"key": key,
			"fraction": raw_share - float(floor_share)
		})
	remainders.sort_custom(func(a, b):
		var frac_a: float = float(a.get("fraction", 0.0))
		var frac_b: float = float(b.get("fraction", 0.0))
		if abs(frac_a - frac_b) < 0.0001:
			return int(a.get("key", 0)) < int(b.get("key", 0))
		return frac_a > frac_b
	)
	var remaining: int = total_amount - taken
	var idx: int = 0
	while remaining > 0 and not remainders.is_empty():
		var target_key: int = int(remainders[idx].get("key", 0))
		split[target_key] = int(split.get(target_key, 0)) + 1
		remaining -= 1
		idx += 1
		if idx >= remainders.size():
			idx = 0
	return split

func _apply_castle_reserve_resource_caps(budget: BudgetComposition, recruits_available: int) -> BudgetComposition:
	var capped_recruits: int = max(0, recruits_available)
	var gold_cap: int = int(floor(float(capped_recruits) * CASTLE_RESERVE_GOLD_PER_RECRUIT))
	var wood_cap: int = int(floor(float(capped_recruits) * CASTLE_RESERVE_WOOD_PER_RECRUIT))
	var iron_cap: int = int(floor(float(capped_recruits) * CASTLE_RESERVE_IRON_PER_RECRUIT))
	return BudgetComposition.new(
		min(budget.gold, gold_cap),
		min(budget.wood, wood_cap),
		min(budget.iron, iron_cap),
		capped_recruits
	)

func _get_castle_recruit_source_total(region_id: int, player_id: int) -> int:
	var sources: Array = region_manager.get_available_recruits_from_region_and_neighbors(region_id, player_id)
	var total_recruits: int = 0
	for source in sources:
		total_recruits += int(source.amount)
	return total_recruits

func _execute_reserved_castle_recruitment(player_id: int) -> Dictionary:
	var processed: int = 0
	var recruited: int = 0
	var entries: Array[String] = []
	var ordered_regions: Array[int] = []
	for region_key in castle_reserved_budget_by_region.keys():
		ordered_regions.append(int(region_key))
	ordered_regions.sort()
	for region_id in ordered_regions:
		var region: Region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
		if not region.has_castle():
			continue
		var budget: BudgetComposition = castle_reserved_budget_by_region.get(region_id, null)
		if budget == null:
			continue
		if budget.available_recruits <= 0:
			budget.available_recruits = _get_castle_recruit_source_total(region_id, player_id)
		var result: Dictionary = recruitment_manager.hire_garrison(region, budget, player_id)
		var hired: int = int(result.get("total_recruited", 0))
		if hired <= 0:
			continue
		processed += 1
		recruited += hired
		entries.append(_format_castle_hire_entry(region.get_region_name(), result))
	var reason: String = "success" if processed > 0 else "no_threatened_castles"
	return {
		"processed": processed,
		"recruited": recruited,
		"entries": entries,
		"reason": reason
	}

func _format_castle_threat_summary_lines(player_id: int) -> Array[String]:
	var lines: Array[String] = []
	var ordered_regions: Array[int] = []
	for region_key in castle_threat_level_by_region.keys():
		ordered_regions.append(int(region_key))
	ordered_regions.sort()
	for region_id in ordered_regions:
		if region_manager.get_region_owner(region_id) != player_id:
			continue
		var region: Region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
		if not region.has_castle():
			continue
		var threat_level: int = int(castle_threat_level_by_region.get(region_id, THREAT_LEVEL_NONE))
		var total_value: int = int(castle_total_threat_value_by_region.get(region_id, 0))
		var threat_registry: Dictionary = castle_threat_registry_by_region.get(region_id, {})
		lines.append("%s: level=%d total=%d threats=%d" % [
			region.get_region_name(),
			threat_level,
			total_value,
			threat_registry.size()
		])
		var scan_entries: Array = castle_threat_scan_entries_by_region.get(region_id, [])
		_append_castle_threat_scan_lines(lines, scan_entries)
		_append_castle_threat_detail_lines(lines, threat_registry)
	return lines

func _append_castle_threat_scan_lines(lines: Array[String], scan_entries: Array) -> void:
	if scan_entries.is_empty():
		return
	var accepted_entries: Array[Dictionary] = []
	var rejected_entries: Array[Dictionary] = []
	for scan_entry_variant in scan_entries:
		var scan_entry: Dictionary = scan_entry_variant
		if bool(scan_entry.get("accepted", false)):
			accepted_entries.append(scan_entry)
		else:
			rejected_entries.append(scan_entry)
	accepted_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_cost: int = int(a.get("path_cost", 999))
		var b_cost: int = int(b.get("path_cost", 999))
		if a_cost != b_cost:
			return a_cost < b_cost
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	rejected_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_reason: String = String(a.get("reason", ""))
		var b_reason: String = String(b.get("reason", ""))
		if a_reason != b_reason:
			return a_reason < b_reason
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	for accepted_entry in accepted_entries:
		lines.append("  - nearby " + _format_threat_scan_entry_line(accepted_entry, "accepted"))
	for rejected_entry in rejected_entries:
		lines.append("  - rejected " + _format_threat_scan_entry_line(rejected_entry, "rejected"))

func _format_threat_scan_entry_line(scan_entry: Dictionary, status_label: String) -> String:
	var threat_id: String = String(scan_entry.get("id", "unknown_threat"))
	var region_id: int = int(scan_entry.get("region_id", -1))
	var region_name: String = "Unknown region"
	if region_id >= 0:
		var threat_region: Region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
		region_name = threat_region.get_region_name()
	var known: bool = bool(scan_entry.get("known", false))
	var power: int = int(scan_entry.get("power", -1))
	var reason: String = String(scan_entry.get("reason", ""))
	var path_cost: int = int(scan_entry.get("path_cost", -1))
	var intel_label: String = "known" if known else "unknown"
	var power_text: String = str(power) if known and power >= 0 else "unknown"
	var cost_text: String = str(path_cost) if path_cost >= 0 else "n/a"
	return "%s @ %s (#%d): %s, intel=%s, power=%s, reason=%s, path_cost=%s" % [
		threat_id,
		region_name,
		region_id,
		status_label,
		intel_label,
		power_text,
		reason,
		cost_text
	]

func _append_castle_threat_detail_lines(lines: Array[String], threat_registry: Dictionary) -> void:
	if threat_registry.is_empty():
		return
	var entries: Array[Dictionary] = []
	for threat_key in threat_registry.keys():
		var threat_entry: Dictionary = threat_registry.get(threat_key, {})
		entries.append(threat_entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_level: int = int(a.get("threat_level", THREAT_LEVEL_NONE))
		var b_level: int = int(b.get("threat_level", THREAT_LEVEL_NONE))
		if a_level != b_level:
			return a_level > b_level
		var a_known: bool = bool(a.get("known", false))
		var b_known: bool = bool(b.get("known", false))
		if a_known != b_known:
			return a_known
		var a_power: int = int(a.get("power", -1))
		var b_power: int = int(b.get("power", -1))
		if a_power != b_power:
			return a_power > b_power
		var a_id: String = String(a.get("id", ""))
		var b_id: String = String(b.get("id", ""))
		return a_id < b_id
	)
	for threat_entry in entries:
		lines.append("  - " + _format_castle_threat_entry_line(threat_entry))

func _format_castle_threat_entry_line(threat_entry: Dictionary) -> String:
	var threat_id: String = String(threat_entry.get("id", "unknown_threat"))
	var region_id: int = int(threat_entry.get("region_id", -1))
	var region_name: String = "Unknown region"
	if region_id >= 0:
		var threat_region: Region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
		if threat_region != null:
			region_name = threat_region.get_region_name()
		else:
			region_name = "Region %d" % region_id
	var threat_label: String = String(threat_entry.get("threat", THREAT_CASTLE_SAFE))
	var threat_level: int = int(threat_entry.get("threat_level", THREAT_LEVEL_NONE))
	var known: bool = bool(threat_entry.get("known", false))
	var tracked_power: int = int(threat_entry.get("power", -1))
	var sim_castle_only: String = String(threat_entry.get("sim_castle_only", "n/a"))
	var sim_with_army: String = String(threat_entry.get("sim_with_army", "n/a"))
	var intel_label: String = "known" if known else "unknown"
	var power_text: String = str(tracked_power) if known and tracked_power >= 0 else "unknown"
	return "%s @ %s (#%d): threat=%s(level=%d), intel=%s, power=%s, sim_castle_only=%s, sim_with_army=%s" % [
		threat_id,
		region_name,
		region_id,
		threat_label,
		threat_level,
		intel_label,
		power_text,
		sim_castle_only,
		sim_with_army
	]

func _format_castle_reserve_summary_lines(player_id: int) -> Array[String]:
	var lines: Array[String] = []
	var ordered_regions: Array[int] = []
	for region_key in castle_reserved_budget_by_region.keys():
		ordered_regions.append(int(region_key))
	ordered_regions.sort()
	for region_id in ordered_regions:
		if region_manager.get_region_owner(region_id) != player_id:
			continue
		var region: Region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
		if not region.has_castle():
			continue
		var budget: BudgetComposition = castle_reserved_budget_by_region.get(region_id, null)
		if budget == null:
			continue
		lines.append("%s reserve -> gold:%d wood:%d iron:%d recruits:%d" % [
			region.get_region_name(),
			budget.gold,
			budget.wood,
			budget.iron,
			budget.available_recruits
		])
	return lines

func _format_unit_breakdown(hired: Dictionary) -> String:
	if hired == null:
		return "none"
	var parts: Array[String] = []
	for unit_type in UNIT_LOG_ORDER:
		var count = int(hired.get(unit_type, 0))
		if count > 0:
			var label = UNIT_LOG_CODES.get(unit_type, "?")
			parts.append("%s: %d" % [label, count])
	return ", ".join(parts) if parts.size() > 0 else "none"

func _format_castle_hire_entry(region_name: String, result: Dictionary) -> String:
	var total = int(result.get("total_recruited", 0))
	var breakdown = _format_unit_breakdown(result.get("hired", {}))
	var spent_gold = int(result.get("spent_gold", 0))
	var recruits_left = int(result.get("recruits_left", -1))
	var entry = "%s: %d units (%s) - gold spent: %d" % [region_name, total, breakdown, spent_gold]
	if recruits_left >= 0:
		entry += ", recruits left: %d" % recruits_left
	return entry

func _format_army_hire_entry(army: Army, location: Region, result: Dictionary) -> String:
	var total = int(result.get("total_recruited", 0))
	var breakdown = _format_unit_breakdown(result.get("hired", {}))
	var spent_gold = int(result.get("spent_gold", 0))
	var recruits_left = int(result.get("recruits_left", -1))
	var entry = "%s at %s: %d units (%s) - gold spent: %d" % [army.name, location.get_region_name(), total, breakdown, spent_gold]
	if recruits_left >= 0:
		entry += ", recruits left: %d" % recruits_left
	return entry

func _get_castle_weight(castle_type: CastleTypeEnum.Type) -> float:
	match castle_type:
		CastleTypeEnum.Type.OUTPOST:
			return 1.0
		CastleTypeEnum.Type.KEEP:
			return 2.0
		CastleTypeEnum.Type.CASTLE:
			return 3.0
		CastleTypeEnum.Type.STRONGHOLD:
			return 4.0
		_:
			return 0.0

func _get_castle_threat_weight(region: Region, enemy_castles: Array[int]) -> float:
	var base_weight = _get_castle_weight(region.get_castle_type())
	if base_weight <= 0.0:
		return 0.0
	if enemy_castles.is_empty():
		return base_weight
	var distance = _calculate_distance_to_enemy_castles(region.get_region_id(), enemy_castles)
	if distance <= 0:
		distance = 1
	return base_weight / float(distance)

func _log_trade(message: String) -> void:
	DebugLogger.log("AIEconomy", message)
	game_manager.ensure_ai_log_started()
	var ai_log = game_manager.get_ai_log_manager()
	ai_log.log_economy(message)

func _log_recruitment(message: String) -> void:
	var ai_log = game_manager.get_ai_log_manager()
	ai_log.log_recruitment(message)
	
func _log_economy(message: String) -> void:
	var ai_log = game_manager.get_ai_log_manager()
	ai_log.log_economy(message)
