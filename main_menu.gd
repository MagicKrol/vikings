extends Control
class_name MainMenu

@onready var continue_button: Button = $MenuContainer/ContinueButton
@onready var new_game_button: Button = $MenuContainer/NewGameButton
@onready var load_game_button: Button = $MenuContainer/LoadGameButton
@onready var options_button: Button = $MenuContainer/OptionsButton
@onready var exit_button: Button = $MenuContainer/ExitButton

# New Game menu buttons
@onready var campaign_button: Button = $NewGame/CampaignButton
@onready var scenario_button: Button = $NewGame/ScenarioButton
@onready var new_game_back_button: Button = $NewGame/BackButton

# Campaign menu elements
@onready var campaign_back_button: Button = $Campaign/BackButton
@onready var campaign_play_button: Button = $Campaign/PlayButton
@onready var scenario_list: VBoxContainer = $Campaign/ScenarioContainer/InnerMargin/ScrollContainer/ScenarioList

# Options menu buttons  
@onready var options_back_button: Button = $Options/BackButton

# Scenario menu buttons
@onready var scenario_back_button: Button = $Scenario/BackButton
@onready var scenario_play_button: Button = $Scenario/PlayButton
@onready var map_list: VBoxContainer = $Scenario/MapContainer/InnerMargin/ScrollContainer/MapList

# Container references
@onready var menu_container: VBoxContainer = $MenuContainer
@onready var new_game_container: VBoxContainer = $NewGame  
@onready var options_container: VBoxContainer = $Options
@onready var campaign_container: VBoxContainer = $Campaign
@onready var scenario_container: VBoxContainer = $Scenario

# Map preview references
@onready var map_preview: Control = $MapPreview
@onready var map_screenshot: TextureRect = $MapPreview/InnerPanel/MapScreenshot

var hover_timer: Timer
var current_hovered_item: String = ""

var sound_manager: SoundManager = null
var selected_scenario: String = ""
var selected_map: String = ""
var selected_scenario_button: Button = null
var selected_map_button: Button = null

func _ready():
	# Create and add sound manager
	sound_manager = SoundManager.new()
	add_child(sound_manager)
	
	# Create hover timer for delayed hide
	hover_timer = Timer.new()
	hover_timer.wait_time = 0.2
	hover_timer.one_shot = true
	hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(hover_timer)
	
	# Play main menu music
	sound_manager.play_main_menu_music()
	# Ensure preview background is always visible; hide screenshot until available
	map_screenshot.visible = false
	
	# Apply font outlines to all buttons
	_apply_font_outlines()
	
	# Connect main menu button signals
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	# Connect new game menu button signals
	campaign_button.pressed.connect(_on_campaign_pressed)
	scenario_button.pressed.connect(_on_scenario_pressed)
	new_game_back_button.pressed.connect(_on_new_game_back_pressed)
	
	# Connect campaign menu button signals
	campaign_back_button.pressed.connect(_on_campaign_back_pressed)
	campaign_play_button.pressed.connect(_on_campaign_play_pressed)
	
	# Connect options and scenario menu button signals
	options_back_button.pressed.connect(_on_options_back_pressed)
	scenario_back_button.pressed.connect(_on_scenario_back_pressed)
	scenario_play_button.pressed.connect(_on_scenario_play_pressed)
	
	# Hover sounds removed - no sound on mouse enter
	
	# Initially show main menu
	_show_main_menu()

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
		
		DebugLogger.log("UISystem", "Testing - programmatic overrides commented out for " + button.text)

func _on_button_hover():
	"""Play hover sound when mouse enters button"""
	if sound_manager:
		sound_manager.click_sound()

func _on_continue_pressed():
	DebugLogger.log("UISystem", "Continue button pressed")
	if sound_manager:
		sound_manager.stop_main_menu_music()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_new_game_pressed():
	DebugLogger.log("UISystem", "New Game button pressed")
	_show_new_game_menu()

func _on_load_game_pressed():
	DebugLogger.log("UISystem", "Load Game button pressed")

func _on_options_pressed():
	DebugLogger.log("UISystem", "Options button pressed")
	_show_options_menu()

func _on_exit_pressed():
	DebugLogger.log("UISystem", "Exit button pressed")
	get_tree().quit()

func _on_campaign_pressed():
	DebugLogger.log("UISystem", "Campaign button pressed")
	_show_campaign_menu()

func _on_scenario_pressed():
	DebugLogger.log("UISystem", "Scenario button pressed")
	_show_scenario_menu()

func _on_new_game_back_pressed():
	DebugLogger.log("UISystem", "New Game Back button pressed")
	_show_main_menu()

func _on_campaign_back_pressed():
	DebugLogger.log("UISystem", "Campaign Back button pressed")
	_show_new_game_menu()

func _on_campaign_play_pressed():
	DebugLogger.log("UISystem", "Campaign Play button pressed with scenario: " + selected_scenario)
	if selected_scenario != "":
		# TODO: Load the selected scenario
		pass

func _on_options_back_pressed():
	DebugLogger.log("UISystem", "Options Back button pressed")
	_show_main_menu()

func _on_scenario_back_pressed():
	DebugLogger.log("UISystem", "Scenario Back button pressed")  
	_show_new_game_menu()

func _on_scenario_play_pressed():
	DebugLogger.log("UISystem", "Scenario Play button pressed with map: " + selected_map)
	if selected_map != "":
		# TODO: Load the selected map
		pass

func _show_main_menu():
	"""Show the main menu and hide other menus"""
	menu_container.visible = true
	new_game_container.visible = false
	options_container.visible = false
	campaign_container.visible = false
	scenario_container.visible = false
	map_preview.visible = false

func _show_new_game_menu():
	"""Show the new game menu"""
	menu_container.visible = false
	new_game_container.visible = true
	options_container.visible = false
	campaign_container.visible = false
	scenario_container.visible = false
	map_preview.visible = false

func _show_options_menu():
	"""Show the options menu"""
	menu_container.visible = false
	new_game_container.visible = false
	options_container.visible = true
	campaign_container.visible = false
	scenario_container.visible = false
	map_preview.visible = false

func _show_campaign_menu():
	"""Show the campaign menu and load scenarios"""
	menu_container.visible = false
	new_game_container.visible = false
	options_container.visible = false
	campaign_container.visible = true
	scenario_container.visible = false
	map_preview.visible = true
	selected_scenario = ""
	if selected_scenario_button:
		selected_scenario_button.modulate = Color.WHITE
	selected_scenario_button = null
	campaign_play_button.disabled = true
	_load_scenario_list()

func _show_scenario_menu():
	"""Show the scenario menu and load map list"""
	menu_container.visible = false
	new_game_container.visible = false
	options_container.visible = false
	campaign_container.visible = false
	scenario_container.visible = true
	map_preview.visible = true
	selected_map = ""
	if selected_map_button:
		selected_map_button.modulate = Color.WHITE
	selected_map_button = null
	scenario_play_button.disabled = true
	_load_map_list()

func _load_scenario_list():
	"""Load and display available scenarios"""
	# Clear existing list
	for child in scenario_list.get_children():
		child.queue_free()
	
	# Get all scenario files
	var dir = DirAccess.open("res://scenarios")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				_add_scenario_button(file_name.trim_suffix(".json"))
			file_name = dir.get_next()
		dir.list_dir_end()

func _add_scenario_button(scenario_name: String):
	"""Add a button for a scenario to the list"""
	var button = Button.new()
	button.text = scenario_name.capitalize().replace("_", " ")
	
	# Create the scenario theme dynamically to match the scene theme
	var scenario_theme = Theme.new()
	var font = load("res://fonts/Cardo-Bold.ttf")
	
	# Set font and styling to match Theme_scenario from scene
	scenario_theme.set_font("font", "Button", font)
	scenario_theme.set_font_size("font_size", "Button", 30)
	scenario_theme.set_color("font_color", "Button", Color(1, 1, 1, 1))  # White
	scenario_theme.set_color("font_hover_color", "Button", Color(0.9, 0.6, 0.4, 1))  # Even lighter orange-red
	scenario_theme.set_color("font_pressed_color", "Button", Color(0.9, 0.6, 0.4, 1))  # Same as hover
	scenario_theme.set_color("font_outline_color", "Button", Color(0, 0, 0, 1))  # Black outline
	scenario_theme.set_color("font_shadow_color", "Button", Color(0, 0, 0, 1))  # Black shadow
	scenario_theme.set_constant("outline_size", "Button", 5)
	scenario_theme.set_constant("shadow_offset_x", "Button", 1)
	scenario_theme.set_constant("shadow_offset_y", "Button", 1)
	
	# Create StyleBoxFlat with no borders for all button states
	var style_flat = StyleBoxFlat.new()
	style_flat.draw_center = false
	style_flat.border_width_left = 0
	style_flat.border_width_top = 0
	style_flat.border_width_right = 0
	style_flat.border_width_bottom = 0
	scenario_theme.set_stylebox("normal", "Button", style_flat)
	scenario_theme.set_stylebox("hover", "Button", style_flat)
	scenario_theme.set_stylebox("pressed", "Button", style_flat)
	scenario_theme.set_stylebox("focus", "Button", style_flat)
	
	button.theme = scenario_theme
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT  # Left align
	button.custom_minimum_size.y = 50
	
	# Connect the button to select this scenario
	button.pressed.connect(_on_scenario_selected.bind(scenario_name, button))
	
	# Connect hover signals for preview
	button.mouse_entered.connect(_on_scenario_hovered.bind(scenario_name))
	button.mouse_exited.connect(_on_scenario_unhovered)
	
	scenario_list.add_child(button)

func _on_scenario_selected(scenario_name: String, button: Button):
	"""Handle scenario selection"""
	# Reset previous selection
	if selected_scenario_button:
		selected_scenario_button.modulate = Color.WHITE
	
	# Set new selection
	selected_scenario = scenario_name
	selected_scenario_button = button
	button.modulate = Color(0.8, 0.4, 0.2, 1)  # Selected color (darker orange-red)
	
	# Enable play button
	campaign_play_button.disabled = false
	
	DebugLogger.log("UISystem", "Selected scenario: " + scenario_name)
	# no click sound in main menu

func _load_map_list():
	"""Load and display available maps from mapdata folder"""
	# Clear existing list
	for child in map_list.get_children():
		child.queue_free()
	
	# Get all map files from mapdata folder
	var dir = DirAccess.open("res://mapdata")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				_add_map_button(file_name.trim_suffix(".json"))
			file_name = dir.get_next()
		dir.list_dir_end()

func _add_map_button(map_name: String):
	"""Add a button for a map to the list"""
	var button = Button.new()
	button.text = map_name.capitalize().replace("_", " ").replace("-", " ")
	
	# Create the map theme dynamically to match scenario theme
	var map_theme = Theme.new()
	var font = load("res://fonts/Cardo-Bold.ttf")
	
	# Set font and styling to match scenario theme
	map_theme.set_font("font", "Button", font)
	map_theme.set_font_size("font_size", "Button", 30)
	map_theme.set_color("font_color", "Button", Color(1, 1, 1, 1))  # White
	map_theme.set_color("font_hover_color", "Button", Color(0.9, 0.6, 0.4, 1))  # Even lighter orange-red
	map_theme.set_color("font_pressed_color", "Button", Color(0.9, 0.6, 0.4, 1))  # Same as hover
	map_theme.set_color("font_outline_color", "Button", Color(0, 0, 0, 1))  # Black outline
	map_theme.set_color("font_shadow_color", "Button", Color(0, 0, 0, 1))  # Black shadow
	map_theme.set_constant("outline_size", "Button", 5)
	map_theme.set_constant("shadow_offset_x", "Button", 1)
	map_theme.set_constant("shadow_offset_y", "Button", 1)
	
	# Create StyleBoxFlat with no borders for all button states
	var style_flat = StyleBoxFlat.new()
	style_flat.draw_center = false
	style_flat.border_width_left = 0
	style_flat.border_width_top = 0
	style_flat.border_width_right = 0
	style_flat.border_width_bottom = 0
	map_theme.set_stylebox("normal", "Button", style_flat)
	map_theme.set_stylebox("hover", "Button", style_flat)
	map_theme.set_stylebox("pressed", "Button", style_flat)
	map_theme.set_stylebox("focus", "Button", style_flat)
	
	button.theme = map_theme
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT  # Left align
	button.custom_minimum_size.y = 50
	
	# Connect the button to select this map
	button.pressed.connect(_on_map_selected.bind(map_name, button))
	
	# Connect hover signals for preview
	button.mouse_entered.connect(_on_map_hovered.bind(map_name))
	button.mouse_exited.connect(_on_map_unhovered)
	
	map_list.add_child(button)

func _on_map_selected(map_name: String, button: Button):
	"""Handle map selection"""
	# Reset previous selection
	if selected_map_button:
		selected_map_button.modulate = Color.WHITE
	
	# Set new selection
	selected_map = map_name
	selected_map_button = button
	button.modulate = Color(0.8, 0.4, 0.2, 1)  # Selected color (darker orange-red)
	
	# Enable play button
	scenario_play_button.disabled = false
	
	DebugLogger.log("UISystem", "Selected map: " + map_name)
	# no click sound in main menu

func _on_scenario_hovered(scenario_name: String):
	"""Handle scenario hover for preview"""
	current_hovered_item = scenario_name
	hover_timer.stop()
	_show_preview(scenario_name)

func _on_scenario_unhovered():
	"""Handle scenario unhover"""
	current_hovered_item = ""
	hover_timer.start()

func _on_map_hovered(map_name: String):
	"""Handle map hover for preview"""
	current_hovered_item = map_name
	hover_timer.stop()
	_show_preview(map_name)

func _on_map_unhovered():
	"""Handle map unhover"""
	current_hovered_item = ""
	hover_timer.start()

func _on_hover_timer_timeout():
	"""Handle delayed hide of preview"""
	if current_hovered_item == "":
		_hide_preview()

func _show_preview(item_name: String):
	"""Show preview image for scenario or map"""
	var preview_path = "res://previews/" + item_name + ".png"
	
	# Check if preview image exists
	if ResourceLoader.exists(preview_path):
		var texture = load(preview_path)
		if texture:
			map_screenshot.texture = texture
			map_screenshot.visible = true
	else:
		# No preview available
		_hide_preview()

func _hide_preview():
	"""Hide preview image"""
	map_screenshot.visible = false
	map_screenshot.texture = null
