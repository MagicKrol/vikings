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
var initial_economy_processed: bool = false

# Game manager reference for resource updates
var game_manager: GameManager = null
var ui_manager: UIManager = null

func _ready():
	# Get game manager reference
	game_manager = get_node("../../GameManager") as GameManager
	ui_manager = get_node("../UIManager") as UIManager
	mouse_entered.connect(_on_mouse_entered)
	DebugLogger.log("UIManager", "PlayerStatusModal2 ready, mouse_entered connected")
	DebugLogger.log("UIManager", "PlayerStatusModal2 mouse_filter=" + str(mouse_filter))
	var panel = get_node("Panel") as Control
	panel.mouse_entered.connect(_on_panel_mouse_entered)
	DebugLogger.log("UIManager", "PlayerStatusModal2 Panel mouse_filter=" + str(panel.mouse_filter))
	# In editor mode, keep this hidden and skip updates
	if game_manager and game_manager.enable_map_editor:
		visible = false
		return
	# Make visible by default as a status bar (non-editor). GameManager triggers updates.
	visible = true

func _on_mouse_entered() -> void:
	DebugLogger.log("UIManager", "PlayerStatusModal2 mouse entered. Hiding tooltip")
	ui_manager.hide_tooltip_due_to(self)

func _on_panel_mouse_entered() -> void:
	DebugLogger.log("UIManager", "PlayerStatusModal2 Panel mouse entered. Hiding tooltip")
	ui_manager.hide_tooltip_due_to(self)

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
	# Ensure game manager reference is set (resolve on-demand)
	game_manager = get_node("../../GameManager") as GameManager

	# Get current player
	var current_player = game_manager.player_manager.get_current_player()
	var snapshot = game_manager.player_manager.get_player_economy_snapshot(current_player.get_player_id())
	var projected_income: Dictionary = snapshot.get("income", {})
	var population_data: Dictionary = snapshot.get("population", {})
	var balances: Dictionary = snapshot.get("balances", {})
	current_population.amount = int(population_data.get("amount", 0))
	current_population.income = int(population_data.get("growth", 0))
	for resource_type in current_resources:
		var amount = int(balances.get(resource_type, current_player.get_resource_amount(resource_type)))
		var income = int(projected_income.get(resource_type, 0))
		current_resources[resource_type] = {"amount": amount, "income": income}
	
	# Update the display
	_update_display()
	initial_economy_processed = true

func refresh_from_game_state() -> void:
	"""Refresh resource display from current game state (public method)"""
	_update_display_from_game_state()

func show_and_update() -> void:
	"""Show the modal and update it with current game state (public method for castle placement)"""
	visible = true
	_update_display_from_game_state()

func set_panel_visible(is_visible: bool) -> void:
	get_node("Panel").visible = is_visible
