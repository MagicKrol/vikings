# Integration example demonstrating the castle-based BudgetManager workflow
extends RefCounted

func test_complete_recruitment_workflow():
	print("=== Complete Castle-Based Recruitment Workflow Example ===")
	
	# Step 1: Create a player with resources
	var player = Player.new(1, "Test Player")
	player.set_resource_amount(ResourcesEnum.Type.GOLD, 200)
	player.set_resource_amount(ResourcesEnum.Type.WOOD, 100) 
	player.set_resource_amount(ResourcesEnum.Type.IRON, 50)
	
	print("Player resources: Gold=", player.get_resource_amount(ResourcesEnum.Type.GOLD),
	      " Wood=", player.get_resource_amount(ResourcesEnum.Type.WOOD),
	      " Iron=", player.get_resource_amount(ResourcesEnum.Type.IRON))
	
	# Step 2: Create armies - some at castles, some not
	var army1 = Army.new()  # Will be at castle
	var army2 = Army.new()  # Will be at castle  
	var army3 = Army.new()  # Will NOT be at castle
	
	army1.setup_army(1, "I")
	army2.setup_army(1, "II") 
	army3.setup_army(1, "III")
	
	# Create mock regions and region manager for castle checking
	var mock_region_at_castle = Region.new()
	mock_region_at_castle._region_id = 1
	var mock_region_no_castle = Region.new() 
	mock_region_no_castle._region_id = 2
	
	# Position armies in regions
	mock_region_at_castle.add_child(army1)
	mock_region_at_castle.add_child(army2) 
	mock_region_no_castle.add_child(army3)
	
	# Create mock region manager
	var mock_region_manager = MockRegionManager.new()
	mock_region_manager.castle_levels[1] = 2  # Region 1 has castle level 2
	mock_region_manager.castle_levels[2] = 0  # Region 2 has no castle
	
	print("Created armies: 2 at castle, 1 not at castle")
	
	# Step 3: Use BudgetManager with castle-only allocation 
	var budget_manager = BudgetManager.new()
	var all_armies: Array[Army] = [army1, army2, army3]
	
	var assigned_count = budget_manager.allocate_recruitment_budgets(all_armies, player, mock_region_manager)
	
	print("BudgetManager assigned budgets to ", assigned_count, " armies at castles")
	
	# Step 4: Verify only armies at castles got budgets
	var armies_with_budgets = 0
	for army in all_armies:
		if army.assigned_budget != null:
			armies_with_budgets += 1
			print("Army ", army.name, " at castle got budget: ", army.assigned_budget.to_dict())
		else:
			print("Army ", army.name, " not at castle - no budget assigned")
	
	print("Total armies with budgets: ", armies_with_budgets, " (Expected: 2)")
	
	# Step 5: Verify resource conservation among castle armies
	if armies_with_budgets > 0:
		var total_allocated_gold = 0
		var total_allocated_wood = 0
		var total_allocated_iron = 0
		
		for army in all_armies:
			if army.assigned_budget != null:
				total_allocated_gold += army.assigned_budget.gold
				total_allocated_wood += army.assigned_budget.wood
				total_allocated_iron += army.assigned_budget.iron
		
		print("Resource conservation check:")
		print("  Original gold: 200, Allocated: ", total_allocated_gold, " (Match: ", total_allocated_gold == 200, ")")
		print("  Original wood: 100, Allocated: ", total_allocated_wood, " (Match: ", total_allocated_wood == 100, ")")
		print("  Original iron: 50, Allocated: ", total_allocated_iron, " (Match: ", total_allocated_iron == 50, ")")
	
	print("=== Castle-Based Workflow Complete ===")

# Mock RegionManager for testing
class MockRegionManager:
	var castle_levels: Dictionary = {}
	
	func get_castle_level(region_id: int) -> int:
		return castle_levels.get(region_id, 0)

# Run example
func _init():
	test_complete_recruitment_workflow()