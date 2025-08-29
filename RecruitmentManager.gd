extends RefCounted
class_name RecruitmentManager

# Dependencies (assumed to exist)
var region_manager: RegionManager
var game_manager: GameManager

const MIN_PEA_SHARE = 0.05
const QUALITY_BIAS_STRONG = 0.75
const QUALITY_BIAS_WEAK = 0.15
const SCARCE_RECRUITS_THRESHOLD = 5

func _init(region_mgr: RegionManager = null, game_mgr: GameManager = null) -> void:
	region_manager = region_mgr
	game_manager = game_mgr

# Public API ---------------------------------------------------------------
func hire_soldiers(army: Army, debug: bool = false) -> Dictionary:
	var budget: BudgetComposition = army.assigned_budget
	print("[RecruitmentManager] Army ", army.name, " has budget: ", budget.to_dict())

	var region: Region = army.get_parent()
	var player_id = army.get_player_id()

	var recruit_sources = _gather_recruit_sources(region, player_id)
	var recruits_avail = _sum_sources(recruit_sources)

	var need_key: String = CastleTypeEnum.type_to_string(region.get_castle_type())
	print("Need key: ", need_key)
	var ideal_raw: Dictionary = GameParameters.get_ideal_composition(need_key)
	var ideal = _normalize_ideal(_map_ideal_keys_to_types(ideal_raw))

	var pea_min_prop = MIN_PEA_SHARE
	var pea_max_prop = ideal.get(SoldierTypeEnum.Type.PEASANTS, 0.0)
	if pea_max_prop < pea_min_prop:
		pea_max_prop = pea_min_prop

	var curr_counts = _get_current_counts(army)
	var unit_types = _types_from_ideal(ideal)
	var unit_power = _get_unit_power_map(unit_types)
	var unit_costs = _get_unit_costs_map(unit_types)
	var norm_power = _normalize_power(unit_power)

	var hired: Dictionary = {}
	var spent_gold = 0
	var spent_wood = 0
	var spent_iron = 0

	if debug:
		print("=== RECRUITMENT DEBUG ===")
		print("Budget: gold=%d, wood=%d, iron=%d" % [budget.gold, budget.wood, budget.iron])
		print("Recruits available: %d" % recruits_avail)
		print("Ideal composition: ", ideal)
		print("Unit types: ", unit_types)

	# Quota planning
	var pea_share = float(ideal.get(SoldierTypeEnum.Type.PEASANTS, 0.0))
	var non_pea_share_den = max(0.0, 1.0 - pea_share)
	var non_pea_types: Array = []
	for t in unit_types:
		if t != SoldierTypeEnum.Type.PEASANTS and ideal.get(t, 0.0) > 0.0:
			non_pea_types.append(t)

	var target_non_pea_total = int(round(non_pea_share_den * float(recruits_avail)))
	var planned_non_pea: Dictionary = {}
	var rema: Array = []
	var sum_floor = 0
	for t in non_pea_types:
		var exact = float(ideal[t]) * float(recruits_avail)
		var fl = int(floor(exact))
		planned_non_pea[t] = fl
		sum_floor += fl
		rema.append({"t": t, "r": exact - float(fl)})
	var to_distribute = max(0, target_non_pea_total - sum_floor)
	var _cmp_rema = func(a, b):
		var ar = float(a["r"])
		var br = float(b["r"])
		if abs(ar - br) < 0.000001:
			return float(ideal.get(a["t"], 0.0)) > float(ideal.get(b["t"], 0.0))
		return ar > br
	rema.sort_custom(_cmp_rema)
	for i in range(min(to_distribute, rema.size())):
		var t = rema[i]["t"]
		planned_non_pea[t] = planned_non_pea.get(t, 0) + 1

	var planned_peasants = recruits_avail - target_non_pea_total

	if debug:
		print("Non-peasant types: ", non_pea_types)
		print("Target non-peasant total: ", target_non_pea_total)
		print("Planned non-peasant: ", planned_non_pea)
		print("Planned peasants: ", planned_peasants)

	# Purchase non-peasants by quota with resource-aware redistribution (interleaved, 1-unit picks)
	var blocked: Dictionary = {}
	var loop_safety = 0
	while loop_safety < 1000:
		loop_safety += 1
		var progress = false
		# Mark blocked types (unaffordable now)
		for t in non_pea_types:
			if int(planned_non_pea.get(t, 0)) > 0:
				var cost = unit_costs[t]
				if not budget.can_afford(cost):
					blocked[t] = true
		# Pick one unit to buy interleaved by remaining quota fraction and small power bias
		var best_t = null
		var best_score = -1e9
		var denom_total = 0
		for t in non_pea_types:
			denom_total += int(planned_non_pea.get(t, 0))
		for t in non_pea_types:
			var q = int(planned_non_pea.get(t, 0))
			if q <= 0 or blocked.has(t):
				continue
			var cost = unit_costs[t]
			if not budget.can_afford(cost):
				blocked[t] = true
				continue
			var frac = (float(q) / float(max(1, denom_total)))
			var score = frac + 0.05 * float(unit_power.get(t, 0))
			if score > best_score:
				best_score = score
				best_t = t
		if best_t != null and recruits_avail > 0:
			var cst = unit_costs[best_t]
			if budget.spend(cst):
				army.add_soldiers(best_t, 1)
				curr_counts[best_t] = curr_counts.get(best_t, 0) + 1
				recruits_avail -= 1
				planned_non_pea[best_t] = int(planned_non_pea.get(best_t, 0)) - 1
				hired[best_t] = hired.get(best_t, 0) + 1
				spent_gold += cst["gold"]
				spent_wood += cst["wood"]
				spent_iron += cst["iron"]
				progress = true
		# If nothing moved, consider redistribution or break
		var missing = 0
		for t in non_pea_types:
			missing += max(0, int(planned_non_pea.get(t, 0)))
		if debug:
			print("Loop iteration ", loop_safety, ": progress=", progress, ", missing=", missing, ", blocked=", blocked)
		if progress == false and missing == 0:
			break
		if not progress:
			# No progress made - check if we need to redistribute from blocked types
			var has_blocked = false
			for t in non_pea_types:
				if blocked.has(t) and planned_non_pea.get(t, 0) > 0:
					has_blocked = true
					break
			if not has_blocked:
				# Nothing blocked with quota, can't make progress
				break
			# Redistribute remaining quotas from blocked types
			var remaining_sum = 0.0
			for t in non_pea_types:
				if not blocked.has(t):
					remaining_sum += float(ideal.get(t, 0.0))
			if remaining_sum <= 0.0:
				break
			# Clear quotas for blocked types, pool their counts
			var pool = 0
			for t in non_pea_types:
				if blocked.has(t):
					pool += int(planned_non_pea.get(t, 0))
					planned_non_pea[t] = 0
			if pool <= 0:
				break
			# Distribute pool by remaining weights
			var fracs: Array = []
			for t in non_pea_types:
				if not blocked.has(t):
					var share = float(ideal.get(t, 0.0)) / remaining_sum
					var exact = share * float(pool)
					planned_non_pea[t] = int(floor(float(planned_non_pea.get(t,0)) + exact))
					fracs.append({"t": t, "r": exact - floor(exact)})
			# Fix rounding to sum to pool
			var sum_now = 0
			for t in non_pea_types:
				if not blocked.has(t):
					sum_now += int(planned_non_pea.get(t,0))
			var need = pool - sum_now
			var _cmp_fracs = func(a, b):
				var ar = float(a["r"])
				var br = float(b["r"])
				if abs(ar - br) < 0.000001:
					return float(ideal.get(a["t"], 0.0)) > float(ideal.get(b["t"], 0.0))
				return ar > br
			fracs.sort_custom(_cmp_fracs)
			for i in range(max(0, need)):
				var tk2 = fracs[i]["t"]
				planned_non_pea[tk2] = int(planned_non_pea.get(tk2,0)) + 1
			# Reset blocked to re-attempt purchase with new quotas
			blocked.clear()

	# Purchase peasants up to planned count (respect max cap)
	var pea_type = SoldierTypeEnum.Type.PEASANTS
	while recruits_avail > 0 and planned_peasants > 0:
		# Cap check against final proportion
		if _would_exceed_peasant_cap(curr_counts, pea_type, pea_max_prop):
			break
		army.add_soldiers(pea_type, 1)
		curr_counts[pea_type] = curr_counts.get(pea_type, 0) + 1
		recruits_avail -= 1
		planned_peasants -= 1
		hired[pea_type] = hired.get(pea_type, 0) + 1

	# Ensure minimum peasants share (if possible and under cap)
	while recruits_avail > 0:
		var total2 = _sum_counts(curr_counts)
		var pea_prop2 = (float(curr_counts.get(pea_type, 0)) / float(total2)) if total2 > 0 else 0.0
		if pea_prop2 >= pea_min_prop:
			break
		if _would_exceed_peasant_cap(curr_counts, pea_type, pea_max_prop):
			break
		army.add_soldiers(pea_type, 1)
		curr_counts[pea_type] = curr_counts.get(pea_type, 0) + 1
		recruits_avail -= 1
		hired[pea_type] = hired.get(pea_type, 0) + 1

	var total_recruited = _sum_counts(hired)
	if total_recruited > 0:
		_deduct_recruits_proportionally(total_recruited, recruit_sources)

	army.clear_recruitment_request()

	var recruits_remaining = _count_recruits_remaining(recruit_sources)
	print("Hired: %s" % hired)
	print("Recruits remaining: %d" % recruits_remaining)

	return {
		"hired": hired,
		"spent_gold": spent_gold,
		"spent_wood": spent_wood,
		"spent_iron": spent_iron,
		"budget_left": budget.to_dict(),
		"recruits_left": recruits_remaining
	}

# Helpers ------------------------------------------------------------------
func _gather_recruit_sources(region: Region, player_id: int) -> Array:
	if game_manager.is_player_computer(player_id):
		var sources = region_manager.get_available_recruits_from_region_and_neighbors(region.get_region_id(), player_id)
		var total = 0
		for s in sources:
			total += s.amount
		print("[RecruitmentManager] Computer player - total recruits from ", sources.size(), " regions: ", total)
		return sources
	var avail = region.get_available_recruits()
	print("[RecruitmentManager] Human player - region has ", avail, " available recruits")
	return [{"region_id": region.get_region_id(), "amount": avail}]

func _sum_sources(recruit_sources: Array) -> int:
	var s = 0
	for source in recruit_sources:
		s += int(source.amount)
	return s

func _count_recruits_remaining(recruit_sources: Array) -> int:
	var left = 0
	for source in recruit_sources:
		var source_region = region_manager.map_generator.get_region_container_by_id(source.region_id)
		left += source_region.get_available_recruits()
	return left

func _deduct_recruits_proportionally(total_to_deduct: int, recruit_sources: Array) -> void:
	if recruit_sources.is_empty() or total_to_deduct <= 0:
		return
	var total_available = 0
	for s in recruit_sources:
		total_available += int(s.amount)
	if total_available <= 0:
		return
	var remaining = total_to_deduct
	for i in range(recruit_sources.size()):
		var src = recruit_sources[i]
		var container = region_manager.map_generator.get_region_container_by_id(src.region_id)
		var reg = container as Region
		var to_deduct = 0
		if i == recruit_sources.size() - 1:
			to_deduct = remaining
		else:
			var proportion = float(src.amount) / float(total_available)
			to_deduct = int(proportion * total_to_deduct)
		if to_deduct > 0:
			var actual = reg.hire_recruits(to_deduct)
			remaining -= actual

func _get_affordable_types(budget: BudgetComposition, unit_types: Array, unit_costs: Dictionary) -> Array:
	var arr: Array = []
	for t in unit_types:
		var c = unit_costs[t]
		if budget.can_afford(c):
			arr.append(t)
	return arr

func _would_exceed_peasant_cap(curr_counts: Dictionary, add_type: SoldierTypeEnum.Type, pea_max_prop: float) -> bool:
	if add_type != SoldierTypeEnum.Type.PEASANTS:
		return false
	var peas = int(curr_counts.get(SoldierTypeEnum.Type.PEASANTS, 0))
	var total = _sum_counts(curr_counts)
	var new_total = total + 1
	var new_peas = peas + 1
	var new_prop = float(new_peas) / float(new_total)
	return new_prop > pea_max_prop + 1e-6

func _would_exceed_dynamic_peasant_cap(peasants_added: int, non_peasants_added: int, add_type: SoldierTypeEnum.Type, pea_max_prop: float) -> bool:
	if add_type != SoldierTypeEnum.Type.PEASANTS:
		return false
	var new_p = peasants_added + 1
	var new_n = non_peasants_added
	var new_total = new_p + new_n
	if new_total <= 0:
		return false
	var new_prop = float(new_p) / float(new_total)
	return new_prop > pea_max_prop + 1e-6

func _map_ideal_keys_to_types(raw: Dictionary) -> Dictionary:
	# Map "peasants"/"spearman"/"archers" -> SoldierTypeEnum.Type
	var out: Dictionary = {}
	for k in raw.keys():
		var key: String = str(k).to_lower()
		var pct: float = float(raw[k])
		match key:
			"peasants":
				out[SoldierTypeEnum.Type.PEASANTS] = pct
			"spearmen":
				out[SoldierTypeEnum.Type.SPEARMEN] = pct
			"archers":
				out[SoldierTypeEnum.Type.ARCHERS] = pct
			"knights":
				out[SoldierTypeEnum.Type.KNIGHTS] = pct
			"horsemen":
				out[SoldierTypeEnum.Type.HORSEMEN] = pct
			"swordsman":
				out[SoldierTypeEnum.Type.SWORDSMEN] = pct
			"swordsmen":
				out[SoldierTypeEnum.Type.SWORDSMEN] = pct
			"mounted_knights":
				out[SoldierTypeEnum.Type.MOUNTED_KNIGHTS] = pct
			"royal_guard":
				out[SoldierTypeEnum.Type.ROYAL_GUARD] = pct
			"crossbowmen":
				out[SoldierTypeEnum.Type.CROSSBOWMEN] = pct
			_:
				# Unknown label -> ignore silently (keeps KISS)
				pass
	return out

func _normalize_ideal(ideal: Dictionary) -> Dictionary:
	# Accept either 0..100 (percent) or 0..1; normalize to sum = 1.0
	var total = 0.0
	for t in ideal.keys():
		total += float(ideal[t])
	if total <= 0.0:
		return ideal
	var denom = 0.0
	if total > 1.01:
		denom = 100.0
	else:
		denom = total
	var out: Dictionary = {}
	for t in ideal.keys():
		out[t] = float(ideal[t]) / denom
	return out

func _renormalize(m: Dictionary) -> Dictionary:
	var s = 0.0
	for k in m.keys(): s += float(m[k])
	if s <= 0.0: return m
	var out = {}
	for k in m.keys(): out[k] = float(m[k]) / s
	return out

func _get_current_counts(army: Army) -> Dictionary:
	var comp = army.get_composition()
	var out = {}
	for t in SoldierTypeEnum.get_all_types():
		out[t] = comp.get_soldier_count(t)
	return out

func _sum_counts(m: Dictionary) -> int:
	var s = 0
	for t in m.keys(): s += int(m[t])
	return s

func _compute_prop(counts: Dictionary, total: int) -> Dictionary:
	var out = {}
	if total <= 0:
		for t in counts.keys(): out[t] = 0.0
		return out
	for t in counts.keys():
		out[t] = float(counts[t]) / float(total)
	return out

func _compute_gaps(ideal: Dictionary, curr_prop: Dictionary) -> Dictionary:
	var out = {}
	for t in ideal.keys():
		out[t] = float(ideal[t]) - float(curr_prop.get(t, 0.0))
	return out

func _types_from_ideal(ideal: Dictionary) -> Array:
	var arr: Array = []
	for t in ideal.keys():
		var share = float(ideal[t])
		if share > 0.0 or t == SoldierTypeEnum.Type.PEASANTS:
			arr.append(t)
	return arr

func _get_unit_power_map(types: Array) -> Dictionary:
	var out = {}
	for t in types:
		out[t] = GameParameters.get_unit_power(t)
	return out

func _get_unit_costs_map(types: Array) -> Dictionary:
	var out = {}
	for t in types:
		var gold: int = GameParameters.get_unit_recruit_cost(t)
		var wood: int = GameParameters.get_unit_wood_cost(t)    # 0 for units with no wood
		var iron: int = GameParameters.get_unit_iron_cost(t)    # 0 for units with no iron
		out[t] = { "gold": gold, "wood": wood, "iron": iron }
	return out

func _normalize_power(powers: Dictionary) -> Dictionary:
	var minp: float = 1e9
	var maxp = -1e9
	for t in powers.keys():
		minp = min(minp, float(powers[t]))
		maxp = max(maxp, float(powers[t]))
	var range: float = max(0.001, maxp - minp)
	var out = {}
	for t in powers.keys():
		out[t] = (float(powers[t]) - minp) / range
	return out
