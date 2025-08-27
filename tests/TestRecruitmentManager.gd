extends TestCase
class_name TestRecruitmentManager

# ============================================================================
# RECRUITMENT MANAGER TEST CLASS
# ============================================================================
# 
# Purpose: Test RecruitmentManager functionality with BudgetComposition integration
# 
# This test class verifies:
# - RecruitmentManager correctly uses BudgetComposition for resource management
# - Army composition matches ideal composition for "game_start" scenario
# - Proper integration between Army, Region, and RecruitmentManager
# - Resource spending and budget tracking works correctly
# ============================================================================

var recruitment_manager: RecruitmentManager
var test_army: Army
var test_region: Region
var unlimited_budget: BudgetComposition

## Test Setup and Teardown

func setup() -> void:
	"""Set up test objects before each test"""
	# Create RecruitmentManager instance
	recruitment_manager = RecruitmentManager.new()
	
	# Create test army with empty composition
	test_army = Army.new()
	test_army.setup_raised_army(1, "Test")  # Empty army, no default soldiers
	
	# Create test region with unlimited recruits
	test_region = Region.new()
	_setup_test_region()
	
	# Add army to region (parent-child relationship)
	test_region.add_child(test_army)
	
	# Create unlimited budget (9999 of each resource)
	unlimited_budget = BudgetComposition.new(9999, 9999, 9999)

func teardown() -> void:
	"""Clean up after each test"""
	if test_army and is_instance_valid(test_army):
		test_army.queue_free()
	if test_region and is_instance_valid(test_region):
		test_region.queue_free()
	recruitment_manager = null
	unlimited_budget = null

## Helper Methods

func _setup_test_region() -> void:
	"""Configure test region with unlimited recruits"""
	# Set up basic region data
	var region_data = {
		"id": 999,
		"biome": "grassland",
		"ocean": false,
		"center": [100.0, 100.0]
	}
	test_region.setup_region(region_data)
	test_region.set_region_name("Test Region")
	
	# Set unlimited recruits (9999 should be more than enough)
	test_region.available_recruits = 100
	test_region.population = 10000  # Large population to support recruitment

func _get_ideal_composition_percentages() -> Dictionary:
	"""Get the ideal composition percentages for game_start"""
	var ideal_raw = GameParameters.get_ideal_composition("game_start")
	assert_not_null(ideal_raw, "Game start composition should exist")
	return ideal_raw

func _normalize_composition_to_percentages(composition: Dictionary, total: int) -> Dictionary:
	"""Convert army composition counts to percentages"""
	var percentages = {}
	if total == 0:
		return percentages
	
	for type in composition:
		var count = composition[type]
		percentages[type] = (float(count) / float(total)) * 100.0
	
	return percentages

func _get_army_composition_counts() -> Dictionary:
	"""Get current army composition as count dictionary"""
	var composition = {}
	composition["peasants"] = test_army.get_soldier_count(SoldierTypeEnum.Type.PEASANTS)
	composition["spearmen"] = test_army.get_soldier_count(SoldierTypeEnum.Type.SPEARMEN) 
	composition["archers"] = test_army.get_soldier_count(SoldierTypeEnum.Type.ARCHERS)
	return composition

## Core Functionality Tests

func test_recruitment_manager_exists() -> void:
	"""Test that RecruitmentManager can be instantiated"""
	assert_not_null(recruitment_manager, "RecruitmentManager should be created")
	assert_true(recruitment_manager.has_method("hire_soldiers"), "Should have hire_soldiers method")

func test_budget_composition_integration() -> void:
	"""Test that RecruitmentManager properly uses BudgetComposition"""
	# Verify budget has unlimited resources
	assert_equals(unlimited_budget.gold, 9999, "Should have unlimited gold")
	assert_equals(unlimited_budget.wood, 9999, "Should have unlimited wood") 
	assert_equals(unlimited_budget.iron, 9999, "Should have unlimited iron")
	
	# Test affordability checks
	var expensive_cost = {"gold": 100, "wood": 50, "iron": 25}
	assert_true(unlimited_budget.can_afford(expensive_cost), "Unlimited budget should afford expensive items")

func test_army_starts_empty() -> void:
	"""Test that test army starts with no soldiers"""
	var total_soldiers = test_army.get_total_soldiers()
	assert_equals(total_soldiers, 0, "Army should start empty")
	
	assert_equals(test_army.get_soldier_count(SoldierTypeEnum.Type.PEASANTS), 0, "Should have 0 peasants")
	assert_equals(test_army.get_soldier_count(SoldierTypeEnum.Type.SPEARMEN), 0, "Should have 0 spearmen")
	assert_equals(test_army.get_soldier_count(SoldierTypeEnum.Type.ARCHERS), 0, "Should have 0 archers")

func test_region_has_unlimited_recruits() -> void:
	"""Test that test region has enough recruits"""
	var available_recruits = test_region.get_available_recruits()
	assert_true(available_recruits >= 100, "Region should have plenty of recruits: " + str(available_recruits))

## Main Test: Ideal Composition Matching

func test_game_start_composition_with_unlimited_resources() -> void:
	"""
	MAIN TEST: Verify RecruitmentManager produces ideal army composition for game_start
	with unlimited resources and recruits
	"""
	# Get expected ideal composition percentages
	var ideal_percentages = _get_ideal_composition_percentages()
	
	# Verify we have the expected unit types in ideal composition
	assert_true(ideal_percentages.has("peasants"), "Ideal composition should include peasants")
	assert_true(ideal_percentages.has("spearmen"), "Ideal composition should include spearmen")  
	assert_true(ideal_percentages.has("archers"), "Ideal composition should include archers")
	
	# Verify percentages are reasonable (should sum to 100)
	var total_percentage = ideal_percentages.peasants + ideal_percentages.spearmen + ideal_percentages.archers
	assert_true(abs(total_percentage - 100.0) < 1.0, "Ideal percentages should sum to ~100: " + str(total_percentage))
	
	# Run recruitment with unlimited resources
	var result = recruitment_manager.hire_soldiers(test_army, "game_start", unlimited_budget)
	
	# Verify recruitment was successful
	assert_not_null(result, "Recruitment should return a result")
	assert_true(result.has("hired"), "Result should contain hired units")
	assert_true(result.has("spent_gold"), "Result should track gold spending")
	
	# Verify army now has soldiers
	var total_recruited = test_army.get_total_soldiers()
	assert_true(total_recruited > 0, "Army should have recruited soldiers: " + str(total_recruited))
	
	# Get actual composition
	var actual_counts = _get_army_composition_counts()
	var actual_percentages = _normalize_composition_to_percentages(actual_counts, total_recruited)
	
	# Verify composition matches ideal (within tolerance)
	var tolerance = 5.0  # Allow 5% tolerance for rounding effects
	
	var peasant_diff = abs(actual_percentages.peasants - ideal_percentages.peasants)
	var spearmen_diff = abs(actual_percentages.spearmen - ideal_percentages.spearmen)
	var archers_diff = abs(actual_percentages.archers - ideal_percentages.archers)
	
	print("Expected vs Actual Composition:")
	print("  Peasants: %.1f%% vs %.1f%% (diff: %.1f%%)" % [ideal_percentages.peasants, actual_percentages.peasants, peasant_diff])
	print("  Spearmen: %.1f%% vs %.1f%% (diff: %.1f%%)" % [ideal_percentages.spearmen, actual_percentages.spearmen, spearmen_diff])
	print("  Archers: %.1f%% vs %.1f%% (diff: %.1f%%)" % [ideal_percentages.archers, actual_percentages.archers, archers_diff])
	print("  Total recruited: %d soldiers" % total_recruited)
	
	assert_true(peasant_diff <= tolerance, "Peasant percentage should match ideal within " + str(tolerance) + "% (diff: " + str(peasant_diff) + "%)")
	assert_true(spearmen_diff <= tolerance, "Spearmen percentage should match ideal within " + str(tolerance) + "% (diff: " + str(spearmen_diff) + "%)")
	assert_true(archers_diff <= tolerance, "Archers percentage should match ideal within " + str(tolerance) + "% (diff: " + str(archers_diff) + "%)")

## Resource Management Tests

func test_budget_spending_tracking() -> void:
	"""Test that budget spending is properly tracked"""
	var initial_gold = unlimited_budget.gold
	var initial_wood = unlimited_budget.wood
	var initial_iron = unlimited_budget.iron
	
	# Run recruitment
	var result = recruitment_manager.hire_soldiers(test_army, "game_start", unlimited_budget)
	
	# Verify resources were spent
	var gold_spent = initial_gold - unlimited_budget.gold
	var wood_spent = initial_wood - unlimited_budget.wood
	var iron_spent = initial_iron - unlimited_budget.iron
	
	assert_true(gold_spent > 0, "Should have spent some gold: " + str(gold_spent))
	assert_equals(gold_spent, result.spent_gold, "Spent gold should match result")
	assert_equals(wood_spent, result.spent_wood, "Spent wood should match result")
	assert_equals(iron_spent, result.spent_iron, "Spent iron should match result")

func test_budget_remaining_tracking() -> void:
	"""Test that remaining budget is properly tracked"""
	var result = recruitment_manager.hire_soldiers(test_army, "game_start", unlimited_budget)
	
	# Verify budget_left is returned
	assert_true(result.has("budget_left"), "Result should include budget_left")
	assert_true(result.budget_left.has("gold"), "Budget left should include gold")
	assert_true(result.budget_left.has("wood"), "Budget left should include wood")
	assert_true(result.budget_left.has("iron"), "Budget left should include iron")
	
	# Verify remaining budget matches actual budget
	assert_equals(result.budget_left.gold, unlimited_budget.gold, "Remaining gold should match budget")
	assert_equals(result.budget_left.wood, unlimited_budget.wood, "Remaining wood should match budget")
	assert_equals(result.budget_left.iron, unlimited_budget.iron, "Remaining iron should match budget")

## Edge Case Tests

func test_recruitment_with_limited_recruits() -> void:
	"""Test recruitment behavior when recruits are limited"""
	# Set limited recruits
	test_region.available_recruits = 10
	
	var result = recruitment_manager.hire_soldiers(test_army, "game_start", unlimited_budget)
	
	# Should recruit exactly 10 soldiers
	var total_recruited = test_army.get_total_soldiers()
	assert_equals(total_recruited, 10, "Should recruit exactly the available recruits")
	assert_equals(result.recruits_left, 0, "Should have no recruits left")

func test_recruitment_with_zero_budget() -> void:
	"""Test recruitment behavior with no resources"""
	var zero_budget = BudgetComposition.new(0, 0, 0)
	
	var result = recruitment_manager.hire_soldiers(test_army, "game_start", zero_budget)
	
	# Should recruit only peasants (they are free)
	var total_recruited = test_army.get_total_soldiers()
	var peasant_count = test_army.get_soldier_count(SoldierTypeEnum.Type.PEASANTS)
	var spearmen_count = test_army.get_soldier_count(SoldierTypeEnum.Type.SPEARMEN)
	var archer_count = test_army.get_soldier_count(SoldierTypeEnum.Type.ARCHERS)
	
	assert_true(total_recruited > 0, "Should recruit peasants with zero budget (peasants are free)")
	assert_equals(peasant_count, total_recruited, "Should recruit only peasants with zero budget")
	assert_equals(spearmen_count, 0, "Should recruit no spearmen with zero budget")
	assert_equals(archer_count, 0, "Should recruit no archers with zero budget")
	assert_equals(result.spent_gold, 0, "Should spend no gold")

## Integration Tests

func test_army_composition_integration() -> void:
	"""Test that army composition is properly updated"""
	# Recruit soldiers
	recruitment_manager.hire_soldiers(test_army, "game_start", unlimited_budget)
	
	# Verify composition object reflects changes
	var composition = test_army.get_composition()
	assert_not_null(composition, "Army should have composition object")
	
	var total_from_composition = composition.get_total_soldiers()
	var total_from_army = test_army.get_total_soldiers()
	
	assert_equals(total_from_composition, total_from_army, "Composition and army totals should match")

func test_multiple_recruitment_calls() -> void:
	"""Test that multiple recruitment calls work correctly"""
	# First recruitment
	var result1 = recruitment_manager.hire_soldiers(test_army, "game_start", unlimited_budget)
	var soldiers_after_first = test_army.get_total_soldiers()
	
	# Second recruitment (should add to existing army)
	var result2 = recruitment_manager.hire_soldiers(test_army, "game_start", unlimited_budget)
	var soldiers_after_second = test_army.get_total_soldiers()
	
	assert_true(soldiers_after_second > soldiers_after_first, "Second recruitment should add more soldiers")
	assert_true(result2.spent_gold > 0, "Second recruitment should spend resources")

## Validation Tests

func test_game_parameters_integration() -> void:
	"""Test that GameParameters integration works correctly"""
	# Verify we can get ideal composition
	var ideal_comp = GameParameters.get_ideal_composition("game_start")
	assert_not_null(ideal_comp, "Should be able to get game_start composition from GameParameters")
	
	# Verify we can get unit costs
	var peasant_gold_cost = GameParameters.get_unit_recruit_cost(SoldierTypeEnum.Type.PEASANTS)
	var peasant_wood_cost = GameParameters.get_unit_wood_cost(SoldierTypeEnum.Type.PEASANTS)
	var peasant_iron_cost = GameParameters.get_unit_iron_cost(SoldierTypeEnum.Type.PEASANTS)
	
	assert_type(peasant_gold_cost, TYPE_INT, "Unit gold cost should be integer")
	assert_type(peasant_wood_cost, TYPE_INT, "Unit wood cost should be integer")  
	assert_type(peasant_iron_cost, TYPE_INT, "Unit iron cost should be integer")