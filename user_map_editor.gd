extends Node2D
class_name UserMapEditor

enum EditMode {
	PAINT,
	SELECT
}

const PAYLOAD_META_KEY: String = "user_map_editor_payload"
const RESULT_META_KEY: String = "user_map_editor_result"
const USER_MAPS_DIRECTORY: String = "user://user_maps"
const USER_MAP_EXTENSION: String = ".json"
const SAVE_SUCCESS_COLOR: Color = Color(0.45, 1.0, 0.45, 1.0)
const SAVE_ERROR_COLOR: Color = Color(1.0, 0.45, 0.35, 1.0)
const OCEAN_BORDER_COLOR: Color = Color(0.0, 0.0, 0.0, 0.2)

@onready var map_generator: MapGenerator = get_node("Map") as MapGenerator
@onready var camera: CameraController = get_node("Camera2D") as CameraController
@onready var ocean_borders: Node2D = get_node("Map/EditorOceanBorders") as Node2D
@onready var hover_highlight: Polygon2D = get_node("Map/EditorHighlights/HoverHighlight") as Polygon2D
@onready var selection_highlight: Polygon2D = get_node("Map/EditorHighlights/SelectionHighlight") as Polygon2D
@onready var editor_panel: Control = get_node("UI/EditorPanel") as Control
@onready var map_panel_texture: TextureRect = get_node("UI/EditorPanel/MapTexture") as TextureRect
@onready var scenario_panel_texture: TextureRect = get_node("UI/EditorPanel/ScenarioTexture") as TextureRect
@onready var map_tab: Label = get_node("UI/EditorPanel/Header/Tabs/MapTab") as Label
@onready var scenario_tab: Label = get_node("UI/EditorPanel/Header/Tabs/ScenarioTab") as Label
@onready var map_content: Control = get_node("UI/EditorPanel/MapContent") as Control
@onready var scenario_content: Control = get_node("UI/EditorPanel/ScenarioContent") as Control
@onready var paint_button: Button = get_node("UI/EditorPanel/MapContent/Content/ModeButtons/Paint") as Button
@onready var select_button: Button = get_node("UI/EditorPanel/MapContent/Content/ModeButtons/Select") as Button
@onready var ocean_button: Button = get_node("UI/EditorPanel/MapContent/Content/RegionButtons/Ocean") as Button
@onready var grassland_button: Button = get_node("UI/EditorPanel/MapContent/Content/RegionButtons/Grassland") as Button
@onready var forest_button: Button = get_node("UI/EditorPanel/MapContent/Content/RegionButtons/Forest") as Button
@onready var hill_button: Button = get_node("UI/EditorPanel/MapContent/Content/RegionButtons/Hill") as Button
@onready var forest_hill_button: Button = get_node("UI/EditorPanel/MapContent/Content/RegionButtons/ForestHill") as Button
@onready var mountain_button: Button = get_node("UI/EditorPanel/MapContent/Content/RegionButtons/Mountain") as Button
@onready var map_name_input: LineEdit = get_node("UI/EditorPanel/MapContent/Content/SaveMapRow/MapName") as LineEdit
@onready var save_map_button: Button = get_node("UI/EditorPanel/MapContent/Content/SaveMapRow/SaveMap") as Button
@onready var save_status: Label = get_node("UI/EditorPanel/MapContent/Content/SaveStatus") as Label
@onready var saved_map_options: OptionButton = get_node("UI/EditorPanel/MapContent/Content/LoadMapRow/SavedMaps") as OptionButton
@onready var load_map_button: Button = get_node("UI/EditorPanel/MapContent/Content/LoadMapRow/LoadMap") as Button
@onready var validation_error: Label = get_node("UI/EditorPanel/ValidationError") as Label
@onready var back_button: Button = get_node("UI/EditorPanel/Back") as Button
@onready var done_button: Button = get_node("UI/EditorPanel/Done") as Button

var current_mode: EditMode = EditMode.PAINT
var selected_terrain: String = "grassland"
var selected_region_id: int = -1
var hovered_region_id: int = -1
var locked_ocean_region_ids: Dictionary = {}
var original_map_data: Dictionary = {}
var working_map_data: Dictionary = {}
var return_context: Dictionary = {}
var painting_active: bool = false
var last_painted_region_id: int = -1
var topology_dirty: bool = false
var terrain_buttons: Array[Button] = []

func _ready() -> void:
	var payload: Dictionary = get_tree().get_meta(PAYLOAD_META_KEY) as Dictionary
	get_tree().set_meta(PAYLOAD_META_KEY, null)
	original_map_data = payload.get("map_data", {}).duplicate(true)
	working_map_data = original_map_data.duplicate(true)
	return_context = payload.duplicate(true)
	return_context.erase("map_data")
	_collect_locked_ocean_regions()
	_setup_controls()
	map_generator.render_map_data(working_map_data)
	_setup_camera()
	_rebuild_ocean_borders()

func _setup_controls() -> void:
	paint_button.pressed.connect(_on_mode_pressed.bind(EditMode.PAINT))
	select_button.pressed.connect(_on_mode_pressed.bind(EditMode.SELECT))
	terrain_buttons = [
		ocean_button,
		grassland_button,
		forest_button,
		hill_button,
		forest_hill_button,
		mountain_button
	]
	ocean_button.pressed.connect(_on_terrain_pressed.bind("ocean"))
	grassland_button.pressed.connect(_on_terrain_pressed.bind("grassland"))
	forest_button.pressed.connect(_on_terrain_pressed.bind("forest"))
	hill_button.pressed.connect(_on_terrain_pressed.bind("hills"))
	forest_hill_button.pressed.connect(_on_terrain_pressed.bind("hill_forest"))
	mountain_button.pressed.connect(_on_terrain_pressed.bind("mountains"))
	map_tab.gui_input.connect(_on_tab_gui_input.bind(0))
	scenario_tab.gui_input.connect(_on_tab_gui_input.bind(1))
	map_name_input.text_changed.connect(_on_map_name_changed)
	save_map_button.pressed.connect(_on_save_map_pressed)
	load_map_button.pressed.connect(_on_load_map_pressed)
	back_button.pressed.connect(_on_back_pressed)
	done_button.pressed.connect(_on_done_pressed)
	editor_panel.mouse_entered.connect(_set_hovered_region.bind(-1))
	_refresh_saved_map_options()
	_show_tab(0)

func _setup_camera() -> void:
	var map_center: float = 500.0 * map_generator.polygon_scale
	var map_size: float = 1000.0 * map_generator.polygon_scale
	var frame_width: float = map_generator.ocean_frame_width * map_generator.polygon_scale
	camera.limit_left = int(-frame_width)
	camera.limit_top = int(-frame_width)
	camera.limit_right = int(map_size + frame_width)
	camera.limit_bottom = int(map_size + frame_width)
	camera.set_camera_target(Vector2(map_center, map_center))
	camera.set_zoom_immediate(map_generator.get_map_initial_zoom())
	camera.snap_to_target()

func _collect_locked_ocean_regions() -> void:
	locked_ocean_region_ids.clear()
	var bounds: Dictionary = working_map_data.get("bounds", {})
	var minimum_x: float = float(bounds.get("x", 0.0))
	var minimum_y: float = float(bounds.get("y", 0.0))
	var width: float = float(bounds.get("width", 1000.0))
	var height: float = float(bounds.get("height", 1000.0))
	var maximum_x: float = minimum_x + width
	var maximum_y: float = minimum_y + height
	var regions: Array = working_map_data.get("regions", [])
	for region_variant: Variant in regions:
		var region_data: Dictionary = region_variant as Dictionary
		if not bool(region_data.get("ocean", false)):
			continue
		var polygon: Array = region_data.get("polygon", [])
		for point_variant: Variant in polygon:
			var point: Array = point_variant as Array
			if point.size() != 2:
				continue
			var x: float = float(point[0])
			var y: float = float(point[1])
			if x < minimum_x or x > maximum_x or y < minimum_y or y > maximum_y:
				locked_ocean_region_ids[int(region_data.get("id", -1))] = true
				break

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_TAB:
			_show_tab(1 if map_content.visible else 0)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed and painting_active:
			painting_active = false
			last_painted_region_id = -1
			_commit_topology_changes()

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		if painting_active:
			painting_active = false
			last_painted_region_id = -1
			_commit_topology_changes()
		return
	if Input.is_key_pressed(KEY_SHIFT):
		return
	if not map_content.visible:
		return
	var region_id: int = _find_region_at_mouse()
	if region_id == -1:
		return
	if current_mode == EditMode.PAINT:
		painting_active = true
		last_painted_region_id = region_id
		_apply_terrain_to_region(region_id, selected_terrain)
	else:
		_select_region(region_id)
	get_viewport().set_input_as_handled()

func _handle_mouse_motion() -> void:
	var hovered_control: Control = get_viewport().gui_get_hovered_control()
	if hovered_control != null and (hovered_control == editor_panel or editor_panel.is_ancestor_of(hovered_control)):
		_set_hovered_region(-1)
		return
	var region_id: int = _find_region_at_mouse()
	_set_hovered_region(region_id)
	if not map_content.visible:
		return
	if not painting_active or Input.is_key_pressed(KEY_SHIFT):
		return
	if region_id == -1 or region_id == last_painted_region_id:
		return
	last_painted_region_id = region_id
	_apply_terrain_to_region(region_id, selected_terrain)

func _find_region_at_mouse() -> int:
	var world_position: Vector2 = camera.get_global_mouse_position()
	for region_id_variant: Variant in map_generator.region_container_by_id.keys():
		var region_id: int = int(region_id_variant)
		if locked_ocean_region_ids.has(region_id):
			continue
		var region: Region = map_generator.region_container_by_id[region_id] as Region
		var polygon: Polygon2D = region.get_node("Polygon") as Polygon2D
		var local_position: Vector2 = polygon.to_local(world_position)
		if Geometry2D.is_point_in_polygon(local_position, polygon.polygon):
			return region_id
	return -1

func _on_mode_pressed(mode: EditMode) -> void:
	current_mode = mode
	selection_highlight.visible = current_mode == EditMode.SELECT and selected_region_id != -1
	_set_terrain_buttons_locked(false)
	if current_mode == EditMode.SELECT and selected_region_id != -1:
		_sync_terrain_selection(selected_region_id)

func _on_terrain_pressed(terrain: String) -> void:
	selected_terrain = terrain
	if current_mode == EditMode.SELECT and selected_region_id != -1:
		_apply_terrain_to_region(selected_region_id, selected_terrain)
		_commit_topology_changes()

func _select_region(region_id: int) -> void:
	selected_region_id = region_id
	_sync_terrain_selection(region_id)
	_update_highlight(selection_highlight, region_id)
	selection_highlight.visible = true

func _sync_terrain_selection(region_id: int) -> void:
	var terrain: String = _get_region_terrain(region_id)
	selected_terrain = terrain
	var selected_button: Button = _get_terrain_button(terrain)
	selected_button.button_pressed = true
	_set_terrain_buttons_locked(locked_ocean_region_ids.has(region_id))

func _set_terrain_buttons_locked(locked: bool) -> void:
	for terrain_button: Button in terrain_buttons:
		terrain_button.disabled = locked and terrain_button != ocean_button

func _get_terrain_button(terrain: String) -> Button:
	match terrain:
		"ocean":
			return ocean_button
		"forest":
			return forest_button
		"hills":
			return hill_button
		"hill_forest":
			return forest_hill_button
		"mountains":
			return mountain_button
		_:
			return grassland_button

func _get_region_terrain(region_id: int) -> String:
	var region_data: Dictionary = _get_working_region_data(region_id)
	if bool(region_data.get("ocean", false)):
		return "ocean"
	var biome: String = String(region_data.get("biome", "grassland")).to_lower()
	if biome == "forest_hills" or biome == "hills_forest":
		return "hill_forest"
	return biome

func _apply_terrain_to_region(region_id: int, terrain: String) -> void:
	if locked_ocean_region_ids.has(region_id):
		return
	if _get_region_terrain(region_id) == terrain:
		return
	_clear_validation_error()
	var is_ocean: bool = terrain == "ocean"
	_update_working_region_data(region_id, terrain, is_ocean)
	map_generator.set_editor_region_terrain(region_id, terrain, is_ocean)
	topology_dirty = true
	if selected_region_id == region_id:
		_update_highlight(selection_highlight, region_id)
	if hovered_region_id == region_id:
		_update_highlight(hover_highlight, region_id)

func _update_working_region_data(region_id: int, terrain: String, ocean: bool) -> void:
	var regions: Array = working_map_data.get("regions", [])
	for index: int in range(regions.size()):
		var region_data: Dictionary = regions[index]
		if int(region_data.get("id", -1)) != region_id:
			continue
		region_data["biome"] = "ocean" if ocean else terrain
		region_data["ocean"] = ocean
		region_data["water"] = ocean
		region_data["coast"] = false
		regions[index] = region_data
		working_map_data["regions"] = regions
		return

func _get_working_region_data(region_id: int) -> Dictionary:
	var regions: Array = working_map_data.get("regions", [])
	for region_variant: Variant in regions:
		var region_data: Dictionary = region_variant as Dictionary
		if int(region_data.get("id", -1)) == region_id:
			return region_data
	return {}

func _commit_topology_changes() -> void:
	if not topology_dirty:
		return
	map_generator.rebuild_after_editor_terrain_changes()
	_rebuild_ocean_borders()
	_refresh_highlights()
	topology_dirty = false

func _rebuild_ocean_borders() -> void:
	for child: Node in ocean_borders.get_children():
		child.queue_free()
	for edge_variant: Variant in map_generator.edges:
		var edge: Dictionary = edge_variant as Dictionary
		var first_region_id: int = int(edge.get("region1", -1))
		var second_region_id: int = int(edge.get("region2", -1))
		if first_region_id == -1 or second_region_id == -1:
			continue
		var first_region: Dictionary = map_generator.region_by_id[first_region_id]
		var second_region: Dictionary = map_generator.region_by_id[second_region_id]
		if not bool(first_region.get("ocean", false)) or not bool(second_region.get("ocean", false)):
			continue
		var line: Line2D = Line2D.new()
		line.name = "OceanBorder@%d" % int(edge.get("id", 0))
		line.points = map_generator.border_manager.get_edge_render_points(edge)
		line.width = maxf(1.0, map_generator.polygon_scale * map_generator.get_map_visual_scale())
		line.default_color = OCEAN_BORDER_COLOR
		line.z_index = 3
		ocean_borders.add_child(line)

func _set_hovered_region(region_id: int) -> void:
	hovered_region_id = region_id
	if region_id == -1 or region_id == selected_region_id:
		hover_highlight.visible = false
		return
	_update_highlight(hover_highlight, region_id)
	hover_highlight.visible = true

func _update_highlight(highlight: Polygon2D, region_id: int) -> void:
	var region: Region = map_generator.region_container_by_id[region_id] as Region
	var polygon: Polygon2D = region.get_node("Polygon") as Polygon2D
	highlight.polygon = polygon.polygon
	highlight.position = polygon.position

func _refresh_highlights() -> void:
	if selected_region_id != -1:
		_update_highlight(selection_highlight, selected_region_id)
	if hovered_region_id != -1:
		_update_highlight(hover_highlight, hovered_region_id)

func _on_tab_gui_input(event: InputEvent, tab_index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_show_tab(tab_index)

func _show_tab(tab_index: int) -> void:
	var show_map: bool = tab_index == 0
	if not show_map and painting_active:
		painting_active = false
		last_painted_region_id = -1
		_commit_topology_changes()
	map_content.visible = show_map
	scenario_content.visible = not show_map
	map_panel_texture.visible = show_map
	scenario_panel_texture.visible = not show_map
	map_tab.modulate = Color.WHITE if show_map else Color(0.6, 0.6, 0.6, 1.0)
	scenario_tab.modulate = Color(0.6, 0.6, 0.6, 1.0) if show_map else Color.WHITE

func _on_map_name_changed(map_name: String) -> void:
	save_map_button.disabled = _sanitize_user_map_name(map_name).is_empty()
	save_status.visible = false

func _on_save_map_pressed() -> void:
	var map_name: String = _sanitize_user_map_name(map_name_input.text)
	if map_name.is_empty():
		return
	_commit_topology_changes()
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_MAPS_DIRECTORY))
	if directory_error != OK:
		push_error("Unable to create user map directory: " + USER_MAPS_DIRECTORY)
		_show_save_status(false)
		return
	var map_path: String = USER_MAPS_DIRECTORY.path_join(map_name + USER_MAP_EXTENSION)
	var map_file: FileAccess = FileAccess.open(map_path, FileAccess.WRITE)
	if map_file == null:
		push_error("Unable to save user map: " + map_path)
		_show_save_status(false)
		return
	map_file.store_string(JSON.stringify(working_map_data, "\t"))
	map_file.close()
	_show_save_status(true)
	_refresh_saved_map_options(map_path)

func _show_save_status(saved: bool) -> void:
	save_status.text = tr("Map saved") if saved else tr("Saving error")
	save_status.add_theme_color_override("font_color", SAVE_SUCCESS_COLOR if saved else SAVE_ERROR_COLOR)
	save_status.visible = true

func _sanitize_user_map_name(map_name: String) -> String:
	return map_name.strip_edges().validate_filename().replace(" ", "_")

func _refresh_saved_map_options(preferred_path: String = "") -> void:
	saved_map_options.clear()
	load_map_button.disabled = true
	var directory: DirAccess = DirAccess.open(USER_MAPS_DIRECTORY)
	if directory == null:
		return
	var file_names: Array[String] = []
	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and file_name.to_lower().ends_with(USER_MAP_EXTENSION):
			file_names.append(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	file_names.sort()
	var preferred_index: int = 0
	for saved_file_name: String in file_names:
		var file_path: String = USER_MAPS_DIRECTORY.path_join(saved_file_name)
		if _read_saved_map(file_path).is_empty():
			continue
		var display_name: String = saved_file_name.get_basename().replace("_", " ").capitalize()
		saved_map_options.add_item(display_name)
		var item_index: int = saved_map_options.item_count - 1
		saved_map_options.set_item_metadata(item_index, file_path)
		if file_path == preferred_path:
			preferred_index = item_index
	if saved_map_options.item_count == 0:
		return
	saved_map_options.select(preferred_index)
	load_map_button.disabled = false

func _on_load_map_pressed() -> void:
	var selected_index: int = saved_map_options.selected
	if selected_index < 0:
		return
	var map_path: String = String(saved_map_options.get_item_metadata(selected_index))
	var loaded_map_data: Dictionary = _read_saved_map(map_path)
	if loaded_map_data.is_empty():
		push_error("Unable to load user map: " + map_path)
		return
	_replace_working_map(loaded_map_data)

func _read_saved_map(map_path: String) -> Dictionary:
	var content: String = FileAccess.get_file_as_string(map_path)
	var json: JSON = JSON.new()
	if json.parse(content) != OK:
		return {}
	var parsed_data: Variant = json.get_data()
	if not (parsed_data is Dictionary):
		return {}
	var map_data: Dictionary = parsed_data as Dictionary
	var regions_value: Variant = map_data.get("regions", [])
	var edges_value: Variant = map_data.get("edges", [])
	if not (regions_value is Array) or not (edges_value is Array):
		return {}
	if (regions_value as Array).is_empty():
		return {}
	return map_data

func _replace_working_map(map_data: Dictionary) -> void:
	working_map_data = map_data.duplicate(true)
	painting_active = false
	last_painted_region_id = -1
	selected_region_id = -1
	hovered_region_id = -1
	topology_dirty = false
	selection_highlight.visible = false
	hover_highlight.visible = false
	save_status.visible = false
	_set_terrain_buttons_locked(false)
	_clear_validation_error()
	_collect_locked_ocean_regions()
	map_generator.render_map_data(working_map_data)
	_setup_camera()
	_rebuild_ocean_borders()

func _on_back_pressed() -> void:
	_return_to_main_menu(original_map_data)

func _on_done_pressed() -> void:
	_commit_topology_changes()
	var regions: Array = working_map_data.get("regions", [])
	var edges: Array = working_map_data.get("edges", [])
	if not RegionGraph.is_passable_map_connected(regions, edges):
		validation_error.visible = true
		done_button.disabled = true
		return
	_return_to_main_menu(working_map_data)

func _clear_validation_error() -> void:
	validation_error.visible = false
	done_button.disabled = false

func _return_to_main_menu(map_data: Dictionary) -> void:
	var result: Dictionary = return_context.duplicate(true)
	result["map_data"] = map_data.duplicate(true)
	get_tree().set_meta(RESULT_META_KEY, result)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
