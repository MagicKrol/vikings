extends Node2D

class_name MapGenerator

signal map_generated

# Configuration
@export var data_file_path: String = "mapdata-207-xtiny.json"
@export var noisy_edges_enabled: bool = true
@export var debug_draw_overlay: bool = false
@export var show_region_colors: bool = false
@export var show_region_graph: bool = false
@export var show_region_points: bool = false
@export var region_point_inner_color: Color = Color.RED
@export var polygon_scale: float = 2.0
@export var ocean_frame_width: float = 500.0

# Map size configuration
enum MapSize {
	TINY,
	SMALL,
	MEDIUM,
	LARGE,
	HUGE,
	XTINY
}

@export var map_size: MapSize = MapSize.XTINY

# Map size scaling factors (SMALL is baseline 1.0)
const MAP_SIZE_SCALES := {
	MapSize.TINY: 1.436486,      # Tiny map size: 504
	MapSize.SMALL: 1.0,          # Baseline
	MapSize.MEDIUM: 0.703062,    # Medium map size: 2104
	MapSize.LARGE: 0.505064,     # Large map size: 4077
	MapSize.HUGE: 9.0/26.0,      # ~0.346154
	MapSize.XTINY: 55.0/26.0     # ~2.115385
}

# Noisy edge parameters (matching JS defaults)
@export var noisy_edge_amplitude: float = 0.15
@export var noisy_edge_length: float = 6.0
@export var noisy_edge_seed: int = 12345

# Data from JSON
var map_data: Dictionary = {}
var regions: Array = []
var edges: Array = []
var region_by_id: Dictionary = {}
var non_ocean_graph: Dictionary = {}
var non_ocean_centers: Dictionary = {}

# Map content containers
var map_root: Node2D
var map_node_regions: Node2D
var map_node_ocean: Node2D
var map_node_frame: Node2D

# Region node lookup: region_id -> Node2D container
var region_container_by_id: Dictionary = {}
var center_markers_enabled: bool = false
var center_marker_container: Node2D = null

@onready var border_manager: BorderManager = get_node("BorderManager") as BorderManager

func _ready() -> void:
	generate_map()

func generate_map() -> void:
	_load_json_data()
	_tag_mountain_neighbor_info()
	_render_from_json()

	# Center camera to the middle of the map if a Camera2D exists
	var cam: Camera2D = get_node_or_null("../Camera2D") as Camera2D
	if cam != null:
		var map_center = 500.0 * polygon_scale
		# Use camera controller method if available, otherwise set position directly
		if cam.has_method("set_camera_target"):
			cam.set_camera_target(Vector2(map_center, map_center))
		else:
			cam.position = Vector2(map_center, map_center)  # fallback
			
		# Update camera limits based on scaled map size including ocean frame
		var map_size = 1000.0 * polygon_scale
		var frame_width = ocean_frame_width * polygon_scale
		cam.limit_left = int(-frame_width)
		cam.limit_top = int(-frame_width)
		cam.limit_right = int(map_size + frame_width)
		cam.limit_bottom = int(map_size + frame_width)

# -------------------- Map container helpers --------------------
func _ensure_map_nodes() -> void:
	# Get references to static map container nodes defined in main.tscn
	if map_root == null:
		map_root = self  # This node is the Map root
	
	if map_node_regions == null:
		map_node_regions = get_node("Regions") as Node2D
	
	if map_node_ocean == null:
		map_node_ocean = get_node("Ocean") as Node2D
	
	if map_node_frame == null:
		map_node_frame = get_node("Frame") as Node2D

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

# -------------------- JSON Data Loading --------------------
func _load_json_data() -> void:
	var path := _resolve_mapdata_path(data_file_path)
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		DebugLogger.log("MapGeneration", "ERROR: Could not open file: " + path)
		return
		
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		DebugLogger.log("MapGeneration", "ERROR: Could not parse JSON: " + json.error_string)
		return

	map_data = json.data
	regions = map_data.get("regions", [])
	edges = map_data.get("edges", [])
	DebugLogger.log("MapGeneration", "Loaded map: regions=" + str(regions.size()) + ", edges=" + str(edges.size()) + ", file=" + path)
	region_by_id.clear()
	for r in regions:
		var rid = int(r.get("id", -1))
		if rid >= 0:
			region_by_id[rid] = r
	

	var meta = map_data.get("meta", {})

	
	# Scale all coordinates if polygon_scale != 1.0
	if polygon_scale != 1.0:
		_scale_map_data()

func _tag_mountain_neighbor_info() -> void:
	for region in regions:
		var biome := String(region.get("biome", "")).to_lower()
		if biome != "mountains":
			continue
		var region_id := int(region.get("id", -1))
		if region_id == -1:
			continue
		var edges_list: Array = region.get("edges", [])
		if edges_list.is_empty():
			region["internal_mountain"] = false
			continue
		var is_internal := true
		for edge_id in edges_list:
			if edge_id < 0 or edge_id >= edges.size():
				is_internal = false
				break
			var edge: Dictionary = edges[edge_id]
			var r1 := int(edge.get("region1", -1))
			var r2 := int(edge.get("region2", -1))
			var neighbor_id := r2 if r1 == region_id else r1
			if neighbor_id == -1:
				is_internal = false
				break
			var neighbor_data: Dictionary = region_by_id.get(neighbor_id, {})
			if neighbor_data.is_empty():
				is_internal = false
				break
			if bool(neighbor_data.get("ocean", false)):
				is_internal = false
				break
			var neighbor_biome := String(neighbor_data.get("biome", "")).to_lower()
			if neighbor_biome != "mountains":
				is_internal = false
				break
		region["internal_mountain"] = is_internal

func _resolve_mapdata_path(name: String) -> String:
	# Always read from res://mapdata/. Accept bare filenames or full paths; normalize to folder.
	if name == null or name == "":
		return "res://mapdata/mapdata-280-small.json"
	if name.begins_with("res://"):
		var base := name.get_file()
		return "res://mapdata/" + base
	var file_only := name.get_file()
	return "res://mapdata/" + file_only
	

func _scale_map_data() -> void:
	# Scale all coordinate data in the loaded JSON
	
	# Scale region centers and any direct polygon data
	for region in regions:
		var center_data = region.get("center", [])
		if center_data.size() == 2:
			region["center"] = [center_data[0] * polygon_scale, center_data[1] * polygon_scale]
			
		# Scale direct polygon coordinates if they exist
		var polygon_data = region.get("polygon", [])
		if polygon_data.size() > 0:
			var scaled_polygon = []
			for point in polygon_data:
				if point is Array and point.size() == 2:
					scaled_polygon.append([point[0] * polygon_scale, point[1] * polygon_scale])
				else:
					scaled_polygon.append(point)  # Keep non-coordinate data as-is
			region["polygon"] = scaled_polygon
	
	# Scale edge coordinates  
	for edge in edges:
		var start_data = edge.get("start", [])
		if start_data.size() == 2:
			edge["start"] = [start_data[0] * polygon_scale, start_data[1] * polygon_scale]
			
		var end_data = edge.get("end", [])
		if end_data.size() == 2:
			edge["end"] = [end_data[0] * polygon_scale, end_data[1] * polygon_scale]
			
		var center1_data = edge.get("region1_center", [])
		if center1_data.size() == 2:
			edge["region1_center"] = [center1_data[0] * polygon_scale, center1_data[1] * polygon_scale]
			
		var center2_data = edge.get("region2_center", [])
		if center2_data.size() == 2:
			edge["region2_center"] = [center2_data[0] * polygon_scale, center2_data[1] * polygon_scale]

# -------------------- Rendering from JSON --------------------
func _render_from_json() -> void:
	# Clear previous children
	for child in get_children():
		if (child is Polygon2D or child is ColorRect or child is Sprite2D or child is Line2D) and child.name != "TutorialWorldArrow":
			remove_child(child)
			child.queue_free()

	_ensure_map_nodes()
	_clear_children(map_node_regions)
	_clear_children(map_node_ocean)
	_clear_children(map_node_frame)
	region_container_by_id.clear()
	_recompute_region_centers()

	# Add background image
	var background := Sprite2D.new()
	background.texture = load("res://images/sea_new8_opt.png")
	var map_dimension := 1000.0 * polygon_scale
	var frame_width_scaled := ocean_frame_width * polygon_scale
	var background_size := map_dimension + frame_width_scaled * 2.0
	background.centered = false
	background.position = Vector2(-frame_width_scaled, -frame_width_scaled)
	background.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	background.region_enabled = true
	background.region_rect = Rect2(Vector2.ZERO, Vector2(background_size, background_size))
	background.scale = Vector2.ONE
	background.z_index = -100
	if map_root != null:
		map_root.add_child(background)
	else:
		add_child(background)

	# Create blue ocean frame around the map
	_create_ocean_frame()

	# Create individual ocean polygons without textures so the main background shows through
	var ocean_count := 0
	var ocean_region_ids: Array[int] = []
	for region_data in regions:
		var is_ocean := bool(region_data.get("ocean", false))
		var region_id := int(region_data.get("id", -1))
		if is_ocean:
			ocean_region_ids.append(region_id)
			var poly := _build_region_polygon_points(region_data)
			if poly.size() >= 3:
				var ocean_pg := Polygon2D.new()
				ocean_count += 1
				ocean_pg.name = "ocean" + str(ocean_count)
				# Tag with region metadata for editor hit-testing
				ocean_pg.set_meta("region_id", region_id)
				var cmeta: Array = region_data.get("center", [])
				if cmeta.size() == 2:
					ocean_pg.set_meta("center", Vector2(float(cmeta[0]), float(cmeta[1])))
				ocean_pg.polygon = poly
				ocean_pg.visible = false
				ocean_pg.z_index = 0
				map_node_ocean.add_child(ocean_pg)
				# DebugLogger.log("MapGeneration", "Created ocean region ID: " + str(region_id) + " biome: " + str(region_data.get("biome", "unknown")))
	


	# Build region containers for all regions and land polygons
	var _region_count := 0
	var _total_regions := 0
	var land_region_ids: Array[int] = []
	for region_data in regions:
		_total_regions += 1
		var is_ocean := bool(region_data.get("ocean", false))
		var region_id := int(region_data.get("id", -1))
		# Create region container structure with Region script for ALL regions
		var region_container := Node2D.new()
		region_container.set_script(load("res://region.gd"))
		region_container.setup_region(region_data)
		_assign_region_name_if_available(region_container)
		var reg_id: int = region_container.get_region_id()
		region_container.name = "%s#%d" % [region_container.get_region_name(), reg_id]
		map_node_regions.add_child(region_container)
		region_container_by_id[region_id] = region_container
	
		if not is_ocean:
			land_region_ids.append(region_id)
			_region_count += 1
			# Land: add visible polygon under region container
			var _polygon_node := _add_region_polygon_node(region_data, null, "Polygon", region_container)
			# Add region point under region container
			if show_region_points:
				var center_data = region_data.get("center", [])
				if center_data.size() == 2:
					var center := Vector2(center_data[0], center_data[1])
					var region_point := RegionPoints.create_region_point(center, polygon_scale, region_point_inner_color)
					region_point.name = "RegionPoint"
					region_container.add_child(region_point)
		else:
			# Ocean: add hidden polygon for editor hit logic and future land conversion
			var ocean_poly_points := _build_region_polygon_points(region_data)
			if ocean_poly_points.size() >= 3:
				var hidden_pg := Polygon2D.new()
				hidden_pg.name = "Polygon"
				hidden_pg.polygon = ocean_poly_points
				hidden_pg.visible = false
				region_container.add_child(hidden_pg)
		# Add Borders container for all regions (needed when ocean becomes land)
		var borders_node := Node2D.new()
		borders_node.name = "Borders"
		region_container.add_child(borders_node)
	
	# DebugLogger.log("MapGeneration", "Total regions in JSON: " + str(total_regions))
	# DebugLogger.log("MapGeneration", "Ocean regions: " + str(ocean_count) + ", Land regions: " + str(region_count))
	# DebugLogger.log("MapGeneration", "Coverage check: " + str(ocean_count + region_count) + " should equal " + str(total_regions))
	
	# Check for overlapping IDs (this should never happen!)
	for ocean_id in ocean_region_ids:
		if ocean_id in land_region_ids:
			DebugLogger.log("MapGeneration", "ERROR: Region ID " + str(ocean_id) + " appears in BOTH ocean and land lists!")
	
	# DebugLogger.log("MapGeneration", "Ocean IDs: " + str(ocean_region_ids))
	# DebugLogger.log("MapGeneration", "Land IDs: " + str(land_region_ids))

	DebugLogger.log("MapGeneration", "Ocean polygons added=" + str(ocean_count))

	# Draw and register borders via dedicated manager
	border_manager.setup(self)

	# Sync land polygons with the generated noisy borders
	_rebuild_region_polygons_from_borders()
	_ensure_neutral_overlays_for_all_regions()

	# Build adjacency graph for non-ocean regions and draw overlay
	_build_and_draw_region_graph_overlay()
	_refresh_center_markers()
	_sort_mountain_icon_z_indices()


	DebugLogger.log("MapGeneration", "Rendered edges: " + str(edges.size()) + ", land regions created=" + str(_region_count))
	# Notify listeners that the map has been generated
	emit_signal("map_generated")

func _create_region_from_data(region_data: Dictionary) -> void:
	var polygon_data = region_data.get("polygon", [])
	if polygon_data.size() < 3:
		return  # Invalid polygon
		
	# Convert polygon points to PackedVector2Array
	var poly := PackedVector2Array()
	for point in polygon_data:
		if point is Array and point.size() == 2:
			poly.append(Vector2(point[0], point[1]))
	
	if poly.size() < 3:
		return  # Still invalid after conversion
	
	var region_id = region_data.get("id", -1)
	
	# Create Polygon2D
	var pg := Polygon2D.new()
	var biome_name := String(region_data.get("biome", "OCEAN"))
	pg.color = BiomeManager.get_biome_color(biome_name)
	
	# Ensure proper winding order for Godot (counter-clockwise)
	if Utils.is_clockwise(poly):
		poly.reverse()
	
	# Apply noisy edges if enabled
	if noisy_edges_enabled:
		var noisy_poly = NoisyEdges.apply_noisy_edges_to_polygon(poly, region_data, noisy_edge_seed, noisy_edge_length, noisy_edge_amplitude)

		pg.polygon = noisy_poly

	else:
		pg.polygon = poly
	
	# Set z-index to avoid overlap issues
	pg.z_index = int(region_id) % 100
	
	add_child(pg)
	
	# Debug overlay if enabled
	if debug_draw_overlay:
		var center_data = region_data.get("center", [500, 500])
		var center := Vector2(center_data[0], center_data[1])
		var dot := ColorRect.new()
		dot.position = center - Vector2(1, 1)
		dot.size = Vector2(2, 2)
		var is_ocean := bool(region_data.get("ocean", false))
		var is_water := bool(region_data.get("water", false))
		if is_ocean:
			dot.color = Color(0.2, 0.4, 0.8, 0.9)
		elif is_water:
			dot.color = Color(0.2, 0.7, 1.0, 0.9)
		else:
			dot.color = Color(0.2, 0.8, 0.3, 0.9)
		dot.z_index = 50
		add_child(dot)

func _create_region_from_edges(region_data: Dictionary) -> void:
	var center_data = region_data.get("center", [500, 500])
	var center := Vector2(center_data[0], center_data[1])
	var edge_ids: Array = region_data.get("edges", [])
	if edge_ids.is_empty():
		return
	var pts: Array[Vector2] = []
	for eid in edge_ids:
		var e = edges[int(eid)]
		var a_arr: Array = e.get("start", [])
		var b_arr: Array = e.get("end", [])
		if a_arr.size() == 2:
			pts.append(Vector2(a_arr[0], a_arr[1]))
		if b_arr.size() == 2:
			pts.append(Vector2(b_arr[0], b_arr[1]))
	var poly := Utils.dedup_and_sort_polygon(pts, center)
	if poly.size() < 3:
		return
	var pg := Polygon2D.new()
	var biome_name := String(region_data.get("biome", "OCEAN"))
	pg.color = BiomeManager.get_biome_color(biome_name)
	if Utils.is_clockwise(poly):
		poly.reverse()
	pg.polygon = poly
	pg.z_index = int(region_data.get("id", 0)) % 100
	add_child(pg)



func _build_region_polygon_points(region_data: Dictionary) -> PackedVector2Array:
	var center_data = region_data.get("center", [500, 500])
	var center := Vector2(center_data[0], center_data[1])
	var edge_ids: Array = region_data.get("edges", [])
	var region_id := int(region_data.get("id", -1))
	var polygon_fallback := PackedVector2Array()
	var polygon_data = region_data.get("polygon", [])
	if polygon_data.size() >= 3:
		for point in polygon_data:
			if point is Array and point.size() == 2:
				polygon_fallback.append(Vector2(point[0], point[1]))
	
	if edge_ids.is_empty():
		DebugLogger.log("MapGeneration", "WARNING: Region " + str(region_id) + " has no edges!")
		return polygon_fallback
		
	var pts: Array[Vector2] = []
	var invalid_points := 0
	
	for eid in edge_ids:
		var edge_id := int(eid)
		
		# Skip invalid edge IDs (negative values are placeholders/invalid)
		if edge_id < 0:
			continue
			
		if edge_id >= edges.size():
			DebugLogger.log("MapGeneration", "ERROR: Region " + str(region_id) + " references invalid edge ID: " + str(eid))
			continue
			
		var e = edges[edge_id]
		var a_arr: Array = e.get("start", [])
		var b_arr: Array = e.get("end", [])
		
		# Validate and filter out invalid coordinates
		if a_arr.size() == 2:
			var point_a := Vector2(a_arr[0], a_arr[1])
			if Utils.is_valid_coordinate(point_a, polygon_scale):
				pts.append(point_a)
			else:
				invalid_points += 1
				DebugLogger.log("MapGeneration", "WARNING: Region " + str(region_id) + " edge " + str(edge_id) + " has invalid start point: " + str(point_a))
				
		if b_arr.size() == 2:
			var point_b := Vector2(b_arr[0], b_arr[1])
			if Utils.is_valid_coordinate(point_b, polygon_scale):
				pts.append(point_b)
			else:
				invalid_points += 1
				DebugLogger.log("MapGeneration", "WARNING: Region " + str(region_id) + " edge " + str(edge_id) + " has invalid end point: " + str(point_b))
	
	if invalid_points > 0:
		DebugLogger.log("MapGeneration", "WARNING: Region " + str(region_id) + " had " + str(invalid_points) + " invalid coordinates filtered out")
	
	if pts.size() < 3:
		if polygon_fallback.size() >= 3:
			return polygon_fallback
		# DebugLogger.log("MapGeneration", "ERROR: Region " + str(region_id) + " has insufficient valid points: " + str(pts.size()))
		return PackedVector2Array()
		
	var deduped := Utils.dedup_and_sort_polygon(pts, center)
	if deduped.size() >= 3:
		return deduped
	return polygon_fallback if polygon_fallback.size() >= 3 else deduped

func _recompute_region_centers() -> void:
	for region_data in regions:
		var region_id := int(region_data.get("id", -1))
		if region_id < 0:
			continue
		var polygon_points := _build_region_polygon_points(region_data)
		if polygon_points.size() >= 3:
			_update_region_center_from_polygon(region_id, region_data, polygon_points)

func _update_region_center_from_polygon(region_id: int, region_data: Dictionary, polygon_points: PackedVector2Array, region_container: Node = null, polygon_node: Polygon2D = null) -> Vector2:
	if polygon_points.size() < 1 or region_data.is_empty():
		return Vector2.ZERO
	var center := Utils.compute_polygon_centroid(polygon_points)
	region_data["center"] = [center.x, center.y]
	region_by_id[region_id] = region_data
	if polygon_node != null:
		polygon_node.set_meta("center", center)
	if region_container != null and region_container is Region:
		var region := region_container as Region
		region.center = center
	return center

func _add_region_polygon_node(region_data: Dictionary, polygon_color, node_name: String = "", parent_container: Node = null) -> Polygon2D:
	var poly := _build_region_polygon_points(region_data)
	if poly.size() < 3:
		return null
	var pg := Polygon2D.new()
	
	# Set node name if provided
	if node_name != "":
		pg.name = node_name
	
	# Random color per region for visual verification
	var rid := int(region_data.get("id", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = noisy_edge_seed + rid
	# Tag polygon with region metadata for click handling
	pg.set_meta("region_id", rid)
	# Only set color for debug modes or explicit color override
	if (polygon_color != null):
		pg.color = polygon_color
	elif show_region_colors:
		pg.color = Color(rng.randf(), rng.randf(), rng.randf(), 1.0)  # Random colors for verification
	# Otherwise don't set pg.color at all - let it default to white like ocean polygons
	pg.polygon = poly
	_update_region_center_from_polygon(rid, region_data, pg.polygon, parent_container, pg)

	# Apply grass texture to all non-ocean regions
	pg.texture = load("res://images/background4grass7.png")
	# pg.texture_scale = Vector2(1.0 / polygon_scale, 1.0 / polygon_scale)
	pg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	pg.z_index = 0  # Land on same level as ocean
	if parent_container != null:
		parent_container.add_child(pg)
	else:
		add_child(pg)
	# DebugLogger.log("MapGeneration", "Created land region ID: " + str(region_data.get("id", "unknown")) + " name: " + str(node_name) + " at z_index: " + str(pg.z_index))

	# Add biome icons based on mapping rules
	var biome_name := String(region_data.get("biome", ""))
	if biome_name != "":
		RegionIconManager.place_region_icon(pg, region_data, polygon_scale, map_size)

	return pg

func _rebuild_region_polygons_from_borders() -> void:
	for region_data in regions:
		if bool(region_data.get("ocean", false)):
			continue
		var region_id := int(region_data.get("id", -1))
		if region_id == -1:
			continue
		var region_container: Node2D = region_container_by_id[region_id]
		var polygon_node: Polygon2D = region_container.get_node("Polygon")
		var updated_polygon := _create_noisy_polygon_for_region(region_id)
		if updated_polygon.size() >= 3:
			polygon_node.polygon = updated_polygon
			_update_region_center_from_polygon(region_id, region_data, updated_polygon, region_container, polygon_node)

func _sort_mountain_icon_z_indices() -> void:
	var mountain_icons: Array = []
	for region_id in region_container_by_id.keys():
		var region_container = region_container_by_id.get(region_id, null)
		if region_container == null or not (region_container is Region):
			continue
		var region := region_container as Region
		var polygon := region_container.get_node_or_null("Polygon") as Polygon2D
		if polygon == null:
			continue
		for child in polygon.get_children():
			if child is Sprite2D and child.has_meta("mountain_icon") and child.get_meta("mountain_icon"):
				mountain_icons.append({
					"sprite": child,
					"center_y": region.center.y
				})
	if mountain_icons.is_empty():
		return
	mountain_icons.sort_custom(func(a, b):
		return a.center_y < b.center_y
	)
	var base_z := 10
	for i in range(mountain_icons.size()):
		var sprite := mountain_icons[i].sprite as Sprite2D
		if sprite == null:
			continue
		sprite.z_index = base_z + i

func _ensure_neutral_overlays_for_all_regions() -> void:
	for region_id in region_container_by_id.keys():
		var region_container = region_container_by_id[region_id]
		if region_container == null:
			continue
		if region_container is Region:
			if (region_container as Region).is_ocean_region():
				continue
		var overlay = _get_or_create_ownership_overlay(region_id)
		if overlay != null and overlay.color.a <= 0.001:
			overlay.color = _get_neutral_overlay_color()


func _get_player_color(player_id: int) -> Color:
	"""Get the color for a specific player"""
	var color = GameParameters.get_player_color(player_id)
	color.a = 0.5  # 50% transparency
	return color

func create_ownership_overlay(region_id: int, player_id: int) -> void:
	"""Create or recolor the ownership overlay for this region."""
	var overlay_polygon = _get_or_create_ownership_overlay(region_id)
	if overlay_polygon == null:
		DebugLogger.log("MapGeneration", "Error: Could not create ownership overlay for region: " + str(region_id))
		return
	var player_color = _get_player_color(player_id)
	player_color.a = 0.4
	overlay_polygon.color = player_color

func update_ownership_overlay(region_id: int, player_id: int) -> void:
	"""Update color of existing ownership overlay (do not change alpha)."""
	var overlay = _get_or_create_ownership_overlay(region_id)
	if overlay != null:
		var player_color = _get_player_color(player_id)
		overlay.color = Color(player_color.r, player_color.g, player_color.b, 0.4)

func _create_noisy_polygon_for_region(region_id: int) -> PackedVector2Array:
	"""Extract polygon points directly from the existing Line2D borders"""
	var region_container = get_region_container_by_id(region_id)
	if region_container == null:
		return PackedVector2Array()
	
	var border_segments := border_manager.get_region_border_points(region_id)
	if border_segments.is_empty():
		var original_polygon = region_container.get_node_or_null("Polygon") as Polygon2D
		if original_polygon:
			return original_polygon.polygon
		return PackedVector2Array()
	
	var polygon_points := _reconstruct_polygon_from_segments(border_segments)
	if polygon_points.size() >= 3:
		return polygon_points
	
	var all_border_points := PackedVector2Array()
	for segment in border_segments:
		for point in segment:
			all_border_points.append(point)
	
	if all_border_points.size() < 3:
		return PackedVector2Array()
	
	return _create_polygon_from_border_points(all_border_points)

func _create_polygon_from_border_points(border_points: PackedVector2Array) -> PackedVector2Array:
	"""Create a polygon from scattered border points"""
	if border_points.size() < 3:
		return PackedVector2Array()
	
	# Find the center point
	var center = Vector2.ZERO
	for point in border_points:
		center += point
	center /= border_points.size()
	
	# Sort points by angle from center (this creates a rough polygon)
	var points_with_angles: Array = []
	for point in border_points:
		var angle = (point - center).angle()
		points_with_angles.append({"point": point, "angle": angle})
	
	# Sort by angle
	points_with_angles.sort_custom(func(a, b): return a.angle < b.angle)
	
	# Extract the sorted points
	var sorted_points := PackedVector2Array()
	for item in points_with_angles:
		sorted_points.append(item.point)
	
	# Simplify the polygon by removing points that are too close to each other
	var simplified_points := PackedVector2Array()
	var min_distance = 2.0 * polygon_scale  # Minimum distance between points
	
	for i in range(sorted_points.size()):
		var point = sorted_points[i]
		var add_point = true
		
		# Check if this point is too close to the last added point
		if not simplified_points.is_empty():
			var last_point = simplified_points[-1]
			if point.distance_to(last_point) < min_distance:
				add_point = false
		
		if add_point:
			simplified_points.append(point)
	
	return simplified_points

func _reconstruct_polygon_from_segments(segments: Array[PackedVector2Array]) -> PackedVector2Array:
	if segments.is_empty():
		return PackedVector2Array()
	var remaining: Array = segments.duplicate(true)
	var polygon_points := PackedVector2Array()
	var first_segment: PackedVector2Array = remaining.pop_back()
	for point in first_segment:
		polygon_points.append(point)
	var epsilon := 0.1 * polygon_scale
	while not remaining.is_empty():
		var extended := false
		var tail := polygon_points[polygon_points.size() - 1]
		for i in range(remaining.size()):
			var segment: PackedVector2Array = remaining[i]
			if segment.size() < 2:
				remaining.remove_at(i)
				extended = true
				break
			var seg_start := segment[0]
			var seg_end := segment[segment.size() - 1]
			if tail.distance_to(seg_start) <= epsilon:
				for j in range(1, segment.size()):
					polygon_points.append(segment[j])
				remaining.remove_at(i)
				extended = true
				break
			elif tail.distance_to(seg_end) <= epsilon:
				for j in range(segment.size() - 2, -1, -1):
					polygon_points.append(segment[j])
				remaining.remove_at(i)
				extended = true
				break
		if not extended:
			return PackedVector2Array()
	if polygon_points.size() >= 2:
		var first_point := polygon_points[0]
		var last_point := polygon_points[polygon_points.size() - 1]
		if last_point.distance_to(first_point) <= epsilon:
			polygon_points.remove_at(polygon_points.size() - 1)
	return polygon_points

func remove_ownership_overlay(region_id: int) -> void:
	"""Reset the ownership overlay for a region back to neutral."""
	var overlay = _get_or_create_ownership_overlay(region_id)
	if overlay != null:
		overlay.color = _get_neutral_overlay_color()

func _get_or_create_ownership_overlay(region_id: int) -> Polygon2D:
	"""Ensure an ownership overlay exists and matches the region polygon."""
	var region_container = get_region_container_by_id(region_id)
	if region_container == null:
		return null
	var original_polygon = region_container.get_node("Polygon") as Polygon2D
	if original_polygon == null:
		return null
	var overlay: Polygon2D
	var created_overlay := false
	if region_container.has_node("OwnershipOverlay"):
		overlay = region_container.get_node("OwnershipOverlay") as Polygon2D
	else:
		overlay = Polygon2D.new()
		overlay.name = "OwnershipOverlay"
		region_container.add_child(overlay)
		created_overlay = true
	var noisy_polygon_points = _create_noisy_polygon_for_region(region_id)
	if noisy_polygon_points.is_empty():
		noisy_polygon_points = original_polygon.polygon
	overlay.polygon = noisy_polygon_points
	overlay.position = original_polygon.position
	overlay.rotation = original_polygon.rotation
	overlay.scale = original_polygon.scale
	overlay.z_index = original_polygon.z_index + 1
	if created_overlay:
		overlay.color = _get_neutral_overlay_color()
	return overlay

func _get_neutral_overlay_color() -> Color:
	return Color(0.0, 0.0, 0.0, 0.0)


func _build_and_draw_region_graph_overlay() -> void:
	# Skip if graph display is disabled
	if not show_region_graph:
		return
		
	# Build adjacency graph for non-ocean regions
	var Graph := load("res://region_graph.gd")
	if Graph == null:
		return
	non_ocean_graph = Graph.build_non_ocean_adjacency(regions, edges)
	non_ocean_centers = Graph.compute_region_centers(regions)

	# Create overlay node to hold markers and lines
	var overlay := Node2D.new()
	overlay.name = "RegionGraphOverlay"
	# Attach overlay under Map for cleanliness
	if map_root != null:
		map_root.add_child(overlay)
	else:
		add_child(overlay)

	# Optionally draw center markers here, but avoid duplicating if show_region_points is enabled
	if not show_region_points:
		var region_points_container: Node2D = RegionPoints.create_region_points_for_centers(
			non_ocean_centers, 
			polygon_scale, 
			region_point_inner_color
		)
		overlay.add_child(region_points_container)
	else:
		# Fallback to original simple markers if RegionPoints script not found
		for rid in non_ocean_centers.keys():
			var center: Vector2 = non_ocean_centers[rid]
			var marker := ColorRect.new()
			marker.color = Color(0, 0, 0, 0.7)
			var radius := 2.0 * polygon_scale
			marker.position = center - Vector2(radius, radius)
			marker.size = Vector2(radius * 2.0, radius * 2.0)
			overlay.add_child(marker)

	# Draw connections between adjacent regions
	for rid in non_ocean_graph.keys():
		var neighbors: Array = non_ocean_graph[rid]
		var start_center: Vector2 = non_ocean_centers.get(rid, Vector2.ZERO)
		for nbr in neighbors:
			if int(nbr) < int(rid):
				continue  # Avoid drawing twice
			var end_center: Vector2 = non_ocean_centers.get(nbr, Vector2.ZERO)
			if start_center == Vector2.ZERO or end_center == Vector2.ZERO:
				continue
			var line := Line2D.new()
			line.points = PackedVector2Array([start_center, end_center])
			line.width = 1.5 * polygon_scale
			line.default_color = Color(0, 0, 0, 0.5)
			overlay.add_child(line)

func _create_ocean_frame() -> void:
	# Create a textured frame around the map using 4 rectangles
	var map_size = 1000.0 * polygon_scale
	var frame_width = ocean_frame_width * polygon_scale
	var ocean_texture = load("res://images/transparent.png")  # Use same texture as ocean polygons
	
	# Calculate frame rectangle coordinates
	var frame_rects = [
		# Top frame
		{
			"name": "ocean_frame_top",
			"points": [
				Vector2(-frame_width, -frame_width),
				Vector2(map_size + frame_width, -frame_width),
				Vector2(map_size + frame_width, 0),
				Vector2(-frame_width, 0)
			]
		},
		# Bottom frame
		{
			"name": "ocean_frame_bottom",
			"points": [
				Vector2(-frame_width, map_size),
				Vector2(map_size + frame_width, map_size),
				Vector2(map_size + frame_width, map_size + frame_width),
				Vector2(-frame_width, map_size + frame_width)
			]
		},
		# Left frame
		{
			"name": "ocean_frame_left",
			"points": [
				Vector2(-frame_width, 0),
				Vector2(0, 0),
				Vector2(0, map_size),
				Vector2(-frame_width, map_size)
			]
		},
		# Right frame
		{
			"name": "ocean_frame_right",
			"points": [
				Vector2(map_size, 0),
				Vector2(map_size + frame_width, 0),
				Vector2(map_size + frame_width, map_size),
				Vector2(map_size, map_size)
			]
		}
	]
	
	# Create the frame polygons
	for rect_data in frame_rects:
		var frame_polygon := Polygon2D.new()
		frame_polygon.name = rect_data["name"]

		if rect_data["name"] == "ocean_frame_top":
			frame_polygon.position.y = 30
		if rect_data["name"] == "ocean_frame_right":
			frame_polygon.position.x = -35
		
		# Configure exactly like ocean polygons
		frame_polygon.texture = ocean_texture
		frame_polygon.texture_offset = Vector2(500, 500)
		# Scale texture to maintain visual density with scaled polygons  
		frame_polygon.texture_scale = Vector2(1.0 / polygon_scale, 1.0 / polygon_scale)
		# Don't set color - defaults to Color.WHITE like ocean polygons
		
		frame_polygon.polygon = PackedVector2Array(rect_data["points"])
		frame_polygon.z_index = -50  # Behind ocean but in front of background
		if map_node_frame != null:
			map_node_frame.add_child(frame_polygon)
		else:
			add_child(frame_polygon)
	






func _is_ocean_region_coastal(ocean_region_id: int) -> bool:
	# Check if this ocean region has any land neighbors by examining edges
	for edge in edges:
		var r1 := int(edge.get("region1", -1))
		var r2 := int(edge.get("region2", -1))
		
		# Skip invalid edges
		if r1 == -1 or r2 == -1:
			continue
			
		# Check if this edge connects our ocean region to a land region
		var involves_our_ocean := (r1 == ocean_region_id or r2 == ocean_region_id)
		if involves_our_ocean:
			var other_region_id := r1 if r2 == ocean_region_id else r2
			var other_region: Dictionary = region_by_id.get(other_region_id, {})
			if not other_region.is_empty():
				var other_is_ocean := bool(other_region.get("ocean", false))
				if not other_is_ocean:
					return true  # Found a land neighbor
	
	return false  # No land neighbors found

func _create_region_points_for_all_regions() -> void:
	"""
	Creates region points for NON-OCEAN regions using the dedicated RegionPoints script.
	This function is independent of the show_region_graph setting.
	"""
	# Skip if region points display is disabled
	if not show_region_points:
		return
	# Create centers dictionary for NON-OCEAN regions only
	var land_centers: Dictionary = {}
	for region_data in regions:
		var region_id := int(region_data.get("id", -1))
		var center_data = region_data.get("center", [])
		var is_ocean := bool(region_data.get("ocean", false))
		if region_id >= 0 and center_data.size() == 2 and not is_ocean:
			land_centers[region_id] = Vector2(center_data[0], center_data[1])

	if land_centers.is_empty():
	
		return

	# Create region points container (circles) for non-ocean regions
	var region_points_container: Node2D = RegionPoints.create_region_points_for_centers(
		land_centers,
		polygon_scale,
		region_point_inner_color
	)
	region_points_container.name = "NonOceanRegionPoints"
	region_points_container.z_index = 200  # High z-index to ensure visibility

	add_child(region_points_container)

func set_center_markers_enabled(enabled: bool) -> void:
	center_markers_enabled = enabled
	_refresh_center_markers()

func _refresh_center_markers() -> void:
	_clear_center_markers()
	if not center_markers_enabled:
		return
	_ensure_map_nodes()
	center_marker_container = Node2D.new()
	center_marker_container.name = "CenterMarkers"
	map_node_regions.add_child(center_marker_container)
	var half := 2.0 * polygon_scale
	var square := PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half)
	])
	for region_id in region_container_by_id.keys():
		var region_node: Region = region_container_by_id[region_id]
		if region_node.is_ocean_region():
			continue
		var center := region_node.center
		var marker := Polygon2D.new()
		marker.polygon = square
		marker.color = Color(1, 0, 0, 0.9)
		marker.position = center
		marker.z_index = 2000
		center_marker_container.add_child(marker)

func _clear_center_markers() -> void:
	if center_marker_container != null:
		center_marker_container.queue_free()
		center_marker_container = null


func get_region_container_by_id(region_id: int) -> Node:
	"""Get region container by region ID (helper for other systems)"""
	return region_container_by_id.get(region_id, null)

func _assign_region_name_if_available(region: Region) -> void:
	"""Assign a name to the region using RegionManager if available"""
	if region.is_ocean_region():
		return  # Don't name ocean regions
		
	# Try to find RegionManager in the click manager
	var click_manager = get_node_or_null("../ClickManager")
	var region_manager = null
	
	if click_manager and click_manager.has_method("get_region_manager"):
		region_manager = click_manager.get_region_manager()
	
	# If no RegionManager available, create one
	if region_manager == null:
		region_manager = RegionManager.new(self)

	
	if region_manager and region_manager.has_method("assign_region_name"):
		var assigned_name = region_manager.assign_region_name(region)
		region.set_region_name(assigned_name)

		return
	
	# Fallback: assign a default name if RegionManager isn't available
	var fallback_name = "Region " + str(region.get_region_id())
	region.set_region_name(fallback_name)

func regenerate_borders() -> void:
	"""Refresh existing border visuals for the full map"""
	border_manager.refresh_all_borders()

func regenerate_borders_for_region(region_id: int) -> void:
	"""Refresh borders for a single region plus its neighbors"""
	border_manager.refresh_region_and_neighbors(region_id)
	

func refresh_region_visual(region_id: int) -> void:
	"""Refresh the visual for a single region after type change (editor mode)."""
	var region_container = get_region_container_by_id(region_id)
	var region := region_container as Region
	var polygon := region_container.get_node("Polygon") as Polygon2D
	# Remove existing icon sprites under polygon
	for child in polygon.get_children():
		if child is Sprite2D:
			child.queue_free()
	# Apply ocean or land visuals
	if region.is_ocean_region():
		# Ocean-like look
		polygon.texture = load("res://images/sea_transparent_large.png")
		polygon.texture_scale = Vector2(1.0 / polygon_scale, 1.0 / polygon_scale)
		polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	else:
		# Restore land grass texture
		polygon.texture = load("res://images/background4grass7.png")
		polygon.texture_scale = Vector2(1.0 / polygon_scale, 1.0 / polygon_scale)
		polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		polygon.visible = true
		# Re-add biome icon
		var rdata: Dictionary = region_by_id.get(region_id, {})
		var biome_str := region.get_biome()
		if biome_str == "forest_hills":
			biome_str = "hill_forest"
		rdata["biome"] = biome_str
		region_by_id[region_id] = rdata
		RegionIconManager.place_region_icon(polygon, rdata, polygon_scale, map_size)
	# Regenerate borders for region and neighbors
	regenerate_borders_for_region(region_id)
	_sort_mountain_icon_z_indices()
