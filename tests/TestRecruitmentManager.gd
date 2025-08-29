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

# Minimal managers required by updated RecruitmentManager
var _map_generator: MapGenerator
var _region_manager: RegionManager
var _game_manager: GameManager

## Test Setup and Teardown

func setup() -> void:
	"""Set up test objects before each test"""
	# Create managers and inject into RecruitmentManager
	_map_generator = MapGenerator.new()
	_region_manager = RegionManager.new(_map_generator)
	_game_manager = GameManager.new()

	recruitment_manager = RecruitmentManager.new()
	recruitment_manager.region_manager = _region_manager
	recruitment_manager.game_manager = _game_manager
	
	# Create test army with empty composition
	test_army = Army.new()
	test_army.setup_raised_army(1, "Test")  # Empty army, no default soldiers
	
	# Create test region with unlimited recruits
	test_region = Region.new()
	_setup_test_region()

	# Ensure MapGenerator can resolve our test region by ID
	_map_generator.region_container_by_id[test_region.get_region_id()] = test_region
	
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
	_map_generator = null
	_region_manager = null
	_game_manager = null

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
	
	# Set castle type so RecruitmentManager can get proper composition
	test_region.set_castle_type(CastleTypeEnum.Type.OUTPOST)  # Use OUTPOST for consistent testing
	
	# Set unlimited recruits (9999 should be more than enough)
	test_region.available_recruits = 100
	test_region.population = 10000  # Large population to support recruitment

func _get_ideal_composition_percentages() -> Dictionary:
	"""Get the ideal composition percentages for Outpost castle type"""
	var ideal_raw = GameParameters.get_ideal_composition("Outpost")
	assert_not_null(ideal_raw, "Outpost composition should exist")
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

func test_outpost_composition_with_unlimited_resources() -> void:
	"""
	MAIN TEST: Verify RecruitmentManager produces ideal army composition for Outpost
	with unlimited resources and recruits
	"""
	# Get expected ideal composition percentages
	var ideal_percentages = _get_ideal_composition_percentages()
	
	# Verify we have the expected unit types in ideal composition
	assert_true(ideal_percentages.has("peasants"), "Ideal composition should include peasants")
	assert_true(ideal_percentages.has("spearmen"), "Ideal composition should include spearmen")  
	assert_true(ideal_percentages.has("archers"), "Ideal composition should include archers")
	
	# Verify percentages are reasonable (Outpost has peasants: 40, spearmen: 30, archers: 20, swordsmen: 10)
	var basic_units_percentage = ideal_percentages["peasants"] + ideal_percentages["spearmen"] + ideal_percentages["archers"]
	assert_true(abs(basic_units_percentage - 90.0) < 1.0, "Basic unit percentages should sum to ~90 for Outpost: " + str(basic_units_percentage))
	
	# Assign budget to army (new system)
	test_army.assigned_budget = unlimited_budget
	
	# Run recruitment with unlimited resources
	var result = recruitment_manager.hire_soldiers(test_army)
	
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
	
	var peasant_diff = abs(actual_percentages.get("peasants", 0.0) - ideal_percentages.get("peasants", 0.0))
	var spearmen_diff = abs(actual_percentages.get("spearmen", 0.0) - ideal_percentages.get("spearmen", 0.0))
	var archers_diff = abs(actual_percentages.get("archers", 0.0) - ideal_percentages.get("archers", 0.0))
	
	# Debug output (disabled for clean test results)
	# print("Expected vs Actual Composition:")
	# print("  Peasants: %.1f%% vs %.1f%% (diff: %.1f%%)" % [ideal_percentages.peasants, actual_percentages.peasants, peasant_diff])
	# print("  Spearmen: %.1f%% vs %.1f%% (diff: %.1f%%)" % [ideal_percentages.spearmen, actual_percentages.spearmen, spearmen_diff])
	# print("  Archers: %.1f%% vs %.1f%% (diff: %.1f%%)" % [ideal_percentages.archers, actual_percentages.archers, archers_diff])
	# print("  Total recruited: %d soldiers" % total_recruited)
	
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
	test_army.assigned_budget = unlimited_budget
	var result = recruitment_manager.hire_soldiers(test_army)
	
	# Verify resources were spent
	var gold_spent = initial_gold - unlimited_budget.gold
	var wood_spent = initial_wood - unlimited_budget.wood
	var iron_spent = initial_iron - unlimited_budget.iron
	
	assert_true(gold_spent > 0, "Should have spent some gold: " + str(gold_spent))
	assert_equals(gold_spent, result["spent_gold"], "Spent gold should match result")
	assert_equals(wood_spent, result["spent_wood"], "Spent wood should match result")
	assert_equals(iron_spent, result["spent_iron"], "Spent iron should match result")

func test_budget_remaining_tracking() -> void:
	"""Test that remaining budget is properly tracked"""
	test_army.assigned_budget = unlimited_budget
	var result = recruitment_manager.hire_soldiers(test_army)
	
	# Verify budget_left is returned
	assert_true(result.has("budget_left"), "Result should include budget_left")
	assert_true(result["budget_left"].has("gold"), "Budget left should include gold")
	assert_true(result["budget_left"].has("wood"), "Budget left should include wood")
	assert_true(result["budget_left"].has("iron"), "Budget left should include iron")
	
	# Verify remaining budget matches actual budget
	assert_equals(result["budget_left"]["gold"], unlimited_budget.gold, "Remaining gold should match budget")
	assert_equals(result["budget_left"]["wood"], unlimited_budget.wood, "Remaining wood should match budget")
	assert_equals(result["budget_left"]["iron"], unlimited_budget.iron, "Remaining iron should match budget")

## Resource Constraint Tests

func test_recruitment_with_limited_wood() -> void:
	"""Test recruitment behavior with limited wood - should get max archers, then peasants/spearmen in ratio"""
	# 10 wood = max 10 archers (archers cost 1 wood each)
	var limited_wood_budget = BudgetComposition.new(9999, 10, 9999)  # unlimited gold/iron, limited wood
	
	test_army.assigned_budget = limited_wood_budget
	var result = recruitment_manager.hire_soldiers(test_army)
	
	var total_recruited = test_army.get_total_soldiers()
	var peasant_count = test_army.get_soldier_count(SoldierTypeEnum.Type.PEASANTS)
	var spearmen_count = test_army.get_soldier_count(SoldierTypeEnum.Type.SPEARMEN)
	var archer_count = test_army.get_soldier_count(SoldierTypeEnum.Type.ARCHERS)
	
	# Should recruit exactly 10 archers (limited by wood)
	assert_equals(archer_count, 10, "Should recruit exactly 10 archers (limited by wood)")
	
	# Remaining non-peasants should be redistributed 3:1 to spears:swords
	var swords_count = test_army.get_soldier_count(SoldierTypeEnum.Type.SWORDSMEN)
	assert_equals(peasant_count, 40, "Peasants stay at ideal 40% = 40")
	assert_equals(spearmen_count, 38, "Spearmen get 3/4 of shortfall (8)")
	assert_equals(swords_count, 12, "Swordsmen get 1/4 of shortfall (2)")
	assert_equals(result["spent_wood"], 10, "Should spend exactly 10 wood")

func test_recruitment_with_limited_gold() -> void:
	"""Test recruitment behavior with limited gold - should get spearmen/archers maintaining ratio"""
	# 40 gold = can buy mix of spearmen (1 gold) and archers (3 gold)
	var limited_gold_budget = BudgetComposition.new(40, 9999, 9999)  # limited gold, unlimited wood/iron
	
	test_army.assigned_budget = limited_gold_budget
	var result = recruitment_manager.hire_soldiers(test_army)
	
	var total_recruited = test_army.get_total_soldiers()
	var peasant_count = test_army.get_soldier_count(SoldierTypeEnum.Type.PEASANTS)
	var spearmen_count = test_army.get_soldier_count(SoldierTypeEnum.Type.SPEARMEN)
	var archer_count = test_army.get_soldier_count(SoldierTypeEnum.Type.ARCHERS)
	
	# With limited gold, verify units.py algorithm: peasants = floor(unit0_share * total_units) 
	var ideal = _get_ideal_composition_percentages()
	var pea_share = float(ideal["peasants"]) / 100.0
	var expected_peas = int(floor(pea_share * 100.0))  # floor(0.40 * 100) = 40
	assert_equals(peasant_count, expected_peas, "Peasants should be exactly floor(unit0_share * total_units)")
	assert_true((spearmen_count + archer_count) > 0, "Should recruit some paid units with available gold")

func test_recruitment_with_limited_recruits_maintaining_ratio() -> void:
	"""Test recruitment with unlimited resources but limited recruits - should maintain ideal ratio"""
	# Set limited recruits to 50
	test_region.available_recruits = 50
	
	test_army.assigned_budget = unlimited_budget
	var result = recruitment_manager.hire_soldiers(test_army)
	
	var total_recruited = test_army.get_total_soldiers()
	var peasant_count = test_army.get_soldier_count(SoldierTypeEnum.Type.PEASANTS)
	var spearmen_count = test_army.get_soldier_count(SoldierTypeEnum.Type.SPEARMEN)
	var archer_count = test_army.get_soldier_count(SoldierTypeEnum.Type.ARCHERS)
	
	# Should recruit exactly 50 soldiers
	assert_equals(total_recruited, 50, "Should recruit exactly 50 soldiers (limited by recruits)")
	
	# Should maintain ideal composition ratios
	var ideal_percentages = _get_ideal_composition_percentages()
	var actual_percentages = _normalize_composition_to_percentages(_get_army_composition_counts(), total_recruited)
	
	var tolerance = 8.0  # Allow 8% tolerance for small army sizes
	var peasant_diff = abs(actual_percentages.get("peasants", 0.0) - ideal_percentages.get("peasants", 0.0))
	var spearmen_diff = abs(actual_percentages.get("spearmen", 0.0) - ideal_percentages.get("spearmen", 0.0))
	var archers_diff = abs(actual_percentages.get("archers", 0.0) - ideal_percentages.get("archers", 0.0))
	
	# Debug output (disabled for clean test results)
	# print("Limited Recruits Test Results:")
	# print("  Total: %d soldiers" % total_recruited)
	# print("  Expected: Peasants %.1f%%, Spearmen %.1f%%, Archers %.1f%%" % [ideal_percentages.peasants, ideal_percentages.spearmen, ideal_percentages.archers])
	# print("  Actual: Peasants %.1f%%, Spearmen %.1f%%, Archers %.1f%%" % [actual_percentages.peasants, actual_percentages.spearmen, actual_percentages.archers])
	# print("  Differences: Peasants %.1f%%, Spearmen %.1f%%, Archers %.1f%%" % [peasant_diff, spearmen_diff, archers_diff])
	
	assert_true(peasant_diff <= tolerance, "Peasant percentage should match ideal within " + str(tolerance) + "%")
	assert_true(spearmen_diff <= tolerance, "Spearmen percentage should match ideal within " + str(tolerance) + "%")
	assert_true(archers_diff <= tolerance, "Archers percentage should match ideal within " + str(tolerance) + "%")
	assert_equals(result["recruits_left"], 0, "Should have no recruits left")

## Edge Case Tests

func test_recruitment_with_limited_recruits() -> void:
	"""Test recruitment behavior when recruits are limited"""
	# Set limited recruits
	test_region.available_recruits = 10
	
	test_army.assigned_budget = unlimited_budget
	var result = recruitment_manager.hire_soldiers(test_army)
	
	# Should recruit exactly 10 soldiers
	var total_recruited = test_army.get_total_soldiers()
	assert_equals(total_recruited, 10, "Should recruit exactly the available recruits")
	assert_equals(result["recruits_left"], 0, "Should have no recruits left")

func test_recruitment_with_zero_budget() -> void:
	"""Test recruitment with zero budget respects peasant cap and leaves recruits unused"""
	var zero_budget = BudgetComposition.new(0, 0, 0)
	
	test_army.assigned_budget = zero_budget
	var result = recruitment_manager.hire_soldiers(test_army)
	
	var total_recruited = test_army.get_total_soldiers()
	var peasant_count = test_army.get_soldier_count(SoldierTypeEnum.Type.PEASANTS)
	var ideal_percentages = _get_ideal_composition_percentages()
	var pea_share = float(ideal_percentages["peasants"]) / 100.0
	var expected_peas = int(floor(pea_share * 100.0))  # floor(0.40 * 100) = 40
	
	assert_equals(peasant_count, expected_peas, "With zero budget, should still recruit floor(unit0_share * total_units) peasants")
	assert_equals(result["spent_gold"], 0, "Should spend no gold")

## Integration Tests

func test_army_composition_integration() -> void:
	"""Test that army composition is properly updated"""
	# Recruit soldiers
	test_army.assigned_budget = unlimited_budget
	recruitment_manager.hire_soldiers(test_army)
	
	# Verify composition object reflects changes
	var composition = test_army.get_composition()
	assert_not_null(composition, "Army should have composition object")
	
	var total_from_composition = composition.get_total_soldiers()
	var total_from_army = test_army.get_total_soldiers()
	
	assert_equals(total_from_composition, total_from_army, "Composition and army totals should match")

func test_multiple_recruitment_calls() -> void:
	"""Second pass may do nothing if recruits/resources are exhausted"""
	# First recruitment
	test_army.assigned_budget = unlimited_budget
	var result1 = recruitment_manager.hire_soldiers(test_army)
	var soldiers_after_first = test_army.get_total_soldiers()
	
	# Second recruitment (likely no recruits/resources left)
	test_army.assigned_budget = unlimited_budget
	var result2 = recruitment_manager.hire_soldiers(test_army)
	var soldiers_after_second = test_army.get_total_soldiers()
	
	assert_true(soldiers_after_second >= soldiers_after_first, "Second recruitment should not reduce soldiers")
	# New units.py algorithm: if no recruits available, should hire 0
	var expected_hired_count = 1 if result2["hired"].has(SoldierTypeEnum.Type.PEASANTS) and result2["hired"][SoldierTypeEnum.Type.PEASANTS] > 0 else 0
	assert_true(result2["hired"].size() <= 1, "Second recruitment should hire at most peasants when no recruits left")

## Validation Tests

func test_game_parameters_integration() -> void:
	"""Test that GameParameters integration works correctly"""
	# Verify we can get ideal composition
	var ideal_comp = GameParameters.get_ideal_composition("Outpost")
	assert_not_null(ideal_comp, "Should be able to get Outpost composition from GameParameters")
	
	# Verify we can get unit costs
	var peasant_gold_cost = GameParameters.get_unit_recruit_cost(SoldierTypeEnum.Type.PEASANTS)
	var peasant_wood_cost = GameParameters.get_unit_wood_cost(SoldierTypeEnum.Type.PEASANTS)
	var peasant_iron_cost = GameParameters.get_unit_iron_cost(SoldierTypeEnum.Type.PEASANTS)
	
	assert_type(peasant_gold_cost, TYPE_INT, "Unit gold cost should be integer")
	assert_type(peasant_wood_cost, TYPE_INT, "Unit wood cost should be integer")  
	assert_type(peasant_iron_cost, TYPE_INT, "Unit iron cost should be integer")

func test_none_castle_recruits_peasants_only() -> void:
	"""Test that RecruitmentManager recruits 100% peasants for NONE castle type with limited resources"""
	# Set castle type to NONE (no castle)
	test_region.set_castle_type(CastleTypeEnum.Type.NONE)
	
	# Test recruitment with no castle and no resources - should recruit only peasants (they're free)
	var zero_budget = BudgetComposition.new(0, 0, 0)
	test_army.assigned_budget = zero_budget
	var result = recruitment_manager.hire_soldiers(test_army)
	
	# Should succeed and recruit soldiers (100% peasants)
	assert_not_null(result, "Should return result dictionary")
	assert_false(result.has("error"), "Should not have error field")
	assert_not_null(result["hired"], "Should have hired soldiers")
	
	# Verify army now has soldiers (all peasants)
	var total_recruited = test_army.get_total_soldiers()
	assert_true(total_recruited > 0, "Army should have recruited soldiers: " + str(total_recruited))
	
	# Verify composition is 100% peasants
	var peasant_count = test_army.get_soldier_count(SoldierTypeEnum.Type.PEASANTS)
	var spearmen_count = test_army.get_soldier_count(SoldierTypeEnum.Type.SPEARMEN)
	var archer_count = test_army.get_soldier_count(SoldierTypeEnum.Type.ARCHERS)
	
	assert_equals(peasant_count, total_recruited, "Should recruit only peasants for NONE castle type")
	assert_equals(spearmen_count, 0, "Should recruit no spearmen for NONE castle type")
	assert_equals(archer_count, 0, "Should recruit no archers for NONE castle type")
