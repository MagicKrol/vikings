extends Control
class_name MainMenu

# Set to true for demo menu, false for standard menu
const USE_DEMO_MENU: bool = true

@onready var continue_button: Button = $MenuContainer/ContinueButton
@onready var new_game_button: Button = $MenuContainer/NewGameButton
@onready var load_game_button: Button = $MenuContainer/LoadGameButton
@onready var options_button: Button = $MenuContainer/OptionsButton
@onready var exit_button: Button = $MenuContainer/ExitButton

# New Game menu buttons
@onready var campaign_button: Button = $NewGame/CampaignButton
@onready var scenario_button: Button = $NewGame/ScenarioButton
@onready var custom_map_button: Button = $NewGame/ScenarioButton2
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
@onready var scenario_list_scenario: VBoxContainer = $Scenario/Scenario/MapContainer/InnerMargin/ScrollContainer/MapList

# CustomMap menu buttons
@onready var custom_map_back_button: Button = $CustomMap/BackButton
@onready var custom_map_play_button: Button = $CustomMap/PlayButton
@onready var custom_map_list: VBoxContainer = $CustomMap/MapContainer/InnerMargin/ScrollContainer/MapList
@onready var custom_map_settings: Control = $CustomMapSettings
@onready var player_settings_container: VBoxContainer = $CustomMapSettings/InnerPanel/PlayerSettings

# Container references
@onready var menu_container: VBoxContainer = $MenuContainer
@onready var new_game_container: VBoxContainer = $NewGame
@onready var options_container: VBoxContainer = $Options
@onready var campaign_container: VBoxContainer = $Campaign
@onready var scenario_container: VBoxContainer = $Scenario
@onready var custom_map_container: VBoxContainer = $CustomMap
@onready var demo_container: VBoxContainer = $Demo

# Demo menu buttons
@onready var demo_tutorial_button: Button = $Demo/TutorialButton
@onready var demo_map_button: Button = $Demo/DemoMapButton
@onready var demo_options_button: Button = $Demo/OptionsButton
@onready var demo_exit_button: Button = $Demo/ExitButton

@onready var button_bg1 = $TextureRect1
@onready var button_bg2 = $TextureRect2
@onready var button_bg3 = $TextureRect3
@onready var button_bg4 = $TextureRect4
@onready var button_bg5 = $TextureRect5

# Map preview references
@onready var map_preview: Control = $MapPreview
@onready var map_screenshot: TextureRect = $MapPreview/InnerPanel/MapScreenshot

var hover_timer: Timer
var current_hovered_item: String = ""
var default_preview_item: String = ""

var sound_manager: SoundManager = null
var selected_scenario: String = ""
var selected_custom_map: String = ""
var selected_scenario_button: Button = null
var selected_custom_map_button: Button = null

# Player settings for custom map
var player_settings: Array = []  # Array of dictionaries with player configuration

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
	custom_map_button.pressed.connect(_on_custom_map_pressed)
	new_game_back_button.pressed.connect(_on_new_game_back_pressed)
	
	# Connect campaign menu button signals
	campaign_back_button.pressed.connect(_on_campaign_back_pressed)
	campaign_play_button.pressed.connect(_on_campaign_play_pressed)
	
	# Connect options and scenario menu button signals
	options_back_button.pressed.connect(_on_options_back_pressed)
	scenario_back_button.pressed.connect(_on_scenario_back_pressed)
	scenario_play_button.pressed.connect(_on_scenario_play_pressed)
	
	# Connect custom map menu button signals
	custom_map_back_button.pressed.connect(_on_custom_map_back_pressed)
	custom_map_play_button.pressed.connect(_on_custom_map_play_pressed)

	# Connect demo menu button signals
	demo_tutorial_button.pressed.connect(_on_demo_tutorial_pressed)
	demo_map_button.pressed.connect(_on_demo_map_pressed)
	demo_options_button.pressed.connect(_on_options_pressed)
	demo_exit_button.pressed.connect(_on_exit_pressed)

	# Hover sounds removed - no sound on mouse enter

	# Show demo or standard menu based on USE_DEMO_MENU constant
	if USE_DEMO_MENU:
		_show_demo_menu()
	else:
		_show_main_menu()

	# Initialize player settings UI
	_initialize_player_settings()

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

func _on_custom_map_pressed():
	DebugLogger.log("UISystem", "Custom Map button pressed")
	_show_custom_map_menu()

func _on_new_game_back_pressed():
	DebugLogger.log("UISystem", "New Game Back button pressed")
	_show_main_menu()

func _on_campaign_back_pressed():
	DebugLogger.log("UISystem", "Campaign Back button pressed")
	_show_new_game_menu()

func _on_campaign_play_pressed():
	DebugLogger.log("UISystem", "Campaign Play button pressed with scenario: " + selected_scenario)
	if selected_scenario != "":
		var scen_path := "res://scenarios/" + selected_scenario + ".json"
		get_tree().set_meta("start_payload", {
			"type": "scenario",
			"scenario_path": scen_path
		})
		if sound_manager:
			sound_manager.stop_main_menu_music()
		get_tree().change_scene_to_file("res://main.tscn")

func _on_options_back_pressed():
	DebugLogger.log("UISystem", "Options Back button pressed")
	if USE_DEMO_MENU:
		_show_demo_menu()
	else:
		_show_main_menu()

func _on_scenario_back_pressed():
	DebugLogger.log("UISystem", "Scenario Back button pressed")  
	_show_new_game_menu()

func _on_scenario_play_pressed():
	DebugLogger.log("UISystem", "Scenario Play button pressed with scenario: " + selected_scenario)
	if selected_scenario != "":
		var scen_path := "res://scenarios/" + selected_scenario + ".json"
		get_tree().set_meta("start_payload", {
			"type": "scenario",
			"scenario_path": scen_path
		})
		if sound_manager:
			sound_manager.stop_main_menu_music()
		get_tree().change_scene_to_file("res://main.tscn")

func _on_custom_map_back_pressed():
	DebugLogger.log("UISystem", "Custom Map Back button pressed")  
	_show_new_game_menu()

func _on_custom_map_play_pressed():
	DebugLogger.log("UISystem", "Custom Map Play button pressed with map: " + selected_custom_map)
	if selected_custom_map != "":
		var map_file := selected_custom_map + ".json"
		var map_path := "res://mapdata/" + map_file
		var parts := selected_custom_map.split("-")
		var size_str: String = parts[parts.size() - 1]
		get_tree().set_meta("start_payload", {
			"type": "map",
			"map_file": map_path,
			"map_size": size_str,
			"player_settings": player_settings
		})
		if sound_manager:
			sound_manager.stop_main_menu_music()
		get_tree().change_scene_to_file("res://main.tscn")

func _on_demo_tutorial_pressed():
	DebugLogger.log("UISystem", "Demo Tutorial button pressed")
	var scen_path := "res://scenarios/tutorial.json"
	get_tree().set_meta("start_payload", {
		"type": "scenario",
		"scenario_path": scen_path
	})
	if sound_manager:
		sound_manager.stop_main_menu_music()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_demo_map_pressed():
	DebugLogger.log("UISystem", "Demo Map button pressed")
	var map_path := "res://mapdata/demo-999-medium.json"
	var demo_player_settings := [
		{"player_id": 1, "control_type": "Player"},
		{"player_id": 2, "control_type": "Computer"},
		{"player_id": 3, "control_type": "Computer"},
		{"player_id": 4, "control_type": "Computer"},
		{"player_id": 5, "control_type": "Computer"},
		{"player_id": 6, "control_type": "Off"}
	]
	get_tree().set_meta("start_payload", {
		"type": "map",
		"map_file": map_path,
		"map_size": "medium",
		"player_settings": demo_player_settings
	})
	if sound_manager:
		sound_manager.stop_main_menu_music()
	get_tree().change_scene_to_file("res://main.tscn")

func _show_main_menu():
	"""Show the main menu and hide other menus"""
	button_bg1.visible = true
	button_bg2.visible = true
	button_bg3.visible = true
	button_bg4.visible = true
	button_bg5.visible = true
	menu_container.visible = true
	new_game_container.visible = false
	options_container.visible = false
	campaign_container.visible = false
	scenario_container.visible = false
	custom_map_container.visible = false
	demo_container.visible = false
	map_preview.visible = false
	custom_map_settings.visible = false

func _show_new_game_menu():
	"""Show the new game menu"""
	button_bg1.visible = true
	button_bg2.visible = true
	button_bg3.visible = true
	button_bg4.visible = true
	button_bg5.visible = false
	menu_container.visible = false
	new_game_container.visible = true
	options_container.visible = false
	campaign_container.visible = false
	scenario_container.visible = false
	custom_map_container.visible = false
	demo_container.visible = false
	map_preview.visible = false
	custom_map_settings.visible = false

func _show_options_menu():
	"""Show the options menu"""
	button_bg4.visible = false
	button_bg5.visible = false
	menu_container.visible = false
	new_game_container.visible = false
	options_container.visible = true
	campaign_container.visible = false
	scenario_container.visible = false
	custom_map_container.visible = false
	demo_container.visible = false
	map_preview.visible = false

func _show_campaign_menu():
	"""Show the campaign menu and load scenarios"""
	button_bg1.visible = true
	button_bg2.visible = false
	button_bg3.visible = false
	button_bg4.visible = false
	button_bg5.visible = false
	menu_container.visible = false
	new_game_container.visible = false
	options_container.visible = false
	campaign_container.visible = true
	scenario_container.visible = false
	custom_map_container.visible = false
	demo_container.visible = false
	map_preview.visible = true
	selected_scenario = ""
	default_preview_item = ""
	if selected_scenario_button:
		selected_scenario_button.modulate = Color.WHITE
	selected_scenario_button = null
	campaign_play_button.disabled = true
	_load_scenario_list()

func _show_scenario_menu():
	"""Show the scenario menu and load scenario list"""
	button_bg1.visible = true
	button_bg2.visible = false
	button_bg3.visible = false
	button_bg4.visible = false
	button_bg5.visible = false
	menu_container.visible = false
	new_game_container.visible = false
	options_container.visible = false
	campaign_container.visible = false
	scenario_container.visible = true
	custom_map_container.visible = false
	demo_container.visible = false
	map_preview.visible = true
	selected_scenario = ""
	default_preview_item = ""
	if selected_scenario_button:
		selected_scenario_button.modulate = Color.WHITE
	selected_scenario_button = null
	scenario_play_button.disabled = true
	_load_scenario_list_for_scenario()

func _show_custom_map_menu():
	"""Show the custom map menu and load map list"""
	button_bg1.visible = true
	button_bg2.visible = false
	button_bg3.visible = false
	button_bg4.visible = false
	button_bg5.visible = false
	menu_container.visible = false
	new_game_container.visible = false
	options_container.visible = false
	campaign_container.visible = false
	scenario_container.visible = false
	custom_map_container.visible = true
	demo_container.visible = false
	map_preview.visible = true
	custom_map_settings.visible = true
	selected_custom_map = ""
	default_preview_item = ""
	if selected_custom_map_button:
		selected_custom_map_button.modulate = Color.WHITE
	selected_custom_map_button = null
	custom_map_play_button.disabled = true
	_load_custom_map_list()

func _show_demo_menu():
	"""Show the demo menu"""
	button_bg1.visible = true
	button_bg2.visible = true
	button_bg3.visible = true
	button_bg4.visible = true
	button_bg5.visible = false
	menu_container.visible = false
	new_game_container.visible = false
	options_container.visible = false
	campaign_container.visible = false
	scenario_container.visible = false
	custom_map_container.visible = false
	demo_container.visible = true
	map_preview.visible = false
	custom_map_settings.visible = false

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

func _load_scenario_list_for_scenario():
	"""Load and display available scenarios for scenario menu"""
	# Clear existing list
	for child in scenario_list_scenario.get_children():
		child.queue_free()
	
	# Get all scenario files
	var dir = DirAccess.open("res://scenarios")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				_add_scenario_button_for_scenario(file_name.trim_suffix(".json"))
			file_name = dir.get_next()
		dir.list_dir_end()

func _add_scenario_button_for_scenario(scenario_name: String):
	"""Add a button for a scenario to the scenario menu list"""
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
	button.pressed.connect(_on_scenario_selected_for_scenario.bind(scenario_name, button))
	
	# Connect hover signals for preview
	button.mouse_entered.connect(_on_scenario_hovered.bind(scenario_name))
	button.mouse_exited.connect(_on_scenario_unhovered)
	
	scenario_list_scenario.add_child(button)

func _on_scenario_selected_for_scenario(scenario_name: String, button: Button):
	"""Handle scenario selection in scenario menu"""
	# Reset previous selection
	if selected_scenario_button:
		selected_scenario_button.modulate = Color.WHITE
	
	# Set new selection
	selected_scenario = scenario_name
	selected_scenario_button = button
	button.modulate = Color(0.8, 0.4, 0.2, 1)  # Selected color (darker orange-red)
	
	# Set as default preview
	default_preview_item = scenario_name
	_show_preview(scenario_name)
	
	# Enable play button
	scenario_play_button.disabled = false
	
	DebugLogger.log("UISystem", "Selected scenario: " + scenario_name)

func _on_scenario_selected(scenario_name: String, button: Button):
	"""Handle scenario selection"""
	# Reset previous selection
	if selected_scenario_button:
		selected_scenario_button.modulate = Color.WHITE
	
	# Set new selection
	selected_scenario = scenario_name
	selected_scenario_button = button
	button.modulate = Color(0.8, 0.4, 0.2, 1)  # Selected color (darker orange-red)
	
	# Set as default preview
	default_preview_item = scenario_name
	_show_preview(scenario_name)
	
	# Enable play button
	campaign_play_button.disabled = false
	
	DebugLogger.log("UISystem", "Selected scenario: " + scenario_name)
	# no click sound in main menu

func _load_custom_map_list():
	"""Load and display available maps from mapdata folder for custom map menu"""
	# Clear existing list
	for child in custom_map_list.get_children():
		child.queue_free()
	
	# Get all map files from mapdata folder (both old mapdata-* and new formats)
	var dir = DirAccess.open("res://mapdata")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json") and _is_valid_map_file(file_name):
				_add_custom_map_button(file_name.trim_suffix(".json"))
			file_name = dir.get_next()
		dir.list_dir_end()

func _add_custom_map_button(map_name: String):
	"""Add a button for a map to the custom map list"""
	var button = Button.new()
	var display_text = _format_map_name_for_display(map_name)
	button.text = display_text
	
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
	button.pressed.connect(_on_custom_map_selected.bind(map_name, button))
	
	# Connect hover signals for preview
	button.mouse_entered.connect(_on_map_hovered.bind(map_name))
	button.mouse_exited.connect(_on_map_unhovered)
	
	custom_map_list.add_child(button)

func _on_custom_map_selected(map_name: String, button: Button):
	"""Handle custom map selection"""
	# Reset previous selection
	if selected_custom_map_button:
		selected_custom_map_button.modulate = Color.WHITE
	
	# Set new selection
	selected_custom_map = map_name
	selected_custom_map_button = button
	button.modulate = Color(0.8, 0.4, 0.2, 1)  # Selected color (darker orange-red)
	
	# Set as default preview
	default_preview_item = map_name
	_show_preview(map_name)
	
	# Enable play button
	custom_map_play_button.disabled = false
	
	DebugLogger.log("UISystem", "Selected custom map: " + map_name)

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
	"""Handle delayed return to default preview"""
	if current_hovered_item == "":
		if default_preview_item != "":
			_show_preview(default_preview_item)
		else:
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

func _initialize_player_settings():
	"""Initialize the player settings UI with 6 player rows"""
	# Initialize player settings array with default values
	player_settings.clear()
	for i in range(1, 7):  # Players 1-6
		player_settings.append({
			"player_id": i,
			"control_type": "Off" if i > 2 else ("Player" if i == 1 else "Computer")
		})
	
	# Create UI rows for each player
	var font = load("res://fonts/Cardo-Bold.ttf")
	
	for i in range(6):
		var player_num = i + 1
		var player_color = GameParameters.get_player_color(player_num)
		
		# Create horizontal container for the row
		var row_container = HBoxContainer.new()
		row_container.custom_minimum_size.y = 50
		
		# Create player label with color
		var player_label = Label.new()
		player_label.text = "Player " + str(player_num)
		player_label.custom_minimum_size.x = 100
		player_label.modulate = player_color
		player_label.add_theme_font_override("font", font)
		player_label.add_theme_font_size_override("font_size", 24)
		player_label.add_theme_color_override("font_outline_color", Color.BLACK)
		player_label.add_theme_constant_override("outline_size", 2)
		row_container.add_child(player_label)
		
		# Add spacer
		var spacer = Control.new()
		spacer.custom_minimum_size.x = 30
		row_container.add_child(spacer)
		
		# Create button group for this player
		var button_group = ButtonGroup.new()
		
		# Create Player button
		var player_button = Button.new()
		player_button.text = "Player"
		player_button.custom_minimum_size.x = 80
		player_button.toggle_mode = true
		player_button.button_group = button_group
		player_button.add_theme_font_override("font", font)
		player_button.add_theme_font_size_override("font_size", 20)
		player_button.button_pressed = (player_settings[i].control_type == "Player")
		player_button.toggled.connect(_on_player_control_changed.bind(player_num, "Player"))
		row_container.add_child(player_button)
		
		# Create Computer button
		var computer_button = Button.new()
		computer_button.text = "Computer"
		computer_button.custom_minimum_size.x = 100
		computer_button.toggle_mode = true
		computer_button.button_group = button_group
		computer_button.add_theme_font_override("font", font)
		computer_button.add_theme_font_size_override("font_size", 20)
		computer_button.button_pressed = (player_settings[i].control_type == "Computer")
		computer_button.toggled.connect(_on_player_control_changed.bind(player_num, "Computer"))
		row_container.add_child(computer_button)
		
		# Create Off button
		var off_button = Button.new()
		off_button.text = "Off"
		off_button.custom_minimum_size.x = 60
		off_button.toggle_mode = true
		off_button.button_group = button_group
		off_button.add_theme_font_override("font", font)
		off_button.add_theme_font_size_override("font_size", 20)
		off_button.button_pressed = (player_settings[i].control_type == "Off")
		off_button.toggled.connect(_on_player_control_changed.bind(player_num, "Off"))
		row_container.add_child(off_button)
		
		# Add row to container
		player_settings_container.add_child(row_container)

func _convert_size_name(old_size: String) -> String:
	"""Convert old size names to new display names: XTiny->Small, Tiny->Medium, Small->Large, Medium->Huge"""
	var size_lower = old_size.to_lower()
	match size_lower:
		"xtiny":
			return "Small"
		"tiny":
			return "Medium"
		"small":
			return "Large"
		"medium":
			return "Huge"
		_:
			# For any other size (including already new names), just capitalize
			return old_size.capitalize()

func _is_valid_map_file(filename: String) -> bool:
	"""Check if filename follows valid map file pattern (old or new format)"""
	var name_without_extension = filename.trim_suffix(".json")
	var parts = name_without_extension.split("-")
	
	# Old format: mapdata-id-size (3 parts)
	if parts.size() == 3 and parts[0] == "mapdata":
		return true
	
	# New format: MapName-id-size (at least 3 parts, but could be more for multi-word names)
	if parts.size() >= 3:
		var size_part = parts[parts.size() - 1].to_lower()
		# Check if last part is a valid size (old or new naming)
		var valid_old_sizes = ["xtiny", "tiny", "small", "medium", "large", "huge"]
		var valid_new_sizes = ["small", "medium", "large", "huge"]
		return size_part in valid_old_sizes or size_part in valid_new_sizes
	
	return false

func _format_map_name_for_display(map_name: String) -> String:
	"""Format map name for display: MapName-id-size -> 'Size MapName' (hide ID, replace underscores with spaces)"""
	var parts = map_name.split("-")
	
	if parts.size() >= 3:
		# After file renaming, all files now use new size names (small, medium, large, huge)
		# So we just capitalize them - no conversion needed
		var raw_size = parts[parts.size() - 1]
		var size_part = raw_size.capitalize()
		
		# Use first part as map name (before first hyphen)
		var map_name_part = parts[0].replace("_", " ")
		
		return size_part + " " + map_name_part
	else:
		# Fallback for unexpected format
		return map_name.capitalize().replace("_", " ").replace("-", " ")

func _on_player_control_changed(toggled_on: bool, player_num: int, control_type: String):
	"""Handle player control type change"""
	if toggled_on:
		player_settings[player_num - 1].control_type = control_type
		DebugLogger.log("UISystem", "Player " + str(player_num) + " set to: " + control_type)
