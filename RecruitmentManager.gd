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
	# Use new units.py-based allocation algorithm
	var budget: BudgetComposition = army.assigned_budget
	print("[RecruitmentManager] Army ", army.name, " has budget: ", budget.to_dict())

	var region: Region = army.get_parent()
	var player_id = army.get_player_id()

	var recruit_sources = _gather_recruit_sources(region, player_id)
	var total_units = _sum_sources(recruit_sources)

	var need_key: String = CastleTypeEnum.type_to_string(region.get_castle_type())
	var ideal_raw: Dictionary = GameParameters.get_ideal_composition(need_key)
	var ideal = _normalize_ideal(_map_ideal_keys_to_types(ideal_raw))
	var unit0_share = ideal.get(SoldierTypeEnum.Type.PEASANTS, 0.0)

	var result = _allocate_with_unit0_gd(
		army, budget, total_units, ideal, unit0_share, {}, debug
	)

	if result.get("total_recruited", 0) > 0:
		_deduct_recruits_proportionally(result["total_recruited"], recruit_sources)

	army.clear_recruitment_request()
	var recruits_remaining = _count_recruits_remaining(recruit_sources)

	print("Hired: %s" % result["hired"])
	print("Recruits remaining: %d" % recruits_remaining)

	return {
		"hired": result["hired"],
		"spent_gold": result["spent_gold"],
		"spent_wood": result["spent_wood"],
		"spent_iron": result["spent_iron"],
		"budget_left": budget.to_dict(),
		"recruits_left": recruits_remaining
	}


# Helpers ------------------------------------------------------------------
func _gather_recruit_sources(region: Region, player_id: int) -> Array:
	# Always gather from region and neighbors (AI-only usage via TurnController)
	var sources = region_manager.get_available_recruits_from_region_and_neighbors(region.get_region_id(), player_id)
	var total = 0
	for s in sources:
		total += s.amount
	print("[RecruitmentManager] Total recruits from ", sources.size(), " regions: ", total)
	return sources

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

# Core units.py allocation algorithm -----------------------------------------
func _allocate_with_unit0_gd(
	army: Army,
	budget: BudgetComposition, 
	total_units: int, 
	ideal: Dictionary, 
	unit0_share: float, 
	special_caps: Dictionary = {},
	debug: bool = false
) -> Dictionary:
	"""Mirror units.py allocation algorithm using game data"""
	
	# 1) Unit 0 (peasants - free)
	var unit0 = int(floor(unit0_share * float(total_units)))
	var paid_units_cap = max(0, total_units - unit0)
	
	# 2) Build non-peasant props (integer ratios)
	var non_peasant_types: Array = []
	var props_raw: Dictionary = {}
	for t in ideal.keys():
		if t != SoldierTypeEnum.Type.PEASANTS and ideal.get(t, 0.0) > 0.0:
			non_peasant_types.append(t)
			props_raw[t] = max(1, int(round(ideal[t] * 100.0)))
	
	# Sort for stable ordering
	non_peasant_types.sort_custom(func(a, b): return int(a) < int(b))
	
	if non_peasant_types.is_empty():
		# No paid units - just add peasants
		army.add_soldiers(SoldierTypeEnum.Type.PEASANTS, unit0)
		return {
			"hired": {SoldierTypeEnum.Type.PEASANTS: unit0},
			"spent_gold": 0, "spent_wood": 0, "spent_iron": 0,
			"total_recruited": unit0
		}
	
	# Build unit costs only for non-peasant types (micro-optimization)
	var unit_costs = _get_unit_costs_map(non_peasant_types)
	
	# Reduce props by GCD to keep numbers small
	var gcd_val = _gcd_all(props_raw.values())
	var props: Dictionary = {}
	for t in non_peasant_types:
		props[t] = props_raw[t] / gcd_val
	
	var P = _sum_dict_values(props)
	
	# 3) Pack costs (vector sum)
	var pack_costs = _compute_pack_costs(props, unit_costs)
	
	# 4) Full packages (min over all constraints)
	var full_packages = _max_full_packages(budget, pack_costs, P, paid_units_cap, special_caps, props)
	
	if debug:
		print("=== UNITS.PY DEBUG ===")
		print("Total units: ", total_units, ", Unit0: ", unit0, ", Paid cap: ", paid_units_cap)
		print("Props: ", props, ", P: ", P)
		print("Pack costs: ", pack_costs)
		print("Full packages: ", full_packages)
	
	# 5) Apply full packages
	var x_paid: Dictionary = {}
	for t in non_peasant_types:
		x_paid[t] = full_packages * props[t]
	
	# Spend budget for full packages
	for res in ["gold", "wood", "iron"]:
		var cost = full_packages * pack_costs.get(res, 0)
		match res:
			"gold": budget.gold -= cost
			"wood": budget.wood -= cost
			"iron": budget.iron -= cost
	
	var units_left = paid_units_cap - full_packages * P
	
	# 6) Partial sequence fill
	var seq = _build_sequence(props, non_peasant_types)
	
	var changed = true
	var loop_count = 0
	while changed and units_left > 0 and _can_afford_any(budget, unit_costs, non_peasant_types):
		loop_count += 1
		if loop_count > 1000: break  # safety
		
		changed = false
		for i in seq:
			# Check special caps
			if special_caps.has(i) and x_paid.get(i, 0) >= special_caps[i]:
				continue
			
			var cost = unit_costs[i]
			if units_left > 0 and budget.can_afford(cost):
				x_paid[i] = x_paid.get(i, 0) + 1
				units_left -= 1
				budget.spend(cost)
				changed = true
			
			if units_left == 0 or not _can_afford_any(budget, unit_costs, non_peasant_types):
				break
	
	if debug:
		print("Partial fill: ", x_paid, ", units left: ", units_left)
	
	# 7) Apply to army
	if unit0 > 0:
		army.add_soldiers(SoldierTypeEnum.Type.PEASANTS, unit0)
	for t in non_peasant_types:
		var count = x_paid.get(t, 0)
		if count > 0:
			army.add_soldiers(t, count)
	
	# 8) Calculate spending
	var hired: Dictionary = {}
	if unit0 > 0:
		hired[SoldierTypeEnum.Type.PEASANTS] = unit0
	for t in non_peasant_types:
		var count = x_paid.get(t, 0)
		if count > 0:
			hired[t] = count
	
	var spent_gold = 0
	var spent_wood = 0
	var spent_iron = 0
	for t in non_peasant_types:
		var count = x_paid.get(t, 0)
		var cost = unit_costs[t]
		spent_gold += count * cost["gold"]
		spent_wood += count * cost["wood"]
		spent_iron += count * cost["iron"]
	
	var total_recruited = unit0 + _sum_dict_values(x_paid)
	
	return {
		"hired": hired,
		"spent_gold": spent_gold,
		"spent_wood": spent_wood, 
		"spent_iron": spent_iron,
		"total_recruited": total_recruited
	}

# Vector pack helpers ------------------------------------------------------
func _compute_pack_costs(props: Dictionary, unit_costs: Dictionary) -> Dictionary:
	"""Sum costs per resource weighted by props"""
	var pack: Dictionary = {"gold": 0, "wood": 0, "iron": 0}
	for t in props.keys():
		var p = props[t]
		var cost = unit_costs[t]
		pack["gold"] += p * cost["gold"]
		pack["wood"] += p * cost["wood"]
		pack["iron"] += p * cost["iron"]
	return pack

func _max_full_packages(budget: BudgetComposition, pack_costs: Dictionary, P: int, paid_units_cap: int, special_caps: Dictionary, props: Dictionary) -> int:
	"""Min over all resource floors, units cap, and per-type caps"""
	var candidates: Array = []
	
	# Budget constraints
	for res in ["gold", "wood", "iron"]:
		var pack_cost = pack_costs.get(res, 0)
		if pack_cost > 0:
			var budget_val = 0
			match res:
				"gold": budget_val = budget.gold
				"wood": budget_val = budget.wood  
				"iron": budget_val = budget.iron
			candidates.append(int(floor(float(budget_val) / float(pack_cost))))
	
	# Units cap
	if P > 0:
		candidates.append(int(floor(float(paid_units_cap) / float(P))))
	
	# Special caps per type
	for t in special_caps.keys():
		if props.has(t) and props[t] > 0:
			candidates.append(int(floor(float(special_caps[t]) / float(props[t]))))
	
	if candidates.is_empty():
		return 0
	
	var min_val = candidates[0]
	for c in candidates:
		min_val = min(min_val, c)
	return max(0, min_val)

func _build_sequence(props: Dictionary, unit_types: Array) -> Array:
	"""Repeat each type according to props (e.g., {A:3,B:2,C:1} -> [A,A,A,B,B,C])"""
	var seq: Array = []
	for t in unit_types:
		var count = props.get(t, 0)
		for i in range(count):
			seq.append(t)
	return seq

func _can_afford_any(budget: BudgetComposition, unit_costs: Dictionary, candidates: Array) -> bool:
	"""True if any unit type can be afforded"""
	for t in candidates:
		if budget.can_afford(unit_costs[t]):
			return true
	return false


func _sum_dict_values(dict: Dictionary) -> int:
	"""Sum all values in dictionary"""
	var sum = 0
	for key in dict.keys():
		sum += int(dict[key])
	return sum

func _gcd_all(values: Array) -> int:
	"""Calculate GCD of all values in array"""
	if values.is_empty(): return 1
	var result = int(values[0])
	for i in range(1, values.size()):
		result = _gcd(result, int(values[i]))
	return max(1, result)

func _gcd(a: int, b: int) -> int:
	"""Calculate greatest common divisor"""
	while b != 0:
		var temp = b
		b = a % b
		a = temp
	return abs(a)

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
