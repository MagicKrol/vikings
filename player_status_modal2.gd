extends Control
class_name PlayerStatusModal2

# Current player resources
var current_resources: Dictionary = {
	ResourcesEnum.Type.GOLD: {"amount": 1, "income": 0},
	ResourcesEnum.Type.FOOD: {"amount": 1, "income": 0},
	ResourcesEnum.Type.WOOD: {"amount": 1, "income": 0},
	ResourcesEnum.Type.STONE: {"amount": 1, "income": 0},
	ResourcesEnum.Type.IRON: {"amount": 1, "income": 0}
}

# Population data
var current_population: Dictionary = {"amount": 0, "income": 0}

# Game manager reference for resource updates
var game_manager: GameManager = null

func _ready():
	# Get game manager reference
	game_manager = get_node("../../GameManager") as GameManager
	# In editor mode, keep this hidden and skip updates
	if game_manager and game_manager.enable_map_editor:
		visible = false
		return
	# Make visible by default as a status bar (non-editor)
	visible = true
	# Update display immediately when ready
	call_deferred("_update_display_from_game_state")

func set_resource_data(resource_type: ResourcesEnum.Type, amount: int, income: int = 0) -> void:
	"""Update resource data for a specific type"""
	current_resources[resource_type] = {"amount": amount, "income": income}
	_update_display()

func update_all_resources(resources_data: Dictionary) -> void:
	"""Update all resources at once"""
	for resource_type in resources_data:
		if resource_type in current_resources:
			current_resources[resource_type] = resources_data[resource_type]
	_update_display()

func _update_display() -> void:
	"""Update the display with current resource information"""
	
	# Update population display
	var pop_container = get_node("Panel/HBoxContainer/Population")
	var pop_value = pop_container.get_node("Value")
	var pop_change = pop_container.get_node("Change")
	
	pop_value.text = str(current_population.amount)
	if current_population.income > 0:
		pop_change.text = "(+" + str(current_population.income) + ")"
		pop_change.modulate = Color.html("#41b43e")
	elif current_population.income < 0:
		pop_change.text = "(" + str(current_population.income) + ")"
		pop_change.modulate = Color.html("#d13131")
	else:
		pop_change.text = "(+0)"
		pop_change.modulate = Color.WHITE
	
	# Update Food
	_update_resource_display("Food", ResourcesEnum.Type.FOOD)
	
	# Update Wood
	_update_resource_display("Wood", ResourcesEnum.Type.WOOD)
	
	# Update Stone
	_update_resource_display("Stone", ResourcesEnum.Type.STONE)
	
	# Update Iron
	_update_resource_display("Iron", ResourcesEnum.Type.IRON)
	
	# Update Gold
	_update_resource_display("Gold", ResourcesEnum.Type.GOLD)

func _update_resource_display(container_name: String, resource_type: ResourcesEnum.Type) -> void:
	"""Helper to update individual resource display"""
	var container = get_node("Panel/HBoxContainer/" + container_name)
	var value_label = container.get_node("Value")
	var change_label = container.get_node("Change")
	
	var resource_data = current_resources[resource_type]
	value_label.text = str(resource_data.amount)
	
	if resource_data.income > 0:
		change_label.text = "(+" + str(resource_data.income) + ")"
		change_label.modulate = Color.html("#41b43e")
	elif resource_data.income < 0:
		change_label.text = "(" + str(resource_data.income) + ")"
		change_label.modulate = Color.html("#d13131")
	else:
		change_label.text = "(+0)"
		change_label.modulate = Color.WHITE

func _update_display_from_game_state() -> void:
	"""Update display from current game state"""
	
	# Get current player
	var current_player = game_manager.player_manager.get_current_player()
	
	# Calculate actual income from owned regions
	var region_income = _calculate_region_income(current_player.get_player_id())
	
	# Calculate population data
	var population_data = _calculate_population_data(current_player.get_player_id())
	current_population = population_data
	
	# Update resource data from current player
	for resource_type in current_resources:
		var amount = current_player.get_resource_amount(resource_type)
		var income = region_income.get(resource_type, 0)
		current_resources[resource_type] = {"amount": amount, "income": income}
	
	# Update the display
	_update_display()

func refresh_from_game_state() -> void:
	"""Refresh resource display from current game state (public method)"""
	_update_display_from_game_state()

func show_and_update() -> void:
	"""Show the modal and update it with current game state (public method for castle placement)"""
	visible = true
	_update_display_from_game_state()

func _calculate_region_income(player_id: int) -> Dictionary:
	"""Calculate net income from regions owned by the player (production - costs)"""
	var income = {
		ResourcesEnum.Type.GOLD: 0,
		ResourcesEnum.Type.FOOD: 0,
		ResourcesEnum.Type.WOOD: 0,
		ResourcesEnum.Type.IRON: 0,
		ResourcesEnum.Type.STONE: 0
	}
	
	# Get region manager and map generator from game manager
	var region_manager = game_manager.click_manager.get_region_manager()
	var map_generator = game_manager.get_node("../Map") as MapGenerator
	
	# Get all regions owned by this player
	var owned_regions = region_manager.get_player_regions(player_id)
	
	# Get regions node from map generator
	var regions_node = map_generator.get_node("Regions")
	
	# Sum up resources from all owned regions
	for region_id in owned_regions:
		var region_node = _find_region_by_id(regions_node, region_id)
		if region_node != null:
			for resource_type in income.keys():
				var region_resource_amount = region_node.get_resource_amount(resource_type)
				income[resource_type] += region_resource_amount
			
			# Add population-based gold income
			var pop_gold_income = _calculate_population_gold_income(region_node)
			income[ResourcesEnum.Type.GOLD] += pop_gold_income
	
	# Subtract army food costs from food income to show net food income
	var total_army_food_cost = game_manager.player_manager.calculate_total_army_food_cost(player_id)
	var food_cost_int = int(ceil(total_army_food_cost))
	income[ResourcesEnum.Type.FOOD] -= food_cost_int
	
	return income

func _find_region_by_id(regions_node: Node, region_id: int) -> Region:
	"""Find a region node by its ID"""
	for child in regions_node.get_children():
		if child is Region and child.get_region_id() == region_id:
			return child
	return null

func _calculate_population_data(player_id: int) -> Dictionary:
	"""Calculate total population and last turn growth for the player"""
	var population_data = {"amount": 0, "income": 0}
	
	# Get region manager and map generator from game manager
	var region_manager = game_manager.click_manager.get_region_manager()
	var map_generator = game_manager.get_node("../Map") as MapGenerator
	
	# Get all regions owned by this player
	var owned_regions = region_manager.get_player_regions(player_id)
	
	# Get regions node from map generator
	var regions_node = map_generator.get_node("Regions")
	
	# Calculate total population and last turn growth from all owned regions
	for region_id in owned_regions:
		var region_node = _find_region_by_id(regions_node, region_id)
		if region_node != null:
			# Add population
			population_data.amount += region_node.get_population()
			
			# Add last turn's population growth
			population_data.income += region_node.last_population_growth
	
	return population_data

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
