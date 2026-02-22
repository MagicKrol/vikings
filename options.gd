extends Control
class_name OptionsPanel

signal back_requested

const CLOUDS_SCRIPT: Script = preload("res://clouds.gd")

var sound_manager: SoundManager
var _apply_runtime_clouds: bool = false

@onready var back_button: Button = get_node("Scenario/VBoxContainer/HBoxContainer2/Back") as Button
@onready var sound_value_label: Label = get_node("Scenario/VBoxContainer/Sound/Labels/Header2") as Label
@onready var sound_slider: HSlider = get_node("Scenario/VBoxContainer/Sound/HSlider") as HSlider
@onready var music_value_label: Label = get_node("Scenario/VBoxContainer/Music/Labels/Header2") as Label
@onready var music_slider: HSlider = get_node("Scenario/VBoxContainer/Music/HSlider") as HSlider
@onready var clouds_show_button: Button = get_node("Scenario/VBoxContainer/Clouds/Show") as Button
@onready var clouds_hide_button: Button = get_node("Scenario/VBoxContainer/Clouds/Hide") as Button
@onready var ai_speed_normal_button: Button = get_node("Scenario/VBoxContainer/AiTurnSpeed/Normal") as Button
@onready var ai_speed_fast_button: Button = get_node("Scenario/VBoxContainer/AiTurnSpeed/Fast") as Button
@onready var ai_speed_very_fast_button: Button = get_node("Scenario/VBoxContainer/AiTurnSpeed/VeryFast") as Button
@onready var battle_speed_normal_button: Button = get_node("Scenario/VBoxContainer/BattleSpeed/Normal") as Button
@onready var battle_speed_fast_button: Button = get_node("Scenario/VBoxContainer/BattleSpeed/Fast") as Button
@onready var battle_speed_very_fast_button: Button = get_node("Scenario/VBoxContainer/BattleSpeed/VeryFast") as Button

var _cloud_buttons_group: ButtonGroup
var _ai_speed_buttons_group: ButtonGroup
var _battle_speed_buttons_group: ButtonGroup

func _ready() -> void:
	_cloud_buttons_group = ButtonGroup.new()
	_cloud_buttons_group.allow_unpress = false
	clouds_show_button.button_group = _cloud_buttons_group
	clouds_hide_button.button_group = _cloud_buttons_group
	_ai_speed_buttons_group = ButtonGroup.new()
	_ai_speed_buttons_group.allow_unpress = false
	ai_speed_normal_button.button_group = _ai_speed_buttons_group
	ai_speed_fast_button.button_group = _ai_speed_buttons_group
	ai_speed_very_fast_button.button_group = _ai_speed_buttons_group
	_battle_speed_buttons_group = ButtonGroup.new()
	_battle_speed_buttons_group.allow_unpress = false
	battle_speed_normal_button.button_group = _battle_speed_buttons_group
	battle_speed_fast_button.button_group = _battle_speed_buttons_group
	battle_speed_very_fast_button.button_group = _battle_speed_buttons_group
	back_button.pressed.connect(_on_back_pressed)
	sound_slider.value_changed.connect(_on_sound_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	clouds_show_button.pressed.connect(_on_clouds_show_pressed)
	clouds_hide_button.pressed.connect(_on_clouds_hide_pressed)
	ai_speed_normal_button.pressed.connect(_on_ai_speed_normal_pressed)
	ai_speed_fast_button.pressed.connect(_on_ai_speed_fast_pressed)
	ai_speed_very_fast_button.pressed.connect(_on_ai_speed_very_fast_pressed)
	battle_speed_normal_button.pressed.connect(_on_battle_speed_normal_pressed)
	battle_speed_fast_button.pressed.connect(_on_battle_speed_fast_pressed)
	battle_speed_very_fast_button.pressed.connect(_on_battle_speed_very_fast_pressed)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if get_tree().current_scene.name != "MainMenu":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hovered: Control = get_viewport().gui_get_hovered_control()
		var hovered_path: String = hovered.get_path() if hovered else "NONE"

func configure(sound_manager_ref: SoundManager, apply_runtime_clouds: bool, back_text: String) -> void:
	sound_manager = sound_manager_ref
	_apply_runtime_clouds = apply_runtime_clouds
	if not sound_manager.is_node_ready():
		await sound_manager.ready
	if not is_node_ready():
		await ready
	back_button.text = back_text
	refresh_state()

func refresh_state() -> void:
	var sound_percent: float = _db_to_percent(sound_manager.click_player.volume_db) if sound_manager.sound_enabled else 0.0
	var music_percent: float = _db_to_percent(sound_manager.music_player.volume_db) if sound_manager.music_enabled else 0.0
	sound_slider.set_value_no_signal(sound_percent)
	music_slider.set_value_no_signal(music_percent)
	_update_sound_label(sound_percent)
	_update_music_label(music_percent)
	_set_cloud_buttons_state(CLOUDS_SCRIPT.is_global_clouds_enabled())
	_sync_ai_speed_buttons()
	_sync_battle_speed_buttons()

func _on_back_pressed() -> void:
	back_requested.emit()

func _on_sound_slider_changed(value: float) -> void:
	var clamped_value: float = clampf(value, 0.0, 100.0)
	sound_manager.sound_enabled = clamped_value > 0.0
	var volume_db: float = _percent_to_db(clamped_value)
	sound_manager.click_player.volume_db = volume_db
	sound_manager.horn_player.volume_db = volume_db
	sound_manager.battle_player.volume_db = volume_db
	_update_sound_label(clamped_value)

func _on_music_slider_changed(value: float) -> void:
	var clamped_value: float = clampf(value, 0.0, 100.0)
	var was_enabled: bool = sound_manager.music_enabled
	sound_manager.music_enabled = clamped_value > 0.0
	sound_manager.music_player.volume_db = _percent_to_db(clamped_value)
	if not sound_manager.music_enabled:
		sound_manager.stop_all_music()
	elif not was_enabled:
		if get_tree().current_scene.name == "MainMenu":
			sound_manager.play_main_menu_music()
		else:
			sound_manager.play_game_music()
	_update_music_label(clamped_value)

func _on_clouds_show_pressed() -> void:
	_set_clouds_enabled(true)

func _on_clouds_hide_pressed() -> void:
	_set_clouds_enabled(false)

func _set_clouds_enabled(enabled: bool) -> void:
	CLOUDS_SCRIPT.set_global_clouds_enabled(enabled)
	if _apply_runtime_clouds:
		var runtime_clouds: Node = get_tree().current_scene.get_node("Map/Clouds") as Node
		runtime_clouds.call("set_clouds_enabled", enabled)
	_set_cloud_buttons_state(enabled)

func _set_cloud_buttons_state(show_clouds: bool) -> void:
	clouds_show_button.button_pressed = show_clouds
	clouds_hide_button.button_pressed = not show_clouds

func _on_ai_speed_normal_pressed() -> void:
	_set_ai_turn_speed(GameParameters.AI_MOVE_SPEED_NORMAL)

func _on_ai_speed_fast_pressed() -> void:
	_set_ai_turn_speed(GameParameters.AI_MOVE_SPEED_FAST)

func _on_ai_speed_very_fast_pressed() -> void:
	_set_ai_turn_speed(GameParameters.AI_MOVE_SPEED_VERY_FAST)

func _on_battle_speed_normal_pressed() -> void:
	_set_battle_speed(GameParameters.BATTLE_ROUND_TIME_NORMAL)

func _on_battle_speed_fast_pressed() -> void:
	_set_battle_speed(GameParameters.BATTLE_ROUND_TIME_FAST)

func _on_battle_speed_very_fast_pressed() -> void:
	_set_battle_speed(GameParameters.BATTLE_ROUND_TIME_VERY_FAST)

func _set_ai_turn_speed(multiplier: float) -> void:
	GameParameters.set_ai_move_speed_multiplier(multiplier)
	_sync_ai_speed_buttons()

func _set_battle_speed(seconds: float) -> void:
	GameParameters.set_battle_round_time(seconds)
	_sync_battle_speed_buttons()

func _sync_ai_speed_buttons() -> void:
	var current_value: float = GameParameters.get_ai_move_speed_multiplier()
	if is_equal_approx(current_value, GameParameters.AI_MOVE_SPEED_FAST):
		_set_ai_speed_buttons_state("fast")
	elif is_equal_approx(current_value, GameParameters.AI_MOVE_SPEED_VERY_FAST):
		_set_ai_speed_buttons_state("very_fast")
	else:
		_set_ai_speed_buttons_state("normal")

func _sync_battle_speed_buttons() -> void:
	var current_value: float = GameParameters.get_battle_round_time()
	if is_equal_approx(current_value, GameParameters.BATTLE_ROUND_TIME_FAST):
		_set_battle_speed_buttons_state("fast")
	elif is_equal_approx(current_value, GameParameters.BATTLE_ROUND_TIME_VERY_FAST):
		_set_battle_speed_buttons_state("very_fast")
	else:
		_set_battle_speed_buttons_state("normal")

func _set_ai_speed_buttons_state(selected_key: String) -> void:
	ai_speed_normal_button.button_pressed = selected_key == "normal"
	ai_speed_fast_button.button_pressed = selected_key == "fast"
	ai_speed_very_fast_button.button_pressed = selected_key == "very_fast"

func _set_battle_speed_buttons_state(selected_key: String) -> void:
	battle_speed_normal_button.button_pressed = selected_key == "normal"
	battle_speed_fast_button.button_pressed = selected_key == "fast"
	battle_speed_very_fast_button.button_pressed = selected_key == "very_fast"

func _update_sound_label(value: float) -> void:
	sound_value_label.text = str(int(round(value))) + "%"

func _update_music_label(value: float) -> void:
	music_value_label.text = str(int(round(value))) + "%"

func _percent_to_db(percent: float) -> float:
	if percent <= 0.0:
		return -80.0
	return linear_to_db(percent / 100.0)

func _db_to_percent(db_value: float) -> float:
	if db_value <= -79.0:
		return 0.0
	return clampf(db_to_linear(db_value) * 100.0, 0.0, 100.0)
