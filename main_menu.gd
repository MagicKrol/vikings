extends Control
class_name MainMenu

const DEMO_MODE_ENABLED: bool = GameParameters.DEMO_MODE_ENABLED
const TUTORIAL_SCENARIO_PATH: String = "res://scenarios/tutorial.json"
const LANGUAGE_ENGLISH_FLAG: Texture2D = preload("res://images/flags/english.png")
const LANGUAGE_GERMAN_FLAG: Texture2D = preload("res://images/flags/germany.png")
const LANGUAGE_POLISH_FLAG: Texture2D = preload("res://images/flags/poland.png")
const LANGUAGE_PORTUGUESE_BRAZIL_FLAG: Texture2D = preload("res://images/flags/brazil.png")
const MAIN_MENU_TARGET_META_KEY: String = "main_menu_target"
const MAIN_MENU_TARGET_CAMPAIGN_LIST: String = "campaign_list"
const FEEDBACK_URL: String = "https://steamcommunity.com/app/4380120/discussions/0/"

@onready var continue_button: Button = $MenuContainer/ContinueButton
@onready var new_game_button: Button = $MenuContainer/NewGameButton
@onready var load_game_button: Button = $MenuContainer/LoadGameButton
@onready var options_button: Button = $MenuContainer/OptionsButton
@onready var exit_button: Button = $MenuContainer/ExitButton
@onready var feedback_container: Control = $Feedback
@onready var feedback_button: Button = $Feedback/TextureRect/FeedbackButton
@onready var save_game_modal: MainMenuSaveGameModal = $SaveGameModal

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
@onready var custom_map_difficulty_buttons: Array[Button] = [
	get_node("CustomMap/Panel/VBoxContainer/Difficulty/Easy"),
	get_node("CustomMap/Panel/VBoxContainer/Difficulty/Normal"),
	get_node("CustomMap/Panel/VBoxContainer/Difficulty/Hard")
]
@onready var custom_map_list: VBoxContainer = $CustomMap/Panel3/VBoxContainer/ScrollContainer/MapList
@onready var custom_map_template_row: HBoxContainer = $CustomMap/Panel3/VBoxContainer/ScrollContainer/MapList/Row
@onready var campaign_map_list: VBoxContainer = $CustomMap/Panel4/VBoxContainer/ScrollContainer/MapList
@onready var campaign_template_row: HBoxContainer = $CustomMap/Panel4/VBoxContainer/ScrollContainer/MapList/Row
@onready var custom_map_preview: TextureRect = $CustomMap/Panel2/VBoxContainer/TextureRect
@onready var custom_map_map_name_label: Label = $CustomMap/Panel2/VBoxContainer/HBoxContainer/MapName
@onready var custom_map_map_size_label: Label = $CustomMap/Panel2/VBoxContainer/HBoxContainer2/MapSize
@onready var scenario_header_label: Label = $CustomMap/Scenario/VBoxContainer/Label
@onready var scenario_description_label: RichTextLabel = $CustomMap/Scenario/VBoxContainer/Description
@onready var scenario_objectives_label: Label = $CustomMap/Scenario/VBoxContainer/Description2
@onready var map_size_label: Label = $CustomMap/Panel3/VBoxContainer/MapSize
@onready var map_size_margin1: MarginContainer = $CustomMap/Panel3/VBoxContainer/MapSizeMargin1
@onready var map_sizes_container: HBoxContainer = $CustomMap/Panel3/VBoxContainer/Sizes
@onready var map_size_button_all: Button = $CustomMap/Panel3/VBoxContainer/Sizes/All
@onready var map_size_button_xs: Button = $CustomMap/Panel3/VBoxContainer/Sizes/XS
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

@onready var button_bg1 = $TextureRect1
@onready var button_bg2 = $TextureRect2
@onready var button_bg3 = $TextureRect3
@onready var button_bg4 = $TextureRect4
@onready var button_bg5 = $TextureRect5

# Map preview references
@onready var map_preview: Control = $MapPreview
@onready var map_screenshot: TextureRect = $MapPreview/InnerPanel/MapScreenshot
@onready var language_flag_icon: TextureRect = $Language/Flag
@onready var language_right_arrow: TextureRect = $Language/RightButton
@onready var language_left_arrow: TextureRect = $Language/LeftButton
@onready var language_label: Label = $Language/Text
@onready var custom_tooltip: TextureRect = $CustomTooltip
@onready var custom_tooltip_label: Label = $CustomTooltip/Label

var hover_timer: Timer
var current_hovered_item: String = ""
var default_preview_item: String = ""
var _language_index: int = 0

var sound_manager: SoundManager = null
var selected_scenario: String = ""
var selected_custom_map: String = ""
var selected_scenario_button: Button = null

# Custom map/scenario selection state
const ROW_HIGHLIGHT_NONE_COLOR: Color = Color(0, 0, 0, 0)
const ROW_HIGHLIGHT_HOVER_COLOR: Color = Color(0, 0, 0, 0.2)
const ROW_HIGHLIGHT_SELECTED_COLOR: Color = Color(0, 0, 0, 0.4)
const ROW_TEXT_COLOR: Color = Color(1, 1, 1, 1)
const MAP_SIZE_ORDER := {"XS": 0, "T": 0, "S": 1, "M": 2, "L": 3}
const SCENARIO_DIFFICULTY_ALL: String = "all"
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
var default_scenario_description_text: String = ""
var default_scenario_objectives_text: String = ""

# Player settings for custom map
var player_settings: Array = []  # Array of dictionaries with player configuration

func _ready():

	TranslationServer.set_locale(_resolve_startup_locale())
	# Create and add sound manager
	sound_manager = SoundManager.new()
	add_child(sound_manager)
	SaveGameManager.load_settings(sound_manager)
	_setup_language_controls()
	
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
	feedback_button.pressed.connect(_on_feedback_pressed)
	save_game_modal.back_requested.connect(_on_save_game_modal_back_requested)
	save_game_modal.action_requested.connect(_on_save_game_modal_action_requested)
	
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
	map_size_button_xs.pressed.connect(_on_size_filter_pressed.bind("XS", map_size_button_xs))
	map_size_button_small.pressed.connect(_on_size_filter_pressed.bind("S", map_size_button_small))
	map_size_button_medium.pressed.connect(_on_size_filter_pressed.bind("M", map_size_button_medium))
	map_size_button_large.pressed.connect(_on_size_filter_pressed.bind("L", map_size_button_large))

	# Hover sounds removed - no sound on mouse enter

	_setup_custom_map_preview()
	_setup_size_filter_group()
	_setup_player_buttons()
	_setup_difficulty_buttons()
	_setup_scenario_difficulty_buttons()
	_setup_victory_buttons()
	default_scenario_description_text = scenario_description_label.text
	default_scenario_objectives_text = scenario_objectives_label.text
	options_container.configure(sound_manager, false, tr("Back to Menu"))
	_update_primary_main_menu_button()

	if _apply_start_target_from_meta():
		return

	_show_main_menu()

func _apply_start_target_from_meta() -> bool:
	if not get_tree().has_meta(MAIN_MENU_TARGET_META_KEY):
		return false
	var target_variant: Variant = get_tree().get_meta(MAIN_MENU_TARGET_META_KEY)
	get_tree().set_meta(MAIN_MENU_TARGET_META_KEY, null)
	var target: String = String(target_variant)
	if target == MAIN_MENU_TARGET_CAMPAIGN_LIST:
		_show_campaign_menu()
		return true
	return false

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

func _setup_language_controls() -> void:
	language_right_arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	language_left_arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	language_right_arrow.gui_input.connect(_on_language_right_gui_input)
	language_left_arrow.gui_input.connect(_on_language_left_gui_input)
	_language_index = _language_index_from_locale(TranslationServer.get_locale())
	_apply_language_by_index(_language_index, false)

func _on_language_right_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_cycle_language(1)

func _on_language_left_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_cycle_language(-1)

func _cycle_language(step: int) -> void:
	_apply_language_by_index(_language_index + step, true)

func _apply_language_by_index(index: int, persist: bool) -> void:
	var language_count: int = 4
	_language_index = posmod(index, language_count)
	var locale: String = _locale_for_language_index(_language_index)
	TranslationServer.set_locale(locale)
	language_label.text = _label_for_language_index(_language_index)
	language_flag_icon.texture = _flag_for_language_index(_language_index)
	_update_primary_main_menu_button()
	options_container.configure(sound_manager, false, tr("Back to Menu"))
	if persist:
		SaveGameManager.save_settings(sound_manager)

func _language_index_from_locale(locale: String) -> int:
	var normalized_locale: String = locale.to_lower()
	if normalized_locale.begins_with("de"):
		return 1
	if normalized_locale.begins_with("pl"):
		return 2
	if normalized_locale.begins_with("br") or normalized_locale.begins_with("pt"):
		return 3
	return 0

func _locale_for_language_index(index: int) -> String:
	match index:
		1:
			return "de"
		2:
			return "pl"
		3:
			return "br"
		_:
			return "en"

func _label_for_language_index(index: int) -> String:
	match index:
		1:
			return "Deutsch"
		2:
			return "Polski"
		3:
			return "Português (Brasil)"
		_:
			return "English"

func _flag_for_language_index(index: int) -> Texture2D:
	match index:
		1:
			return LANGUAGE_GERMAN_FLAG
		2:
			return LANGUAGE_POLISH_FLAG
		3:
			return LANGUAGE_PORTUGUESE_BRAZIL_FLAG
		_:
			return LANGUAGE_ENGLISH_FLAG

func _resolve_startup_locale() -> String:
	var saved_locale: String = SaveGameManager.get_saved_locale()
	if saved_locale != "":
		return _normalize_supported_locale(saved_locale)
	var steam_locale: String = _get_steam_language_locale()
	if steam_locale != "":
		return _normalize_supported_locale(steam_locale)
	var os_locale: String = OS.get_locale_language()
	if os_locale == "":
		os_locale = OS.get_locale()
	return _normalize_supported_locale(os_locale)

func _get_steam_language_locale() -> String:
	if not Engine.has_singleton("Steam"):
		return ""
	var steam_singleton: Object = Engine.get_singleton("Steam")
	if steam_singleton == null:
		return ""
	var steam_language: String = ""
	if steam_singleton.has_method("getCurrentGameLanguage"):
		steam_language = String(steam_singleton.call("getCurrentGameLanguage"))
	elif steam_singleton.has_method("get_current_game_language"):
		steam_language = String(steam_singleton.call("get_current_game_language"))
	return steam_language.strip_edges().to_lower()

func _normalize_supported_locale(raw_locale: String) -> String:
	var normalized_locale: String = raw_locale.strip_edges().to_lower()
	if normalized_locale.begins_with("de"):
		return "de"
	if normalized_locale.begins_with("pl"):
		return "pl"
	if normalized_locale.begins_with("br") or normalized_locale.begins_with("pt"):
		return "br"
	return "en"

func _on_continue_pressed():
	var has_save_file: bool = SaveGameManager.has_save_file()
	if has_save_file:
		var latest_save_path: String = SaveGameManager.get_latest_save_path()
		DebugLogger.log("UISystem", "Continue button pressed")
		get_tree().set_meta("start_payload", {
			"type": "save",
			"save_path": latest_save_path
		})
	else:
		DebugLogger.log("UISystem", "Tutorial button pressed")
		get_tree().set_meta("start_payload", {
			"type": "scenario",
			"scenario_path": TUTORIAL_SCENARIO_PATH,
			"difficulty": "normal"
		})
	if sound_manager:
		sound_manager.stop_main_menu_music()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_new_game_pressed():
	DebugLogger.log("UISystem", "New Game button pressed")
	_show_new_game_menu()

func _on_load_game_pressed():
	DebugLogger.log("UISystem", "Load Game button pressed")
	var save_entries: Array[Dictionary] = SaveGameManager.get_save_entries()
	save_game_modal.configure(MainMenuSaveGameModal.Mode.LOAD, save_entries)
	save_game_modal.visible = true
	save_game_modal.move_to_front()

func _on_save_game_modal_back_requested() -> void:
	save_game_modal.visible = false
	_show_main_menu()

func _on_save_game_modal_action_requested(mode: int, selected_file_name: String, _entered_file_name: String) -> void:
	if mode != MainMenuSaveGameModal.Mode.LOAD:
		return
	if selected_file_name == "":
		return
	var save_path: String = SaveGameManager.build_save_path_from_file_name(selected_file_name)
	get_tree().set_meta("start_payload", {
		"type": "save",
		"save_path": save_path
	})
	sound_manager.stop_main_menu_music()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_options_pressed():
	DebugLogger.log("UISystem", "Options button pressed")
	_show_options_menu()

func _on_exit_pressed():
	DebugLogger.log("UISystem", "Exit button pressed")
	get_tree().quit()

func _on_feedback_pressed() -> void:
	DebugLogger.log("UISystem", "Feedback button pressed")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	OS.shell_open(FEEDBACK_URL)

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
			"scenario_path": scen_path,
			"difficulty": _get_selected_scenario_difficulty()
		})
		if sound_manager:
			sound_manager.stop_main_menu_music()
		get_tree().change_scene_to_file("res://main.tscn")

func _on_options_back_pressed():
	DebugLogger.log("UISystem", "Options Back button pressed")
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
			"scenario_path": scen_path,
			"difficulty": _get_selected_scenario_difficulty()
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
	var fallback_size_str: String = _size_full_name(size_code).to_lower()
	var size_str: String = String(selected_map_item.get("map_size_exact", fallback_size_str))
	var selected_victory: String = _get_selected_custom_map_victory()
	get_tree().set_meta("start_payload", {
		"type": "map",
		"map_file": map_path,
		"map_size": size_str,
		"player_settings": player_settings,
		"victory_condition": selected_victory,
		"difficulty": _get_selected_custom_map_difficulty()
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
		"scenario_path": scen_path,
		"difficulty": _get_selected_scenario_difficulty()
	})
	if sound_manager:
		sound_manager.stop_main_menu_music()
	get_tree().change_scene_to_file("res://main.tscn")

func _show_main_menu():
	"""Show the main menu and hide other menus"""
	_update_primary_main_menu_button()
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
	feedback_container.visible = false

func _update_primary_main_menu_button() -> void:
	var has_save_file: bool = SaveGameManager.has_save_file()
	if has_save_file:
		continue_button.text = tr("Continue")
	else:
		continue_button.text = tr("Tutorial")

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
	feedback_container.visible = false

func _show_options_menu():
	"""Show the options menu"""
	options_container.configure(sound_manager, false, tr("Back to Menu"))
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
	feedback_container.visible = false

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
	feedback_container.visible = false
	is_scenario_mode = true
	is_campaign_mode = true
	custom_map_panel.visible = false
	scenario_panel.visible = true
	custom_map_panel2.visible = true
	custom_map_panel3.visible = false
	campaign_panel.visible = true
	custom_map_panel3_label.text = tr("Campaign List")
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
	feedback_container.visible = false
	is_scenario_mode = true
	is_campaign_mode = false
	custom_map_panel.visible = false
	scenario_panel.visible = true
	custom_map_panel2.visible = true
	custom_map_panel3.visible = true
	campaign_panel.visible = false
	custom_map_panel3_label.text = tr("Scenario List")
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
	feedback_container.visible = false
	is_scenario_mode = false
	custom_map_panel.visible = true
	scenario_panel.visible = false
	custom_map_panel2.visible = true
	custom_map_panel3.visible = true
	campaign_panel.visible = false
	custom_map_panel3_label.text = tr("Select Map")
	_set_campaign_ui(false)
	_clear_map_selection()
	_load_custom_map_items()

func _set_campaign_ui(enabled: bool):
	scenario_header_label.text = tr("Campaign") if enabled else tr("Scenario")
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
	var buttons: Array = [map_size_button_all, map_size_button_xs, map_size_button_small, map_size_button_medium, map_size_button_large]
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
		if DEMO_MODE_ENABLED and player_num >= 5:
			human_btn.disabled = true
			computer_btn.disabled = true
			off_btn.button_pressed = true
		player_settings.append({"player_id": player_num, "control_type": default_control})
		human_btn.toggled.connect(_on_player_control_changed.bind(player_num, "Player", human_btn))
		computer_btn.toggled.connect(_on_player_control_changed.bind(player_num, "Computer", computer_btn))
		off_btn.toggled.connect(_on_player_control_changed.bind(player_num, "Off", off_btn))
		_update_button_gold_state(human_btn, human_btn.button_pressed)
		_update_button_gold_state(computer_btn, computer_btn.button_pressed)
		_update_button_gold_state(off_btn, off_btn.button_pressed)

func _setup_difficulty_buttons():
	var group := ButtonGroup.new()
	for btn in custom_map_difficulty_buttons:
		btn.toggle_mode = true
		btn.button_group = group
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.mouse_entered.connect(_on_difficulty_button_hovered.bind(btn))
		btn.mouse_exited.connect(_on_custom_tooltip_unhovered)
	for btn in custom_map_difficulty_buttons:
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
		btn.mouse_entered.connect(_on_difficulty_button_hovered.bind(btn))
		btn.mouse_exited.connect(_on_custom_tooltip_unhovered)
	_set_scenario_difficulty_buttons_enabled(true)
	_select_scenario_difficulty("normal")

func _difficulty_from_buttons(buttons: Array[Button]) -> String:
	for btn in buttons:
		if btn.button_pressed:
			return btn.name.to_lower()
	return "normal"

func _normalize_scenario_difficulty(difficulty_value: String) -> String:
	var normalized: String = difficulty_value.to_lower()
	match normalized:
		"easy", "normal", "hard":
			return normalized
		_:
			return SCENARIO_DIFFICULTY_ALL

func _set_scenario_difficulty_buttons_enabled(enabled: bool) -> void:
	for btn in scenario_difficulty_buttons:
		btn.disabled = not enabled

func _select_scenario_difficulty(difficulty_value: String) -> void:
	var normalized: String = _normalize_scenario_difficulty(difficulty_value)
	var selected_name: String = "normal"
	if normalized != SCENARIO_DIFFICULTY_ALL:
		selected_name = normalized
	for btn in scenario_difficulty_buttons:
		var selected: bool = btn.name.to_lower() == selected_name
		_update_button_gold_state(btn, selected)

func _apply_scenario_difficulty_constraints(item: Dictionary) -> void:
	var scenario_difficulty: String = _normalize_scenario_difficulty(String(item.get("difficulty", SCENARIO_DIFFICULTY_ALL)))
	if scenario_difficulty == SCENARIO_DIFFICULTY_ALL:
		_set_scenario_difficulty_buttons_enabled(true)
		return
	_select_scenario_difficulty(scenario_difficulty)
	for btn in scenario_difficulty_buttons:
		var btn_difficulty: String = btn.name.to_lower()
		btn.disabled = btn_difficulty != scenario_difficulty

func _get_selected_custom_map_difficulty() -> String:
	return _difficulty_from_buttons(custom_map_difficulty_buttons)

func _get_selected_scenario_difficulty() -> String:
	return _difficulty_from_buttons(scenario_difficulty_buttons)

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
		btn.mouse_entered.connect(_on_victory_button_hovered.bind(btn))
		btn.mouse_exited.connect(_on_custom_tooltip_unhovered)
	for btn in buttons:
		var selected: bool = btn.name == "Conquer"
		btn.button_pressed = selected
		_update_button_gold_state(btn, selected)

func _on_difficulty_button_hovered(button: Button) -> void:
	var description_key: String = ""
	match button.name:
		"Easy":
			description_key = "difficulty_easy_description"
		"Normal":
			description_key = "difficulty_normal_description"
		"Hard":
			description_key = "difficulty_hard_description"
		_:
			return
	_show_custom_tooltip(description_key)

func _on_victory_button_hovered(button: Button) -> void:
	var description_key: String = ""
	match button.name:
		"Conquer":
			description_key = "conquer_condition_description"
		"Dominate":
			description_key = "dominate_condition_description"
		_:
			return
	_show_custom_tooltip(description_key)

func _show_custom_tooltip(description_key: String) -> void:
	custom_tooltip_label.text = tr(description_key)
	custom_tooltip.visible = true

func _on_custom_tooltip_unhovered() -> void:
	custom_tooltip.visible = false

func _get_selected_custom_map_victory() -> String:
	var conquer_button: Button = get_node("CustomMap/Panel/VBoxContainer/VictoryConditions/Conquer")
	var dominate_button: Button = get_node("CustomMap/Panel/VBoxContainer/VictoryConditions/Dominate")
	if conquer_button.button_pressed:
		return "conquer"
	if dominate_button.button_pressed:
		return "dominate"
	return ""

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
	button.text = tr(scenario_name.capitalize().replace("_", " "))
	
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
	button.text = tr(scenario_name.capitalize().replace("_", " "))
	
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
	var requested_type: String = "campaign" if is_campaign_mode else "scenario"
	scenario_items = _gather_scenario_items(requested_type)
	_apply_map_filter()

func _apply_map_filter():
	_clear_map_selection()
	var filter_code: String = _normalize_frontend_size_code(current_map_filter)
	var items: Array = []
	if is_scenario_mode:
		for item in scenario_items:
			var item_size: String = _normalize_frontend_size_code(String(item.get("size", "S")))
			if filter_code == "ALL" or item_size == filter_code:
				items.append(item)
		_populate_map_list(items, true)
	else:
		for item in map_items:
			var item_size: String = _normalize_frontend_size_code(String(item.get("size", "S")))
			if filter_code == "ALL" or item_size == filter_code:
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
	var first_created_row: HBoxContainer = null
	var first_created_item: Dictionary = {}
	_clear_map_list_nodes(container, template_row)
	if template_row:
		template_row.visible = false
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var row: HBoxContainer = template_row.duplicate(true)
		if not row.has_method("set_highlight_color"):
			row.set_script(load("res://map_list_row.gd"))
		row.name = "Entry" + str(i + 1)
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.visible = true
		var size_label: Label = row.get_node("Size")
		var name_label: Label = row.get_node("Name")
		if for_scenario and is_campaign_mode:
			size_label.text = str(int(item.get("mission_number", 0)))
		else:
			size_label.text = item.get("size", "S")
		name_label.text = _resolve_item_display_name(item)
		size_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		name_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_set_row_highlight_color(row, ROW_HIGHLIGHT_NONE_COLOR)
		row.gui_input.connect(_on_map_row_gui_input.bind(row, item, for_scenario))
		row.mouse_entered.connect(_on_map_row_hovered.bind(row, item, for_scenario))
		row.mouse_exited.connect(_on_map_row_unhovered.bind(row, item, for_scenario))
		container.add_child(row)
		if i == 0:
			first_created_row = row
			first_created_item = item
	if first_created_row:
		_on_map_row_pressed(first_created_row, first_created_item, for_scenario)

func _on_map_row_gui_input(event: InputEvent, row: Control, item: Dictionary, for_scenario: bool):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_map_row_pressed(row, item, for_scenario)

func _on_map_row_pressed(row: Control, item: Dictionary, for_scenario: bool):
	var current_selected: Control = selected_scenario_button_custom if for_scenario else selected_map_button
	if current_selected and not is_instance_valid(current_selected):
		current_selected = null
		if for_scenario:
			selected_scenario_button_custom = null
		else:
			selected_map_button = null
	if current_selected and current_selected != row:
		_set_row_highlight_color(current_selected, ROW_HIGHLIGHT_NONE_COLOR)
	_set_row_highlight_color(row, ROW_HIGHLIGHT_SELECTED_COLOR)
	if for_scenario:
		selected_scenario_button_custom = row
		selected_scenario_item = item
		_apply_scenario_difficulty_constraints(item)
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
	if current_selected and not is_instance_valid(current_selected):
		current_selected = null
		if for_scenario:
			selected_scenario_button_custom = null
		else:
			selected_map_button = null
	if current_selected != row:
		_set_row_highlight_color(row, ROW_HIGHLIGHT_HOVER_COLOR)

func _on_map_row_unhovered(row: Control, item: Dictionary, for_scenario: bool):
	var current_selected: Control = selected_scenario_button_custom if for_scenario else selected_map_button
	if current_selected and not is_instance_valid(current_selected):
		current_selected = null
		if for_scenario:
			selected_scenario_button_custom = null
		else:
			selected_map_button = null
	if current_selected != row:
		_set_row_highlight_color(row, ROW_HIGHLIGHT_NONE_COLOR)

func _set_row_highlight_color(row: Control, color: Color) -> void:
	var size_label: Label = row.get_node("Size")
	var name_label: Label = row.get_node("Name")
	size_label.add_theme_color_override("font_color", ROW_TEXT_COLOR)
	name_label.add_theme_color_override("font_color", ROW_TEXT_COLOR)
	if row.has_method("set_highlight_color"):
		row.call("set_highlight_color", color)

func _update_button_gold_state(button: Button, selected: bool):
	button.button_pressed = selected

func _update_info_labels(item: Dictionary):
	custom_map_map_name_label.text = _resolve_item_display_name(item)
	var size_code: String = item.get("size", "S")
	custom_map_map_size_label.text = _size_full_name(size_code)
	if is_scenario_mode:
		_update_scenario_details_labels(item)

func _update_scenario_details_labels(item: Dictionary) -> void:
	var description: String = String(item.get("description", ""))
	var objectives: String = String(item.get("objectives", ""))
	var resolved_description: String = description if description != "" else default_scenario_description_text
	var resolved_objectives: String = objectives if objectives != "" else default_scenario_objectives_text
	scenario_description_label.text = tr(resolved_description)
	scenario_objectives_label.text = tr(resolved_objectives)

func _update_preview_with_item(item: Dictionary, for_scenario: bool):
	var candidates: Array = []
	if for_scenario:
		var scenario_file_base: String = String(item.get("scenario_file_base", item.get("name", "")))
		if scenario_file_base != "":
			candidates.append(scenario_file_base)
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
	selected_map_item = {}
	selected_scenario_item = {}
	if selected_map_button and not is_instance_valid(selected_map_button):
		selected_map_button = null
	if selected_scenario_button_custom and not is_instance_valid(selected_scenario_button_custom):
		selected_scenario_button_custom = null
	if selected_map_button:
		_set_row_highlight_color(selected_map_button, ROW_HIGHLIGHT_NONE_COLOR)
	if selected_scenario_button_custom:
		_set_row_highlight_color(selected_scenario_button_custom, ROW_HIGHLIGHT_NONE_COLOR)
	selected_map_button = null
	selected_scenario_button_custom = null
	_set_scenario_difficulty_buttons_enabled(true)
	_select_scenario_difficulty("normal")
	_set_custom_map_select_enabled(false)
	_set_scenario_select_enabled(false)
	custom_map_map_name_label.text = tr("Map Name")
	custom_map_map_size_label.text = tr("Large")
	scenario_description_label.text = tr(default_scenario_description_text)
	scenario_objectives_label.text = tr(default_scenario_objectives_text)
	custom_map_preview.texture = null
	custom_map_preview.visible = false

func _set_custom_map_select_enabled(enabled: bool):
	custom_map_select_button.disabled = not enabled
	custom_map_select_button.text = tr("Start Game") if enabled else tr("Select Map")

func _set_scenario_select_enabled(enabled: bool):
	scenario_select_button_custom.disabled = not enabled
	scenario_select_button_custom.text = tr("Start Game") if enabled else tr("Select Map")

func _gather_map_items() -> Array:
	var items: Array = []
	var allowed_custom_maps: Array[String] = GameParameters.DEMO_ALLOWED_CUSTOM_MAP_FILES
	var dir = DirAccess.open("res://mapdata")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				if DEMO_MODE_ENABLED and not allowed_custom_maps.has(file_name):
					file_name = dir.get_next()
					continue
				var base := file_name.trim_suffix(".json")
				if base.begins_with("mission"):
					file_name = dir.get_next()
					continue
				var map_profile: Dictionary = _resolve_map_profile_for_file(file_name)
				var size_code: String = _normalize_frontend_size_code(String(map_profile.get("frontend_size_code", "S")))
				var exact_size: String = String(map_profile.get("canonical_size_token", "small"))
				var region_count: int = int(map_profile.get("region_count", 0))
				items.append({
					"file": base,
					"display_name_key": _display_key_for_map(base),
					"display_name": _display_name_for_map(base),
					"size": size_code,
					"map_size_exact": exact_size,
					"region_count": region_count
				})
			file_name = dir.get_next()
		dir.list_dir_end()
	items.sort_custom(Callable(self, "_sort_items"))
	return items

func _gather_scenario_items(requested_type: String) -> Array:
	var items: Array = []
	var allowed_scenarios: Array[String] = GameParameters.DEMO_ALLOWED_SCENARIO_FILES
	var dir = DirAccess.open("res://scenarios")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				if DEMO_MODE_ENABLED and not allowed_scenarios.has(file_name):
					file_name = dir.get_next()
					continue
				var scenario_name := file_name.trim_suffix(".json")
				var map_file_base: String = ""
				var size_code: String = "S"
				var scenario_type: String = "scenario"
				var scenario_difficulty: String = SCENARIO_DIFFICULTY_ALL
				var description: String = ""
				var objectives: String = ""
				var scenario_title_key: String = ""
				var mission_number: int = 0
				var file_path: String = "res://scenarios/" + file_name
				var content: String = FileAccess.get_file_as_string(file_path)
				var json = JSON.new()
				if json.parse(content) == OK:
					var data: Variant = json.get_data()
					if typeof(data) == TYPE_DICTIONARY:
						var dict_data: Dictionary = data
						if dict_data.has("map_file"):
							map_file_base = str(dict_data["map_file"]).trim_suffix(".json")
							var map_profile: Dictionary = _resolve_map_profile_for_file(map_file_base + ".json")
							size_code = _normalize_frontend_size_code(String(map_profile.get("frontend_size_code", "S")))
						scenario_type = String(dict_data.get("scenario_type", "scenario")).to_lower()
						scenario_difficulty = _normalize_scenario_difficulty(String(dict_data.get("difficulty", SCENARIO_DIFFICULTY_ALL)))
						description = String(dict_data.get("description", ""))
						objectives = String(dict_data.get("objectives", ""))
						scenario_title_key = String(dict_data.get("name", "")).strip_edges()
						mission_number = int(dict_data.get("mission_number", 0))
				if scenario_type != requested_type:
					file_name = dir.get_next()
					continue
				var display_name: String = scenario_name.capitalize().replace("_", " ")
				var display_name_key: String = scenario_title_key
				if display_name_key == "":
					display_name_key = scenario_name
				items.append({
					"name": scenario_name,
					"scenario_file_base": scenario_name,
					"display_name_key": display_name_key,
					"display_name": display_name,
					"size": size_code,
					"map_file_base": map_file_base,
					"mission_number": mission_number,
					"difficulty": scenario_difficulty,
					"description": description,
					"objectives": objectives
				})
			file_name = dir.get_next()
		dir.list_dir_end()
	if requested_type == "campaign":
		items.sort_custom(Callable(self, "_sort_campaign_items"))
	else:
		items.sort_custom(Callable(self, "_sort_items"))
	return items

func _resolve_map_profile_for_file(map_file_name: String) -> Dictionary:
	var file_only: String = map_file_name.get_file()
	var file_name: String = file_only if file_only.ends_with(".json") else (file_only + ".json")
	var file_path: String = "res://mapdata/" + file_name
	var region_count: int = 0
	var content: String = FileAccess.get_file_as_string(file_path)
	if content != "":
		var json := JSON.new()
		if json.parse(content) == OK:
			var data: Variant = json.get_data()
			if typeof(data) == TYPE_DICTIONARY:
				var dict_data: Dictionary = data
				var regions_value: Variant = dict_data.get("regions", [])
				if typeof(regions_value) == TYPE_ARRAY:
					region_count = (regions_value as Array).size()
	if region_count > 0:
		var frontend_size_code: String = Utils.get_frontend_size_code_from_region_count(region_count)
		return {
			"token": Utils.extract_map_size_token(file_name),
			"region_count": region_count,
			"canonical_size_token": Utils.get_nearest_anchor_label_from_region_count(region_count),
			"visual_scale": Utils.get_map_visual_scale_from_region_count(region_count),
			"initial_zoom": Utils.get_initial_zoom_from_region_count(region_count),
			"frontend_size_code": frontend_size_code,
			"frontend_size_label": Utils.get_frontend_size_label_from_code(frontend_size_code),
			"source": "json_regions"
		}
	return Utils.resolve_map_profile(file_name, region_count)

func _sort_items(a: Dictionary, b: Dictionary) -> bool:
	var sa: int = MAP_SIZE_ORDER.get(_normalize_frontend_size_code(String(a.get("size", "S"))), 4)
	var sb: int = MAP_SIZE_ORDER.get(_normalize_frontend_size_code(String(b.get("size", "S"))), 4)
	if sa == sb:
		return a.get("display_name", "") < b.get("display_name", "")
	return sa < sb

func _sort_campaign_items(a: Dictionary, b: Dictionary) -> bool:
	var ma: int = int(a.get("mission_number", 0))
	var mb: int = int(b.get("mission_number", 0))
	if ma > 0 and mb > 0 and ma != mb:
		return ma < mb
	return a.get("display_name", "") < b.get("display_name", "")

func _normalize_frontend_size_code(code: String) -> String:
	var normalized: String = code.strip_edges().to_upper()
	match normalized:
		"ALL":
			return "ALL"
		"XS", "T", "XTINY", "XXTINY", "TINY":
			return "XS"
		"S", "SMALL":
			return "S"
		"M", "MEDIUM":
			return "M"
		"L", "LARGE", "HUGE":
			return "L"
		_:
			return normalized

func _extract_size_code(base_name: String) -> String:
	var parts = base_name.split("-")
	var size_part = parts[parts.size() - 1].to_lower()
	match size_part:
		"xtiny", "tiny":
			return "XS"
		"small":
			return "S"
		"medium":
			return "M"
		"large", "huge":
			return "L"
		_:
			return "S"

func _extract_exact_size_name(base_name: String) -> String:
	var parts: Array = base_name.split("-")
	if parts.is_empty():
		return "small"
	var size_part: String = String(parts[parts.size() - 1]).to_lower()
	match size_part:
		"xtiny", "tiny", "small", "medium", "large", "huge":
			return size_part
		_:
			return "small"

func _size_full_name(code: String) -> String:
	match code:
		"XS", "T":
			return tr("Extra Small")
		"S":
			return tr("Small")
		"M":
			return tr("Medium")
		"L":
			return tr("Large")
		_:
			return tr("Unknown")

func _display_name_for_map(base: String) -> String:
	var normalized: String = base.replace("_", "-")
	var parts := normalized.split("-")
	if parts.size() >= 2:
		parts = parts.slice(0, parts.size() - 1)
		var name_part := " ".join(parts)
		return name_part.capitalize()
	return base.capitalize().replace("_", " ")

func _display_key_for_map(base: String) -> String:
	var normalized: String = base.replace("_", "-")
	var parts := normalized.split("-")
	if parts.size() >= 3:
		var leading: String = String(parts[0]).strip_edges()
		if leading != "":
			return leading + "_map"
	return ""

func _resolve_item_display_name(item: Dictionary) -> String:
	var fallback: String = String(item.get("display_name", "Map Name"))
	var key: String = String(item.get("display_name_key", "")).strip_edges()
	if key != "":
		var translated_key: String = tr(key)
		if translated_key != key:
			return translated_key
	return tr(fallback)

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
