extends Node
class_name MapEditor

# ============================================================================
# MAP EDITOR CONTROLLER
# ============================================================================
# 
# Purpose: Map editor mode controller 
# 
# Core Responsibilities:
# - Initialize map editor mode
# - Show/hide editor panel
# - Coordinate editor mode state
# 
# Integration Points:
# - GameManager: Called from _initialize_map_editor()
# - MapEditorPanel: UI panel management
# ============================================================================

var initialized: bool = false
var map_editor_panel: Control = null
var _last_region_id: int = -1

func initialize() -> void:
	"""Initialize map editor controller"""
	if initialized:
		return
	
	DebugLogger.log("MapEditor", "Initializing map editor controller")
	
	# Get reference to map editor panel
	var ui_node = get_node("../UI")
	map_editor_panel = ui_node.get_node("MapEditorPanel")
	
	DebugLogger.log("MapEditor", "Map editor panel found and connected")
	_setup_editor_panel()
	
	initialized = true
	DebugLogger.log("MapEditor", "Map editor initialization complete")

func _setup_editor_panel() -> void:
	"""Setup map editor panel initial state"""
	# Show the panel
	map_editor_panel.visible = true
	# Connect selection changed from panel
	if map_editor_panel.has_signal("region_type_changed"):
		map_editor_panel.connect("region_type_changed", Callable(self, "_on_region_type_changed"))
	
	DebugLogger.log("MapEditor", "Map editor panel setup complete")

func is_editor_mode() -> bool:
	"""Check if currently in map editor mode"""
	return initialized

func get_editor_panel() -> Control:
	"""Get the map editor panel reference"""
	return map_editor_panel

func set_current_region(region: Region) -> void:
	_last_region_id = region.get_region_id()
	var panel := map_editor_panel as MapEditorPanel
	panel.update_from_region(region)

func _on_region_type_changed(region_id: int, selection: String) -> void:
	var gm: GameManager = get_node("../GameManager") as GameManager
	var mg: MapGenerator = get_node("../Map") as MapGenerator
	var region_container = mg.get_region_container_by_id(region_id)
	var region := region_container as Region
	if selection == "Ocean":
		region.set_ocean(true)
		mg.region_by_id[region_id]["ocean"] = true
		mg.region_by_id[region_id]["biome"] = "ocean"
		mg.refresh_region_visual(region_id)
		return
	# Land selection
	if selection.begins_with("LEVEL:"):
		var lv_str = selection.substr(6, selection.length()).strip_edges()
		var lv = RegionLevelEnum.string_to_level(lv_str)
		region.set_region_level(lv)
		return
	if selection.begins_with("CASTLE:"):
		var c_str = selection.substr(7, selection.length()).strip_edges()
		var ct = CastleTypeEnum.string_to_type(c_str)
		region.set_castle_type(ct)
		# Place or remove castle icon directly (editor mode)
		var container = mg.get_region_container_by_id(region_id)
		var existing = container.get_node_or_null("Castle")
		if existing:
			container.remove_child(existing)
			existing.queue_free()
		if ct != CastleTypeEnum.Type.NONE:
			var icon_path = CastleTypeEnum.get_icon_path(ct)
			if icon_path != "":
				var castle := Sprite2D.new()
				castle.name = "Castle"
				castle.texture = load(icon_path)
				var castle_scale := 0.12
				var map_size_scale := Utils.get_map_size_icon_scale(mg.map_size)
				castle_scale = castle_scale * mg.polygon_scale * map_size_scale
				var polygon := container.get_node("Polygon") as Polygon2D
				var center: Vector2 = polygon.get_meta("center")
				castle.position = center + Vector2(-5 * map_size_scale, -5 * map_size_scale)
				castle.scale = Vector2(castle_scale, castle_scale)
				castle.z_index = 100
				container.add_child(castle)
		return
	if selection.begins_with("NAME:"):
		var name = selection.substr(5, selection.length())
		region.set_region_name(name)
		return
	if selection.begins_with("RES:"):
		# Format: RES:<value>:<rt>
		var parts = selection.split(":")
		if parts.size() == 3:
			var value = int(parts[1])
			var rt = int(parts[2])
			region.get_resources().set_resource_amount(rt, value)
			mg.refresh_region_visual(region_id)
		return
	if selection.begins_with("POP:"):
		var value = int(selection.substr(4, selection.length()))
		region.set_population(max(0, value))
		return
	if selection.begins_with("ORE:"):
		var flag = selection.substr(4, selection.length())
		region.set_any_ore_discovered(flag == "1")
		return
	# Region type change (land)
	region.set_ocean(false)
	mg.region_by_id[region_id]["ocean"] = false
	var t := _display_to_enum(selection)
	region.set_region_type(t)
	mg.region_by_id[region_id]["biome"] = RegionTypeEnum.type_to_string(t).to_lower()
	mg.refresh_region_visual(region_id)

func _display_to_enum(txt: String) -> RegionTypeEnum.Type:
	match txt:
		"Grassland":
			return RegionTypeEnum.Type.GRASSLAND
		"Hills":
			return RegionTypeEnum.Type.HILLS
		"Forest Hills":
			return RegionTypeEnum.Type.FOREST_HILLS
		"Forest":
			return RegionTypeEnum.Type.FOREST
		"Mountains":
			return RegionTypeEnum.Type.MOUNTAINS
		_:
			return RegionTypeEnum.Type.GRASSLAND
