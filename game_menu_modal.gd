extends Control

# Main menu elements
@onready var top_texture: TextureRect = $Top
@onready var header_label: Label = $InnerPanel/HeaderSection/HeaderLabel
@onready var button_container: VBoxContainer = $InnerPanel/ButtonContainer
@onready var continue_button: Button = $InnerPanel/ButtonContainer/ContinueButton
@onready var options_button: Button = $InnerPanel/ButtonContainer/OptionsButton
@onready var load_game_button: Button = $InnerPanel/ButtonContainer/SaveGameButton
@onready var save_game_button: Button = $InnerPanel/ButtonContainer/MainMenuButton
@onready var help_button: Button = $InnerPanel/ButtonContainer/Help
@onready var exit_button: Button = $InnerPanel/ButtonContainer/ExitButton
@onready var options_panel: OptionsPanel = get_node("../Options") as OptionsPanel
@onready var game_guide_menu_modal: GameGuideMenuModal = get_node("../GameGuideMenuModal") as GameGuideMenuModal

var sound_manager: SoundManager
var ui_manager: UIManager
var _load_enabled: bool = true
var _save_enabled: bool = true

signal main_menu_pressed
signal exit_pressed
signal load_game_pressed
signal save_game_pressed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	continue_button.pressed.connect(_on_continue_pressed)
	options_button.pressed.connect(_on_options_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	save_game_button.pressed.connect(_on_save_game_pressed)
	help_button.pressed.connect(_on_help_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	options_panel.back_requested.connect(_on_options_back_pressed)
	game_guide_menu_modal.back_requested.connect(_on_game_guide_menu_back_requested)
	sound_manager = get_node("/root/Main/SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	options_panel.configure(sound_manager, true, tr("Back"))
	options_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			hide_modal()
			get_viewport().set_input_as_handled()

func _on_continue_pressed() -> void:
	DebugLogger.log("UISystem", "Game Menu - Continue pressed")
	hide_modal()

func _on_options_pressed() -> void:
	DebugLogger.log("UISystem", "Game Menu - Options pressed")
	_show_options_menu()

func _on_main_menu_pressed() -> void:
	DebugLogger.log("UISystem", "Game Menu - Main Menu pressed")
	main_menu_pressed.emit()

func _on_load_game_pressed() -> void:
	if not _load_enabled:
		return
	DebugLogger.log("UISystem", "Game Menu - Load Game pressed")
	load_game_pressed.emit()

func _on_save_game_pressed() -> void:
	if not _save_enabled:
		return
	DebugLogger.log("UISystem", "Game Menu - Save Game pressed")
	save_game_pressed.emit()

func _on_help_pressed() -> void:
	DebugLogger.log("UISystem", "Game Menu - Game Guide pressed")
	visible = false
	game_guide_menu_modal.show_modal()

func _on_exit_pressed() -> void:
	DebugLogger.log("UISystem", "Game Menu - Exit pressed")
	exit_pressed.emit()

func _on_options_back_pressed() -> void:
	DebugLogger.log("UISystem", "Game Menu - Options Back pressed")
	_show_main_menu()

func _show_main_menu() -> void:
	header_label.text = tr("Game Menu")
	header_label.visible = true
	top_texture.visible = true
	button_container.visible = true
	options_panel.visible = false

func _show_options_menu() -> void:
	options_panel.configure(sound_manager, true, tr("Back"))
	header_label.text = ""
	header_label.visible = true
	top_texture.visible = false
	button_container.visible = false
	options_panel.visible = true

func _on_game_guide_menu_back_requested() -> void:
	visible = true
	ui_manager.set_modal_active(true)
	move_to_front()
	_show_main_menu()

func set_save_load_enabled(enabled: bool) -> void:
	_load_enabled = enabled
	_save_enabled = enabled
	load_game_button.disabled = not enabled
	save_game_button.disabled = not enabled

func set_save_enabled(enabled: bool) -> void:
	_save_enabled = enabled
	save_game_button.disabled = not enabled

func show_modal() -> void:
	visible = true
	ui_manager.set_modal_active(true)
	get_tree().paused = true
	var game_manager_node: GameManager = get_node("/root/Main/GameManager") as GameManager
	set_save_load_enabled(not game_manager_node.tutorial_enabled)
	set_save_enabled(not game_manager_node.tutorial_enabled and not game_manager_node.is_save_blocked_by_battle_flow())
	sound_manager = get_node("/root/Main/SoundManager") as SoundManager
	options_panel.configure(sound_manager, true, tr("Back"))
	_show_main_menu()
	if game_guide_menu_modal.visible:
		game_guide_menu_modal.hide_modal()

func hide_modal() -> void:
	if game_guide_menu_modal.visible:
		game_guide_menu_modal.hide_modal()
	options_panel.visible = false
	visible = false
	ui_manager.set_modal_active(false)
	get_tree().paused = false
