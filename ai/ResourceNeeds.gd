extends RefCounted
class_name ResourceNeeds

# Computes per-resource need multipliers based on player state.
# KISS: derive from stock, net change per turn (income - use), coverage, and basic quantity floors.

static func compute_needs(player_mgr: PlayerManagerNode, region_mgr: RegionManager, map_gen: MapGenerator, player_id: int) -> Dictionary:
	var needs: Dictionary = {}
	var player := player_mgr.get_player(player_id)
	if player == null:
		return needs

	# Gather stocks
	var stock := {
		ResourcesEnum.Type.FOOD: player.get_resource_amount(ResourcesEnum.Type.FOOD),
		ResourcesEnum.Type.WOOD: player.get_resource_amount(ResourcesEnum.Type.WOOD),
		ResourcesEnum.Type.STONE: player.get_resource_amount(ResourcesEnum.Type.STONE),
		ResourcesEnum.Type.IRON: player.get_resource_amount(ResourcesEnum.Type.IRON),
		ResourcesEnum.Type.GOLD: player.get_resource_amount(ResourcesEnum.Type.GOLD)
	}

	# Estimate per-turn income from owned regions (like PlayerManagerNode)
	var income := {
		ResourcesEnum.Type.FOOD: 0,
		ResourcesEnum.Type.WOOD: 0,
		ResourcesEnum.Type.STONE: 0,
		ResourcesEnum.Type.IRON: 0,
		ResourcesEnum.Type.GOLD: 0
	}
	if region_mgr != null and map_gen != null:
		var owned := region_mgr.get_player_regions(player_id)
		var regions_node = map_gen.get_node_or_null("Regions")
		if regions_node != null:
			for rid in owned:
				var reg = _find_region_by_id(regions_node, rid)
				if reg != null:
					for rt in income.keys():
						if reg.can_collect_resource(rt):
							income[rt] += reg.get_resource_amount(rt)
					# Population-based gold income (approx)
					income[ResourcesEnum.Type.GOLD] += player_mgr._calculate_population_gold_income(reg)

	# Estimate consumption: only food (armies+garrisons)
	var food_use: float = 0.0
	if player_mgr != null:
		food_use = player_mgr.calculate_total_army_food_cost(player_id)

	# Net change per turn
	var net := {
		ResourcesEnum.Type.FOOD: float(income[ResourcesEnum.Type.FOOD]) - food_use,
		ResourcesEnum.Type.WOOD: float(income[ResourcesEnum.Type.WOOD]),
		ResourcesEnum.Type.STONE: float(income[ResourcesEnum.Type.STONE]),
		ResourcesEnum.Type.IRON: float(income[ResourcesEnum.Type.IRON]),
		ResourcesEnum.Type.GOLD: float(income[ResourcesEnum.Type.GOLD])
	}

	# Coverage: stock / max(net, 1) when net > 0; if net <= 0, treat coverage as 0 (critical)
	var coverage := {}
	for rt in net.keys():
		var n: float = float(net[rt])
		if n > 0.0:
			coverage[rt] = float(stock[rt]) / n
		else:
			coverage[rt] = 0.0

	# Build need multipliers per resource
	for rt in stock.keys():
		var mult: float = 1.0
		# 1) Negative growth boost (mainly food)
		if net.get(rt, 0.0) < 0.0:
			mult *= GameParameters.AI_NEED_NEG_GROWTH_MULT
		# 2) Low coverage boost
		if coverage.get(rt, 0.0) > 0.0 and coverage[rt] < GameParameters.AI_NEED_COVERAGE_TARGET:
			mult *= GameParameters.AI_NEED_COVERAGE_MULT
		# 3) Quantity floor boost
		var qty_min: int = int(GameParameters.AI_NEED_MIN_STOCK.get(rt, 0))
		if int(stock[rt]) < int(qty_min):
			mult *= GameParameters.AI_NEED_LOW_STOCK_MULT
		needs[rt] = mult

	return needs

static func _find_region_by_id(regions_node: Node, region_id: int) -> Region:
	for child in regions_node.get_children():
		if child is Region and child.get_region_id() == region_id:
			return child
	return null
