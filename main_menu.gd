extends Control
class_name MainMenu

const TUTORIAL_SCENARIO_PATH: String = "res://scenarios/tutorial.json"
const LANGUAGE_ENGLISH_FLAG: Texture2D = preload("res://images/flags/english.png")
const LANGUAGE_GERMAN_FLAG: Texture2D = preload("res://images/flags/germany.png")
const LANGUAGE_POLISH_FLAG: Texture2D = preload("res://images/flags/poland.png")
const LANGUAGE_PORTUGUESE_BRAZIL_FLAG: Texture2D = preload("res://images/flags/brazil.png")
const MAIN_MENU_TARGET_META_KEY: String = "main_menu_target"
const MAIN_MENU_TARGET_CAMPAIGN_LIST: String = "campaign_list"
const FEEDBACK_URL: String = "https://steamcommunity.com/app/4380120/discussions/0/"
const CARD_GREEN_TEXTURE: Texture2D = preload("res://images/card_green.png")
const CARD_GREEN_DISABLED_TEXTURE: Texture2D = preload("res://images/card_green_disabled.png")
const CARD_GREEN_SELECTED_TEXTURE: Texture2D = preload("res://images/card_green_selected.png")
const CARD_BLUE_TEXTURE: Texture2D = preload("res://images/card_blue.png")
const CARD_BLUE_DISABLED_TEXTURE: Texture2D = preload("res://images/card_blue_disabled.png")
const CARD_BLUE_SELECTED_TEXTURE: Texture2D = preload("res://images/card_blue_selected.png")
const LEVEL_LOCKED_TEXTURE: Texture2D = preload("res://images/level_locked.png")
const LEVEL_1_TEXTURE: Texture2D = preload("res://images/level1.png")
const LEVEL_2_TEXTURE: Texture2D = preload("res://images/level2.png")
const LEVEL_3_TEXTURE: Texture2D = preload("res://images/level3.png")
const CARD_LEVEL_TOOLTIP_OFFSET: Vector2 = Vector2(18.0, 18.0)
const MAPGEN_GENERATOR: Script = preload("res://mapgen/mapgen_generator.gd")
const RANDOM_SEED_MIN: int = 0
const RANDOM_SEED_MAX: int = 2147483647
const RANDOM_FORESTS_GENERATION_MIN: float = 0.25
const MAP_TYPE_ORIGINAL: String = "original"
const MAP_TYPE_RANDOM: String = "random"
const MAP_TYPE_SAVED: String = "saved"
const USER_MAPS_DIRECTORY: String = "user://user_maps"
const USER_MAP_EDITOR_PAYLOAD_META_KEY: String = "user_map_editor_payload"
const USER_MAP_EDITOR_RESULT_META_KEY: String = "user_map_editor_result"
const INVALID_MAP_MESSAGE: String = "Invalid Map: Some of the regions are inaccessible - surrounded by ocean, or mountains."
const MAP_PREVIEW_NORMAL_SIZE: Vector2 = Vector2(450.0, 450.0)
const MAP_PREVIEW_EXPANDED_SIZE: Vector2 = Vector2(1050.0, 1050.0)
const MAP_PREVIEW_EXPANDED_POSITION: Vector2 = Vector2(50.0, 50.0)
const GENERATED_PREVIEW_NORMAL_POSITION: Vector2 = Vector2(15.0, 15.0)
const GENERATED_PREVIEW_NORMAL_SCALE: Vector2 = Vector2(0.21, 0.21)
const DEFAULT_MAP_NAME_WIDTH: float = 370.0
const SAVED_MAP_NAME_WIDTH: float = 325.0

@onready var continue_button: Button = $MenuContainer/ContinueButton
@onready var new_game_button: Button = $MenuContainer/NewGameButton
@onready var load_game_button: Button = $MenuContainer/LoadGameButton
@onready var options_button: Button = $MenuContainer/OptionsButton
@onready var upgrades_button: Button = $MenuContainer/UpgradesButton
@onready var exit_button: Button = $MenuContainer/ExitButton
@onready var demo_mode_enabled: bool = GameParameters.is_demo_mode_enabled()
@onready var feedback_container: Control = $Feedback
@onready var feedback_button: Button = $Feedback/TextureRect/FeedbackButton
@onready var save_game_modal: MainMenuSaveGameModal = $SaveGameModal
@onready var cards_container: Control = $Cards
@onready var cards_title_label: Label = $Cards/VBoxContainer/Label
@onready var cards_back_button: Button = $Cards/VBoxContainer/HBoxContainer2/Back
@onready var cards_rows: GridContainer = $Cards/VBoxContainer/Rows
@onready var cards_limit_label: Label = $Cards/VBoxContainer/Label2
@onready var cards_spacer_label: Label = $Cards/VBoxContainer/Label3
@onready var card_level_tooltip: SelectTooltipModalNoRes = $Cards/LevelTooltip

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
@onready var scenario_list_background: TextureRect = $CustomMap/Panel3/ScenarioArmyTexture
@onready var skirmish_list_background: TextureRect = $CustomMap/Panel3/SkirmishArmyTexture
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
@onready var generated_map_preview: SubViewportContainer = $CustomMap/Panel2/VBoxContainer/GeneratedPreview
@onready var generated_map_renderer: MapGenerator = $CustomMap/Panel2/VBoxContainer/GeneratedPreview/SubViewport/MapRenderer
@onready var custom_map_preview_parent: VBoxContainer = $CustomMap/Panel2/VBoxContainer
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
@onready var map_type_label: Label = $CustomMap/Panel3/VBoxContainer/MapType
@onready var map_type_margin: MarginContainer = $CustomMap/Panel3/VBoxContainer/MapSizeMargin2
@onready var map_type_buttons_container: HBoxContainer = $CustomMap/Panel3/VBoxContainer/Sizes2
@onready var map_type_original_button: Button = $CustomMap/Panel3/VBoxContainer/Sizes2/Original
@onready var map_type_random_button: Button = $CustomMap/Panel3/VBoxContainer/Sizes2/Random
@onready var map_type_saved_button: Button = $CustomMap/Panel3/VBoxContainer/Sizes2/Saved
@onready var custom_map_list_headers: HBoxContainer = $CustomMap/Panel3/VBoxContainer/Headers
@onready var custom_map_list_header_margin: MarginContainer = $CustomMap/Panel3/VBoxContainer/MarginContainer8
@onready var custom_map_scroll_container: ScrollContainer = $CustomMap/Panel3/VBoxContainer/ScrollContainer
@onready var random_parameters: VBoxContainer = $CustomMap/Panel3/VBoxContainer/RandomParameters
@onready var random_map_seed_input: LineEdit = $CustomMap/Panel3/VBoxContainer/RandomParameters/MapSeedRow/Input
@onready var random_map_seed_button: Button = $CustomMap/Panel3/VBoxContainer/RandomParameters/MapSeedRow/Random
@onready var random_biome_seed_input: LineEdit = $CustomMap/Panel3/VBoxContainer/RandomParameters/BiomeSeedRow/Input
@onready var random_biome_seed_button: Button = $CustomMap/Panel3/VBoxContainer/RandomParameters/BiomeSeedRow/Random
@onready var random_forests_slider: HSlider = $CustomMap/Panel3/VBoxContainer/RandomParameters/ForestsSlider
@onready var random_hills_slider: HSlider = $CustomMap/Panel3/VBoxContainer/RandomParameters/HillsSlider
@onready var random_mountains_slider: HSlider = $CustomMap/Panel3/VBoxContainer/RandomParameters/MountainsSlider
@onready var random_sea_level_slider: HSlider = $CustomMap/Panel3/VBoxContainer/RandomParameters/SeaLevelSlider
@onready var random_forests_value: Label = $CustomMap/Panel3/VBoxContainer/RandomParameters/ForestsHeader/Value
@onready var random_hills_value: Label = $CustomMap/Panel3/VBoxContainer/RandomParameters/HillsHeader/Value
@onready var random_mountains_value: Label = $CustomMap/Panel3/VBoxContainer/RandomParameters/MountainsHeader/Value
@onready var random_sea_level_value: Label = $CustomMap/Panel3/VBoxContainer/RandomParameters/SeaLevelHeader/Value
@onready var edit_random_map_button: Button = $CustomMap/Panel3/VBoxContainer/RandomParameters/EditMapRow/EditMap

# Container references
@onready var menu_container: VBoxContainer = $MenuContainer
@onready var new_game_container: VBoxContainer = $NewGame
@onready var options_container: OptionsPanel = $Options
@onready var campaign_container: VBoxContainer = $Campaign
@onready var scenario_container: VBoxContainer = $Scenario
@onready var demo_container: VBoxContainer = $Demo

@onready var button_bg1: TextureRect = $TextureRect1
@onready var button_bg2: TextureRect = $TextureRect2
@onready var button_bg3: TextureRect = $TextureRect3
@onready var button_bg4: TextureRect = $TextureRect4
@onready var button_bg5: TextureRect = $TextureRect5
@onready var button_bg6: TextureRect = $TextureRect6

# Map preview references
@onready var map_preview: Control = $MapPreview
@onready var map_screenshot: TextureRect = $MapPreview/InnerPanel/MapScreenshot
@onready var language_flag_icon: TextureRect = $Language/Flag
@onready var language_right_arrow: TextureRect = $Language/RightButton
@onready var language_left_arrow: TextureRect = $Language/LeftButton
@onready var language_label: Label = $Language/Text
@onready var custom_tooltip: TextureRect = $CustomTooltip
@onready var custom_tooltip_label: Label = $CustomTooltip/Label
@onready var saved_map_delete_confirm: Control = $SavedMapDeleteConfirm
@onready var saved_map_delete_message: Label = $SavedMapDeleteConfirm/Dialog/Content/Message
@onready var saved_map_delete_confirm_button: Button = $SavedMapDeleteConfirm/Dialog/Content/Buttons/Confirm
@onready var saved_map_delete_cancel_button: Button = $SavedMapDeleteConfirm/Dialog/Content/Buttons/Cancel

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
const ROW_DISABLED_TEXT_COLOR: Color = Color(0.45, 0.45, 0.45, 1)
const CAMPAIGN_ALWAYS_UNLOCKED_MISSION_MAX: int = 2
const MAP_SIZE_ORDER := {"XS": 0, "T": 0, "S": 1, "M": 2, "L": 3}
const SCENARIO_DIFFICULTY_ALL: String = "all"
var map_items: Array = []
var scenario_items: Array = []
var selected_map_item: Dictionary = {}
var selected_map_button: Control = null
var selected_scenario_item: Dictionary = {}
var selected_scenario_button_custom: Control = null
var size_filter_button_group: ButtonGroup = null
var map_type_button_group: ButtonGroup = null
var current_map_filter: String = "All"
var current_map_type: String = MAP_TYPE_ORIGINAL
var random_map_size: String = "S"
var random_map_seed: int = 187
var random_biome_seed: int = MapgenConfig.NOISE_SEED
var generated_random_map_data: Dictionary = {}
var random_map_initialized: bool = false
var map_preview_expanded: bool = false
var expanded_map_preview: Control
var custom_map_preview_index: int = 0
var generated_map_preview_index: int = 0
var generated_map_preview_cursor_active: bool = false
var is_scenario_mode: bool = false
var is_campaign_mode: bool = false
var scenario_difficulty_group: ButtonGroup
var default_scenario_description_text: String = ""
var default_scenario_objectives_text: String = ""
var main_game_debug_mode: bool = true
var cards_selection_mode: bool = false
var pending_start_payload: Dictionary = {}
var selected_upgrade_card_ids: Array[String] = []
var pending_saved_map_delete_path: String = ""

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
	upgrades_button.pressed.connect(_on_upgrades_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	feedback_button.pressed.connect(_on_feedback_pressed)
	cards_back_button.pressed.connect(_on_cards_back_pressed)
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
	map_type_original_button.pressed.connect(_on_map_type_pressed.bind(MAP_TYPE_ORIGINAL))
	map_type_random_button.pressed.connect(_on_map_type_pressed.bind(MAP_TYPE_RANDOM))
	map_type_saved_button.pressed.connect(_on_map_type_pressed.bind(MAP_TYPE_SAVED))
	saved_map_delete_confirm_button.pressed.connect(_on_saved_map_delete_confirmed)
	saved_map_delete_cancel_button.pressed.connect(_on_saved_map_delete_cancelled)

	# Hover sounds removed - no sound on mouse enter

	_setup_custom_map_preview()
	_setup_size_filter_group()
	_setup_map_type_group()
	_setup_random_map_controls()
	edit_random_map_button.pressed.connect(_on_edit_random_map_pressed)
	_setup_player_buttons()
	_setup_difficulty_buttons()
	_setup_scenario_difficulty_buttons()
	_setup_victory_buttons()
	_setup_upgrade_cards()
	default_scenario_description_text = scenario_description_label.text
	default_scenario_objectives_text = scenario_objectives_label.text
	main_game_debug_mode = _resolve_main_game_debug_mode()
	options_container.configure(sound_manager, false, tr("Back to Menu"))
	_update_primary_main_menu_button()

	if _apply_user_map_editor_result():
		return
	if _apply_start_target_from_meta():
		return

	_show_main_menu()

func _process(_delta: float) -> void:
	if card_level_tooltip.visible:
		_update_card_level_tooltip_position(get_viewport().get_mouse_position())
	_update_generated_map_preview_cursor()

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

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE and _handle_back_input():
		get_viewport().set_input_as_handled()
		return
	if not _is_map_list_keyboard_active():
		return
	if key_event.keycode == KEY_UP:
		_move_map_list_selection(-1)
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_DOWN:
		_move_map_list_selection(1)
		get_viewport().set_input_as_handled()

func _handle_back_input() -> bool:
	if save_game_modal.visible:
		_on_save_game_modal_back_requested()
		return true
	if options_container.visible:
		options_container.request_back()
		return true
	if cards_container.visible and not cards_selection_mode:
		_on_cards_back_pressed()
		return true
	if custom_map_container.visible:
		_on_custom_map_back_pressed()
		return true
	if new_game_container.visible:
		_on_new_game_back_pressed()
		return true
	return false

func _is_map_list_keyboard_active() -> bool:
	return custom_map_container.visible and (custom_map_panel3.visible or campaign_panel.visible)

func _resolve_main_game_debug_mode() -> bool:
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	var scene_state: SceneState = scene.get_state()
	for node_index in range(scene_state.get_node_count()):
		if String(scene_state.get_node_name(node_index)) == "GameManager":
			for property_index in range(scene_state.get_node_property_count(node_index)):
				if String(scene_state.get_node_property_name(node_index, property_index)) == "debug_mode":
					return bool(scene_state.get_node_property_value(node_index, property_index))
			break
	var default_game_manager: GameManager = GameManager.new()
	var debug_enabled: bool = default_game_manager.debug_mode
	default_game_manager.free()
	return debug_enabled

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
		_refresh_upgrade_cards()
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

func _on_upgrades_pressed() -> void:
	DebugLogger.log("UISystem", "Upgrades button pressed")
	_show_cards_menu()

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
		_begin_upgrade_selection_or_start({
			"type": "scenario",
			"scenario_path": scen_path,
			"difficulty": _get_selected_scenario_difficulty()
		})

func _on_options_back_pressed():
	DebugLogger.log("UISystem", "Options Back button pressed")
	_show_main_menu()

func _on_cards_back_pressed() -> void:
	DebugLogger.log("UISystem", "Cards Back button pressed")
	if cards_selection_mode:
		_start_game_from_payload(_build_payload_with_selected_upgrades())
	else:
		_show_main_menu()

func _on_scenario_back_pressed():
	DebugLogger.log("UISystem", "Scenario Back button pressed")  
	_show_new_game_menu()

func _on_scenario_play_pressed():
	DebugLogger.log("UISystem", "Scenario Play button pressed with scenario: " + selected_scenario)
	if selected_scenario != "":
		var scen_path := "res://scenarios/" + selected_scenario + ".json"
		_begin_upgrade_selection_or_start({
			"type": "scenario",
			"scenario_path": scen_path,
			"difficulty": _get_selected_scenario_difficulty()
		})

func _on_custom_map_back_pressed():
	DebugLogger.log("UISystem", "Custom Map Back button pressed")  
	_restore_expanded_map_preview()
	_show_new_game_menu()

func _on_custom_map_select_pressed() -> void:
	if current_map_type == MAP_TYPE_RANDOM:
		_start_generated_random_map()
		return
	if selected_map_item.is_empty():
		return
	if current_map_type == MAP_TYPE_SAVED:
		_start_saved_map()
		return
	var map_file: String = selected_map_item.get("file", "")
	if map_file == "":
		return
	var size_code: String = selected_map_item.get("size", "S")
	var map_path := "res://mapdata/" + map_file + ".json"
	var fallback_size_str: String = _size_full_name(size_code).to_lower()
	var size_str: String = String(selected_map_item.get("map_size_exact", fallback_size_str))
	var selected_victory: String = _get_selected_custom_map_victory()
	_begin_upgrade_selection_or_start({
		"type": "map",
		"map_file": map_path,
		"map_size": size_str,
		"player_settings": player_settings,
		"victory_condition": selected_victory,
		"difficulty": _get_selected_custom_map_difficulty()
	})

func _start_saved_map() -> void:
	var saved_map_data: Dictionary = selected_map_item.get("map_data", {})
	var regions: Array = saved_map_data.get("regions", [])
	var edges: Array = saved_map_data.get("edges", [])
	if not RegionGraph.is_passable_map_connected(regions, edges):
		_show_custom_tooltip(INVALID_MAP_MESSAGE)
		_set_custom_map_select_enabled(false)
		return
	var size_code: String = String(selected_map_item.get("size", "S"))
	var fallback_size: String = _size_full_name(size_code).to_lower()
	var map_size: String = String(selected_map_item.get("map_size_exact", fallback_size))
	_begin_upgrade_selection_or_start({
		"type": "map",
		"map_data": saved_map_data,
		"map_size": map_size,
		"player_settings": player_settings,
		"victory_condition": _get_selected_custom_map_victory(),
		"difficulty": _get_selected_custom_map_difficulty()
	})

func _start_generated_random_map() -> void:
	if generated_random_map_data.is_empty():
		return
	var regions: Array = generated_random_map_data.get("regions", [])
	var edges: Array = generated_random_map_data.get("edges", [])
	if not RegionGraph.is_passable_map_connected(regions, edges):
		_show_custom_tooltip(INVALID_MAP_MESSAGE)
		_set_custom_map_select_enabled(false)
		return
	var size_profile: Dictionary = MapgenConfig.get_size_profile(random_map_size)
	var selected_victory: String = _get_selected_custom_map_victory()
	_begin_upgrade_selection_or_start({
		"type": "map",
		"map_data": generated_random_map_data,
		"map_size": String(size_profile["ui_size"]),
		"player_settings": player_settings,
		"victory_condition": selected_victory,
		"difficulty": _get_selected_custom_map_difficulty()
	})

func _on_edit_random_map_pressed() -> void:
	if generated_random_map_data.is_empty():
		return
	get_tree().set_meta(USER_MAP_EDITOR_PAYLOAD_META_KEY, {
		"map_data": generated_random_map_data.duplicate(true),
		"random_state": _get_random_map_editor_state(),
		"player_settings": player_settings.duplicate(true),
		"difficulty": _get_selected_custom_map_difficulty(),
		"victory_condition": _get_selected_custom_map_victory()
	})
	sound_manager.stop_main_menu_music()
	get_tree().change_scene_to_file("res://scenes/user_map_editor.tscn")

func _get_random_map_editor_state() -> Dictionary:
	return {
		"map_size": random_map_size,
		"map_seed": random_map_seed,
		"biome_seed": random_biome_seed,
		"forests": random_forests_slider.value,
		"hills": random_hills_slider.value,
		"mountains": random_mountains_slider.value,
		"sea_level": random_sea_level_slider.value
	}

func _apply_user_map_editor_result() -> bool:
	if not get_tree().has_meta(USER_MAP_EDITOR_RESULT_META_KEY):
		return false
	var result: Dictionary = get_tree().get_meta(USER_MAP_EDITOR_RESULT_META_KEY) as Dictionary
	get_tree().set_meta(USER_MAP_EDITOR_RESULT_META_KEY, null)
	var edited_map_data: Dictionary = result.get("map_data", {}).duplicate(true)
	var random_state: Dictionary = result.get("random_state", {})
	_show_custom_map_menu()
	_restore_random_map_editor_state(random_state)
	random_map_initialized = true
	_set_map_type(MAP_TYPE_RANDOM)
	generated_random_map_data = edited_map_data
	generated_map_renderer.render_map_data(generated_random_map_data)
	_restore_custom_map_settings(result)
	return true

func _restore_random_map_editor_state(state: Dictionary) -> void:
	random_map_size = String(state.get("map_size", "S"))
	random_map_seed = int(state.get("map_seed", 187))
	random_biome_seed = int(state.get("biome_seed", MapgenConfig.NOISE_SEED))
	random_map_seed_input.text = str(random_map_seed)
	random_biome_seed_input.text = str(random_biome_seed)
	random_forests_slider.value = float(state.get("forests", 0.33))
	random_hills_slider.value = float(state.get("hills", 0.33))
	random_mountains_slider.value = float(state.get("mountains", 0.5))
	random_sea_level_slider.value = float(state.get("sea_level", 0.5))

func _restore_custom_map_settings(result: Dictionary) -> void:
	var restored_player_settings: Array = result.get("player_settings", [])
	if not restored_player_settings.is_empty():
		player_settings = restored_player_settings.duplicate(true)
		for setting_variant: Variant in player_settings:
			var setting: Dictionary = setting_variant as Dictionary
			var player_id: int = int(setting.get("player_id", 0))
			var control_type: String = String(setting.get("control_type", "Off"))
			var button_name: String = "Human" if control_type == "Player" else control_type
			var control_button: Button = get_node("CustomMap/Panel/VBoxContainer/Player%d/%s" % [player_id, button_name]) as Button
			control_button.button_pressed = true
	var difficulty: String = String(result.get("difficulty", "normal"))
	for difficulty_button: Button in custom_map_difficulty_buttons:
		var selected_difficulty: bool = difficulty_button.name.to_lower() == difficulty
		difficulty_button.button_pressed = selected_difficulty
		_update_button_gold_state(difficulty_button, selected_difficulty)
	var victory_condition: String = String(result.get("victory_condition", "conquer"))
	var victory_buttons: Array[Button] = [
		get_node("CustomMap/Panel/VBoxContainer/VictoryConditions/Conquer") as Button,
		get_node("CustomMap/Panel/VBoxContainer/VictoryConditions/Dominate") as Button
	]
	for victory_button: Button in victory_buttons:
		var selected_victory: bool = victory_button.name.to_lower() == victory_condition
		victory_button.button_pressed = selected_victory
		_update_button_gold_state(victory_button, selected_victory)

func _on_scenario_select_pressed():
	if selected_scenario_item.is_empty():
		return
	var scenario_name: String = selected_scenario_item.get("name", "")
	var scen_path := "res://scenarios/" + scenario_name + ".json"
	_begin_upgrade_selection_or_start({
		"type": "scenario",
		"scenario_path": scen_path,
		"difficulty": _get_selected_scenario_difficulty()
	})
	
func _begin_upgrade_selection_or_start(payload: Dictionary) -> void:
	if _is_tutorial_payload(payload):
		_start_game_from_payload(payload)
		return
	if _is_non_single_human_custom_map_payload(payload):
		_start_game_from_payload(payload)
		return
	if not UpgradesManager.has_unlocked_cards(main_game_debug_mode):
		_start_game_from_payload(payload)
		return
	pending_start_payload = payload.duplicate(true)
	selected_upgrade_card_ids.clear()
	cards_selection_mode = true
	_show_cards_menu()

func _is_non_single_human_custom_map_payload(payload: Dictionary) -> bool:
	if String(payload.get("type", "")) != "map":
		return false
	var human_players: int = 0
	var raw_player_settings: Array = payload.get("player_settings", [])
	for raw_setting in raw_player_settings:
		var setting: Dictionary = raw_setting
		if String(setting.get("control_type", "")) == "Player":
			human_players += 1
	return human_players != 1

func _is_tutorial_payload(payload: Dictionary) -> bool:
	if String(payload.get("type", "")) != "scenario":
		return false
	return String(payload.get("scenario_path", "")).get_file() == TUTORIAL_SCENARIO_PATH.get_file()

func _build_payload_with_selected_upgrades() -> Dictionary:
	var payload: Dictionary = pending_start_payload.duplicate(true)
	var difficulty_name: String = String(payload.get("difficulty", "normal"))
	payload["selected_upgrade_cards"] = UpgradesManager.get_valid_selected_cards(selected_upgrade_card_ids, difficulty_name, main_game_debug_mode)
	return payload

func _start_game_from_payload(payload: Dictionary) -> void:
	get_tree().set_meta("start_payload", payload)
	if sound_manager:
		sound_manager.stop_main_menu_music()
	get_tree().change_scene_to_file("res://main.tscn")

func _show_main_menu():
	"""Show the main menu and hide other menus"""
	card_level_tooltip.hide_tooltip()
	cards_selection_mode = false
	pending_start_payload.clear()
	selected_upgrade_card_ids.clear()
	_update_primary_main_menu_button()
	button_bg1.visible = true
	button_bg2.visible = true
	button_bg3.visible = true
	button_bg4.visible = true
	button_bg5.visible = true
	button_bg6.visible = true
	menu_container.visible = true
	new_game_container.visible = false
	options_container.visible = false
	campaign_container.visible = false
	scenario_container.visible = false
	custom_map_container.visible = false
	demo_container.visible = false
	map_preview.visible = false
	feedback_container.visible = false
	cards_container.visible = false

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
	button_bg6.visible = false
	menu_container.visible = false
	new_game_container.visible = true
	options_container.visible = false
	campaign_container.visible = false
	scenario_container.visible = false
	custom_map_container.visible = false
	demo_container.visible = false
	map_preview.visible = false
	feedback_container.visible = false
	cards_container.visible = false

func _show_options_menu():
	"""Show the options menu"""
	options_container.configure(sound_manager, false, tr("Back to Menu"))
	button_bg4.visible = false
	button_bg5.visible = false
	button_bg6.visible = false
	menu_container.visible = false
	new_game_container.visible = false
	options_container.visible = true
	campaign_container.visible = false
	scenario_container.visible = false
	custom_map_container.visible = false
	demo_container.visible = false
	map_preview.visible = false
	feedback_container.visible = false
	cards_container.visible = false

func _show_cards_menu() -> void:
	card_level_tooltip.hide_tooltip()
	_refresh_upgrade_cards()
	button_bg1.visible = false
	button_bg2.visible = false
	button_bg3.visible = false
	button_bg4.visible = false
	button_bg5.visible = false
	button_bg6.visible = false
	menu_container.visible = false
	new_game_container.visible = false
	options_container.visible = false
	campaign_container.visible = false
	scenario_container.visible = false
	custom_map_container.visible = false
	demo_container.visible = false
	map_preview.visible = false
	feedback_container.visible = false
	cards_container.visible = true

func _setup_upgrade_cards() -> void:
	for card: Dictionary in UpgradesManager.get_all_cards():
		var card_id: String = String(card.get("id", ""))
		var card_node: Control = cards_rows.get_node(card_id) as Control
		card_node.mouse_filter = Control.MOUSE_FILTER_STOP
		_set_upgrade_card_child_mouse_filters(card_node)
		_connect_upgrade_level_tooltips(card_node, card_id)
		var card_text: RichTextLabel = card_node.get_node("CardText") as RichTextLabel
		card_node.set_meta("upgrade_card_desc_key", card_text.text)
		card_node.gui_input.connect(_on_upgrade_card_gui_input.bind(card_id))
	_refresh_upgrade_cards()

func _set_upgrade_card_child_mouse_filters(card_node: Control) -> void:
	for child: Node in card_node.get_children():
		if child is Control:
			var child_control: Control = child as Control
			child_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _connect_upgrade_level_tooltips(card_node: Control, card_id: String) -> void:
	for level: int in range(1, 4):
		var level_node: TextureRect = card_node.get_node("Level" + str(level)) as TextureRect
		level_node.mouse_filter = Control.MOUSE_FILTER_PASS
		level_node.mouse_entered.connect(_on_upgrade_level_mouse_entered.bind(card_id, level))
		level_node.mouse_exited.connect(_on_upgrade_level_mouse_exited)

func _refresh_upgrade_cards() -> void:
	cards_title_label.text = tr("Bonus Cards")
	cards_back_button.text = tr("Continue") if cards_selection_mode else tr("Back")
	var difficulty_name: String = String(pending_start_payload.get("difficulty", "normal"))
	var selection_limit: int = UpgradesManager.get_selection_limit_for_difficulty(difficulty_name)
	cards_limit_label.visible = cards_selection_mode
	cards_spacer_label.visible = not cards_selection_mode
	cards_limit_label.text = tr("You can select up to %d cards") % selection_limit
	for card: Dictionary in UpgradesManager.get_all_cards():
		var card_id: String = String(card.get("id", ""))
		var card_node: Control = cards_rows.get_node(card_id) as Control
		var level: int = UpgradesManager.get_card_level(card_id, main_game_debug_mode)
		var unlocked: bool = level > 0
		var selected: bool = selected_upgrade_card_ids.has(card_id)
		card_node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if cards_selection_mode and unlocked else Control.CURSOR_ARROW
		var card_texture: TextureRect = card_node.get_node("CardTexture") as TextureRect
		card_texture.texture = _get_upgrade_card_texture(String(card.get("color", "green")), unlocked, selected)
		var card_icon: TextureRect = card_node.get_node("CardIcon") as TextureRect
		card_icon.visible = unlocked
		var card_text: RichTextLabel = card_node.get_node("CardText") as RichTextLabel
		var description_key: String = String(card_node.get_meta("upgrade_card_desc_key"))
		var description_amount: int = UpgradesManager.get_card_bonus_amount(card_id, maxi(level, 1))
		card_text.text = tr(description_key).format({"amount": description_amount})
		card_text.visible = unlocked
		var lock_icon: TextureRect = card_node.get_node("Lock") as TextureRect
		lock_icon.visible = not unlocked
		_apply_upgrade_card_level_textures(card_node, level)

func _get_upgrade_card_texture(card_color: String, unlocked: bool, selected: bool) -> Texture2D:
	if card_color == "blue":
		if not unlocked:
			return CARD_BLUE_DISABLED_TEXTURE
		if selected:
			return CARD_BLUE_SELECTED_TEXTURE
		return CARD_BLUE_TEXTURE
	if not unlocked:
		return CARD_GREEN_DISABLED_TEXTURE
	if selected:
		return CARD_GREEN_SELECTED_TEXTURE
	return CARD_GREEN_TEXTURE

func _apply_upgrade_card_level_textures(card_node: Control, level: int) -> void:
	var level_textures: Array[Texture2D] = [LEVEL_1_TEXTURE, LEVEL_2_TEXTURE, LEVEL_3_TEXTURE]
	for i in range(3):
		var level_node: TextureRect = card_node.get_node("Level" + str(i + 1)) as TextureRect
		level_node.texture = level_textures[i] if level >= i + 1 else LEVEL_LOCKED_TEXTURE

func _on_upgrade_level_mouse_entered(card_id: String, level: int) -> void:
	var tooltip_text: String = _build_upgrade_level_tooltip(card_id, level)
	if tooltip_text == "":
		card_level_tooltip.hide_tooltip()
		return
	card_level_tooltip.show_text(tooltip_text)
	_update_card_level_tooltip_position(get_viewport().get_mouse_position())

func _on_upgrade_level_mouse_exited() -> void:
	card_level_tooltip.hide_tooltip()

func _build_upgrade_level_tooltip(card_id: String, level: int) -> String:
	var requirement: Dictionary = UpgradesManager.get_card_level_requirement(card_id, level)
	if requirement.is_empty():
		return ""
	var requirement_type: String = String(requirement.get("type", ""))
	if requirement_type == UpgradesManager.REQUIREMENT_TOTAL_GAMES:
		var count: int = int(requirement.get("count", 0))
		return tr("upgrade_level_requirement_games_tooltip").format({"count": count})
	if requirement_type != UpgradesManager.REQUIREMENT_SOURCE:
		return ""
	var source_type: String = String(requirement.get("source_type", UpgradesManager.SOURCE_NONE))
	var source_id: String = String(requirement.get("source_id", "")).strip_edges()
	var difficulty_key: String = String(requirement.get("difficulty", "")).strip_edges()
	if source_type == UpgradesManager.SOURCE_SCENARIO and source_id == "tutorial":
		return tr("upgrade_level_requirement_tutorial_tooltip")
	if source_type == UpgradesManager.SOURCE_SKIRMISH:
		var skirmish_difficulty_name: String = tr(_upgrade_difficulty_display_key(difficulty_key))
		return tr("upgrade_level_requirement_skirmish_tooltip").format({"difficulty": skirmish_difficulty_name})
	var mission_name: String = _resolve_upgrade_source_display_name(source_id)
	if difficulty_key == "":
		var any_tooltip_key: String = "upgrade_level_requirement_mission_any_tooltip" if _is_upgrade_mission_source(source_id) else "upgrade_level_requirement_scenario_any_tooltip"
		return tr(any_tooltip_key).format({"mission": mission_name})
	var difficulty_name: String = tr(_upgrade_difficulty_display_key(difficulty_key))
	var tooltip_key: String = "upgrade_level_requirement_mission_tooltip" if _is_upgrade_mission_source(source_id) else "upgrade_level_requirement_scenario_tooltip"
	return tr(tooltip_key).format({"mission": mission_name, "difficulty": difficulty_name})

func _resolve_upgrade_source_display_name(source_id: String) -> String:
	var translation_key: String = source_id
	if source_id == "mission7":
		translation_key = "mission-7"
	var translated_name: String = tr(translation_key)
	if translated_name != translation_key:
		return translated_name
	return source_id.replace("-", " ").capitalize()

func _is_upgrade_mission_source(source_id: String) -> bool:
	return source_id.begins_with("mission-") or source_id == "mission7"

func _upgrade_difficulty_display_key(difficulty_key: String) -> String:
	match difficulty_key.to_lower():
		"easy":
			return "Easy"
		"normal":
			return "Normal"
		_:
			return "Hard"

func _update_card_level_tooltip_position(mouse_pos: Vector2) -> void:
	var pos: Vector2 = mouse_pos + CARD_LEVEL_TOOLTIP_OFFSET
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	if pos.x + card_level_tooltip.size.x > screen_size.x:
		pos.x = screen_size.x - card_level_tooltip.size.x - 10.0
	if pos.y + card_level_tooltip.size.y > screen_size.y:
		pos.y = screen_size.y - card_level_tooltip.size.y - 10.0
	pos.x = max(10.0, pos.x)
	pos.y = max(10.0, pos.y)
	card_level_tooltip.global_position = pos

func _on_upgrade_card_gui_input(event: InputEvent, card_id: String) -> void:
	if not cards_selection_mode:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_toggle_upgrade_card_selection(card_id)

func _toggle_upgrade_card_selection(card_id: String) -> void:
	if not UpgradesManager.is_card_unlocked(card_id, main_game_debug_mode):
		return
	if selected_upgrade_card_ids.has(card_id):
		selected_upgrade_card_ids.erase(card_id)
	else:
		var difficulty_name: String = String(pending_start_payload.get("difficulty", "normal"))
		var selection_limit: int = UpgradesManager.get_selection_limit_for_difficulty(difficulty_name)
		if selected_upgrade_card_ids.size() >= selection_limit:
			return
		selected_upgrade_card_ids.append(card_id)
	_refresh_upgrade_cards()

func _show_campaign_menu():
	"""Show campaign using the Scenario node layout"""
	button_bg1.visible = true
	button_bg2.visible = false
	button_bg3.visible = false
	button_bg4.visible = false
	button_bg5.visible = false
	button_bg6.visible = false
	menu_container.visible = false
	new_game_container.visible = false
	options_container.visible = false
	campaign_container.visible = false
	scenario_container.visible = false
	custom_map_container.visible = true
	demo_container.visible = false
	map_preview.visible = false
	feedback_container.visible = false
	cards_container.visible = false
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
	button_bg6.visible = false
	menu_container.visible = false
	new_game_container.visible = false
	options_container.visible = false
	campaign_container.visible = false
	scenario_container.visible = false
	custom_map_container.visible = true
	demo_container.visible = false
	map_preview.visible = false
	feedback_container.visible = false
	cards_container.visible = false
	is_scenario_mode = true
	is_campaign_mode = false
	custom_map_panel.visible = false
	scenario_panel.visible = true
	custom_map_panel2.visible = true
	custom_map_panel3.visible = true
	campaign_panel.visible = false
	scenario_list_background.visible = true
	skirmish_list_background.visible = false
	custom_map_panel3_label.text = tr("Scenario List")
	_set_campaign_ui(false)
	_set_map_type_controls_visible(false)
	_set_map_type(MAP_TYPE_ORIGINAL)
	_clear_map_selection()
	_load_scenario_items()

func _show_custom_map_menu():
	"""Show the custom map menu and load map list"""
	button_bg1.visible = true
	button_bg2.visible = false
	button_bg3.visible = false
	button_bg4.visible = false
	button_bg5.visible = false
	button_bg6.visible = false
	menu_container.visible = false
	new_game_container.visible = false
	options_container.visible = false
	campaign_container.visible = false
	scenario_container.visible = false
	custom_map_container.visible = true
	demo_container.visible = false
	map_preview.visible = false
	feedback_container.visible = false
	cards_container.visible = false
	is_scenario_mode = false
	custom_map_panel.visible = true
	scenario_panel.visible = false
	custom_map_panel2.visible = true
	custom_map_panel3.visible = true
	campaign_panel.visible = false
	scenario_list_background.visible = false
	skirmish_list_background.visible = true
	custom_map_panel3_label.text = tr("Select Map")
	_set_campaign_ui(false)
	_set_map_type_controls_visible(true)
	_set_map_type(MAP_TYPE_ORIGINAL)
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
	generated_map_preview.visible = false
	custom_map_preview_index = custom_map_preview.get_index()
	generated_map_preview_index = generated_map_preview.get_index()
	custom_map_preview.gui_input.connect(_on_map_preview_gui_input.bind(custom_map_preview))
	generated_map_preview.gui_input.connect(_on_map_preview_gui_input.bind(generated_map_preview))
	if custom_map_template_row:
		custom_map_template_row.visible = false

func _update_generated_map_preview_cursor() -> void:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var hovered: bool = generated_map_preview.visible and not is_scenario_mode and generated_map_preview.get_global_rect().has_point(mouse_position)
	if hovered == generated_map_preview_cursor_active:
		return
	generated_map_preview_cursor_active = hovered
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered else Input.CURSOR_ARROW)

func _on_map_preview_gui_input(event: InputEvent, preview: Control) -> void:
	if is_scenario_mode:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if map_preview_expanded:
		_restore_expanded_map_preview()
	else:
		_expand_map_preview(preview)
	preview.accept_event()

func _expand_map_preview(preview: Control) -> void:
	expanded_map_preview = preview
	map_preview_expanded = true
	preview.reparent(custom_map_container, false)
	preview.position = MAP_PREVIEW_EXPANDED_POSITION
	preview.size = MAP_PREVIEW_EXPANDED_SIZE
	preview.custom_minimum_size = MAP_PREVIEW_EXPANDED_SIZE
	preview.z_index = 100
	if preview == generated_map_preview:
		_fit_generated_map_preview(MAP_PREVIEW_EXPANDED_SIZE)

func _restore_expanded_map_preview() -> void:
	if not map_preview_expanded:
		return
	var preview_index: int = custom_map_preview_index if expanded_map_preview == custom_map_preview else generated_map_preview_index
	expanded_map_preview.reparent(custom_map_preview_parent, false)
	expanded_map_preview.custom_minimum_size = MAP_PREVIEW_NORMAL_SIZE
	expanded_map_preview.size = MAP_PREVIEW_NORMAL_SIZE
	expanded_map_preview.z_index = 0
	custom_map_preview_parent.move_child(expanded_map_preview, preview_index)
	if expanded_map_preview == generated_map_preview:
		_fit_generated_map_preview(MAP_PREVIEW_NORMAL_SIZE)
	map_preview_expanded = false

func _fit_generated_map_preview(preview_size: Vector2) -> void:
	var scale_multiplier: float = minf(preview_size.x / MAP_PREVIEW_NORMAL_SIZE.x, preview_size.y / MAP_PREVIEW_NORMAL_SIZE.y)
	generated_map_renderer.position = GENERATED_PREVIEW_NORMAL_POSITION * scale_multiplier
	generated_map_renderer.scale = GENERATED_PREVIEW_NORMAL_SCALE * scale_multiplier

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

func _setup_map_type_group() -> void:
	map_type_button_group = ButtonGroup.new()
	var buttons: Array[Button] = [map_type_original_button, map_type_random_button, map_type_saved_button]
	for button: Button in buttons:
		button.toggle_mode = true
		button.button_group = map_type_button_group
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	map_type_original_button.button_pressed = true
	map_type_random_button.disabled = demo_mode_enabled
	map_type_saved_button.disabled = demo_mode_enabled
	_update_button_gold_state(map_type_original_button, true)
	_update_button_gold_state(map_type_random_button, false)
	_update_button_gold_state(map_type_saved_button, false)

func _setup_random_map_controls() -> void:
	random_map_seed_button.pressed.connect(_on_random_map_seed_pressed)
	random_map_seed_input.text_submitted.connect(_on_random_map_seed_submitted)
	random_map_seed_input.focus_exited.connect(_on_random_map_seed_focus_exited)
	random_biome_seed_button.pressed.connect(_on_random_biome_seed_pressed)
	random_biome_seed_input.text_submitted.connect(_on_random_biome_seed_submitted)
	random_biome_seed_input.focus_exited.connect(_on_random_biome_seed_focus_exited)
	_connect_random_map_slider(random_forests_slider, random_forests_value)
	_connect_random_map_slider(random_hills_slider, random_hills_value)
	_connect_random_map_slider(random_mountains_slider, random_mountains_value)
	_connect_random_map_slider(random_sea_level_slider, random_sea_level_value)

func _connect_random_map_slider(slider: HSlider, value_label: Label) -> void:
	slider.value_changed.connect(_on_random_map_slider_value_changed.bind(value_label))
	slider.drag_ended.connect(_on_random_map_slider_drag_ended)

func _on_size_filter_pressed(filter_code: String, button: Button):
	if current_map_type == MAP_TYPE_RANDOM and not is_scenario_mode:
		if filter_code == "All":
			return
		random_map_size = filter_code
		_select_map_size_button(button)
		_generate_random_map_preview()
		return
	current_map_filter = filter_code
	_select_map_size_button(button)
	_apply_map_filter()

func _select_map_size_button(selected_button: Button) -> void:
	for base_button: BaseButton in size_filter_button_group.get_buttons():
		var button: Button = base_button as Button
		_update_button_gold_state(button, button == selected_button)

func _on_map_type_pressed(map_type: String) -> void:
	_set_map_type(map_type)
	if map_type == MAP_TYPE_ORIGINAL:
		_load_custom_map_items()
	elif map_type == MAP_TYPE_SAVED:
		_load_saved_map_items()

func _set_map_type(map_type: String) -> void:
	_restore_expanded_map_preview()
	current_map_type = map_type
	_update_button_gold_state(map_type_original_button, map_type == MAP_TYPE_ORIGINAL)
	_update_button_gold_state(map_type_random_button, map_type == MAP_TYPE_RANDOM)
	_update_button_gold_state(map_type_saved_button, map_type == MAP_TYPE_SAVED)
	if map_type == MAP_TYPE_RANDOM:
		_show_random_map_content()
	else:
		_show_original_map_content()

func _show_random_map_content() -> void:
	if not random_map_initialized:
		random_map_size = "S" if current_map_filter == "All" else current_map_filter
		random_map_seed = _create_random_map_seed()
		random_biome_seed = _create_random_map_seed()
		random_map_seed_input.text = str(random_map_seed)
		random_biome_seed_input.text = str(random_biome_seed)
		random_map_initialized = true
	random_parameters.visible = true
	custom_map_list_headers.visible = false
	custom_map_list_header_margin.visible = false
	custom_map_scroll_container.visible = false
	map_size_button_all.disabled = true
	_select_map_size_button(_map_size_button_for_code(random_map_size))
	custom_map_preview.visible = false
	custom_map_map_name_label.text = tr("Random Map")
	custom_map_map_size_label.text = _size_full_name(random_map_size)
	_set_custom_map_select_enabled(false)
	_generate_random_map_preview()

func _show_original_map_content() -> void:
	random_parameters.visible = false
	custom_map_list_headers.visible = true
	custom_map_list_header_margin.visible = true
	custom_map_scroll_container.visible = true
	map_size_button_all.disabled = false
	_select_map_size_button(_map_size_button_for_code(current_map_filter))
	generated_map_preview.visible = false
	if selected_map_item.is_empty():
		custom_map_preview.texture = null
		custom_map_preview.visible = false
		_set_custom_map_select_enabled(false)
		return
	_update_info_labels(selected_map_item)
	_update_preview_with_item(selected_map_item, false)
	_set_custom_map_select_enabled(true)

func _set_map_type_controls_visible(visible: bool) -> void:
	map_type_label.visible = visible
	map_type_margin.visible = visible
	map_type_buttons_container.visible = visible

func _map_size_button_for_code(size_code: String) -> Button:
	match size_code:
		"XS":
			return map_size_button_xs
		"S":
			return map_size_button_small
		"M":
			return map_size_button_medium
		"L":
			return map_size_button_large
		_:
			return map_size_button_all

func _on_random_map_seed_pressed() -> void:
	random_map_seed = _create_random_map_seed()
	random_map_seed_input.text = str(random_map_seed)
	_generate_random_map_preview()

func _on_random_biome_seed_pressed() -> void:
	random_biome_seed = _create_random_map_seed()
	random_biome_seed_input.text = str(random_biome_seed)
	_generate_random_map_preview()

func _create_random_map_seed() -> int:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.randomize()
	return random.randi_range(RANDOM_SEED_MIN, RANDOM_SEED_MAX)

func _on_random_map_seed_submitted(text: String) -> void:
	_apply_random_map_seed_text(text)

func _on_random_map_seed_focus_exited() -> void:
	_apply_random_map_seed_text(random_map_seed_input.text)

func _apply_random_map_seed_text(text: String) -> void:
	var entered_seed: int = _validated_random_map_seed(text, random_map_seed)
	random_map_seed_input.text = str(entered_seed)
	if entered_seed == random_map_seed:
		return
	random_map_seed = entered_seed
	_generate_random_map_preview()

func _on_random_biome_seed_submitted(text: String) -> void:
	_apply_random_biome_seed_text(text)

func _on_random_biome_seed_focus_exited() -> void:
	_apply_random_biome_seed_text(random_biome_seed_input.text)

func _apply_random_biome_seed_text(text: String) -> void:
	var entered_seed: int = _validated_random_map_seed(text, random_biome_seed)
	random_biome_seed_input.text = str(entered_seed)
	if entered_seed == random_biome_seed:
		return
	random_biome_seed = entered_seed
	_generate_random_map_preview()

func _validated_random_map_seed(text: String, current_seed: int) -> int:
	if not text.is_valid_int():
		return current_seed
	return clampi(int(text), RANDOM_SEED_MIN, RANDOM_SEED_MAX)

func _on_random_map_slider_value_changed(value: float, value_label: Label) -> void:
	value_label.text = "%.2f" % value

func _on_random_map_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		_generate_random_map_preview()

func _generate_random_map_preview() -> void:
	if current_map_type != MAP_TYPE_RANDOM or is_scenario_mode:
		return
	var parameters: Dictionary = {
		"size": random_map_size,
		"noise_seed": random_biome_seed,
		"forests": lerpf(RANDOM_FORESTS_GENERATION_MIN, 1.0, random_forests_slider.value),
		"hills": random_hills_slider.value,
		"mountains": random_mountains_slider.value,
		"sea_level": random_sea_level_slider.value
	}
	var generated: Dictionary = MAPGEN_GENERATOR.generate(random_map_seed, parameters)
	generated_random_map_data = MAPGEN_GENERATOR.build_export(generated)
	generated_map_renderer.render_map_data(generated_random_map_data)
	generated_map_preview.visible = true
	custom_tooltip.visible = false
	_set_custom_map_select_enabled(true)

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
		if demo_mode_enabled and player_num >= 5:
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

func _load_saved_map_items() -> void:
	map_items = _gather_saved_map_items()
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
		if not for_scenario:
			var delete_button: Button = row.get_node("Delete") as Button
			var show_delete_button: bool = current_map_type == MAP_TYPE_SAVED
			delete_button.visible = show_delete_button
			name_label.custom_minimum_size.x = SAVED_MAP_NAME_WIDTH if show_delete_button else DEFAULT_MAP_NAME_WIDTH
			if show_delete_button:
				delete_button.pressed.connect(_on_saved_map_delete_pressed.bind(item))
		if for_scenario and is_campaign_mode:
			size_label.text = str(int(item.get("mission_number", 0)))
		else:
			size_label.text = item.get("size", "S")
		name_label.text = _resolve_item_display_name(item)
		var item_enabled: bool = _is_map_list_item_enabled(item, for_scenario)
		var cursor_shape: Control.CursorShape = Control.CURSOR_POINTING_HAND if item_enabled else Control.CURSOR_ARROW
		row.mouse_default_cursor_shape = cursor_shape
		size_label.mouse_default_cursor_shape = cursor_shape
		name_label.mouse_default_cursor_shape = cursor_shape
		_set_row_highlight_color(row, ROW_HIGHLIGHT_NONE_COLOR)
		_apply_map_row_enabled_style(row, item_enabled)
		row.set_meta("map_list_item", item)
		row.gui_input.connect(_on_map_row_gui_input.bind(row, item, for_scenario))
		row.mouse_entered.connect(_on_map_row_hovered.bind(row, item, for_scenario))
		row.mouse_exited.connect(_on_map_row_unhovered.bind(row, item, for_scenario))
		container.add_child(row)
		if first_created_row == null and item_enabled:
			first_created_row = row
			first_created_item = item
	if first_created_row:
		_on_map_row_pressed(first_created_row, first_created_item, for_scenario)

func _move_map_list_selection(step: int) -> void:
	var for_scenario: bool = is_scenario_mode
	var container: VBoxContainer = _get_list_container(for_scenario)
	var rows: Array[Control] = _get_selectable_map_rows(container)
	if rows.is_empty():
		return
	var current_selected: Control = selected_scenario_button_custom if for_scenario else selected_map_button
	var selected_index: int = rows.find(current_selected)
	var next_index: int = 0
	if selected_index >= 0:
		next_index = clampi(selected_index + step, 0, rows.size() - 1)
	var next_row: Control = rows[next_index]
	var next_item: Dictionary = next_row.get_meta("map_list_item")
	_on_map_row_pressed(next_row, next_item, for_scenario)
	var scroll_container: ScrollContainer = container.get_parent() as ScrollContainer
	scroll_container.ensure_control_visible(next_row)

func _get_selectable_map_rows(container: VBoxContainer) -> Array[Control]:
	var rows: Array[Control] = []
	for child: Node in container.get_children():
		if child is Control:
			var row: Control = child as Control
			if row.visible and row.has_meta("map_list_item") and _is_map_list_item_enabled(row.get_meta("map_list_item"), is_scenario_mode):
				rows.append(row)
	return rows

func _on_map_row_gui_input(event: InputEvent, row: Control, item: Dictionary, for_scenario: bool):
	if not _is_map_list_item_enabled(item, for_scenario):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_map_row_pressed(row, item, for_scenario)

func _on_map_row_pressed(row: Control, item: Dictionary, for_scenario: bool):
	if not _is_map_list_item_enabled(item, for_scenario):
		return
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
		custom_tooltip.visible = false
		_set_custom_map_select_enabled(true)

func _on_map_row_hovered(row: Control, item: Dictionary, for_scenario: bool):
	if not _is_map_list_item_enabled(item, for_scenario):
		return
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
	var item_enabled: bool = true
	if row.has_meta("map_list_item"):
		item_enabled = _is_map_list_item_enabled(row.get_meta("map_list_item"), is_scenario_mode)
	var text_color: Color = ROW_TEXT_COLOR if item_enabled else ROW_DISABLED_TEXT_COLOR
	size_label.add_theme_color_override("font_color", text_color)
	name_label.add_theme_color_override("font_color", text_color)
	if row.has_method("set_highlight_color"):
		row.call("set_highlight_color", color)

func _apply_map_row_enabled_style(row: Control, enabled: bool) -> void:
	var size_label: Label = row.get_node("Size")
	var name_label: Label = row.get_node("Name")
	var text_color: Color = ROW_TEXT_COLOR if enabled else ROW_DISABLED_TEXT_COLOR
	size_label.add_theme_color_override("font_color", text_color)
	name_label.add_theme_color_override("font_color", text_color)

func _is_map_list_item_enabled(item: Dictionary, for_scenario: bool) -> bool:
	if not for_scenario or not is_campaign_mode:
		return true
	if main_game_debug_mode:
		return true
	return bool(item.get("campaign_unlocked", true))

func _update_button_gold_state(button: Button, selected: bool):
	button.button_pressed = selected

func _update_info_labels(item: Dictionary):
	var display_name: String = _resolve_item_display_name(item)
	if main_game_debug_mode and not is_scenario_mode:
		var map_file: String = String(item.get("file", "")).strip_edges()
		if map_file != "":
			display_name += " (" + map_file + ")"
	custom_map_map_name_label.text = display_name
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
	if not for_scenario and item.has("map_data"):
		var saved_map_data: Dictionary = item.get("map_data", {})
		custom_map_preview.texture = null
		custom_map_preview.visible = false
		generated_map_renderer.render_map_data(saved_map_data)
		generated_map_preview.visible = true
		return
	generated_map_preview.visible = false
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
	generated_map_preview.visible = false

func _on_saved_map_delete_pressed(item: Dictionary) -> void:
	pending_saved_map_delete_path = String(item.get("file_path", ""))
	var display_name: String = _resolve_item_display_name(item)
	saved_map_delete_message.text = tr('Delete saved map "%s"?') % display_name
	saved_map_delete_confirm.visible = true
	saved_map_delete_confirm.move_to_front()

func _on_saved_map_delete_cancelled() -> void:
	saved_map_delete_confirm.visible = false
	pending_saved_map_delete_path = ""

func _on_saved_map_delete_confirmed() -> void:
	var delete_path: String = pending_saved_map_delete_path
	_on_saved_map_delete_cancelled()
	if not delete_path.begins_with(USER_MAPS_DIRECTORY + "/"):
		return
	var delete_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(delete_path))
	if delete_error != OK:
		push_error("Unable to delete saved map: " + delete_path)
		return
	_load_saved_map_items()

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
				if demo_mode_enabled and not allowed_custom_maps.has(file_name):
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
				var display_name_key: String = String(map_profile.get("display_name_key", "")).strip_edges()
				if display_name_key == "":
					file_name = dir.get_next()
					continue
				items.append({
					"file": base,
					"display_name_key": display_name_key,
					"display_name": display_name_key,
					"size": size_code,
					"map_size_exact": exact_size,
					"region_count": region_count
				})
			file_name = dir.get_next()
		dir.list_dir_end()
	items.sort_custom(Callable(self, "_sort_items"))
	return items

func _gather_saved_map_items() -> Array:
	var items: Array = []
	var directory: DirAccess = DirAccess.open(USER_MAPS_DIRECTORY)
	if directory == null:
		return items
	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and file_name.to_lower().ends_with(".json"):
			var item: Dictionary = _load_saved_map_item(file_name)
			if not item.is_empty():
				items.append(item)
		file_name = directory.get_next()
	directory.list_dir_end()
	items.sort_custom(Callable(self, "_sort_items"))
	return items

func _load_saved_map_item(file_name: String) -> Dictionary:
	var file_path: String = USER_MAPS_DIRECTORY.path_join(file_name)
	var content: String = FileAccess.get_file_as_string(file_path)
	var json: JSON = JSON.new()
	if json.parse(content) != OK:
		return {}
	var parsed_data: Variant = json.get_data()
	if not (parsed_data is Dictionary):
		return {}
	var map_data: Dictionary = parsed_data as Dictionary
	var regions_value: Variant = map_data.get("regions", [])
	if not (regions_value is Array):
		return {}
	var regions: Array = regions_value as Array
	if regions.is_empty():
		return {}
	var region_count: int = regions.size()
	var passable_region_count: int = _resolve_non_ocean_region_count_for_map_profile(map_data, regions)
	var size_code: String = Utils.get_frontend_size_code_from_region_count(passable_region_count)
	var base_name: String = file_name.get_basename()
	return {
		"file": base_name,
		"file_path": file_path,
		"display_name": base_name.replace("_", " ").capitalize(),
		"size": size_code,
		"map_size_exact": Utils.get_nearest_anchor_label_from_region_count(region_count),
		"region_count": region_count,
		"map_data": map_data
	}

func _gather_scenario_items(requested_type: String) -> Array:
	var items: Array = []
	var allowed_scenarios: Array[String] = GameParameters.DEMO_ALLOWED_SCENARIO_FILES
	var dir = DirAccess.open("res://scenarios")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				if demo_mode_enabled and not allowed_scenarios.has(file_name):
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
		_apply_campaign_unlocks(items)
	else:
		items.sort_custom(Callable(self, "_sort_items"))
	return items

func _apply_campaign_unlocks(items: Array) -> void:
	if main_game_debug_mode:
		for item: Dictionary in items:
			item["campaign_unlocked"] = true
		return
	var mission_source_by_number: Dictionary = {}
	for item: Dictionary in items:
		var mission_number: int = int(item.get("mission_number", 0))
		if mission_number > 0:
			mission_source_by_number[mission_number] = String(item.get("scenario_file_base", item.get("name", "")))
	for item: Dictionary in items:
		var mission_number: int = int(item.get("mission_number", 0))
		var campaign_unlocked: bool = mission_number > 0 and mission_number <= CAMPAIGN_ALWAYS_UNLOCKED_MISSION_MAX
		if not campaign_unlocked and mission_number > CAMPAIGN_ALWAYS_UNLOCKED_MISSION_MAX:
			var previous_source_id: String = String(mission_source_by_number.get(mission_number - 1, ""))
			campaign_unlocked = previous_source_id != "" and UpgradesManager.has_completed_source(UpgradesManager.SOURCE_SCENARIO, previous_source_id)
		item["campaign_unlocked"] = campaign_unlocked

func _resolve_map_profile_for_file(map_file_name: String) -> Dictionary:
	var file_only: String = map_file_name.get_file()
	var file_name: String = file_only if file_only.ends_with(".json") else (file_only + ".json")
	var file_path: String = "res://mapdata/" + file_name
	var region_count: int = 0
	var frontend_region_count: int = 0
	var display_name_key: String = ""
	var content: String = FileAccess.get_file_as_string(file_path)
	if content != "":
		var json := JSON.new()
		if json.parse(content) == OK:
			var data: Variant = json.get_data()
			if typeof(data) == TYPE_DICTIONARY:
				var dict_data: Dictionary = data
				display_name_key = String(dict_data.get("display_name_key", "")).strip_edges()
				var regions_value: Variant = dict_data.get("regions", [])
				if typeof(regions_value) == TYPE_ARRAY:
					var regions_array: Array = regions_value as Array
					region_count = regions_array.size()
					frontend_region_count = _resolve_non_ocean_region_count_for_map_profile(dict_data, regions_array)
	if region_count > 0:
		var frontend_size_code: String = Utils.get_frontend_size_code_from_region_count(frontend_region_count)
		return {
			"token": Utils.extract_map_size_token(file_name),
			"region_count": region_count,
			"frontend_region_count": frontend_region_count,
			"canonical_size_token": Utils.get_nearest_anchor_label_from_region_count(region_count),
			"visual_scale": Utils.get_map_visual_scale_from_region_count(region_count),
			"initial_zoom": Utils.get_initial_zoom_from_region_count(region_count),
			"frontend_size_code": frontend_size_code,
			"frontend_size_label": Utils.get_frontend_size_label_from_code(frontend_size_code),
			"display_name_key": display_name_key,
			"source": "json_regions"
		}
	return Utils.resolve_map_profile(file_name, region_count, frontend_region_count)

func _resolve_non_ocean_region_count_for_map_profile(map_data: Dictionary, regions_array: Array) -> int:
	var stored_count: int = int(map_data.get("non_ocean_region_count", 0))
	if stored_count > 0:
		return stored_count
	var count: int = 0
	for raw_region in regions_array:
		if not (raw_region is Dictionary):
			continue
		var region_data: Dictionary = raw_region as Dictionary
		var biome_name: String = String(region_data.get("biome", "")).to_lower()
		if bool(region_data.get("ocean", false)) or biome_name == "ocean":
			continue
		count += 1
	return count

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
