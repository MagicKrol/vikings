extends RefCounted

class_name Utils

static func hex_to_color(hex: String) -> Color:
	# Convert hex string like "#44447a" to Color
	# Remove # and parse as hex
	var hex_clean := hex.substr(1)
	var r := ("0x" + hex_clean.substr(0, 2)).to_int() / 255.0
	var g := ("0x" + hex_clean.substr(2, 2)).to_int() / 255.0
	var b := ("0x" + hex_clean.substr(4, 2)).to_int() / 255.0
	return Color(r, g, b)

static func build_region_promotion_message(region_name: String, new_level: RegionLevelEnum.Level) -> String:
	return region_name + " has been promoted to " + RegionLevelEnum.level_to_string(new_level)

static func is_clockwise(poly: PackedVector2Array) -> bool:
	# Calculate the signed area to determine winding order
	if poly.size() < 3:
		return false
		
	var signed_area: float = 0.0
	for i in range(poly.size()):
		var j = (i + 1) % poly.size()
		signed_area += (poly[j].x - poly[i].x) * (poly[j].y + poly[i].y)
	
	return signed_area > 0.0

static func is_valid_coordinate(point: Vector2, polygon_scale: float) -> bool:
	# Filter out invalid coordinates that cause broken polygons
	
	# Reject NaN or infinite values (critical)
	if is_nan(point.x) or is_nan(point.y):
		return false
	if is_inf(point.x) or is_inf(point.y):
		return false
	
	# For debugging, let's be less strict and only reject extreme outliers
	# Reject points way outside reasonable bounds (very large margin)
	var margin := 5000.0 * polygon_scale  # Much more permissive for debugging
	var scaled_bounds := 1000.0 * polygon_scale
	if point.x < -margin or point.x > (scaled_bounds + margin):
		return false
	if point.y < -margin or point.y > (scaled_bounds + margin):
		return false
		
	return true

static func dedup_and_sort_polygon(points: Array[Vector2], center: Vector2, epsilon: float = 0.25) -> PackedVector2Array:
	var unique: Array[Vector2] = []
	for p in points:
		var found := false
		for q in unique:
			if p.distance_to(q) <= epsilon:
				found = true
				break
		if not found:
			unique.append(p)
	unique.sort_custom(func(a, b):
		return atan2(a.y - center.y, a.x - center.x) < atan2(b.y - center.y, b.x - center.x)
	)
	return PackedVector2Array(unique)

static func analyze_polygon_shape(polygon_points: PackedVector2Array) -> Dictionary:
	"""
	Analyze a polygon's shape characteristics.
	Returns a dictionary with:
	- area: float - polygon area
	- perimeter: float - polygon perimeter
	- aspect_ratio: float - width/height ratio
	- compactness: float - area/perimeter ratio (higher = more compact)
	- shape_type: String - "narrow", "wide", "compact", "elongated"
	- bounding_box: Rect2 - bounding rectangle
	"""
	var result: Dictionary = {}
	
	# Calculate area using shoelace formula (Godot 4 doesn't have Geometry2D.get_polygon_area)
	var area: float = 0.0
	for i in range(polygon_points.size()):
		var j := (i + 1) % polygon_points.size()
		area += polygon_points[i].x * polygon_points[j].y
		area -= polygon_points[j].x * polygon_points[i].y
	area = abs(area) / 2.0
	result["area"] = area
	
	# Calculate perimeter
	var perimeter: float = 0.0
	for i in range(polygon_points.size()):
		var current := polygon_points[i]
		var next := polygon_points[(i + 1) % polygon_points.size()]
		perimeter += current.distance_to(next)
	result["perimeter"] = perimeter
	
	# Calculate bounding box
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	
	for point in polygon_points:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)
	
	var bounding_box := Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
	result["bounding_box"] = bounding_box
	
	# Calculate aspect ratio (width/height)
	var width: float = bounding_box.size.x
	var height: float = bounding_box.size.y
	result["aspect_ratio"] = width / height if height > 0 else 0
	
	# Calculate compactness (area/perimeter ratio)
	# Higher values indicate more compact shapes
	result["compactness"] = area / perimeter if perimeter > 0 else 0
	
	# Determine shape type based on characteristics
	var shape_type: String = "normal"
	
	if result["aspect_ratio"] > 2.0:
		shape_type = "wide"  # Much wider than tall
	elif result["aspect_ratio"] < 0.5:
		shape_type = "narrow"  # Much taller than wide
	elif result["compactness"] > 0.1:  # Threshold for compactness
		shape_type = "compact"
	elif result["compactness"] < 0.05:  # Threshold for elongation
		shape_type = "elongated"
	
	result["shape_type"] = shape_type
	
	return result

static func compute_polygon_centroid(polygon_points: PackedVector2Array) -> Vector2:
	if polygon_points.is_empty():
		return Vector2.ZERO
	if polygon_points.size() == 1:
		return polygon_points[0]
	var twice_area: float = 0.0
	var cx: float = 0.0
	var cy: float = 0.0
	for i in range(polygon_points.size()):
		var j := (i + 1) % polygon_points.size()
		var x1 := polygon_points[i].x
		var y1 := polygon_points[i].y
		var x2 := polygon_points[j].x
		var y2 := polygon_points[j].y
		var cross := x1 * y2 - x2 * y1
		twice_area += cross
		cx += (x1 + x2) * cross
		cy += (y1 + y2) * cross
	var area := twice_area * 0.5
	if area == 0.0:
		var sum := Vector2.ZERO
		for point in polygon_points:
			sum += point
		return sum / float(polygon_points.size())
	var inv := 1.0 / (6.0 * area)
	return Vector2(cx * inv, cy * inv)

static func get_region_shape_analysis(region_data: Dictionary) -> Dictionary:
	"""
	Get shape analysis for a region from its data.
	Returns the same analysis dictionary as analyze_polygon_shape().
	"""
	if region_data.is_empty():
		return {}
	
	var polygon_data = region_data.get("polygon", [])
	if polygon_data.is_empty():
		return {}
	
	# Convert polygon data to PackedVector2Array
	var polygon_points := PackedVector2Array()
	for point_data in polygon_data:
		if point_data.size() >= 2:
			polygon_points.append(Vector2(point_data[0], point_data[1]))
	
	if polygon_points.size() < 3:
		return {}
	
	return analyze_polygon_shape(polygon_points)

static func get_map_size_icon_scale(map_size: int) -> float:
	"""Get the icon scale factor based on the current map size setting"""
	# Map size scaling factors (SMALL is baseline 1.0)
	# Must match MAP_SIZE_SCALES in map_generator.gd
	# Tiny/Small/Medium/Large use the validated ratio set (SMALL baseline).
	var map_size_scales := {
		0: 38.0/26.0,     # TINY   ~1.461538
		1: 1.0,           # SMALL  ~1.0 (baseline)
		2: 18.0/26.0,     # MEDIUM ~0.692308
		3: 12.8/26.0,     # LARGE  ~0.492308
		4: 9.0/26.0,      # HUGE   ~0.346154
		5: 55.0/26.0      # XTINY  ~2.115385
	}
	
	var size = map_size_scales.get(map_size, 1.0)
	
	return size * 1.3

static func take_screenshot(filename: String = "res://screenshots/screenshot.png") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := tree.current_scene
	var viewport := scene.get_viewport()
	var camera: CameraController = scene.get_node("Camera2D")
	var ui_layer: CanvasLayer = scene.get_node("UI")

	# Derive filename by mode: scenario file name or mapdata file name
	var gm: GameManager = scene.get_node("GameManager")
	var map_gen: MapGenerator = scene.get_node("Map")
	var base_name := "screenshot"
	if gm.game_mode == "scenario":
		if gm.loaded_scenario_name != "":
			base_name = gm.loaded_scenario_name
		else:
			base_name = String(gm.scenario_path).get_file().get_basename()
	else:
		base_name = String(map_gen.data_file_path).get_file().get_basename()
	var final_path := "res://previews/" + base_name + ".png"

	var original_state := camera.get_current_state()
	camera.set_instant_mode(true)
	camera.move_to_center()
	camera.zoom_out_for_screenshot()

	ui_layer.visible = false
	await tree.process_frame
	await RenderingServer.frame_post_draw

	var img: Image = viewport.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(final_path)

	ui_layer.visible = true
	camera.restore_state(original_state)

static func compute_wounded(losses: Dictionary) -> Dictionary:
	"""Compute wounded counts per unit type from a losses dictionary.
	Uses base WOUNDED_CHANCE modified by unit defense: chance = base * (1 + defense_percent).
	Returns a dict { unit_type: wounded_count }.
	"""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result := {}
	for unit_type in losses.keys():
		var dead_count: int = int(losses[unit_type])
		if dead_count <= 0:
			continue
		var base: float = float(GameParameters.WOUNDED_CHANCE)
		var defense_pct: float = float(GameParameters.get_unit_stat(unit_type, "defense")) / 100.0
		var chance: float = clampf(base * (1.0 + defense_pct), 0.0, 1.0)
		var wounded: int = 0
		for i in range(dead_count):
			if rng.randf() < chance:
				wounded += 1
		if wounded > 0:
			result[unit_type] = wounded
	return result
