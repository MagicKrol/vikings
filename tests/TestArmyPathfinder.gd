extends TestCase
class_name TestArmyPathfinder

# Minimal stub RegionManager for pathfinding tests (must match expected type)
class FakeRegionManager:
	extends RegionManager
	var neighbors := {}
	var cost_by_region := {}

	func _init(_neighbors: Dictionary, _costs: Dictionary):
		neighbors = _neighbors
		cost_by_region = _costs

	func get_neighbor_regions(region_id: int) -> Array[int]:
		var src = neighbors.get(region_id, [])
		var out: Array[int] = []
		for v in src:
			out.append(int(v))
		return out

	func calculate_terrain_cost(region_id: int, player_id: int) -> int:
		return int(cost_by_region.get(region_id, 1))

var pathfinder: ArmyPathfinder

func setup() -> void:
	# Graph: 1-2-3-4 (line), 2 connected to 5 (branch)
	var neighbors = {
		1: [2],
		2: [1, 3, 5],
		3: [2, 4],
		4: [3],
		5: [2]
	}
	# Enter costs: default 1 unless specified; 99 is impassable (-1)
	var costs = {
		2: 1,
		3: 1,
		4: 1,
		5: 2,
		99: -1
	}
	var rm = FakeRegionManager.new(neighbors, costs)
	pathfinder = ArmyPathfinder.new(rm, null)

func test_find_path_simple() -> void:
	# From 1 to 3, expect [1,2,3], cost 2
	var result = pathfinder.find_path_to_target(1, 3, 1)
	assert_true(result.success, "Path should be found")
	assert_equals(result.path, [1, 2, 3], "Path sequence should be 1-2-3")
	assert_equals(result.cost, 2, "Cost should be sum of enter costs (1 + 1)")

func test_find_path_unreachable_due_to_impassable() -> void:
	# Make region 2 impassable dynamically by overriding cost map
	var rm = pathfinder.region_manager
	rm.cost_by_region[2] = -1
	var bad = pathfinder.find_path_to_target(1, 3, 1)
	assert_false(bad.success, "Path should be unreachable through impassable region")

func test_calculate_path_cost() -> void:
	# Reset cost for 2 to 2, 3 to 3 → total 5
	var rm = pathfinder.region_manager
	rm.cost_by_region[2] = 2
	rm.cost_by_region[3] = 3
	var cost = pathfinder.calculate_path_cost([1, 2, 3], 1)
	assert_equals(cost, 5, "Sum of enter costs should be 5 (2 + 3)")

func test_trim_path_to_mp_limit() -> void:
	# Path 1-2-3-4 where entering 2=2, 3=2, 4=2; limit=3 → [1,2]
	var rm = pathfinder.region_manager
	rm.cost_by_region[2] = 2
	rm.cost_by_region[3] = 2
	rm.cost_by_region[4] = 2
	var trimmed = pathfinder.trim_path_to_mp_limit([1, 2, 3, 4], 1, 3)
	assert_equals(trimmed, [1, 2], "Trim to first step only within MP limit")
