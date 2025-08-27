extends Control
class_name PlayerStatusModal

# Styling constants (same as RegionModal)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

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

# UI manager reference
var ui_manager: UIManager = null
# Game manager reference for resource updates
var game_manager: GameManager = null

func _ready():
	# Get UI manager reference
	ui_manager = get_node("../UIManager") as UIManager
	
	# Get game manager reference
	game_manager = get_node("../../GameManager") as GameManager
	
	# Connect end turn button signal
	var end_turn_button = get_node("ResourceContainer/EndTurnButton")
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	
	# Make visible by default as a status bar
	visible = true
	
	# Update display immediately when ready
	call_deferred("_update_display_from_game_state")

func _draw():
	# Draw shadow first (behind everything)
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)
	
	# Draw black border
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)

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
	
	# Update population label
	var population_label = get_node("ResourceContainer/PopulationLabel")
	var pop_data = current_population
	var income_text = " (+0)"
	if pop_data.income > 0:
		income_text = " (+" + str(pop_data.income) + ")"
	elif pop_data.income < 0:
		income_text = " (" + str(pop_data.income) + ")"
	var pop_text = "Population: " + str(pop_data.amount) + income_text
	population_label.text = pop_text
	
	# Update gold label
	var gold_label = get_node("ResourceContainer/GoldLabel")
	var gold_data = current_resources[ResourcesEnum.Type.GOLD]
	income_text = " (+0)"
	if gold_data.income > 0:
		income_text = " (+" + str(gold_data.income) + ")"
	elif gold_data.income < 0:
		income_text = " (" + str(gold_data.income) + ")"
	var new_text = "Gold: " + str(gold_data.amount) + income_text
	gold_label.text = new_text
	
	# Update food label
	var food_label = get_node("ResourceContainer/FoodLabel")
	var food_data = current_resources[ResourcesEnum.Type.FOOD]
	income_text = " (+0)"
	if food_data.income > 0:
		income_text = " (+" + str(food_data.income) + ")"
	elif food_data.income < 0:
		income_text = " (" + str(food_data.income) + ")"
	new_text = "Food: " + str(food_data.amount) + income_text
	food_label.text = new_text
	
	# Update wood label
	var wood_label = get_node("ResourceContainer/WoodLabel")
	var wood_data = current_resources[ResourcesEnum.Type.WOOD]
	income_text = " (+0)"
	if wood_data.income > 0:
		income_text = " (+" + str(wood_data.income) + ")"
	elif wood_data.income < 0:
		income_text = " (" + str(wood_data.income) + ")"
	wood_label.text = "Wood: " + str(wood_data.amount) + income_text
	
	# Update stone label
	var stone_label = get_node("ResourceContainer/StoneLabel")
	var stone_data = current_resources[ResourcesEnum.Type.STONE]
	income_text = " (+0)"
	if stone_data.income > 0:
		income_text = " (+" + str(stone_data.income) + ")"
	elif stone_data.income < 0:
		income_text = " (" + str(stone_data.income) + ")"
	stone_label.text = "Stone: " + str(stone_data.amount) + income_text
	
	# Update iron label
	var iron_label = get_node("ResourceContainer/IronLabel")
	var iron_data = current_resources[ResourcesEnum.Type.IRON]
	income_text = " (+0)"
	if iron_data.income > 0:
		income_text = " (+" + str(iron_data.income) + ")"
	elif iron_data.income < 0:
		income_text = " (" + str(iron_data.income) + ")"
	iron_label.text = "Iron: " + str(iron_data.amount) + income_text
	
	# Update player turn label
	var player_turn_label = get_node("ResourceContainer/PlayerTurnLabel")
	var current_player = game_manager.get_current_player()
	var player_color = GameParameters.get_player_color(current_player)
	var color_hex = "#%02x%02x%02x" % [int(player_color.r * 255), int(player_color.g * 255), int(player_color.b * 255)]
	
	if game_manager.is_castle_placing_mode():
		player_turn_label.text = "[center][color=" + color_hex + "]Player " + str(current_player) + "[/color]\nPlace Castle[/center]"
	else:
		var turn_number = game_manager.get_current_turn()
		player_turn_label.text = "[center][color=" + color_hex + "]Player " + str(current_player) + "[/color]\nRound " + str(turn_number) + "[/center]"

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

func _on_end_turn_button_pressed():
	"""Handle end turn button press"""
	if game_manager:
		game_manager.next_turn()
	else:
		print("[PlayerStatusModal] Error: Game manager not available")
