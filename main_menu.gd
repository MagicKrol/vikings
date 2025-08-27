extends Control
class_name MainMenu

@onready var continue_button: Button = $MenuContainer/ContinueButton
@onready var new_game_button: Button = $MenuContainer/NewGameButton
@onready var load_game_button: Button = $MenuContainer/LoadGameButton
@onready var options_button: Button = $MenuContainer/OptionsButton
@onready var exit_button: Button = $MenuContainer/ExitButton

var sound_manager: SoundManager = null

func _ready():
	# Create and add sound manager
	sound_manager = SoundManager.new()
	add_child(sound_manager)
	
	# Play main menu music
	sound_manager.play_main_menu_music()
	
	# Apply font outlines to all buttons
	_apply_font_outlines()
	
	# Connect button signals
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	# Connect hover sounds
	continue_button.mouse_entered.connect(_on_button_hover)
	new_game_button.mouse_entered.connect(_on_button_hover)
	load_game_button.mouse_entered.connect(_on_button_hover)
	options_button.mouse_entered.connect(_on_button_hover)
	exit_button.mouse_entered.connect(_on_button_hover)

func _apply_font_outlines():
	"""Apply black outline to all menu buttons"""
	var buttons = [continue_button, new_game_button, load_game_button, options_button, exit_button]
	
	for button in buttons:
		# TEST: Comment out programmatic overrides to see if theme file is working
		#button.add_theme_color_override("font_outline_color", Color.BLACK)
		#button.add_theme_constant_override("outline_size", 3)
		
		# Alternative shadow approach if outline doesn't work
		#button.add_theme_color_override("font_shadow_color", Color.BLACK)
		#button.add_theme_constant_override("shadow_offset_x", 2)
		#button.add_theme_constant_override("shadow_offset_y", 2)
		#button.add_theme_constant_override("shadow_outline_size", 1)
		
		print("[MainMenu] Testing - programmatic overrides commented out for ", button.text)

func _on_button_hover():
	"""Play hover sound when mouse enters button"""
	if sound_manager:
		sound_manager.click_sound()

func _on_continue_pressed():
	print("[MainMenu] Continue button pressed")
	if sound_manager:
		sound_manager.click_sound()
		sound_manager.stop_main_menu_music()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_new_game_pressed():
	print("[MainMenu] New Game button pressed")
	if sound_manager:
		sound_manager.click_sound()
		sound_manager.stop_main_menu_music()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_load_game_pressed():
	print("[MainMenu] Load Game button pressed")
	if sound_manager:
		sound_manager.click_sound()

func _on_options_pressed():
	print("[MainMenu] Options button pressed")
	if sound_manager:
		sound_manager.click_sound()

func _on_exit_pressed():
	print("[MainMenu] Exit button pressed")
	if sound_manager:
		sound_manager.click_sound()
	get_tree().quit()
