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

const BUILD_CASTLE_TYPE := CastleTypeEnum.Type.OUTPOST
const STRATEGIC_SCORE_SCALE := 10.0
const FRIENDLY_NEIGHBOR_VALUE := 15.0
const NEUTRAL_NEIGHBOR_VALUE := 5.0
const ENEMY_NEIGHBOR_PENALTY := 10.0
const CASTLE_SCORE_THRESHOLD := 100.0
const MAX_DISTANCE := 9999
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

func plan_turn(player_id: int, turn_number: int) -> Dictionary:
	DebugLogger.log("AIEconomy", "\n=== AI ECONOMY TURN PLANNING (Player %d, Turn %d) ===" % [player_id, turn_number])
	
	# Snapshot signals once and rebuild garrison queue
	signals = _compute_signals(player_id, turn_number)
	garrison_skip_logs = []
	garrison_requests = _build_garrison_requests(player_id)
	var summary: Dictionary = {
		"decision": "sequential",
		"signals": signals
	}
	
	# Step 1: Army recruitment budgets (armies + dangerous castles)
	var army_recruitment = army_recruitments(player_id, turn_number)
	summary["army_recruitment"] = army_recruitment
	
	# Step 2: Raise armies when allowed
	var raise_res = decide_and_raise_army(player_id, turn_number)
	summary["raise"] = raise_res
	
	# Step 3: Build castles
	var build_castle = _evaluate_build_castle(player_id, turn_number)
	summary["build_castle"] = build_castle
	
	# Step 4: Upgrade castles
	var upgrade_castle = _evaluate_upgrade_castle(player_id, turn_number)
	summary["upgrade_castle"] = upgrade_castle
	
	# Step 5: Repair damaged castles
	var repair_castle = _evaluate_repair_castle(player_id)
	summary["repair_castle"] = repair_castle
	
	# Step 6: Upgrade regions
	var upgrade_region = _evaluate_upgrade_region(player_id, turn_number)
	summary["upgrade_region"] = upgrade_region
	
	# Step 7: Ore searches
	var ore_result = ore_checks(player_id)
	summary["ore"] = ore_result
	
	# Step 8: Additional castle recruitment (threat-weighted)
	var garrison_trickle = perform_garrison_trickle(player_id, turn_number)
	summary["garrison_trickle"] = garrison_trickle
	
	# Step 9: Trading (sell surplus, buy to cover food deficit)
	var trade_result = _execute_ai_trades(player_id)
	summary["trade"] = trade_result
	
	summary["recruitment_candidates"] = army_recruitment["candidates"]
	DebugLogger.log("AIEconomy", "=== END AI ECONOMY TURN PLANNING ===\n")
	return summary

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
			if not player.can_afford_cost(cost):
				repairs.append({"region_id": region.get_region_id(), "reason": "no_resources"})
				continue
			if region_manager.try_repair_castle(region, player):
				repairs.append({"region_id": region.get_region_id(), "reason": "started"})
				DebugLogger.log("AIEconomy", "   REPAIR CASTLE: Started repair at region %s" % [region.get_region_name()])
				return {"executed": true, "repairs": repairs, "reason": "repair_started"}
	return {"executed": false, "repairs": repairs, "reason": "no_repair_started"}

func army_recruitments(player_id, turn_number):
	var armies_need = _find_recruitment_armies_at_castles(player_id, turn_number)
	var recruitment_candidates_desc = _describe_recruitment_candidates(armies_need)
	var army_recruitment: Dictionary = {
		"needs": armies_need.size(),
		"candidates": recruitment_candidates_desc,
		"garrison_danger": garrison_requests.size(),
		"garrison_skip_logs": garrison_skip_logs.duplicate()
	}
	var assigned_budgets = _allocate_recruitment(player_id, turn_number, garrison_requests)
	army_recruitment["budgets_assigned"] = assigned_budgets
	var army_hires = _execute_army_recruitment(player_id, armies_need)
	army_recruitment["army_hires"] = army_hires
	var garrison_defense = execute_garrison_recruitment(player_id)
	var defense_entries: Array = garrison_defense.get("entries", [])
	var defense_reason = "no castles in danger"
	if garrison_requests.size() > 0:
		defense_reason = "success" if defense_entries.size() > 0 else "no resources available"
	army_recruitment["garrison_defense_entries"] = defense_entries
	army_recruitment["garrison_defense_reason"] = defense_reason
	return army_recruitment

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
		if player.get_resource_amount(ResourcesEnum.Type.GOLD) < search_cost:
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
	return budget_manager.allocate_recruitment_budgets(armies, player, region_manager, turn_number, castle_garrison_requests)

func _execute_army_recruitment(player_id: int, armies: Array[Army]) -> Array[String]:
	var entries: Array[String] = []
	if recruitment_manager == null:
		return entries
	for army in armies:
		if army == null or not is_instance_valid(army):
			continue
		var location := army.get_parent() as Region
		if location == null:
			continue
		var budget = army.assigned_budget
		if budget == null:
			continue
		var result = recruitment_manager.hire_soldiers(army)
		var total := int(result.get("total_recruited", 0))
		if total > 0:
			var entry = _format_army_hire_entry(army, location, result)
			entries.append(entry)
	return entries

# Find armies at castles that need recruitment
func _find_recruitment_armies_at_castles(player_id: int, turn_number: int) -> Array[Army]:
	var out: Array[Army] = []
	var armies = army_manager.get_player_armies(player_id)
	for a in armies:
		if a.needs_recruitment(turn_number):
			# Always flag the army as needing recruitment
			a.request_recruitment()
			# But only add to output list if at castle (for budget allocation)
			var r: Region = a.get_parent()
			var rid = r.get_region_id()
			if region_manager.get_castle_level(rid) >= 1:
				out.append(a)
	return out

# Main orchestrator for raise army decision
func decide_and_raise_army(player_id: int, turn_number: int) -> Dictionary:
	DebugLogger.log("AIEconomy", "   Evaluating raise army decision...")
	var candidate = pick_best_raise_region(player_id)
	var player = player_manager.get_player(player_id)
	
	if candidate.is_empty():
		DebugLogger.log("AIEconomy", "   Decision: NO - No valid castle regions with sufficient recruits")
		return {"raised": false, "reason": "no_candidate"}
	
	DebugLogger.log("AIEconomy", "   Best candidate: Region %d (recruits: %d, score: %.1f)" % [candidate["region_id"], candidate["recruits_total"], candidate["score"]])
	
	var should_raise = should_raise_army(candidate, player)
	if should_raise:
		DebugLogger.log("AIEconomy", "   Decision: YES - All constraints satisfied")
		var success = execute_raise_army(player_id, candidate["region_id"])
		if success:
			DebugLogger.log("AIEconomy", "   Execution: SUCCESS - Army raised at region %d" % candidate["region_id"])
			return {"raised": true, "region_id": candidate["region_id"]}
		else:
			DebugLogger.log("AIEconomy", "   Execution: FAILED - Could not deduct gold cost")
			return {"raised": false, "reason": "execution_failed"}
	else:
		return {"raised": false, "reason": "guards_failed"}

# Pick the best castle region to raise an army at
func pick_best_raise_region(player_id: int) -> Dictionary:
	DebugLogger.log("AIEconomy", "   Searching for castle regions with sufficient recruits...")
	var owned_regions = region_manager.get_player_regions(player_id)
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
		var recruit_sources = region_manager.get_available_recruits_from_region_and_neighbors(region_id, player_id)
		var recruits_total = 0
		for source in recruit_sources:
			recruits_total += int(source.amount)
		
		DebugLogger.log("AIEconomy", "   Castle %d: %d recruits (min: %d)" % [region_id, recruits_total, GameParameters.AI_MIN_RECRUITS_FOR_RAISING])
		
		if recruits_total < GameParameters.AI_MIN_RECRUITS_FOR_RAISING:
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
		
		candidates.append({
			"region_id": region_id,
			"recruits_total": recruits_total,
			"frontier_near": frontier_near,
			"travel_hint": travel_hint
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
		candidate["score"] = score
		DebugLogger.log("AIEconomy", "   Candidate %d: score %.1f (recruits: %.2f*%.1f, frontier: %d*%.1f, travel: %d*%.1f)" % [
			candidate["region_id"], score,
			recruits_norm, GameParameters.AI_CAND_W_RECRUITS,
			candidate["frontier_near"], GameParameters.AI_CAND_W_FRONTIER_NEAR,
			candidate["travel_hint"], GameParameters.AI_CAND_W_TRAVEL
		])
	
	# Pick highest score with deterministic tie-break
	candidates.sort_custom(func(a, b): 
		if abs(a["score"] - b["score"]) < 0.001:
			return a["region_id"] < b["region_id"]  # Tie-break by region_id
		return a["score"] > b["score"]
	)

	DebugLogger.log("AIEconomy", "   Winner: Region %d (score: %.1f)" % [candidates[0]["region_id"], candidates[0]["score"]])
	
	return candidates[0]

# Decide whether to raise an army this turn
func should_raise_army(candidate: Dictionary, player: Player) -> bool:
	# New normalized model: region/army ratio, avg distance (MP), recruits, gold
	if candidate.is_empty():
		DebugLogger.log("AIEconomy", "   Constraint: NO_CANDIDATE")
		return false
	
	var regions := region_manager.get_player_regions(player.get_player_id()).size()
	var armies_arr := army_manager.get_player_armies(player.get_player_id())
	var armies_count := armies_arr.size()
	
	# Average MP distance from existing armies to the candidate castle
	var castle_id: int = candidate["region_id"]
	var avg_dist := _compute_avg_distance_to_castle(armies_arr, castle_id, player.get_player_id())
	var recruits_total := int(candidate["recruits_total"])
	var gold := int(player.get_resource_amount(ResourcesEnum.Type.GOLD))
	
	# Hard gates
	var gold_after := gold - GameParameters.RAISE_ARMY_COST
	if gold_after < GameParameters.AI_RESERVE_GOLD_MIN:
		DebugLogger.log("AIEconomy", "   Gate FAIL: GOLD_RESERVE (current: %d, after: %d, min: %d)" % [gold, gold_after, GameParameters.AI_RESERVE_GOLD_MIN])
		return false
	if recruits_total < GameParameters.AI_MIN_RECRUITS_FOR_RAISING:
		DebugLogger.log("AIEconomy", "   Gate FAIL: RECRUITS_MIN (%d < %d)" % [recruits_total, GameParameters.AI_MIN_RECRUITS_FOR_RAISING])
		return false
	
	var decision := RaiseArmyDecision.should_raise_army_simple(regions, armies_count, avg_dist, recruits_total, gold)
	var s := RaiseArmyDecision.score(regions, armies_count, avg_dist, recruits_total, gold)
	DebugLogger.log("AIEconomy", "   Score: %.2f (r=%d, a=%d, dist=%.1f, rec=%d, gold=%d) vs thr=%.2f" % [
		s, regions, armies_count, avg_dist, recruits_total, gold, GameParameters.AI_RAISE_THRESHOLD_NORM])
	DebugLogger.log("AIEconomy", "   Decision: %s" % ("RAISE" if decision else "DECLINE"))
	return decision

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
	if not player.remove_resources(ResourcesEnum.Type.GOLD, GameParameters.RAISE_ARMY_COST):
		DebugLogger.log("AIEconomy", "Recruitment: cannot remove resources")
		return false
	
	# Create the army
	var new_army := army_manager.create_army(region_container, player_id, true)
	if new_army == null:
		player.add_resources(ResourcesEnum.Type.GOLD, GameParameters.RAISE_ARMY_COST)
		DebugLogger.log("AIEconomy", "Recruitment: army creation failed")
		return false
	DebugLogger.log("AIEconomy", "Recruitment: army creation successfully")
	return true

# Post-movement economy pass: spend leftovers on region economy only
func _evaluate_build_castle(player_id: int, turn_number: int) -> Dictionary:
	var player = player_manager.get_player(player_id)
	if player == null:
		return {"executed": false, "reason": "no_player"}
	var candidate_info = _pick_castle_build_candidate(player_id)
	var candidate_id = int(candidate_info.get("best_region_id", -1))
	var detail_entries: Array = candidate_info.get("details", [])
	var detail_summary = _limit_candidate_details(detail_entries)
	if candidate_id == -1:
		return {
			"executed": false,
			"reason": "no_viable_candidate",
			"details": detail_summary
		}
	var cost = GameParameters.get_castle_building_cost(BUILD_CASTLE_TYPE)
	if cost.is_empty():
		return {"executed": false, "reason": "no_cost_data", "details": detail_summary}
	if not player.can_afford_cost(cost):
		return {"executed": false, "reason": "insufficient_resources", "details": detail_summary}
	var region = region_manager.map_generator.get_region_container_by_id(candidate_id) as Region
	if region == null:
		return {"executed": false, "reason": "region_missing", "details": detail_summary}
	if not player.pay_cost(cost):
		return {"executed": false, "reason": "deduction_failed", "details": detail_summary}
	region.start_castle_construction(BUILD_CASTLE_TYPE)
	DebugLogger.log("AIEconomy", "   BUILD CASTLE: Started %s at region %s" % [
		CastleTypeEnum.type_to_string(BUILD_CASTLE_TYPE),
		region.get_region_name()
	])
	return {"executed": true, "region_id": candidate_id, "details": detail_summary, "reason": "built"}

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
			"score_pass": total_score >= CASTLE_SCORE_THRESHOLD
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
	var score = 0.0
	for neighbor_id in neighbor_ids:
		var owner_id = region_manager.get_region_owner(neighbor_id)
		if owner_id == player_id:
			score += FRIENDLY_NEIGHBOR_VALUE
		elif owner_id == -1:
			score += NEUTRAL_NEIGHBOR_VALUE
		else:
			score -= ENEMY_NEIGHBOR_PENALTY
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
			var neighbors = region_manager.get_neighbor_regions(int(rid))
			for neighbor_id in neighbors:
				excluded[neighbor_id] = true
	return excluded

func _limit_candidate_details(all_details: Array) -> Array:
	var limited: Array = []
	var max_entries = min(3, all_details.size())
	for i in range(max_entries):
		limited.append(all_details[i])
	return limited

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
	var candidate_info = _pick_castle_upgrade_candidate(player_id)
	var candidate_id = int(candidate_info.get("best_region_id", -1))
	var detail_entries: Array = candidate_info.get("details", [])
	var detail_summary = _limit_candidate_details(detail_entries)
	if candidate_id == -1:
		return {"executed": false, "reason": "no_upgrade_candidates", "details": detail_summary}
	var region = region_manager.map_generator.get_region_container_by_id(candidate_id) as Region
	if region == null:
		return {"executed": false, "reason": "region_missing", "details": detail_summary}
	if region.is_castle_under_construction():
		return {"executed": false, "reason": "castle_under_construction", "details": detail_summary}
	var current_type = region.get_castle_type()
	var next_type = CastleTypeEnum.get_next_level(current_type)
	if next_type == CastleTypeEnum.Type.NONE:
		return {"executed": false, "reason": "max_level_reached", "details": detail_summary}
	var cost = GameParameters.get_castle_building_cost(next_type)
	if cost.is_empty():
		return {"executed": false, "reason": "no_cost_data", "details": detail_summary}
	if not player.can_afford_cost(cost):
		return {"executed": false, "reason": "insufficient_resources", "details": detail_summary}
	if not player.pay_cost(cost):
		return {"executed": false, "reason": "deduction_failed", "details": detail_summary}
	region.start_castle_construction(next_type)
	DebugLogger.log("AIEconomy", "   UPGRADE CASTLE: Started %s at region %s" % [
		CastleTypeEnum.type_to_string(next_type),
		region.get_region_name()
	])
	return {"executed": true, "region_id": candidate_id, "details": detail_summary, "reason": "upgrade_started"}

func _evaluate_upgrade_region(player_id: int, turn_number: int) -> Dictionary:
	var player = player_manager.get_player(player_id)
	if player == null:
		return {"executed": false, "reason": "no_player", "details": [], "actions": [], "action_entries": []}
	# Quick affordability check for the cheapest upgrade (L1 -> L2)
	var min_upgrade_cost: Dictionary = GameParameters.REGION_PROMOTION_COSTS.get(RegionLevelEnum.Level.L2, {})
	if not min_upgrade_cost.is_empty() and not player.can_afford_cost(min_upgrade_cost):
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
			var region_id = int(detail.get("region_id", -1))
			var score = float(detail.get("score", 0.0))
			if region_id == -1 or score <= 0.0:
				skip_reasons.append("Region %d: low_score" % region_id)
				continue
			var next_level = int(detail.get("next_level", RegionLevelEnum.Level.L1))
			var cost: Dictionary = detail.get("cost", {})
			if cost.is_empty():
				skip_reasons.append("Region %d: no_cost_data" % region_id)
				continue
			var region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
			if region == null:
				skip_reasons.append("Region %d: region_missing" % region_id)
				continue
			if region.get_promotion_cooldown() > 0:
				skip_reasons.append("Region %d: cooldown_active" % region_id)
				continue
			var food_cost = int(cost.get(ResourcesEnum.Type.FOOD, 0))
			if not player_manager.meets_food_upgrade_safeguard(player_id, food_cost):
				skip_reasons.append("Region %d: food_safeguard" % region_id)
				continue
			if not player.can_afford_cost(cost):
				skip_reasons.append("Region %d: insufficient_resources" % region_id)
				continue
			if not player.pay_cost(cost):
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
	var wood_positive := player_manager.get_player_resource_growth(player_id, ResourcesEnum.Type.WOOD) > 0.0
	var iron_positive := player_manager.get_player_resource_growth(player_id, ResourcesEnum.Type.IRON) > 0.0
	var owned_regions = region_manager.get_player_regions(player_id)
	var processed := 0
	var added := 0
	var entries: Array[String] = []
	for region_id in owned_regions:
		var region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
		if not region.has_castle():
			continue
		var units_to_add = GameParameters.get_garrison_trickle_units(region.get_castle_type())
		if units_to_add <= 0:
			continue
		for i in range(units_to_add):
			var unit_type = _pick_trickle_unit(region.get_castle_type(), wood_positive, iron_positive)
			region.add_soldiers_to_garrison(unit_type, 1)
			added += 1
		processed += 1
		entries.append(region.get_region_name() + ": +" + str(units_to_add))
	var reason = "success" if processed > 0 else "no_castles"
	return {"processed": processed, "recruited": added, "reason": reason, "entries": entries}

func _execute_ai_trades(player_id: int) -> Dictionary:
	var player = player_manager.get_player(player_id)
	var sold: Array = []
	var bought: Array = []
	var actions: Array[String] = []
	var gold_change := 0
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
	
	var food_growth = player_manager.get_player_resource_growth(player_id, ResourcesEnum.Type.FOOD)
	if food_growth < 0.0:
		var deficit = int(ceil(-food_growth))
		if deficit > 0:
			var buy_result = trade_manager.buy(player_id, ResourcesEnum.Type.FOOD, deficit)
			var buy_entry = {
				"resource": ResourcesEnum.type_to_string(ResourcesEnum.Type.FOOD),
				"amount": deficit,
				"success": buy_result.get("success", false)
			}
			if buy_result.get("success", false):
				var delta_gold_buy = int(buy_result.get("gold_change", 0))
				buy_entry["gold_change"] = delta_gold_buy
				gold_change += delta_gold_buy
				var buy_msg = "Bought %d Food (gold change %d)" % [deficit, delta_gold_buy]
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
