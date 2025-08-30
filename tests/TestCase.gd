extends RefCounted
class_name TestCase

# ============================================================================
# TEST CASE BASE CLASS
# ============================================================================
# 
# Purpose: Base class for all unit tests
# 
# Core Responsibilities:
# - Provide interface to TestRunner for assertions
# - Handle test lifecycle methods (setup/teardown)
# - Provide convenient assertion methods
# 
# Usage:
# - Extend this class for your test cases
# - Implement test methods starting with "test_"
# - Use assertion methods to verify expected behavior
# - Override setup() and teardown() for test initialization/cleanup
# 
# Example:
# extends TestCase
# 
# func setup():
#     # Initialize test data
#     pass
# 
# func teardown():
#     # Clean up after test
#     pass
# 
# func test_something():
#     assert_equals(2 + 2, 4, "Basic math should work")
# ============================================================================

var _test_runner: TestRunner
var _current_test_failed: bool = false

func get_test_runner() -> TestRunner:
	"""Required method to identify this as a test case"""
	return _test_runner

func set_test_runner(runner: TestRunner) -> void:
	"""Set the test runner instance"""
	_test_runner = runner

func _mark_test_failed() -> void:
	"""Mark current test as failed for debug output purposes"""
	_current_test_failed = true

func _reset_test_state() -> void:
	"""Reset test state for next test"""
	_current_test_failed = false

func should_debug() -> bool:
	"""Return true if current test has failed and we should show debug output"""
	return _current_test_failed

## Test Lifecycle Methods (Override in subclasses)

func setup() -> void:
	"""Called before each test method. Override to set up test data."""
	pass

func teardown() -> void:
	"""Called after each test method. Override to clean up."""
	pass

## Assertion Methods (Convenience wrappers)

func assert_equals(actual, expected, message: String = "") -> void:
	"""Assert that two values are equal"""
	_test_runner.assert_equals(actual, expected, message)

func assert_not_equals(actual, expected, message: String = "") -> void:
	"""Assert that two values are not equal"""
	_test_runner.assert_not_equals(actual, expected, message)

func assert_true(value, message: String = "") -> void:
	"""Assert that a value is true"""
	_test_runner.assert_true(value, message)

func assert_false(value, message: String = "") -> void:
	"""Assert that a value is false"""
	_test_runner.assert_false(value, message)

func assert_null(value, message: String = "") -> void:
	"""Assert that a value is null"""
	_test_runner.assert_null(value, message)

func assert_not_null(value, message: String = "") -> void:
	"""Assert that a value is not null"""
	_test_runner.assert_not_null(value, message)

func assert_type(value, expected_type: int, message: String = "") -> void:
	"""Assert that a value is of expected type"""
	_test_runner.assert_type(value, expected_type, message)

## Utility Methods

func fail(message: String) -> void:
	"""Explicitly fail a test with a message"""
	assert_true(false, message)

func skip(message: String) -> void:
	"""Skip a test (print message and return early)"""
	DebugLogger.log("Testing", "    SKIPPED: " + message)
	return