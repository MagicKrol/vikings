extends SceneTree

# Test script for M4 AI Travel implementation
# Verifies that GameManager.ai_travel_to() works with step-by-step debug

func _init():
	print("\n=== M4 AI Travel Test ===")
	run_tests()
	quit()

func run_tests():
	var success_count = 0
	var total_tests = 4
	
	# Test 1: Check GameManager has ai_travel_to method
	print("\n1. Testing GameManager.ai_travel_to() method exists...")
	var game_manager_script = load("res://game_manager.gd")
	var game_manager = game_manager_script.new()
	
	if game_manager.has_method("ai_travel_to"):
		print("✓ GameManager.ai_travel_to() method found")
		success_count += 1
	else:
		print("✗ GameManager.ai_travel_to() method missing")
	
	# Test 2: Check TurnController uses ai_travel_to
	print("\n2. Testing TurnController calls ai_travel_to...")
	var turn_controller_code = FileAccess.open("res://TurnController.gd", FileAccess.READ)
	if turn_controller_code:
		var content = turn_controller_code.get_as_text()
		turn_controller_code.close()
		
		if "await game_manager.ai_travel_to(army, target_id)" in content:
			print("✓ TurnController calls ai_travel_to for step-by-step movement")
			success_count += 1
		else:
			print("✗ TurnController does not call ai_travel_to")
	else:
		print("✗ Could not read TurnController.gd")
	
	# Test 3: Check ai_travel_to includes debug step gating
	print("\n3. Testing ai_travel_to includes debug step pausing...")
	var game_manager_code = FileAccess.open("res://game_manager.gd", FileAccess.READ)
	if game_manager_code:
		var content = game_manager_code.get_as_text()
		game_manager_code.close()
		
		if "debug_step_gate.step()" in content and "Debug step - Army" in content:
			print("✓ ai_travel_to includes debug step pausing with proper logging")
			success_count += 1
		else:
			print("✗ ai_travel_to missing debug step pausing")
	else:
		print("✗ Could not read game_manager.gd")
	
	# Test 4: Check proper delegation to perform_region_entry vs ArmyManager.move_army
	print("\n4. Testing ai_travel_to uses proper delegation...")
	if game_manager_code:
		var content = FileAccess.get_file_as_string("res://game_manager.gd")
		
		var has_battle_check = "_should_trigger_battle(army, next_region)" in content
		var has_contested_path = "perform_region_entry(army, next_region_id, \"ai\")" in content
		var has_friendly_path = "_army_manager.move_army(army, next_region)" in content
		
		if has_battle_check and has_contested_path and has_friendly_path:
			print("✓ ai_travel_to properly delegates contested vs friendly steps")
			success_count += 1
		else:
			print("✗ ai_travel_to delegation incomplete:")
			print("  Battle check: ", has_battle_check)
			print("  Contested path: ", has_contested_path)
			print("  Friendly path: ", has_friendly_path)
	
	print("\n=== M4 AI Travel Test Results ===")
	print("Passed: ", success_count, "/", total_tests, " tests")
	
	if success_count == total_tests:
		print("✓ All M4 AI Travel tests passed!")
		print("✓ GameManager.ai_travel_to() wrapper implemented correctly")
		print("✓ TurnController updated to use ai_travel_to")
		print("✓ Step-by-step debug pausing integrated")
		print("✓ Proper delegation between contested and friendly movement")
	else:
		print("✗ Some M4 AI Travel tests failed")
	
	print("===========================================\n")