extends RefCounted
class_name EconomyAIManager

# Foundation for AI economy planning. KISS: keep recruitment wired, stub others.

var region_manager: RegionManager
var army_manager: ArmyManager
var player_manager: PlayerManagerNode
var budget_manager: BudgetManager
var signals: Dictionary

const BUILD_CASTLE_TYPE := CastleTypeEnum.Type.OUTPOST
const STRATEGIC_SCORE_SCALE := 10.0
const FRIENDLY_NEIGHBOR_VALUE := 15.0
const NEUTRAL_NEIGHBOR_VALUE := 5.0
const ENEMY_NEIGHBOR_PENALTY := 10.0
const CASTLE_SCORE_THRESHOLD := 100.0
const MAX_DISTANCE := 9999

static var _region_distance_cache: Dictionary = {}
static var _cached_region_count: int = 0

func _init(_region_manager: RegionManager, _army_manager: ArmyManager, _player_manager: PlayerManagerNode) -> void:
	region_manager = _region_manager
	army_manager = _army_manager
	player_manager = _player_manager
	budget_manager = BudgetManager.new()

# Public entry: plan and allocate budgets for this player's turn.
# Currently only recruitment is executed; other categories are stubs.
func plan_turn(player_id: int, turn_number: int) -> Dictionary:
	DebugLogger.log("AIEconomy", "\n=== AI ECONOMY TURN PLANNING (Player %d, Turn %d) ===" % [player_id, turn_number])
	
	# Snapshot signals once
	signals = _compute_signals(player_id, turn_number)

	# 1) If any armies at castles need recruitment → allocate budgets and stop (skip raise/builds)
	var armies_need = _find_recruitment_armies_at_castles(player_id, turn_number)
	var recruitment_candidates_desc = _describe_recruitment_candidates(armies_need)
	if armies_need.size() > 0:
		DebugLogger.log("AIEconomy", ">> PRIORITY: RECRUITMENT — " + str(armies_need.size()) + " army(ies) at castles need units")
		var assigned1 = _allocate_recruitment(player_id, turn_number)
		DebugLogger.log("AIEconomy", ">> RECRUITMENT: Assigned budgets to " + str(assigned1) + " armies; skipping raise/builds this turn")
		DebugLogger.log("AIEconomy", "=== END AI ECONOMY TURN PLANNING ===\n")
		return {
			"decision": "recruit_only",
			"recruit_assigned": assigned1,
			"signals": signals,
			"recruitment_candidates": recruitment_candidates_desc,
			"raise": {"raised": false, "reason": "skipped_due_to_recruitment"}
		}

	# 2) Otherwise try to raise an army; if raised → allocate recruitment for it and stop
	DebugLogger.log("AIEconomy", ">> PRIORITY: RAISE ARMY — no armies need recruitment")
	var raise_res = decide_and_raise_army(player_id, turn_number)
	if raise_res.get("raised", false):
		var assigned2 = _allocate_recruitment(player_id, turn_number)
		DebugLogger.log("AIEconomy", ">> RAISE ARMY: Raised at region " + str(raise_res.get("region_id", -1)) + "; post-raise recruitment assigned to " + str(assigned2) + " armies")
		DebugLogger.log("AIEconomy", "=== END AI ECONOMY TURN PLANNING ===\n")
		return {
			"decision": "raised_then_recruit",
			"raise": raise_res,
			"recruit_assigned": assigned2,
			"signals": signals,
			"recruitment_candidates": recruitment_candidates_desc
		}
	else:
		DebugLogger.log("AIEconomy", ">> RAISE ARMY: Skipped — " + str(raise_res.get("reason", "unknown")))

# 3) No recruitment needs and no raise → defer region economy to post-movement phase
	DebugLogger.log("AIEconomy", ">> PRIORITY: NONE — deferring region economy to post-movement phase")
	DebugLogger.log("AIEconomy", "=== END AI ECONOMY TURN PLANNING ===\n")
	return {
		"decision": "defer_region_economy",
		"signals": signals,
		"recruit_assigned": 0,
		"recruitment_candidates": recruitment_candidates_desc,
		"raise": raise_res
	}

func ore_checks(player_id: int) -> void:
	var player := player_manager.get_player(player_id)
	var owned_regions := region_manager.get_player_regions(player_id)
	var search_cost := GameParameters.get_ore_search_cost()
	for region_id in owned_regions:
		if player.get_resource_amount(ResourcesEnum.Type.GOLD) < search_cost:
			return
		var region := region_manager.map_generator.get_region_container_by_id(region_id) as Region
		if region.can_search_for_ore():
			region.search_for_ore()
			player.remove_resources(ResourcesEnum.Type.GOLD, search_cost)

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
func _allocate_recruitment(player_id: int, turn_number: int) -> int:
	var player = player_manager.get_player(player_id)
	var armies: Array[Army] = army_manager.get_player_armies(player_id)
	return budget_manager.allocate_recruitment_budgets(armies, player, region_manager, turn_number)

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
	
	# Check and deduct cost
	if not player.remove_resources(ResourcesEnum.Type.GOLD, GameParameters.RAISE_ARMY_COST):
		return false
	
	# Get the region container
	var region_container = region_manager.map_generator.get_region_container_by_id(region_id)
	
	# Create the army
	army_manager.create_army(region_container, player_id, true)
	return true

# Post-movement economy pass: spend leftovers on region economy only
func plan_post_movement(player_id: int, turn_number: int) -> Dictionary:
	DebugLogger.log("AIEconomy", "\n=== AI ECONOMY POST-MOVEMENT (Player %d, Turn %d) ===" % [player_id, turn_number])
	# Recompute snapshot (cheap) to base any simple heuristics on fresh state
	signals = _compute_signals(player_id, turn_number)
	var reg_actions = _process_region_economy(player_id, turn_number)
	DebugLogger.log("AIEconomy", ">> REGION ECONOMY (post-move): " + str(reg_actions))
	DebugLogger.log("AIEconomy", "=== END AI ECONOMY POST-MOVEMENT ===\n")
	return {"decision": "region_economy_post", "region_actions": reg_actions, "signals": signals}

func _process_region_economy(player_id: int, turn_number: int) -> Dictionary:
	# Try to build a castle before moving on to other upgrades
	var build_result = _evaluate_build_castle(player_id, turn_number)
	var build_details = build_result.get("details", [])
	var base_reason = build_result.get("reason", "no_build")
	var executed_actions: Array = []
	if build_result.get("executed", false):
		var executed = [{
			"action": "build_castle",
			"region_id": build_result.get("region_id", -1),
			"details": build_details
		}]
		return {
			"executed": executed,
			"build_castle_details": build_details,
			"build_castle_reason": base_reason,
			"upgrade_castle_details": [],
			"upgrade_castle_reason": "not_evaluated",
			"upgrade_region_details": [],
			"upgrade_region_reason": "not_evaluated",
			"upgrade_region_actions": []
		}
	var result := {
		"executed": executed_actions,
		"reason": "no_region_actions",
		"build_castle_details": build_details,
		"build_castle_reason": base_reason,
		"upgrade_castle_details": [],
		"upgrade_castle_reason": "not_evaluated",
		"upgrade_region_details": [],
		"upgrade_region_reason": "not_evaluated",
		"upgrade_region_actions": []
	}
	var upgrade_castle = _evaluate_upgrade_castle(player_id, turn_number)
	result["upgrade_castle_reason"] = upgrade_castle.get("reason", "not_evaluated")
	result["upgrade_castle_details"] = upgrade_castle.get("details", [])
	if upgrade_castle.get("executed", false):
		result["executed"].append({
			"action": "upgrade_castle",
			"region_id": upgrade_castle.get("region_id", -1),
			"details": upgrade_castle.get("details", [])
		})
	var upgrade_region = _evaluate_upgrade_region(player_id, turn_number)
	result["upgrade_region_reason"] = upgrade_region.get("reason", "not_evaluated")
	result["upgrade_region_details"] = upgrade_region.get("details", [])
	result["upgrade_region_actions"] = upgrade_region.get("actions", [])
	if upgrade_region.get("executed", false):
		var region_entries: Array = upgrade_region.get("action_entries", [])
		for entry in region_entries:
			result["executed"].append(entry)
	return result

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
	var level_int = _region_level_to_int(region.get_region_level())
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

func _region_level_to_int(level: RegionLevelEnum.Level) -> int:
	match level:
		RegionLevelEnum.Level.L1:
			return 1
		RegionLevelEnum.Level.L2:
			return 2
		RegionLevelEnum.Level.L3:
			return 3
		RegionLevelEnum.Level.L4:
			return 4
		RegionLevelEnum.Level.L5:
			return 5
		_:
			return 1

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
	var upgrades: Array[String] = []
	var action_entries: Array = []
	var reason = "no_candidate"
	var last_details: Array = []
	var safety := 0
	while true:
		safety += 1
		if safety > 20:
			reason = "loop_guard"
			break
		var candidate_info = _pick_region_upgrade_candidates(player_id)
		var details: Array = candidate_info.get("details", [])
		last_details = details
		var best_region_id = int(candidate_info.get("best_region_id", -1))
		if best_region_id == -1 or details.is_empty():
			reason = "no_candidate"
			break
		var best_detail = details[0]
		var score = float(best_detail.get("score", 0.0))
		if score <= 0.0:
			reason = "low_score"
			break
		var next_level = int(best_detail.get("next_level", RegionLevelEnum.Level.L1))
		var cost: Dictionary = best_detail.get("cost", {})
		if cost.is_empty():
			reason = "no_cost_data"
			break
		var food_cost = int(cost.get(ResourcesEnum.Type.FOOD, 0))
		if not player_manager.meets_food_upgrade_safeguard(player_id, food_cost):
			reason = "food_safeguard"
			break
		if not player.can_afford_cost(cost):
			reason = "insufficient_resources"
			break
		if not player.pay_cost(cost):
			reason = "deduction_failed"
			break
		var region = region_manager.map_generator.get_region_container_by_id(best_region_id) as Region
		if region == null:
			reason = "region_missing"
			break
		region.set_region_level(next_level)
		region_manager.generate_region_resources(region)
		var level_name = RegionLevelEnum.level_to_string(next_level)
		var msg = "Upgrading %s to %s (score: %.1f)" % [region.get_region_name(), level_name, score]
		upgrades.append(msg)
		action_entries.append({
			"action": "upgrade_region",
			"region_id": best_region_id,
			"details": best_detail
		})
		reason = "upgrades_completed"
		# Continue loop to see if we can afford another upgrade
		continue
	return {
		"executed": upgrades.size() > 0,
		"reason": reason,
		"details": _limit_candidate_details(last_details),
		"actions": upgrades,
		"action_entries": action_entries
	}
