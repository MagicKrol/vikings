extends Control
class_name MainMenu

# Set to true for demo menu, false for standard menu
const USE_DEMO_MENU: bool = false

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

# Scenario menu buttons
@onready var scenario_back_button: Button = $Scenario/BackButton
@onready var scenario_play_button: Button = $Scenario/PlayButton
@onready var scenario_list_scenario: VBoxContainer = $Scenario/Scenario/MapContainer/InnerMargin/ScrollContainer/MapList

# CustomMap menu nodes
@onready var custom_map_container: Control = $CustomMap
@onready var custom_map_panel: Panel = $CustomMap/Panel
@onready var custom_map_panel2: Panel = $CustomMap/Panel2
@onready var custom_map_panel3: Panel = $CustomMap/Panel3
@onready var campaign_panel: Panel = $CustomMap/Panel4
@onready var custom_map_panel3_label: Label = $CustomMap/Panel3/VBoxContainer/Label
@onready var custom_map_back_button: Button = $CustomMap/Panel/VBoxContainer/HBoxContainer2/Back
@onready var custom_map_select_button: Button = $CustomMap/Panel/VBoxContainer/HBoxContainer/SelectMap
@onready var scenario_panel: Panel = $CustomMap/Scenario
@onready var scenario_back_button_custom: Button = $CustomMap/Scenario/VBoxContainer/HBoxContainer2/Back
@onready var scenario_select_button_custom: Button = $CustomMap/Scenario/VBoxContainer/HBoxContainer/SelectMap
@onready var scenario_difficulty_buttons: Array[Button] = [
	get_node("CustomMap/Scenario/VBoxContainer/Difficulty/Easy"),
	get_node("CustomMap/Scenario/VBoxContainer/Difficulty/Normal"),
	get_node("CustomMap/Scenario/VBoxContainer/Difficulty/Hard")
]
@onready var custom_map_list: VBoxContainer = $CustomMap/Panel3/VBoxContainer/ScrollContainer/MapList
@onready var custom_map_template_row: HBoxContainer = $CustomMap/Panel3/VBoxContainer/ScrollContainer/MapList/Row
@onready var campaign_map_list: VBoxContainer = $CustomMap/Panel4/VBoxContainer/ScrollContainer/MapList
@onready var campaign_template_row: HBoxContainer = $CustomMap/Panel4/VBoxContainer/ScrollContainer/MapList/Row
@onready var custom_map_preview: TextureRect = $CustomMap/Panel2/VBoxContainer/TextureRect
@onready var custom_map_map_name_label: Label = $CustomMap/Panel2/VBoxContainer/HBoxContainer/MapName
@onready var custom_map_map_size_label: Label = $CustomMap/Panel2/VBoxContainer/HBoxContainer2/MapSize
@onready var scenario_header_label: Label = $CustomMap/Scenario/VBoxContainer/Label
@onready var map_size_label: Label = $CustomMap/Panel3/VBoxContainer/MapSize
@onready var map_size_margin1: MarginContainer = $CustomMap/Panel3/VBoxContainer/MapSizeMargin1
@onready var map_sizes_container: HBoxContainer = $CustomMap/Panel3/VBoxContainer/Sizes
@onready var map_size_button_all: Button = $CustomMap/Panel3/VBoxContainer/Sizes/All
@onready var map_size_button_tiny: Button = $CustomMap/Panel3/VBoxContainer/Sizes/Tiny
@onready var map_size_button_small: Button = $CustomMap/Panel3/VBoxContainer/Sizes/Small
@onready var map_size_button_medium: Button = $CustomMap/Panel3/VBoxContainer/Sizes/Medium
@onready var map_size_button_large: Button = $CustomMap/Panel3/VBoxContainer/Sizes/Hard

# Container references
@onready var menu_container: VBoxContainer = $MenuContainer
@onready var new_game_container: VBoxContainer = $NewGame
@onready var options_container: OptionsPanel = $Options
@onready var campaign_container: VBoxContainer = $Campaign
@onready var scenario_container: VBoxContainer = $Scenario
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

# Custom map/scenario selection state
const GOLD_COLOR := Color(0.945098, 0.847059, 0.568627, 1.0)
const MAP_SIZE_ORDER := {"T": 0, "S": 1, "M": 2, "L": 3}
var map_items: Array = []
var scenario_items: Array = []
var selected_map_item: Dictionary = {}
var selected_map_button: Control = null
var selected_scenario_item: Dictionary = {}
var selected_scenario_button_custom: Control = null
var size_filter_button_group: ButtonGroup = null
var current_map_filter: String = "All"
var is_scenario_mode: bool = false
var is_campaign_mode: bool = false
var scenario_difficulty_group: ButtonGroup

# Player settings for custom map
var player_settings: Array = []  # Array of dictionaries with player configuration

func _ready():
	
	TranslationServer.set_locale("en")
	# Create and add sound manager
	sound_manager = SoundManager.new()
	add_child(sound_manager)
	SaveGameManager.load_settings(sound_manager)
	
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
	options_container.back_requested.connect(_on_options_back_pressed)
	scenario_back_button.pressed.connect(_on_scenario_back_pressed)
	scenario_play_button.pressed.connect(_on_scenario_play_pressed)
	
	# Connect custom map menu button signals
	custom_map_back_button.pressed.connect(_on_custom_map_back_pressed)
	custom_map_select_button.pressed.connect(_on_custom_map_select_pressed)
	scenario_back_button_custom.pressed.connect(_on_custom_map_back_pressed)
	scenario_select_button_custom.pressed.connect(_on_scenario_select_pressed)
	map_size_button_all.pressed.connect(_on_size_filter_pressed.bind("All", map_size_button_all))
	map_size_button_tiny.pressed.connect(_on_size_filter_pressed.bind("T", map_size_button_tiny))
	map_size_button_small.pressed.connect(_on_size_filter_pressed.bind("S", map_size_button_small))
	map_size_button_medium.pressed.connect(_on_size_filter_pressed.bind("M", map_size_button_medium))
	map_size_button_large.pressed.connect(_on_size_filter_pressed.bind("L", map_size_button_large))

	# Connect demo menu button signals
	demo_tutorial_button.pressed.connect(_on_demo_tutorial_pressed)
	demo_map_button.pressed.connect(_on_demo_map_pressed)
	demo_options_button.pressed.connect(_on_options_pressed)
	demo_exit_button.pressed.connect(_on_exit_pressed)

	# Hover sounds removed - no sound on mouse enter

	_setup_custom_map_preview()
	_setup_size_filter_group()
	_setup_player_buttons()
	_setup_difficulty_buttons()
	_setup_scenario_difficulty_buttons()
	_setup_victory_buttons()
	options_container.configure(sound_manager, false, "Back to Menu")

	# Show demo or standard menu based on USE_DEMO_MENU constant
	if USE_DEMO_MENU:
		_show_demo_menu()
	else:
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
	if not SaveGameManager.has_save_file():
		return
	get_tree().set_meta("start_payload", {
		"type": "save",
		"save_path": SaveGameManager.SAVE_FILE_PATH
	})
	if sound_manager:
		sound_manager.stop_main_menu_music()
	get_tree().change_scene_to_file("res://main.tscn")

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

func _on_custom_map_select_pressed():
	if selected_map_item.is_empty():
		return
	var map_file: String = selected_map_item.get("file", "")
	if map_file == "":
		return
	var size_code: String = selected_map_item.get("size", "S")
	var map_path := "res://mapdata/" + map_file + ".json"
	var size_str := _size_full_name(size_code).to_lower()
	var selected_victory: String = _get_selected_custom_map_victory()
	get_tree().set_meta("start_payload", {
		"type": "map",
		"map_file": map_path,
		"map_size": size_str,
		"player_settings": player_settings,
		"victory_condition": selected_victory
	})
	if sound_manager:
		sound_manager.stop_main_menu_music()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_scenario_select_pressed():
	if selected_scenario_item.is_empty():
		return
	var scenario_name: String = selected_scenario_item.get("name", "")
	var scen_path := "res://scenarios/" + scenario_name + ".json"
	get_tree().set_meta("start_payload", {
		"type": "scenario",
		"scenario_path": scen_path
	})
	if sound_manager:
		sound_manager.stop_main_menu_music()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_demo_tutorial_pressed():
	DebugLogger.log("UISystem", "Demo Tutorial button pressed")
	# Disable button to prevent re-triggering
	demo_tutorial_button.disabled = true
	var scen_path := "res://scenarios/tutorial.json"
	get_tree().set_meta("start_payload", {
		"type": "scenario",
		"scenario_path": scen_path
	})
	if sound_manager:
		sound_manager.stop_main_menu_music()
	# Wait for mouse button release to prevent click leaking to next scene
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		await get_tree().process_frame
	# Small delay to absorb any rapid subsequent clicks
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file("res://main.tscn")

func _on_demo_map_pressed():
	DebugLogger.log("UISystem", "Demo Map button pressed")
	# Disable button to prevent re-triggering
	# demo_map_button.disabled = true
	var map_path := "res://mapdata/demo-999-small.json"
	var demo_player_settings := [
		{"player_id": 1, "control_type": "Player"},
		{"player_id": 2, "control_type": "Computer"},
		{"player_id": 3, "control_type": "Computer"},
		{"player_id": 4, "control_type": "Off"},
		{"player_id": 5, "control_type": "Off"},
		{"player_id": 6, "control_type": "Off"}
	]
	get_tree().set_meta("start_payload", {
		"type": "map",
		"map_file": map_path,
		"map_size": "small",
		"player_settings": demo_player_settings,
		"victory_condition": "conquer"
	})
	if sound_manager:
		sound_manager.stop_main_menu_music()
	# Wait for mouse button release to prevent click leaking to next scene
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		await get_tree().process_frame
	# Small delay to absorb any rapid subsequent clicks
	await get_tree().create_timer(0.15).timeout
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

func _show_options_menu():
	"""Show the options menu"""
	options_container.configure(sound_manager, false, "Back to Menu")
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
	"""Show campaign using the Scenario node layout"""
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
	map_preview.visible = false
	is_scenario_mode = true
	is_campaign_mode = true
	custom_map_panel.visible = false
	scenario_panel.visible = true
	custom_map_panel2.visible = true
	custom_map_panel3.visible = false
	campaign_panel.visible = true
	custom_map_panel3_label.text = "Campaign list"
	_set_campaign_ui(true)
	_clear_map_selection()
	_load_scenario_items()

func _show_scenario_menu():
	"""Show scenario selection using the CustomMap layout"""
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
	map_preview.visible = false
	is_scenario_mode = true
	is_campaign_mode = false
	custom_map_panel.visible = false
	scenario_panel.visible = true
	custom_map_panel2.visible = true
	custom_map_panel3.visible = true
	campaign_panel.visible = false
	custom_map_panel3_label.text = "Scenario list"
	_set_campaign_ui(false)
	_clear_map_selection()
	_load_scenario_items()

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
	map_preview.visible = false
	is_scenario_mode = false
	custom_map_panel.visible = true
	scenario_panel.visible = false
	custom_map_panel2.visible = true
	custom_map_panel3.visible = true
	campaign_panel.visible = false
	custom_map_panel3_label.text = "Select Map"
	_set_campaign_ui(false)
	_clear_map_selection()
	_load_custom_map_items()

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
	custom_map_preview.visible = false

func _set_campaign_ui(enabled: bool):
	scenario_header_label.text = "Campaign" if enabled else "Scenario"
	var show_sizes := not enabled
	map_size_label.visible = show_sizes
	map_size_margin1.visible = show_sizes
	map_sizes_container.visible = show_sizes

func _setup_custom_map_preview():
	custom_map_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	custom_map_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	custom_map_preview.ignore_texture_size = true
	custom_map_preview.texture = null
	custom_map_preview.visible = false
	if custom_map_template_row:
		custom_map_template_row.visible = false

func _setup_size_filter_group():
	size_filter_button_group = ButtonGroup.new()
	var buttons: Array = [map_size_button_all, map_size_button_tiny, map_size_button_small, map_size_button_medium, map_size_button_large]
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		btn.toggle_mode = true
		btn.button_group = size_filter_button_group
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var selected := i == 0
		btn.button_pressed = selected
		_update_button_gold_state(btn, selected)
	current_map_filter = "All"

func _on_size_filter_pressed(filter_code: String, button: Button):
	current_map_filter = filter_code
	for b in size_filter_button_group.get_buttons():
		_update_button_gold_state(b, b == button)
	_apply_map_filter()

func _setup_player_buttons():
	player_settings.clear()
	for i in range(6):
		var player_num := i + 1
		var base_path := "CustomMap/Panel/VBoxContainer/Player" + str(player_num) + "/"
		var human_btn: Button = get_node(base_path + "Human")
		var computer_btn: Button = get_node(base_path + "Computer")
		var off_btn: Button = get_node(base_path + "Off")
		var group := ButtonGroup.new()
		for btn in [human_btn, computer_btn, off_btn]:
			btn.toggle_mode = true
			btn.button_group = group
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var default_control := "Player" if player_num == 1 else ("Computer" if player_num <= 4 else "Off")
		human_btn.button_pressed = default_control == "Player"
		computer_btn.button_pressed = default_control == "Computer"
		off_btn.button_pressed = default_control == "Off"
		player_settings.append({"player_id": player_num, "control_type": default_control})
		human_btn.toggled.connect(_on_player_control_changed.bind(player_num, "Player", human_btn))
		computer_btn.toggled.connect(_on_player_control_changed.bind(player_num, "Computer", computer_btn))
		off_btn.toggled.connect(_on_player_control_changed.bind(player_num, "Off", off_btn))
		_update_button_gold_state(human_btn, human_btn.button_pressed)
		_update_button_gold_state(computer_btn, computer_btn.button_pressed)
		_update_button_gold_state(off_btn, off_btn.button_pressed)

func _setup_difficulty_buttons():
	var buttons: Array = [
		get_node("CustomMap/Panel/VBoxContainer/Difficulty/Easy"),
		get_node("CustomMap/Panel/VBoxContainer/Difficulty/Normal"),
		get_node("CustomMap/Panel/VBoxContainer/Difficulty/Hard")
	]
	var group := ButtonGroup.new()
	for btn in buttons:
		btn.toggle_mode = true
		btn.button_group = group
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for btn in buttons:
		var selected: bool = btn.name == "Normal"
		btn.button_pressed = selected
		_update_button_gold_state(btn, selected)

func _setup_scenario_difficulty_buttons():
	scenario_difficulty_group = ButtonGroup.new()
	scenario_difficulty_group.allow_unpress = false
	for btn in scenario_difficulty_buttons:
		btn.toggle_mode = true
		btn.button_group = scenario_difficulty_group
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for btn in scenario_difficulty_buttons:
		var selected: bool = btn.name == "Normal"
		btn.button_pressed = selected

func _setup_victory_buttons():
	var buttons: Array = [
		get_node("CustomMap/Panel/VBoxContainer/VictoryConditions/Conquer"),
		get_node("CustomMap/Panel/VBoxContainer/VictoryConditions/Dominate")
	]
	var group := ButtonGroup.new()
	for btn in buttons:
		btn.toggle_mode = true
		btn.button_group = group
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for btn in buttons:
		var selected: bool = btn.name == "Conquer"
		btn.button_pressed = selected
		_update_button_gold_state(btn, selected)

func _get_selected_custom_map_victory() -> String:
	var conquer_button: Button = get_node("CustomMap/Panel/VBoxContainer/VictoryConditions/Conquer")
	if conquer_button.button_pressed:
		return "conquer"
	return "dominate"

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

func _load_custom_map_items():
	map_items = _gather_map_items()
	_apply_map_filter()

func _load_scenario_items():
	scenario_items = _gather_scenario_items(is_campaign_mode)
	_apply_map_filter()

func _apply_map_filter():
	_clear_map_selection()
	var items: Array = []
	if is_scenario_mode:
		for item in scenario_items:
			if current_map_filter == "All" or item.get("size", "S") == current_map_filter:
				items.append(item)
		_populate_map_list(items, true)
	else:
		for item in map_items:
			if current_map_filter == "All" or item.get("size", "S") == current_map_filter:
				items.append(item)
		_populate_map_list(items, false)

func _get_list_container(for_scenario: bool) -> VBoxContainer:
	if for_scenario and is_campaign_mode:
		return campaign_map_list
	return custom_map_list

func _get_template_row(for_scenario: bool) -> HBoxContainer:
	if for_scenario and is_campaign_mode:
		return campaign_template_row
	return custom_map_template_row

func _clear_map_list_nodes(container: VBoxContainer, template_row: HBoxContainer):
	for child in container.get_children():
		if child != template_row:
			child.queue_free()

func _populate_map_list(items: Array, for_scenario: bool):
	var container := _get_list_container(for_scenario)
	var template_row := _get_template_row(for_scenario)
	_clear_map_list_nodes(container, template_row)
	if template_row:
		template_row.visible = false
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var row: HBoxContainer = template_row.duplicate(true)
		row.name = "Entry" + str(i + 1)
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.visible = true
		var size_label: Label = row.get_node("Size")
		var name_label: Label = row.get_node("Name")
		size_label.text = item.get("size", "S")
		name_label.text = item.get("display_name", "Map")
		size_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		name_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_set_row_color(row, Color.WHITE)
		row.gui_input.connect(_on_map_row_gui_input.bind(row, item, for_scenario))
		row.mouse_entered.connect(_on_map_row_hovered.bind(row, item, for_scenario))
		row.mouse_exited.connect(_on_map_row_unhovered.bind(row, item, for_scenario))
		container.add_child(row)

func _on_map_row_gui_input(event: InputEvent, row: Control, item: Dictionary, for_scenario: bool):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_map_row_pressed(row, item, for_scenario)

func _on_map_row_pressed(row: Control, item: Dictionary, for_scenario: bool):
	var current_selected: Control = selected_scenario_button_custom if for_scenario else selected_map_button
	if current_selected and current_selected != row:
		_set_row_color(current_selected, Color.WHITE)
	_set_row_color(row, GOLD_COLOR)
	if for_scenario:
		selected_scenario_button_custom = row
		selected_scenario_item = item
		_update_info_labels(item)
		_update_preview_with_item(item, true)
		_set_scenario_select_enabled(true)
	else:
		selected_map_button = row
		selected_map_item = item
		_update_info_labels(item)
		_update_preview_with_item(item, false)
		_set_custom_map_select_enabled(true)

func _on_map_row_hovered(row: Control, item: Dictionary, for_scenario: bool):
	var current_selected: Control = selected_scenario_button_custom if for_scenario else selected_map_button
	if current_selected != row:
		_set_row_color(row, GOLD_COLOR)

func _on_map_row_unhovered(row: Control, item: Dictionary, for_scenario: bool):
	var current_selected: Control = selected_scenario_button_custom if for_scenario else selected_map_button
	if current_selected != row:
		_set_row_color(row, Color.WHITE)

func _set_row_color(row: Control, color: Color):
	if not row:
		return
	var size_label: Label = row.get_node("Size")
	var name_label: Label = row.get_node("Name")
	size_label.add_theme_color_override("font_color", color)
	name_label.add_theme_color_override("font_color", color)

func _update_button_gold_state(button: Button, selected: bool):
	button.button_pressed = selected

func _update_info_labels(item: Dictionary):
	custom_map_map_name_label.text = item.get("display_name", "Map Name")
	var size_code: String = item.get("size", "S")
	custom_map_map_size_label.text = _size_full_name(size_code)

func _update_preview_with_item(item: Dictionary, for_scenario: bool):
	var candidates: Array = []
	if for_scenario:
		var scen_name: String = item.get("name", "")
		if scen_name != "":
			candidates.append(scen_name)
		var map_base: String = item.get("map_file_base", "")
		if map_base != "":
			candidates.append(map_base)
	else:
		var file_base: String = item.get("file", "")
		if file_base != "":
			candidates.append(file_base)
	for base in candidates:
		if _set_custom_map_preview_texture(base):
			return
	custom_map_preview.texture = null
	custom_map_preview.visible = false

func _set_custom_map_preview_texture(base_name: String) -> bool:
	var preview_path := "res://previews/" + base_name + ".png"
	if ResourceLoader.exists(preview_path):
		var texture: Texture2D = load(preview_path)
		if texture:
			custom_map_preview.texture = texture
			custom_map_preview.visible = true
			return true
	return false

func _clear_map_selection():
	selected_map_item.clear()
	selected_scenario_item.clear()
	if selected_map_button:
		_set_row_color(selected_map_button, Color.WHITE)
	if selected_scenario_button_custom:
		_set_row_color(selected_scenario_button_custom, Color.WHITE)
	selected_map_button = null
	selected_scenario_button_custom = null
	_set_custom_map_select_enabled(false)
	_set_scenario_select_enabled(false)
	custom_map_map_name_label.text = "Map Name"
	custom_map_map_size_label.text = "Large"
	custom_map_preview.texture = null
	custom_map_preview.visible = false

func _set_custom_map_select_enabled(enabled: bool):
	custom_map_select_button.disabled = not enabled
	custom_map_select_button.text = "Start Game" if enabled else " Select Map "

func _set_scenario_select_enabled(enabled: bool):
	scenario_select_button_custom.disabled = not enabled
	scenario_select_button_custom.text = "Start Game" if enabled else " Select Map "

func _gather_map_items() -> Array:
	var items: Array = []
	var dir = DirAccess.open("res://mapdata")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var base := file_name.trim_suffix(".json")
				if base.begins_with("mission"):
					file_name = dir.get_next()
					continue
				var size_code := _extract_size_code(base)
				items.append({
					"file": base,
					"display_name": _display_name_for_map(base),
					"size": size_code
				})
			file_name = dir.get_next()
		dir.list_dir_end()
	items.sort_custom(Callable(self, "_sort_items"))
	return items

func _gather_scenario_items(require_mission_prefix: bool) -> Array:
	var items: Array = []
	var dir = DirAccess.open("res://scenarios")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var scenario_name := file_name.trim_suffix(".json")
				var has_prefix := scenario_name.begins_with("mission")
				if require_mission_prefix and not has_prefix:
					file_name = dir.get_next()
					continue
				if not require_mission_prefix and has_prefix:
					file_name = dir.get_next()
					continue
				var map_file_base: String = ""
				var size_code: String = "S"
				var file_path: String = "res://scenarios/" + file_name
				var content: String = FileAccess.get_file_as_string(file_path)
				var json = JSON.new()
				if json.parse(content) == OK:
					var data: Variant = json.get_data()
					if typeof(data) == TYPE_DICTIONARY and data.has("map_file"):
						map_file_base = str(data["map_file"]).trim_suffix(".json")
						size_code = _extract_size_code(map_file_base)
				items.append({
					"name": scenario_name,
					"display_name": scenario_name.capitalize().replace("_", " "),
					"size": size_code,
					"map_file_base": map_file_base
				})
			file_name = dir.get_next()
		dir.list_dir_end()
	items.sort_custom(Callable(self, "_sort_items"))
	return items

func _sort_items(a: Dictionary, b: Dictionary) -> bool:
	var sa: int = MAP_SIZE_ORDER.get(a.get("size", "S"), 4)
	var sb: int = MAP_SIZE_ORDER.get(b.get("size", "S"), 4)
	if sa == sb:
		return a.get("display_name", "") < b.get("display_name", "")
	return sa < sb

func _extract_size_code(base_name: String) -> String:
	var parts = base_name.split("-")
	var size_part = parts[parts.size() - 1].to_lower()
	match size_part:
		"xtiny", "tiny":
			return "T"
		"small":
			return "S"
		"medium":
			return "M"
		"large", "huge":
			return "L"
		_:
			return "S"

func _size_full_name(code: String) -> String:
	match code:
		"T":
			return "Tiny"
		"S":
			return "Small"
		"M":
			return "Medium"
		"L":
			return "Large"
		_:
			return "Unknown"

func _display_name_for_map(base: String) -> String:
	var parts := base.split("-")
	if parts.size() >= 2:
		parts = parts.slice(0, parts.size() - 1)
		var name_part := " ".join(parts)
		return name_part.capitalize().replace("_", " ")
	return base.capitalize().replace("_", " ")

func _on_scenario_hovered(scenario_name: String):
	current_hovered_item = scenario_name
	hover_timer.stop()
	_show_preview(scenario_name)

func _on_scenario_unhovered():
	current_hovered_item = ""
	hover_timer.start()

func _on_map_hovered(map_name: String):
	current_hovered_item = map_name
	hover_timer.stop()
	_show_preview(map_name)

func _on_map_unhovered():
	current_hovered_item = ""
	hover_timer.start()

func _on_hover_timer_timeout():
	if current_hovered_item == "":
		if default_preview_item != "":
			_show_preview(default_preview_item)
		else:
			_hide_preview()

func _show_preview(item_name: String):
	var preview_path = "res://previews/" + item_name + ".png"
	if ResourceLoader.exists(preview_path):
		var texture = load(preview_path)
		if texture:
			map_screenshot.texture = texture
			map_screenshot.visible = true
	else:
		_hide_preview()

func _hide_preview():
	map_screenshot.visible = false
	map_screenshot.texture = null

func _on_player_control_changed(toggled_on: bool, player_num: int, control_type: String, button: Button):
	if not toggled_on:
		return
	player_settings[player_num - 1].control_type = control_type
	for b in button.button_group.get_buttons():
		_update_button_gold_state(b, b == button)
	DebugLogger.log("UISystem", "Player " + str(player_num) + " set to: " + control_type)
