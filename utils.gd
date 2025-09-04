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
	# Map size scaling factors
	var map_size_scales := {
		0: 1.0,           # TINY
		1: 26.0/38.0,     # SMALL ~0.684
		2: 18.0/38.0,     # MEDIUM ~0.474
		3: 12.8/38.0,     # LARGE ~0.337
		4: 9.0/38.0       # HUGE ~0.237
	}
	
	return map_size_scales.get(map_size, 1.0)

static func create_mountain_icon_with_size_modifier(parent_pg: Polygon2D, region_data: Dictionary, icon_path: String, base_scale: float, polygon_scale: float, map_size_scale: float = 1.0) -> void:
	"""
	Create mountain icon with size and shape modifiers based on region characteristics.
	- Larger regions get larger icons
	- Narrow regions get two icons stacked vertically
	- Wide regions get two icons side by side
	"""
	if icon_path == "":
		return
	
	var center_data = region_data.get("center", [500, 500])
	if center_data.size() != 2:
		return
	
	var center := Vector2(center_data[0], center_data[1])
	
	# Get polygon points for analysis
	var polygon_points := parent_pg.polygon
	if polygon_points.size() < 3:
		return
	
	# Analyze region shape
	var analysis: Dictionary = analyze_polygon_shape(polygon_points)
	var area: float = analysis.get("area", 0.0)
	var shape_type: String = analysis.get("shape_type", "normal")
	
	# Debug output for mountain regions
	var region_id: int = region_data.get("id", -1)
	
	# Calculate size modifier based on area (less aggressive scaling for better visibility)
	# Based on debug output, areas are around 6000-9000, so we'll use 8000 as baseline
	var area_scale_factor: float = 1.0
	if area > 0:
		# Normalize area to a reasonable scale factor (0.9 to 1.3) for subtle size differences
		var normalized_area: float = area / 8000.0  # 8000 as baseline based on actual data
		area_scale_factor = clamp(normalized_area, 0.9, 1.3)

	# Create first mountain icon
	var icon1 := Sprite2D.new()
	icon1.texture = load(icon_path)
	if icon1.texture == null:
		return
	
	# Apply scaled position offset
	icon1.position = center + Vector2(0, -20 * map_size_scale)
	# Maintain same ratio with other biomes by not applying map_size_scale to mountains
	var final_scale: float = base_scale * polygon_scale * area_scale_factor
	icon1.scale = Vector2(final_scale, final_scale)
	icon1.z_index = parent_pg.z_index + 10
	parent_pg.add_child(icon1)
	
	# Add second icon below and slightly to the right, 20% smaller
	var icon2 := Sprite2D.new()
	icon2.texture = load(icon_path)
	var second_icon_scale: float = final_scale * 0.8  # 20% smaller than first icon
	icon2.scale = Vector2(second_icon_scale, second_icon_scale)
	icon2.z_index = parent_pg.z_index + 11  # Higher z-index for second icon
	
	# Position second icon below and slightly to the right of first icon (scaled)
	icon2.position = center + Vector2(20 * map_size_scale, 10 * map_size_scale)
	
	parent_pg.add_child(icon2)
