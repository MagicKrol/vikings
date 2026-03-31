extends RefCounted
class_name BudgetManager

# Allocate player resources equally among armies at castles that need reinforcement
# Only armies positioned at castles can receive budgets since they can immediately use them
# Assigns budgets directly to armies' assigned_budget field
# Returns number of armies that received budgets
func allocate_recruitment_budgets(all_armies: Array[Army], player: Player, region_manager: RegionManager, turn_number: int = 1, castle_requests: Array = [], resource_caps: Dictionary = {}) -> int:
	if all_armies.is_empty() and castle_requests.is_empty():
		DebugLogger.log("AIRecruitment", "No armies or castles require recruitment budgets")
		return 0
	
	if not player:
		DebugLogger.log("AIRecruitment", "Error: No player provided")
		return 0
		
	if not region_manager:
		DebugLogger.log("AIRecruitment", "Error: No region manager provided")
		return 0
	
	# Group armies by castle region for recruit quota distribution
	var armies_by_castle: Dictionary = {}  # region_id -> Array[Army]
	var garrisons_by_castle: Dictionary = {}  # region_id -> Array[Dictionary]
	
	for army in all_armies:
		var needs_recruitment: bool = army.needs_recruitment(turn_number) or army.is_recruitment_requested()
		if not needs_recruitment:
			continue
		army.request_recruitment()
		var army_region = army.get_parent() as Region
		if army_region:
			var region_id := army_region.get_region_id()
			var region_owner: int = region_manager.get_region_owner(region_id)
			if region_owner != player.get_player_id():
				continue
			var castle_level := region_manager.get_castle_level(region_id)
			if castle_level >= 1:
				if not armies_by_castle.has(region_id):
					armies_by_castle[region_id] = []
				armies_by_castle[region_id].append(army)
				DebugLogger.log("AIRecruitment", "Army " + army.name + " at castle (level " + str(castle_level) + ") flagged for recruitment")
			else:
				DebugLogger.log("AIRecruitment", "Army " + army.name + " needs recruitment but not at castle - flagged but no budget allocated")
	
	for request in castle_requests:
		var region_id := int(request.get("region_id", -1))
		if region_id < 0:
			continue
		if not garrisons_by_castle.has(region_id):
			garrisons_by_castle[region_id] = []
		garrisons_by_castle[region_id].append(request)
	
	var combined_region_ids: Dictionary = {}
	for region_id in armies_by_castle.keys():
		combined_region_ids[region_id] = true
	for region_id in garrisons_by_castle.keys():
		combined_region_ids[region_id] = true
	
	var ordered_region_ids: Array = combined_region_ids.keys()
	ordered_region_ids.sort()
	var combined_entries: Array[Dictionary] = []
	var army_entries_assigned: int = 0
	for region_id in ordered_region_ids:
		var castle_armies: Array = armies_by_castle.get(region_id, [])
		if castle_armies.size() > 0:
			castle_armies.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
		for army in castle_armies:
			combined_entries.append({
				"kind": "army",
				"region_id": int(region_id),
				"army": army,
				"weight": 1.0
			})
		var castle_garrisons: Array = garrisons_by_castle.get(region_id, [])
		for request in castle_garrisons:
			var request_weight: float = max(0.0, float(request.get("weight", 1.0)))
			if request_weight <= 0.0:
				request_weight = 1.0
			combined_entries.append({
				"kind": "castle",
				"region_id": int(region_id),
				"request": request,
				"weight": request_weight
			})

	if combined_entries.is_empty():
		DebugLogger.log("AIRecruitment", "No armies at castles need recruitment")
		return 0
	
	var total_gold := int(resource_caps.get(ResourcesEnum.Type.GOLD, player.get_resource_amount(ResourcesEnum.Type.GOLD)))
	var total_wood := int(resource_caps.get(ResourcesEnum.Type.WOOD, player.get_resource_amount(ResourcesEnum.Type.WOOD)))
	var total_iron := int(resource_caps.get(ResourcesEnum.Type.IRON, player.get_resource_amount(ResourcesEnum.Type.IRON)))
	var combined_size: int = combined_entries.size()
	
	DebugLogger.log("AIRecruitment", "Player " + str(player.get_player_id()) + " has: " + str(total_gold) + " gold, " + str(total_wood) + " wood, " + str(total_iron) + " iron")
	var army_entry_count: int = 0
	var castle_entry_count: int = 0
	for entry in combined_entries:
		var entry_kind: String = String(entry.get("kind", ""))
		if entry_kind == "army":
			army_entry_count += 1
		else:
			castle_entry_count += 1
	DebugLogger.log("AIRecruitment", "Allocating resources across " + str(army_entry_count) + " armies and " + str(castle_entry_count) + " castle garrisons")

	var weighted_entries: Dictionary = {}
	for idx in range(combined_size):
		var entry_weight: float = max(0.0, float(combined_entries[idx].get("weight", 1.0)))
		if entry_weight <= 0.0:
			entry_weight = 1.0
		weighted_entries[idx] = entry_weight

	var gold_split: Dictionary = _split_weighted_int(total_gold, weighted_entries)
	var wood_split: Dictionary = _split_weighted_int(total_wood, weighted_entries)
	var iron_split: Dictionary = _split_weighted_int(total_iron, weighted_entries)
	var entry_budgets: Array = []
	for idx in range(combined_size):
		entry_budgets.append(BudgetComposition.new(
			int(gold_split.get(idx, 0)),
			int(wood_split.get(idx, 0)),
			int(iron_split.get(idx, 0)),
			0
		))

	for idx in range(combined_entries.size()):
		var entry: Dictionary = combined_entries[idx]
		var budget: BudgetComposition = entry_budgets[idx]
		var entry_kind: String = String(entry.get("kind", ""))
		if entry_kind == "army":
			var entry_army: Army = entry.get("army", null)
			entry_army.assigned_budget = budget
			army_entries_assigned += 1
			DebugLogger.log("AIRecruitment", "Assigned budget to army " + entry_army.name + ": " + str(budget.to_dict()))
		else:
			var entry_request: Dictionary = entry.get("request", {})
			entry_request["assigned_budget"] = budget
			DebugLogger.log("AIRecruitment", "Assigned garrison budget for region " + str(int(entry.get("region_id", -1))) + ": " + str(budget.to_dict()))

	var entry_indices_by_region: Dictionary = {}
	for idx in range(combined_entries.size()):
		var entry_region_id: int = int(combined_entries[idx].get("region_id", -1))
		if not entry_indices_by_region.has(entry_region_id):
			entry_indices_by_region[entry_region_id] = []
		var region_indices: Array = entry_indices_by_region.get(entry_region_id, [])
		region_indices.append(idx)
		entry_indices_by_region[entry_region_id] = region_indices

	# Assign recruit caps per castle with deterministic split across all entries tied to that castle
	for region_id in ordered_region_ids:
		var region_entry_indices: Array = entry_indices_by_region.get(region_id, [])
		var entry_count: int = region_entry_indices.size()
		if entry_count == 0:
			continue
		var sources := region_manager.get_available_recruits_from_region_and_neighbors(region_id, player.get_player_id())
		var total_recruits: int = 0
		for s in sources:
			total_recruits += int(s.amount)
		var recruits_split: Array[int] = _distribute_equally(total_recruits, entry_count)
		for local_idx in range(region_entry_indices.size()):
			var idx: int = int(region_entry_indices[local_idx])
			var budget: BudgetComposition = entry_budgets[idx]
			if local_idx < recruits_split.size():
				budget.available_recruits = recruits_split[local_idx]
			else:
				budget.available_recruits = 0
			var entry: Dictionary = combined_entries[idx]
			var entry_kind: String = String(entry.get("kind", ""))
			if entry_kind == "army":
				var entry_army: Army = entry.get("army", null)
				entry_army.assigned_budget = budget
			else:
				var entry_request: Dictionary = entry.get("request", {})
				entry_request["assigned_budget"] = budget

	return army_entries_assigned

# Distribute an amount equally among recipients using largest remainder method
func _distribute_equally(total_amount: int, num_recipients: int) -> Array[int]:
	if num_recipients <= 0:
		return []
	
	if total_amount <= 0:
		var result: Array[int] = []
		for i in range(num_recipients):
			result.append(0)
		return result
	
	# Base amount each recipient gets
	var base_amount := total_amount / num_recipients
	var remainder := total_amount % num_recipients
	
	var result: Array[int] = []
	for i in range(num_recipients):
		if i < remainder:
			result.append(base_amount + 1)  # First 'remainder' recipients get +1
		else:
			result.append(base_amount)      # Rest get base amount
	
	return result

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

# Legacy method for backwards compatibility with existing tests
# Split a total budget across "keys" (e.g., armies) proportionally to weights.
# Returns Dictionary { key: BudgetComposition }
func split_by_weights(total: BudgetComposition, weights: Dictionary) -> Dictionary:
	# Normalize weights (>=0)
	var norm := {}
	var sumw := 0.0
	for k in weights.keys():
		var w: float = max(0.0, float(weights[k]))
		norm[k] = w
		sumw += w
	if sumw <= 0.0:
		# Handle zero weights case
		var keys := weights.keys()
		if keys.is_empty():
			return {}  # No keys to distribute to
		# Even split if all weights are zero
		var even := {}
		for k in keys:
			even[k] = 1.0
		return split_by_weights(total, even)
	
	# Split each resource independently
	var gold_map := _split_scalar(total.gold, norm, sumw)
	var wood_map := _split_scalar(total.wood, norm, sumw)
	var iron_map := _split_scalar(total.iron, norm, sumw)
	
	var out := {}
	for k in weights.keys():
		out[k] = BudgetComposition.new(int(gold_map.get(k, 0)), int(wood_map.get(k, 0)), int(iron_map.get(k, 0)))
	return out

# Helper to split one scalar using largest remainder (legacy method)
func _split_scalar(total_val: int, weights: Dictionary, sum_weights: float) -> Dictionary:
	var base := {}
	var rema := []
	var taken := 0
	for k in weights.keys():
		var share := float(total_val) * float(weights[k]) / sum_weights
		var floor_share := int(floor(share))
		base[k] = floor_share
		taken += floor_share
		rema.append({"k": k, "frac": share - float(floor_share)})
	var rem := total_val - taken
	rema.sort_custom(func(a, b): return a["frac"] > b["frac"])
	var idx := 0
	while rem > 0 and idx < rema.size():
		var key = rema[idx]["k"]
		base[key] = int(base[key]) + 1
		rem -= 1
		idx += 1
		if idx == rema.size() and rem > 0:
			idx = 0
	return base
