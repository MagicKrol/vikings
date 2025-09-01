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
	# Initialize players immediately
	_initialize_players()

func initialize_with_managers(region_mgr: RegionManager, map_gen: MapGenerator):
	"""Initialize with manager references from GameManager"""
	region_manager = region_mgr
	map_generator = map_gen

func set_army_manager(army_mgr: ArmyManager) -> void:
	"""Set the army manager reference"""
	army_manager = army_mgr

func _initialize_players() -> void:
	"""Initialize all players with default settings"""
	for i in range(1, total_players + 1):
		var player = Player.new(i, "Player " + str(i))
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

# Resource income and management
func process_resource_income() -> void:
	
	# Process income for all players
	for player_id in players:
		var player = players[player_id]
		DebugLogger.log("PlayerManagement", "Processing income for " + player.get_player_name())
		_calculate_player_income(player)

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
	
	# Region manager and map generator are required - no fallbacks
	if region_manager == null:
		push_error("[PlayerManagerNode] CRITICAL: RegionManager is null - cannot calculate region-based income")
		return
	
	if map_generator == null:
		push_error("[PlayerManagerNode] CRITICAL: MapGenerator is null - cannot access region data")
		return
	
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
			var population_gold = _calculate_population_gold_income(region_node)
			total_resources[ResourcesEnum.Type.GOLD] += population_gold
	
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

func _calculate_population_gold_income(region: Region) -> int:
	"""Calculate gold income from population based on formula: floor(population / (56 - 6 * region_level))"""
	var population = region.get_population()
	var region_level = region.get_region_level()
	
	# Convert region level enum to integer (assuming L1=1, L2=2, etc.)
	var level_int = _region_level_to_int(region_level)
	
	# Formula: floor(Population / (56 - 6 * region_level))
	var divisor = 56 - (6 * level_int)
	
	# Prevent division by zero or negative divisors
	if divisor <= 0:
		return 0
	
	var gold_income = int(population / divisor)
	return max(0, gold_income)

func _region_level_to_int(region_level: RegionLevelEnum.Level) -> int:
	"""Convert region level enum to integer"""
	match region_level:
		RegionLevelEnum.Level.L1:
			return 1
		RegionLevelEnum.Level.L2:
			return 2
		RegionLevelEnum.Level.L3:
			return 3
		RegionLevelEnum.Level.L4:
			return 4
		RegionLevelEnum.Level.L5:
			return 5
		_:
			return 1  # Default to level 1

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

func calculate_total_army_food_cost(player_id: int) -> float:
	"""Calculate total food cost for all armies and garrisons owned by a player"""
	var total_food_cost = 0.0
	
	# Get all regions owned by this player and sum garrison food costs
	if region_manager != null:
		var owned_regions = region_manager.get_player_regions(player_id)
		
		if map_generator != null:
			var regions_node = map_generator.get_node_or_null("Regions")
			if regions_node != null:
				for region_id in owned_regions:
					var region_node = _find_region_by_id(regions_node, region_id)
					if region_node != null:
						var garrison = region_node.get_garrison()
						if garrison != null:
							var garrison_food_cost = garrison.get_total_food_cost()
							total_food_cost += garrison_food_cost
	
	# Add standalone armies
	if army_manager != null:
		var all_armies = army_manager.get_all_armies()
		for army in all_armies:
			if army.get_player_id() == player_id:
				var army_composition = army.get_composition()
				if army_composition != null:
					var army_food_cost = army_composition.get_total_food_cost()
					total_food_cost += army_food_cost
	
	return total_food_cost
