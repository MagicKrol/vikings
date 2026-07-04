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
var resource_tooltips: Dictionary = {}

const POSITIVE_VALUE_COLOR: Color = Color("#41b43e")
const NEGATIVE_VALUE_COLOR: Color = Color("#d13131")
const RESOURCE_TOOLTIP_WIDTH: float = 259.0
const RESOURCE_TOOLTIP_TOP_Y: float = 50.0
const TOOLTIP_SCREEN_MARGIN: float = 10.0

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
	_initialize_resource_tooltips()
	_hide_resource_tooltips()
	# In editor mode, keep this hidden and skip updates
	if game_manager and game_manager.enable_map_editor:
		visible = false
		return
	# Make visible by default as a status bar (non-editor). GameManager triggers updates.
	visible = true
	GlobalSignals.player_status_refresh_requested.connect(_on_player_status_refresh_requested)
	call_deferred("refresh_from_game_state")

func _on_mouse_entered() -> void:
	DebugLogger.log("UIManager", "PlayerStatusModal2 mouse entered. Hiding tooltip")
	ui_manager.hide_tooltip_due_to(self)

func _on_panel_mouse_entered() -> void:
	DebugLogger.log("UIManager", "PlayerStatusModal2 Panel mouse entered. Hiding tooltip")
	ui_manager.hide_tooltip_due_to(self)

func _initialize_resource_tooltips() -> void:
	resource_tooltips = {
		ResourcesEnum.Type.FOOD: get_node("Tooltips/Food") as Control,
		ResourcesEnum.Type.WOOD: get_node("Tooltips/Wood") as Control,
		ResourcesEnum.Type.STONE: get_node("Tooltips/Stone") as Control,
		ResourcesEnum.Type.IRON: get_node("Tooltips/Iron") as Control,
		ResourcesEnum.Type.GOLD: get_node("Tooltips/Gold") as Control
	}
	_connect_resource_tooltip("Food", ResourcesEnum.Type.FOOD)
	_connect_resource_tooltip("Wood", ResourcesEnum.Type.WOOD)
	_connect_resource_tooltip("Stone", ResourcesEnum.Type.STONE)
	_connect_resource_tooltip("Iron", ResourcesEnum.Type.IRON)
	_connect_resource_tooltip("Gold", ResourcesEnum.Type.GOLD)
	_set_static_tooltip_labels()

func _connect_resource_tooltip(container_name: String, resource_type: ResourcesEnum.Type) -> void:
	var hover_area := get_node("Panel/HBoxContainer/" + container_name) as Control
	hover_area.mouse_entered.connect(_on_resource_mouse_entered.bind(resource_type, hover_area))
	hover_area.mouse_exited.connect(_on_resource_mouse_exited)

func _set_static_tooltip_labels() -> void:
	_set_tooltip_text("Tooltips/Food/Tooltip/Production/Text", "Production")
	_set_tooltip_text("Tooltips/Food/Tooltip/Armies/Text", "Armies")
	_set_tooltip_text("Tooltips/Food/Tooltip/Garrisons/Text", "Garrisons")
	_set_tooltip_text("Tooltips/Wood/Tooltip/Production/Text", "Production")
	_set_tooltip_text("Tooltips/Wood/Tooltip/Upkeep/Text", "Upkeep")
	_set_tooltip_text("Tooltips/Stone/Tooltip/Production/Text", "Production")
	_set_tooltip_text("Tooltips/Stone/Tooltip/Upkeep/Text", "Upkeep")
	_set_tooltip_text("Tooltips/Iron/Tooltip/Production/Text", "Mines")
	_set_tooltip_text("Tooltips/Gold/Tooltip/Taxes/Text", "Taxes")
	_set_tooltip_text("Tooltips/Gold/Tooltip/Production/Text", "Mines")

func _set_tooltip_text(path: String, key: String) -> void:
	var label := get_node(path) as Label
	label.text = tr(key)

func _on_resource_mouse_entered(resource_type: ResourcesEnum.Type, source_control: Control) -> void:
	ui_manager.hide_tooltip_due_to(self)
	_update_resource_tooltip(resource_type)
	_hide_resource_tooltips()
	var tooltip := resource_tooltips[resource_type] as Control
	_position_resource_tooltip(tooltip, source_control)
	tooltip.visible = true

func _position_resource_tooltip(tooltip: Control, source_control: Control) -> void:
	var source_rect: Rect2 = source_control.get_global_rect()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var tooltip_x: float = source_rect.position.x + source_rect.size.x * 0.5 - RESOURCE_TOOLTIP_WIDTH * 0.5
	tooltip_x = clampf(tooltip_x, TOOLTIP_SCREEN_MARGIN, viewport_size.x - RESOURCE_TOOLTIP_WIDTH - TOOLTIP_SCREEN_MARGIN)
	tooltip.global_position = Vector2(tooltip_x, RESOURCE_TOOLTIP_TOP_Y)

func _on_resource_mouse_exited() -> void:
	_hide_resource_tooltips()

func _hide_resource_tooltips() -> void:
	for tooltip in resource_tooltips.values():
		var tooltip_control := tooltip as Control
		tooltip_control.visible = false

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

func _update_resource_tooltip(resource_type: ResourcesEnum.Type) -> void:
	var current_player: Player = game_manager.player_manager.get_current_player()
	var player_id: int = current_player.get_player_id()
	var breakdown: Dictionary = _get_resource_tooltip_rows(player_id)
	var resource_breakdown: Dictionary = breakdown[resource_type]
	for line_name in resource_breakdown:
		var value: int = int(resource_breakdown[line_name])
		_set_tooltip_value(resource_type, line_name, value)

func _get_resource_tooltip_rows(player_id: int) -> Dictionary:
	var breakdown: Dictionary = game_manager.player_manager.get_player_economy_breakdown(player_id)
	var production: Dictionary = breakdown.get("production", {})
	var region_upkeep: Dictionary = breakdown.get("region_upkeep", {})
	var taxes: int = int(breakdown.get("taxes", 0))
	var army_food_upkeep: int = int(breakdown.get("army_food_upkeep", 0))
	var garrison_food_upkeep: int = int(breakdown.get("garrison_food_upkeep", 0))
	return {
		ResourcesEnum.Type.FOOD: {
			"Production": int(production[ResourcesEnum.Type.FOOD]) - int(region_upkeep[ResourcesEnum.Type.FOOD]),
			"Armies": -army_food_upkeep,
			"Garrisons": -garrison_food_upkeep
		},
		ResourcesEnum.Type.WOOD: {
			"Production": int(production[ResourcesEnum.Type.WOOD]),
			"Upkeep": -int(region_upkeep[ResourcesEnum.Type.WOOD])
		},
		ResourcesEnum.Type.STONE: {
			"Production": int(production[ResourcesEnum.Type.STONE]),
			"Upkeep": -int(region_upkeep[ResourcesEnum.Type.STONE])
		},
		ResourcesEnum.Type.IRON: {
			"Production": int(production[ResourcesEnum.Type.IRON])
		},
		ResourcesEnum.Type.GOLD: {
			"Taxes": taxes,
			"Production": int(production[ResourcesEnum.Type.GOLD])
		}
	}

func _set_tooltip_value(resource_type: ResourcesEnum.Type, line_name: String, value: int) -> void:
	var tooltip := resource_tooltips[resource_type] as Control
	var value_label := tooltip.get_node("Tooltip/" + line_name + "/Value") as Label
	value_label.text = _format_signed_value(value)
	if value > 0:
		value_label.modulate = POSITIVE_VALUE_COLOR
	elif value < 0:
		value_label.modulate = NEGATIVE_VALUE_COLOR
	else:
		value_label.modulate = Color.WHITE

func _format_signed_value(value: int) -> String:
	if value > 0:
		return "+" + str(value)
	return str(value)

func show_and_update() -> void:
	"""Show the modal and update it with current game state (public method for castle placement)"""
	visible = true
	_update_display_from_game_state()

func set_panel_visible(is_visible: bool) -> void:
	get_node("Panel").visible = is_visible
	if not is_visible:
		_hide_resource_tooltips()

func _on_player_status_refresh_requested() -> void:
	refresh_from_game_state()
