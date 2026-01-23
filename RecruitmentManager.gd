extends RefCounted
class_name RecruitmentManager

var region_manager: RegionManager
var game_manager: GameManager

const UNIT_ORDER: Array = [
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

const RANGED_TYPES: Array = [
	SoldierTypeEnum.Type.ARCHERS,
	SoldierTypeEnum.Type.CROSSBOWMEN
]

const CONVERSIONS: Array = [
	{"from": SoldierTypeEnum.Type.PEASANTS, "to": SoldierTypeEnum.Type.SPEARMEN},
	{"from": SoldierTypeEnum.Type.SPEARMEN, "to": SoldierTypeEnum.Type.SWORDSMEN},
	{"from": SoldierTypeEnum.Type.PEASANTS, "to": SoldierTypeEnum.Type.ARCHERS},
	{"from": SoldierTypeEnum.Type.PEASANTS, "to": SoldierTypeEnum.Type.CROSSBOWMEN},
	{"from": SoldierTypeEnum.Type.PEASANTS, "to": SoldierTypeEnum.Type.HORSEMEN},
	{"from": SoldierTypeEnum.Type.SWORDSMEN, "to": SoldierTypeEnum.Type.KNIGHTS},
	{"from": SoldierTypeEnum.Type.HORSEMEN, "to": SoldierTypeEnum.Type.MOUNTED_KNIGHTS},
	{"from": SoldierTypeEnum.Type.KNIGHTS, "to": SoldierTypeEnum.Type.ROYAL_GUARD},
	{"from": SoldierTypeEnum.Type.ARCHERS, "to": SoldierTypeEnum.Type.CROSSBOWMEN}
]

const UPGRADES: Array = [
	{"from": SoldierTypeEnum.Type.PEASANTS, "to": SoldierTypeEnum.Type.SPEARMEN},
	{"from": SoldierTypeEnum.Type.SPEARMEN, "to": SoldierTypeEnum.Type.SWORDSMEN},
	{"from": SoldierTypeEnum.Type.SWORDSMEN, "to": SoldierTypeEnum.Type.KNIGHTS},
	{"from": SoldierTypeEnum.Type.KNIGHTS, "to": SoldierTypeEnum.Type.ROYAL_GUARD},
	{"from": SoldierTypeEnum.Type.HORSEMEN, "to": SoldierTypeEnum.Type.MOUNTED_KNIGHTS},
	{"from": SoldierTypeEnum.Type.ARCHERS, "to": SoldierTypeEnum.Type.CROSSBOWMEN}
]

func _init(region_mgr: RegionManager = null, game_mgr: GameManager = null) -> void:
	region_manager = region_mgr
	game_manager = game_mgr

func hire_soldiers(army: Army, debug: bool = false) -> Dictionary:
	var budget: BudgetComposition = army.assigned_budget
	var region: Region = army.get_parent()
	var player_id: int = army.get_player_id()
	var recruit_sources: Array = _gather_recruit_sources(region, player_id)
	var available: int = _sum_sources(recruit_sources)
	if budget.available_recruits > 0:
		available = min(available, budget.available_recruits)
	var castle_type := region.get_castle_type()
	var ideal_raw: Dictionary = GameParameters.get_ideal_composition(CastleTypeEnum.type_to_string(castle_type))
	DebugLogger.log("UnitRecruitment", "[hire_soldiers] army=" + str(army.get_display_name()) + " castle=" + str(castle_type) + " available=" + str(available) + " budget=" + str(budget.to_dict()) + " ideal_raw=" + str(ideal_raw))
	var result: Dictionary = _run_recruitment(ideal_raw, budget, available, {}, debug, castle_type)
	_apply_hires_to_composition(army.get_composition(), result.get("hired", {}), {})
	_deduct_recruits_proportionally(int(result.get("total_recruited", 0)), recruit_sources)
	_deduct_player_resources(player_id, int(result.get("spent_gold", 0)), int(result.get("spent_wood", 0)), int(result.get("spent_iron", 0)))
	army.clear_recruitment_request()
	result["recruits_left"] = _count_recruits_remaining(recruit_sources)
	result["budget_left"] = budget.to_dict()
	DebugLogger.log("UnitRecruitment", "[hire_soldiers] result hired=" + str(result.get("hired", {})) + " spent_g=" + str(result.get("spent_gold", 0)) + " spent_w=" + str(result.get("spent_wood", 0)) + " spent_i=" + str(result.get("spent_iron", 0)) + " total=" + str(result.get("total_recruited", 0)) + " recruits_left=" + str(result["recruits_left"]) + " budget_left=" + str(result["budget_left"]))
	return result

func hire_garrison(region: Region, budget: BudgetComposition, player_id: int, debug: bool = false) -> Dictionary:
	var recruit_sources: Array = _gather_recruit_sources(region, player_id)
	var available: int = _sum_sources(recruit_sources)
	if budget.available_recruits > 0:
		available = min(available, budget.available_recruits)
	var castle_type := region.get_castle_type()
	var ideal_raw: Dictionary = GameParameters.get_ideal_castle_garrison(castle_type)
	var special_caps: Dictionary = _compute_garrison_caps(region.get_garrison(), ideal_raw)
	var cap_total: int = _sum_dict_ints(special_caps)
	if cap_total > 0:
		available = min(available, cap_total)
	DebugLogger.log("UnitRecruitment", "[hire_garrison] region=" + str(region.get_region_name()) + " castle=" + str(castle_type) + " available=" + str(available) + " budget=" + str(budget.to_dict()) + " ideal_raw=" + str(ideal_raw) + " caps=" + str(special_caps))
	var result: Dictionary = _run_recruitment(ideal_raw, budget, available, special_caps, debug, castle_type)
	_apply_hires_to_composition(region.get_garrison(), result.get("hired", {}), special_caps)
	_deduct_recruits_proportionally(int(result.get("total_recruited", 0)), recruit_sources)
	_deduct_player_resources(player_id, int(result.get("spent_gold", 0)), int(result.get("spent_wood", 0)), int(result.get("spent_iron", 0)))
	result["recruits_left"] = _count_recruits_remaining(recruit_sources)
	result["budget_left"] = budget.to_dict()
	DebugLogger.log("UnitRecruitment", "[hire_garrison] result hired=" + str(result.get("hired", {})) + " spent_g=" + str(result.get("spent_gold", 0)) + " spent_w=" + str(result.get("spent_wood", 0)) + " spent_i=" + str(result.get("spent_iron", 0)) + " total=" + str(result.get("total_recruited", 0)) + " recruits_left=" + str(result["recruits_left"]) + " budget_left=" + str(result["budget_left"]))
	return result

func _run_recruitment(ideal_raw: Dictionary, budget: BudgetComposition, recruits_available: int, special_caps: Dictionary, debug: bool, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE) -> Dictionary:
	var mapped_ideal: Dictionary = _map_ideal_keys_to_types(ideal_raw, castle_type)
	var max_tier: int = GameParameters.CASTLE_RECRUITMENT_TIERS.get(castle_type, 1)
	DebugLogger.log(
		"UnitRecruitment",
		"[run][IN] castle=" + str(castle_type) +
		" max_tier=" + str(max_tier) +
		" recruits_avail=" + str(recruits_available) +
		" budget_g=" + str(budget.gold) +
		" budget_w=" + str(budget.wood) +
		" budget_i=" + str(budget.iron) +
		" caps=" + str(special_caps) +
		" caps_sum=" + str(_sum_dict_ints(special_caps))
	)
	var dropped_units: Dictionary = {}
	for k in ideal_raw.keys():
		var key_str: String = str(k).to_lower()
		var mapped_type = null
		match key_str:
			"peasants":
				mapped_type = SoldierTypeEnum.Type.PEASANTS
			"spearmen":
				mapped_type = SoldierTypeEnum.Type.SPEARMEN
			"archers":
				mapped_type = SoldierTypeEnum.Type.ARCHERS
			"swordsman", "swordsmen":
				mapped_type = SoldierTypeEnum.Type.SWORDSMEN
			"crossbowmen":
				mapped_type = SoldierTypeEnum.Type.CROSSBOWMEN
			"horsemen":
				mapped_type = SoldierTypeEnum.Type.HORSEMEN
			"knights":
				mapped_type = SoldierTypeEnum.Type.KNIGHTS
			"mounted_knights":
				mapped_type = SoldierTypeEnum.Type.MOUNTED_KNIGHTS
			"royal_guard":
				mapped_type = SoldierTypeEnum.Type.ROYAL_GUARD
			_:
				mapped_type = null
		if mapped_type != null and not mapped_ideal.has(mapped_type):
			var tier: int = int(GameParameters.UNIT_TIERS.get(mapped_type, 99))
			if tier > max_tier:
				dropped_units[mapped_type] = tier
	DebugLogger.log("UnitRecruitment", "[run] castle=" + str(castle_type) + " max_tier=" + str(max_tier) + " recruits_avail=" + str(recruits_available) + " mapped_ideal=" + str(mapped_ideal) + " caps=" + str(special_caps) + " dropped_due_to_tier=" + str(dropped_units))
	if mapped_ideal.is_empty() or recruits_available <= 0:
		return {"hired": {}, "spent_gold": 0, "spent_wood": 0, "spent_iron": 0, "total_recruited": 0, "budget_left": budget.to_dict()}
	var pea_cap_share: float = GameParameters.RECRUIT_PEA_CAP_SHARE
	var rmin_share: float = GameParameters.RECRUIT_RANGED_MIN_SHARE
	var rmax_share: float = GameParameters.RECRUIT_RANGED_MAX_SHARE
	var spend_target_pct: float = GameParameters.RECRUIT_SPEND_TARGET_PCT
	var start_gold: int = budget.gold
	var start_wood: int = budget.wood
	var start_iron: int = budget.iron
	var total_cap: int = recruits_available
	if not special_caps.is_empty():
		total_cap = min(recruits_available, _sum_dict_ints(special_caps))
	var T: int = _decide_T_auto(
		total_cap,
		budget.gold,
		budget.wood,
		budget.iron,
		pea_cap_share,
		rmin_share,
		rmax_share,
		mapped_ideal,
		spend_target_pct,
		special_caps,
		max_tier
	)
	DebugLogger.log("UnitRecruitment", "[run] decided T=" + str(T) + " gold=" + str(budget.gold) + " wood=" + str(budget.wood) + " iron=" + str(budget.iron) + " range_bounds=" + str(_compute_ranged_bounds(T, rmin_share, rmax_share, budget.wood)) + " diversity_req=" + str(_compute_diversity_requirements(mapped_ideal, T)))

	if T <= 0:
		return {"hired": {}, "spent_gold": 0, "spent_wood": 0, "spent_iron": 0, "total_recruited": 0, "budget_left": budget.to_dict(), "notes": ["No feasible recruitment size."]}
	var build := _build_counts_for_T(
		T,
		start_gold,
		start_wood,
		start_iron,
		pea_cap_share,
		rmin_share,
		rmax_share,
		mapped_ideal,
		special_caps,
		max_tier
	)
	var counts: Dictionary = build.counts
	DebugLogger.log(
		"UnitRecruitment",
		"[run][T] decided T=" + str(T) +
		" rmin=" + str(build.rmin) +
		" rmax=" + str(build.rmax) +
		" diversity_req=" + str(build.diversity_req)
	)
	var g_left: int = build.g_left
	var w_left: int = build.w_left
	var i_left: int = build.i_left
	var spent_gold: int = start_gold - g_left
	var spent_wood: int = start_wood - w_left
	var spent_iron: int = start_iron - i_left
	var hired: Dictionary = {}
	for t in counts.keys():
		var c: int = counts[t]
		if c > 0:
			hired[t] = c
	budget.gold = g_left
	budget.wood = w_left
	budget.iron = i_left
	if debug:
		DebugLogger.log("AIRecruitment", "Recruitment result T=%d hired=%s spent=(%d,%d,%d)" % [T, str(hired), spent_gold, spent_wood, spent_iron])
	DebugLogger.log("UnitRecruitment", "[run] hired=" + str(hired) + " spent_g=" + str(spent_gold) + " spent_w=" + str(spent_wood) + " spent_i=" + str(spent_iron) + " remaining_g=" + str(g_left) + " remaining_w=" + str(w_left) + " remaining_i=" + str(i_left) + " total_recruited=" + str(_sum_dict_ints(counts)))
	var total_hired_check := 0
	for k in hired.keys():
		total_hired_check += int(hired[k])

	DebugLogger.log(
		"UnitRecruitment",
		"[run][OUT] decided_T=" + str(T) +
		" total_recruited(result)=" + str(_sum_dict_ints(counts)) +
		" total_hired(sum)=" + str(total_hired_check) +
		" hired=" + str(hired) +
		" spent_g=" + str(spent_gold) +
		" spent_w=" + str(spent_wood) +
		" spent_i=" + str(spent_iron) +
		" remaining_g=" + str(g_left) +
		" remaining_w=" + str(w_left) +
		" remaining_i=" + str(i_left)
	)
	
	return {
		"hired": hired,
		"spent_gold": spent_gold,
		"spent_wood": spent_wood,
		"spent_iron": spent_iron,
		"total_recruited": _sum_dict_ints(counts),
		"notes": build.get("notes", [])
	}

func _gather_recruit_sources(region: Region, player_id: int) -> Array:
	var sources: Array = region_manager.get_available_recruits_from_region_and_neighbors(region.get_region_id(), player_id)
	var total: int = 0
	for s in sources:
		total += int(s.amount)
	DebugLogger.log("AIRecruitment", "[RecruitmentManager] Total recruits from %d regions: %d" % [sources.size(), total])
	return sources

func _sum_sources(recruit_sources: Array) -> int:
	var s: int = 0
	for source in recruit_sources:
		s += int(source.amount)
	return s

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

func _map_ideal_keys_to_types(raw: Dictionary, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE) -> Dictionary:
	var out: Dictionary = {}
	var max_tier: int = GameParameters.CASTLE_RECRUITMENT_TIERS.get(castle_type, 1)
	for k in raw.keys():
		var key: String = str(k).to_lower()
		var pct: float = float(raw[k])
		if pct <= 0.0:
			continue
		match key:
			"peasants":
				out[SoldierTypeEnum.Type.PEASANTS] = pct
			"spearmen":
				out[SoldierTypeEnum.Type.SPEARMEN] = pct
			"archers":
				out[SoldierTypeEnum.Type.ARCHERS] = pct
			"swordsman", "swordsmen":
				out[SoldierTypeEnum.Type.SWORDSMEN] = pct
			"crossbowmen":
				out[SoldierTypeEnum.Type.CROSSBOWMEN] = pct
			"horsemen":
				out[SoldierTypeEnum.Type.HORSEMEN] = pct
			"knights":
				out[SoldierTypeEnum.Type.KNIGHTS] = pct
			"mounted_knights":
				out[SoldierTypeEnum.Type.MOUNTED_KNIGHTS] = pct
			"royal_guard":
				out[SoldierTypeEnum.Type.ROYAL_GUARD] = pct
			_:
				pass
	# Enforce castle recruitment tier: drop any unit above max tier
	var filtered: Dictionary = {}
	for unit_type in out.keys():
		var unit_tier: int = GameParameters.UNIT_TIERS.get(unit_type, 99)
		if unit_tier <= max_tier:
			filtered[unit_type] = out[unit_type]
	return filtered

func _compute_diversity_requirements(ideal: Dictionary, T: int = -1) -> Dictionary:
	# Diversity floors should only apply when the recruited batch is large enough,
	# matching recruitment.py behavior.
	if T >= 0 and T < GameParameters.RECRUIT_DIVERSITY_MIN_T:
		return {}
	var req: Dictionary = {}
	for t in GameParameters.RECRUIT_DIVERSITY_REQUIREMENTS.keys():
		if float(ideal.get(t, 0.0)) > 0.0:
			req[t] = int(GameParameters.RECRUIT_DIVERSITY_REQUIREMENTS[t])
	return req

func _decide_T_auto(
	recruits_avail: int,
	gold_budget: int,
	wood_av: int,
	iron_av: int,
	pea_cap_share: float,
	rmin_share: float,
	rmax_share: float,
	mapped_ideal: Dictionary,
	spend_pct: float,
	special_caps: Dictionary,
	max_tier: int
	) -> int:
		# Match recruitment.py:
		# score = (spent_g, div_ok, -ideal_dist, T) lexicographically max.
		var gold_eff: int = int(floor(float(gold_budget) * spend_pct))
		if gold_eff <= 0 or recruits_avail <= 0:
			return 0

		var gpr: float = float(gold_eff) / max(1.0, float(recruits_avail))
		var qty_factor: float = max(0.0, 1.0 - gpr) # Encourage quantity when gold per recruit is low
		var qty_weight: float = 2.0

		var best_t: int = 0
		var best_spent: float = -1.0
		var best_div_ok: int = -1
		var best_dist: float = 1e18

		for T in range(1, recruits_avail + 1):
			var sim: Dictionary = _simulate_for_T(
			T,
			gold_eff, wood_av, iron_av,
			pea_cap_share,
			rmin_share, rmax_share,
			mapped_ideal,
			special_caps,
			max_tier
			)
			if not bool(sim.get("hard_ok", false)):
				continue

			var spent_g: int = int(sim["spent_g"])
			var spent_score: float = float(spent_g) + qty_weight * qty_factor * float(T)
			var div_ok: int = int(sim["div_ok"])
			var dist: float = float(sim["ideal_dist"])

			var better := false
			if spent_score > best_spent:
				better = true
			elif abs(spent_score - best_spent) <= 1e-6:
				if div_ok > best_div_ok:
					better = true
				elif div_ok == best_div_ok:
					if dist < best_dist - 1e-9:
						better = true
				elif abs(dist - best_dist) <= 1e-9 and T > best_t:
					better = true

			if better:
				best_spent = spent_score
				best_div_ok = div_ok
				best_dist = dist
				best_t = T

		return best_t

func _build_counts_for_T(
	T: int,
	gold_budget: int,
	wood_budget: int,
	iron_budget: int,
	pea_cap_share: float,
	rmin_share: float,
	rmax_share: float,
	mapped_ideal: Dictionary,
	special_caps: Dictionary,
	max_tier: int
) -> Dictionary:
	var low: float = GameParameters.RECRUIT_SCARCITY_LOW
	var high: float = GameParameters.RECRUIT_SCARCITY_HIGH

	var bias_res: Dictionary = _apply_scarcity_bias(
		mapped_ideal,
		GameParameters.RECRUIT_UNIT_BOOSTS,
		gold_budget,
		T,
		low,
		high,
		true
	)
	var biased_ideal: Dictionary = bias_res.get("ideal", mapped_ideal)
	var target_counts: Dictionary = _hamilton_round(biased_ideal, T)
	var base_target_counts: Dictionary = _hamilton_round(_renormalize_to_100(mapped_ideal), T)
	var diversity_req: Dictionary = _compute_diversity_requirements(biased_ideal, T)
	var bounds: Dictionary = _compute_ranged_bounds(T, rmin_share, rmax_share, wood_budget)
	var rmin: int = int(bounds["min"])
	var rmax: int = int(bounds["max"])
	var gpr_actual: float = float(gold_budget) / max(1.0, float(T))

	var counts: Dictionary = _construct_base_counts(T)
	var base_totals: Dictionary = _totals(counts)
	var g_left: int = gold_budget - int(base_totals["gold"])
	var w_left: int = wood_budget - int(base_totals["wood"])
	var i_left: int = iron_budget - int(base_totals["iron"])

	var cap_map: Dictionary = special_caps.duplicate()

	var step = _enforce_ranged_min(counts, g_left, w_left, i_left, rmin)
	counts = step.counts; g_left = step.g_left; w_left = step.w_left; i_left = step.i_left

	var cap_units: int = int(floor(pea_cap_share * float(T) + 1e-6))
	step = _enforce_peasants_cap(counts, g_left, w_left, i_left, cap_units, cap_map, max_tier)
	counts = step.counts; g_left = step.g_left; w_left = step.w_left; i_left = step.i_left

	step = _seed_diversity(counts, diversity_req, g_left, w_left, i_left, rmin, rmax, cap_map)
	counts = step.counts; g_left = step.g_left; w_left = step.w_left; i_left = step.i_left

	step = _move_toward_target(counts, target_counts, g_left, w_left, i_left, rmin, rmax, cap_map, max_tier)
	counts = step.counts; g_left = step.g_left; w_left = step.w_left; i_left = step.i_left

	step = _burn_budget(counts, g_left, w_left, i_left, rmin, rmax, cap_map, max_tier, target_counts, base_target_counts, gpr_actual)
	counts = step.counts; g_left = step.g_left; w_left = step.w_left; i_left = step.i_left

	counts = _trim_to_caps(counts, cap_map)

	var totals_after: Dictionary = _totals(counts)
	g_left = gold_budget - int(totals_after["gold"])
	w_left = wood_budget - int(totals_after["wood"])
	i_left = iron_budget - int(totals_after["iron"])

	return {
		"counts": counts,
		"g_left": g_left,
		"w_left": w_left,
		"i_left": i_left,
		"biased_ideal": biased_ideal,
		"base_target_counts": base_target_counts,
		"diversity_req": diversity_req,
		"rmin": rmin,
		"rmax": rmax,
		"gpr": gpr_actual,
		"notes": bias_res.get("notes", [])
	}

func _simulate_for_T(
	T: int,
	gold_budget: int,
	wood_av: int,
	iron_av: int,
	pea_cap_share: float,
	rmin_share: float,
	rmax_share: float,
	mapped_ideal: Dictionary,
	special_caps: Dictionary,
	max_tier: int
) -> Dictionary:
	# Equivalent to recruitment.py simulate_for_T

	var plan := _build_counts_for_T(
		T,
		gold_budget,
		wood_av,
		iron_av,
		pea_cap_share,
		rmin_share,
		rmax_share,
		mapped_ideal,
		special_caps,
		max_tier
	)
	var counts: Dictionary = plan.counts
	var g_left: int = plan.g_left
	var w_left: int = plan.w_left
	var i_left: int = plan.i_left
	var rmin: int = plan.rmin
	var rmax: int = plan.rmax
	var biased_ideal: Dictionary = plan.biased_ideal
	var base_target_counts: Dictionary = plan.base_target_counts
	var req: Dictionary = plan.diversity_req
	var cap_units: int = int(floor(pea_cap_share * float(T) + 1e-6))

	var spent_g: int = gold_budget - g_left
	var left_g: int = g_left
	var left_w: int = w_left
	var left_i: int = i_left

	var peasants_ok: bool = int(counts.get(SoldierTypeEnum.Type.PEASANTS, 0)) <= cap_units
	var ranged_final: int = _ranged_units(counts)
	var ranged_ok: bool = (rmin <= ranged_final and ranged_final <= rmax)
	var budgets_ok: bool = (left_g >= 0 and left_w >= 0 and left_i >= 0)

	var div_ok: int = 0
	var div_total: int = 0
	for t in req.keys():
		div_total += 1
		if int(counts.get(t, 0)) >= int(req[t]):
			div_ok += 1

	var dist: float = _ideal_l1_nonpeasants(counts, biased_ideal)
	if T == 25:
		var total_units := 0
		for k in counts.keys():
			total_units += int(counts[k])

		DebugLogger.log(
			"UnitRecruitment",
			"[sim][OUT] T=" + str(T) +
			" total_units=" + str(total_units) +
			" counts=" + str(counts) +
			" g_left=" + str(g_left) +
			" w_left=" + str(w_left) +
			" i_left=" + str(i_left)
		)

	return {
		"hard_ok": peasants_ok and ranged_ok and budgets_ok,
		"spent_g": spent_g,
		"div_ok": div_ok,
		"div_total": div_total,
		"ideal_dist": dist
	}

func _ideal_l1_nonpeasants(counts: Dictionary, ideal_100: Dictionary) -> float:
	var total_np: int = 0
	for t in UNIT_ORDER:
		if t == SoldierTypeEnum.Type.PEASANTS:
			continue
		total_np += int(counts.get(t, 0))

	if total_np <= 0:
		return 1e9

	var ideal_np_sum: float = 0.0
	for t in UNIT_ORDER:
		if t == SoldierTypeEnum.Type.PEASANTS:
			continue
		ideal_np_sum += float(ideal_100.get(t, 0.0))

	if ideal_np_sum <= 1e-9:
		return 1e9

	var dist: float = 0.0
	for t in UNIT_ORDER:
		if t == SoldierTypeEnum.Type.PEASANTS:
			continue
		var actual_share: float = float(counts.get(t, 0)) / float(total_np)
		var ideal_share: float = float(ideal_100.get(t, 0.0)) / ideal_np_sum
		dist += abs(actual_share - ideal_share)

	return dist


func _min_cost_feasible_for_T(
	T: int,
	gold_budget: int,
	wood_av: int,
	pea_cap_share: float,
	rmin_share: float,
	ideal: Dictionary,
	diversity_req: Dictionary
) -> Dictionary:
	var rmin: int = int(ceil(float(T) * rmin_share))
	rmin = min(rmin, T)

	var nonpea_req: int = int(ceil((1.0 - pea_cap_share) * float(T) - 1e-9))
	nonpea_req = clampi(nonpea_req, 0, T)

	# Diversity may force additional ranged beyond rmin
	var required_ranged: int = 0
	for t in diversity_req.keys():
		if t in RANGED_TYPES and int(diversity_req[t]) > 0 and float(ideal.get(t, 0.0)) > 0.0:
			required_ranged += int(diversity_req[t])
	if required_ranged > rmin:
		rmin = required_ranged

	nonpea_req = max(nonpea_req, rmin)

	var cheapest_ranged = _get_cheapest_unit(RANGED_TYPES)
	var ranged_cost = _unit_cost(cheapest_ranged)

	var wood_min: int = rmin * int(ranged_cost["wood"])
	if wood_min > wood_av:
		return {"feasible": false, "wood_min": wood_min}

	var gold_min: int = rmin * int(ranged_cost["gold"])

	var cheapest_nonpea = _get_cheapest_paid_unit()
	var cheapest_nonpea_cost = _unit_cost(cheapest_nonpea)

	var nonpea_fill: int = max(0, nonpea_req - rmin)
	gold_min += nonpea_fill * int(cheapest_nonpea_cost["gold"])
	var iron_min: int = nonpea_fill * int(cheapest_nonpea_cost["iron"])

	# Add diversity deltas (IMPORTANT: multiply by 'needed')
	for req_t in diversity_req.keys():
		if float(ideal.get(req_t, 0.0)) <= 0.0:
			continue
		var needed: int = int(diversity_req[req_t])
		if needed <= 0:
			continue

		if req_t in RANGED_TYPES:
			var req_cost = _unit_cost(req_t)
			var delta_gold: int = max(0, int(req_cost["gold"]) - int(ranged_cost["gold"]))
			var delta_wood: int = max(0, int(req_cost["wood"]) - int(ranged_cost["wood"]))
			gold_min += needed * delta_gold
			wood_min += needed * delta_wood
		else:
			var req_cost2 = _unit_cost(req_t)
			var delta_gold_non: int = max(0, int(req_cost2["gold"]) - int(cheapest_nonpea_cost["gold"]))
			var delta_wood_non: int = max(0, int(req_cost2["wood"]) - int(cheapest_nonpea_cost["wood"]))
			var delta_iron_non: int = max(0, int(req_cost2["iron"]) - int(cheapest_nonpea_cost["iron"]))
			gold_min += needed * delta_gold_non
			wood_min += needed * delta_wood_non
			iron_min += needed * delta_iron_non

	return {"feasible": gold_min <= gold_budget and wood_min <= wood_av, "gold_min": gold_min, "wood_min": wood_min, "iron_min": iron_min}

func _apply_scarcity_bias(base_ideal_100: Dictionary, boosts: Dictionary, gold_budget: int, recruits: int, low: float, high: float, ranged_lock: bool) -> Dictionary:
	var base = _renormalize_to_100(base_ideal_100)
	var gpr: float = float(gold_budget) / max(1.0, float(recruits))
	var scarcity: float = _clampf((gpr - low) / max(1e-6, (high - low)), 0.0, 1.0)
	scarcity = sqrt(scarcity)
	var out: Dictionary = {}
	for t in base.keys():
		var boost: float = float(boosts.get(t, 0.0))
		out[t] = max(0.0, float(base[t]) * (1.0 + scarcity * boost))
	if ranged_lock:
		var base_np: float = 0.0
		var out_np: float = 0.0
		for t in base.keys():
			if t != SoldierTypeEnum.Type.PEASANTS:
				base_np += float(base[t])
				out_np += float(out[t])
		if base_np > 1e-6 and out_np > 1e-6:
			var target_r: float = float(base.get(SoldierTypeEnum.Type.ARCHERS, 0.0) + base.get(SoldierTypeEnum.Type.CROSSBOWMEN, 0.0)) / base_np
			var curr_r: float = float(out.get(SoldierTypeEnum.Type.ARCHERS, 0.0) + out.get(SoldierTypeEnum.Type.CROSSBOWMEN, 0.0)) / out_np
			if curr_r > 1e-6:
				var corr: float = _clampf(target_r / curr_r, 0.7, 1.4)
				out[SoldierTypeEnum.Type.ARCHERS] = float(out.get(SoldierTypeEnum.Type.ARCHERS, 0.0)) * corr
				out[SoldierTypeEnum.Type.CROSSBOWMEN] = float(out.get(SoldierTypeEnum.Type.CROSSBOWMEN, 0.0)) * corr
	return {"ideal": _renormalize_to_100(out), "gpr": gpr, "scarcity": scarcity}

func _hamilton_round(weights_100: Dictionary, T: int) -> Dictionary:
	var weights = _renormalize_to_100(weights_100)
	var raw: Dictionary = {}
	var floors: Dictionary = {}
	for t in weights.keys():
		raw[t] = (float(weights[t]) / 100.0) * float(T)
		floors[t] = int(floor(raw[t]))
	var remain: int = T - _sum_dict_ints(floors)
	var fracs: Array = []
	for t in weights.keys():
		fracs.append({"frac": float(raw[t]) - float(floors[t]), "type": t})
	fracs.sort_custom(func(a, b): return a["frac"] > b["frac"])
	if not fracs.is_empty():
		for idx in range(remain):
			floors[fracs[idx % fracs.size()]["type"]] += 1
	return floors

func _estimate_ideal_cost(T: int, mapped_ideal: Dictionary) -> int:
	# NOTE: mapped_ideal is expected to use SoldierTypeEnum.Type keys (already mapped).
	if mapped_ideal.is_empty() or T <= 0:
		return 0
	var counts: Dictionary = _hamilton_round(_renormalize_to_100(mapped_ideal), T)
	var cost: int = 0
	for t in counts.keys():
		var n: int = counts[t]
		if n <= 0:
			continue
		var c = _unit_cost(t)
		cost += n * int(c["gold"])
	return cost

func _compute_ranged_bounds(T: int, rmin_share: float, rmax_share: float, wood_av: int) -> Dictionary:
	var cheapest_ranged = _get_cheapest_unit(RANGED_TYPES)
	var ranged_cost = _unit_cost(cheapest_ranged)
	var rmin: int = int(ceil(float(T) * rmin_share))
	var rmax: int = int(floor(float(T) * rmax_share))
	if int(ranged_cost["wood"]) > 0:
		var wood_cap: int = int(floor(float(wood_av) / float(max(1, int(ranged_cost["wood"])))))
		rmin = min(rmin, wood_cap)
		rmax = min(rmax, wood_cap)
	rmin = min(rmin, T)
	rmax = min(max(rmax, rmin), T)
	return {"min": rmin, "max": rmax}

func _construct_base_counts(T: int) -> Dictionary:
	var counts: Dictionary = {}
	for t in UNIT_ORDER:
		counts[t] = 0
	counts[SoldierTypeEnum.Type.PEASANTS] = T
	return counts

func _enforce_ranged_min(counts: Dictionary, g_left: int, w_left: int, i_left: int, rmin: int) -> Dictionary:
	var ranged_now: int = _ranged_units(counts)
	var needed: int = max(0, rmin - ranged_now)
	var cheapest_ranged = _get_cheapest_unit(RANGED_TYPES)
	var cost = _unit_cost(cheapest_ranged)
	var donor_cost = _unit_cost(SoldierTypeEnum.Type.PEASANTS)
	var peasants: int = counts.get(SoldierTypeEnum.Type.PEASANTS, 0)
	var dg: int = int(cost["gold"]) - int(donor_cost["gold"])
	var dw: int = int(cost["wood"]) - int(donor_cost["wood"])
	var di: int = int(cost["iron"]) - int(donor_cost["iron"])
	while needed > 0 and peasants > 0 and _can_afford_delta(g_left, w_left, i_left, dg, dw, di):
		peasants -= 1
		counts[SoldierTypeEnum.Type.PEASANTS] = peasants
		counts[cheapest_ranged] = counts.get(cheapest_ranged, 0) + 1
		g_left -= dg
		w_left -= dw
		i_left -= di
		needed -= 1
	return {"counts": counts, "g_left": g_left, "w_left": w_left, "i_left": i_left}

func _enforce_peasants_cap(counts: Dictionary, g_left: int, w_left: int, i_left: int, cap: int, special_caps: Dictionary, max_tier: int) -> Dictionary:
	var peasants: int = counts.get(SoldierTypeEnum.Type.PEASANTS, 0)
	var cheapest_nonpea = _get_cheapest_paid_unit_upto(max_tier)
	var cost = _unit_cost(cheapest_nonpea)
	var donor_cost = _unit_cost(SoldierTypeEnum.Type.PEASANTS)
	var dg: int = int(cost["gold"]) - int(donor_cost["gold"])
	var dw: int = int(cost["wood"]) - int(donor_cost["wood"])
	var di: int = int(cost["iron"]) - int(donor_cost["iron"])
	while peasants > cap and _can_afford_delta(g_left, w_left, i_left, dg, dw, di):
		if special_caps.has(cheapest_nonpea) and counts.get(cheapest_nonpea, 0) >= int(special_caps[cheapest_nonpea]):
			break
		peasants -= 1
		counts[SoldierTypeEnum.Type.PEASANTS] = peasants
		counts[cheapest_nonpea] = counts.get(cheapest_nonpea, 0) + 1
		g_left -= dg
		w_left -= dw
		i_left -= di
	return {"counts": counts, "g_left": g_left, "w_left": w_left, "i_left": i_left}

func _seed_diversity(counts: Dictionary, diversity_req: Dictionary, g_left: int, w_left: int, i_left: int, rmin: int, rmax: int, special_caps: Dictionary) -> Dictionary:
	for t in diversity_req.keys():
		var need: int = int(diversity_req[t]) - counts.get(t, 0)
		while need > 0:
			if special_caps.has(t) and counts.get(t, 0) >= int(special_caps[t]):
				break
			var donor: SoldierTypeEnum.Type = SoldierTypeEnum.Type.PEASANTS
			if counts.get(donor, 0) <= 0:
				if counts.get(SoldierTypeEnum.Type.SPEARMEN, 0) > 0:
					donor = SoldierTypeEnum.Type.SPEARMEN
				elif counts.get(SoldierTypeEnum.Type.ARCHERS, 0) > 0:
					donor = SoldierTypeEnum.Type.ARCHERS
				else:
					break
			if _ranged_move_breaks_bounds(counts, donor, t, rmin, rmax):
				break
			var donor_cost = _unit_cost(donor)
			var to_cost = _unit_cost(t)
			var dg: int = int(to_cost["gold"]) - int(donor_cost["gold"])
			var dw: int = int(to_cost["wood"]) - int(donor_cost["wood"])
			var di: int = int(to_cost["iron"]) - int(donor_cost["iron"])
			if not _can_afford_delta(g_left, w_left, i_left, dg, dw, di):
				break
			counts[donor] = counts.get(donor, 0) - 1
			counts[t] = counts.get(t, 0) + 1
			g_left -= dg
			w_left -= dw
			i_left -= di
			need -= 1
	return {"counts": counts, "g_left": g_left, "w_left": w_left, "i_left": i_left}

func _move_toward_target(counts: Dictionary, target_counts: Dictionary, g_left: int, w_left: int, i_left: int, rmin: int, rmax: int, special_caps: Dictionary, max_tier: int) -> Dictionary:
	var guard: int = 0
	while guard < 200000:
		guard += 1
		if g_left <= 0:
			break
		var best = {}
		for conv in CONVERSIONS:
			var donor = conv["from"]
			var to = conv["to"]
			if counts.get(donor, 0) <= 0:
				continue
			if special_caps.has(to) and counts.get(to, 0) >= int(special_caps[to]):
				continue

			if GameParameters.UNIT_TIERS.get(to, 99) > max_tier:
				continue
			if _ranged_move_breaks_bounds(counts, donor, to, rmin, rmax):
				continue
			var gaps: int = int(target_counts.get(to, 0)) - counts.get(to, 0)
			if gaps <= 0 and to not in [SoldierTypeEnum.Type.KNIGHTS, SoldierTypeEnum.Type.MOUNTED_KNIGHTS, SoldierTypeEnum.Type.ROYAL_GUARD]:
				continue
			var donor_cost = _unit_cost(donor)
			var to_cost = _unit_cost(to)
			var dg: int = int(to_cost["gold"]) - int(donor_cost["gold"])
			var dw: int = int(to_cost["wood"]) - int(donor_cost["wood"])
			var di: int = int(to_cost["iron"]) - int(donor_cost["iron"])
			if dg < 0:
				continue
			if not _can_afford_delta(g_left, w_left, i_left, dg, dw, di):
				continue
			var power_gain: int = int(to_cost["power"]) - int(donor_cost["power"])
			var ppg: float = 0.0
			if dg > 0:
				ppg = float(power_gain) / float(dg)
			else:
				ppg = float(power_gain) * 1e6
			if best.is_empty() or gaps > best["gap"] or (gaps == best["gap"] and ppg > best["ppg"]):
				best = {"gap": gaps, "ppg": ppg, "donor": donor, "to": to, "dg": dg, "dw": dw, "di": di}
		if best.is_empty():
			break
		counts[best["donor"]] = counts.get(best["donor"], 0) - 1
		counts[best["to"]] = counts.get(best["to"], 0) + 1
		g_left -= int(best["dg"])
		w_left -= int(best["dw"])
		i_left -= int(best["di"])
	return {"counts": counts, "g_left": g_left, "w_left": w_left, "i_left": i_left}

func _burn_budget(counts: Dictionary, g_left: int, w_left: int, i_left: int, rmin: int, rmax: int, special_caps: Dictionary, max_tier: int, target_counts: Dictionary, base_target_counts: Dictionary, gpr: float) -> Dictionary:
	var guard: int = 0
	while guard < 200000:
		guard += 1
		if g_left <= 0:
			break
		var best = {}
		for up in UPGRADES:
			var donor = up["from"]
			var to = up["to"]
			if counts.get(donor, 0) <= 0:
				continue
			if counts.get(donor, 0) <= int(target_counts.get(donor, 0)):
				continue
			if counts.get(donor, 0) <= int(base_target_counts.get(donor, 0)):
				continue
			if special_caps.has(to) and counts.get(to, 0) >= int(special_caps[to]):
				continue
			if GameParameters.UNIT_TIERS.get(to, 99) > max_tier:
				continue
			if _ranged_move_breaks_bounds(counts, donor, to, rmin, rmax):
				continue
			if donor == SoldierTypeEnum.Type.PEASANTS and gpr < 1.0:
				continue
			if donor == SoldierTypeEnum.Type.SPEARMEN and gpr < 0.8:
				continue
			var donor_cost = _unit_cost(donor)
			var to_cost = _unit_cost(to)
			var dg: int = int(to_cost["gold"]) - int(donor_cost["gold"])
			var dw: int = int(to_cost["wood"]) - int(donor_cost["wood"])
			var di: int = int(to_cost["iron"]) - int(donor_cost["iron"])
			if dg <= 0:
				continue
			if not _can_afford_delta(g_left, w_left, i_left, dg, dw, di):
				continue
			var power_gain: int = int(to_cost["power"]) - int(donor_cost["power"])
			if best.is_empty() or dg > best["dg"] or (dg == best["dg"] and power_gain > best["power_gain"]):
				best = {"dg": dg, "dw": dw, "di": di, "donor": donor, "to": to, "power_gain": power_gain}
		if best.is_empty():
			break
		counts[best["donor"]] = counts.get(best["donor"], 0) - 1
		counts[best["to"]] = counts.get(best["to"], 0) + 1
		g_left -= int(best["dg"])
		w_left -= int(best["dw"])
		i_left -= int(best["di"])
	return {"counts": counts, "g_left": g_left, "w_left": w_left, "i_left": i_left}

func _trim_to_caps(counts: Dictionary, special_caps: Dictionary) -> Dictionary:
	if special_caps.is_empty():
		return counts
	for t in special_caps.keys():
		var cap: int = int(special_caps[t])
		if counts.get(t, 0) > cap:
			counts[t] = cap
	return counts

func _top_up_peasants(counts: Dictionary, recruits_avail: int, biased_ideal: Dictionary, pea_cap_share: float, special_caps: Dictionary) -> Dictionary:
	var s: float = float(biased_ideal.get(SoldierTypeEnum.Type.PEASANTS, biased_ideal.get("peasants", 0.0))) / 100.0
	if s <= 0.0 or s >= 1.0:
		return counts
	var P: int = counts.get(SoldierTypeEnum.Type.PEASANTS, 0)
	var N: int = _sum_dict_ints(counts)
	if N <= 0:
		return counts
	var curr: float = float(P) / float(N)
	if curr >= s:
		return counts
	var slots_left: int = max(0, recruits_avail - N)
	if slots_left <= 0:
		return counts
	var needed: int = int(ceil((s * float(N) - float(P)) / max(1e-6, (1.0 - s))))
	var cap_limit: int = int(floor((pea_cap_share * float(N) - float(P)) / max(1e-6, 1.0 - pea_cap_share)))
	if cap_limit < 0:
		cap_limit = 0
	var add: int = min(needed, slots_left, cap_limit)
	if special_caps.has(SoldierTypeEnum.Type.PEASANTS):
		add = min(add, max(0, int(special_caps[SoldierTypeEnum.Type.PEASANTS]) - P))
	if add > 0:
		counts[SoldierTypeEnum.Type.PEASANTS] = P + add
	return counts

func _compute_garrison_caps(garrison_comp: ArmyComposition, ideal_raw: Dictionary) -> Dictionary:
	var ideal = _map_ideal_keys_to_types(ideal_raw)
	var caps: Dictionary = {}
	for t in ideal.keys():
		var target: int = int(ideal[t])
		var current: int = garrison_comp.get_soldier_count(t)
		var deficit: int = max(0, target - current)
		caps[t] = deficit
	return caps

func _apply_hires_to_composition(comp: ArmyComposition, hired: Dictionary, caps: Dictionary) -> void:
	for t in hired.keys():
		var to_add: int = int(hired[t])
		if caps.has(t):
			to_add = min(to_add, int(caps[t]))
		if to_add > 0:
			comp.add_soldiers(t, to_add)

func _get_cheapest_unit(types: Array) -> SoldierTypeEnum.Type:
	var cheapest: SoldierTypeEnum.Type = types[0]
	var cheapest_cost: Dictionary = _unit_cost(cheapest)
	for t in types:
		var c = _unit_cost(t)
		if int(c["gold"]) < int(cheapest_cost["gold"]) or (int(c["gold"]) == int(cheapest_cost["gold"]) and int(c["power"]) > int(cheapest_cost["power"])):
			cheapest = t
			cheapest_cost = c
	return cheapest

func _get_cheapest_paid_unit() -> SoldierTypeEnum.Type:
	var cheapest: SoldierTypeEnum.Type = SoldierTypeEnum.Type.SPEARMEN
	var cheapest_cost: Dictionary = _unit_cost(cheapest)
	for t in UNIT_ORDER:
		if t == SoldierTypeEnum.Type.PEASANTS:
			continue
		var c = _unit_cost(t)
		if int(c["gold"]) < int(cheapest_cost["gold"]) or (int(c["gold"]) == int(cheapest_cost["gold"]) and int(c["power"]) > int(cheapest_cost["power"])):
			cheapest = t
			cheapest_cost = c
	return cheapest

func _ranged_units(counts: Dictionary) -> int:
	var total: int = 0
	for t in RANGED_TYPES:
		total += counts.get(t, 0)
	return total

func _can_afford_delta(g_left: int, w_left: int, i_left: int, dg: int, dw: int, di: int) -> bool:
	return dg <= g_left and dw <= w_left and di <= i_left

func _ranged_move_breaks_bounds(counts: Dictionary, donor: SoldierTypeEnum.Type, to: SoldierTypeEnum.Type, rmin: int, rmax: int) -> bool:
	var r_now: int = _ranged_units(counts)
	var new_r: int = r_now - (1 if donor in RANGED_TYPES else 0) + (1 if to in RANGED_TYPES else 0)
	return new_r < rmin or new_r > rmax

func _unit_cost(t: SoldierTypeEnum.Type) -> Dictionary:
	return {
		"gold": GameParameters.get_unit_recruit_cost(t),
		"wood": GameParameters.get_unit_wood_cost(t),
		"iron": GameParameters.get_unit_iron_cost(t),
		"power": GameParameters.get_unit_power(t)
	}

func _totals(counts: Dictionary) -> Dictionary:
	var gold: int = 0
	var wood: int = 0
	var iron: int = 0
	var power: int = 0
	for t in counts.keys():
		var n: int = counts[t]
		var c = _unit_cost(t)
		gold += n * int(c["gold"])
		wood += n * int(c["wood"])
		iron += n * int(c["iron"])
		power += n * int(c["power"])
	return {"gold": gold, "wood": wood, "iron": iron, "power": power}

func _sum_dict_ints(m: Dictionary) -> int:
	var s: int = 0
	for k in m.keys():
		s += int(m[k])
	return s

func _renormalize_to_100(d: Dictionary) -> Dictionary:
	var s: float = 0.0
	for k in d.keys():
		s += max(0.0, float(d[k]))
	if s <= 0.0:
		return d
	var out: Dictionary = {}
	for k in d.keys():
		out[k] = max(0.0, float(d[k])) * 100.0 / s
	return out

func _clampf(x: float, a: float, b: float) -> float:
	return max(a, min(b, x))

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

func _get_cheapest_paid_unit_upto(max_tier: int) -> SoldierTypeEnum.Type:
	var cheapest: SoldierTypeEnum.Type = SoldierTypeEnum.Type.SPEARMEN
	var cheapest_cost: Dictionary = _unit_cost(cheapest)

	for t in UNIT_ORDER:
		if t == SoldierTypeEnum.Type.PEASANTS:
			continue
		if GameParameters.UNIT_TIERS.get(t, 99) > max_tier:
			continue
		var c = _unit_cost(t)
		if int(c["gold"]) < int(cheapest_cost["gold"]) or (int(c["gold"]) == int(cheapest_cost["gold"]) and int(c["power"]) > int(cheapest_cost["power"])):
			cheapest = t
			cheapest_cost = c

	return cheapest

func _sum_counts(counts: Dictionary) -> int:
	var total := 0
	for k in counts.keys():
		total += int(counts[k])
	return total
