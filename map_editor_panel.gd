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
var _army_panel: Panel
var _region_panel: Node
var _edit_army_button: Button
var _close_army_button: Button
var _unit_edits: Dictionary = {}
var _army_name_value: Label
var _region_id_value_army: Label
var _region_name_value_army: Label
var _current_region_node: Region
var _save_scenario_button: Button
var _scenario_select: OptionButton
var _load_scenario_button: Button
var _scenario_name_edit: LineEdit

func _ready() -> void:
	"""Initialize map editor panel"""
	DebugLogger.log("MapEditorPanel", "Map editor panel ready")
	# Get references to static nodes
	_id_value = get_node("Panel/Content/IDRow/IDValue") as Label
	_name_edit = get_node("Panel/Content/NameRow/NameEdit") as LineEdit
	_option = get_node("Panel/Content/TypeRow/TypeOption") as OptionButton
	_level_option = get_node("Panel/Content/LevelRow/LevelOption") as OptionButton
	_population_edit = get_node("Panel/Content/PopulationRow/PopulationEdit") as LineEdit
	_castle_option = get_node("Panel/Content/CastleRow/CastleOption") as OptionButton
	_ore_check = get_node("Panel/Content/OreRow/OreCheck") as CheckBox
	_ownership_option = get_node("Panel/Content/OwnershipRow/OwnershipOption") as OptionButton
	_army_toggle_button = get_node("Panel/Content/ArmyRow/ArmyToggleButton") as Button
	_region_panel = get_node("Panel")
	_army_panel = get_node("ArmyPanel") as Panel
	_edit_army_button = get_node("Panel/Content/ArmyEditRow/EditArmyButton") as Button
	_close_army_button = get_node("ArmyPanel/ArmyContent/ArmyHeaderRow/CloseArmyButton") as Button
	_army_name_value = get_node("ArmyPanel/ArmyContent/ArmyNameRow/ArmyNameValue") as Label
	_region_id_value_army = get_node("ArmyPanel/ArmyContent/RegionIDRow/RegionIDValue") as Label
	_region_name_value_army = get_node("ArmyPanel/ArmyContent/RegionNameRow/RegionNameValue") as Label
	_save_scenario_button = get_node("Panel/Content/SaveButtonRow/SaveScenarioButton") as Button
	_scenario_name_edit = get_node("Panel/Content/SaveRow/ScenarioNameEdit") as LineEdit
	_scenario_select = get_node("Panel/Content/LoadScenarioSelectRow/ScenarioSelect") as OptionButton
	_load_scenario_button = get_node("Panel/Content/LoadScenarioButtonRow/LoadScenarioButton") as Button
	_unit_edits = {
		SoldierTypeEnum.Type.PEASANTS: get_node("ArmyPanel/ArmyContent/PeasantsRow/PeasantsEdit") as LineEdit,
		SoldierTypeEnum.Type.SPEARMEN: get_node("ArmyPanel/ArmyContent/SpearmenRow/SpearmenEdit") as LineEdit,
		SoldierTypeEnum.Type.SWORDSMEN: get_node("ArmyPanel/ArmyContent/SwordsmenRow/SwordsmenEdit") as LineEdit,
		SoldierTypeEnum.Type.ARCHERS: get_node("ArmyPanel/ArmyContent/ArchersRow/ArchersEdit") as LineEdit,
		SoldierTypeEnum.Type.CROSSBOWMEN: get_node("ArmyPanel/ArmyContent/CrossbowmenRow/CrossbowmenEdit") as LineEdit,
		SoldierTypeEnum.Type.HORSEMEN: get_node("ArmyPanel/ArmyContent/HorsemenRow/HorsemenEdit") as LineEdit,
		SoldierTypeEnum.Type.KNIGHTS: get_node("ArmyPanel/ArmyContent/KnightsRow/KnightsEdit") as LineEdit,
		SoldierTypeEnum.Type.MOUNTED_KNIGHTS: get_node("ArmyPanel/ArmyContent/MountedKnightsRow/MountedKnightsEdit") as LineEdit,
		SoldierTypeEnum.Type.ROYAL_GUARD: get_node("ArmyPanel/ArmyContent/RoyalGuardRow/RoyalGuardEdit") as LineEdit
	}
	_resource_edits = {
		ResourcesEnum.Type.FOOD: get_node("Panel/Content/FoodRow/FoodEdit") as LineEdit,
		ResourcesEnum.Type.WOOD: get_node("Panel/Content/WoodRow/WoodEdit") as LineEdit,
		ResourcesEnum.Type.STONE: get_node("Panel/Content/StoneRow/StoneEdit") as LineEdit,
		ResourcesEnum.Type.IRON: get_node("Panel/Content/IronRow/IronEdit") as LineEdit,
		ResourcesEnum.Type.GOLD: get_node("Panel/Content/GoldRow/GoldEdit") as LineEdit
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
	_save_scenario_button.pressed.connect(_on_save_scenario_pressed)
	_load_scenario_button.pressed.connect(_on_load_scenario_pressed)
	_populate_scenario_list()

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
	# Ensure correct default visibility (Region panel shown by default)
	_region_panel.visible = true
	_army_panel.visible = false

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
	_region_panel.visible = false
	_army_panel.visible = true

func _on_close_army_pressed() -> void:
	var data: Dictionary = {}
	for t in _unit_edits.keys():
		var e: LineEdit = _unit_edits[t]
		data[t] = int(e.text)
	army_edit_saved.emit(_current_region_id, data)
	_army_panel.visible = false
	_region_panel.visible = true

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
	data["name"] = region.get_region_name()
	data["biome"] = region.get_biome()
	data["ocean"] = region.is_ocean_region()
	data["type_display"] = region.get_region_type_display_string()
	data["level"] = RegionLevelEnum.level_to_string(region.get_region_level())
	data["castle_type"] = CastleTypeEnum.type_to_string(region.get_castle_type())
	data["population"] = region.get_population()
	data["owner"] = region.get_region_owner()
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
	_populate_scenario_list()

func _populate_scenario_list() -> void:
	_scenario_select.clear()
	var dir := DirAccess.open("res://scenarios")
	if dir == null:
		return
	dir.list_dir_begin()
	var files: Array[String] = []
	while true:
		var f := dir.get_next()
		if f == "":
			break
		if dir.current_is_dir():
			continue
		if f.to_lower().ends_with(".json"):
			files.append(f)
	dir.list_dir_end()
	files.sort()  # stable order
	for f in files:
		_scenario_select.add_item(f)

func _on_load_scenario_pressed() -> void:
	# Placeholder: selection is available via _scenario_select.get_item_text(index)
	var i := _scenario_select.get_selected_id()
	var name := _scenario_select.get_item_text(_scenario_select.get_selected()) if _scenario_select.item_count > 0 else ""
	DebugLogger.log("MapEditorPanel", "Selected scenario: " + name)

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
