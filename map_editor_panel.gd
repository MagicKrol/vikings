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
var _tab_container: TabContainer
var _army_default_content: VBoxContainer
var _army_edit_panel: VBoxContainer
var _garrison_edit_panel: VBoxContainer
var _edit_garrison_button: Button
var _close_garrison_button: Button
var _garrison_unit_edits: Dictionary = {}
var _garrison_customized: Dictionary = {}
var _region_default_nodes: Array = []

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
	_populate_ownership()
	_ownership_option.item_selected.connect(_on_ownership_selected)
	for rt in _resource_edits.keys():
		(_resource_edits[rt] as LineEdit).text_submitted.connect(Callable(self, "_on_resource_changed").bind(rt))
	_population_edit.text_submitted.connect(_on_population_changed)
	_ore_check.toggled.connect(_on_ore_toggled)
	_name_edit.text_submitted.connect(_on_name_changed)
	_army_toggle_button.pressed.connect(_on_army_toggle_pressed)
	_edit_army_button.pressed.connect(_on_edit_army_pressed)
	_close_army_button.pressed.connect(_on_close_army_pressed)
	_edit_garrison_button.pressed.connect(_on_edit_garrison_pressed)
	_close_garrison_button.pressed.connect(_on_close_garrison_pressed)
	_save_scenario_button.pressed.connect(_on_save_scenario_pressed)
	_save_map_button.pressed.connect(_on_save_map_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	
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
			return
	# If game manager didn't report a scenario name, leave field as-is

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
	var scenario := {
		"map_file": mg.data_file_path,
		"regions": regions_data,
		"armies": armies_data
	}
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
	# Optional garrison: include only if customized in editor
	if _garrison_customized.has(region.get_region_id()):
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
	
	# Load the original map data
	var file := FileAccess.open(mg.data_file_path, FileAccess.READ)
	if not file:
		DebugLogger.log("MapEditorPanel", "Failed to open map file: " + mg.data_file_path)
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
	var save_file := FileAccess.open(mg.data_file_path, FileAccess.WRITE)
	if not save_file:
		DebugLogger.log("MapEditorPanel", "Failed to open map file for writing: " + mg.data_file_path)
		return
	
	var updated_json := JSON.stringify(data, "\t")
	save_file.store_string(updated_json)
	save_file.close()
	
	DebugLogger.log("MapEditorPanel", "Map saved to " + mg.data_file_path + " (" + str(updated_count) + " regions updated)")

func _populate_army_panel() -> void:
	_region_id_value_army.text = str(_current_region_id)
	_region_name_value_army.text = _current_region_node.get_region_name()
	var army_found: Army = null
	for child in _current_region_node.get_children():
		if child is Army:
			army_found = child as Army
			break
	_army_name_value.text = army_found.name
	for t in _unit_edits.keys():
		var count = army_found.get_soldier_count(t)
		(_unit_edits[t] as LineEdit).text = str(count)
