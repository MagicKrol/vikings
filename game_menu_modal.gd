extends Control

# Main menu elements
@onready var header_label: Label = $InnerPanel/HeaderSection/HeaderLabel
@onready var button_container: VBoxContainer = $InnerPanel/ButtonContainer
@onready var continue_button: Button = $InnerPanel/ButtonContainer/ContinueButton
@onready var options_button: Button = $InnerPanel/ButtonContainer/OptionsButton
@onready var main_menu_button: Button = $InnerPanel/ButtonContainer/MainMenuButton
@onready var exit_button: Button = $InnerPanel/ButtonContainer/ExitButton

# Options menu elements
@onready var options_container: VBoxContainer = $InnerPanel/OptionsContainer
@onready var options_back_button: Button = $InnerPanel/OptionsContainer/BackButton
@onready var audio_button: Button = $InnerPanel/OptionsContainer/AudioButton

# Audio menu elements
@onready var audio_container: VBoxContainer = $InnerPanel/AudioContainer
@onready var audio_back_button: Button = $InnerPanel/AudioContainer/BackButton
@onready var music_toggle: CheckButton = $InnerPanel/AudioContainer/AudioPanel/MusicRow/MusicToggle
@onready var music_slider: HSlider = $InnerPanel/AudioContainer/AudioPanel/MusicRow/MusicSlider
@onready var sound_toggle: CheckButton = $InnerPanel/AudioContainer/AudioPanel/SoundRow/SoundToggle
@onready var sound_slider: HSlider = $InnerPanel/AudioContainer/AudioPanel/SoundRow/SoundSlider

var sound_manager: SoundManager = null

signal main_menu_pressed
signal exit_pressed

func _ready():
	# Main menu buttons
	continue_button.pressed.connect(_on_continue_pressed)
	options_button.pressed.connect(_on_options_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Options menu buttons
	options_back_button.pressed.connect(_on_options_back_pressed)
	audio_button.pressed.connect(_on_audio_pressed)

	# Audio menu buttons and controls
	audio_back_button.pressed.connect(_on_audio_back_pressed)
	music_toggle.toggled.connect(_on_music_toggled)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sound_toggle.toggled.connect(_on_sound_toggled)
	sound_slider.value_changed.connect(_on_sound_volume_changed)

	# Get sound manager reference
	sound_manager = get_node_or_null("/root/Main/SoundManager")

func _on_continue_pressed():
	DebugLogger.log("UISystem", "Game Menu - Continue pressed")
	hide_modal()

func _on_options_pressed():
	DebugLogger.log("UISystem", "Game Menu - Options pressed")
	_show_options_menu()

func _on_main_menu_pressed():
	DebugLogger.log("UISystem", "Game Menu - Main Menu pressed")
	main_menu_pressed.emit()

func _on_exit_pressed():
	DebugLogger.log("UISystem", "Game Menu - Exit pressed")
	exit_pressed.emit()

func _on_options_back_pressed():
	DebugLogger.log("UISystem", "Game Menu - Options Back pressed")
	_show_main_menu()

func _on_audio_pressed():
	DebugLogger.log("UISystem", "Game Menu - Audio pressed")
	_show_audio_menu()

func _on_audio_back_pressed():
	DebugLogger.log("UISystem", "Game Menu - Audio Back pressed")
	_show_options_menu()

func _on_music_toggled(enabled: bool):
	if sound_manager:
		sound_manager.music_enabled = enabled
		if not enabled:
			sound_manager.stop_all_music()
		else:
			sound_manager.play_game_music()
	DebugLogger.log("UISystem", "Music " + ("enabled" if enabled else "disabled"))

func _on_music_volume_changed(value: float):
	if sound_manager and sound_manager.music_player:
		sound_manager.music_player.volume_db = linear_to_db(value / 100.0)
	DebugLogger.log("UISystem", "Music volume: " + str(value))

func _on_sound_toggled(enabled: bool):
	if sound_manager:
		sound_manager.sound_enabled = enabled
	DebugLogger.log("UISystem", "Sound " + ("enabled" if enabled else "disabled"))

func _on_sound_volume_changed(value: float):
	if sound_manager:
		if sound_manager.click_player:
			sound_manager.click_player.volume_db = linear_to_db(value / 100.0)
		if sound_manager.horn_player:
			sound_manager.horn_player.volume_db = linear_to_db(value / 100.0)
		if sound_manager.battle_player:
			sound_manager.battle_player.volume_db = linear_to_db(value / 100.0)
	DebugLogger.log("UISystem", "Sound volume: " + str(value))

func _show_main_menu():
	header_label.text = "Game Menu"
	button_container.visible = true
	options_container.visible = false
	audio_container.visible = false

func _show_options_menu():
	header_label.text = "Options"
	button_container.visible = false
	options_container.visible = true
	audio_container.visible = false

func _show_audio_menu():
	header_label.text = "Audio"
	button_container.visible = false
	options_container.visible = false
	audio_container.visible = true
	_sync_audio_controls()

func _sync_audio_controls():
	if sound_manager:
		music_toggle.button_pressed = sound_manager.music_enabled
		sound_toggle.button_pressed = sound_manager.sound_enabled
		if sound_manager.music_player:
			music_slider.value = db_to_linear(sound_manager.music_player.volume_db) * 100.0
		if sound_manager.click_player:
			sound_slider.value = db_to_linear(sound_manager.click_player.volume_db) * 100.0

func show_modal():
	visible = true
	get_tree().paused = true
	_show_main_menu()
	# Re-acquire sound manager reference when showing modal
	if not sound_manager:
		sound_manager = get_node_or_null("/root/Main/SoundManager")

func hide_modal():
	visible = false
	get_tree().paused = false
