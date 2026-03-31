extends RefCounted
class_name RecruitmentManager

var region_manager: RegionManager
var game_manager: GameManager

const BASE_ORDER: Array = [
	SoldierTypeEnum.Type.PEASANTS,
	SoldierTypeEnum.Type.SPEARMEN,
	SoldierTypeEnum.Type.SWORDSMEN,
	SoldierTypeEnum.Type.HORSEMEN,
	SoldierTypeEnum.Type.KNIGHTS,
	SoldierTypeEnum.Type.MOUNTED_KNIGHTS,
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
	var result := _compute_plan(budget, recruits_available, tier_cap, false)
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
	var result := _compute_plan(budget, recruits_available, tier_cap, true)
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

func _compute_plan(budget: BudgetComposition, recruits: int, tier_cap: int, disable_cavalry: bool) -> Dictionary:
	var gold: int = max(0, budget.gold)
	var wood: int = max(0, budget.wood)
	var iron: int = max(0, budget.iron)
	var recruits_left: int = max(0, recruits)
	var weights := _build_weights(gold, recruits_left, tier_cap, disable_cavalry)
	if _sum_floats(weights) <= 0.0 or recruits_left <= 0 or gold <= 0:
		return {
			"hired": {},
			"spent_gold": 0,
			"spent_wood": 0,
			"spent_iron": 0,
			"total_recruited": 0,
			"left": {"gold": gold, "wood": wood, "iron": iron}
		}
	var purchase := _purchase_units(weights, gold, wood, iron, recruits_left)
	budget.gold = purchase.left_gold
	budget.wood = purchase.left_wood
	budget.iron = purchase.left_iron
	return {
		"hired": purchase.counts,
		"spent_gold": purchase.spent_gold,
		"spent_wood": purchase.spent_wood,
		"spent_iron": purchase.spent_iron,
		"total_recruited": purchase.total_recruited,
		"left": {
			"gold": purchase.left_gold,
			"wood": purchase.left_wood,
			"iron": purchase.left_iron
		}
	}

func _build_weights(gold: int, recruits: int, tier_cap: int, disable_cavalry: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var shift: float = _compute_shift(gold, recruits)
	var weights: Dictionary = {}
	for idx in range(BASE_ORDER.size()):
		var t = BASE_ORDER[idx]
		var w = _gauss(float(idx), shift)
		if disable_cavalry and (t == SoldierTypeEnum.Type.HORSEMEN or t == SoldierTypeEnum.Type.MOUNTED_KNIGHTS):
			w = 0.0
		if GameParameters.UNIT_TIERS.get(t, 99) > tier_cap:
			w = 0.0
		weights[t] = w
	var total_base: float = _sum_floats(weights)
	var ranged_pool: float = 0.0
	if total_base > 0.0:
		var roll: float = rng.randf_range(GameParameters.RECRUIT_RANGED_SHARE_MIN, GameParameters.RECRUIT_RANGED_SHARE_MAX)
		ranged_pool = total_base * roll
	var arch_mass: float = weights.get(SoldierTypeEnum.Type.PEASANTS, 0.0) + weights.get(SoldierTypeEnum.Type.SPEARMEN, 0.0) + weights.get(SoldierTypeEnum.Type.SWORDSMEN, 0.0)
	var cross_mass: float = weights.get(SoldierTypeEnum.Type.HORSEMEN, 0.0) + weights.get(SoldierTypeEnum.Type.KNIGHTS, 0.0) + weights.get(SoldierTypeEnum.Type.MOUNTED_KNIGHTS, 0.0)
	if disable_cavalry:
		cross_mass = 0.0
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
	return weights

func _purchase_units(weights: Dictionary, gold: int, wood: int, iron: int, recruits: int) -> Dictionary:
	var counts: Dictionary = {}
	for t in ORDER:
		counts[t] = 0
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
			var best_unit: SoldierTypeEnum.Type = _get_best_weighted_unit(effective, gold_left, wood_left, iron_left)
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
			var removed := _remove_one(loop_counts, func(u): return int(_unit_cost(u)["wood"]) > 0)
			if not removed:
				break
			wood_used = _resource_used(loop_counts, "wood")
		while iron_used > iron_left:
			var removed2 := _remove_one(loop_counts, func(u): return int(_unit_cost(u)["iron"]) > 0)
			if not removed2:
				break
			iron_used = _resource_used(loop_counts, "iron")
		loop_total = _sum_dict(loop_counts)
		if loop_total <= 0:
			break
		var gold_spent: int = 0
		for t in ORDER:
			gold_spent += loop_counts[t] * int(_unit_cost(t)["gold"])
		if gold_spent <= 0 or gold_spent > gold_left:
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

func _get_best_weighted_unit(effective: Dictionary, gold: int, wood: int, iron: int):
	var best = null
	var best_w: float = -1.0
	for t in ORDER:
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
