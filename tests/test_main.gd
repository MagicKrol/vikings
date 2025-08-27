extends Node
class_name TestMain

# ============================================================================
# TEST MAIN - Entry Point for Running Tests
# ============================================================================
# 
# Purpose: Main entry point for running unit tests in Godot
# 
# Usage:
# 1. Add this script to a scene and run the scene to execute all tests
# 2. Or call TestMain.run_tests() from anywhere in your project
# 3. Or run specific test classes: TestMain.run_specific_test("TestDummy")
# 
# This provides multiple ways to run tests:
# - Through Godot editor by running the test scene
# - Programmatically from other scripts
# - Command line via Godot's headless mode
# ============================================================================

func _ready() -> void:
	"""Automatically run all tests when this scene is loaded"""
	print("[TestMain] Starting automated test run...")
	run_tests()
	
	# Exit after tests in headless mode
	if DisplayServer.get_name() == "headless":
		get_tree().quit()

static func run_tests() -> Dictionary:
	"""Static method to run all tests"""
	var runner = TestRunner.new()
	return runner.run_all_tests()

static func run_specific_test(test_class_name: String) -> Dictionary:
	"""Static method to run a specific test class"""
	var runner = TestRunner.new()
	return runner.run_test_class(test_class_name)

## Alternative manual execution methods

func run_tests_manual() -> Dictionary:
	"""Manual test execution (can be called from UI)"""
	return run_tests()

func run_game_parameters_tests() -> Dictionary:
	"""Run only GameParameters-related tests"""
	return run_specific_test("TestGameParameters")

func run_recruitment_tests() -> Dictionary:
	"""Run only RecruitmentManager-related tests"""
	return run_specific_test("TestRecruitmentManager")
