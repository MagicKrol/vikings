extends Control
class_name SpeedModal

@onready var normal_button: Button = get_node("Panel/List/ButtonSection/HBoxContainer3/ButtonBorder/NormalButton")
@onready var fast_button: Button = get_node("Panel/List/ButtonSection/HBoxContainer/ButtonBorder/FastButton")
@onready var very_fast_button: Button = get_node("Panel/List/ButtonSection/HBoxContainer2/ButtonBorder/VeryFastButton")

signal speed_changed(context: String, value: float)

var _button_definitions: Dictionary = {}
var _selected_keys: Dictionary = {"ai": "normal", "battle": "normal"}
var _context: String = "ai"

func _ready() -> void:
	_build_button_definitions()
	_connect_buttons()
	_sync_selection_from_parameters()

func set_context(context: String) -> void:
	if context != "ai" and context != "battle":
		return
	_context = context
	_build_button_definitions()
	_sync_selection_from_parameters()

func _on_speed_selected(key: String) -> void:
	if not _button_definitions.has(key):
		return
	_selected_keys[_context] = key
	var multiplier: float = _button_definitions[key]["multiplier"]
	if _context == "battle":
		GameParameters.set_battle_round_time(multiplier)
	else:
		GameParameters.set_ai_move_speed_multiplier(multiplier)
	_update_button_styles(true)
	speed_changed.emit(_context, multiplier)

func _sync_selection_from_parameters() -> void:
	var current_multiplier := _get_current_value_for_context()
	for key in _button_definitions.keys():
		var target: float = _button_definitions[key]["multiplier"]
		if is_equal_approx(current_multiplier, target):
			_selected_keys[_context] = key
			break
	_update_button_styles(false)

func _update_button_styles(force_focus: bool = false) -> void:
	for key in _button_definitions.keys():
		var button: Button = _button_definitions[key]["button"]
		var selected: bool = key == _selected_keys.get(_context, "normal")
		button.button_pressed = selected
		if force_focus and selected:
			button.grab_focus()
		button.queue_redraw()

func _connect_buttons() -> void:
	for key in _button_definitions.keys():
		var button: Button = _button_definitions[key]["button"]
		button.pressed.connect(Callable(self, "_on_speed_selected").bind(key))

func _build_button_definitions() -> void:
	if _context == "battle":
		_button_definitions = {
			"normal": {"button": normal_button, "multiplier": GameParameters.BATTLE_ROUND_TIME_NORMAL},
			"fast": {"button": fast_button, "multiplier": GameParameters.BATTLE_ROUND_TIME_FAST},
			"very_fast": {"button": very_fast_button, "multiplier": GameParameters.BATTLE_ROUND_TIME_VERY_FAST}
		}
	else:
		_button_definitions = {
			"normal": {"button": normal_button, "multiplier": GameParameters.AI_MOVE_SPEED_NORMAL},
			"fast": {"button": fast_button, "multiplier": GameParameters.AI_MOVE_SPEED_FAST},
			"very_fast": {"button": very_fast_button, "multiplier": GameParameters.AI_MOVE_SPEED_VERY_FAST}
		}

func _get_current_value_for_context() -> float:
	if _context == "battle":
		return GameParameters.get_battle_round_time()
	return GameParameters.get_ai_move_speed_multiplier()
