extends Control

const SCALE_TEXTURE := preload("res://images/icons/scale.png")
const SCALE_TEXTURE_HOVER := preload("res://images/icons/scale2.png")
const MAP_TEXTURE := preload("res://images/icons/map.png")
const MAP_TEXTURE_HOVER := preload("res://images/icons/map2.png")

var scale_icon: TextureRect
var map_icon: TextureRect
var trade_modal: TradeModal

func _ready() -> void:
	scale_icon = get_node("TextureRect") as TextureRect
	map_icon = get_node("TextureRect2") as TextureRect
	trade_modal = get_parent().get_node("TradeModal") as TradeModal
	_connect_scale_signals()
	_connect_map_signals()

func _connect_scale_signals() -> void:
	scale_icon.mouse_entered.connect(_on_scale_mouse_entered)
	scale_icon.mouse_exited.connect(_on_scale_mouse_exited)
	scale_icon.gui_input.connect(_on_scale_gui_input)

func _connect_map_signals() -> void:
	map_icon.mouse_entered.connect(_on_map_mouse_entered)
	map_icon.mouse_exited.connect(_on_map_mouse_exited)

func _on_scale_mouse_entered() -> void:
	scale_icon.texture = SCALE_TEXTURE_HOVER

func _on_scale_mouse_exited() -> void:
	scale_icon.texture = SCALE_TEXTURE

func _on_scale_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		trade_modal.show_modal()

func _on_map_mouse_entered() -> void:
	map_icon.texture = MAP_TEXTURE_HOVER

func _on_map_mouse_exited() -> void:
	map_icon.texture = MAP_TEXTURE
