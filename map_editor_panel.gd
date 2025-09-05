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

var _option: OptionButton
var _current_region_id: int = -1
var _name_edit: LineEdit
var _level_option: OptionButton
var _castle_option: OptionButton
var _ore_check: CheckBox
var _resource_edits: Dictionary = {}
var _id_value: Label
var _population_edit: LineEdit

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
	for rt in _resource_edits.keys():
		(_resource_edits[rt] as LineEdit).text_submitted.connect(Callable(self, "_on_resource_changed").bind(rt))
	_population_edit.text_submitted.connect(_on_population_changed)
	_ore_check.toggled.connect(_on_ore_toggled)
	_name_edit.text_submitted.connect(_on_name_changed)

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

func _select_castle(txt: String) -> void:
	for i in range(_castle_option.item_count):
		if _castle_option.get_item_text(i) == txt:
			_castle_option.select(i)
			return

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
