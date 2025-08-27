
extends RefCounted
class_name BudgetManager

# Split a total budget across "keys" (e.g., armies) proportionally to weights.
# Returns Dictionary { key: BudgetComposition }
func split_by_weights(total: BudgetComposition, weights: Dictionary) -> Dictionary:
	# Normalize weights (>=0)
	var norm := {}
	var sumw := 0.0
	for k in weights.keys():
		var w := max(0.0, float(weights[k]))
		norm[k] = w
		sumw += w
	if sumw <= 0.0:
		# Even split if all weights are zero
		var even := {}
		var keys := weights.keys()
		for k in keys:
			even[k] = 1.0
		return split_by_weights(total, even)
	
	# Helper to split one scalar using largest remainder
	func _split_scalar(total_val: int, w: Dictionary) -> Dictionary:
		var base := {}
		var rema := []
		var taken := 0
		for k in w.keys():
			var share := float(total_val) * float(w[k]) / sumw
			var floor_share := int(floor(share))
			base[k] = floor_share
			taken += floor_share
			rema.append({"k": k, "frac": share - float(floor_share)})
		var rem := total_val - taken
		rema.sort_custom(func(a, b): return a["frac"] > b["frac"])
		var idx := 0
		while rem > 0 and idx < rema.size():
			var key := rema[idx]["k"]
			base[key] = int(base[key]) + 1
			rem -= 1
			idx += 1
			if idx == rema.size() and rem > 0:
				idx = 0
		return base
	
	# Split each resource independently
	var gold_map := _split_scalar(total.gold, norm)
	var wood_map := _split_scalar(total.wood, norm)
	var iron_map := _split_scalar(total.iron, norm)
	
	var out := {}
	for k in weights.keys():
		out[k] = BudgetComposition.new(int(gold_map.get(k, 0)), int(wood_map.get(k, 0)), int(iron_map.get(k, 0)))
	return out
