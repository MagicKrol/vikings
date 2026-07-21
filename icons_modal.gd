extends Control

const SCALE_TEXTURE := preload("res://images/icons/scale.png")
const SCALE_TEXTURE_HOVER := preload("res://images/icons/scale2.png")
const SETTINGS_TEXTURE := preload("res://images/icons/settings.png")
const SETTINGS_TEXTURE_HOVER := preload("res://images/icons/settings2.png")
const OBJECTIVES_TEXTURE := preload("res://images/icons/objectives.png")
const OBJECTIVES_TEXTURE_HOVER := preload("res://images/icons/objectives2.png")
const MAP_TEXTURE := preload("res://images/icons/map.png")
const MAP_TEXTURE_HOVER := preload("res://images/icons/map2.png")

var scale_icon: TextureRect
var settings_icon: TextureRect
var objectives_icon: TextureRect
var map_icon: TextureRect
var trade_modal: TradeModal
var game_menu_modal: Node
var map_filter_modal: MapFilterModal
var ui_manager: UIManager
var game_manager: GameManager
var visual_manager: VisualManager

func _ready() -> void:
	scale_icon = get_node("TextureRect") as TextureRect
	settings_icon = get_node("Settings") as TextureRect
	objectives_icon = get_node("Objectives") as TextureRect
	map_icon = get_node("Map") as TextureRect
	trade_modal = get_parent().get_node("TradeModal") as TradeModal
	game_menu_modal = get_parent().get_node("GameMenuModal") as Node
	map_filter_modal = get_parent().get_node("Map") as MapFilterModal
	ui_manager = get_parent().get_node("UIManager") as UIManager
	game_manager = get_parent().get_parent().get_node("GameManager") as GameManager
	visual_manager = game_manager.get_visual_manager()
	_connect_scale_signals()
	_connect_settings_signals()
	_connect_objectives_signals()
	_connect_map_signals()

func _connect_scale_signals() -> void:
	scale_icon.mouse_entered.connect(_on_scale_mouse_entered)
	scale_icon.mouse_exited.connect(_on_scale_mouse_exited)
	scale_icon.gui_input.connect(_on_scale_gui_input)

func _connect_settings_signals() -> void:
	settings_icon.mouse_entered.connect(_on_settings_mouse_entered)
	settings_icon.mouse_exited.connect(_on_settings_mouse_exited)
	settings_icon.gui_input.connect(_on_settings_gui_input)

func _connect_objectives_signals() -> void:
	objectives_icon.mouse_entered.connect(_on_objectives_mouse_entered)
	objectives_icon.mouse_exited.connect(_on_objectives_mouse_exited)
	objectives_icon.gui_input.connect(_on_objectives_gui_input)

func _on_scale_mouse_entered() -> void:
	_hide_tooltip_and_unhighlight_region()
	scale_icon.texture = SCALE_TEXTURE_HOVER

func _on_scale_mouse_exited() -> void:
	scale_icon.texture = SCALE_TEXTURE

func _on_scale_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_toggle_trade_modal()

func _unhandled_input(event: InputEvent) -> void:
	if game_manager.tutorial_enabled:
		return
	if GameParameters.is_keyboard_action_pressed(event, GameParameters.KeyboardAction.TRADE):
		if _toggle_trade_modal():
			get_viewport().set_input_as_handled()
	elif GameParameters.is_keyboard_action_pressed(event, GameParameters.KeyboardAction.MAP_OVERVIEW):
		if _toggle_map_overview_modal():
			get_viewport().set_input_as_handled()

func _toggle_trade_modal() -> bool:
	if trade_modal.visible:
		trade_modal.hide_modal()
		return true
	if not visible or game_manager.is_castle_placing_mode():
		return false
	trade_modal.show_modal()
	return true

func _toggle_map_overview_modal() -> bool:
	if map_filter_modal.visible:
		map_filter_modal.hide_modal()
		return true
	if not visible:
		return false
	map_filter_modal.show_modal()
	return true

func _on_settings_mouse_entered() -> void:
	_hide_tooltip_and_unhighlight_region()
	settings_icon.texture = SETTINGS_TEXTURE_HOVER

func _on_settings_mouse_exited() -> void:
	settings_icon.texture = SETTINGS_TEXTURE

func _on_settings_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		game_menu_modal.call("show_modal")

func _on_objectives_mouse_entered() -> void:
	_hide_tooltip_and_unhighlight_region()
	objectives_icon.texture = OBJECTIVES_TEXTURE_HOVER

func _on_objectives_mouse_exited() -> void:
	objectives_icon.texture = OBJECTIVES_TEXTURE

func _on_objectives_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		game_manager.show_intro_message_modal_again()

func _connect_map_signals() -> void:
	map_icon.mouse_entered.connect(_on_map_mouse_entered)
	map_icon.mouse_exited.connect(_on_map_mouse_exited)
	map_icon.gui_input.connect(_on_map_gui_input)

func _on_map_mouse_entered() -> void:
	_hide_tooltip_and_unhighlight_region()
	map_icon.texture = MAP_TEXTURE_HOVER

func _on_map_mouse_exited() -> void:
	map_icon.texture = MAP_TEXTURE

func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_toggle_map_overview_modal()

func _hide_tooltip_and_unhighlight_region() -> void:
	ui_manager.hide_region_tooltip()
	visual_manager.clear_region_highlight_hover()
	visual_manager.set_map_hover_region(-1)
