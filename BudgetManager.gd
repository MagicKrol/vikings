extends RefCounted
class_name BudgetManager

# Allocate player resources equally among armies at castles that need reinforcement
# Only armies positioned at castles can receive budgets since they can immediately use them
# Assigns budgets directly to armies' assigned_budget field
# Returns number of armies that received budgets
func allocate_recruitment_budgets(all_armies: Array[Army], player: Player, region_manager: RegionManager, turn_number: int = 1) -> int:
	if all_armies.is_empty():
		print("[BudgetManager] No armies provided")
		return 0
	
	if not player:
		print("[BudgetManager] Error: No player provided")
		return 0
		
	if not region_manager:
		print("[BudgetManager] Error: No region manager provided")
		return 0
	
	# Check which armies need reinforcement AND are at castles
	var armies_needing_recruitment: Array[Army] = []
	for army in all_armies:
		if army.needs_recruitment(turn_number):
			army.request_recruitment()
			# Check if army is positioned at a castle
			var army_region = army.get_parent() as Region
			if army_region:
				var region_id := army_region.get_region_id()
				var castle_level := region_manager.get_castle_level(region_id)
				if castle_level >= 1:
					# Request recruitment and add to list for budget allocation
					armies_needing_recruitment.append(army)
					print("[BudgetManager] Army ", army.name, " at castle (level ", castle_level, ") flagged for recruitment")
				else:
					# Army needs recruitment but not at castle - still flag for movement toward castle
					print("[BudgetManager] Army ", army.name, " needs recruitment but not at castle - flagged but no budget allocated")
	
	if armies_needing_recruitment.is_empty():
		print("[BudgetManager] No armies at castles need recruitment")
		return 0
	
	# Get available resources from player (gold, wood, iron only - used for recruitment)
	var total_gold := player.get_resource_amount(ResourcesEnum.Type.GOLD)
	var total_wood := player.get_resource_amount(ResourcesEnum.Type.WOOD) 
	var total_iron := player.get_resource_amount(ResourcesEnum.Type.IRON)
	
	print("[BudgetManager] Player ", player.get_player_id(), " has: ", total_gold, " gold, ", total_wood, " wood, ", total_iron, " iron")
	print("[BudgetManager] Allocating resources to ", armies_needing_recruitment.size(), " armies that need reinforcement")
	
	# Split equally among all armies needing recruitment
	var num_armies := armies_needing_recruitment.size()
	var gold_per_army := _distribute_equally(total_gold, num_armies)
	var wood_per_army := _distribute_equally(total_wood, num_armies)  
	var iron_per_army := _distribute_equally(total_iron, num_armies)
	
	# Assign budgets directly to each army
	for i in range(armies_needing_recruitment.size()):
		var army = armies_needing_recruitment[i]
		var budget = BudgetComposition.new(
			gold_per_army[i],
			wood_per_army[i], 
			iron_per_army[i]
		)
		army.assigned_budget = budget
		print("[BudgetManager] Assigned budget to army ", army.name, ": ", budget.to_dict())
	
	return armies_needing_recruitment.size()

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
