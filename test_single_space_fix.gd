extends SceneTree

# Test script to verify specific budget test

func _initialize():
	print("=== Testing single test case with debug output ===")
	
	# Create the test class
	var test = TestRecruitmentProportions.new()
	test.setup()
	
	# Run just the problematic test
	print("Running test_outpost_ai_like_budget_balance...")
	test.test_outpost_ai_like_budget_balance()
	print("Test completed successfully")
	
	test.teardown()
	quit(0)

func run_tests_old():
	var success_count = 0
	var total_tests = 3
	
	# Test 1: Check TurnController no longer has redundant debug gate
	print("\n1. Testing TurnController debug gate removal...")
	var turn_controller_code = FileAccess.open("res://TurnController.gd", FileAccess.READ)
	if turn_controller_code:
		var content = turn_controller_code.get_as_text()
		turn_controller_code.close()
		
		# Check that the problematic line is removed
		var has_debug_gate_before_execute = "await debug_step_gate.step()" in content and "Step 6: Debug gate before execution" in content
		if not has_debug_gate_before_execute:
			print("✓ Redundant debug gate removed from TurnController._process_turn()")
			success_count += 1
		else:
			print("✗ TurnController still has redundant debug gate at line 189")
	else:
		print("✗ Could not read TurnController.gd")
	
	# Test 2: Verify ai_travel_to still has its own debug gating
	print("\n2. Testing ai_travel_to retains step-by-step debug gating...")
	var game_manager_code = FileAccess.open("res://game_manager.gd", FileAccess.READ)
	if game_manager_code:
		var content = game_manager_code.get_as_text()
		game_manager_code.close()
		
		if "debug_step_gate.step()" in content and "Debug step - Army" in content:
			print("✓ ai_travel_to retains proper step-by-step debug gating")
			success_count += 1
		else:
			print("✗ ai_travel_to missing step-by-step debug gating")
	else:
		print("✗ Could not read game_manager.gd")
	
	# Test 3: Check that army arrow guards are working
	print("\n3. Testing arrow guard implementation...")
	var army_manager_code = FileAccess.open("res://army_manager.gd", FileAccess.READ)
	if army_manager_code:
		var content = army_manager_code.get_as_text()
		army_manager_code.close()
		
		var has_arrow_guard = "_should_show_human_arrows()" in content
		var guard_implementation = "is_player_human(current_player_id)" in content
		
		if has_arrow_guard and guard_implementation:
			print("✓ Human arrow guards properly implemented")
			success_count += 1
		else:
			print("✗ Arrow guards not properly implemented")
			print("  Has guard: ", has_arrow_guard)
			print("  Has implementation: ", guard_implementation)
	else:
		print("✗ Could not read army_manager.gd")
	
	print("\n=== Single Space Press Fix Results ===")
	print("Passed: ", success_count, "/", total_tests, " tests")
	
	if success_count == total_tests:
		print("✓ Single space press fix implemented successfully!")
		print("✓ Removed redundant debug gate from TurnController")
		print("✓ Preserved ai_travel_to step-by-step debugging") 
		print("✓ Arrow guards prevent human UI during AI turns")
		print("\nExpected behavior:")
		print("- Each AI action should advance with a single space press")
		print("- No human path arrows during AI turns")
		print("- No empty first press at start of each AI army action")
	else:
		print("✗ Some tests failed - single space press fix may be incomplete")
	
	print("===========================================\n")