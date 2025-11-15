extends RefCounted
class_name BudgetManager

# Allocate player resources equally among armies at castles that need reinforcement
# Only armies positioned at castles can receive budgets since they can immediately use them
# Assigns budgets directly to armies' assigned_budget field
# Returns number of armies that received budgets
func allocate_recruitment_budgets(all_armies: Array[Army], player: Player, region_manager: RegionManager, turn_number: int = 1, castle_requests: Array = []) -> int:
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
		if army.needs_recruitment(turn_number):
			army.request_recruitment()
			var army_region = army.get_parent() as Region
			if army_region:
				var region_id := army_region.get_region_id()
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
	var ordered_armies: Array[Army] = []
	var army_to_index: Dictionary = {}
	
	for region_id in ordered_region_ids:
		var group: Array = armies_by_castle.get(region_id, [])
		if group.size() > 0:
			group.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
		for army in group:
			army_to_index[army] = ordered_armies.size()
			ordered_armies.append(army)
	
	if ordered_armies.is_empty():
		DebugLogger.log("AIRecruitment", "No armies at castles need recruitment")
	
	var sorted_castle_requests: Array = castle_requests.duplicate()
	if not sorted_castle_requests.is_empty():
		sorted_castle_requests.sort_custom(func(a, b): return int(a.get("region_id", -1)) < int(b.get("region_id", -1)))
	
	var combined_size := ordered_armies.size() + sorted_castle_requests.size()
	if combined_size == 0:
		return 0
	
	var total_gold := player.get_resource_amount(ResourcesEnum.Type.GOLD)
	var total_wood := player.get_resource_amount(ResourcesEnum.Type.WOOD) 
	var total_iron := player.get_resource_amount(ResourcesEnum.Type.IRON)
	
	DebugLogger.log("AIRecruitment", "Player " + str(player.get_player_id()) + " has: " + str(total_gold) + " gold, " + str(total_wood) + " wood, " + str(total_iron) + " iron")
	DebugLogger.log("AIRecruitment", "Allocating resources across " + str(ordered_armies.size()) + " armies and " + str(sorted_castle_requests.size()) + " castle garrisons")
	
	var gold_split := _distribute_equally(total_gold, combined_size)
	var wood_split := _distribute_equally(total_wood, combined_size)
	var iron_split := _distribute_equally(total_iron, combined_size)
	var entry_budgets: Array = []
	for idx in range(combined_size):
		entry_budgets.append(BudgetComposition.new(gold_split[idx], wood_split[idx], iron_split[idx], 0))
	
	var current_index := 0
	for army in ordered_armies:
		army_to_index[army] = current_index
		current_index += 1
	
	for request in sorted_castle_requests:
		request["combined_index"] = current_index
		current_index += 1
	
	# Assign budgets per castle with deterministic recruits split
	for region_id in ordered_region_ids:
		var castle_armies: Array = armies_by_castle.get(region_id, [])
		if castle_armies.size() > 0:
			castle_armies.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
		var castle_garrisons: Array = garrisons_by_castle.get(region_id, [])
		var entry_count := castle_armies.size() + castle_garrisons.size()
		if entry_count == 0:
			continue
		var sources := region_manager.get_available_recruits_from_region_and_neighbors(region_id, player.get_player_id())
		var total_recruits := 0
		for s in sources:
			total_recruits += int(s.amount)
		var recruits_split := _distribute_equally(total_recruits, entry_count)
		var share_index := 0
		
		for local_idx in range(castle_armies.size()):
			var army = castle_armies[local_idx]
			var idx = int(army_to_index[army])
			var budget: BudgetComposition = entry_budgets[idx]
			if share_index < recruits_split.size():
				budget.available_recruits = recruits_split[share_index]
			else:
				budget.available_recruits = 0
			army.assigned_budget = budget
			DebugLogger.log("AIRecruitment", "Assigned budget to army " + army.name + ": " + str(budget.to_dict()))
			share_index += 1
		
		for request in castle_garrisons:
			var budget: BudgetComposition = request.get("assigned_budget", null)
			if budget == null:
				share_index += 1
				continue
			if share_index < recruits_split.size():
				budget.available_recruits = recruits_split[share_index]
			else:
				budget.available_recruits = 0
			request["assigned_budget"] = budget
			DebugLogger.log("AIRecruitment", "Assigned garrison budget for region " + str(region_id) + ": " + str(budget.to_dict()))
			share_index += 1
	
	for request in sorted_castle_requests:
		var idx = int(request.get("combined_index", -1))
		if idx >= 0 and idx < entry_budgets.size():
			request["assigned_budget"] = entry_budgets[idx]
		request.erase("combined_index")
	
	return ordered_armies.size()

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
