extends Node
class_name Player

# ============================================================================
# PLAYER
# ============================================================================
# 
# Purpose: Individual player data container and resource management
# 
# Core Responsibilities:
# - Player identification and metadata (ID, name, color)
# - Resource storage and transaction handling
# - Player statistics tracking (regions, armies, population)
# - Save/load functionality with dictionary serialization
# 
# Required Functions:
# - add_resource() / remove_resource(): Resource transactions
# - can_afford() / pay_cost(): Cost validation and payment
# - get_all_resources(): Resource state access
# - to_dict() / from_dict(): Serialization support
# 
# Integration Points:
# - ResourcesEnum: Resource type definitions and starting amounts
# - PlayerManager: Multi-player coordination and management
# - GameManager: Player state access and updates
# ============================================================================

# Player identification
var player_id: int = -1
var player_name: String = ""
var player_color: Color = Color.WHITE

# Resource storage - maps ResourcesEnum.Type -> int (amount)
var resources: Dictionary = {}

# Player statistics
var regions_owned: Array[int] = []
var armies_owned: Array[Army] = []
var total_population: int = 0

func _init(id: int = -1, name: String = ""):
	player_id = id
	player_name = name if name != "" else "Player " + str(id)
	
	# Initialize resources with starting amounts
	_initialize_resources()
	
	# Set player color based on ID
	_set_player_color()

func _initialize_resources() -> void:
	"""Initialize all resources with starting amounts"""
	for resource_type in ResourcesEnum.get_all_types():
		resources[resource_type] = ResourcesEnum.get_starting_amount(resource_type)

func _set_player_color() -> void:
	"""Set player color based on player ID"""
	match player_id:
		1:
			player_color = Color.RED
		2:
			player_color = Color.from_string("#61727a", Color.BLUE)  # Custom blue-gray
		3:
			player_color = Color.GREEN
		4:
			player_color = Color.YELLOW
		_:
			player_color = Color.WHITE

# Resource management methods
func get_resource_amount(resource_type: ResourcesEnum.Type) -> int:
	"""Get current amount of a specific resource"""
	return resources.get(resource_type, 0)

func add_resources(resource_type: ResourcesEnum.Type, amount: int) -> void:
	"""Add resources to the player's storage"""
	if amount <= 0:
		return
	
	resources[resource_type] = resources.get(resource_type, 0) + amount
	DebugLogger.log("PlayerManagement", "Player " + str(player_id) + " Added " + str(amount) + " " + ResourcesEnum.type_to_string(resource_type) + " (Total: " + str(resources[resource_type]) + ")")

func remove_resources(resource_type: ResourcesEnum.Type, amount: int) -> bool:
	"""Remove resources from the player's storage. Returns true if successful."""
	if amount <= 0:
		return true
	
	var current_amount = resources.get(resource_type, 0)
	if current_amount < amount:
		return false  # Not enough resources
	
	resources[resource_type] = current_amount - amount
	DebugLogger.log("PlayerManagement", "Player " + str(player_id) + " Spent " + str(amount) + " " + ResourcesEnum.type_to_string(resource_type) + " (Remaining: " + str(resources[resource_type]) + ")")
	return true

func can_afford(resource_type: ResourcesEnum.Type, amount: int) -> bool:
	"""Check if player can afford a specific amount of resources"""
	return get_resource_amount(resource_type) >= amount

func can_afford_cost(cost: Dictionary) -> bool:
	"""Check if player can afford a cost dictionary {ResourceType: amount}"""
	for resource_type in cost:
		if not can_afford(resource_type, cost[resource_type]):
			return false
	return true

func pay_cost(cost: Dictionary) -> bool:
	"""Pay a cost dictionary. Returns true if successful."""
	# First check if we can afford it
	if not can_afford_cost(cost):
		return false
	
	# Then deduct all resources
	for resource_type in cost:
		remove_resources(resource_type, cost[resource_type])
	
	return true

func get_all_resources() -> Dictionary:
	"""Get a copy of all player resources"""
	return resources.duplicate()

func set_resource_amount(resource_type: ResourcesEnum.Type, amount: int) -> void:
	"""Set a specific resource to an exact amount (for debugging/testing)"""
	resources[resource_type] = max(0, amount)
	DebugLogger.log("PlayerManagement", "Player " + str(player_id) + " Set " + ResourcesEnum.type_to_string(resource_type) + " to " + str(amount))

# Player information methods
func get_player_id() -> int:
	"""Get the player ID"""
	return player_id

func get_player_name() -> String:
	"""Get the player name"""
	return player_name

func set_player_name(new_name: String) -> void:
	"""Set the player name"""
	player_name = new_name

func get_player_color() -> Color:
	"""Get the player's color"""
	return player_color

# Resource display methods
func get_resources_string() -> String:
	"""Get all resources as a readable string"""
	var parts: Array[String] = []
	for resource_type in ResourcesEnum.get_all_types():
		var resource_name = ResourcesEnum.type_to_string(resource_type)
		var amount = get_resource_amount(resource_type)
		parts.append(resource_name + ": " + str(amount))
	
	return "\n".join(parts)

func get_resource_summary() -> String:
	"""Get a brief summary of key resources"""
	var gold = get_resource_amount(ResourcesEnum.Type.GOLD)
	var food = get_resource_amount(ResourcesEnum.Type.FOOD)
	var wood = get_resource_amount(ResourcesEnum.Type.WOOD)
	
	return "Gold: " + str(gold) + " | Food: " + str(food) + " | Wood: " + str(wood)

# Save/Load functionality
func to_dictionary() -> Dictionary:
	"""Convert player data to dictionary for saving"""
	return {
		"player_id": player_id,
		"player_name": player_name,
		"player_color": [player_color.r, player_color.g, player_color.b, player_color.a],
		"resources": _resources_to_dict(),
		"regions_owned": regions_owned,
		"total_population": total_population
	}

func from_dictionary(data: Dictionary) -> void:
	"""Load player data from dictionary"""
	player_id = data.get("player_id", -1)
	player_name = data.get("player_name", "")
	
	var color_array = data.get("player_color", [1.0, 1.0, 1.0, 1.0])
	player_color = Color(color_array[0], color_array[1], color_array[2], color_array[3])
	
	_resources_from_dict(data.get("resources", {}))
	regions_owned = data.get("regions_owned", [])
	total_population = data.get("total_population", 0)

func _resources_to_dict() -> Dictionary:
	"""Convert resources enum keys to strings for saving"""
	var result = {}
	for resource_type in resources:
		var type_name = ResourcesEnum.type_to_string(resource_type)
		result[type_name] = resources[resource_type]
	return result

func _resources_from_dict(data: Dictionary) -> void:
	"""Convert string keys back to resource enum types"""
	resources.clear()
	_initialize_resources()  # Start with defaults
	
	for key in data:
		var resource_type = ResourcesEnum.string_to_type(key)
		resources[resource_type] = int(data[key])