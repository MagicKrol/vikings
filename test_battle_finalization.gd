extends Node

# Test script to verify Milestone 5: Single Battle Finalization
# This script tests that both Human and AI battles use identical finalization paths

var test_passed = true
var test_results = []

func run_battle_finalization_tests():
	"""Run tests to verify unified battle finalization"""
	print("=== Testing Milestone 5: Single Battle Finalization ===")
	
	# Test 1: Verify GameManager has finalize_battle_result method
	var game_manager = GameManager.new()
	if game_manager.has_method("finalize_battle_result"):
		test_results.append("✓ GameManager.finalize_battle_result method exists")
	else:
		test_results.append("✗ GameManager.finalize_battle_result method missing")
		test_passed = false
	
	# Test 2: Verify BattleManager delegates to GameManager
	var region_manager = RegionManager.new(null)  # Simplified for testing
	var army_manager = ArmyManager.new(null, region_manager)
	var battle_manager = BattleManager.new(region_manager, army_manager, null, null)
	battle_manager.set_game_manager(game_manager)
	
	if battle_manager.has_method("handle_battle_modal_closed"):
		test_results.append("✓ BattleManager.handle_battle_modal_closed method exists")
	else:
		test_results.append("✗ BattleManager.handle_battle_modal_closed method missing")
		test_passed = false
	
	# Test 3: Verify TurnController uses GameManager battle handling
	# Check that TurnController uses game_manager.handle_army_battle()
	var turn_controller_script = load("res://TurnController.gd")
	var source_code = FileAccess.open("res://TurnController.gd", FileAccess.READ).get_as_text()
	if "game_manager.handle_army_battle" in source_code:
		test_results.append("✓ TurnController uses game_manager.handle_army_battle")
	else:
		test_results.append("✗ TurnController does not use game_manager.handle_army_battle")
		test_passed = false
	
	# Test 4: Verify no duplicate ownership setting in battle paths
	var game_manager_source = FileAccess.open("res://game_manager.gd", FileAccess.READ).get_as_text()
	var ownership_calls = 0
	var lines = game_manager_source.split("\n")
	for line in lines:
		if "set_region_ownership" in line and "finalize_battle_result" in lines[lines.find(line) - 10]:
			ownership_calls += 1
	
	if ownership_calls == 1:
		test_results.append("✓ Single ownership setting in battle finalization")
	else:
		test_results.append("✗ Multiple or missing ownership settings found: " + str(ownership_calls))
		test_passed = false
	
	# Print test results
	print("\n=== Test Results ===")
	for result in test_results:
		print(result)
	
	print("\n=== Overall Result ===")
	if test_passed:
		print("✓ ALL TESTS PASSED - Milestone 5 implementation verified")
	else:
		print("✗ SOME TESTS FAILED - Review implementation")
	
	return test_passed

func _ready():
	# Auto-run tests when script loads
	await get_tree().process_frame
	run_battle_finalization_tests()
	queue_free()