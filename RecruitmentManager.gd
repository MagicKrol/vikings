extends RefCounted
class_name RecruitmentManager

var region_manager: RegionManager
var game_manager: GameManager

const BASE_ORDER: Array = [
	SoldierTypeEnum.Type.PEASANTS,
	SoldierTypeEnum.Type.SPEARMEN,
	SoldierTypeEnum.Type.SWORDSMEN,
	SoldierTypeEnum.Type.KNIGHTS,
	SoldierTypeEnum.Type.ROYAL_GUARD
]

const ORDER: Array = [
	SoldierTypeEnum.Type.PEASANTS,
	SoldierTypeEnum.Type.SPEARMEN,
	SoldierTypeEnum.Type.SWORDSMEN,
	SoldierTypeEnum.Type.ARCHERS,
	SoldierTypeEnum.Type.CROSSBOWMEN,
	SoldierTypeEnum.Type.HORSEMEN,
	SoldierTypeEnum.Type.KNIGHTS,
	SoldierTypeEnum.Type.MOUNTED_KNIGHTS,
	SoldierTypeEnum.Type.ROYAL_GUARD
]

const RANGED_UNITS: Array = [
	SoldierTypeEnum.Type.ARCHERS,
	SoldierTypeEnum.Type.CROSSBOWMEN
]

var _grassland_global_percent_cache: int = -1

func _init(region_mgr: RegionManager = null, game_mgr: GameManager = null) -> void:
	region_manager = region_mgr
	game_manager = game_mgr

func hire_soldiers(army: Army, debug: bool = false) -> Dictionary:
	var budget: BudgetComposition = army.assigned_budget
	var region: Region = army.get_parent()
	var player_id: int = army.get_player_id()
	var recruit_sources: Array = _gather_recruit_sources(region, player_id)
	var recruits_available: int = _cap_recruits_with_budget(_sum_sources(recruit_sources), budget)
	var castle_type := region.get_castle_type()
	var tier_cap: int = GameParameters.CASTLE_RECRUITMENT_TIERS.get(castle_type, 1)
	var result := _compute_plan(budget, recruits_available, tier_cap, false, player_id)
	_apply_hires_to_composition(army.get_composition(), result.get("hired", {}))
	game_manager.record_hired_units(player_id, result.get("hired", {}))
	_deduct_recruits_proportionally(int(result.get("total_recruited", 0)), recruit_sources)
	_deduct_player_resources(player_id, int(result.get("spent_gold", 0)), int(result.get("spent_wood", 0)), int(result.get("spent_iron", 0)))
	army.clear_recruitment_request()
	result["recruits_left"] = _count_recruits_remaining(recruit_sources)
	result["budget_left"] = budget.to_dict()
	if debug:
		_log_recruitment("Army %s recruited %d (g:%d w:%d i:%d) at %s" % [
			army.get_display_name(),
			int(result.get("total_recruited", 0)),
			int(result.get("spent_gold", 0)),
			int(result.get("spent_wood", 0)),
			int(result.get("spent_iron", 0)),
			region.get_region_name()
		])
	return result

func hire_garrison(region: Region, budget: BudgetComposition, player_id: int, debug: bool = false) -> Dictionary:
	var recruit_sources: Array = _gather_recruit_sources(region, player_id)
	var recruits_available: int = _cap_recruits_with_budget(_sum_sources(recruit_sources), budget)
	var castle_type := region.get_castle_type()
	var tier_cap: int = GameParameters.CASTLE_RECRUITMENT_TIERS.get(castle_type, 1)
	# Garrison never hires cavalry per request.
	var result := _compute_plan(budget, recruits_available, tier_cap, true, player_id)
	_apply_hires_to_composition(region.get_garrison(), result.get("hired", {}))
	game_manager.record_hired_units(player_id, result.get("hired", {}))
	_deduct_recruits_proportionally(int(result.get("total_recruited", 0)), recruit_sources)
	_deduct_player_resources(player_id, int(result.get("spent_gold", 0)), int(result.get("spent_wood", 0)), int(result.get("spent_iron", 0)))
	result["recruits_left"] = _count_recruits_remaining(recruit_sources)
	result["budget_left"] = budget.to_dict()
	if debug:
		_log_recruitment("Garrison recruited %d (g:%d w:%d i:%d) at %s" % [
			int(result.get("total_recruited", 0)),
			int(result.get("spent_gold", 0)),
			int(result.get("spent_wood", 0)),
			int(result.get("spent_iron", 0)),
			region.get_region_name()
		])
	return result

func _compute_plan(budget: BudgetComposition, recruits: int, tier_cap: int, disable_cavalry: bool, player_id: int) -> Dictionary:
	var gold: int = max(0, budget.gold)
	var wood: int = max(0, budget.wood)
	var iron: int = max(0, budget.iron)
	var recruits_left: int = max(0, recruits)
	var grassland_global: int = _get_grassland_global_percent()
	var grassland_frontier: int = _get_grassland_frontier_percent(player_id)
	var horsemen_share: float = _compute_horsemen_share(grassland_global, grassland_frontier)
	var weights: Dictionary = _build_weights(gold, recruits_left, tier_cap, disable_cavalry, horsemen_share)
	if _sum_floats(weights) <= 0.0 or recruits_left <= 0 or gold <= 0:
		return {
			"hired": {},
			"spent_gold": 0,
			"spent_wood": 0,
			"spent_iron": 0,
			"total_recruited": 0,
			"left": {"gold": gold, "wood": wood, "iron": iron},
			"horsemen_percentage": horsemen_share * 100.0,
			"ranged_assigned": 0,
			"ranged_percentage": 0.0
		}
	var best_plan: Dictionary = _choose_best_two_pass_plan(recruits_left, weights, gold, wood, iron)
	var merged_counts: Dictionary = best_plan.get("counts", {})
	var total_recruited: int = int(best_plan.get("total_recruited", 0))
	var ranged_assigned: int = int(best_plan.get("ranged_assigned", 0))
	var ranged_percentage: float = float(best_plan.get("share_ratio", 0.0)) * 100.0
	budget.gold = int(best_plan.get("left_gold", gold))
	budget.wood = int(best_plan.get("left_wood", wood))
	budget.iron = int(best_plan.get("left_iron", iron))
	return {
		"hired": merged_counts,
		"spent_gold": int(best_plan.get("spent_gold", 0)),
		"spent_wood": int(best_plan.get("spent_wood", 0)),
		"spent_iron": int(best_plan.get("spent_iron", 0)),
		"total_recruited": total_recruited,
		"left": {
			"gold": int(best_plan.get("left_gold", gold)),
			"wood": int(best_plan.get("left_wood", wood)),
			"iron": int(best_plan.get("left_iron", iron))
		},
		"horsemen_percentage": horsemen_share * 100.0,
		"ranged_assigned": ranged_assigned,
		"ranged_percentage": ranged_percentage
	}

func _build_weights(gold: int, recruits: int, tier_cap: int, disable_cavalry: bool, horsemen_share: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var shift: float = _compute_shift(gold, recruits)
	var weights: Dictionary = {}
	for idx in range(BASE_ORDER.size()):
		var t = BASE_ORDER[idx]
		var w = _gauss(float(idx), shift)
		weights[t] = w
	var swords_bucket: float = float(weights.get(SoldierTypeEnum.Type.SWORDSMEN, 0.0))
	var knights_bucket: float = float(weights.get(SoldierTypeEnum.Type.KNIGHTS, 0.0))
	weights[SoldierTypeEnum.Type.SWORDSMEN] = swords_bucket * (1.0 - horsemen_share)
	weights[SoldierTypeEnum.Type.HORSEMEN] = swords_bucket * horsemen_share
	weights[SoldierTypeEnum.Type.KNIGHTS] = knights_bucket * (1.0 - horsemen_share)
	weights[SoldierTypeEnum.Type.MOUNTED_KNIGHTS] = knights_bucket * horsemen_share
	if disable_cavalry:
		weights[SoldierTypeEnum.Type.HORSEMEN] = 0.0
		weights[SoldierTypeEnum.Type.MOUNTED_KNIGHTS] = 0.0
	var total_base: float = _sum_floats(weights)
	var ranged_pool: float = 0.0
	if total_base > 0.0:
		var roll: float = rng.randf_range(GameParameters.RECRUIT_RANGED_SHARE_MIN, GameParameters.RECRUIT_RANGED_SHARE_MAX)
		ranged_pool = total_base * roll
	var arch_mass: float = (
		float(weights.get(SoldierTypeEnum.Type.PEASANTS, 0.0)) +
		float(weights.get(SoldierTypeEnum.Type.SPEARMEN, 0.0)) +
		float(weights.get(SoldierTypeEnum.Type.SWORDSMEN, 0.0)) +
		float(weights.get(SoldierTypeEnum.Type.HORSEMEN, 0.0))
	)
	var cross_mass: float = (
		float(weights.get(SoldierTypeEnum.Type.KNIGHTS, 0.0)) +
		float(weights.get(SoldierTypeEnum.Type.MOUNTED_KNIGHTS, 0.0)) +
		float(weights.get(SoldierTypeEnum.Type.ROYAL_GUARD, 0.0))
	)
	var mass_total: float = arch_mass + cross_mass
	var archers_val: float = 0.0
	var cross_val: float = 0.0
	if mass_total > 0.0 and ranged_pool > 0.0:
		archers_val = ranged_pool * (arch_mass / mass_total)
		cross_val = ranged_pool * (cross_mass / mass_total)
	weights[SoldierTypeEnum.Type.ARCHERS] = archers_val
	weights[SoldierTypeEnum.Type.CROSSBOWMEN] = cross_val
	# Drop units above tier cap
	for unit in ORDER:
		if GameParameters.UNIT_TIERS.get(unit, 99) > tier_cap:
			weights[unit] = 0.0
	if disable_cavalry:
		weights[SoldierTypeEnum.Type.HORSEMEN] = 0.0
		weights[SoldierTypeEnum.Type.MOUNTED_KNIGHTS] = 0.0
	return weights

func _purchase_units(weights: Dictionary, gold: int, wood: int, iron: int, recruits: int, allowed_units: Array = []) -> Dictionary:
	var counts: Dictionary = {}
	for t in ORDER:
		counts[t] = 0
	var active_order: Array = ORDER
	if not allowed_units.is_empty():
		active_order = allowed_units
	var active_lookup: Dictionary = {}
	for t in active_order:
		active_lookup[t] = true
	var gold_left: int = gold
	var wood_left: int = wood
	var iron_left: int = iron
	var recruits_left: int = recruits
	var last_rate: float = 0.0
	var guard: int = 0
	while gold_left > 0 and recruits_left > 0 and guard < 500:
		guard += 1
		var effective: Dictionary = {}
		var min_cost: int = -1
		for t in ORDER:
			var w: float = float(weights.get(t, 0.0))
			var cost = _unit_cost(t)
			if not active_lookup.has(t):
				w = 0.0
			if wood_left <= 0 and int(cost["wood"]) > 0:
				w = 0.0
			if iron_left <= 0 and int(cost["iron"]) > 0:
				w = 0.0
			effective[t] = w
			if w > 0.0:
				if min_cost == -1 or int(cost["gold"]) < min_cost:
					min_cost = int(cost["gold"])
		if min_cost == -1 or gold_left < min_cost:
			break
		var weighted_sum: float = 0.0
		for t in ORDER:
			weighted_sum += float(effective.get(t, 0.0)) * float(_unit_cost(t)["gold"])
		if weighted_sum <= 0.0:
			break
		var rate: float = float(gold_left) / weighted_sum
		last_rate = rate
		var loop_counts: Dictionary = {}
		var loop_total: int = 0
		for t in ORDER:
			var c: int = int(floor(float(effective[t]) * rate))
			loop_counts[t] = c
			loop_total += c
		if loop_total == 0:
			var best_unit: SoldierTypeEnum.Type = _get_best_weighted_unit(effective, gold_left, wood_left, iron_left, active_order)
			if best_unit != null:
				loop_counts[best_unit] = 1
				loop_total = 1
			else:
				break
		if loop_total > recruits_left:
			var scale: float = float(recruits_left) / float(loop_total)
			loop_total = 0
			for t in ORDER:
				loop_counts[t] = int(floor(float(loop_counts[t]) * scale))
				loop_total += loop_counts[t]
		var wood_used: int = 0
		var iron_used: int = 0
		for t in ORDER:
			wood_used += loop_counts[t] * int(_unit_cost(t)["wood"])
			iron_used += loop_counts[t] * int(_unit_cost(t)["iron"])
		while wood_used > wood_left:
			var removed: bool = _remove_one(loop_counts, func(u): return int(_unit_cost(u)["wood"]) > 0)
			if not removed:
				break
			wood_used = _resource_used(loop_counts, "wood")
		while iron_used > iron_left:
			var removed2: bool = _remove_one_reverse(loop_counts, func(u): return int(_unit_cost(u)["iron"]) > 0)
			if not removed2:
				break
			iron_used = _resource_used(loop_counts, "iron")
		loop_total = _sum_dict(loop_counts)
		if loop_total <= 0:
			var best_unit_2: SoldierTypeEnum.Type = _get_best_weighted_unit(effective, gold_left, wood_left, iron_left, active_order)
			if best_unit_2 != null:
				loop_counts[best_unit_2] = 1
				loop_total = 1
				wood_used = _resource_used(loop_counts, "wood")
				iron_used = _resource_used(loop_counts, "iron")
			else:
				break
		var gold_spent: int = 0
		for t in ORDER:
			gold_spent += loop_counts[t] * int(_unit_cost(t)["gold"])
		loop_total = _sum_dict(loop_counts)
		if loop_total <= 0:
			break
		gold_left -= gold_spent
		wood_left -= wood_used
		iron_left -= iron_used
		recruits_left -= loop_total
		for t in ORDER:
			counts[t] += loop_counts[t]
	return {
		"counts": counts,
		"spent_gold": gold - gold_left,
		"spent_wood": wood - wood_left,
		"spent_iron": iron - iron_left,
		"left_gold": gold_left,
		"left_wood": wood_left,
		"left_iron": iron_left,
		"total_recruited": recruits - recruits_left,
		"rate": last_rate
	}

func _get_best_weighted_unit(effective: Dictionary, gold: int, wood: int, iron: int, candidate_order: Array):
	var best = null
	var best_w: float = -1.0
	for t in candidate_order:
		var w: float = float(effective.get(t, 0.0))
		if w <= 0.0:
			continue
		var cost = _unit_cost(t)
		if int(cost["gold"]) > gold or int(cost["wood"]) > wood or int(cost["iron"]) > iron:
			continue
		if w > best_w:
			best_w = w
			best = t
	return best

func _remove_one(loop_counts: Dictionary, predicate: Callable) -> bool:
	for t in ORDER:
		if loop_counts.get(t, 0) > 0 and predicate.call(t):
			loop_counts[t] -= 1
			return true
	return false

func _remove_one_reverse(loop_counts: Dictionary, predicate: Callable) -> bool:
	for i in range(ORDER.size() - 1, -1, -1):
		var t = ORDER[i]
		if loop_counts.get(t, 0) > 0 and predicate.call(t):
			loop_counts[t] -= 1
			return true
	return false

func _resource_used(loop_counts: Dictionary, key: String) -> int:
	var total: int = 0
	for t in ORDER:
		total += loop_counts[t] * int(_unit_cost(t)[key])
	return total

func _cap_recruits_with_budget(avail: int, budget: BudgetComposition) -> int:
	if budget.available_recruits > 0:
		return min(avail, budget.available_recruits)
	return avail

func _apply_hires_to_composition(comp: ArmyComposition, hired: Dictionary) -> void:
	for t in hired.keys():
		var n: int = int(hired[t])
		if n > 0:
			comp.add_soldiers(t, n)

func _gather_recruit_sources(region: Region, player_id: int) -> Array:
	var sources: Array = region_manager.get_available_recruits_from_region_and_neighbors(region.get_region_id(), player_id)
	return sources

func _sum_sources(recruit_sources: Array) -> int:
	var total: int = 0
	for source in recruit_sources:
		total += int(source.amount)
	return total

func _count_recruits_remaining(recruit_sources: Array) -> int:
	var left: int = 0
	for source in recruit_sources:
		var source_region: Region = region_manager.map_generator.get_region_container_by_id(source.region_id)
		left += source_region.get_available_recruits()
	return left

func _deduct_recruits_proportionally(total_to_deduct: int, recruit_sources: Array) -> void:
	if recruit_sources.is_empty() or total_to_deduct <= 0:
		return
	var total_available: int = 0
	for s in recruit_sources:
		total_available += int(s.amount)
	if total_available <= 0:
		return
	var remaining: int = total_to_deduct
	for i in range(recruit_sources.size()):
		var src = recruit_sources[i]
		var reg: Region = region_manager.map_generator.get_region_container_by_id(src.region_id)
		var to_deduct: int = 0
		if i == recruit_sources.size() - 1:
			to_deduct = remaining
		else:
			var proportion: float = float(src.amount) / float(total_available)
			to_deduct = int(proportion * float(total_to_deduct))
		if to_deduct > 0:
			var actual: int = reg.hire_recruits(to_deduct)
			remaining -= actual

func _deduct_player_resources(player_id: int, gold: int, wood: int, iron: int) -> void:
	if gold <= 0 and wood <= 0 and iron <= 0:
		return
	var pm: PlayerManagerNode = game_manager.get_player_manager()
	if gold > 0:
		pm.remove_resources_from_player(player_id, ResourcesEnum.Type.GOLD, gold)
	if wood > 0:
		pm.remove_resources_from_player(player_id, ResourcesEnum.Type.WOOD, wood)
	if iron > 0:
		pm.remove_resources_from_player(player_id, ResourcesEnum.Type.IRON, iron)

func _gauss(x: float, mu: float) -> float:
	if x >= GameParameters.RECRUIT_GAUSS_CUTOFF_X:
		return 0.0
	var exponent: float = -pow((x - mu), 2.0) / (2.0 * pow(GameParameters.RECRUIT_GAUSS_SIGMA, 2.0))
	return GameParameters.RECRUIT_GAUSS_AMPLITUDE * exp(exponent)

func _compute_shift(gold: int, recruits: int) -> float:
	if recruits <= 0:
		return GameParameters.RECRUIT_GAUSS_MAX_SHIFT
	var ratio: float = float(gold) / float(recruits)
	if ratio <= GameParameters.RECRUIT_GAUSS_RATIO_MIN:
		return 0.0
	if ratio >= GameParameters.RECRUIT_GAUSS_RATIO_MAX:
		return GameParameters.RECRUIT_GAUSS_MAX_SHIFT
	var span: float = GameParameters.RECRUIT_GAUSS_RATIO_MAX - GameParameters.RECRUIT_GAUSS_RATIO_MIN
	return ((ratio - GameParameters.RECRUIT_GAUSS_RATIO_MIN) / span) * GameParameters.RECRUIT_GAUSS_MAX_SHIFT

func _compute_horsemen_share(grassland_global: int, grassland_frontier: int) -> float:
	return (float(grassland_global) + float(grassland_frontier)) / 200.0

func _compute_ranged_target(recruits: int, weights: Dictionary, gold: int, wood: int) -> int:
	if recruits <= 0:
		return 0
	var ranged_weight: float = float(weights.get(SoldierTypeEnum.Type.ARCHERS, 0.0)) + float(weights.get(SoldierTypeEnum.Type.CROSSBOWMEN, 0.0))
	if ranged_weight <= 0.0:
		return 0
	var min_ranged: int = int(ceil(float(recruits) * GameParameters.RECRUIT_RANGED_SHARE_MIN))
	var max_ranged: int = int(floor(float(recruits) * GameParameters.RECRUIT_RANGED_SHARE_MAX))
	if max_ranged < min_ranged:
		max_ranged = min_ranged
	var total_weight: float = _sum_floats(weights)
	var target: int = min_ranged
	if total_weight > 0.0:
		target = int(round((ranged_weight / total_weight) * float(recruits)))
	target = clampi(target, min_ranged, max_ranged)
	var max_gold_ranged: int = int(gold / 3)
	var max_wood_ranged: int = wood
	var max_possible: int = mini(recruits, mini(max_gold_ranged, max_wood_ranged))
	return clampi(target, 0, max_possible)

func _ranged_share_ratio(ranged_assigned: int, total_recruited: int) -> float:
	if total_recruited <= 0:
		return 0.0
	return float(ranged_assigned) / float(total_recruited)

func _ranged_band_distance(share_ratio: float) -> float:
	if share_ratio < GameParameters.RECRUIT_RANGED_SHARE_MIN:
		return GameParameters.RECRUIT_RANGED_SHARE_MIN - share_ratio
	if share_ratio > GameParameters.RECRUIT_RANGED_SHARE_MAX:
		return share_ratio - GameParameters.RECRUIT_RANGED_SHARE_MAX
	return 0.0

func _simulate_two_pass_plan(total_recruits: int, weights: Dictionary, gold: int, wood: int, iron: int, ranged_target: int) -> Dictionary:
	var ranged_purchase: Dictionary = _purchase_units(weights, gold, wood, iron, ranged_target, RANGED_UNITS)
	var melee_weights: Dictionary = weights.duplicate()
	melee_weights[SoldierTypeEnum.Type.ARCHERS] = 0.0
	melee_weights[SoldierTypeEnum.Type.CROSSBOWMEN] = 0.0
	var remaining_recruits: int = max(0, total_recruits - int(ranged_purchase.get("total_recruited", 0)))
	var melee_purchase: Dictionary = _purchase_units(
		melee_weights,
		int(ranged_purchase.get("left_gold", 0)),
		int(ranged_purchase.get("left_wood", 0)),
		int(ranged_purchase.get("left_iron", 0)),
		remaining_recruits
	)
	var merged_counts: Dictionary = _merge_counts(
		ranged_purchase.get("counts", {}),
		melee_purchase.get("counts", {})
	)
	var total_recruited: int = int(ranged_purchase.get("total_recruited", 0)) + int(melee_purchase.get("total_recruited", 0))
	var ranged_assigned: int = int(merged_counts.get(SoldierTypeEnum.Type.ARCHERS, 0)) + int(merged_counts.get(SoldierTypeEnum.Type.CROSSBOWMEN, 0))
	var share_ratio: float = _ranged_share_ratio(ranged_assigned, total_recruited)
	var midpoint: float = (GameParameters.RECRUIT_RANGED_SHARE_MIN + GameParameters.RECRUIT_RANGED_SHARE_MAX) * 0.5
	var rate: float = float(ranged_purchase.get("rate", 0.0))
	if remaining_recruits > 0:
		rate = float(melee_purchase.get("rate", 0.0))
	return {
		"ranged_target": ranged_target,
		"counts": merged_counts,
		"spent_gold": int(ranged_purchase.get("spent_gold", 0)) + int(melee_purchase.get("spent_gold", 0)),
		"spent_wood": int(ranged_purchase.get("spent_wood", 0)) + int(melee_purchase.get("spent_wood", 0)),
		"spent_iron": int(ranged_purchase.get("spent_iron", 0)) + int(melee_purchase.get("spent_iron", 0)),
		"left_gold": int(melee_purchase.get("left_gold", 0)),
		"left_wood": int(melee_purchase.get("left_wood", 0)),
		"left_iron": int(melee_purchase.get("left_iron", 0)),
		"rate": rate,
		"total_recruited": total_recruited,
		"ranged_assigned": ranged_assigned,
		"share_ratio": share_ratio,
		"in_band": share_ratio >= GameParameters.RECRUIT_RANGED_SHARE_MIN and share_ratio <= GameParameters.RECRUIT_RANGED_SHARE_MAX,
		"band_distance": _ranged_band_distance(share_ratio),
		"midpoint_distance": abs(share_ratio - midpoint)
	}

func _is_better_plan_candidate(candidate: Dictionary, current_best: Dictionary) -> bool:
	var candidate_in_band: bool = bool(candidate.get("in_band", false))
	var current_in_band: bool = bool(current_best.get("in_band", false))
	if candidate_in_band != current_in_band:
		return candidate_in_band
	if candidate_in_band:
		var candidate_total: int = int(candidate.get("total_recruited", 0))
		var current_total: int = int(current_best.get("total_recruited", 0))
		if candidate_total != current_total:
			return candidate_total > current_total
		var candidate_midpoint_distance: float = float(candidate.get("midpoint_distance", 0.0))
		var current_midpoint_distance: float = float(current_best.get("midpoint_distance", 0.0))
		if candidate_midpoint_distance != current_midpoint_distance:
			return candidate_midpoint_distance < current_midpoint_distance
		return int(candidate.get("ranged_target", 0)) < int(current_best.get("ranged_target", 0))
	var candidate_band_distance: float = float(candidate.get("band_distance", 0.0))
	var current_band_distance: float = float(current_best.get("band_distance", 0.0))
	if candidate_band_distance != current_band_distance:
		return candidate_band_distance < current_band_distance
	var candidate_total2: int = int(candidate.get("total_recruited", 0))
	var current_total2: int = int(current_best.get("total_recruited", 0))
	if candidate_total2 != current_total2:
		return candidate_total2 > current_total2
	var candidate_midpoint_distance2: float = float(candidate.get("midpoint_distance", 0.0))
	var current_midpoint_distance2: float = float(current_best.get("midpoint_distance", 0.0))
	if candidate_midpoint_distance2 != current_midpoint_distance2:
		return candidate_midpoint_distance2 < current_midpoint_distance2
	return int(candidate.get("ranged_target", 0)) < int(current_best.get("ranged_target", 0))

func _choose_best_two_pass_plan(total_recruits: int, weights: Dictionary, gold: int, wood: int, iron: int) -> Dictionary:
	var ranged_weight: float = float(weights.get(SoldierTypeEnum.Type.ARCHERS, 0.0)) + float(weights.get(SoldierTypeEnum.Type.CROSSBOWMEN, 0.0))
	var max_gold_ranged: int = int(gold / 3)
	var max_wood_ranged: int = wood
	var max_possible: int = maxi(0, mini(total_recruits, mini(max_gold_ranged, max_wood_ranged)))
	if total_recruits <= 0 or max_possible <= 0 or ranged_weight <= 0.0:
		return _simulate_two_pass_plan(total_recruits, weights, gold, wood, iron, 0)
	var initial_target: int = _compute_ranged_target(total_recruits, weights, gold, wood)
	var targets: Array[int] = []
	for ranged_target in range(max_possible + 1):
		targets.append(ranged_target)
	if targets.has(initial_target):
		targets.erase(initial_target)
	targets.insert(0, initial_target)
	var best: Dictionary = {}
	var has_best: bool = false
	for ranged_target in targets:
		var candidate: Dictionary = _simulate_two_pass_plan(total_recruits, weights, gold, wood, iron, ranged_target)
		if not has_best or _is_better_plan_candidate(candidate, best):
			best = candidate
			has_best = true
	if not has_best:
		return _simulate_two_pass_plan(total_recruits, weights, gold, wood, iron, 0)
	return best

func _merge_counts(first: Dictionary, second: Dictionary) -> Dictionary:
	var merged: Dictionary = {}
	for t in ORDER:
		merged[t] = int(first.get(t, 0)) + int(second.get(t, 0))
	return merged

func _get_grassland_global_percent() -> int:
	if _grassland_global_percent_cache >= 0:
		return _grassland_global_percent_cache
	var total_regions: int = 0
	var grassland_regions: int = 0
	for region_id_variant in region_manager.map_generator.region_container_by_id.keys():
		var region_id: int = int(region_id_variant)
		var region: Region = region_manager.map_generator.get_region_container_by_id(region_id)
		if region.is_ocean_region():
			continue
		total_regions += 1
		if region.get_region_type() == RegionTypeEnum.Type.GRASSLAND:
			grassland_regions += 1
	if total_regions <= 0:
		_grassland_global_percent_cache = 0
	else:
		_grassland_global_percent_cache = int(round((float(grassland_regions) / float(total_regions)) * 100.0))
	return _grassland_global_percent_cache

func _get_grassland_frontier_percent(player_id: int) -> int:
	var frontier_regions: Array[int] = region_manager.get_frontier_regions(player_id)
	if frontier_regions.is_empty():
		return 0
	var grassland_regions: int = 0
	for region_id in frontier_regions:
		var region: Region = region_manager.map_generator.get_region_container_by_id(region_id)
		if region.get_region_type() == RegionTypeEnum.Type.GRASSLAND:
			grassland_regions += 1
	return int(round((float(grassland_regions) / float(frontier_regions.size())) * 100.0))

func _unit_cost(t: SoldierTypeEnum.Type) -> Dictionary:
	return {
		"gold": GameParameters.get_unit_recruit_cost(t),
		"wood": GameParameters.get_unit_wood_cost(t),
		"iron": GameParameters.get_unit_iron_cost(t)
	}

func _sum_dict(d: Dictionary) -> int:
	var total: int = 0
	for k in d.keys():
		total += int(d[k])
	return total

func _sum_floats(d: Dictionary) -> float:
	var total: float = 0.0
	for k in d.keys():
		total += float(d[k])
	return total

func _log_recruitment(msg: String) -> void:
	if game_manager and game_manager.get_ai_log_manager():
		game_manager.get_ai_log_manager().log_recruitment(msg)
