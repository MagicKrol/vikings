extends Control

# Main menu elements
@onready var top_texture: TextureRect = $Top
@onready var header_label: Label = $InnerPanel/HeaderSection/HeaderLabel
@onready var button_container: VBoxContainer = $InnerPanel/ButtonContainer
@onready var continue_button: Button = $InnerPanel/ButtonContainer/ContinueButton
@onready var options_button: Button = $InnerPanel/ButtonContainer/OptionsButton
@onready var main_menu_button: Button = $InnerPanel/ButtonContainer/MainMenuButton
@onready var exit_button: Button = $InnerPanel/ButtonContainer/ExitButton
@onready var options_panel: OptionsPanel = get_node("../Options") as OptionsPanel

var sound_manager: SoundManager
var ui_manager: UIManager

signal main_menu_pressed
signal exit_pressed

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	options_button.pressed.connect(_on_options_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	options_panel.back_requested.connect(_on_options_back_pressed)
	sound_manager = get_node("/root/Main/SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	options_panel.configure(sound_manager, true, "Back")
	options_panel.visible = false

func _on_continue_pressed() -> void:
	DebugLogger.log("UISystem", "Game Menu - Continue pressed")
	hide_modal()

func _on_options_pressed() -> void:
	DebugLogger.log("UISystem", "Game Menu - Options pressed")
	_show_options_menu()

func _on_main_menu_pressed() -> void:
	DebugLogger.log("UISystem", "Game Menu - Main Menu pressed")
	main_menu_pressed.emit()

func _on_exit_pressed() -> void:
	DebugLogger.log("UISystem", "Game Menu - Exit pressed")
	exit_pressed.emit()

func _on_options_back_pressed() -> void:
	DebugLogger.log("UISystem", "Game Menu - Options Back pressed")
	_show_main_menu()

func _show_main_menu() -> void:
	header_label.text = "Game Menu"
	top_texture.visible = true
	button_container.visible = true
	options_panel.visible = false

func _show_options_menu() -> void:
	options_panel.configure(sound_manager, true, "Back")
	header_label.text = ""
	top_texture.visible = false
	button_container.visible = false
	options_panel.visible = true

func show_modal() -> void:
	visible = true
	ui_manager.set_modal_active(true)
	get_tree().paused = true
	sound_manager = get_node("/root/Main/SoundManager") as SoundManager
	options_panel.configure(sound_manager, true, "Back")
	_show_main_menu()

func hide_modal() -> void:
	options_panel.visible = false
	visible = false
	ui_manager.set_modal_active(false)
	get_tree().paused = false
