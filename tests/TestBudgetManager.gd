extends TestCase

# ============================================================================
# BUDGET MANAGER UNIT TESTS
# ============================================================================
# 
# Purpose: Test the BudgetManager resource allocation system
# 
# Test Coverage:
# - Equal resource splitting across multiple recipients
# - Weighted resource allocation
# - Edge cases (zero weights, zero resources, single recipient)
# - Largest remainder algorithm accuracy
# - Resource conservation (no loss or creation)
# ============================================================================

var budget_manager: BudgetManager

func setup():
	"""Initialize test data before each test"""
	budget_manager = BudgetManager.new()

func teardown():
	"""Clean up after each test"""
	budget_manager = null

# Basic functionality tests
func test_budget_manager_creation():
	"""Test that BudgetManager can be created"""
	assert_not_null(budget_manager, "BudgetManager should be created successfully")

func test_equal_split_two_recipients():
	"""Test splitting resources equally between two recipients"""
	var total = BudgetComposition.new(100, 60, 40)
	var weights = {"army1": 1.0, "army2": 1.0}
	
	var result = budget_manager.split_by_weights(total, weights)
	
	assert_equals(result.size(), 2, "Should have 2 recipients")
	assert_not_null(result.get("army1"), "Army1 should have budget")
	assert_not_null(result.get("army2"), "Army2 should have budget")
	
	var army1_budget = result["army1"] as BudgetComposition
	var army2_budget = result["army2"] as BudgetComposition
	
	# Check gold split (100 / 2 = 50 each)
	assert_equals(army1_budget.gold, 50, "Army1 should get 50 gold")
	assert_equals(army2_budget.gold, 50, "Army2 should get 50 gold")
	
	# Check wood split (60 / 2 = 30 each)  
	assert_equals(army1_budget.wood, 30, "Army1 should get 30 wood")
	assert_equals(army2_budget.wood, 30, "Army2 should get 30 wood")
	
	# Check iron split (40 / 2 = 20 each)
	assert_equals(army1_budget.iron, 20, "Army1 should get 20 iron")
	assert_equals(army2_budget.iron, 20, "Army2 should get 20 iron")

func test_equal_split_three_recipients():
	"""Test splitting resources equally between three recipients"""
	var total = BudgetComposition.new(99, 66, 33)  # Odd numbers for remainder testing
	var weights = {"army1": 1.0, "army2": 1.0, "army3": 1.0}
	
	var result = budget_manager.split_by_weights(total, weights)
	
	assert_equals(result.size(), 3, "Should have 3 recipients")
	
	var army1_budget = result["army1"] as BudgetComposition
	var army2_budget = result["army2"] as BudgetComposition  
	var army3_budget = result["army3"] as BudgetComposition
	
	# Gold: 99/3 = 33 each, remainder 0
	assert_equals(army1_budget.gold, 33, "Army1 should get 33 gold")
	assert_equals(army2_budget.gold, 33, "Army2 should get 33 gold")
	assert_equals(army3_budget.gold, 33, "Army3 should get 33 gold")
	
	# Wood: 66/3 = 22 each, remainder 0
	assert_equals(army1_budget.wood, 22, "Army1 should get 22 wood")
	assert_equals(army2_budget.wood, 22, "Army2 should get 22 wood")
	assert_equals(army3_budget.wood, 22, "Army3 should get 22 wood")
	
	# Iron: 33/3 = 11 each, remainder 0
	assert_equals(army1_budget.iron, 11, "Army1 should get 11 iron")
	assert_equals(army2_budget.iron, 11, "Army2 should get 11 iron")
	assert_equals(army3_budget.iron, 11, "Army3 should get 11 iron")

func test_remainder_distribution():
	"""Test that remainders are distributed correctly using largest remainder method"""
	var total = BudgetComposition.new(10, 10, 10)  # Small amounts with remainders
	var weights = {"army1": 1.0, "army2": 1.0, "army3": 1.0}
	
	var result = budget_manager.split_by_weights(total, weights)
	
	var army1_budget = result["army1"] as BudgetComposition
	var army2_budget = result["army2"] as BudgetComposition
	var army3_budget = result["army3"] as BudgetComposition
	
	# 10/3 = 3.33... -> 3 base + 1 remainder
	# Two armies get 4, one gets 3 (total = 10)
	var gold_total = army1_budget.gold + army2_budget.gold + army3_budget.gold
	var wood_total = army1_budget.wood + army2_budget.wood + army3_budget.wood  
	var iron_total = army1_budget.iron + army2_budget.iron + army3_budget.iron
	
	assert_equals(gold_total, 10, "Total gold should be conserved")
	assert_equals(wood_total, 10, "Total wood should be conserved")
	assert_equals(iron_total, 10, "Total iron should be conserved")
	
	# Each army should get at least 3 of each resource
	assert_true(army1_budget.gold >= 3, "Army1 should get at least 3 gold")
	assert_true(army2_budget.gold >= 3, "Army2 should get at least 3 gold")
	assert_true(army3_budget.gold >= 3, "Army3 should get at least 3 gold")

func test_weighted_distribution():
	"""Test weighted resource allocation (not equal splits)"""
	var total = BudgetComposition.new(120, 90, 60)
	var weights = {"strong_army": 3.0, "weak_army": 1.0}  # 3:1 ratio
	
	var result = budget_manager.split_by_weights(total, weights)
	
	var strong_budget = result["strong_army"] as BudgetComposition
	var weak_budget = result["weak_army"] as BudgetComposition
	
	# Strong army should get 3/4 = 75% of resources
	# Weak army should get 1/4 = 25% of resources
	assert_equals(strong_budget.gold, 90, "Strong army should get 90 gold (75%)")
	assert_equals(weak_budget.gold, 30, "Weak army should get 30 gold (25%)")
	
	assert_equals(strong_budget.wood, 68, "Strong army should get ~68 wood") # 90*3/4 = 67.5 -> 68
	assert_equals(weak_budget.wood, 22, "Weak army should get ~22 wood")   # 90*1/4 = 22.5 -> 22
	
	assert_equals(strong_budget.iron, 45, "Strong army should get 45 iron (75%)")
	assert_equals(weak_budget.iron, 15, "Weak army should get 15 iron (25%)")

func test_single_recipient():
	"""Test allocation to single recipient (should get everything)"""
	var total = BudgetComposition.new(100, 50, 25)
	var weights = {"only_army": 1.0}
	
	var result = budget_manager.split_by_weights(total, weights)
	
	assert_equals(result.size(), 1, "Should have 1 recipient")
	
	var only_budget = result["only_army"] as BudgetComposition
	assert_equals(only_budget.gold, 100, "Should get all gold")
	assert_equals(only_budget.wood, 50, "Should get all wood")
	assert_equals(only_budget.iron, 25, "Should get all iron")

func test_zero_weights_fallback():
	"""Test that zero weights fallback to equal distribution"""
	var total = BudgetComposition.new(60, 40, 20)
	var weights = {"army1": 0.0, "army2": 0.0}  # Both zero
	
	var result = budget_manager.split_by_weights(total, weights)
	
	var army1_budget = result["army1"] as BudgetComposition
	var army2_budget = result["army2"] as BudgetComposition
	
	# Should fallback to equal split (50-50)
	assert_equals(army1_budget.gold, 30, "Army1 should get 30 gold (equal split)")
	assert_equals(army2_budget.gold, 30, "Army2 should get 30 gold (equal split)")

func test_negative_weights_normalized():
	"""Test that negative weights are normalized to zero"""
	var total = BudgetComposition.new(100, 100, 100)
	var weights = {"army1": -5.0, "army2": 2.0}  # Negative weight should become 0
	
	var result = budget_manager.split_by_weights(total, weights)
	
	var army1_budget = result["army1"] as BudgetComposition
	var army2_budget = result["army2"] as BudgetComposition
	
	# Army1 (negative weight -> 0) should get nothing
	# Army2 (positive weight) should get everything
	assert_equals(army1_budget.gold, 0, "Army1 with negative weight should get 0 gold")
	assert_equals(army2_budget.gold, 100, "Army2 should get all gold")

func test_zero_resources():
	"""Test splitting zero resources"""
	var total = BudgetComposition.new(0, 0, 0)
	var weights = {"army1": 1.0, "army2": 1.0}
	
	var result = budget_manager.split_by_weights(total, weights)
	
	var army1_budget = result["army1"] as BudgetComposition
	var army2_budget = result["army2"] as BudgetComposition
	
	assert_equals(army1_budget.gold, 0, "Army1 should get 0 gold")
	assert_equals(army1_budget.wood, 0, "Army1 should get 0 wood")
	assert_equals(army1_budget.iron, 0, "Army1 should get 0 iron")
	
	assert_equals(army2_budget.gold, 0, "Army2 should get 0 gold")
	assert_equals(army2_budget.wood, 0, "Army2 should get 0 wood")
	assert_equals(army2_budget.iron, 0, "Army2 should get 0 iron")

func test_resource_conservation():
	"""Test that no resources are lost or created in the split"""
	var total = BudgetComposition.new(137, 89, 71)  # Random amounts
	var weights = {"army1": 2.3, "army2": 1.7, "army3": 0.9, "army4": 3.1}
	
	var result = budget_manager.split_by_weights(total, weights)
	
	# Sum all allocated resources
	var total_gold = 0
	var total_wood = 0
	var total_iron = 0
	
	for army_key in result.keys():
		var budget = result[army_key] as BudgetComposition
		total_gold += budget.gold
		total_wood += budget.wood
		total_iron += budget.iron
	
	assert_equals(total_gold, 137, "Total gold should be conserved")
	assert_equals(total_wood, 89, "Total wood should be conserved")
	assert_equals(total_iron, 71, "Total iron should be conserved")

func test_mixed_weight_types():
	"""Test with mix of integer and float weights"""
	var total = BudgetComposition.new(100, 100, 100)
	var weights = {"army1": 1, "army2": 2.0, "army3": 1.5}  # int, float, float
	
	var result = budget_manager.split_by_weights(total, weights)
	
	# Weights: 1 + 2.0 + 1.5 = 4.5 total
	# army1: 1/4.5 ≈ 22%, army2: 2.0/4.5 ≈ 44%, army3: 1.5/4.5 ≈ 33%
	
	var army1_budget = result["army1"] as BudgetComposition
	var army2_budget = result["army2"] as BudgetComposition
	var army3_budget = result["army3"] as BudgetComposition
	
	# Verify proportional allocation (approximately)
	assert_true(army2_budget.gold > army3_budget.gold, "Army2 should get more than Army3")
	assert_true(army3_budget.gold > army1_budget.gold, "Army3 should get more than Army1")
	
	# Verify conservation
	var total_allocated = army1_budget.gold + army2_budget.gold + army3_budget.gold
	assert_equals(total_allocated, 100, "All gold should be allocated")

func test_large_remainder_distribution():
	"""Test remainder distribution with larger numbers"""
	var total = BudgetComposition.new(1000, 999, 1001)
	var weights = {"army1": 1.0, "army2": 1.0, "army3": 1.0}  # 3-way equal split
	
	var result = budget_manager.split_by_weights(total, weights)
	
	var army1_budget = result["army1"] as BudgetComposition
	var army2_budget = result["army2"] as BudgetComposition
	var army3_budget = result["army3"] as BudgetComposition
	
	# Verify conservation
	var gold_total = army1_budget.gold + army2_budget.gold + army3_budget.gold
	var wood_total = army1_budget.wood + army2_budget.wood + army3_budget.wood
	var iron_total = army1_budget.iron + army2_budget.iron + army3_budget.iron
	
	assert_equals(gold_total, 1000, "Total gold conserved")
	assert_equals(wood_total, 999, "Total wood conserved")
	assert_equals(iron_total, 1001, "Total iron conserved")
	
	# Each should get approximately 333 of each (with remainder distribution)
	assert_true(abs(army1_budget.gold - 333) <= 1, "Army1 gold within 1 of expected")
	assert_true(abs(army2_budget.gold - 333) <= 1, "Army2 gold within 1 of expected")
	assert_true(abs(army3_budget.gold - 333) <= 1, "Army3 gold within 1 of expected")

# ---------------------------------------------------------------------------
# Allocation to armies at castles (new BudgetManager.allocate_recruitment_budgets)
# ---------------------------------------------------------------------------

func _make_region_with_castle(map_gen: MapGenerator, region_mgr: RegionManager, region_id: int, recruits: int, owner_id: int) -> Region:
	var region := Region.new()
	var data = {"id": region_id, "biome": "grassland", "ocean": false, "center": [0.0, 0.0]}
	region.setup_region(data)
	region.set_castle_type(CastleTypeEnum.Type.OUTPOST)
	region.available_recruits = recruits
	map_gen.region_container_by_id[region_id] = region
	region_mgr.set_initial_region_ownership(region_id, owner_id)
	return region

func _new_player_with_resources(id: int, gold: int, wood: int, iron: int) -> Player:
	var p := Player.new(id, "P" + str(id))
	p.set_resource_amount(ResourcesEnum.Type.GOLD, gold)
	p.set_resource_amount(ResourcesEnum.Type.WOOD, wood)
	p.set_resource_amount(ResourcesEnum.Type.IRON, iron)
	return p

func _new_army_at(region: Region, player_id: int, name: String) -> Army:
	var a := Army.new()
	a.setup_raised_army(player_id, name)
	region.add_child(a)
	return a

func _sorted_int_array(arr: Array[int]) -> Array[int]:
	arr.sort()
	return arr

func _assert_array_equals_int(actual: Array[int], expected: Array[int], msg: String) -> void:
	assert_equals(actual.size(), expected.size(), msg + " (size)")
	for i in range(actual.size()):
		assert_equals(actual[i], expected[i], msg + " [" + str(i) + "]")

func test_allocate_budgets_splits_recruits_equally_per_castle_group() -> void:
	# Setup simple world: one castle region with 3 armies
	var map_gen := MapGenerator.new()
	var region_mgr := RegionManager.new(map_gen)
	var castle := _make_region_with_castle(map_gen, region_mgr, 1001, 30, 1)
	var a1 := _new_army_at(castle, 1, "A1")
	var a2 := _new_army_at(castle, 1, "A2")
	var a3 := _new_army_at(castle, 1, "A3")
	var armies: Array[Army] = [a1, a2, a3]
	var player := _new_player_with_resources(1, 90, 60, 30)
	
	# Allocate budgets
	var assigned := budget_manager.allocate_recruitment_budgets(armies, player, region_mgr, 1)
	assert_equals(assigned, 3, "All 3 armies at castle should get budgets")
	
	# Collect recruit caps and verify multiset = [10,10,10]
	var caps: Array[int] = []
	for a in armies:
		assert_not_null(a.assigned_budget, "Army should have assigned budget")
		caps.append(a.assigned_budget.available_recruits)
	var expected_caps := [10, 10, 10]
	_assert_array_equals_int(_sorted_int_array(caps), _sorted_int_array(expected_caps), "Recruits split equally among castle armies")

func test_allocate_budgets_resources_split_conserved_globally() -> void:
	# Two castles, 4 armies total; resources split globally, recruits per-castle
	var map_gen := MapGenerator.new()
	var region_mgr := RegionManager.new(map_gen)
	var c1 := _make_region_with_castle(map_gen, region_mgr, 2001, 21, 2)
	var c2 := _make_region_with_castle(map_gen, region_mgr, 2002, 11, 2)
	var a1 := _new_army_at(c1, 2, "A1")
	var a2 := _new_army_at(c1, 2, "A2")
	var a3 := _new_army_at(c2, 2, "A3")
	var a4 := _new_army_at(c2, 2, "A4")
	var armies: Array[Army] = [a1, a2, a3, a4]
	var player := _new_player_with_resources(2, 101, 41, 9)
	
	var assigned := budget_manager.allocate_recruitment_budgets(armies, player, region_mgr, 1)
	assert_equals(assigned, 4, "All 4 armies at castles should get budgets")
	
	# Verify resource conservation and equal global split pattern (largest remainder)
	var golds: Array[int] = []
	var woods: Array[int] = []
	var irons: Array[int] = []
	var caps_c1: Array[int] = []
	var caps_c2: Array[int] = []
	for a in armies:
		golds.append(a.assigned_budget.gold)
		woods.append(a.assigned_budget.wood)
		irons.append(a.assigned_budget.iron)
		if a.get_parent() == c1:
			caps_c1.append(a.assigned_budget.available_recruits)
		else:
			caps_c2.append(a.assigned_budget.available_recruits)
	
	assert_equals(golds[0] + golds[1] + golds[2] + golds[3], 101, "Gold conserved across armies")
	assert_equals(woods[0] + woods[1] + woods[2] + woods[3], 41, "Wood conserved across armies")
	assert_equals(irons[0] + irons[1] + irons[2] + irons[3], 9, "Iron conserved across armies")
	
	# Recruits split per castle group: 21 -> [6,5,5,5] pattern -> for 2 armies it's [11,10]; 11 -> [6,5] or [6,5]
	_assert_array_equals_int(_sorted_int_array(caps_c1), _sorted_int_array([10, 11]), "Castle 1 recruits split among its 2 armies")
	_assert_array_equals_int(_sorted_int_array(caps_c2), _sorted_int_array([5, 6]), "Castle 2 recruits split among its 2 armies")

func test_no_budget_for_army_not_at_castle() -> void:
	# One army at non-castle region should not get budget
	var map_gen := MapGenerator.new()
	var region_mgr := RegionManager.new(map_gen)
	var region := Region.new()
	var data = {"id": 3001, "biome": "grassland", "ocean": false, "center": [0.0, 0.0]}
	region.setup_region(data)
	region.set_castle_type(CastleTypeEnum.Type.NONE)
	region.available_recruits = 25
	map_gen.region_container_by_id[3001] = region
	var a := _new_army_at(region, 3, "A")
	var armies: Array[Army] = [a]
	var player := _new_player_with_resources(3, 30, 20, 10)
	
	var assigned := budget_manager.allocate_recruitment_budgets(armies, player, region_mgr, 1)
	assert_equals(assigned, 0, "No budgets assigned when not at castle")
	assert_null(a.assigned_budget, "Army not at castle should have no budget")

func test_zero_recruits_results_in_zero_caps() -> void:
	# Castle with zero recruits -> caps are zero
	var map_gen := MapGenerator.new()
	var region_mgr := RegionManager.new(map_gen)
	var castle := _make_region_with_castle(map_gen, region_mgr, 4001, 0, 4)
	var a1 := _new_army_at(castle, 4, "A1")
	var a2 := _new_army_at(castle, 4, "A2")
	var armies: Array[Army] = [a1, a2]
	var player := _new_player_with_resources(4, 10, 10, 10)
	
	var assigned := budget_manager.allocate_recruitment_budgets(armies, player, region_mgr, 1)
	assert_equals(assigned, 2, "Budgets assigned even if no recruits")
	assert_equals(a1.assigned_budget.available_recruits + a2.assigned_budget.available_recruits, 0, "Zero recruits produce zero caps")
