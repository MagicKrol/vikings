extends Control
class_name OptionsPanel

signal back_requested

const CLOUDS_SCRIPT: Script = preload("res://clouds.gd")
const NO_CAPTURE_ACTION: int = -1

var sound_manager: SoundManager
var _apply_runtime_clouds: bool = false
var _captured_keyboard_action: int = NO_CAPTURE_ACTION

@onready var scenario_panel: Panel = get_node("Scenario") as Panel
@onready var keys_panel: Panel = get_node("Keys") as Panel
@onready var back_button: Button = get_node("Scenario/VBoxContainer/HBoxContainer2/Back") as Button
@onready var keys_back_button: Button = get_node("Keys/VBoxContainer/HBoxContainer2/Back") as Button
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
@onready var move_army_left_click_button: Button = get_node("Scenario/VBoxContainer/MoveArmy/LeftClick") as Button
@onready var move_army_right_click_button: Button = get_node("Scenario/VBoxContainer/MoveArmy/RightClick") as Button
@onready var configure_keys_button: Button = get_node("Scenario/VBoxContainer/KeysConfigure/Configure") as Button
@onready var continue_close_key_button: Button = get_node("Keys/VBoxContainer/Rows/ContinueClose/KeyButton") as Button
@onready var next_army_key_button: Button = get_node("Keys/VBoxContainer/Rows/NextArmy/KeyButton") as Button
@onready var switch_army_region_key_button: Button = get_node("Keys/VBoxContainer/Rows/SwitchArmyRegion/KeyButton") as Button
@onready var recruit_key_button: Button = get_node("Keys/VBoxContainer/Rows/Recruit/KeyButton") as Button
@onready var camp_rest_key_button: Button = get_node("Keys/VBoxContainer/Rows/CampRest/KeyButton") as Button
@onready var transfer_key_button: Button = get_node("Keys/VBoxContainer/Rows/Transfer/KeyButton") as Button

var _cloud_buttons_group: ButtonGroup
var _ai_speed_buttons_group: ButtonGroup
var _battle_speed_buttons_group: ButtonGroup
var _move_army_buttons_group: ButtonGroup

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
	_move_army_buttons_group = ButtonGroup.new()
	_move_army_buttons_group.allow_unpress = false
	move_army_left_click_button.button_group = _move_army_buttons_group
	move_army_right_click_button.button_group = _move_army_buttons_group
	back_button.pressed.connect(_on_back_pressed)
	keys_back_button.pressed.connect(_on_keys_back_pressed)
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
	move_army_left_click_button.pressed.connect(_on_move_army_left_click_pressed)
	move_army_right_click_button.pressed.connect(_on_move_army_right_click_pressed)
	configure_keys_button.pressed.connect(_on_configure_keys_pressed)
	continue_close_key_button.pressed.connect(_on_continue_close_key_pressed)
	next_army_key_button.pressed.connect(_on_next_army_key_pressed)
	switch_army_region_key_button.pressed.connect(_on_switch_army_region_key_pressed)
	recruit_key_button.pressed.connect(_on_recruit_key_pressed)
	camp_rest_key_button.pressed.connect(_on_camp_rest_key_pressed)
	transfer_key_button.pressed.connect(_on_transfer_key_pressed)
	_show_scenario_panel()
	_sync_keyboard_mapping_buttons()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _captured_keyboard_action == NO_CAPTURE_ACTION:
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var captured_action: int = _captured_keyboard_action
	_captured_keyboard_action = NO_CAPTURE_ACTION
	_set_keyboard_mapping(captured_action, key_event.keycode)
	get_viewport().set_input_as_handled()
	accept_event()

func configure(sound_manager_ref: SoundManager, apply_runtime_clouds: bool, back_text: String) -> void:
	sound_manager = sound_manager_ref
	_apply_runtime_clouds = apply_runtime_clouds
	if not sound_manager.is_node_ready():
		await sound_manager.ready
	if not is_node_ready():
		await ready
	back_button.text = back_text
	keys_back_button.text = back_text
	refresh_state()
	_show_scenario_panel()

func refresh_state() -> void:
	var sound_percent: float = _db_to_percent(sound_manager.get_sound_volume_db()) if sound_manager.sound_enabled else 0.0
	var music_percent: float = _db_to_percent(sound_manager.get_music_volume_db()) if sound_manager.music_enabled else 0.0
	sound_slider.set_value_no_signal(sound_percent)
	music_slider.set_value_no_signal(music_percent)
	_update_sound_label(sound_percent)
	_update_music_label(music_percent)
	_set_cloud_buttons_state(CLOUDS_SCRIPT.is_global_clouds_enabled())
	_sync_ai_speed_buttons()
	_sync_battle_speed_buttons()
	_sync_move_army_buttons()
	_sync_keyboard_mapping_buttons()

func request_back() -> void:
	_cancel_keyboard_capture()
	if keys_panel.visible:
		_show_scenario_panel()
		return
	back_requested.emit()

func _on_back_pressed() -> void:
	request_back()

func _on_keys_back_pressed() -> void:
	_cancel_keyboard_capture()
	_show_scenario_panel()

func _on_configure_keys_pressed() -> void:
	_cancel_keyboard_capture()
	_sync_keyboard_mapping_buttons()
	_show_keys_panel()

func _on_continue_close_key_pressed() -> void:
	_begin_keyboard_capture(GameParameters.KeyboardAction.CONTINUE_CLOSE)

func _on_next_army_key_pressed() -> void:
	_begin_keyboard_capture(GameParameters.KeyboardAction.NEXT_ARMY)

func _on_switch_army_region_key_pressed() -> void:
	_begin_keyboard_capture(GameParameters.KeyboardAction.SWITCH_ARMY_REGION)

func _on_recruit_key_pressed() -> void:
	_begin_keyboard_capture(GameParameters.KeyboardAction.RECRUIT)

func _on_camp_rest_key_pressed() -> void:
	_begin_keyboard_capture(GameParameters.KeyboardAction.CAMP_REST)

func _on_transfer_key_pressed() -> void:
	_begin_keyboard_capture(GameParameters.KeyboardAction.TRANSFER)

func _begin_keyboard_capture(action: int) -> void:
	_captured_keyboard_action = action
	_sync_keyboard_mapping_buttons()
	_get_button_for_keyboard_action(action).grab_focus()

func _cancel_keyboard_capture() -> void:
	if _captured_keyboard_action == NO_CAPTURE_ACTION:
		return
	_captured_keyboard_action = NO_CAPTURE_ACTION
	_sync_keyboard_mapping_buttons()

func _set_keyboard_mapping(action: int, keycode: int) -> void:
	if keycode != KEY_NONE:
		for other_action in _get_keyboard_actions():
			if other_action == action:
				continue
			if GameParameters.get_keyboard_keycode(other_action) == keycode:
				GameParameters.set_keyboard_keycode(other_action, KEY_NONE)
	GameParameters.set_keyboard_keycode(action, keycode)
	_sync_keyboard_mapping_buttons()
	SaveGameManager.save_settings(sound_manager)

func _get_keyboard_actions() -> Array[int]:
	return [
		GameParameters.KeyboardAction.CONTINUE_CLOSE,
		GameParameters.KeyboardAction.NEXT_ARMY,
		GameParameters.KeyboardAction.SWITCH_ARMY_REGION,
		GameParameters.KeyboardAction.RECRUIT,
		GameParameters.KeyboardAction.CAMP_REST,
		GameParameters.KeyboardAction.TRANSFER
	]

func _get_button_for_keyboard_action(action: int) -> Button:
	match action:
		GameParameters.KeyboardAction.CONTINUE_CLOSE:
			return continue_close_key_button
		GameParameters.KeyboardAction.NEXT_ARMY:
			return next_army_key_button
		GameParameters.KeyboardAction.SWITCH_ARMY_REGION:
			return switch_army_region_key_button
		GameParameters.KeyboardAction.RECRUIT:
			return recruit_key_button
		GameParameters.KeyboardAction.CAMP_REST:
			return camp_rest_key_button
		GameParameters.KeyboardAction.TRANSFER:
			return transfer_key_button
	return continue_close_key_button

func _sync_keyboard_mapping_buttons() -> void:
	_update_keyboard_button(GameParameters.KeyboardAction.CONTINUE_CLOSE, continue_close_key_button)
	_update_keyboard_button(GameParameters.KeyboardAction.NEXT_ARMY, next_army_key_button)
	_update_keyboard_button(GameParameters.KeyboardAction.SWITCH_ARMY_REGION, switch_army_region_key_button)
	_update_keyboard_button(GameParameters.KeyboardAction.RECRUIT, recruit_key_button)
	_update_keyboard_button(GameParameters.KeyboardAction.CAMP_REST, camp_rest_key_button)
	_update_keyboard_button(GameParameters.KeyboardAction.TRANSFER, transfer_key_button)

func _update_keyboard_button(action: int, button: Button) -> void:
	if _captured_keyboard_action == action:
		button.text = tr("Press Key")
		return
	button.text = _format_keyboard_button_text(GameParameters.get_keyboard_keycode(action))

func _format_keyboard_button_text(keycode: int) -> String:
	if keycode == KEY_NONE:
		return "..."
	var key_name: String = OS.get_keycode_string(keycode)
	if keycode == KEY_SPACE:
		key_name = tr("Spacebar")
	if key_name.strip_edges() == "":
		return "..."
	return "[" + key_name + "]"

func _show_scenario_panel() -> void:
	scenario_panel.visible = true
	keys_panel.visible = false

func _show_keys_panel() -> void:
	scenario_panel.visible = false
	keys_panel.visible = true

func _on_sound_slider_changed(value: float) -> void:
	var clamped_value: float = clampf(value, 0.0, 100.0)
	sound_manager.sound_enabled = clamped_value > 0.0
	var volume_db: float = _percent_to_db(clamped_value)
	sound_manager.set_sound_volume_db(volume_db)
	_update_sound_label(clamped_value)
	SaveGameManager.save_settings(sound_manager)

func _on_music_slider_changed(value: float) -> void:
	var clamped_value: float = clampf(value, 0.0, 100.0)
	var was_enabled: bool = sound_manager.music_enabled
	sound_manager.music_enabled = clamped_value > 0.0
	sound_manager.set_music_volume_db(_percent_to_db(clamped_value))
	if not sound_manager.music_enabled:
		sound_manager.stop_all_music()
	elif not was_enabled:
		if get_tree().current_scene.name == "MainMenu":
			sound_manager.play_main_menu_music()
		else:
			sound_manager.play_game_music()
	_update_music_label(clamped_value)
	SaveGameManager.save_settings(sound_manager)

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
	SaveGameManager.save_settings(sound_manager)

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

func _on_move_army_left_click_pressed() -> void:
	_set_move_army_trigger(GameParameters.ArmyMoveTrigger.LEFT_CLICK)

func _on_move_army_right_click_pressed() -> void:
	_set_move_army_trigger(GameParameters.ArmyMoveTrigger.RIGHT_CLICK)

func _set_ai_turn_speed(multiplier: float) -> void:
	GameParameters.set_ai_move_speed_multiplier(multiplier)
	_sync_ai_speed_buttons()
	SaveGameManager.save_settings(sound_manager)

func _set_battle_speed(seconds: float) -> void:
	GameParameters.set_battle_round_time(seconds)
	_sync_battle_speed_buttons()
	SaveGameManager.save_settings(sound_manager)

func _set_move_army_trigger(trigger: int) -> void:
	GameParameters.set_army_move_trigger(trigger)
	_sync_move_army_buttons()
	SaveGameManager.save_settings(sound_manager)

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

func _sync_move_army_buttons() -> void:
	var move_trigger: int = GameParameters.get_army_move_trigger()
	if move_trigger == GameParameters.ArmyMoveTrigger.RIGHT_CLICK:
		_set_move_army_buttons_state("right")
		return
	_set_move_army_buttons_state("left")

func _set_ai_speed_buttons_state(selected_key: String) -> void:
	ai_speed_normal_button.button_pressed = selected_key == "normal"
	ai_speed_fast_button.button_pressed = selected_key == "fast"
	ai_speed_very_fast_button.button_pressed = selected_key == "very_fast"

func _set_battle_speed_buttons_state(selected_key: String) -> void:
	battle_speed_normal_button.button_pressed = selected_key == "normal"
	battle_speed_fast_button.button_pressed = selected_key == "fast"
	battle_speed_very_fast_button.button_pressed = selected_key == "very_fast"

func _set_move_army_buttons_state(selected_key: String) -> void:
	move_army_left_click_button.button_pressed = selected_key == "left"
	move_army_right_click_button.button_pressed = selected_key == "right"

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
