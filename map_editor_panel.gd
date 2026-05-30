extends Control
class_name MapEditorPanel

# ============================================================================
# MAP EDITOR PANEL
# ============================================================================
# 
# Purpose: UI panel for map editor mode (25% left side)
# 
# Core Responsibilities:
# - Display empty panel when in editor mode
# - Maintain 25% width, full height layout
# 
# Integration Points:
# - MapEditor: Shows/hides panel
# ============================================================================

signal region_type_changed(region_id: int, selection: String)
signal region_data_changed(region_id: int, selection: String)
signal army_edit_saved(region_id: int, data: Dictionary)

const SCENARIO_EDIT_DIFFICULTIES: Array[String] = ["all", "easy", "normal", "hard"]

var _option: OptionButton
var _current_region_id: int = -1
var _name_edit: LineEdit
var _level_option: OptionButton
var _castle_option: OptionButton
var _ore_check: CheckBox
var _ore_guarantee_attempt_edit: LineEdit
var _ore_guarantee_type_option: OptionButton
var _resource_edits: Dictionary = {}
var _id_value: Label
var _population_edit: LineEdit
var _ownership_option: OptionButton
var _army_toggle_button: Button
var _has_army_cached: bool = false
var _army_panel: Control
var _region_panel: Node
var _edit_army_button: Button
var _close_army_button: Button
var _unit_edits: Dictionary = {}
var _army_name_value: Label
var _region_id_value_army: Label
var _region_name_value_army: Label
var _current_region_node: Region
var _save_scenario_button: Button
var _save_map_button: Button
var _exit_button: Button
var _scenario_name_edit: LineEdit
var _scenario_type_option: OptionButton
var _edit_difficulty_option: OptionButton
var _mission_number_row: HBoxContainer
var _mission_number_option: OptionButton
var _tab_container: TabContainer
var _army_default_content: VBoxContainer
var _army_edit_panel: VBoxContainer
var _garrison_edit_panel: VBoxContainer
var _edit_garrison_button: Button
var _close_garrison_button: Button
var _garrison_unit_edits: Dictionary = {}
var _garrison_customized: Dictionary = {}
var _region_default_nodes: Array = []
var _player_settings_container: VBoxContainer
var player_settings: Array = []  # Array of dictionaries with player configuration
var _player_resource_selector: OptionButton
var _player_resource_fields: Dictionary = {}
var player_resources: Array = []  # Array of dictionaries storing starting resources per player
var _current_resource_player_index: int = 0
var _is_updating_player_resources_ui: bool = false
var _edit_difficulty_target: String = "all"
var _difficulty_player_resources_overrides: Dictionary = {}
var _difficulty_army_compositions_overrides: Dictionary = {}
var _difficulty_garrison_compositions_overrides: Dictionary = {}
var _difficulty_event_compositions_overrides: Dictionary = {}
var _victory_type_option: OptionButton
var _victory_target_player_row: HBoxContainer
var _victory_target_player_option: OptionButton
var _victory_region_row: HBoxContainer
var _victory_region_value: LineEdit
var _victory_turns_row: HBoxContainer
var _victory_turns_value: LineEdit
var _victory_region_level_row: HBoxContainer
var _victory_region_level_option: OptionButton
var _victory_castle_level_row: HBoxContainer
var _victory_castle_level_option: OptionButton
var _victory_unit_type_row: HBoxContainer
var _victory_unit_type_option: OptionButton
var _victory_units_hired_row: HBoxContainer
var _victory_units_hired_value: LineEdit
var _scenario_trade_disabled_check: CheckBox
var _scenario_difficulty_option: OptionButton
var _victory_type_keys: Array[String] = ["conquer", "conquer_after_events", "dominate", "own_region", "survive_turns", "economy"]
var _event_name_add_edit: LineEdit
var _event_add_button: Button
var _event_list_view: VBoxContainer
var _event_list_container: VBoxContainer
var _event_editor_view: VBoxContainer
var _event_back_button: Button
var _event_save_button: Button
var _event_edit_name: LineEdit
var _event_regions_edit: LineEdit
var _event_turn_start_edit: LineEdit
var _event_turn_end_edit: LineEdit
var _event_player_option: OptionButton
var _event_regions_select_button: Button
var _event_message_text: TextEdit
var _event_units_container: VBoxContainer
var _event_unit_edits: Dictionary = {}
var _events: Array[Dictionary] = []
var _editing_event_index: int = -1
var _event_region_select_mode: bool = false
var _event_highlight_region_ids: Array[int] = []

func _ready() -> void:
	"""Initialize map editor panel"""
	DebugLogger.log("MapEditorPanel", "Map editor panel ready")
	# Get references to static nodes
	_tab_container = get_node("Panel/TabContainer") as TabContainer
	_id_value = get_node("Panel/TabContainer/Region/IDRow/IDValue") as Label
	_name_edit = get_node("Panel/TabContainer/Region/NameRow/NameEdit") as LineEdit
	_option = get_node("Panel/TabContainer/Region/TypeRow/TypeOption") as OptionButton
	_level_option = get_node("Panel/TabContainer/Region/LevelRow/LevelOption") as OptionButton
	_population_edit = get_node("Panel/TabContainer/Region/PopulationRow/PopulationEdit") as LineEdit
	_castle_option = get_node("Panel/TabContainer/Region/CastleRow/CastleOption") as OptionButton
	_ore_check = get_node("Panel/TabContainer/Region/OreRow/OreCheck") as CheckBox
	_ore_guarantee_attempt_edit = get_node("Panel/TabContainer/Region/OreGuaranteeAttemptRow/OreGuaranteeAttemptEdit") as LineEdit
	_ore_guarantee_type_option = get_node("Panel/TabContainer/Region/OreGuaranteeTypeRow/OreGuaranteeTypeOption") as OptionButton
	_ownership_option = get_node("Panel/TabContainer/Region/OwnershipRow/OwnershipOption") as OptionButton
	_army_toggle_button = get_node("Panel/TabContainer/Army/ArmyDefaultContent/ArmyRow/ArmyToggleButton") as Button
	_region_panel = get_node("Panel")
	_army_panel = get_node("Panel/TabContainer/Army") as Control
	_army_default_content = get_node("Panel/TabContainer/Army/ArmyDefaultContent") as VBoxContainer
	_army_edit_panel = get_node("Panel/TabContainer/Army/ArmyEditPanel") as VBoxContainer
	_edit_army_button = get_node("Panel/TabContainer/Army/ArmyDefaultContent/ArmyEditRow/EditArmyButton") as Button
	_close_army_button = get_node("Panel/TabContainer/Army/ArmyEditPanel/ArmyHeaderRow/CloseArmyButton") as Button
	_army_name_value = get_node("Panel/TabContainer/Army/ArmyEditPanel/ArmyNameRow/ArmyNameValue") as Label
	_region_id_value_army = get_node("Panel/TabContainer/Army/ArmyEditPanel/RegionIDRow/RegionIDValue") as Label
	_region_name_value_army = get_node("Panel/TabContainer/Army/ArmyEditPanel/RegionNameRow/RegionNameValue") as Label
	_save_scenario_button = get_node("Panel/TabContainer/Main/SaveButtonRow/SaveScenarioButton") as Button
	_save_map_button = get_node("Panel/TabContainer/Main/SaveMapButtonRow/SaveMapButton") as Button
	_scenario_name_edit = get_node("Panel/TabContainer/Main/SaveRow/ScenarioNameEdit") as LineEdit
	_scenario_type_option = get_node("Panel/TabContainer/Main/ScenarioTypeRow/ScenarioTypeOption") as OptionButton
	_edit_difficulty_option = get_node("Panel/TabContainer/Main/SetDifficultyRow/SetDifficultyOption") as OptionButton
	_mission_number_row = get_node("Panel/TabContainer/Main/MissionNumberRow") as HBoxContainer
	_mission_number_option = get_node("Panel/TabContainer/Main/MissionNumberRow/MissionNumberOption") as OptionButton
	_exit_button = get_node("Panel/TabContainer/Main/ExitButtonRow/ExitButton") as Button
	_unit_edits = {
		SoldierTypeEnum.Type.PEASANTS: get_node("Panel/TabContainer/Army/ArmyEditPanel/PeasantsRow/PeasantsEdit") as LineEdit,
		SoldierTypeEnum.Type.SPEARMEN: get_node("Panel/TabContainer/Army/ArmyEditPanel/SpearmenRow/SpearmenEdit") as LineEdit,
		SoldierTypeEnum.Type.SWORDSMEN: get_node("Panel/TabContainer/Army/ArmyEditPanel/SwordsmenRow/SwordsmenEdit") as LineEdit,
		SoldierTypeEnum.Type.ARCHERS: get_node("Panel/TabContainer/Army/ArmyEditPanel/ArchersRow/ArchersEdit") as LineEdit,
		SoldierTypeEnum.Type.CROSSBOWMEN: get_node("Panel/TabContainer/Army/ArmyEditPanel/CrossbowmenRow/CrossbowmenEdit") as LineEdit,
		SoldierTypeEnum.Type.HORSEMEN: get_node("Panel/TabContainer/Army/ArmyEditPanel/HorsemenRow/HorsemenEdit") as LineEdit,
		SoldierTypeEnum.Type.KNIGHTS: get_node("Panel/TabContainer/Army/ArmyEditPanel/KnightsRow/KnightsEdit") as LineEdit,
		SoldierTypeEnum.Type.MOUNTED_KNIGHTS: get_node("Panel/TabContainer/Army/ArmyEditPanel/MountedKnightsRow/MountedKnightsEdit") as LineEdit,
		SoldierTypeEnum.Type.ROYAL_GUARD: get_node("Panel/TabContainer/Army/ArmyEditPanel/RoyalGuardRow/RoyalGuardEdit") as LineEdit
	}
	_resource_edits = {
		ResourcesEnum.Type.FOOD: get_node("Panel/TabContainer/Region/FoodRow/FoodEdit") as LineEdit,
		ResourcesEnum.Type.WOOD: get_node("Panel/TabContainer/Region/WoodRow/WoodEdit") as LineEdit,
		ResourcesEnum.Type.STONE: get_node("Panel/TabContainer/Region/StoneRow/StoneEdit") as LineEdit,
		ResourcesEnum.Type.IRON: get_node("Panel/TabContainer/Region/IronRow/IronEdit") as LineEdit,
		ResourcesEnum.Type.GOLD: get_node("Panel/TabContainer/Region/GoldRow/GoldEdit") as LineEdit
	}
	# Cache default Region tab nodes for show/hide when editing garrison
	_region_default_nodes = [
		get_node("Panel/TabContainer/Region/IDRow"),
		get_node("Panel/TabContainer/Region/NameRow"),
		get_node("Panel/TabContainer/Region/TypeRow"),
		get_node("Panel/TabContainer/Region/LevelRow"),
		get_node("Panel/TabContainer/Region/PopulationRow"),
		get_node("Panel/TabContainer/Region/CastleRow"),
		get_node("Panel/TabContainer/Region/OwnershipRow"),
		get_node("Panel/TabContainer/Region/ResourcesLabel"),
		get_node("Panel/TabContainer/Region/FoodRow"),
		get_node("Panel/TabContainer/Region/WoodRow"),
		get_node("Panel/TabContainer/Region/StoneRow"),
		get_node("Panel/TabContainer/Region/IronRow"),
		get_node("Panel/TabContainer/Region/GoldRow"),
		get_node("Panel/TabContainer/Region/OreRow"),
		get_node("Panel/TabContainer/Region/OreGuaranteeAttemptRow"),
		get_node("Panel/TabContainer/Region/OreGuaranteeTypeRow"),
		get_node("Panel/TabContainer/Region/GarrisonEditRow")
	]
	# Garrison UI nodes
	_edit_garrison_button = get_node("Panel/TabContainer/Region/GarrisonEditRow/EditGarrisonButton") as Button
	_garrison_edit_panel = get_node("Panel/TabContainer/Region/GarrisonEditPanel") as VBoxContainer
	_close_garrison_button = get_node("Panel/TabContainer/Region/GarrisonEditPanel/GarrisonHeaderRow/CloseGarrisonButton") as Button
	_garrison_unit_edits = {
		SoldierTypeEnum.Type.PEASANTS: get_node("Panel/TabContainer/Region/GarrisonEditPanel/GPeasantsRow/GPeasantsEdit") as LineEdit,
		SoldierTypeEnum.Type.SPEARMEN: get_node("Panel/TabContainer/Region/GarrisonEditPanel/GSpearmenRow/GSpearmenEdit") as LineEdit,
		SoldierTypeEnum.Type.SWORDSMEN: get_node("Panel/TabContainer/Region/GarrisonEditPanel/GSwordsmenRow/GSwordsmenEdit") as LineEdit,
		SoldierTypeEnum.Type.ARCHERS: get_node("Panel/TabContainer/Region/GarrisonEditPanel/GArchersRow/GArchersEdit") as LineEdit,
		SoldierTypeEnum.Type.CROSSBOWMEN: get_node("Panel/TabContainer/Region/GarrisonEditPanel/GCrossbowmenRow/GCrossbowmenEdit") as LineEdit,
		SoldierTypeEnum.Type.HORSEMEN: get_node("Panel/TabContainer/Region/GarrisonEditPanel/GHorsemenRow/GHorsemenEdit") as LineEdit,
		SoldierTypeEnum.Type.KNIGHTS: get_node("Panel/TabContainer/Region/GarrisonEditPanel/GKnightsRow/GKnightsEdit") as LineEdit,
		SoldierTypeEnum.Type.MOUNTED_KNIGHTS: get_node("Panel/TabContainer/Region/GarrisonEditPanel/GMountedKnightsRow/GMountedKnightsEdit") as LineEdit,
		SoldierTypeEnum.Type.ROYAL_GUARD: get_node("Panel/TabContainer/Region/GarrisonEditPanel/GRoyalGuardRow/GRoyalGuardEdit") as LineEdit
	}
	# Populate dropdowns and wire signals
	_populate_types()
	_option.item_selected.connect(_on_type_selected)
	_populate_levels()
	_level_option.item_selected.connect(_on_level_selected)
	_populate_castles()
	_castle_option.item_selected.connect(_on_castle_selected)
	_populate_ore_guarantee_types()
	_populate_ownership()
	_ownership_option.item_selected.connect(_on_ownership_selected)
	for rt in _resource_edits.keys():
		(_resource_edits[rt] as LineEdit).text_submitted.connect(Callable(self, "_on_resource_changed").bind(rt))
		(_resource_edits[rt] as LineEdit).focus_exited.connect(Callable(self, "_on_resource_focus_exited").bind(rt))
	_population_edit.text_submitted.connect(_on_population_changed)
	_population_edit.focus_exited.connect(_on_population_focus_exited)
	_ore_check.toggled.connect(_on_ore_toggled)
	_ore_guarantee_attempt_edit.text_submitted.connect(_on_ore_guarantee_attempt_changed)
	_ore_guarantee_attempt_edit.focus_exited.connect(_on_ore_guarantee_attempt_focus_exited)
	_ore_guarantee_type_option.item_selected.connect(_on_ore_guarantee_type_selected)
	_name_edit.text_submitted.connect(_on_name_changed)
	_name_edit.focus_exited.connect(_on_name_focus_exited)
	_army_toggle_button.pressed.connect(_on_army_toggle_pressed)
	_edit_army_button.pressed.connect(_on_edit_army_pressed)
	_close_army_button.pressed.connect(_on_close_army_pressed)
	_edit_garrison_button.pressed.connect(_on_edit_garrison_pressed)
	_close_garrison_button.pressed.connect(_on_close_garrison_pressed)
	_save_scenario_button.pressed.connect(_on_save_scenario_pressed)
	_save_map_button.pressed.connect(_on_save_map_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	
	# Get player settings container
	_player_settings_container = get_node("Panel/TabContainer/Scenario/PlayerSettingsContainer") as VBoxContainer
	_player_resource_selector = get_node("Panel/TabContainer/Scenario/PlayerResourceSelectorRow/PlayerResourceSelector") as OptionButton
	_player_resource_fields = {
		ResourcesEnum.Type.GOLD: get_node("Panel/TabContainer/Scenario/PlayerResourcesContainer/GoldRow/GoldValue") as LineEdit,
		ResourcesEnum.Type.WOOD: get_node("Panel/TabContainer/Scenario/PlayerResourcesContainer/WoodRow/WoodValue") as LineEdit,
		ResourcesEnum.Type.FOOD: get_node("Panel/TabContainer/Scenario/PlayerResourcesContainer/FoodRow/FoodValue") as LineEdit,
		ResourcesEnum.Type.STONE: get_node("Panel/TabContainer/Scenario/PlayerResourcesContainer/StoneRow/StoneValue") as LineEdit,
		ResourcesEnum.Type.IRON: get_node("Panel/TabContainer/Scenario/PlayerResourcesContainer/IronRow/IronValue") as LineEdit
	}
	_victory_type_option = get_node("Panel/TabContainer/Scenario/VictoryTypeRow/VictoryTypeOption") as OptionButton
	_victory_target_player_row = get_node("Panel/TabContainer/Scenario/VictoryTargetPlayerRow") as HBoxContainer
	_victory_target_player_option = get_node("Panel/TabContainer/Scenario/VictoryTargetPlayerRow/VictoryTargetPlayerOption") as OptionButton
	_victory_region_row = get_node("Panel/TabContainer/Scenario/VictoryRegionRow") as HBoxContainer
	_victory_region_value = get_node("Panel/TabContainer/Scenario/VictoryRegionRow/VictoryRegionValue") as LineEdit
	_victory_turns_row = get_node("Panel/TabContainer/Scenario/VictoryTurnsRow") as HBoxContainer
	_victory_turns_value = get_node("Panel/TabContainer/Scenario/VictoryTurnsRow/VictoryTurnsValue") as LineEdit
	_victory_region_level_row = get_node("Panel/TabContainer/Scenario/VictoryRegionLevelRow") as HBoxContainer
	_victory_region_level_option = get_node("Panel/TabContainer/Scenario/VictoryRegionLevelRow/VictoryRegionLevelOption") as OptionButton
	_victory_castle_level_row = get_node("Panel/TabContainer/Scenario/VictoryCastleLevelRow") as HBoxContainer
	_victory_castle_level_option = get_node("Panel/TabContainer/Scenario/VictoryCastleLevelRow/VictoryCastleLevelOption") as OptionButton
	_victory_unit_type_row = get_node("Panel/TabContainer/Scenario/VictoryUnitTypeRow") as HBoxContainer
	_victory_unit_type_option = get_node("Panel/TabContainer/Scenario/VictoryUnitTypeRow/VictoryUnitTypeOption") as OptionButton
	_victory_units_hired_row = get_node("Panel/TabContainer/Scenario/VictoryUnitsHiredRow") as HBoxContainer
	_victory_units_hired_value = get_node("Panel/TabContainer/Scenario/VictoryUnitsHiredRow/VictoryUnitsHiredValue") as LineEdit
	_scenario_trade_disabled_check = get_node("Panel/TabContainer/Scenario/TradeDisabledRow/TradeDisabledCheck") as CheckBox
	_scenario_difficulty_option = get_node("Panel/TabContainer/Scenario/DifficultyRow/DifficultyOption") as OptionButton
	_event_name_add_edit = get_node("Panel/TabContainer/Event/EventListView/EventAddRow/EventNameEdit") as LineEdit
	_event_add_button = get_node("Panel/TabContainer/Event/EventListView/EventAddRow/AddEventButton") as Button
	_event_list_view = get_node("Panel/TabContainer/Event/EventListView") as VBoxContainer
	_event_list_container = get_node("Panel/TabContainer/Event/EventListView/EventListContainer") as VBoxContainer
	_event_editor_view = get_node("Panel/TabContainer/Event/EventEditorView") as VBoxContainer
	_event_back_button = get_node("Panel/TabContainer/Event/EventEditorView/EventEditorHeaderRow/BackButton") as Button
	_event_save_button = get_node("Panel/TabContainer/Event/EventEditorView/EventSaveRow/SaveEventButton") as Button
	_event_edit_name = get_node("Panel/TabContainer/Event/EventEditorView/EventNameRow/EventNameValue") as LineEdit
	_event_regions_edit = get_node("Panel/TabContainer/Event/EventEditorView/EventRegionsRow/EventRegionsValue") as LineEdit
	_event_turn_start_edit = get_node("Panel/TabContainer/Event/EventEditorView/EventTurnStartRow/EventTurnStartValue") as LineEdit
	_event_turn_end_edit = get_node("Panel/TabContainer/Event/EventEditorView/EventTurnEndRow/EventTurnEndValue") as LineEdit
	_event_player_option = get_node("Panel/TabContainer/Event/EventEditorView/EventPlayerRow/EventPlayerOption") as OptionButton
	_event_regions_select_button = get_node("Panel/TabContainer/Event/EventEditorView/EventRegionsRow/EventRegionsSelectButton") as Button
	_event_message_text = get_node("Panel/TabContainer/Event/EventEditorView/EventMessageValue") as TextEdit
	_event_units_container = get_node("Panel/TabContainer/Event/EventEditorView/EventUnitsContainer") as VBoxContainer
	
	# Initialize player settings and resource UI
	_initialize_player_settings()
	_initialize_player_resources()
	_initialize_scenario_type_ui()
	_initialize_edit_difficulty_ui()
	_initialize_scenario_difficulty_ui()
	_initialize_victory_condition_ui()
	_initialize_events_ui()
	
	_player_resource_selector.item_selected.connect(_on_player_resource_selected)
	for rt in _player_resource_fields.keys():
		var field := _player_resource_fields[rt] as LineEdit
		field.text_submitted.connect(_on_player_resource_value_submitted.bind(rt))
		field.focus_exited.connect(_on_player_resource_focus_exited.bind(rt))
	_victory_type_option.item_selected.connect(_on_victory_type_selected)
	_scenario_type_option.item_selected.connect(_on_scenario_type_selected)
	_edit_difficulty_option.item_selected.connect(_on_edit_difficulty_selected)
	_event_add_button.pressed.connect(_on_event_add_pressed)
	_event_back_button.pressed.connect(_on_event_back_pressed)
	_event_save_button.pressed.connect(_on_event_save_pressed)
	_event_regions_select_button.pressed.connect(_on_event_regions_select_button_pressed)
	_event_regions_edit.text_changed.connect(_on_event_regions_text_changed)
	
	# Check for loaded scenario name after a short delay to ensure GameManager is ready
	call_deferred("_check_and_populate_scenario_name")

func _check_and_populate_scenario_name() -> void:
	"""Check if we loaded from a scenario and populate the name field"""
	# Check if there's a scenario path in the game manager or metadata
	var gm = get_node_or_null("../../GameManager")
	if gm and gm.has_method("get_loaded_scenario_name"):
		var scenario_name = gm.get_loaded_scenario_name()
		if scenario_name != "":
			# Remove .json extension if present
			if scenario_name.ends_with(".json"):
				scenario_name = scenario_name.substr(0, scenario_name.length() - 5)
			_scenario_name_edit.text = scenario_name
			DebugLogger.log("MapEditorPanel", "Populated scenario name: " + scenario_name)
			
			# Try to load player settings from the scenario
			_load_player_settings_from_scenario(scenario_name)
			return
	# If game manager didn't report a scenario name, leave field as-is

func _load_player_settings_from_scenario(scenario_name: String) -> void:
	"""Load player settings from an existing scenario file"""
	var path := "res://scenarios/" + scenario_name + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		DebugLogger.log("MapEditorPanel", "Could not open scenario file: " + path)
		return
	
	var json_text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		DebugLogger.log("MapEditorPanel", "Failed to parse scenario JSON")
		return
	
	var data: Dictionary = json.data
	if data.has("player_settings"):
		# Update our player settings array
		var loaded_settings = data["player_settings"]
		if loaded_settings is Array and loaded_settings.size() == 6:
			player_settings = loaded_settings.duplicate(true)
			# Update the UI to reflect loaded settings
			_update_player_settings_ui()
			DebugLogger.log("MapEditorPanel", "Loaded player settings from scenario")
	if data.has("player_resources"):
		var loaded_resources = data["player_resources"]
		if loaded_resources is Array:
			_apply_loaded_player_resources(loaded_resources)
			DebugLogger.log("MapEditorPanel", "Loaded player resources from scenario")
	_apply_loaded_difficulty_overrides(data)
	_set_scenario_type_from_data(String(data.get("scenario_type", "scenario")))
	var mission_number: int = maxi(1, int(data.get("mission_number", 1)))
	var mission_index: int = mini(_mission_number_option.item_count - 1, mission_number - 1)
	_mission_number_option.select(maxi(0, mission_index))
	_scenario_trade_disabled_check.button_pressed = bool(data.get("trade_disabled", false))
	_set_scenario_difficulty_from_data(String(data.get("difficulty", "all")))
	_set_edit_difficulty_target_from_data("all")
	_refresh_difficulty_scoped_editor_views()
	_load_victory_conditions_from_scenario(data)
	_load_events_from_scenario(data)

func _initialize_scenario_type_ui() -> void:
	_scenario_type_option.clear()
	_scenario_type_option.add_item("Scenario")
	_scenario_type_option.add_item("Campaign")
	_scenario_type_option.select(0)
	_mission_number_option.clear()
	for i in range(1, 31):
		_mission_number_option.add_item(str(i))
	_mission_number_option.select(0)
	_update_mission_number_visibility()

func _initialize_edit_difficulty_ui() -> void:
	_edit_difficulty_option.clear()
	_edit_difficulty_option.add_item("All")
	_edit_difficulty_option.add_item("Easy")
	_edit_difficulty_option.add_item("Normal")
	_edit_difficulty_option.add_item("Hard")
	_edit_difficulty_option.select(0)
	_edit_difficulty_target = "all"

func _normalize_edit_difficulty_token(raw_value: String) -> String:
	var normalized: String = raw_value.to_lower().strip_edges()
	match normalized:
		"easy", "normal", "hard":
			return normalized
		_:
			return "all"

func _set_edit_difficulty_target_from_data(raw_value: String) -> void:
	var normalized: String = _normalize_edit_difficulty_token(raw_value)
	match normalized:
		"easy":
			_edit_difficulty_option.select(1)
		"normal":
			_edit_difficulty_option.select(2)
		"hard":
			_edit_difficulty_option.select(3)
		_:
			_edit_difficulty_option.select(0)
	_edit_difficulty_target = normalized

func _on_edit_difficulty_selected(index: int) -> void:
	var selected_token: String = "all"
	match index:
		1:
			selected_token = "easy"
		2:
			selected_token = "normal"
		3:
			selected_token = "hard"
	_edit_difficulty_target = selected_token
	_refresh_difficulty_scoped_editor_views()

func _refresh_difficulty_scoped_editor_views() -> void:
	var army_panel_was_open: bool = _army_edit_panel.visible
	var garrison_panel_was_open: bool = _garrison_edit_panel.visible
	var event_editor_was_open: bool = _event_editor_view.visible
	var edited_event_index: int = _editing_event_index
	_show_player_resources_for_index(_current_resource_player_index)
	if _current_region_node != null:
		update_from_region(_current_region_node)
		if garrison_panel_was_open:
			_on_edit_garrison_pressed()
		if army_panel_was_open:
			_populate_army_panel()
			_tab_container.current_tab = 3
			_army_default_content.visible = false
			_army_edit_panel.visible = true
	_refresh_events_list()
	if event_editor_was_open and edited_event_index >= 0:
		_show_event_editor_by_index(edited_event_index)

func _apply_loaded_difficulty_overrides(data: Dictionary) -> void:
	_difficulty_player_resources_overrides.clear()
	_difficulty_army_compositions_overrides.clear()
	_difficulty_garrison_compositions_overrides.clear()
	_difficulty_event_compositions_overrides.clear()
	var raw_overrides: Variant = data.get("difficulty_overrides", {})
	if not (raw_overrides is Dictionary):
		return
	var overrides: Dictionary = raw_overrides as Dictionary
	for difficulty_token in SCENARIO_EDIT_DIFFICULTIES:
		if difficulty_token == "all":
			continue
		var raw_block: Variant = overrides.get(difficulty_token, null)
		if not (raw_block is Dictionary):
			continue
		var block: Dictionary = raw_block as Dictionary
		var raw_player_resources: Variant = block.get("player_resources", null)
		if raw_player_resources is Array:
			_difficulty_player_resources_overrides[difficulty_token] = _sanitize_player_resources_entries(raw_player_resources as Array, true)
		var raw_army_entries: Variant = block.get("army_compositions", null)
		if raw_army_entries is Array:
			var army_map: Dictionary = _extract_composition_override_map_from_entries(raw_army_entries as Array)
			if not army_map.is_empty():
				_difficulty_army_compositions_overrides[difficulty_token] = army_map
		var raw_garrison_entries: Variant = block.get("garrison_compositions", null)
		if raw_garrison_entries is Array:
			var garrison_map: Dictionary = _extract_composition_override_map_from_entries(raw_garrison_entries as Array)
			if not garrison_map.is_empty():
				_difficulty_garrison_compositions_overrides[difficulty_token] = garrison_map
		var raw_event_entries: Variant = block.get("event_compositions", null)
		if raw_event_entries is Array:
			var event_map: Dictionary = _extract_event_composition_override_map_from_entries(raw_event_entries as Array)
			if not event_map.is_empty():
				_difficulty_event_compositions_overrides[difficulty_token] = event_map

func _extract_composition_override_map_from_entries(raw_entries: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_entry in raw_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var region_id: int = int(entry.get("region_id", -1))
		if region_id <= 0:
			continue
		var raw_composition: Variant = entry.get("composition", {})
		if not (raw_composition is Dictionary):
			continue
		result[region_id] = _sanitize_unit_composition(raw_composition as Dictionary)
	return result

func _extract_event_composition_override_map_from_entries(raw_entries: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_entry in raw_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var event_index: int = int(entry.get("event_index", -1))
		if event_index < 0:
			continue
		var raw_composition: Variant = entry.get("composition", {})
		if not (raw_composition is Dictionary):
			continue
		result[event_index] = _sanitize_unit_composition(raw_composition as Dictionary)
	return result

func _sanitize_unit_composition(raw_composition: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	for unit_type in SoldierTypeEnum.get_all_types():
		var unit_key: String = SoldierTypeEnum.type_to_string(unit_type)
		sanitized[unit_key] = maxi(0, int(raw_composition.get(unit_key, 0)))
	return sanitized

func _build_default_player_resources_entries() -> Array:
	var defaults: Array = []
	for i in range(6):
		defaults.append(_build_default_player_resource_entry(i + 1))
	return defaults

func _sanitize_player_resources_entries(resources_data: Array, seed_from_baseline: bool) -> Array:
	var sanitized: Array = []
	if seed_from_baseline and player_resources.size() == 6:
		sanitized = player_resources.duplicate(true)
	else:
		sanitized = _build_default_player_resources_entries()
	for raw_entry in resources_data:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var player_id: int = int(entry.get("player_id", 0))
		if player_id < 1 or player_id > sanitized.size():
			continue
		var target_entry: Dictionary = sanitized[player_id - 1]
		target_entry["player_id"] = player_id
		var target_resources: Dictionary = target_entry.get("resources", {})
		var raw_resources: Variant = entry.get("resources", {})
		if raw_resources is Dictionary:
			var source_resources: Dictionary = raw_resources as Dictionary
			for resource_type in ResourcesEnum.get_all_types():
				var resource_key: String = ResourcesEnum.type_to_string(resource_type)
				if source_resources.has(resource_key):
					target_resources[resource_key] = maxi(0, int(source_resources.get(resource_key, target_resources.get(resource_key, 0))))
		target_entry["resources"] = target_resources
		sanitized[player_id - 1] = target_entry
	return sanitized

func _get_effective_player_resources_entries() -> Array:
	if _edit_difficulty_target == "all":
		return player_resources
	var raw_override: Variant = _difficulty_player_resources_overrides.get(_edit_difficulty_target, null)
	if raw_override is Array:
		return raw_override as Array
	return player_resources

func _ensure_edit_target_player_resources_override() -> Array:
	if _edit_difficulty_target == "all":
		return player_resources
	if not _difficulty_player_resources_overrides.has(_edit_difficulty_target):
		_difficulty_player_resources_overrides[_edit_difficulty_target] = player_resources.duplicate(true)
	var raw_entries: Variant = _difficulty_player_resources_overrides.get(_edit_difficulty_target, [])
	if raw_entries is Array:
		return raw_entries as Array
	var fallback: Array = player_resources.duplicate(true)
	_difficulty_player_resources_overrides[_edit_difficulty_target] = fallback
	return fallback

func _get_army_override_map_for_target() -> Dictionary:
	var raw_map: Variant = _difficulty_army_compositions_overrides.get(_edit_difficulty_target, {})
	if raw_map is Dictionary:
		return raw_map as Dictionary
	return {}

func _get_garrison_override_map_for_target() -> Dictionary:
	var raw_map: Variant = _difficulty_garrison_compositions_overrides.get(_edit_difficulty_target, {})
	if raw_map is Dictionary:
		return raw_map as Dictionary
	return {}

func _ensure_army_override_map_for_target() -> Dictionary:
	if not _difficulty_army_compositions_overrides.has(_edit_difficulty_target):
		_difficulty_army_compositions_overrides[_edit_difficulty_target] = {}
	var raw_map: Variant = _difficulty_army_compositions_overrides.get(_edit_difficulty_target, {})
	if raw_map is Dictionary:
		return raw_map as Dictionary
	var fallback: Dictionary = {}
	_difficulty_army_compositions_overrides[_edit_difficulty_target] = fallback
	return fallback

func _ensure_garrison_override_map_for_target() -> Dictionary:
	if not _difficulty_garrison_compositions_overrides.has(_edit_difficulty_target):
		_difficulty_garrison_compositions_overrides[_edit_difficulty_target] = {}
	var raw_map: Variant = _difficulty_garrison_compositions_overrides.get(_edit_difficulty_target, {})
	if raw_map is Dictionary:
		return raw_map as Dictionary
	var fallback: Dictionary = {}
	_difficulty_garrison_compositions_overrides[_edit_difficulty_target] = fallback
	return fallback

func _get_event_override_map_for_target() -> Dictionary:
	var raw_map: Variant = _difficulty_event_compositions_overrides.get(_edit_difficulty_target, {})
	if raw_map is Dictionary:
		return raw_map as Dictionary
	return {}

func _ensure_event_override_map_for_target() -> Dictionary:
	if not _difficulty_event_compositions_overrides.has(_edit_difficulty_target):
		_difficulty_event_compositions_overrides[_edit_difficulty_target] = {}
	var raw_map: Variant = _difficulty_event_compositions_overrides.get(_edit_difficulty_target, {})
	if raw_map is Dictionary:
		return raw_map as Dictionary
	var fallback: Dictionary = {}
	_difficulty_event_compositions_overrides[_edit_difficulty_target] = fallback
	return fallback

func _get_first_army_from_region(region: Region) -> Army:
	for child in region.get_children():
		if child is Army:
			return child as Army
	return null

func _build_named_composition_from_army(army: Army) -> Dictionary:
	var composition: Dictionary = {}
	for unit_type in SoldierTypeEnum.get_all_types():
		var unit_key: String = SoldierTypeEnum.type_to_string(unit_type)
		composition[unit_key] = 0
	if army == null:
		return composition
	for unit_type in SoldierTypeEnum.get_all_types():
		var unit_key: String = SoldierTypeEnum.type_to_string(unit_type)
		composition[unit_key] = army.get_soldier_count(unit_type)
	return composition

func _build_named_composition_from_garrison(region: Region) -> Dictionary:
	var composition: Dictionary = {}
	var garrison = region.get_garrison()
	for unit_type in SoldierTypeEnum.get_all_types():
		var unit_key: String = SoldierTypeEnum.type_to_string(unit_type)
		composition[unit_key] = garrison.get_soldier_count(unit_type)
	return composition

func _get_effective_army_composition_for_region(region: Region) -> Dictionary:
	var composition: Dictionary = _build_named_composition_from_army(_get_first_army_from_region(region))
	if _edit_difficulty_target == "all":
		return composition
	var overrides: Dictionary = _get_army_override_map_for_target()
	if overrides.has(region.get_region_id()):
		var raw_override: Variant = overrides.get(region.get_region_id(), {})
		if raw_override is Dictionary:
			return _sanitize_unit_composition(raw_override as Dictionary)
	return composition

func _get_effective_garrison_composition_for_region(region: Region) -> Dictionary:
	var composition: Dictionary = _build_named_composition_from_garrison(region)
	if _edit_difficulty_target == "all":
		return composition
	var overrides: Dictionary = _get_garrison_override_map_for_target()
	if overrides.has(region.get_region_id()):
		var raw_override: Variant = overrides.get(region.get_region_id(), {})
		if raw_override is Dictionary:
			return _sanitize_unit_composition(raw_override as Dictionary)
	return composition

func _apply_named_composition_to_edits(unit_edits: Dictionary, composition: Dictionary) -> void:
	for unit_type in unit_edits.keys():
		var unit_key: String = SoldierTypeEnum.type_to_string(unit_type)
		var unit_value: int = maxi(0, int(composition.get(unit_key, 0)))
		(unit_edits[unit_type] as LineEdit).text = str(unit_value)

func _read_named_composition_from_edits(unit_edits: Dictionary) -> Dictionary:
	var composition: Dictionary = {}
	for unit_type in unit_edits.keys():
		var unit_key: String = SoldierTypeEnum.type_to_string(unit_type)
		var value: int = maxi(0, int((unit_edits[unit_type] as LineEdit).text))
		composition[unit_key] = value
	return composition

func _are_named_compositions_equal(left: Dictionary, right: Dictionary) -> bool:
	for unit_type in SoldierTypeEnum.get_all_types():
		var unit_key: String = SoldierTypeEnum.type_to_string(unit_type)
		if int(left.get(unit_key, 0)) != int(right.get(unit_key, 0)):
			return false
	return true

func _save_army_override_for_current_region() -> void:
	var edited: Dictionary = _read_named_composition_from_edits(_unit_edits)
	var current_effective: Dictionary = _get_effective_army_composition_for_region(_current_region_node)
	if _are_named_compositions_equal(edited, current_effective):
		return
	var overrides: Dictionary = _ensure_army_override_map_for_target()
	overrides[_current_region_id] = edited
	_difficulty_army_compositions_overrides[_edit_difficulty_target] = overrides

func _save_garrison_override_for_current_region() -> void:
	var edited: Dictionary = _read_named_composition_from_edits(_garrison_unit_edits)
	var current_effective: Dictionary = _get_effective_garrison_composition_for_region(_current_region_node)
	if _are_named_compositions_equal(edited, current_effective):
		return
	var overrides: Dictionary = _ensure_garrison_override_map_for_target()
	overrides[_current_region_id] = edited
	_difficulty_garrison_compositions_overrides[_edit_difficulty_target] = overrides

func _build_composition_override_entries(overrides_map: Dictionary) -> Array:
	var region_ids: Array[int] = []
	for key in overrides_map.keys():
		var region_id: int = int(key)
		if region_id > 0:
			region_ids.append(region_id)
	region_ids.sort()
	var entries: Array = []
	for region_id in region_ids:
		var raw_composition: Variant = overrides_map.get(region_id, {})
		if not (raw_composition is Dictionary):
			continue
		entries.append({
			"region_id": region_id,
			"composition": _sanitize_unit_composition(raw_composition as Dictionary)
		})
	return entries

func _build_difficulty_overrides_for_save() -> Dictionary:
	var result: Dictionary = {}
	for difficulty_token in SCENARIO_EDIT_DIFFICULTIES:
		if difficulty_token == "all":
			continue
		var block: Dictionary = {}
		var raw_player_resources: Variant = _difficulty_player_resources_overrides.get(difficulty_token, null)
		if raw_player_resources is Array:
			block["player_resources"] = _sanitize_player_resources_entries(raw_player_resources as Array, true)
		var raw_army_overrides: Variant = _difficulty_army_compositions_overrides.get(difficulty_token, {})
		if raw_army_overrides is Dictionary:
			var army_entries: Array = _build_composition_override_entries(raw_army_overrides as Dictionary)
			if not army_entries.is_empty():
				block["army_compositions"] = army_entries
		var raw_garrison_overrides: Variant = _difficulty_garrison_compositions_overrides.get(difficulty_token, {})
		if raw_garrison_overrides is Dictionary:
			var garrison_entries: Array = _build_composition_override_entries(raw_garrison_overrides as Dictionary)
			if not garrison_entries.is_empty():
				block["garrison_compositions"] = garrison_entries
		var raw_event_overrides: Variant = _difficulty_event_compositions_overrides.get(difficulty_token, {})
		if raw_event_overrides is Dictionary:
			var event_entries: Array = _build_event_composition_override_entries(raw_event_overrides as Dictionary)
			if not event_entries.is_empty():
				block["event_compositions"] = event_entries
		if not block.is_empty():
			result[difficulty_token] = block
	return result

func _build_event_composition_override_entries(overrides_map: Dictionary) -> Array:
	var event_indexes: Array[int] = []
	for key in overrides_map.keys():
		var event_index: int = int(key)
		if event_index >= 0:
			event_indexes.append(event_index)
	event_indexes.sort()
	var entries: Array = []
	for event_index in event_indexes:
		var raw_composition: Variant = overrides_map.get(event_index, {})
		if not (raw_composition is Dictionary):
			continue
		entries.append({
			"event_index": event_index,
			"composition": _sanitize_unit_composition(raw_composition as Dictionary)
		})
	return entries

func _initialize_scenario_difficulty_ui() -> void:
	_scenario_difficulty_option.clear()
	_scenario_difficulty_option.add_item("All")
	_scenario_difficulty_option.add_item("Easy")
	_scenario_difficulty_option.add_item("Normal")
	_scenario_difficulty_option.add_item("Hard")
	_scenario_difficulty_option.select(0)

func _on_scenario_type_selected(_index: int) -> void:
	_update_mission_number_visibility()

func _set_scenario_type_from_data(type_value: String) -> void:
	var normalized: String = type_value.to_lower()
	if normalized == "campaign":
		_scenario_type_option.select(1)
	else:
		_scenario_type_option.select(0)
	_update_mission_number_visibility()

func _get_selected_scenario_type() -> String:
	if _scenario_type_option.selected == 1:
		return "campaign"
	return "scenario"

func _set_scenario_difficulty_from_data(difficulty_value: String) -> void:
	var normalized: String = difficulty_value.to_lower()
	match normalized:
		"easy":
			_scenario_difficulty_option.select(1)
		"normal":
			_scenario_difficulty_option.select(2)
		"hard":
			_scenario_difficulty_option.select(3)
		_:
			_scenario_difficulty_option.select(0)

func _get_selected_scenario_difficulty() -> String:
	match _scenario_difficulty_option.selected:
		1:
			return "easy"
		2:
			return "normal"
		3:
			return "hard"
		_:
			return "all"

func _update_mission_number_visibility() -> void:
	_mission_number_row.visible = _get_selected_scenario_type() == "campaign"

func _initialize_victory_condition_ui() -> void:
	_victory_type_option.clear()
	_victory_type_option.add_item("Conquer")
	_victory_type_option.add_item("Conquer After Events")
	_victory_type_option.add_item("Dominate")
	_victory_type_option.add_item("Own Region")
	_victory_type_option.add_item("Survive Turns")
	_victory_type_option.add_item("Economy")
	_victory_target_player_option.clear()
	for i in range(1, 7):
		_victory_target_player_option.add_item("Player " + str(i))
	_victory_target_player_option.select(0)
	_victory_region_level_option.clear()
	for level in RegionLevelEnum.get_all_levels():
		_victory_region_level_option.add_item(RegionLevelEnum.level_to_string(level))
	_victory_region_level_option.select(0)
	_victory_castle_level_option.clear()
	for castle_type in CastleTypeEnum.get_all_types():
		_victory_castle_level_option.add_item(CastleTypeEnum.type_to_string(castle_type))
	_victory_castle_level_option.select(0)
	_victory_unit_type_option.clear()
	for unit_type in SoldierTypeEnum.get_all_types():
		_victory_unit_type_option.add_item(SoldierTypeEnum.type_to_string(unit_type))
	_victory_unit_type_option.select(0)
	_victory_region_value.text = "0"
	_victory_turns_value.text = "1"
	_victory_units_hired_value.text = "1"
	_select_victory_type("conquer")

func _on_victory_type_selected(index: int) -> void:
	var victory_key: String = _victory_type_keys[index]
	_update_victory_condition_fields(victory_key)

func _select_victory_type(victory_key: String) -> void:
	var index: int = 0
	for i in range(_victory_type_keys.size()):
		if _victory_type_keys[i] == victory_key:
			index = i
			break
	_victory_type_option.select(index)
	_update_victory_condition_fields(victory_key)

func _update_victory_condition_fields(victory_key: String) -> void:
	_victory_target_player_row.visible = victory_key == "own_region" or victory_key == "survive_turns" or victory_key == "economy"
	_victory_region_row.visible = victory_key == "own_region" or victory_key == "economy"
	_victory_turns_row.visible = victory_key == "survive_turns"
	_victory_region_level_row.visible = victory_key == "economy"
	_victory_castle_level_row.visible = victory_key == "economy"
	_victory_unit_type_row.visible = victory_key == "economy"
	_victory_units_hired_row.visible = victory_key == "economy"

func _get_selected_victory_type_key() -> String:
	var index: int = _victory_type_option.selected
	if index < 0 or index >= _victory_type_keys.size():
		return "conquer"
	return _victory_type_keys[index]

func _load_victory_conditions_from_scenario(data: Dictionary) -> void:
	if not data.has("victory_conditions"):
		_select_victory_type("conquer")
		return
	var victory_conditions: Array = data.get("victory_conditions", [])
	if victory_conditions.is_empty():
		_select_victory_type("conquer")
		return
	var first_condition: Variant = victory_conditions[0]
	if first_condition is String:
		var key: String = String(first_condition).to_lower()
		if key == "conquer" or key == "conquer_after_events" or key == "dominate":
			_select_victory_type(key)
		else:
			_select_victory_type("conquer")
		return
	if not (first_condition is Dictionary):
		_select_victory_type("conquer")
		return
	var condition: Dictionary = first_condition as Dictionary
	var type_key: String = String(condition.get("type", "conquer")).to_lower()
	match type_key:
		"conquer":
			_select_victory_type("conquer")
		"conquer_after_events", "conquer_events", "event_conquer":
			_select_victory_type("conquer_after_events")
		"dominate":
			_select_victory_type("dominate")
		"own_region":
			_select_victory_type("own_region")
			var player_id: int = maxi(1, mini(6, int(condition.get("player_id", 1))))
			_victory_target_player_option.select(player_id - 1)
			_victory_region_value.text = str(maxi(0, int(condition.get("region_id", 0))))
		"survive", "survive_turns":
			_select_victory_type("survive_turns")
			var player_id: int = maxi(1, mini(6, int(condition.get("player_id", 1))))
			_victory_target_player_option.select(player_id - 1)
			var turns: int = int(condition.get("turns", condition.get("required_turns", 1)))
			_victory_turns_value.text = str(maxi(1, turns))
		"economy":
			_select_victory_type("economy")
			var player_id: int = maxi(1, mini(6, int(condition.get("player_id", 1))))
			_victory_target_player_option.select(player_id - 1)
			_victory_region_value.text = str(maxi(0, int(condition.get("region_id", 0))))
			var required_region_level: String = String(condition.get("required_region_level", condition.get("region_level", "Shire")))
			var required_castle_level: String = String(condition.get("required_castle_level", condition.get("castle_level", "Outpost")))
			var unit_type_name: String = String(condition.get("unit_type", "Peasants"))
			var units_hired: int = int(condition.get("units_hired", condition.get("required_units_hired", condition.get("unit_count", 1))))
			_select_option_by_text(_victory_region_level_option, required_region_level)
			_select_option_by_text(_victory_castle_level_option, required_castle_level)
			_select_option_by_text(_victory_unit_type_option, unit_type_name)
			_victory_units_hired_value.text = str(maxi(1, units_hired))
		_:
			_select_victory_type("conquer")

func _build_victory_conditions_for_save() -> Array:
	var victory_type: String = _get_selected_victory_type_key()
	match victory_type:
		"conquer":
			return ["conquer"]
		"conquer_after_events":
			return ["conquer_after_events"]
		"dominate":
			return ["dominate"]
		"own_region":
			var player_id: int = _victory_target_player_option.selected + 1
			var region_id: int = maxi(0, int(_victory_region_value.text))
			return [{
				"type": "own_region",
				"player_id": player_id,
				"region_id": region_id
			}]
		"survive_turns":
			var player_id: int = _victory_target_player_option.selected + 1
			var turns: int = maxi(1, int(_victory_turns_value.text))
			return [{
				"type": "survive_turns",
				"player_id": player_id,
				"turns": turns
			}]
		"economy":
			var player_id: int = _victory_target_player_option.selected + 1
			var region_id: int = maxi(0, int(_victory_region_value.text))
			var required_region_level: String = _victory_region_level_option.get_item_text(_victory_region_level_option.selected)
			var required_castle_level: String = _victory_castle_level_option.get_item_text(_victory_castle_level_option.selected)
			var unit_type_name: String = _victory_unit_type_option.get_item_text(_victory_unit_type_option.selected)
			var units_hired: int = maxi(1, int(_victory_units_hired_value.text))
			return [{
				"type": "economy",
				"player_id": player_id,
				"region_id": region_id,
				"required_region_level": required_region_level,
				"required_castle_level": required_castle_level,
				"unit_type": unit_type_name,
				"units_hired": units_hired
			}]
		_:
			return ["conquer"]

func _select_option_by_text(option: OptionButton, text_value: String) -> void:
	for i in range(option.item_count):
		var item_text: String = option.get_item_text(i)
		if item_text.to_lower() == text_value.to_lower():
			option.select(i)
			return
	option.select(0)

func _initialize_events_ui() -> void:
	_set_event_region_select_mode(false)
	_event_player_option.clear()
	for i in range(1, 7):
		_event_player_option.add_item("Player " + str(i))
	_event_player_option.select(0)
	_build_event_unit_inputs()
	_event_list_view.visible = true
	_event_editor_view.visible = false
	_events.clear()
	_difficulty_event_compositions_overrides.clear()
	_refresh_events_list()

func _build_event_unit_inputs() -> void:
	_event_unit_edits.clear()
	for child in _event_units_container.get_children():
		child.queue_free()
	for unit_type in SoldierTypeEnum.get_all_types():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.custom_minimum_size = Vector2(140, 0)
		label.text = SoldierTypeEnum.type_to_string(unit_type)
		row.add_child(label)
		var edit := LineEdit.new()
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.placeholder_text = "0"
		edit.text = "0"
		row.add_child(edit)
		_event_unit_edits[unit_type] = edit
		_event_units_container.add_child(row)

func _on_event_add_pressed() -> void:
	if _edit_difficulty_target != "all":
		return
	var name: String = _event_name_add_edit.text.strip_edges()
	if name == "":
		name = "Event " + str(_events.size() + 1)
	var event_data: Dictionary = _build_default_event(name)
	_events.append(event_data)
	_event_name_add_edit.text = ""
	_refresh_events_list()

func _build_default_event(name: String) -> Dictionary:
	var composition: Dictionary = {}
	for unit_type in SoldierTypeEnum.get_all_types():
		var unit_name: String = SoldierTypeEnum.type_to_string(unit_type)
		composition[unit_name] = 0
	return {
		"name": name,
		"regions": [0],
		"turn_start": 1,
		"turn_end": 1,
		"player_id": 1,
		"composition": composition,
		"message": ""
	}

func _refresh_events_list() -> void:
	var can_edit_baseline_event_fields: bool = _edit_difficulty_target == "all"
	_event_add_button.disabled = not can_edit_baseline_event_fields
	for child in _event_list_container.get_children():
		child.queue_free()
	for i in range(_events.size()):
		var event_data: Dictionary = _events[i]
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 34
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = String(event_data.get("name", "Event " + str(i + 1)))
		row.add_child(label)
		var edit_button := Button.new()
		edit_button.text = "Edit"
		edit_button.pressed.connect(_on_event_edit_pressed.bind(i))
		row.add_child(edit_button)
		var delete_button := Button.new()
		delete_button.text = "Delete"
		delete_button.disabled = not can_edit_baseline_event_fields
		delete_button.pressed.connect(_on_event_delete_pressed.bind(i))
		row.add_child(delete_button)
		_event_list_container.add_child(row)

func _on_event_edit_pressed(index: int) -> void:
	if index < 0 or index >= _events.size():
		return
	_show_event_editor_by_index(index)

func _on_event_delete_pressed(index: int) -> void:
	if _edit_difficulty_target != "all":
		return
	if index < 0 or index >= _events.size():
		return
	_events.remove_at(index)
	if _editing_event_index == index:
		_set_event_region_select_mode(false)
		_clear_event_region_highlights()
		_editing_event_index = -1
		_event_list_view.visible = true
		_event_editor_view.visible = false
	elif _editing_event_index > index:
		_editing_event_index -= 1
	_shift_event_overrides_after_delete(index)
	_refresh_events_list()

func _show_event_editor_by_index(event_index: int) -> void:
	if event_index < 0 or event_index >= _events.size():
		return
	var event_data: Dictionary = _events[event_index]
	_editing_event_index = event_index
	_event_list_view.visible = false
	_event_editor_view.visible = true
	_set_event_region_select_mode(false)
	_event_edit_name.text = String(event_data.get("name", ""))
	_event_regions_edit.text = _regions_to_csv(event_data.get("regions", []))
	_event_turn_start_edit.text = str(int(event_data.get("turn_start", 1)))
	_event_turn_end_edit.text = str(int(event_data.get("turn_end", 1)))
	var player_id: int = maxi(1, mini(6, int(event_data.get("player_id", 1))))
	_event_player_option.select(player_id - 1)
	_event_message_text.text = String(event_data.get("message", ""))
	_set_event_editor_baseline_fields_editable(_edit_difficulty_target == "all")
	var composition: Dictionary = _get_effective_event_composition_for_index(event_index)
	_apply_named_composition_to_edits(_event_unit_edits, composition)
	_refresh_event_region_highlights_from_editor()

func _set_event_editor_baseline_fields_editable(editable: bool) -> void:
	_event_edit_name.editable = editable
	_event_regions_edit.editable = editable
	_event_turn_start_edit.editable = editable
	_event_turn_end_edit.editable = editable
	_event_player_option.disabled = not editable
	_event_message_text.editable = editable
	_event_regions_select_button.disabled = not editable
	if not editable:
		_set_event_region_select_mode(false)

func _get_effective_event_composition_for_index(event_index: int) -> Dictionary:
	if event_index < 0 or event_index >= _events.size():
		return _sanitize_unit_composition({})
	var baseline_raw: Variant = _events[event_index].get("composition", {})
	var baseline_source: Dictionary = {}
	if baseline_raw is Dictionary:
		baseline_source = baseline_raw as Dictionary
	var baseline_composition: Dictionary = _sanitize_unit_composition(baseline_source)
	if _edit_difficulty_target == "all":
		return baseline_composition
	var overrides: Dictionary = _get_event_override_map_for_target()
	if overrides.has(event_index):
		var raw_override: Variant = overrides.get(event_index, {})
		if raw_override is Dictionary:
			return _sanitize_unit_composition(raw_override as Dictionary)
	return baseline_composition

func _save_event_composition_override_for_index(event_index: int, edited_composition: Dictionary) -> void:
	if event_index < 0 or event_index >= _events.size():
		return
	var normalized_edited: Dictionary = _sanitize_unit_composition(edited_composition)
	var baseline_raw: Variant = _events[event_index].get("composition", {})
	var baseline_source: Dictionary = {}
	if baseline_raw is Dictionary:
		baseline_source = baseline_raw as Dictionary
	var baseline_composition: Dictionary = _sanitize_unit_composition(baseline_source)
	var overrides: Dictionary = _ensure_event_override_map_for_target()
	if _are_named_compositions_equal(normalized_edited, baseline_composition):
		overrides.erase(event_index)
	else:
		overrides[event_index] = normalized_edited
	if overrides.is_empty():
		_difficulty_event_compositions_overrides.erase(_edit_difficulty_target)
	else:
		_difficulty_event_compositions_overrides[_edit_difficulty_target] = overrides

func _shift_event_overrides_after_delete(deleted_index: int) -> void:
	for difficulty_token in _difficulty_event_compositions_overrides.keys():
		var raw_map: Variant = _difficulty_event_compositions_overrides[difficulty_token]
		if not (raw_map is Dictionary):
			continue
		var source_map: Dictionary = raw_map as Dictionary
		var shifted_map: Dictionary = {}
		for key in source_map.keys():
			var event_index: int = int(key)
			var raw_composition: Variant = source_map.get(key, {})
			if event_index == deleted_index:
				continue
			if event_index > deleted_index:
				shifted_map[event_index - 1] = raw_composition
			else:
				shifted_map[event_index] = raw_composition
		if shifted_map.is_empty():
			_difficulty_event_compositions_overrides.erase(difficulty_token)
		else:
			_difficulty_event_compositions_overrides[difficulty_token] = shifted_map

func _on_event_back_pressed() -> void:
	_set_event_region_select_mode(false)
	_clear_event_region_highlights()
	_editing_event_index = -1
	_event_list_view.visible = true
	_event_editor_view.visible = false

func _on_event_save_pressed() -> void:
	if _editing_event_index < 0 or _editing_event_index >= _events.size():
		return
	_set_event_region_select_mode(false)
	var composition: Dictionary = _read_named_composition_from_edits(_event_unit_edits)
	if _edit_difficulty_target != "all":
		_save_event_composition_override_for_index(_editing_event_index, composition)
		_refresh_events_list()
		_on_event_back_pressed()
		return
	var start_turn: int = maxi(1, int(_event_turn_start_edit.text))
	var end_turn: int = maxi(1, int(_event_turn_end_edit.text))
	if end_turn < start_turn:
		var tmp: int = start_turn
		start_turn = end_turn
		end_turn = tmp
	var event_data: Dictionary = _events[_editing_event_index]
	event_data["name"] = _event_edit_name.text.strip_edges()
	if String(event_data.get("name", "")) == "":
		event_data["name"] = "Event " + str(_editing_event_index + 1)
	event_data["regions"] = _parse_regions_csv(_event_regions_edit.text)
	event_data["turn_start"] = start_turn
	event_data["turn_end"] = end_turn
	event_data["player_id"] = _event_player_option.selected + 1
	event_data["message"] = _event_message_text.text.strip_edges()
	event_data["composition"] = composition
	_events[_editing_event_index] = event_data
	_refresh_events_list()
	_on_event_back_pressed()

func _regions_to_csv(regions: Variant) -> String:
	if not (regions is Array):
		return ""
	var values: Array = regions as Array
	var parts: Array[String] = []
	for value in values:
		parts.append(str(int(value)))
	return ",".join(parts)

func is_event_region_select_mode_active() -> bool:
	return _event_region_select_mode

func cancel_event_region_selection_mode() -> bool:
	if not _event_region_select_mode:
		return false
	_set_event_region_select_mode(false)
	return true

func try_handle_event_region_click(region_id: int) -> bool:
	if not _event_region_select_mode:
		return false
	if not _event_editor_view.visible or _editing_event_index < 0:
		return false
	var ids: Array[int] = _parse_event_region_ids_for_selection(_event_regions_edit.text)
	var existing_index: int = ids.find(region_id)
	if existing_index == -1:
		ids.append(region_id)
	else:
		ids.remove_at(existing_index)
	_event_regions_edit.text = _regions_to_csv(ids)
	_refresh_event_region_highlights_from_editor()
	return true

func _on_event_regions_select_button_pressed() -> void:
	if _event_regions_select_button.disabled:
		return
	_set_event_region_select_mode(not _event_region_select_mode)
	if _event_region_select_mode:
		_refresh_event_region_highlights_from_editor()

func _on_event_regions_text_changed(_new_text: String) -> void:
	if not _event_editor_view.visible or _editing_event_index < 0:
		return
	_refresh_event_region_highlights_from_editor()

func _set_event_region_select_mode(enabled: bool) -> void:
	_event_region_select_mode = enabled
	_event_regions_select_button.button_pressed = enabled

func _parse_event_region_ids_for_selection(value: String) -> Array[int]:
	var ids: Array[int] = []
	var seen: Dictionary = {}
	var chunks: PackedStringArray = value.split(",", false)
	for raw in chunks:
		var trimmed: String = raw.strip_edges()
		if trimmed == "":
			continue
		var region_id: int = int(trimmed)
		if region_id <= 0:
			continue
		if seen.has(region_id):
			continue
		seen[region_id] = true
		ids.append(region_id)
	return ids

func _refresh_event_region_highlights_from_editor() -> void:
	var visual_manager: VisualManager = _get_visual_manager_for_event_editor()
	if not _event_editor_view.visible or _editing_event_index < 0:
		visual_manager.clear_move_region_highlights()
		_event_highlight_region_ids.clear()
		return
	var ids: Array[int] = _parse_event_region_ids_for_selection(_event_regions_edit.text)
	var highlight_ids: Array = []
	for region_id in ids:
		highlight_ids.append(region_id)
	if highlight_ids.is_empty():
		visual_manager.clear_move_region_highlights()
		_event_highlight_region_ids.clear()
		return
	visual_manager.animate_move_region_highlights(highlight_ids)
	_event_highlight_region_ids = ids.duplicate()

func _clear_event_region_highlights() -> void:
	var visual_manager: VisualManager = _get_visual_manager_for_event_editor()
	visual_manager.clear_move_region_highlights()
	_event_highlight_region_ids.clear()

func _get_visual_manager_for_event_editor() -> VisualManager:
	var game_manager: GameManager = get_node("../../GameManager") as GameManager
	return game_manager.get_visual_manager()

func _parse_regions_csv(value: String) -> Array[int]:
	var result: Array[int] = []
	var chunks: PackedStringArray = value.split(",", false)
	for raw in chunks:
		var trimmed: String = raw.strip_edges()
		if trimmed == "":
			continue
		var region_id: int = int(trimmed)
		if region_id < 0:
			continue
		result.append(region_id)
	if result.is_empty():
		result.append(0)
	return result

func _load_events_from_scenario(data: Dictionary) -> void:
	_events.clear()
	if not data.has("events"):
		_refresh_events_list()
		return
	var loaded_events: Variant = data.get("events", [])
	if not (loaded_events is Array):
		_refresh_events_list()
		return
	for raw_event in loaded_events:
		if not (raw_event is Dictionary):
			continue
		var event_data: Dictionary = _build_default_event("Event " + str(_events.size() + 1))
		event_data["name"] = String(raw_event.get("name", event_data["name"]))
		event_data["regions"] = _parse_regions_csv(_regions_to_csv(raw_event.get("regions", [])))
		var start_turn: int = maxi(1, int(raw_event.get("turn_start", 1)))
		var end_turn: int = maxi(1, int(raw_event.get("turn_end", start_turn)))
		if end_turn < start_turn:
			var tmp: int = start_turn
			start_turn = end_turn
			end_turn = tmp
		event_data["turn_start"] = start_turn
		event_data["turn_end"] = end_turn
		event_data["player_id"] = maxi(1, mini(6, int(raw_event.get("player_id", 1))))
		event_data["message"] = String(raw_event.get("message", ""))
		var source_comp: Dictionary = raw_event.get("composition", {})
		var composition: Dictionary = {}
		for unit_type in SoldierTypeEnum.get_all_types():
			var unit_name: String = SoldierTypeEnum.type_to_string(unit_type)
			composition[unit_name] = maxi(0, int(source_comp.get(unit_name, 0)))
		event_data["composition"] = composition
		_events.append(event_data)
	_refresh_events_list()

func _build_events_for_save() -> Array:
	var output: Array = []
	for event_data in _events:
		output.append(event_data.duplicate(true))
	return output

func _update_player_settings_ui() -> void:
	"""Update the player settings UI to reflect current player_settings array"""
	var rows = _player_settings_container.get_children()
	for i in range(min(rows.size(), player_settings.size())):
		var row = rows[i]
		var control_type = player_settings[i].control_type
		
		# Find and press the appropriate button
		for child in row.get_children():
			if child is Button and child.toggle_mode:
				if child.text == control_type:
					child.button_pressed = true
				else:
					child.button_pressed = false

func _initialize_player_resources() -> void:
	player_resources = _build_default_player_resources_entries()
	_difficulty_player_resources_overrides.clear()
	_difficulty_army_compositions_overrides.clear()
	_difficulty_garrison_compositions_overrides.clear()
	_difficulty_event_compositions_overrides.clear()
	_current_resource_player_index = 0
	_populate_player_resource_selector()
	_show_player_resources_for_index(_current_resource_player_index)

func _build_default_player_resource_entry(player_id: int) -> Dictionary:
	var resource_values: Dictionary = {}
	for rt in ResourcesEnum.get_all_types():
		var resource_name := ResourcesEnum.type_to_string(rt)
		resource_values[resource_name] = GameParameters.get_starting_resource_amount(rt)
	return {
		"player_id": player_id,
		"resources": resource_values
	}

func _populate_player_resource_selector() -> void:
	_player_resource_selector.clear()
	for entry in player_resources:
		var player_id := int(entry.get("player_id", 1))
		_player_resource_selector.add_item("Player " + str(player_id))
	_player_resource_selector.select(_current_resource_player_index)

func _show_player_resources_for_index(index: int) -> void:
	if index < 0:
		return
	var effective_entries: Array = _get_effective_player_resources_entries()
	if index >= effective_entries.size():
		return
	_is_updating_player_resources_ui = true
	var entry: Dictionary = effective_entries[index]
	var resources: Dictionary = entry.get("resources", {})
	for rt in ResourcesEnum.get_all_types():
		var field := _player_resource_fields[rt] as LineEdit
		var key: String = ResourcesEnum.type_to_string(rt)
		var default_value: int = GameParameters.get_starting_resource_amount(rt)
		field.text = str(maxi(0, int(resources.get(key, default_value))))
	_is_updating_player_resources_ui = false

func _on_player_resource_selected(index: int) -> void:
	_current_resource_player_index = index
	_show_player_resources_for_index(index)

func _on_player_resource_value_submitted(text: String, resource_type: ResourcesEnum.Type) -> void:
	_commit_player_resource_value(resource_type, text)

func _on_player_resource_focus_exited(resource_type: ResourcesEnum.Type) -> void:
	var field := _player_resource_fields[resource_type] as LineEdit
	_commit_player_resource_value(resource_type, field.text)

func _commit_player_resource_value(resource_type: ResourcesEnum.Type, value_text: String) -> void:
	if _is_updating_player_resources_ui:
		return
	var sanitized_text: String = value_text.strip_edges()
	if sanitized_text == "":
		sanitized_text = "0"
	var amount: int = sanitized_text.to_int()
	if amount < 0:
		amount = 0
	var key: String = ResourcesEnum.type_to_string(resource_type)
	var target_entries: Array = player_resources
	if _edit_difficulty_target != "all":
		target_entries = _ensure_edit_target_player_resources_override()
	var entry: Dictionary = target_entries[_current_resource_player_index]
	var resources: Dictionary = entry.get("resources", {})
	resources[key] = amount
	entry["resources"] = resources
	target_entries[_current_resource_player_index] = entry
	if _edit_difficulty_target == "all":
		player_resources = target_entries
	else:
		_difficulty_player_resources_overrides[_edit_difficulty_target] = target_entries
	_is_updating_player_resources_ui = true
	var field := _player_resource_fields[resource_type] as LineEdit
	field.text = str(amount)
	_is_updating_player_resources_ui = false

func _apply_loaded_player_resources(resources_data: Array) -> void:
	player_resources = _sanitize_player_resources_entries(resources_data, false)
	_current_resource_player_index = clamp(_current_resource_player_index, 0, player_resources.size() - 1)
	_populate_player_resource_selector()
	_player_resource_selector.select(_current_resource_player_index)
	_show_player_resources_for_index(_current_resource_player_index)

func _populate_types() -> void:
	_option.clear()
	# Land types from RegionTypeEnum
	_option.add_item("Grassland")
	_option.add_item("Hills")
	_option.add_item("Forest Hills")
	_option.add_item("Forest")
	_option.add_item("Mountains")
	# Ocean as extra
	_option.add_item("Ocean")

func update_from_region(region: Region) -> void:
	_set_event_region_select_mode(false)
	_clear_event_region_highlights()
	_current_region_id = region.get_region_id()
	_id_value.text = str(_current_region_id)
	_name_edit.text = region.get_region_name()
	_current_region_node = region
	if region.is_ocean_region():
		_select_text("Ocean")
		return
	var disp := RegionTypeEnum.type_to_display_string(region.get_region_type())
	_select_text(disp)
	# Level
	var level_disp := RegionLevelEnum.level_to_string(region.get_region_level())
	_select_level(level_disp)
	# Castle
	var cast_disp := CastleTypeEnum.type_to_string(region.get_castle_type())
	_select_castle(cast_disp)
	# Resources
	for rt in _resource_edits.keys():
		var e: LineEdit = _resource_edits[rt]
		e.text = str(region.get_base_resource_amount(rt))
	# Ore
	_ore_check.button_pressed = not region.get_discovered_ores().is_empty()
	_ore_guarantee_attempt_edit.text = str(region.get_ore_guaranteed_discovery_attempt())
	if region.get_ore_guaranteed_discovery_attempt() <= 0:
		_ore_guarantee_type_option.select(0)
	else:
		var ore_type_name: String = ResourcesEnum.type_to_string(region.get_ore_guaranteed_discovery_type())
		for i in range(_ore_guarantee_type_option.item_count):
			var item_text: String = _ore_guarantee_type_option.get_item_text(i)
			if item_text.to_lower() == ore_type_name.to_lower():
				_ore_guarantee_type_option.select(i)
				break
	# Population
	_population_edit.text = str(region.get_population())
	# Ownership
	_select_ownership(region.get_region_owner())
	# Army button state (single-army assumption)
	var has_army: bool = _get_first_army_from_region(region) != null
	_has_army_cached = has_army
	var owner_id: int = region.get_region_owner()
	var can_edit_army_presence: bool = _edit_difficulty_target == "all"
	if owner_id <= 0:
		_army_toggle_button.visible = false
		_army_toggle_button.disabled = true
	else:
		_army_toggle_button.visible = true
		_army_toggle_button.text = "Remove Army" if has_army else "Add Army"
		_army_toggle_button.disabled = not can_edit_army_presence
	# Enable Edit Army only if an army exists to edit
	_edit_army_button.disabled = not has_army
	# Default to Region tab when a region is selected
	_tab_container.current_tab = 2  # Region tab
	# Make sure army panels are in default state
	_army_default_content.visible = true
	_army_edit_panel.visible = false
	# Hide garrison edit panel by default
	_garrison_edit_panel.visible = false
	# Ensure default Region tab content is visible by default
	_set_region_default_visible(true)

func commit_pending_region_edits() -> void:
	if _current_region_id < 0:
		return
	_on_name_changed(_name_edit.text)
	for rt in _resource_edits.keys():
		var edit: LineEdit = _resource_edits[rt] as LineEdit
		_on_resource_changed(edit.text, rt)
	_on_population_changed(_population_edit.text)
	_on_ore_guarantee_attempt_changed(_ore_guarantee_attempt_edit.text)

func _set_region_default_visible(visible: bool) -> void:
	for n in _region_default_nodes:
		n.visible = visible

func _select_text(txt: String) -> void:
	for i in range(_option.item_count):
		if _option.get_item_text(i) == txt:
			_option.select(i)
			return

func _populate_levels() -> void:
	_level_option.clear()
	for lv in RegionLevelEnum.get_all_levels():
		_level_option.add_item(RegionLevelEnum.level_to_string(lv))

func _select_level(txt: String) -> void:
	for i in range(_level_option.item_count):
		if _level_option.get_item_text(i) == txt:
			_level_option.select(i)
			return

func _populate_castles() -> void:
	_castle_option.clear()
	_castle_option.add_item("None")
	_castle_option.add_item("Outpost")
	_castle_option.add_item("Keep")
	_castle_option.add_item("Castle")
	_castle_option.add_item("Stronghold")

func _populate_ore_guarantee_types() -> void:
	_ore_guarantee_type_option.clear()
	_ore_guarantee_type_option.add_item("None")
	_ore_guarantee_type_option.add_item("Iron")
	_ore_guarantee_type_option.add_item("Gold")
	_ore_guarantee_type_option.select(0)

func _populate_ownership() -> void:
	_ownership_option.clear()
	_ownership_option.add_item("Neutral")
	for i in range(1, 7):
		_ownership_option.add_item("Player " + str(i))

func _select_castle(txt: String) -> void:
	for i in range(_castle_option.item_count):
		if _castle_option.get_item_text(i) == txt:
			_castle_option.select(i)
			return

func _select_ownership(owner_id: int) -> void:
	var index := 0
	if owner_id > 0:
		index = owner_id
	if index >= 0 and index < _ownership_option.item_count:
		_ownership_option.select(index)

func _on_type_selected(index: int) -> void:
	if _current_region_id < 0:
		return
	var sel := _option.get_item_text(index)
	region_type_changed.emit(_current_region_id, sel)

func _on_level_selected(index: int) -> void:
	var sel := _level_option.get_item_text(index)
	emit_signal("region_data_changed", _current_region_id, "LEVEL:" + sel)

func _on_castle_selected(index: int) -> void:
	var sel := _castle_option.get_item_text(index)
	emit_signal("region_data_changed", _current_region_id, "CASTLE:" + sel)

func _on_name_changed(text: String) -> void:
	emit_signal("region_data_changed", _current_region_id, "NAME:" + text)

func _on_name_focus_exited() -> void:
	_on_name_changed(_name_edit.text)

func _on_resource_changed(text: String, rt: ResourcesEnum.Type) -> void:
	var value: int = int(text)
	if _current_region_node.get_base_resource_amount(rt) == value:
		return
	emit_signal("region_data_changed", _current_region_id, "RES:" + str(value) + ":" + str(rt))

func _on_resource_focus_exited(rt: ResourcesEnum.Type) -> void:
	var edit: LineEdit = _resource_edits[rt] as LineEdit
	_on_resource_changed(edit.text, rt)

func _on_ore_toggled(pressed: bool) -> void:
	emit_signal("region_data_changed", _current_region_id, "ORE:" + ("1" if pressed else "0"))

func _on_ore_guarantee_attempt_changed(text: String) -> void:
	var attempt: int = maxi(0, int(text))
	var selected_type: String = _ore_guarantee_type_option.get_item_text(_ore_guarantee_type_option.selected)
	if selected_type == "None":
		attempt = 0
		_ore_guarantee_attempt_edit.text = "0"
	emit_signal("region_data_changed", _current_region_id, "ORECFG_ATTEMPT:" + str(attempt))

func _on_ore_guarantee_attempt_focus_exited() -> void:
	_on_ore_guarantee_attempt_changed(_ore_guarantee_attempt_edit.text)

func _on_ore_guarantee_type_selected(index: int) -> void:
	var ore_type: String = _ore_guarantee_type_option.get_item_text(index)
	if ore_type == "None":
		_ore_guarantee_attempt_edit.text = "0"
	emit_signal("region_data_changed", _current_region_id, "ORECFG_TYPE:" + ore_type)

func _on_population_changed(text: String) -> void:
	emit_signal("region_data_changed", _current_region_id, "POP:" + str(int(text)))

func _on_population_focus_exited() -> void:
	_on_population_changed(_population_edit.text)

func _on_ownership_selected(index: int) -> void:
	if _current_region_id < 0:
		return
	# index 0 = Neutral (owner 0), index 1..6 = Player 1..6
	var owner_id = index  # Neutral maps to 0
	emit_signal("region_data_changed", _current_region_id, "OWNER:" + str(owner_id))

func _on_army_toggle_pressed() -> void:
	if _current_region_id < 0:
		return
	if _edit_difficulty_target != "all":
		return
	# Toggle based on last-known state
	var action := "ARMY_REMOVE" if _has_army_cached else "ARMY_ADD"
	emit_signal("region_data_changed", _current_region_id, action)
	# Optimistically flip cached state and button label
	_has_army_cached = not _has_army_cached
	_army_toggle_button.text = "Remove Army" if _has_army_cached else "Add Army"

func _on_edit_army_pressed() -> void:
	_populate_army_panel()
	# Switch to Army tab
	_tab_container.current_tab = 3  # Army tab
	# Show army edit panel, hide default content
	_army_default_content.visible = false
	_army_edit_panel.visible = true

func _on_close_army_pressed() -> void:
	var data: Dictionary = {}
	for t in _unit_edits.keys():
		var e: LineEdit = _unit_edits[t]
		data[t] = int(e.text)
	if _edit_difficulty_target == "all":
		army_edit_saved.emit(_current_region_id, data)
	else:
		_save_army_override_for_current_region()
	# Show default army content, hide edit panel
	_army_edit_panel.visible = false
	_army_default_content.visible = true

func _on_edit_garrison_pressed() -> void:
	# Populate garrison panel with current garrison counts
	var garrison_composition: Dictionary = _get_effective_garrison_composition_for_region(_current_region_node)
	_apply_named_composition_to_edits(_garrison_unit_edits, garrison_composition)
	# Show panel
	_garrison_edit_panel.visible = true
	_set_region_default_visible(false)

func _on_close_garrison_pressed() -> void:
	if _edit_difficulty_target == "all":
		# Save garrison edits to region and mark as customized
		var g = _current_region_node.get_garrison()
		for t in _garrison_unit_edits.keys():
			var e: LineEdit = _garrison_unit_edits[t]
			g.set_soldier_count(t, int(e.text))
		_garrison_customized[_current_region_id] = true
	else:
		_save_garrison_override_for_current_region()
	_garrison_edit_panel.visible = false
	_set_region_default_visible(true)

func _on_save_scenario_pressed() -> void:
	commit_pending_region_edits()
	var mg: MapGenerator = get_node("../../Map") as MapGenerator
	var map_editor: MapEditor = get_node("../../MapEditor") as MapEditor
	var regions_node: Node = mg.get_node("Regions")
	var regions_data: Array = []
	var armies_data: Array = []
	for child in regions_node.get_children():
		if child is Region:
			var region := child as Region
			if region.is_ocean_region():
				continue
			if region.get_region_type() == RegionTypeEnum.Type.MOUNTAINS:
				continue
			regions_data.append(_serialize_region(region))
			for sub in region.get_children():
				if sub is Army:
					armies_data.append(_serialize_army(sub as Army, region.get_region_id()))
	var scenario_name: String = _resolve_scenario_save_name()
	var translation_keys: Dictionary = map_editor.ensure_scenario_translation_keys(scenario_name)
	var intro_key: String = String(translation_keys.get("intro_message", scenario_name + "_intro"))
	var description_key: String = String(translation_keys.get("description", scenario_name + "_description"))
	var objectives_key: String = String(translation_keys.get("objectives", scenario_name + "_objectives"))
	var scenario_type: String = _get_selected_scenario_type()
	var skip_intro: bool = _resolve_skip_intro_for_save(scenario_name)
	var scenario := {
		"map_file": mg.data_file_path,
		"regions": regions_data,
		"armies": armies_data,
		"intro_message": intro_key,
		"skip_intro": skip_intro,
		"description": description_key,
		"objectives": objectives_key,
		"scenario_type": scenario_type,
		"player_settings": player_settings,
		"player_resources": player_resources,
		"trade_disabled": _scenario_trade_disabled_check.button_pressed,
		"difficulty": _get_selected_scenario_difficulty(),
		"victory_conditions": _build_victory_conditions_for_save(),
		"events": _build_events_for_save()
	}
	var difficulty_overrides: Dictionary = _build_difficulty_overrides_for_save()
	if not difficulty_overrides.is_empty():
		scenario["difficulty_overrides"] = difficulty_overrides
	if scenario_type == "campaign":
		scenario["mission_number"] = _mission_number_option.selected + 1
	_write_scenario(scenario, scenario_name)

func _resolve_scenario_save_name() -> String:
	var name: String = _scenario_name_edit.text.strip_edges()
	if name == "":
		return "last_saved_scenario"
	return name

func _resolve_skip_intro_for_save(scenario_name: String) -> bool:
	var scenario_path: String = "res://scenarios/" + scenario_name + ".json"
	if not FileAccess.file_exists(scenario_path):
		return false
	var scenario_file: FileAccess = FileAccess.open(scenario_path, FileAccess.READ)
	if scenario_file == null:
		return false
	var scenario_json_text: String = scenario_file.get_as_text()
	scenario_file.close()
	var scenario_json: JSON = JSON.new()
	if scenario_json.parse(scenario_json_text) != OK:
		return false
	var parsed_data: Variant = scenario_json.data
	if not (parsed_data is Dictionary):
		return false
	var existing_scenario: Dictionary = parsed_data
	return bool(existing_scenario.get("skip_intro", false))

func _serialize_region(region: Region) -> Dictionary:
	var data: Dictionary = {}
	data["id"] = region.get_region_id()
	# Include name only if non-empty (avoid empty names for oceans)
	var nm := region.get_region_name().strip_edges()
	if nm != "":
		data["name"] = nm
	data["biome"] = region.get_biome()
	data["ocean"] = region.is_ocean_region()
	data["type_display"] = region.get_region_type_display_string()
	data["level"] = RegionLevelEnum.level_to_string(region.get_region_level())
	data["castle_type"] = CastleTypeEnum.type_to_string(region.get_castle_type())
	data["population"] = region.get_population()
	data["owner"] = region.get_region_owner()
	# Optional garrison: include if present (total > 0), or if customized in editor
	var include_garrison := _garrison_customized.has(region.get_region_id())
	if not include_garrison:
		include_garrison = region.get_garrison().get_total_soldiers() > 0
	if include_garrison:
		var gcomp: Dictionary = {}
		for t in SoldierTypeEnum.get_all_types():
			var tname = SoldierTypeEnum.type_to_string(t)
			gcomp[tname] = region.get_garrison().get_soldier_count(t)
		data["garrison"] = gcomp
	var res: Dictionary = {}
	for rt in ResourcesEnum.get_all_types():
		var rt_name = ResourcesEnum.type_to_string(rt)
		res[rt_name] = region.get_base_resource_amount(rt)
	data["resources"] = res
	var ores: Array = []
	for ore in region.get_discovered_ores():
		ores.append(ResourcesEnum.type_to_string(ore))
	data["discovered_ores"] = ores
	var guaranteed_attempt: int = region.get_ore_guaranteed_discovery_attempt()
	if guaranteed_attempt > 0:
		data["ore_guaranteed_discovery_attempt"] = guaranteed_attempt
		data["ore_guaranteed_discovery_type"] = ResourcesEnum.type_to_string(region.get_ore_guaranteed_discovery_type())
	return data

func _serialize_army(army: Army, region_id: int) -> Dictionary:
	var data: Dictionary = {}
	data["region_id"] = region_id
	data["player_id"] = army.get_player_id()
	data["name"] = army.name
	var comp: Dictionary = {}
	for t in SoldierTypeEnum.get_all_types():
		var tname = SoldierTypeEnum.type_to_string(t)
		comp[tname] = army.get_soldier_count(t)
	data["composition"] = comp
	return data


func _write_scenario(scenario: Dictionary, scenario_name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://scenarios")
	var filename: String = scenario_name + ".json"
	var path := "res://scenarios/" + filename
	var file := FileAccess.open(path, FileAccess.WRITE)
	var json_text := JSON.stringify(scenario, "\t")
	file.store_string(json_text)
	file.close()
	DebugLogger.log("MapEditorPanel", "Scenario saved to " + path)

func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/editor_start.tscn")

func _on_save_map_pressed() -> void:
	var mg: MapGenerator = get_node("../../Map") as MapGenerator
	if not mg or not mg.data_file_path:
		DebugLogger.log("MapEditorPanel", "No map data file to save")
		return
	var map_path := mg._resolve_mapdata_path(mg.data_file_path)
	
	# Load the original map data
	var file := FileAccess.open(map_path, FileAccess.READ)
	if not file:
		DebugLogger.log("MapEditorPanel", "Failed to open map file: " + map_path)
		return
	
	var json_text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		DebugLogger.log("MapEditorPanel", "Failed to parse map JSON")
		return
	
	var data: Dictionary = json.data
	if not data.has("regions"):
		DebugLogger.log("MapEditorPanel", "Map data has no regions")
		return
	
	# Update region types in the data
	var regions_node: Node = mg.get_node("Regions")
	var updated_count := 0
	
	for region_data in data["regions"]:
		var region_id: int = region_data["id"]
		# Find the corresponding Region node
		for child in regions_node.get_children():
			if child is Region:
				var region := child as Region
				if region.get_region_id() == region_id:
					# Update the region type/biome in the data
					if region.is_ocean_region():
						region_data["biome"] = "ocean"
						region_data["ocean"] = true
					else:
						region_data["biome"] = region.get_biome()
						region_data["type"] = region.get_region_type()
						region_data["ocean"] = false
					updated_count += 1
					break
	
	# Save the updated data back to the file
	var save_file := FileAccess.open(map_path, FileAccess.WRITE)
	if not save_file:
		DebugLogger.log("MapEditorPanel", "Failed to open map file for writing: " + map_path)
		return
	
	var updated_json := JSON.stringify(data, "\t")
	save_file.store_string(updated_json)
	save_file.close()
	
	DebugLogger.log("MapEditorPanel", "Map saved to " + map_path + " (" + str(updated_count) + " regions updated)")

func _populate_army_panel() -> void:
	_region_id_value_army.text = str(_current_region_id)
	_region_name_value_army.text = _current_region_node.get_region_name()
	var army_found: Army = _get_first_army_from_region(_current_region_node)
	
	# Check if army was found before trying to access it
	if army_found == null:
		DebugLogger.log("MapEditorPanel", "No army found in region to edit")
		_army_name_value.text = "-"
		# Clear all unit edit fields
		for t in _unit_edits.keys():
			(_unit_edits[t] as LineEdit).text = "0"
		return
	
	_army_name_value.text = army_found.name
	var army_composition: Dictionary = _get_effective_army_composition_for_region(_current_region_node)
	_apply_named_composition_to_edits(_unit_edits, army_composition)

func _initialize_player_settings() -> void:
	"""Initialize the player settings UI with 6 player rows"""
	# Initialize player settings array with default values
	player_settings.clear()
	for i in range(1, 7):  # Players 1-6
		player_settings.append({
			"player_id": i,
			"control_type": "Off" if i > 2 else ("Player" if i == 1 else "Computer")
		})
	
	# Create UI rows for each player
	for i in range(6):
		var player_num = i + 1
		var player_color = GameParameters.get_player_color(player_num)
		
		# Create horizontal container for the row
		var row_container = HBoxContainer.new()
		row_container.custom_minimum_size.y = 40
		
		# Create player label with color
		var player_label = Label.new()
		player_label.text = "Player " + str(player_num)
		player_label.custom_minimum_size.x = 80
		player_label.modulate = player_color
		player_label.add_theme_font_size_override("font_size", 16)
		player_label.add_theme_color_override("font_outline_color", Color.BLACK)
		player_label.add_theme_constant_override("outline_size", 2)
		row_container.add_child(player_label)
		
		# Add spacer
		var spacer = Control.new()
		spacer.custom_minimum_size.x = 10
		row_container.add_child(spacer)
		
		# Create button group for this player
		var button_group = ButtonGroup.new()
		
		# Create Player button
		var player_button = Button.new()
		player_button.text = "Player"
		player_button.custom_minimum_size.x = 60
		player_button.toggle_mode = true
		player_button.button_group = button_group
		player_button.add_theme_font_size_override("font_size", 14)
		player_button.button_pressed = (player_settings[i].control_type == "Player")
		player_button.toggled.connect(_on_player_control_changed.bind(player_num, "Player"))
		row_container.add_child(player_button)
		
		# Create Computer button
		var computer_button = Button.new()
		computer_button.text = "Computer"
		computer_button.custom_minimum_size.x = 80
		computer_button.toggle_mode = true
		computer_button.button_group = button_group
		computer_button.add_theme_font_size_override("font_size", 14)
		computer_button.button_pressed = (player_settings[i].control_type == "Computer")
		computer_button.toggled.connect(_on_player_control_changed.bind(player_num, "Computer"))
		row_container.add_child(computer_button)
		
		# Create Off button
		var off_button = Button.new()
		off_button.text = "Off"
		off_button.custom_minimum_size.x = 40
		off_button.toggle_mode = true
		off_button.button_group = button_group
		off_button.add_theme_font_size_override("font_size", 14)
		off_button.button_pressed = (player_settings[i].control_type == "Off")
		off_button.toggled.connect(_on_player_control_changed.bind(player_num, "Off"))
		row_container.add_child(off_button)
		
		# Add row to container
		_player_settings_container.add_child(row_container)

func _on_player_control_changed(toggled_on: bool, player_num: int, control_type: String) -> void:
	"""Handle player control type change"""
	if toggled_on:
		player_settings[player_num - 1].control_type = control_type
		DebugLogger.log("MapEditorPanel", "Player " + str(player_num) + " set to: " + control_type)
