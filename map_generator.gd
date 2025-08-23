extends Node2D

class_name MapGenerator

# Configuration
@export var data_file_path: String = "data9.json"
@export var noisy_edges_enabled: bool = true
@export var debug_draw_overlay: bool = false
@export var show_region_colors: bool = false
@export var show_region_graph: bool = false
@export var show_region_points: bool = false
@export var region_point_inner_color: Color = Color.RED
@export var polygon_scale: float = 2.0
@export var ocean_frame_width: float = 500.0

# Global icon sizing (tune this to adjust biome icon sizes)
const BIOME_ICON_SCALE: float = 0.15



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


func _ready() -> void:
	generate_map()

func generate_map() -> void:
	_load_json_data()
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
	var file = FileAccess.open(data_file_path, FileAccess.READ)
	if file == null:
		print("[MapGenerator] ERROR: Could not open file: ", data_file_path)
		return
		
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("[MapGenerator] ERROR: Could not parse JSON: ", json.error_string)
		return

	map_data = json.data
	regions = map_data.get("regions", [])
	edges = map_data.get("edges", [])
	region_by_id.clear()
	for r in regions:
		var rid = int(r.get("id", -1))
		if rid >= 0:
			region_by_id[rid] = r
	

	var meta = map_data.get("meta", {})

	
	# Scale all coordinates if polygon_scale != 1.0
	if polygon_scale != 1.0:
		_scale_map_data()
	

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
		if child is Polygon2D or child is ColorRect or child is Sprite2D or child is Line2D:
			remove_child(child)
			child.queue_free()

	_ensure_map_nodes()
	_clear_children(map_node_regions)
	_clear_children(map_node_ocean)
	_clear_children(map_node_frame)
	region_container_by_id.clear()

	# Add background image
	var background := Sprite2D.new()
	background.texture = load("res://images/background2.png")
	var map_center = 500.0 * polygon_scale
	background.position = Vector2(map_center, map_center)  # Center it
	background.scale = Vector2(2 * polygon_scale, 2 * polygon_scale)  # Scale with polygons
	background.z_index = -100
	if map_root != null:
		map_root.add_child(background)
	else:
		add_child(background)

	# Create blue ocean frame around the map
	_create_ocean_frame()

	# Create individual ocean polygons with sea or coast texture
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
				
				# Check if this ocean region is adjacent to land
				var is_coastal := _is_ocean_region_coastal(region_id)
				if is_coastal:
					ocean_pg.texture = load("res://images/coast.png")
				else:
					ocean_pg.texture = load("res://images/sea_transparent_large.png")
				
				ocean_pg.texture_offset = Vector2(500, 500)
				
				# Scale texture to maintain visual density with scaled polygons
				ocean_pg.texture_scale = Vector2(1.0 / polygon_scale, 1.0 / polygon_scale)
				ocean_pg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				
				# Calculate texture offset based on polygon center to create seamless appearance
				# var center_data = region_data.get("center", [500, 500])
				# var center := Vector2(center_data[0], center_data[1])
				
				ocean_pg.polygon = poly
				
				ocean_pg.z_index = 0  # Ocean on same level as land
				map_node_ocean.add_child(ocean_pg)
				# print("[Debug] Created ocean region ID: ", region_id, " biome: ", region_data.get("biome", "unknown"), " coastal: ", is_coastal)
	


	# Build non-ocean polygons
	var _region_count := 0
	var _total_regions := 0
	var land_region_ids: Array[int] = []
	for region_data in regions:
		_total_regions += 1
		var is_ocean := bool(region_data.get("ocean", false))
		var region_id := int(region_data.get("id", -1))
		if not is_ocean:
			land_region_ids.append(region_id)
			_region_count += 1
			# Create region container structure with Region script
			var region_container := Node2D.new()
			# Explicitly attach the Region script
			region_container.set_script(load("res://region.gd"))
			region_container.setup_region(region_data)
			
			# Assign name through RegionManager if available
			_assign_region_name_if_available(region_container)
			
			map_node_regions.add_child(region_container)
			region_container_by_id[region_id] = region_container
			
			# Add polygon under region container
			var _polygon_node := _add_region_polygon_node(region_data, null, "Polygon", region_container)
			
			# Add region point under region container
			if show_region_points:
				var center_data = region_data.get("center", [])
				if center_data.size() == 2:
					var center := Vector2(center_data[0], center_data[1])
					var region_point := RegionPoints.create_region_point(center, polygon_scale, region_point_inner_color)
					region_point.name = "RegionPoint"
					region_container.add_child(region_point)
			
			# Add Borders container
			var borders_node := Node2D.new()
			borders_node.name = "Borders"
			region_container.add_child(borders_node)
	
	# print("[MapGenerator] Total regions in JSON: ", total_regions)
	# print("[MapGenerator] Ocean regions: ", ocean_count, ", Land regions: ", region_count)
	# print("[MapGenerator] Coverage check: ", ocean_count + region_count, " should equal ", total_regions)
	
	# Check for overlapping IDs (this should never happen!)
	for ocean_id in ocean_region_ids:
		if ocean_id in land_region_ids:
			print("[ERROR] Region ID ", ocean_id, " appears in BOTH ocean and land lists!")
	
	# print("[Debug] Ocean IDs: ", ocean_region_ids)
	# print("[Debug] Land IDs: ", land_region_ids)

	# Draw noisy borders from edge data with correct quadrilateral constraints
	_draw_region_borders()

	# Build adjacency graph for non-ocean regions and draw overlay
	_build_and_draw_region_graph_overlay()


	# print("[MapGenerator] Rendered edges: ", edges.size())

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
	
	if edge_ids.is_empty():
		print("[WARNING] Region ", region_id, " has no edges!")
		return PackedVector2Array()
		
	var pts: Array[Vector2] = []
	var invalid_points := 0
	
	for eid in edge_ids:
		var edge_id := int(eid)
		
		# Skip invalid edge IDs (negative values are placeholders/invalid)
		if edge_id < 0:
			continue
			
		if edge_id >= edges.size():
			print("[ERROR] Region ", region_id, " references invalid edge ID: ", eid)
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
				print("[WARNING] Region ", region_id, " edge ", edge_id, " has invalid start point: ", point_a)
				
		if b_arr.size() == 2:
			var point_b := Vector2(b_arr[0], b_arr[1])
			if Utils.is_valid_coordinate(point_b, polygon_scale):
				pts.append(point_b)
			else:
				invalid_points += 1
				print("[WARNING] Region ", region_id, " edge ", edge_id, " has invalid end point: ", point_b)
	
	if invalid_points > 0:
		print("[WARNING] Region ", region_id, " had ", invalid_points, " invalid coordinates filtered out")
	
	if pts.size() < 3:
		# print("[ERROR] Region ", region_id, " has insufficient valid points: ", pts.size())
		return PackedVector2Array()
		
	return Utils.dedup_and_sort_polygon(pts, center)

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
	var cmeta: Array = region_data.get("center", [])
	if cmeta.size() == 2:
		var cx := float(cmeta[0])
		var cy := float(cmeta[1])
		pg.set_meta("center", Vector2(cx, cy))
	# Only set color for debug modes or explicit color override
	if (polygon_color != null):
		pg.color = polygon_color
	elif show_region_colors:
		pg.color = Color(rng.randf(), rng.randf(), rng.randf(), 1.0)  # Random colors for verification
	# Otherwise don't set pg.color at all - let it default to white like ocean polygons
	pg.polygon = poly

	# Apply grass texture to all non-ocean regions
	pg.texture = load("res://images/grass.png")
	pg.texture_scale = Vector2(1.0 / polygon_scale * 5.0, 1.0 / polygon_scale * 5.0)
	pg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	pg.z_index = 0  # Land on same level as ocean
	if parent_container != null:
		parent_container.add_child(pg)
	else:
		add_child(pg)
	# print("[Debug] Created land region ID: ", region_data.get("id", "unknown"), " name: ", node_name, " at z_index: ", pg.z_index)

	# Add biome icons based on mapping rules
	var biome_name := String(region_data.get("biome", ""))
	var icon_path := BiomeManager.get_icon_path_for_biome(biome_name)
	if icon_path != "":
		# Check if this is a mountain biome and use special handling
		if biome_name.to_lower() == "mountains":
			Utils.create_mountain_icon_with_size_modifier(pg, region_data, icon_path, BIOME_ICON_SCALE, polygon_scale)
		else:
			_add_icon_at_region_center(pg, region_data, icon_path, biome_name)

	return pg

func _draw_region_borders() -> void:
	"""Draw borders for each region - each region gets its complete border perimeter"""
	var rng := RandomNumberGenerator.new()
	rng.seed = noisy_edge_seed
	var borders_created := 0
	
	# For each non-ocean region, create its complete border set
	for region_data in regions:
		var region_id := int(region_data.get("id", -1))
		var is_ocean := bool(region_data.get("ocean", false))
		
		if is_ocean or region_id == -1:
			continue
			
		# Get this region's container
		var region_container = region_container_by_id.get(region_id)
		if region_container == null:
			continue
			
		var borders_node = region_container.get_node_or_null("Borders")
		if borders_node == null:
			continue
			
		# Find ALL edges that involve this region and create borders
		var region_borders_created = _create_borders_for_region(region_id, region_data, borders_node, rng)
		borders_created += region_borders_created
	
	print("[MapGenerator] Created ", borders_created, " border lines total (region-centric)")


func _create_borders_for_region(region_id: int, region_data: Dictionary, borders_container: Node2D, rng: RandomNumberGenerator) -> int:
	"""Create all border lines for a specific region"""
	var borders_created := 0
	
	# Find all edges where this region is involved
	for edge in edges:
		var r0 := int(edge.get("region1", -1))
		var r1 := int(edge.get("region2", -1))
		
		# Skip if this region is not involved in this edge
		if r0 != region_id and r1 != region_id:
			continue
			
		# Skip invalid edges
		if r0 == -1 or r1 == -1:
			continue
			
		# Get the OTHER region
		var other_region_id = r0 if r1 == region_id else r1
		var other_region_data = region_by_id.get(other_region_id, {})
		if other_region_data.is_empty():
			continue
			
		# Check if we should draw this border (skip ocean-ocean and mountain-mountain)
		var this_is_ocean = bool(region_data.get("ocean", false))
		var other_is_ocean = bool(other_region_data.get("ocean", false))
		var this_is_mountain = _is_mountain_region(region_data)
		var other_is_mountain = _is_mountain_region(other_region_data)
		
		if this_is_ocean and other_is_ocean:
			continue
		if this_is_mountain and other_is_mountain:
			continue
			
		# Create the border line for THIS region
		if _create_border_line_for_region(edge, region_id, other_region_id, borders_container, rng):
			borders_created += 1
	
	return borders_created

func _create_border_line_for_region(edge: Dictionary, region_id: int, other_region_id: int, borders_container: Node2D, rng: RandomNumberGenerator) -> bool:
	"""Create a single border line for a region"""
	# Extract edge data (same as current system)
	var a_arr: Array = edge.get("start", [])
	var b_arr: Array = edge.get("end", [])
	var c0_arr: Array = edge.get("region1_center", [])
	var c1_arr: Array = edge.get("region2_center", [])
	
	if a_arr.size() != 2 or b_arr.size() != 2 or c0_arr.size() != 2 or c1_arr.size() != 2:
		return false
		
	var a := Vector2(a_arr[0], a_arr[1])
	var b := Vector2(b_arr[0], b_arr[1])
	var p := Vector2(c0_arr[0], c0_arr[1])
	var q := Vector2(c1_arr[0], c1_arr[1])
	
	# Create consistent seed for this specific edge to ensure identical noise patterns
	var edge_seed = _generate_edge_seed(edge)
	rng.seed = edge_seed
	
	# Create noisy subdivision (identical to current system)
	var seg := PackedVector2Array()
	seg.append(a)
	var mid_points := NoisyEdges.recursive_subdivision(a, b, p, q, rng, noisy_edge_length, noisy_edge_amplitude)
	for mp in mid_points:
		seg.append(mp)
	seg.append(b)
	
	# Check ownership and apply colored border logic
	var region_owner = _get_region_owner(region_id)
	var other_owner = _get_region_owner(other_region_id)
	var is_external_border = _is_external_border_for_region(region_id, other_region_id)
	var is_mountain_border = _is_mountain_border_for_region(region_id, other_region_id)
	
	# Determine border type and styling based on ownership
	# COMMENTED OUT: Mountain border special handling - using standard borders instead
	#if is_mountain_border:
		## Mountain border: Solid black border
		#var line := Line2D.new()
		#line.points = seg
		#line.closed = false
		#line.width = 3.0 * polygon_scale
		#line.default_color = Color.BLACK  # Solid black for mountain borders
		#borders_container.add_child(line)
	if is_external_border:
		# Ocean border: Double border system
		if region_owner != -1:
			# Owned region vs ocean: Create offset colored border for land side
			_create_land_ocean_offset_border_line(seg, region_owner, region_id, borders_container)
			# Create offset black border for ocean side (simulated)
			_create_ocean_offset_border_line(seg, region_id, borders_container)
		else:
			# Unowned region vs ocean: Standard brown border
			var line := Line2D.new()
			line.points = seg
			line.closed = false
			line.width = 3.0 * polygon_scale
			line.default_color = Color8(0x41, 0x2c, 0x16, 255)  # Brown for external (ocean)
			borders_container.add_child(line)
	elif region_owner != -1 and other_owner != -1 and region_owner != other_owner:
		# Different owners (enemy border): Create offset colored border
		_create_offset_border_line(seg, region_owner, other_region_id, region_id, borders_container)
	elif region_owner != -1 and other_owner == -1:
		# My region vs neutral: Single colored border (thick like ocean borders)
		var line := Line2D.new()
		line.points = seg
		line.closed = false
		line.width = 3.0 * polygon_scale
		line.default_color = _get_player_border_color(region_owner)
		borders_container.add_child(line)
	else:
		# Same owner or unowned: Default style
		var line := Line2D.new()
		line.points = seg
		line.closed = false
		line.width = 1.5 * polygon_scale
		line.default_color = Color8(0x00, 0x00, 0x00, 50)   # Thin black for internal
		borders_container.add_child(line)
	
	return true

func _is_external_border_for_region(region_id: int, other_region_id: int) -> bool:
	"""Determine if a border is external (touches ocean) for a specific region"""
	var other_region_data = region_by_id.get(other_region_id, {})
	if other_region_data.is_empty():
		return true  # Unknown region = external
		
	var other_is_ocean = bool(other_region_data.get("ocean", false))
	return other_is_ocean  # External if touching ocean

func _is_mountain_border_for_region(region_id: int, other_region_id: int) -> bool:
	"""Determine if a border touches a mountain region"""
	var other_region_data = region_by_id.get(other_region_id, {})
	if other_region_data.is_empty():
		return false  # Unknown region = not mountain
		
	return _is_mountain_region(other_region_data)  # Mountain if other region is mountain

func _generate_edge_seed(edge: Dictionary) -> int:
	"""Generate a consistent seed for an edge based on its coordinates"""
	# Use edge start/end coordinates to create a unique, consistent seed
	var a_arr: Array = edge.get("start", [])
	var b_arr: Array = edge.get("end", [])
	
	if a_arr.size() != 2 or b_arr.size() != 2:
		return noisy_edge_seed  # Fallback to global seed
	
	# Create a hash based on the edge coordinates (order-independent)
	var x1 = float(a_arr[0])
	var y1 = float(a_arr[1])
	var x2 = float(b_arr[0])
	var y2 = float(b_arr[1])
	
	# Ensure consistent ordering regardless of which region processes the edge first
	if x1 > x2 or (x1 == x2 and y1 > y2):
		var temp_x = x1
		var temp_y = y1
		x1 = x2
		y1 = y2
		x2 = temp_x
		y2 = temp_y
	
	# Create a unique hash for this edge
	var hash_value = int(x1 * 1000 + y1 * 1000000 + x2 * 1000000000 + y2 * 1000000000000)
	return noisy_edge_seed + hash_value

func _generate_edge_seed_from_points(point_a: Vector2, point_b: Vector2) -> int:
	"""Generate consistent seed for edge between two Vector2 points"""
	var x1 = point_a.x
	var y1 = point_a.y
	var x2 = point_b.x
	var y2 = point_b.y
	
	# Ensure consistent ordering regardless of which region processes the edge first
	if x1 > x2 or (x1 == x2 and y1 > y2):
		var temp_x = x1
		var temp_y = y1
		x1 = x2
		y1 = y2
		x2 = temp_x
		y2 = temp_y
	
	# Create a unique hash for this edge
	var hash_value = int(x1 * 1000 + y1 * 1000000 + x2 * 1000000000 + y2 * 1000000000000)
	return noisy_edge_seed + hash_value

func _get_region_owner(region_id: int) -> int:
	"""Get the owner of a region, returns -1 if unowned"""
	# Try to find RegionManager in the click manager
	var click_manager = get_node_or_null("../ClickManager")
	if click_manager and click_manager.has_method("get_region_manager"):
		var region_manager = click_manager.get_region_manager()
		if region_manager and region_manager.has_method("get_region_owner"):
			return region_manager.get_region_owner(region_id)
	
	return -1  # Unowned if RegionManager not found


func _get_player_color(player_id: int) -> Color:
	"""Get the color for a specific player"""
	var color = GameParameters.get_player_color(player_id)
	color.a = 0.5  # 50% transparency
	return color

func _get_player_border_color(player_id: int) -> Color:
	"""Get enhanced color for player borders - more saturated and darker"""
	var base_color = GameParameters.get_player_color(player_id)
	
	# Special handling for white color (Player 5) to avoid pink/violet tints
	if player_id == 5:  # Player 5 is white
		# For white, simply darken without changing saturation to create grey
		var grey_value = max(GameParameters.BORDER_MIN_VALUE, base_color.v - GameParameters.BORDER_VALUE_REDUCTION)
		var border_color = Color(grey_value, grey_value, grey_value, GameParameters.BORDER_OPACITY)
		return border_color
	
	# For colored players, enhance saturation and darken
	var hue = base_color.h
	var saturation = base_color.s
	var value = base_color.v
	
	# Apply enhancement parameters from GameParameters
	var enhanced_saturation = min(1.0, saturation + GameParameters.BORDER_SATURATION_BOOST)
	var enhanced_value = max(GameParameters.BORDER_MIN_VALUE, value - GameParameters.BORDER_VALUE_REDUCTION)
	
	# Create the enhanced border color
	var border_color = Color.from_hsv(hue, enhanced_saturation, enhanced_value)
	border_color.a = GameParameters.BORDER_OPACITY
	
	return border_color

func create_ownership_overlay(region_id: int, player_id: int) -> void:
	"""Create a semi-transparent colored polygon overlay for owned regions"""
	var region_container = get_region_container_by_id(region_id)
	if region_container == null:
		print("[MapGenerator] Error: Could not find region container for ID: ", region_id)
		return
	
	# Get the original polygon for positioning reference
	var original_polygon = region_container.get_node_or_null("Polygon") as Polygon2D
	if original_polygon == null:
		print("[MapGenerator] Error: Could not find original polygon for region: ", region_id)
		return
	
	# Remove existing ownership overlay if it exists
	var existing_overlay = region_container.get_node_or_null("OwnershipOverlay")
	if existing_overlay != null:
		existing_overlay.queue_free()
	
	# Create noisy polygon points that match the border noise
	var noisy_polygon_points = _create_noisy_polygon_for_region(region_id)
	if noisy_polygon_points.is_empty():
		print("[MapGenerator] Warning: Could not create noisy polygon for region ", region_id)
		return
	
	# Create new ownership overlay polygon
	var overlay_polygon = Polygon2D.new()
	overlay_polygon.name = "OwnershipOverlay"
	
	# Use the noisy polygon points
	overlay_polygon.polygon = noisy_polygon_points
	overlay_polygon.position = original_polygon.position
	overlay_polygon.rotation = original_polygon.rotation
	overlay_polygon.scale = original_polygon.scale
	
	# Set player color with high transparency
	var player_color = _get_player_color(player_id)
	player_color.a = 0.25  # High transparency (15%)
	overlay_polygon.color = player_color
	
	# Set z-index to appear above the original polygon but below other elements
	overlay_polygon.z_index = original_polygon.z_index + 1
	
	# Add to region container
	region_container.add_child(overlay_polygon)
	
	print("[MapGenerator] Created ownership overlay for region ", region_id, " with color ", player_color)

func _create_noisy_polygon_for_region(region_id: int) -> PackedVector2Array:
	"""Extract polygon points directly from the existing Line2D borders"""
	var region_container = get_region_container_by_id(region_id)
	if region_container == null:
		return PackedVector2Array()
	
	# Get the borders container which has all the Line2D objects
	var borders_container = region_container.get_node_or_null("Borders")
	if borders_container == null:
		print("[MapGenerator] No borders found for region ", region_id)
		# Fallback to original polygon
		var original_polygon = region_container.get_node_or_null("Polygon") as Polygon2D
		if original_polygon:
			return original_polygon.polygon
		return PackedVector2Array()
	
	# Collect all Line2D objects
	var line2d_objects: Array[Line2D] = []
	for child in borders_container.get_children():
		if child is Line2D:
			line2d_objects.append(child as Line2D)
	
	if line2d_objects.is_empty():
		print("[MapGenerator] No Line2D borders found for region ", region_id)
		return PackedVector2Array()
	
	# Extract all points from all Line2D objects
	var all_border_points := PackedVector2Array()
	for line2d in line2d_objects:
		for point in line2d.points:
			all_border_points.append(point)
	
	if all_border_points.size() < 3:
		return PackedVector2Array()
	
	# Create a polygon from these points using convex hull or similar
	# For now, use a simple approach: get the boundary points
	var polygon_points = _create_polygon_from_border_points(all_border_points)
	
	print("[MapGenerator] Created noisy polygon with ", polygon_points.size(), " points from ", all_border_points.size(), " border points")
	return polygon_points

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

func remove_ownership_overlay(region_id: int) -> void:
	"""Remove the ownership overlay for a region"""
	var region_container = get_region_container_by_id(region_id)
	if region_container == null:
		return
	
	var overlay = region_container.get_node_or_null("OwnershipOverlay")
	if overlay != null:
		overlay.queue_free()

func _create_offset_border_line(original_points: PackedVector2Array, player_id: int, other_region_id: int, current_region_id: int, borders_container: Node2D) -> void:
	"""Create an offset border line for ownership-based borders"""
	if original_points.size() < 2:
		return
	
	var offset_distance = 1.0 * polygon_scale  # Offset distance in pixels
	
	# Determine offset direction based on region ID ordering
	# This ensures consistent opposite directions for the two regions
	var offset_direction = 1.0 if current_region_id < other_region_id else -1.0
	
	var offset_points := PackedVector2Array()
	
	# Calculate offset for each point
	for i in range(original_points.size()):
		var current_point = original_points[i]
		var offset_vector = Vector2.ZERO
		
		if i == 0:
			# First point: use direction to next point
			var next_point = original_points[i + 1]
			var direction = (next_point - current_point).normalized()
			offset_vector = Vector2(-direction.y, direction.x) * offset_distance * offset_direction
		elif i == original_points.size() - 1:
			# Last point: use direction from previous point
			var prev_point = original_points[i - 1]
			var direction = (current_point - prev_point).normalized()
			offset_vector = Vector2(-direction.y, direction.x) * offset_distance * offset_direction
		else:
			# Middle points: average of both directions for smooth curves
			var prev_point = original_points[i - 1]
			var next_point = original_points[i + 1]
			var dir1 = (current_point - prev_point).normalized()
			var dir2 = (next_point - current_point).normalized()
			var avg_direction = (dir1 + dir2).normalized()
			offset_vector = Vector2(-avg_direction.y, avg_direction.x) * offset_distance * offset_direction
		
		offset_points.append(current_point + offset_vector)
	
	# Create the offset border line
	var line := Line2D.new()
	line.points = offset_points
	line.closed = false
	line.width = 2.0 * polygon_scale
	line.default_color = _get_player_border_color(player_id)
	
	borders_container.add_child(line)

func _create_land_ocean_offset_border_line(original_points: PackedVector2Array, player_id: int, current_region_id: int, borders_container: Node2D) -> void:
	"""Create an offset colored border line for land side of ocean border"""
	if original_points.size() < 2:
		return
	
	var offset_distance = 1.0 * polygon_scale  # Same offset distance as enemy borders
	
	# Determine which side is land by checking region center position
	var land_offset_direction = _get_land_side_offset_direction(original_points, current_region_id)
	
	var offset_points := PackedVector2Array()
	
	# Calculate offset for each point (same logic as colored borders)
	for i in range(original_points.size()):
		var current_point = original_points[i]
		var offset_vector = Vector2.ZERO
		
		if i == 0:
			# First point: use direction to next point
			var next_point = original_points[i + 1]
			var direction = (next_point - current_point).normalized()
			offset_vector = Vector2(-direction.y, direction.x) * offset_distance * land_offset_direction
		elif i == original_points.size() - 1:
			# Last point: use direction from previous point
			var prev_point = original_points[i - 1]
			var direction = (current_point - prev_point).normalized()
			offset_vector = Vector2(-direction.y, direction.x) * offset_distance * land_offset_direction
		else:
			# Middle points: average of both directions for smooth curves
			var prev_point = original_points[i - 1]
			var next_point = original_points[i + 1]
			var dir1 = (current_point - prev_point).normalized()
			var dir2 = (next_point - current_point).normalized()
			var avg_direction = (dir1 + dir2).normalized()
			offset_vector = Vector2(-avg_direction.y, avg_direction.x) * offset_distance * land_offset_direction
		
		offset_points.append(current_point + offset_vector)
	
	# Create the offset border line with player color
	var line := Line2D.new()
	line.points = offset_points
	line.closed = false
	line.width = 2.0 * polygon_scale
	line.default_color = _get_player_border_color(player_id)
	
	borders_container.add_child(line)

func _create_ocean_offset_border_line(original_points: PackedVector2Array, current_region_id: int, borders_container: Node2D) -> void:
	"""Create an offset black border line for ocean side"""
	if original_points.size() < 2:
		return
	
	var offset_distance = 1.0 * polygon_scale  # Same offset distance as enemy borders
	
	# Ocean gets the opposite offset direction from the land region
	var land_offset_direction = _get_land_side_offset_direction(original_points, current_region_id)
	var ocean_offset_direction = -land_offset_direction  # Always opposite
	
	var offset_points := PackedVector2Array()
	
	# Calculate offset for each point (same logic as colored borders)
	for i in range(original_points.size()):
		var current_point = original_points[i]
		var offset_vector = Vector2.ZERO
		
		if i == 0:
			# First point: use direction to next point
			var next_point = original_points[i + 1]
			var direction = (next_point - current_point).normalized()
			offset_vector = Vector2(-direction.y, direction.x) * offset_distance * ocean_offset_direction
		elif i == original_points.size() - 1:
			# Last point: use direction from previous point
			var prev_point = original_points[i - 1]
			var direction = (current_point - prev_point).normalized()
			offset_vector = Vector2(-direction.y, direction.x) * offset_distance * ocean_offset_direction
		else:
			# Middle points: average of both directions for smooth curves
			var prev_point = original_points[i - 1]
			var next_point = original_points[i + 1]
			var dir1 = (current_point - prev_point).normalized()
			var dir2 = (next_point - current_point).normalized()
			var avg_direction = (dir1 + dir2).normalized()
			offset_vector = Vector2(-avg_direction.y, avg_direction.x) * offset_distance * ocean_offset_direction
		
		offset_points.append(current_point + offset_vector)
	
	# Create the offset border line with black color
	var line := Line2D.new()
	line.points = offset_points
	line.closed = false
	line.width = 2.0 * polygon_scale
	line.default_color = Color.BLACK
	
	borders_container.add_child(line)

func _get_land_side_offset_direction(edge_points: PackedVector2Array, region_id: int) -> float:
	"""Determine which side of the edge is land by checking region center position"""
	if edge_points.size() < 2:
		return 1.0
	
	# Get region center
	var region_container = region_container_by_id.get(region_id)
	if region_container == null:
		return 1.0
	
	var region = region_container as Region
	if region == null:
		return 1.0
	
	# Get region center from the region data
	var center_data = []
	for region_data in regions:
		if int(region_data.get("id", -1)) == region_id:
			center_data = region_data.get("center", [])
			break
	
	if center_data.size() != 2:
		return 1.0
	
	var region_center = Vector2(center_data[0], center_data[1])
	
	# Calculate edge midpoint and direction
	var edge_start = edge_points[0]
	var edge_end = edge_points[edge_points.size() - 1]
	var edge_midpoint = (edge_start + edge_end) * 0.5
	var edge_direction = (edge_end - edge_start).normalized()
	
	# Calculate perpendicular vector (both directions)
	var perp_vector = Vector2(-edge_direction.y, edge_direction.x)
	
	# Test which direction points toward the region center
	var to_center = (region_center - edge_midpoint).normalized()
	var dot_product = perp_vector.dot(to_center)
	
	# Return +1 if perpendicular points toward center, -1 if away
	return 1.0 if dot_product > 0 else -1.0


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
	var ocean_texture = load("res://images/sea_transparent_large.png")  # Use same texture as ocean polygons
	
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
	






func _is_mountain_region(region_data: Dictionary) -> bool:
	"""Check if a region is a mountain region (non-interactive terrain like ocean)"""
	var biome_name := String(region_data.get("biome", "")).to_lower()
	return biome_name == "mountains"

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

func _add_icon_at_region_center(parent_pg: Polygon2D, region_data: Dictionary, icon_path: String, biome_name: String = "") -> void:
	if icon_path == "":
		return
	var center_data = region_data.get("center", [500, 500])
	if center_data.size() != 2:
		return
	var center := Vector2(center_data[0], center_data[1])
	var icon := Sprite2D.new()
	icon.texture = load(icon_path)
	if icon.texture == null:
		return
	icon.position = center + Vector2(0, -30)
	
	# Use forest-specific scale for forest biomes, otherwise use general biome scale
	var icon_scale: float
	if biome_name.to_lower() == "forest":
		icon_scale = GameParameters.FOREST_ICON_SCALE
	else:
		icon_scale = GameParameters.BIOME_ICON_SCALE
	
	icon.scale = Vector2(icon_scale * polygon_scale, icon_scale * polygon_scale)
	icon.z_index = parent_pg.z_index + 10
	icon.modulate.a = 0.85  # High transparency (15%)
	parent_pg.add_child(icon)

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
	"""Regenerate all region borders when ownership changes"""
	# Clear existing borders
	var regions_node = get_node("Regions")
		
	for region_container in regions_node.get_children():
		var borders_node = region_container.get_node_or_null("Borders")
		if borders_node:
			for border in borders_node.get_children():
				border.queue_free()
	
	# Regenerate borders
	_draw_region_borders()

func regenerate_borders_for_region(region_id: int) -> void:
	"""Regenerate borders for a specific region and its neighbors (more efficient)"""
	var click_manager = get_node_or_null("../ClickManager")
	if not click_manager or not click_manager.has_method("get_region_manager"):
		# Fallback to full regeneration
		regenerate_borders()
		return
	
	var region_manager = click_manager.get_region_manager()
	if not region_manager or not region_manager.has_method("get_neighbor_regions"):
		# Fallback to full regeneration
		regenerate_borders()
		return
	
	# Get all regions that need border updates (the region + its neighbors)
	var regions_to_update = [region_id]
	var neighbors = region_manager.get_neighbor_regions(region_id)
	for neighbor_id in neighbors:
		regions_to_update.append(neighbor_id)
	
	# Clear borders for affected regions
	var regions_node = get_node("Regions")
	
	for region_container in regions_node.get_children():
		if region_container.has_method("get_region_id"):
			var container_region_id = region_container.get_region_id()
			if container_region_id in regions_to_update:
				var borders_node = region_container.get_node_or_null("Borders")
				if borders_node:
					for border in borders_node.get_children():
						border.queue_free()
	
	# Regenerate borders only for affected regions
	# We need to process edges that connect any of the affected regions
	var rng = RandomNumberGenerator.new()
	rng.seed = noisy_edge_seed
	
	for edge in edges:
		var region1_id = int(edge.get("region1", -1))
		var region2_id = int(edge.get("region2", -1))
		
		# Check if this edge involves any of our updated regions
		if region1_id in regions_to_update or region2_id in regions_to_update:
			# Process the edge for both regions
			if region1_id != -1 and region1_id in regions_to_update:
				var region1_container = get_region_container_by_id(region1_id)
				if region1_container:
					var borders_container = region1_container.get_node_or_null("Borders")
					if borders_container:
						_create_border_line_for_region(edge, region1_id, region2_id, borders_container, rng)
			
			if region2_id != -1 and region2_id in regions_to_update:
				var region2_container = get_region_container_by_id(region2_id)
				if region2_container:
					var borders_container = region2_container.get_node_or_null("Borders")
					if borders_container:
						_create_border_line_for_region(edge, region2_id, region1_id, borders_container, rng)
	
