extends TestCase
class_name TestDummy

# ============================================================================
# DUMMY TEST CLASS
# ============================================================================
# 
# Purpose: Simple test class to verify the testing framework works correctly
# 
# This test class contains basic tests that verify:
# - Framework can discover and run test methods
# - Assertions work correctly (both passing and failing)
# - Setup and teardown lifecycle methods work
# - Different assertion types function properly
# ============================================================================

var test_data: Dictionary

## Test Lifecycle Methods

func setup() -> void:
	"""Set up test data before each test"""
	test_data = {
		"number": 42,
		"text": "hello",
		"array": [1, 2, 3],
		"boolean": true
	}

func teardown() -> void:
	"""Clean up after each test"""
	test_data.clear()

## Basic Functionality Tests

func test_basic_math() -> void:
	"""Test basic mathematical operations"""
	assert_equals(2 + 2, 4, "Addition should work")
	assert_equals(10 - 5, 5, "Subtraction should work")
	assert_equals(3 * 4, 12, "Multiplication should work")
	assert_equals(8 / 2, 4, "Division should work")

func test_string_operations() -> void:
	"""Test string operations"""
	var greeting = "Hello, World!"
	assert_equals(greeting.length(), 13, "String length should be correct")
	assert_true(greeting.begins_with("Hello"), "String should start with 'Hello'")
	assert_true(greeting.ends_with("World!"), "String should end with 'World!'")

func test_array_operations() -> void:
	"""Test array operations"""
	var numbers = [1, 2, 3, 4, 5]
	assert_equals(numbers.size(), 5, "Array should have 5 elements")
	assert_true(numbers.has(3), "Array should contain 3")
	assert_false(numbers.has(10), "Array should not contain 10")
	
	numbers.append(6)
	assert_equals(numbers.size(), 6, "Array should have 6 elements after append")

## Data Type Tests

func test_setup_data() -> void:
	"""Test that setup() method works and data is available"""
	assert_not_null(test_data, "Test data should not be null")
	assert_equals(test_data.number, 42, "Test number should be 42")
	assert_equals(test_data.text, "hello", "Test text should be 'hello'")
	assert_true(test_data.boolean, "Test boolean should be true")

func test_type_checking() -> void:
	"""Test type assertion methods"""
	assert_type(42, TYPE_INT, "42 should be an integer")
	assert_type("hello", TYPE_STRING, "hello should be a string")
	assert_type([], TYPE_ARRAY, "[] should be an array")
	assert_type({}, TYPE_DICTIONARY, "} should be a dictionary")
	assert_type(true, TYPE_BOOL, "true should be a boolean")

## Boolean Tests

func test_boolean_assertions() -> void:
	"""Test boolean assertion methods"""
	assert_true(true, "true should be true")
	assert_false(false, "false should be false")
	assert_true(1 > 0, "1 should be greater than 0")
	assert_false(0 > 1, "0 should not be greater than 1")

## Null Tests

func test_null_assertions() -> void:
	"""Test null assertion methods"""
	var null_value = null
	var non_null_value = "not null"
	
	assert_null(null_value, "null_value should be null")
	assert_not_null(non_null_value, "non_null_value should not be null")

## Equality Tests

func test_equality_assertions() -> void:
	"""Test equality assertion methods"""
	assert_equals("same", "same", "Identical strings should be equal")
	assert_not_equals("different", "values", "Different strings should not be equal")
	
	var obj1 = {"key": "value"}
	var obj2 = {"key": "value"}
	assert_equals(obj1, obj2, "Objects with same content should be equal")

## GameParameters Integration Test

func test_game_parameters_accessible() -> void:
	"""Test that we can access GameParameters from tests"""
	assert_not_null(GameParameters, "GameParameters should be accessible")
	
	# Test that we can call static methods
	var starting_gold = GameParameters.get_starting_resource_amount(ResourcesEnum.Type.GOLD)
	assert_equals(starting_gold, 100, "Starting gold should be 100")
	
	# Test ideal composition access
	var game_start_composition = GameParameters.get_ideal_composition("game_start")
	assert_not_null(game_start_composition, "Game start composition should exist")
	assert_true(game_start_composition.has("peasants"), "Composition should have peasants")

## Edge Case Tests

func test_edge_cases() -> void:
	"""Test edge cases and boundary conditions"""
	# Empty collections
	assert_equals([].size(), 0, "Empty array should have size 0")
	assert_equals({}.size(), 0, "Empty dictionary should have size 0")
	
	# Zero and negative numbers
	assert_equals(0 * 100, 0, "Zero multiplication should work")
	assert_true(-5 < 0, "Negative numbers should be less than zero")
	
	# String edge cases
	assert_equals("".length(), 0, "Empty string should have length 0")
	assert_true("a".length() > 0, "Non-empty string should have positive length")