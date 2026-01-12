extends Node
class_name PlayerManagerNode

# Signals
signal current_player_changed(player_id: int)

# ============================================================================
# PLAYER MANAGER NODE
# ============================================================================
# 
# Purpose: Multi-player system coordination and resource management as a static node
# 
# Core Responsibilities:
# - Player lifecycle management (initialization, storage, access)
# - Turn-based resource income calculation and distribution
# - Territory ownership tracking and region-based income
# - Resource transaction validation and processing
# - Player state coordination for game systems
# 
# Required Functions:
# - process_resource_income(): Calculate and apply turn-based income
# - add/remove_resources_to_player(): Resource transactions
# - can_player_afford_cost(): Cost validation
# - get_player_regions(): Territory ownership queries
# - set_current_player(): Turn management
# 
# Integration Points:
# - RegionManager: Territory ownership and resource calculations
# - MapGenerator: Region data for income calculations  
# - Player: Individual player data management
# - GameManager: Turn coordination and state updates
# ============================================================================

# Player storage: player_id -> Player
var players: Dictionary = {}

# Current active player
var current_player_id: int = 1
var total_players: int = 6

# References for region-based income calculation and army management
var region_manager: RegionManager = null
var map_generator: MapGenerator = null
var army_manager: ArmyManager = null

func _ready():
	# Initialize players immediately when not already prepared (editor mode)
	if players.is_empty():
		_initialize_players([])

func initialize_with_managers(region_mgr: RegionManager, map_gen: MapGenerator):
	"""Initialize with manager references from GameManager"""
	region_manager = region_mgr
	map_generator = map_gen

func set_army_manager(army_mgr: ArmyManager) -> void:
	"""Set the army manager reference"""
	army_manager = army_mgr

func _initialize_players(player_types: Array[PlayerTypeEnum.Type]) -> void:
	"""Initialize all players with default settings"""
	for i in range(1, total_players + 1):
		var player = Player.new(i, "Player " + str(i))
		#Check if player is computer or human and set a proper flag
		if player_types.is_empty():
			player.set_is_computer(false)
		else:
			if player_types[i-1] == PlayerTypeEnum.Type.COMPUTER:
				player.set_is_computer(true)
			else:
				player.set_is_computer(false)
		players[i] = player

func get_player(player_id: int) -> Player:
	"""Get a player by ID"""
	return players.get(player_id, null)

func get_current_player() -> Player:
	"""Get the currently active player"""
	return get_player(current_player_id)

func get_all_players() -> Array[Player]:
	"""Get all players as an array"""
	var result: Array[Player] = []
	for player_id in players:
		result.append(players[player_id])
	return result

func get_player_wealth_level(player_id: int) -> int:
	var player = get_player(player_id)
	if player == null:
		return GameParameters.WealthLevel.POOR
	return player.get_wealth_level()

func update_player_wealth_status(player_id: int) -> void:
	var player = get_player(player_id)
	if player == null:
		return
	var gold = player.get_resource_amount(ResourcesEnum.Type.GOLD)
	var level = GameParameters.get_wealth_level_for_gold(gold)
	player.set_wealth_level(level)

func set_current_player(player_id: int) -> void:
	"""Set the active player"""
	if players.has(player_id):
		current_player_id = player_id
		DebugLogger.log("PlayerManagement", "Current player changed to " + get_current_player().get_player_name())
		current_player_changed.emit(player_id)

func next_player() -> Player:
	"""Advance to the next player and return them"""
	current_player_id = (current_player_id % total_players) + 1
	var next_player = get_current_player()
	DebugLogger.log("PlayerManagement", "Advanced to " + next_player.get_player_name())
	return next_player

func get_total_players() -> int:
	"""Get the total number of players"""
	return total_players

func player_exists(player_id: int) -> bool:
	"""Check if a player exists"""
	return players.has(player_id)

# Resource management for all players
func add_resources_to_player(player_id: int, resource_type: ResourcesEnum.Type, amount: int) -> bool:
	"""Add resources to a specific player"""
	var player = get_player(player_id)
	if player == null:
		return false
	
	player.add_resources(resource_type, amount)
	return true

func remove_resources_from_player(player_id: int, resource_type: ResourcesEnum.Type, amount: int) -> bool:
	"""Remove resources from a specific player"""
	var player = get_player(player_id)
	if player == null:
		return false
	
	return player.remove_resources(resource_type, amount)

func add_traded_resource_amount(player_id: int, resource_type: ResourcesEnum.Type, amount: int) -> void:
	var player = get_player(player_id)
	if player == null:
		return
	player.add_traded_resource_amount(resource_type, amount)

func get_traded_resource_amount(player_id: int, resource_type: ResourcesEnum.Type) -> int:
	var player = get_player(player_id)
	if player == null:
		return 0
	return player.get_traded_resource_amount(resource_type)

func decay_traded_resources_for_player(player_id: int, rate: float) -> void:
	var player = get_player(player_id)
	if player == null:
		return
	if region_manager == null or map_generator == null:
		return
	var growths: Dictionary = {}
	var trade_resources = [
		ResourcesEnum.Type.FOOD,
		ResourcesEnum.Type.WOOD,
		ResourcesEnum.Type.STONE,
		ResourcesEnum.Type.IRON
	]
	for rt in trade_resources:
		growths[rt] = get_player_resource_growth(player_id, rt)
	player.decay_traded_resources(rate, growths)

func can_player_afford(player_id: int, resource_type: ResourcesEnum.Type, amount: int) -> bool:
	"""Check if a player can afford a specific cost"""
	var player = get_player(player_id)
	if player == null:
		return false
	
	return player.can_afford(resource_type, amount)

func can_player_afford_cost(player_id: int, cost: Dictionary) -> bool:
	"""Check if a player can afford a cost dictionary"""
	var player = get_player(player_id)
	if player == null:
		return false
	
	return player.can_afford_cost(cost)

func charge_player(player_id: int, cost: Dictionary) -> bool:
	"""Charge a player for a cost dictionary"""
	var player = get_player(player_id)
	if player == null:
		return false
	
	return player.pay_cost(cost)

func set_player_resources(player_id: int, resources_data: Dictionary) -> void:
	"""Set all resource amounts for a player using a resource dictionary"""
	var player = get_player(player_id)
	for resource_type in ResourcesEnum.get_all_types():
		var key := ResourcesEnum.type_to_string(resource_type)
		var amount := int(resources_data.get(key, GameParameters.get_starting_resource_amount(resource_type)))
		player.set_resource_amount(resource_type, amount)

func process_resource_income_for_player(player_id: int) -> void:
	"""Process resource income for a specific player"""
	
	var player = players.get(player_id, null)
	if player != null:
		DebugLogger.log("PlayerManagement", "Processing income for " + player.get_player_name())
		_calculate_player_income(player)
	else:
		push_error("[PlayerManagerNode] Player ", player_id, " not found!")

func _calculate_player_income(player: Player) -> void:
	"""Calculate and apply resource income for a player based on owned regions"""
	var player_id = player.get_player_id()
	var is_ai := player.is_computer()

	# Get all regions owned by this player
	var owned_regions = region_manager.get_player_regions(player_id)

	if owned_regions.is_empty():
		DebugLogger.log("PlayerManagement", "No regions owned by " + player.get_player_name() + " - no resource income")
		return
	
	# Calculate total resources from all owned regions
	var total_resources = {
		ResourcesEnum.Type.GOLD: 0,
		ResourcesEnum.Type.FOOD: 0,
		ResourcesEnum.Type.WOOD: 0,
		ResourcesEnum.Type.IRON: 0,
		ResourcesEnum.Type.STONE: 0
	}
	
	# Get regions node from map generator
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		push_error("[PlayerManagerNode] CRITICAL: No Regions node found in map generator")
		return
	
	# Sum up resources from all owned regions
	for region_id in owned_regions:
		var region_node = _find_region_by_id(regions_node, region_id)
		if region_node != null:
			# Add region resource production (only if resource can be collected)
			for resource_type in total_resources.keys():
				if region_node.can_collect_resource(resource_type):
					var region_resource_amount = region_node.get_resource_amount(resource_type)
					total_resources[resource_type] += region_resource_amount
			
			# Add population-based gold income
			total_resources[ResourcesEnum.Type.GOLD] += region_node.get_income()
	
	# Apply AI handicap bonuses
	if is_ai:
		total_resources = _apply_ai_income_bonus(total_resources)
	
	# Apply the total resources to the player
	var total_income_value = 0
	for resource_type in total_resources:
		var amount = total_resources[resource_type]
		if amount > 0:
			player.add_resources(resource_type, amount)
			total_income_value += amount

func _find_region_by_id(regions_node: Node, region_id: int) -> Region:
	"""Find a region node by its ID"""
	for child in regions_node.get_children():
		if child is Region and child.get_region_id() == region_id:
			return child
	return null

func get_player_economy_snapshot(player_id: int) -> Dictionary:
	"""Aggregate current balances, projected income, and population snapshot for a player."""
	var player = get_player(player_id)
	var income := {
		ResourcesEnum.Type.GOLD: 0,
		ResourcesEnum.Type.FOOD: 0,
		ResourcesEnum.Type.WOOD: 0,
		ResourcesEnum.Type.IRON: 0,
		ResourcesEnum.Type.STONE: 0
	}
	var population_amount := 0
	var population_growth := 0
	var owned_regions = region_manager.get_player_regions(player_id)
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		return {
			"income": income,
			"population": {
				"amount": population_amount,
				"growth": population_growth
			},
			"balances": player.get_all_resources()
		}
	for region_id in owned_regions:
		var region_node = _find_region_by_id(regions_node, region_id)
		if region_node != null:
			for resource_type in income.keys():
				if region_node.can_collect_resource(resource_type):
					income[resource_type] += region_node.get_resource_amount(resource_type)
			income[ResourcesEnum.Type.GOLD] += region_node.get_income()
			population_amount += region_node.get_population()
			if not region_node.is_ocean_region():
				population_growth += region_node.get_population_increase()
	if player != null and player.is_computer():
		income = _apply_ai_income_bonus(income)
	var food_upkeep := calculate_total_army_food_cost(player_id)
	income[ResourcesEnum.Type.FOOD] -= int(ceil(food_upkeep))
	return {
		"income": income,
		"population": {
			"amount": population_amount,
			"growth": population_growth
		},
		"balances": player.get_all_resources()
	}

func get_projected_economy_for_player(player_id: int) -> Dictionary:
	"""Return next-turn resource income and population growth snapshot without mutating state."""
	var snapshot = get_player_economy_snapshot(player_id)
	return {
		"income": snapshot.get("income", {}),
		"population": snapshot.get("population", {"amount": 0, "growth": 0})
	}

func _apply_ai_income_bonus(income: Dictionary) -> Dictionary:
	var result := income.duplicate()
	var resource_multiplier := 1.0 + GameParameters.AI_RESOURCE_GROWTH_BONUS
	var gold_multiplier := 1.0 + GameParameters.AI_INCOME_GROWTH_BONUS
	for resource_type in result.keys():
		var amount := float(result[resource_type])
		if resource_type == ResourcesEnum.Type.GOLD:
			result[resource_type] = int(ceil(amount * gold_multiplier))
		else:
			result[resource_type] = int(ceil(amount * resource_multiplier))
	return result

# Player information
func get_player_resource_summary() -> String:
	"""Get a summary of all players' resources"""
	var summary = "=== Player Resources ===\n"
	
	for player_id in players:
		var player = players[player_id]
		summary += player.get_player_name() + ":\n"
		summary += player.get_resources_string() + "\n\n"
	
	return summary

func get_current_player_summary() -> String:
	"""Get current player's resource summary"""
	var current = get_current_player()
	if current == null:
		return "No active player"
	
	return current.get_player_name() + " Resources:\n" + current.get_resources_string()

# Economy helper functions
func get_richest_player() -> Player:
	"""Get the player with the most gold"""
	var richest_player: Player = null
	var most_gold = -1
	
	for player_id in players:
		var player = players[player_id]
		var gold = player.get_resource_amount(ResourcesEnum.Type.GOLD)
		if gold > most_gold:
			most_gold = gold
			richest_player = player
	
	return richest_player

func get_total_economy_value() -> int:
	"""Get the total economic value across all players"""
	var total = 0
	
	for player_id in players:
		var player = players[player_id]
		for resource_type in ResourcesEnum.get_all_types():
			total += player.get_resource_amount(resource_type)
	
	return total

func record_enemy_army_power(observer_id: int, enemy_army: Army) -> void:
	var player = get_player(observer_id)
	if player == null:
		return
	var key = Player.get_enemy_tracker_key(enemy_army)
	if key == "":
		return
	var power = 0
	if enemy_army != null and is_instance_valid(enemy_army):
		power = enemy_army.get_army_power()
	player.update_enemy_army_memory(key, power)

func record_enemy_garrison(observer_id: int, region_id: int, power: int) -> void:
	var player = get_player(observer_id)
	if player == null:
		return
	player.update_enemy_garrison_memory(region_id, power)

func decay_enemy_memory_for_player(player_id: int) -> void:
	var player = get_player(player_id)
	if player == null:
		return
	player.decay_enemy_memory()

func get_tracked_enemy_power(player_id: int, key: String) -> int:
	var player = get_player(player_id)
	if player == null:
		return -1
	return player.get_tracked_enemy_power(key)

func get_tracked_enemy_garrison_power(player_id: int, region_id: int) -> int:
	var player = get_player(player_id)
	if player == null:
		return -1
	return player.get_tracked_enemy_garrison_power(region_id)

# Methods for recruitment modal support
func get_resource_amount(resource_type: ResourcesEnum.Type) -> int:
	"""Get current player's resource amount"""
	var player = get_current_player()
	if player == null:
		return 0
	return player.get_resource_amount(resource_type)

func spend_resource(resource_type: ResourcesEnum.Type, amount: int) -> bool:
	"""Spend resources from current player"""
	var player = get_current_player()
	if player == null:
		return false
	return player.remove_resources(resource_type, amount)

func temp_deduct_resources(cost: Dictionary) -> void:
	"""Temporarily deduct resources (for UI preview) - actually deduct them immediately"""
	# For simplicity, we'll deduct the resources immediately
	# The recruitment modal will manage the temporary state
	var player = get_current_player()
	if player == null:
		return
	
	for resource_type in cost:
		var amount = cost[resource_type]
		if amount > 0:
			# Don't actually deduct here - just used for UI updates
			pass

# Save/Load functionality
func save_to_dictionary() -> Dictionary:
	"""Save all player data to dictionary"""
	var result = {
		"current_player_id": current_player_id,
		"total_players": total_players,
		"players": {}
	}
	
	for player_id in players:
		result["players"][str(player_id)] = players[player_id].to_dictionary()
	
	return result

func load_from_dictionary(data: Dictionary) -> void:
	"""Load player data from dictionary"""
	current_player_id = data.get("current_player_id", 1)
	total_players = data.get("total_players", 4)
	
	players.clear()
	var players_data = data.get("players", {})
	
	for player_id_str in players_data:
		var player_id = int(player_id_str)
		var player = Player.new()
		player.from_dictionary(players_data[player_id_str])
		players[player_id] = player

# Debug and testing functions
func print_all_resources() -> void:
	"""Print all players' resources to console"""
	DebugLogger.log("PlayerManagement", get_player_resource_summary())

func give_test_resources(player_id: int) -> void:
	"""Give test resources to a player for debugging"""
	var player = get_player(player_id)
	if player == null:
		return
	
	player.add_resources(ResourcesEnum.Type.GOLD, 1000)
	player.add_resources(ResourcesEnum.Type.FOOD, 500)
	player.add_resources(ResourcesEnum.Type.WOOD, 300)
	player.add_resources(ResourcesEnum.Type.IRON, 200)
	player.add_resources(ResourcesEnum.Type.STONE, 250)
	
	DebugLogger.log("PlayerManagement", "Gave test resources to " + player.get_player_name())

# Resource income and management
func process_resource_income() -> void:
	
	# Process income for all players
	for player_id in players:
		var player = players[player_id]
		DebugLogger.log("PlayerManagement", "Processing income for " + player.get_player_name())
		_calculate_player_income(player)

func get_player_food_growth(player_id: int) -> float:
	"""Calculate net food change per turn (income - upkeep)"""
	var owned_regions = region_manager.get_player_regions(player_id)
	var food_income := 0.0
	for region_id in owned_regions:
		var region_node = map_generator.get_region_container_by_id(region_id) as Region
		if region_node != null and region_node.can_collect_resource(ResourcesEnum.Type.FOOD):
			food_income += float(region_node.get_resource_amount(ResourcesEnum.Type.FOOD))
	var total_food_cost = calculate_total_army_food_cost(player_id)
	return food_income - total_food_cost

func meets_food_upgrade_safeguard(player_id: int, food_cost: int) -> bool:
	"""Check if player keeps minimum food buffer after a region upgrade"""
	var player = get_player(player_id)
	if player == null:
		return false
	var food_after_upgrade = float(player.get_resource_amount(ResourcesEnum.Type.FOOD) - food_cost)
	var projected_food = food_after_upgrade + get_player_food_growth(player_id)
	return projected_food >= float(GameParameters.AI_MIN_FOOD_AFTER_UPGRADE)

func calculate_total_army_food_cost(player_id: int) -> float:
	"""Calculate total food cost for all armies and garrisons owned by a player"""
	var total_food_cost = 0.0
	var player = get_player(player_id)
	var is_computer = player.is_computer()
	
	# Get all regions owned by this player and sum garrison food costs
	# if not is_computer or 1: #for now we enable food cost for AI
	# 	var owned_regions = region_manager.get_player_regions(player_id)
	# 	var regions_node = map_generator.get_node_or_null("Regions")
	# 	for region_id in owned_regions:
	# 		var region_node = _find_region_by_id(regions_node, region_id)
	# 		var garrison = region_node.get_garrison()
	# 		if garrison != null:
	# 			var garrison_food_cost = garrison.get_total_food_cost()
	# 			total_food_cost += garrison_food_cost
	# 		var wounded_garrison = region_node.get_wounded_garrison()
	# 		if wounded_garrison != null:
	# 			var wounded_garrison_food_cost = wounded_garrison.get_total_food_cost()
	# 			total_food_cost += wounded_garrison_food_cost
	
	# Add standalone armies
	if army_manager != null:
		var all_armies = army_manager.get_all_armies()
		for army in all_armies:
			if army.get_player_id() == player_id:
				var army_composition = army.get_composition()
				if army_composition != null:
					var army_food_cost = army_composition.get_total_food_cost()
					total_food_cost += army_food_cost
					# Include wounded composition upkeep
					var wounded_comp = army.get_wounded_composition()
					if wounded_comp != null:
						total_food_cost += wounded_comp.get_total_food_cost()
	
	return total_food_cost

func get_player_resource_growth(player_id: int, resource_type: ResourcesEnum.Type) -> float:
	var owned_regions = region_manager.get_player_regions(player_id)
	var total := 0.0
	for region_id in owned_regions:
		var region_node = map_generator.get_region_container_by_id(region_id) as Region
		if region_node.can_collect_resource(resource_type):
			total += float(region_node.get_resource_amount(resource_type))
	if resource_type == ResourcesEnum.Type.FOOD:
		return total - calculate_total_army_food_cost(player_id)
	return total
