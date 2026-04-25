extends Node
class_name MapEditor

const HOTW_TRANSLATIONS_CSV_PATH: String = "res://translations/hotw_translations.csv"

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

func ensure_scenario_translation_keys(scenario_name: String) -> Dictionary:
	var intro_key: String = scenario_name + "_intro"
	var description_key: String = scenario_name + "_description"
	var objectives_key: String = scenario_name + "_objectives"
	var translation_rows: Array[Dictionary] = [
		{
			"key": intro_key,
			"explanation": "Scenario metadata key used for intro popup text at scenario start."
		},
		{
			"key": description_key,
			"explanation": "Scenario metadata key used for scenario description text in the main menu."
		},
		{
			"key": objectives_key,
			"explanation": "Scenario metadata key used for scenario objectives text in the main menu."
		}
	]
	_ensure_translation_rows(translation_rows)
	return {
		"intro_message": intro_key,
		"description": description_key,
		"objectives": objectives_key
	}

func _ensure_translation_rows(rows: Array[Dictionary]) -> void:
	var csv_text: String = FileAccess.get_file_as_string(HOTW_TRANSLATIONS_CSV_PATH)
	if csv_text == "":
		DebugLogger.log("MapEditor", "Could not read translation file: " + HOTW_TRANSLATIONS_CSV_PATH)
		return
	var existing_keys: Dictionary = {}
	var csv_lines: PackedStringArray = csv_text.split("\n", false)
	for line in csv_lines:
		var trimmed_line: String = line.strip_edges()
		if trimmed_line == "":
			continue
		var key: String = _extract_csv_first_column(trimmed_line)
		if key != "":
			existing_keys[key] = true
	var rows_to_append: Array[String] = []
	for row_data in rows:
		var key: String = String(row_data.get("key", ""))
		if key == "" or existing_keys.has(key):
			continue
		var explanation: String = String(row_data.get("explanation", ""))
		rows_to_append.append(_build_translation_csv_row(key, explanation))
	if rows_to_append.is_empty():
		return
	var newline: String = "\n"
	if csv_text.contains("\r\n"):
		newline = "\r\n"
	var output_text: String = csv_text
	if not output_text.ends_with("\n") and not output_text.ends_with("\r\n"):
		output_text += newline
	for row_line in rows_to_append:
		output_text += row_line + newline
	var file: FileAccess = FileAccess.open(HOTW_TRANSLATIONS_CSV_PATH, FileAccess.WRITE)
	file.store_string(output_text)
	file.close()

func _build_translation_csv_row(key: String, explanation: String) -> String:
	var escaped_key: String = _csv_escape(key)
	var escaped_explanation: String = _csv_escape(explanation)
	return ",".join([
		escaped_key,
		escaped_explanation,
		escaped_key,
		escaped_key,
		escaped_key,
		escaped_key
	])

func _csv_escape(value: String) -> String:
	var escaped_value: String = value.replace("\"", "\"\"")
	if value.contains(",") or value.contains("\"") or value.contains("\n") or value.contains("\r"):
		return "\"" + escaped_value + "\""
	return escaped_value

func _extract_csv_first_column(line: String) -> String:
	if line.begins_with("\""):
		var key: String = ""
		var index: int = 1
		while index < line.length():
			var char: String = line.substr(index, 1)
			if char == "\"":
				var next_index: int = index + 1
				if next_index < line.length() and line.substr(next_index, 1) == "\"":
					key += "\""
					index += 2
					continue
				break
			key += char
			index += 1
		return key
	return line.get_slice(",", 0).strip_edges()

func _apply_region_data_updates(mg: MapGenerator, region_id: int, updates: Dictionary) -> void:
	var region_data = mg.region_by_id.get(region_id, null)
	if region_data:
		for key in updates.keys():
			region_data[key] = updates[key]
	for i in range(mg.regions.size()):
		var entry: Dictionary = mg.regions[i]
		if int(entry.get("id", -1)) == region_id:
			for key in updates.keys():
				entry[key] = updates[key]
			mg.regions[i] = entry
			break

func _rebuild_border_geometry(mg: MapGenerator) -> void:
	var border_mgr: BorderManager = mg.border_manager
	border_mgr.setup(mg)
	mg._rebuild_region_polygons_from_borders()
	mg._ensure_neutral_overlays_for_all_regions()

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
	if map_editor_panel.has_signal("army_edit_saved"):
		map_editor_panel.connect("army_edit_saved", Callable(self, "_on_army_edit_saved"))
	
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
	var region_manager: RegionManager = gm.get_region_manager()
	var region_container = mg.get_region_container_by_id(region_id)
	var region := region_container as Region
	# Ownership change via editor
	if selection.begins_with("OWNER:"):
		var owner_id = int(selection.substr(6, selection.length()))
		# Use RegionManager through ClickManager for canonical visuals and borders
		var click_mgr: ClickManager = get_node("../ClickManager") as ClickManager
		var region_mgr: RegionManager = click_mgr.get_region_manager()
		# Neutral (0) clears ownership, otherwise assign
		region_mgr.set_region_ownership(region_id, owner_id)
		return
	# Army add/remove toggle
	if selection == "ARMY_ADD":
		var click_mgr2: ClickManager = get_node("../ClickManager") as ClickManager
		var army_mgr: ArmyManager = click_mgr2.get_army_manager()
		var owner := region.get_region_owner()
		if owner > 0:
			army_mgr.create_raised_army(region_container, owner)
		return
	if selection == "ARMY_REMOVE":
		# Remove first army found in region and from tracking
		var click_mgr3: ClickManager = get_node("../ClickManager") as ClickManager
		var army_mgr2: ArmyManager = click_mgr3.get_army_manager()
		for child in region_container.get_children():
			if child is Army:
				army_mgr2.remove_army_from_tracking(child)
				region_container.remove_child(child)
				child.queue_free()
				break
		return
	if selection == "Ocean":
		region.set_ocean(true)
		_apply_region_data_updates(mg, region_id, {
			"ocean": true,
			"biome": "ocean"
		})
		_reinitialize_region_for_type_change(region, region_manager)
		mg.refresh_region_visual(region_id)
		_rebuild_border_geometry(mg)
		(map_editor_panel as MapEditorPanel).update_from_region(region)
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
				var map_visual_scale := mg.get_map_visual_scale()
				castle_scale = castle_scale * mg.polygon_scale * map_visual_scale
				var polygon := container.get_node("Polygon") as Polygon2D
				var center: Vector2 = polygon.get_meta("center")
				castle.position = center + Vector2(-5 * map_visual_scale, -5 * map_visual_scale)
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
	if selection.begins_with("ORECFG_ATTEMPT:"):
		var attempt: int = maxi(0, int(selection.substr(15, selection.length())))
		region.set_ore_guaranteed_discovery(attempt, region.get_ore_guaranteed_discovery_type())
		return
	if selection.begins_with("ORECFG_TYPE:"):
		var ore_type_name: String = selection.substr(12, selection.length()).strip_edges()
		if ore_type_name.to_lower() == "none":
			region.set_ore_guaranteed_discovery(0, region.get_ore_guaranteed_discovery_type())
			return
		var ore_type: ResourcesEnum.Type = ResourcesEnum.string_to_type(ore_type_name)
		region.set_ore_guaranteed_discovery(region.get_ore_guaranteed_discovery_attempt(), ore_type)
		return
	# Region type change (land)
	region.set_ocean(false)
	var t := _display_to_enum(selection)
	var biome_str := RegionTypeEnum.type_to_string(t).to_lower()
	if biome_str == "forest_hills":
		biome_str = "hill_forest"
	_apply_region_data_updates(mg, region_id, {
		"ocean": false,
		"biome": biome_str
	})
	region.set_region_type(t)
	_reinitialize_region_for_type_change(region, region_manager)
	mg.refresh_region_visual(region_id)
	_rebuild_border_geometry(mg)
	(map_editor_panel as MapEditorPanel).update_from_region(region)

func _reinitialize_region_for_type_change(region: Region, region_manager: RegionManager) -> void:
	if region.is_ocean_region():
		_reset_ocean_region_state(region)
		return
	_initialize_land_region_state(region, region_manager)

func _reset_ocean_region_state(region: Region) -> void:
	region.set_population(0)
	region.available_recruits = 0
	region.ore_search_attempts_remaining = 0
	region.discovered_ores.clear()
	var empty_resources := ResourceComposition.new()
	region.set_base_resources(empty_resources)

func _initialize_land_region_state(region: Region, region_manager: RegionManager) -> void:
	var generated_population: int = GameParameters.generate_population_size(region.get_region_level())
	region.set_population(generated_population)
	region.available_recruits = GameParameters.calculate_max_recruits(generated_population, region.get_region_level())
	region.discovered_ores.clear()
	region.ore_search_used_this_turn = false
	if GameParameters.can_search_for_ore_in_region(region.get_region_type()):
		region.ore_search_attempts_remaining = GameParameters.ORE_SEARCH_CHANCES_PER_REGION
	else:
		region.ore_search_attempts_remaining = 0
	var empty_resources := ResourceComposition.new()
	region.set_base_resources(empty_resources)
	if region.get_region_type() != RegionTypeEnum.Type.MOUNTAINS:
		region_manager.generate_region_resources(region)

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

func _on_army_edit_saved(region_id: int, data: Dictionary) -> void:
	var mg: MapGenerator = get_node("../Map") as MapGenerator
	var region_container = mg.get_region_container_by_id(region_id)
	var army: Army = null
	for child in region_container.get_children():
		if child is Army:
			army = child as Army
			break
	
	# Check if army was found before trying to modify it
	if army == null:
		DebugLogger.log("MapEditor", "No army found in region " + str(region_id) + " to edit")
		return
	
	for t in SoldierTypeEnum.get_all_types():
		var val = int(data[t])
		army.get_composition().set_soldier_count(t, val)
