# Simple test script to demonstrate the budget management system
extends RefCounted

func test_budget_system():
	DebugLogger.log("Testing", "=== Testing Budget Management System ===")
	
	# Create test armies
	var army1 = Army.new()
	var army2 = Army.new() 
	var army3 = Army.new()
	
	army1.setup_army(1, "I")
	army2.setup_army(1, "II") 
	army3.setup_army(1, "III")
	
	DebugLogger.log("Testing", "Created 3 armies for player 1")
	
	# Flag armies for recruitment
	army1.request_recruitment()
	army2.request_recruitment()
	# army3 not flagged
	
	DebugLogger.log("Testing", "Army I recruitment requested: " + str(army1.is_recruitment_requested()))
	DebugLogger.log("Testing", "Army II recruitment requested: " + str(army2.is_recruitment_requested()))  
	DebugLogger.log("Testing", "Army III recruitment requested: " + str(army3.is_recruitment_requested()))
	
	# Create ArmyManager and add armies to tracking
	var army_manager = ArmyManager.new(null, null)
	army_manager.armies_by_player[1] = [army1, army2, army3]
	
	# Create test budget (100 gold, 50 wood, 30 iron)
	var total_budget = BudgetComposition.new(100, 50, 30)
	DebugLogger.log("Testing", "Total player budget: " + str(total_budget.to_dict()))
	
	# Test collecting recruitment requests
	var requesting_armies = army_manager.collect_recruitment_requests(1)
	DebugLogger.log("Testing", "Armies requesting recruitment: " + str(requesting_armies.size()) + " armies")
	
	# Test budget assignment (should split equally between 2 requesting armies)
	army_manager.assign_recruitment_budgets(1, total_budget)
	
	DebugLogger.log("Testing", "Army I assigned budget: " + str(army1.get_assigned_budget().to_dict() if army1.get_assigned_budget() else "None"))
	DebugLogger.log("Testing", "Army II assigned budget: " + str(army2.get_assigned_budget().to_dict() if army2.get_assigned_budget() else "None"))
	DebugLogger.log("Testing", "Army III assigned budget: " + str(army3.get_assigned_budget().to_dict() if army3.get_assigned_budget() else "None"))
	
	DebugLogger.log("Testing", "=== Budget System Test Complete ===")

# Run test
func _init():
	test_budget_system()