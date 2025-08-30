extends RefCounted
class_name TestRunner

# ============================================================================
# TEST RUNNER
# ============================================================================
# 
# Purpose: Simple, lightweight unit testing framework for Godot 4.3
# 
# Core Responsibilities:
# - Discover and run test classes automatically
# - Provide assertion methods for testing
# - Generate test reports and results
# - Handle test lifecycle (setup/teardown)
# 
# Usage:
# - Create test classes extending TestCase
# - Name test methods starting with "test_"
# - Run tests using TestRunner.run_all_tests()
# 
# Example:
# extends TestCase
# func test_something():
#     assert_equals(2 + 2, 4, "Basic math should work")
# ============================================================================

## Test Results
var test_results: Array[Dictionary] = []
var current_test_class: String = ""
var current_test_method: String = ""
var current_test_instance = null

## Test Statistics
var tests_run: int = 0
var tests_passed: int = 0
var tests_failed: int = 0

## Console Colors
const COLOR_GREEN = "\u001b[32m"
const COLOR_RED = "\u001b[31m"
const COLOR_YELLOW = "\u001b[33m"
const COLOR_BLUE = "\u001b[34m"
const COLOR_RESET = "\u001b[0m"

func _init():
	DebugLogger.log("Testing", "[TestRunner] Initialized")

## Main test execution
func run_all_tests() -> Dictionary:
	"""Discover and run all test classes in the tests directory"""
	DebugLogger.log("Testing", "\n" + COLOR_BLUE + "=== RUNNING UNIT TESTS ===" + COLOR_RESET)
	
	_reset_stats()
	var test_files = _discover_test_files()
	
	if test_files.is_empty():
		DebugLogger.log("Testing", COLOR_YELLOW + "No test files found in tests directory" + COLOR_RESET)
		return _get_summary()
	
	# Run each test file
	for test_file in test_files:
		_run_test_file(test_file)
	
	# Print final summary
	_print_summary()
	return _get_summary()

func run_test_class(test_class_name: String) -> Dictionary:
	"""Run a specific test class by name"""
	DebugLogger.log("Testing", "\n" + COLOR_BLUE + "=== RUNNING TEST CLASS: " + test_class_name + " ===" + COLOR_RESET)
	
	_reset_stats()
	var test_file = "tests/" + test_class_name + ".gd"
	_run_test_file(test_file)
	_print_summary()
	return _get_summary()

## Private Methods

func _reset_stats() -> void:
	"""Reset test statistics"""
	test_results.clear()
	tests_run = 0
	tests_passed = 0
	tests_failed = 0

func _discover_test_files() -> Array[String]:
	"""Discover all test files in the tests directory"""
	var test_files: Array[String] = []
	var dir = DirAccess.open("res://tests")
	
	if dir == null:
		DebugLogger.log("Testing", COLOR_RED + "Could not open tests directory" + COLOR_RESET)
		return test_files
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".gd") and file_name.begins_with("Test"):
			test_files.append("tests/" + file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return test_files

func _run_test_file(test_file_path: String) -> void:
	"""Run all tests in a specific test file"""
	var script = load("res://" + test_file_path)
	if script == null:
		DebugLogger.log("Testing", COLOR_RED + "Could not load test file: " + test_file_path + COLOR_RESET)
		return
	
	var test_instance = script.new()
	if not test_instance.has_method("get_test_runner"):
		DebugLogger.log("Testing", COLOR_RED + "Test class must extend TestCase: " + test_file_path + COLOR_RESET)
		return
	
	# Set up the test instance
	test_instance.set_test_runner(self)
	current_test_class = test_file_path.get_file().get_basename()
	current_test_instance = test_instance
	
	DebugLogger.log("Testing", COLOR_BLUE + "\n--- Running " + current_test_class + " ---" + COLOR_RESET)
	
	# Get all methods that start with "test_"
	var test_methods = _get_test_methods(test_instance)
	
	if test_methods.is_empty():
		DebugLogger.log("Testing", COLOR_YELLOW + "No test methods found (methods should start with 'test_')" + COLOR_RESET)
		return
	
	# Run each test method
	for method_name in test_methods:
		_run_single_test(test_instance, method_name)

func _get_test_methods(test_instance) -> Array[String]:
	"""Get all methods that start with 'test_' from a test instance"""
	var methods: Array[String] = []
	var method_list = test_instance.get_method_list()
	
	for method_info in method_list:
		var method_name: String = method_info.name
		if method_name.begins_with("test_"):
			methods.append(method_name)
	
	return methods

func _run_single_test(test_instance, method_name: String) -> void:
	"""Run a single test method"""
	current_test_method = method_name
	tests_run += 1
	
	# Reset test state for clean debug tracking
	if test_instance.has_method("_reset_test_state"):
		test_instance._reset_test_state()
	
	var start_time = Time.get_time_dict_from_system()
	var success = true
	var error_message = ""
	
	# Call setup if it exists
	if test_instance.has_method("setup"):
		test_instance.setup()
	
	# Call the test method - if assertions fail, they will call _fail_current_test
	# We track success/failure through a flag system
	var initial_failed_count = tests_failed
	test_instance.call(method_name)
	
	# Check if test failed during execution
	if tests_failed > initial_failed_count:
		DebugLogger.log("Testing", COLOR_RED + "FAIL " + method_name + COLOR_RESET)
		success = false
		# The error message and failure handling was done in _fail_current_test
	else:
		DebugLogger.log("Testing", COLOR_GREEN + "PASS " + method_name + COLOR_RESET)
		tests_passed += 1
	
	var end_time = Time.get_time_dict_from_system()
	
	# Call teardown if it exists
	if test_instance.has_method("teardown"):
		test_instance.teardown()
	
	# Record result (only if not already recorded by _fail_current_test)
	if success:
		test_results.append({
			"class": current_test_class,
			"method": method_name,
			"success": success,
			"error": error_message,
			"start_time": start_time,
			"end_time": end_time
		})

func _print_summary() -> void:
	"""Print test execution summary"""
	DebugLogger.log("Testing", "\n" + COLOR_BLUE + "=== TEST SUMMARY ===" + COLOR_RESET)
	DebugLogger.log("Testing", "Tests run: " + str(tests_run))
	DebugLogger.log("Testing", COLOR_GREEN + "Passed: " + str(tests_passed) + COLOR_RESET)
	
	if tests_failed > 0:
		DebugLogger.log("Testing", COLOR_RED + "Failed: " + str(tests_failed) + COLOR_RESET)
		DebugLogger.log("Testing", "\n" + COLOR_RED + "FAILED TESTS:" + COLOR_RESET)
		for result in test_results:
			if not result.success:
				DebugLogger.log("Testing", "  • " + result.class + "::" + result.method)
				if result.error != "":
					DebugLogger.log("Testing", "    " + result.error)
	else:
		DebugLogger.log("Testing", COLOR_GREEN + "All tests passed!" + COLOR_RESET)

func _get_summary() -> Dictionary:
	"""Get test summary as dictionary"""
	return {
		"tests_run": tests_run,
		"tests_passed": tests_passed,
		"tests_failed": tests_failed,
		"success_rate": float(tests_passed) / float(tests_run) if tests_run > 0 else 0.0,
		"results": test_results
	}

## Test Assertion Methods (called by TestCase instances)

func assert_equals(actual, expected, message: String = "") -> void:
	"""Assert that two values are equal"""
	if actual != expected:
		var error = "Expected: " + str(expected) + ", but got: " + str(actual)
		if message != "":
			error = message + " | " + error
		_fail_current_test(error)

func assert_not_equals(actual, expected, message: String = "") -> void:
	"""Assert that two values are not equal"""
	if actual == expected:
		var error = "Expected values to be different, but both were: " + str(actual)
		if message != "":
			error = message + " | " + error
		_fail_current_test(error)

func assert_true(value, message: String = "") -> void:
	"""Assert that a value is true"""
	if not value:
		var error = "Expected true, but got: " + str(value)
		if message != "":
			error = message + " | " + error
		_fail_current_test(error)

func assert_false(value, message: String = "") -> void:
	"""Assert that a value is false"""
	if value:
		var error = "Expected false, but got: " + str(value)
		if message != "":
			error = message + " | " + error
		_fail_current_test(error)

func assert_null(value, message: String = "") -> void:
	"""Assert that a value is null"""
	if value != null:
		var error = "Expected null, but got: " + str(value)
		if message != "":
			error = message + " | " + error
		_fail_current_test(error)

func assert_not_null(value, message: String = "") -> void:
	"""Assert that a value is not null"""
	if value == null:
		var error = "Expected non-null value, but got null"
		if message != "":
			error = message + " | " + error
		_fail_current_test(error)

func assert_type(value, expected_type: int, message: String = "") -> void:
	"""Assert that a value is of expected type"""
	if typeof(value) != expected_type:
		var error = "Expected type " + type_string(expected_type) + ", but got: " + type_string(typeof(value))
		if message != "":
			error = message + " | " + error
		_fail_current_test(error)

func _fail_current_test(error_message: String) -> void:
	"""Fail the current test with an error message"""
	# Mark test instance as failed for debug output
	if current_test_instance and current_test_instance.has_method("_mark_test_failed"):
		current_test_instance._mark_test_failed()
	
	DebugLogger.log("Testing", COLOR_RED + "FAIL" + COLOR_RESET)
	DebugLogger.log("Testing", COLOR_RED + "    " + error_message + COLOR_RESET)
	tests_failed += 1
	
	# Add to results immediately
	test_results.append({
		"class": current_test_class,
		"method": current_test_method,
		"success": false,
		"error": error_message,
		"start_time": {},
		"end_time": {}
	})
	
	# Throw an error to stop test execution
	assert(false, error_message)
