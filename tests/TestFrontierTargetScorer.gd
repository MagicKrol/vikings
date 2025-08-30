extends TestCase
class_name TestFrontierTargetScorer

# Lightweight stubs
class FakeRegionManager:
	extends RegionManager
	var owned := {}
	var neighbors := {}

	func _init(_owned: Dictionary, _neighbors: Dictionary):
		owned = _owned
		neighbors = _neighbors

	func get_player_regions(player_id: int) -> Array[int]:
		var res: Array[int] = []
		for rid in owned.keys():
			if int(owned[rid]) == player_id:
				res.append(int(rid))
		return res

	func get_neighbor_regions(region_id: int) -> Array[int]:
		var src = neighbors.get(region_id, [])
		var out: Array[int] = []
		for v in src:
			out.append(int(v))
		return out

	func get_region_owner(region_id: int) -> int:
		return int(owned.get(region_id, -1))

class FakeMapGenerator:
	extends MapGenerator
	var fake_regions: Dictionary = {}

	func _init(_regions: Dictionary):
		fake_regions = _regions

	func get_region_container_by_id(region_id: int):
		return fake_regions.get(region_id, null)

# Helpers to construct real Region nodes for type checks
static func _make_region(id: int, name: String, pop: int, level: int, rtype: int, res: Dictionary) -> Region:
	var reg: Region = Region.new()
	reg.region_id = id
	reg.region_name = name
	reg.population = pop
	match level:
		1: reg.region_level = RegionLevelEnum.Level.L1
		2: reg.region_level = RegionLevelEnum.Level.L2
		3: reg.region_level = RegionLevelEnum.Level.L3
		4: reg.region_level = RegionLevelEnum.Level.L4
		5: reg.region_level = RegionLevelEnum.Level.L5
	reg.region_type = rtype
	reg.is_ocean = false
	var rc := ResourceComposition.new()
	for k in res.keys():
		rc.set_resource_amount(k, int(res[k]))
	reg.resources = rc
	return reg

var scorer: FrontierTargetScorer

func setup() -> void:
	# Ownership: 1 owned by P1; 4 owned by P1; 3 owned by enemy (2); 2 neutral; 5 neutral (mountain)
	var owned = {1: 1, 4: 1, 3: 2, 2: -1, 5: -1}
	var neighbors = {1: [2, 3, 4, 5]}
	var rm = FakeRegionManager.new(owned, neighbors)

	# Regions
	var r2 = _make_region(2, "R2", 350, 3, RegionTypeEnum.Type.GRASSLAND, {
		ResourcesEnum.Type.FOOD: 20,
		ResourcesEnum.Type.WOOD: 20,
		ResourcesEnum.Type.STONE: 20,
		ResourcesEnum.Type.IRON: 20,
		ResourcesEnum.Type.GOLD: 20,
	})
	var r3 = _make_region(3, "R3", 220, 2, RegionTypeEnum.Type.GRASSLAND, {
		ResourcesEnum.Type.FOOD: 5,
		ResourcesEnum.Type.WOOD: 5,
		ResourcesEnum.Type.STONE: 5,
		ResourcesEnum.Type.IRON: 5,
		ResourcesEnum.Type.GOLD: 5,
	})
	var r4 = _make_region(4, "R4", 300, 2, RegionTypeEnum.Type.GRASSLAND, {})
	var r5 = _make_region(5, "R5", 300, 2, RegionTypeEnum.Type.MOUNTAINS, {})
	var regions = {2: r2, 3: r3, 4: r4, 5: r5}
	var mg = FakeMapGenerator.new(regions)

	scorer = FrontierTargetScorer.new(rm, mg)

func test_get_frontier_targets_filters_owned_and_impassable() -> void:
	# From region 1 (owned by P1), neighbors are 2 (neutral), 3 (enemy), 4 (owned), 5 (mountain)
	var targets: Array[int] = scorer.get_frontier_targets(1)
	# Expect 2 and 3 only
	assert_true(targets.size() == 2, "Should only include neutral+enemy reachable targets")
	assert_true(2 in targets and 3 in targets, "Targets should include 2 and 3")
	assert_false(4 in targets, "Owned neighbor should be excluded")
	assert_false(5 in targets, "Impassable (mountain) should be excluded")

func test_score_frontier_targets_orders_by_value() -> void:
	var scored = scorer.score_frontier_targets(1)
	# Should include 2 entries (2 and 3), ordered by base_score desc
	assert_equals(scored.size(), 2, "Two frontier targets should be scored")
	var first = scored[0]
	var second = scored[1]
	# R2 was set with high pop/resources/level; despite neutral ownership (0.8), should outrank R3 (enemy=1.0) due to much higher value
	assert_equals(first.region_id, 2, "Region 2 should be the top scored target")
	assert_equals(second.region_id, 3, "Region 3 should be second")
	assert_true(first.base_score >= second.base_score, "Top score should be >= next")
