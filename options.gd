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

var _cloud_buttons_group: ButtonGroup

func _ready() -> void:
	_cloud_buttons_group = ButtonGroup.new()
	_cloud_buttons_group.allow_unpress = false
	clouds_show_button.button_group = _cloud_buttons_group
	clouds_hide_button.button_group = _cloud_buttons_group
	back_button.pressed.connect(_on_back_pressed)
	sound_slider.value_changed.connect(_on_sound_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	clouds_show_button.pressed.connect(_on_clouds_show_pressed)
	clouds_hide_button.pressed.connect(_on_clouds_hide_pressed)

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
