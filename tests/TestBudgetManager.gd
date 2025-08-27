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