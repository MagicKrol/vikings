extends Control
class_name SpeedModal

@onready var normal_button: Button = get_node("Panel/List/ButtonSection/HBoxContainer3/ButtonBorder/NormalButton")
@onready var fast_button: Button = get_node("Panel/List/ButtonSection/HBoxContainer/ButtonBorder/FastButton")
@onready var very_fast_button: Button = get_node("Panel/List/ButtonSection/HBoxContainer2/ButtonBorder/VeryFastButton")

var _button_definitions: Dictionary = {}
var _selected_key: String = "normal"

func _ready() -> void:
	_button_definitions = {
		"normal": {"button": normal_button, "multiplier": GameParameters.AI_MOVE_SPEED_NORMAL},
		"fast": {"button": fast_button, "multiplier": GameParameters.AI_MOVE_SPEED_FAST},
		"very_fast": {"button": very_fast_button, "multiplier": GameParameters.AI_MOVE_SPEED_VERY_FAST}
	}
	_connect_buttons()
	_sync_selection_from_parameters()

func _on_speed_selected(key: String) -> void:
	if not _button_definitions.has(key):
		return
	_selected_key = key
	var multiplier: float = _button_definitions[key]["multiplier"]
	GameParameters.set_ai_move_speed_multiplier(multiplier)
	_update_button_styles(true)

func _sync_selection_from_parameters() -> void:
	var current_multiplier := GameParameters.get_ai_move_speed_multiplier()
	for key in _button_definitions.keys():
		var target: float = _button_definitions[key]["multiplier"]
		if is_equal_approx(current_multiplier, target):
			_selected_key = key
			break
	_update_button_styles(false)

func _update_button_styles(force_focus: bool = false) -> void:
	for key in _button_definitions.keys():
		var button: Button = _button_definitions[key]["button"]
		var selected: bool = key == _selected_key
		var color := Color.YELLOW if selected else Color.WHITE
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", color)
		button.add_theme_color_override("font_pressed_color", color)
		button.add_theme_color_override("font_focus_color", color)
		button.add_theme_color_override("font_disabled_color", color)
		if force_focus and selected:
			button.grab_focus()
		button.queue_redraw()

func _connect_buttons() -> void:
	for key in _button_definitions.keys():
		var button: Button = _button_definitions[key]["button"]
		button.pressed.connect(Callable(self, "_on_speed_selected").bind(key))
