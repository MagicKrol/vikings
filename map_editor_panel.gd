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
signal army_edit_saved(region_id: int, data: Dictionary)

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
var _intro_message_edit: LineEdit
var _scenario_description_edit: LineEdit
var _objectives_edit: LineEdit
var _scenario_type_option: OptionButton
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
var _event_message_text: TextEdit
var _event_units_container: VBoxContainer
var _event_unit_edits: Dictionary = {}
var _events: Array[Dictionary] = []
var _editing_event_index: int = -1

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
	_intro_message_edit = get_node("Panel/TabContainer/Main/IntroMessageRow/IntroMessageEdit") as LineEdit
	_scenario_description_edit = get_node("Panel/TabContainer/Main/DescriptionRow/DescriptionEdit") as LineEdit
	_objectives_edit = get_node("Panel/TabContainer/Main/ObjectivesRow/ObjectivesEdit") as LineEdit
	_scenario_type_option = get_node("Panel/TabContainer/Main/ScenarioTypeRow/ScenarioTypeOption") as OptionButton
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
	_population_edit.text_submitted.connect(_on_population_changed)
	_ore_check.toggled.connect(_on_ore_toggled)
	_ore_guarantee_attempt_edit.text_submitted.connect(_on_ore_guarantee_attempt_changed)
	_ore_guarantee_type_option.item_selected.connect(_on_ore_guarantee_type_selected)
	_name_edit.text_submitted.connect(_on_name_changed)
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
	_event_message_text = get_node("Panel/TabContainer/Event/EventEditorView/EventMessageValue") as TextEdit
	_event_units_container = get_node("Panel/TabContainer/Event/EventEditorView/EventUnitsContainer") as VBoxContainer
	
	# Initialize player settings and resource UI
	_initialize_player_settings()
	_initialize_player_resources()
	_initialize_scenario_type_ui()
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
	_event_add_button.pressed.connect(_on_event_add_pressed)
	_event_back_button.pressed.connect(_on_event_back_pressed)
	_event_save_button.pressed.connect(_on_event_save_pressed)
	
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
	_intro_message_edit.text = String(data.get("intro_message", ""))
	_scenario_description_edit.text = String(data.get("description", ""))
	_objectives_edit.text = String(data.get("objectives", ""))
	_set_scenario_type_from_data(String(data.get("scenario_type", "scenario")))
	var mission_number: int = maxi(1, int(data.get("mission_number", 1)))
	var mission_index: int = mini(_mission_number_option.item_count - 1, mission_number - 1)
	_mission_number_option.select(maxi(0, mission_index))
	_scenario_trade_disabled_check.button_pressed = bool(data.get("trade_disabled", false))
	_set_scenario_difficulty_from_data(String(data.get("difficulty", "all")))
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
	_event_player_option.clear()
	for i in range(1, 7):
		_event_player_option.add_item("Player " + str(i))
	_event_player_option.select(0)
	_build_event_unit_inputs()
	_event_list_view.visible = true
	_event_editor_view.visible = false
	_events.clear()
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
		delete_button.pressed.connect(_on_event_delete_pressed.bind(i))
		row.add_child(delete_button)
		_event_list_container.add_child(row)

func _on_event_edit_pressed(index: int) -> void:
	if index < 0 or index >= _events.size():
		return
	_editing_event_index = index
	_show_event_editor(_events[index])

func _on_event_delete_pressed(index: int) -> void:
	if index < 0 or index >= _events.size():
		return
	_events.remove_at(index)
	if _editing_event_index == index:
		_editing_event_index = -1
		_event_list_view.visible = true
		_event_editor_view.visible = false
	elif _editing_event_index > index:
		_editing_event_index -= 1
	_refresh_events_list()

func _show_event_editor(event_data: Dictionary) -> void:
	_event_list_view.visible = false
	_event_editor_view.visible = true
	_event_edit_name.text = String(event_data.get("name", ""))
	_event_regions_edit.text = _regions_to_csv(event_data.get("regions", []))
	_event_turn_start_edit.text = str(int(event_data.get("turn_start", 1)))
	_event_turn_end_edit.text = str(int(event_data.get("turn_end", 1)))
	var player_id: int = maxi(1, mini(6, int(event_data.get("player_id", 1))))
	_event_player_option.select(player_id - 1)
	_event_message_text.text = String(event_data.get("message", ""))
	var composition: Dictionary = event_data.get("composition", {})
	for unit_type in _event_unit_edits.keys():
		var unit_name: String = SoldierTypeEnum.type_to_string(unit_type)
		var edit: LineEdit = _event_unit_edits[unit_type] as LineEdit
		edit.text = str(maxi(0, int(composition.get(unit_name, 0))))

func _on_event_back_pressed() -> void:
	_editing_event_index = -1
	_event_list_view.visible = true
	_event_editor_view.visible = false

func _on_event_save_pressed() -> void:
	if _editing_event_index < 0 or _editing_event_index >= _events.size():
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
	var composition: Dictionary = {}
	for unit_type in _event_unit_edits.keys():
		var unit_name: String = SoldierTypeEnum.type_to_string(unit_type)
		var value: int = maxi(0, int((_event_unit_edits[unit_type] as LineEdit).text))
		composition[unit_name] = value
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
	player_resources.clear()
	for i in range(6):
		player_resources.append(_build_default_player_resource_entry(i + 1))
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
	_is_updating_player_resources_ui = true
	var entry: Dictionary = player_resources[index]
	var resources: Dictionary = entry.get("resources", {})
	for rt in _player_resource_fields.keys():
		var field := _player_resource_fields[rt] as LineEdit
		var key := ResourcesEnum.type_to_string(rt)
		if not resources.has(key):
			resources[key] = GameParameters.get_starting_resource_amount(rt)
		field.text = str(int(resources[key]))
	entry["resources"] = resources
	player_resources[index] = entry
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
	var entry: Dictionary = player_resources[_current_resource_player_index]
	var resources: Dictionary = entry.get("resources", {})
	var sanitized_text := value_text.strip_edges()
	if sanitized_text == "":
		sanitized_text = "0"
	var amount := sanitized_text.to_int()
	if amount < 0:
		amount = 0
	var key := ResourcesEnum.type_to_string(resource_type)
	resources[key] = amount
	entry["resources"] = resources
	player_resources[_current_resource_player_index] = entry
	_is_updating_player_resources_ui = true
	var field := _player_resource_fields[resource_type] as LineEdit
	field.text = str(amount)
	_is_updating_player_resources_ui = false

func _apply_loaded_player_resources(resources_data: Array) -> void:
	var sanitized: Array = []
	for i in range(6):
		sanitized.append(_build_default_player_resource_entry(i + 1))
	for entry in resources_data:
		if entry is Dictionary:
			var player_id := int(entry.get("player_id", 0))
			if player_id >= 1 and player_id <= sanitized.size():
				var target: Dictionary = sanitized[player_id - 1]
				var target_resources: Dictionary = target.get("resources", {})
				if entry.has("resources") and entry["resources"] is Dictionary:
					var source_resources: Dictionary = entry["resources"] as Dictionary
					for rt in ResourcesEnum.get_all_types():
						var key := ResourcesEnum.type_to_string(rt)
						if source_resources.has(key):
							target_resources[key] = int(source_resources.get(key))
					target["resources"] = target_resources
					sanitized[player_id - 1] = target
	player_resources = sanitized
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
		e.text = str(region.get_resource_amount(rt))
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
	var has_army := false
	for child in region.get_children():
		if child is Army:
			has_army = true
			break
	_has_army_cached = has_army
	var owner_id = region.get_region_owner()
	if owner_id <= 0:
		_army_toggle_button.visible = false
	else:
		_army_toggle_button.visible = true
		_army_toggle_button.text = "Remove Army" if has_army else "Add Army"
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
	emit_signal("region_type_changed", _current_region_id, "LEVEL:" + sel)

func _on_castle_selected(index: int) -> void:
	var sel := _castle_option.get_item_text(index)
	emit_signal("region_type_changed", _current_region_id, "CASTLE:" + sel)

func _on_name_changed(text: String) -> void:
	emit_signal("region_type_changed", _current_region_id, "NAME:" + text)

func _on_resource_changed(text: String, rt: ResourcesEnum.Type) -> void:
	emit_signal("region_type_changed", _current_region_id, "RES:" + str(int(text)) + ":" + str(rt))

func _on_ore_toggled(pressed: bool) -> void:
	emit_signal("region_type_changed", _current_region_id, "ORE:" + ("1" if pressed else "0"))

func _on_ore_guarantee_attempt_changed(text: String) -> void:
	var attempt: int = maxi(0, int(text))
	var selected_type: String = _ore_guarantee_type_option.get_item_text(_ore_guarantee_type_option.selected)
	if selected_type == "None":
		attempt = 0
		_ore_guarantee_attempt_edit.text = "0"
	emit_signal("region_type_changed", _current_region_id, "ORECFG_ATTEMPT:" + str(attempt))

func _on_ore_guarantee_type_selected(index: int) -> void:
	var ore_type: String = _ore_guarantee_type_option.get_item_text(index)
	if ore_type == "None":
		_ore_guarantee_attempt_edit.text = "0"
	emit_signal("region_type_changed", _current_region_id, "ORECFG_TYPE:" + ore_type)

func _on_population_changed(text: String) -> void:
	emit_signal("region_type_changed", _current_region_id, "POP:" + str(int(text)))

func _on_ownership_selected(index: int) -> void:
	if _current_region_id < 0:
		return
	# index 0 = Neutral (owner 0), index 1..6 = Player 1..6
	var owner_id = index  # Neutral maps to 0
	emit_signal("region_type_changed", _current_region_id, "OWNER:" + str(owner_id))

func _on_army_toggle_pressed() -> void:
	if _current_region_id < 0:
		return
	# Toggle based on last-known state
	var action := "ARMY_REMOVE" if _has_army_cached else "ARMY_ADD"
	emit_signal("region_type_changed", _current_region_id, action)
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
	army_edit_saved.emit(_current_region_id, data)
	# Show default army content, hide edit panel
	_army_edit_panel.visible = false
	_army_default_content.visible = true

func _on_edit_garrison_pressed() -> void:
	# Populate garrison panel with current garrison counts
	var g := _current_region_node.get_garrison()
	for t in _garrison_unit_edits.keys():
		var count := g.get_soldier_count(t)
		(_garrison_unit_edits[t] as LineEdit).text = str(count)
	# Show panel
	_garrison_edit_panel.visible = true
	_set_region_default_visible(false)

func _on_close_garrison_pressed() -> void:
	# Save garrison edits to region and mark as customized
	var g := _current_region_node.get_garrison()
	for t in _garrison_unit_edits.keys():
		var e: LineEdit = _garrison_unit_edits[t]
		g.set_soldier_count(t, int(e.text))
	_garrison_customized[_current_region_id] = true
	_garrison_edit_panel.visible = false
	_set_region_default_visible(true)

func _on_save_scenario_pressed() -> void:
	var mg: MapGenerator = get_node("../../Map") as MapGenerator
	var regions_node: Node = mg.get_node("Regions")
	var regions_data: Array = []
	var armies_data: Array = []
	for child in regions_node.get_children():
		if child is Region:
			var region := child as Region
			regions_data.append(_serialize_region(region))
			for sub in region.get_children():
				if sub is Army:
					armies_data.append(_serialize_army(sub as Army, region.get_region_id()))
	var scenario_type: String = _get_selected_scenario_type()
	var scenario := {
		"map_file": mg.data_file_path,
		"regions": regions_data,
		"armies": armies_data,
		"intro_message": _intro_message_edit.text.strip_edges(),
		"description": _scenario_description_edit.text.strip_edges(),
		"objectives": _objectives_edit.text.strip_edges(),
		"scenario_type": scenario_type,
		"player_settings": player_settings,
		"player_resources": player_resources,
		"trade_disabled": _scenario_trade_disabled_check.button_pressed,
		"difficulty": _get_selected_scenario_difficulty(),
		"victory_conditions": _build_victory_conditions_for_save(),
		"events": _build_events_for_save()
	}
	if scenario_type == "campaign":
		scenario["mission_number"] = _mission_number_option.selected + 1
	_write_scenario(scenario)

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
		res[rt_name] = region.get_resource_amount(rt)
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


func _write_scenario(scenario: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://scenarios")
	var name := _scenario_name_edit.text.strip_edges()
	var filename := (name if name != "" else "last_saved_scenario") + ".json"
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
	var army_found: Army = null
	for child in _current_region_node.get_children():
		if child is Army:
			army_found = child as Army
			break
	
	# Check if army was found before trying to access it
	if army_found == null:
		DebugLogger.log("MapEditorPanel", "No army found in region to edit")
		_army_name_value.text = "-"
		# Clear all unit edit fields
		for t in _unit_edits.keys():
			(_unit_edits[t] as LineEdit).text = "0"
		return
	
	_army_name_value.text = army_found.name
	for t in _unit_edits.keys():
		var count = army_found.get_soldier_count(t)
		(_unit_edits[t] as LineEdit).text = str(count)

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
