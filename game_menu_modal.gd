extends Control

@onready var continue_button: Button = $InnerPanel/ButtonContainer/ContinueButton
@onready var options_button: Button = $InnerPanel/ButtonContainer/OptionsButton
@onready var main_menu_button: Button = $InnerPanel/ButtonContainer/MainMenuButton
@onready var exit_button: Button = $InnerPanel/ButtonContainer/ExitButton

signal main_menu_pressed
signal exit_pressed

func _ready():
	continue_button.pressed.connect(_on_continue_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _on_continue_pressed():
	DebugLogger.log("UISystem", "Game Menu - Continue pressed")
	hide_modal()

func _on_main_menu_pressed():
	DebugLogger.log("UISystem", "Game Menu - Main Menu pressed")
	main_menu_pressed.emit()

func _on_exit_pressed():
	DebugLogger.log("UISystem", "Game Menu - Exit pressed")
	exit_pressed.emit()

func show_modal():
	visible = true
	get_tree().paused = true

func hide_modal():
	visible = false
	get_tree().paused = false
