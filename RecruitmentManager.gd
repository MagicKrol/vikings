# RecruitmentManager.gd
extends RefCounted
class_name RecruitmentManager

# Keep at least this share of peasants (5%)
const MIN_PEA_SHARE := 0.05

# Quality bias when recruits are scarce (prefers high-power units)
const QUALITY_BIAS_STRONG := 0.75
const QUALITY_BIAS_WEAK := 0.15
const SCARCE_RECRUITS_THRESHOLD := 5  # if ≤ this, lean into quality

# Public entry point
# - army: Army node to recruit into (budget taken from army.assigned_budget)
# - debug: if true, print detailed debug information
#
# Returns a small report dictionary for debugging/telemetry.
# Uses army.assigned_budget and clears it after successful recruitment.
# Also clears army.recruitment_requested flag.
func hire_soldiers(army: Army, debug: bool = false) -> Dictionary:
	# Check if army has assigned budget
	if not army.assigned_budget:
		print("[RecruitmentManager] Army ", army.name, " has no assigned budget")
		return {"hired": {}, "error": "no_budget"}
	
	var budget: BudgetComposition = army.assigned_budget
	print("[RecruitmentManager] Army ", army.name, " has budget: ", budget.to_dict())
	
	var region: Region = army.get_parent()
	if not region:
		print("[RecruitmentManager] Army ", army.name, " has no parent region")
		return {"hired": {}, "error": "no_region"}
	
	var recruits_avail: int = region.get_available_recruits()  # must exist in Region
	print("[RecruitmentManager] Region has ", recruits_avail, " available recruits")
	
	var need_key: String = CastleTypeEnum.type_to_string(region.get_castle_type())

	# Pull the ideal composition (percentages sum to 100 or 1.0)
	var ideal_raw: Dictionary = GameParameters.get_ideal_composition(need_key)  # e.g., {"peasants":47,"spearmen":33,"archers":20}
	if ideal_raw.is_empty():
		push_error("[RecruitmentManager] Invalid need_key '" + need_key + "' - no ideal composition found in GameParameters")
		return {"hired": {}, "error": "invalid_need_key"}
	var ideal := _normalize_ideal(_map_ideal_keys_to_types(ideal_raw))  # { SoldierTypeEnum.Type : 0..1 }
	
	# Enforce minimal peasants share, renormalize
	if ideal.has(SoldierTypeEnum.Type.PEASANTS):
		ideal[SoldierTypeEnum.Type.PEASANTS] = max(ideal[SoldierTypeEnum.Type.PEASANTS], MIN_PEA_SHARE)
		ideal = _renormalize(ideal)
	
	# Snapshot current composition
	var curr_counts := _get_current_counts(army)              # { type : count }
	var curr_total := _sum_counts(curr_counts)
	
	# Precompute base unit data
	var unit_types := _types_from_ideal(ideal)
	var unit_power := _get_unit_power_map(unit_types)         # { type : power }
	var unit_costs := _get_unit_costs_map(unit_types)         # { type : {gold, wood, iron} }
	
	# Normalize powers for tie-breaks / quality bias
	var norm_power := _normalize_power(unit_power)            # { type : 0..1 }
	
	var hired: Dictionary = {}                                # { type : count }
	var spent_gold := 0
	var spent_wood := 0
	var spent_iron := 0
	var recruited_so_far := 0
	
	# Debug output (only if requested)  
	if debug:  # back to normal debug control
		print("=== RECRUITMENT DEBUG ===")
		print("Budget: gold=%d, wood=%d, iron=%d" % [budget.gold, budget.wood, budget.iron])
		print("Recruits available: %d" % recruits_avail)
		print("Ideal composition: %s" % ideal)
		print("Unit costs: %s" % unit_costs)
		print("Unit power: %s" % unit_power)
		print("Normalized power: %s" % norm_power)
	
	# Main greedy loop (one unit at a time → simple, robust, Pareto)
	while recruits_avail > 0:
		# Filter types we can still buy at least 1 of (by gold AND resources)
		var affordable: Array = []
		for t in unit_types:
			var c = unit_costs[t]
			if budget.can_afford(c):
				affordable.append(t)
		if affordable.is_empty():
			if debug and recruited_so_far == 0:
				print("  -> No affordable units found (budget exhausted or zero)")
			break  # nothing more we can buy
		
		# Compute current proportions; handle empty army gracefully
		curr_total = _sum_counts(curr_counts)
		var curr_prop := _compute_prop(curr_counts, curr_total)  # { type : 0..1 }
		var gaps := _compute_gaps(ideal, curr_prop)              # positive gap = we need more of that type
		
		# Pick best type to buy one unit (gap first, quality bias second)
		var scarce := recruits_avail <= SCARCE_RECRUITS_THRESHOLD
		var bias := QUALITY_BIAS_STRONG if scarce else QUALITY_BIAS_WEAK
		
		var best_type: SoldierTypeEnum.Type
		var best_score := -1e9
		
		for t in affordable:
			var gap: float = gaps.get(t, 0.0)
			var qual_term: float = norm_power.get(t, 0.0)
			
			# If we have a positive gap, prioritize filling it
			# If gap is negative (we have too many), heavily penalize
			var score: float
			if gap > 0.0:
				# Positive gap: prioritize this type, with small quality bonus
				score = gap + bias * qual_term
			else:
				# Negative gap: only quality matters, but heavily penalized
				# This ensures we avoid over-recruiting high-power units
				score = -abs(gap) * 2.0 + bias * qual_term * 0.1
			
			# Debug output for first few iterations (only if requested)
			if false and recruited_so_far < 5:  # debug disabled
				print("  Type %s: gap=%.3f, qual_term=%.3f, score=%.3f" % [t, gap, qual_term, score])
			
			if score > best_score:
				best_score = score
				best_type = t
		
		if best_type == null:
			break
		
		# Check resources again and buy 1 unit
		var uc = unit_costs[best_type]
		if not budget.can_afford(uc):
			# Shouldn't happen due to affordable filter, but guard anyway
			affordable.erase(best_type)
			if affordable.is_empty():
				break
			continue
		
		# Deduct from budget
		if not budget.spend(uc):
			# Should not happen since we checked can_afford
			break
		
		# Apply to the army
		army.add_soldiers(best_type, 1)
		curr_counts[best_type] = curr_counts.get(best_type, 0) + 1
		recruits_avail -= 1
		recruited_so_far += 1
		
		if false and recruited_so_far <= 5:  # debug disabled
			print("  -> Selected %s (score=%.3f)" % [best_type, best_score])
		
		hired[best_type] = hired.get(best_type, 0) + 1
		spent_gold += uc["gold"]
		spent_wood += uc["wood"]
		spent_iron += uc["iron"]
	
	# Enforce minimal peasants share if still short (try to add peasants while possible)
	if ideal.has(SoldierTypeEnum.Type.PEASANTS):
		var pea_type = SoldierTypeEnum.Type.PEASANTS
		while recruits_avail > 0:
			curr_total = _sum_counts(curr_counts)
			var pea_prop = float(curr_counts.get(pea_type, 0)) / float(curr_total) if curr_total > 0 else 0.0
			if pea_prop >= MIN_PEA_SHARE:
				break
			var pc = unit_costs[pea_type]
			if not budget.can_afford(pc):
				break
			if not budget.spend(pc):
				break
			army.add_soldiers(pea_type, 1)
			curr_counts[pea_type] = curr_counts.get(pea_type, 0) + 1
			recruits_avail -= 1
			hired[pea_type] = hired.get(pea_type, 0) + 1
			spent_gold += pc["gold"]
			spent_wood += pc["wood"]
			spent_iron += pc["iron"]
	
	# Clear army recruitment state after successful recruitment
	army.clear_recruitment_request()  # This clears both recruitment_requested flag and assigned_budget
	
	return {
		"hired": hired,
		"spent_gold": spent_gold,
		"spent_wood": spent_wood,
		"spent_iron": spent_iron,
		"budget_left": budget.to_dict(),
		"recruits_left": recruits_avail
	}

# --- Helpers ---------------------------------------------------------------

func _map_ideal_keys_to_types(raw: Dictionary) -> Dictionary:
	# Map "peasants"/"spearman"/"archers" -> SoldierTypeEnum.Type
	var out: Dictionary = {}
	for k in raw.keys():
		var key: String = str(k).to_lower()
		var pct: float = float(raw[k])
		match key:
			"peasants":
				out[SoldierTypeEnum.Type.PEASANTS] = pct
			"spearman", "spearmen", "spears":
				out[SoldierTypeEnum.Type.SPEARMEN] = pct
			"archers", "archer":
				out[SoldierTypeEnum.Type.ARCHERS] = pct
			_:
				# Unknown label → ignore silently (keeps KISS)
				pass
	return out

func _normalize_ideal(ideal: Dictionary) -> Dictionary:
	# Accept either 0..100 or 0..1; normalize to sum = 1.0
	var sum_vals := 0.0
	for t in ideal.keys():
		sum_vals += float(ideal[t])
	if sum_vals <= 0.0:
		return ideal
	var scale := 1.0 / ((sum_vals / 100.0) if sum_vals > 1.01 else sum_vals)
	var out: Dictionary = {}
	for t in ideal.keys():
		out[t] = float(ideal[t]) * scale
	return out

func _renormalize(m: Dictionary) -> Dictionary:
	var s := 0.0
	for k in m.keys(): s += float(m[k])
	if s <= 0.0: return m
	var out := {}
	for k in m.keys(): out[k] = float(m[k]) / s
	return out

func _get_current_counts(army: Army) -> Dictionary:
	var comp := army.get_composition()
	var out := {}
	for t in SoldierTypeEnum.get_all_types():
		out[t] = comp.get_soldier_count(t)
	return out

func _sum_counts(m: Dictionary) -> int:
	var s := 0
	for t in m.keys(): s += int(m[t])
	return s

func _compute_prop(counts: Dictionary, total: int) -> Dictionary:
	var out := {}
	if total <= 0:
		for t in counts.keys(): out[t] = 0.0
		return out
	for t in counts.keys():
		out[t] = float(counts[t]) / float(total)
	return out

func _compute_gaps(ideal: Dictionary, curr_prop: Dictionary) -> Dictionary:
	var out := {}
	for t in ideal.keys():
		out[t] = float(ideal[t]) - float(curr_prop.get(t, 0.0))
	return out

func _types_from_ideal(ideal: Dictionary) -> Array:
	var arr: Array = []
	for t in ideal.keys(): arr.append(t)
	return arr

func _get_unit_power_map(types: Array) -> Dictionary:
	var out := {}
	for t in types:
		# Prefer GameParameters.get_unit_power(t) if available, else SoldierTypeEnum.get_power(t)
		# Adjust these calls to match your actual API.
		out[t] = GameParameters.get_unit_power(t)
	return out

func _get_unit_costs_map(types: Array) -> Dictionary:
	var out := {}
	for t in types:
		# Adjust these calls to your actual API:
		var gold: int = GameParameters.get_unit_recruit_cost(t)
		var wood: int = GameParameters.get_unit_wood_cost(t)    # 0 for units with no wood
		var iron: int = GameParameters.get_unit_iron_cost(t)    # 0 for units with no iron
		out[t] = { "gold": gold, "wood": wood, "iron": iron }
	return out

func _normalize_power(powers: Dictionary) -> Dictionary:
	var minp: float = 1e9
	var maxp := -1e9
	for t in powers.keys():
		minp = min(minp, float(powers[t]))
		maxp = max(maxp, float(powers[t]))
	var range: float = max(0.001, maxp - minp)
	var out := {}
	for t in powers.keys():
		out[t] = (float(powers[t]) - minp) / range
	return out
