extends Node
class_name BorderManager

enum BorderType {
	OCEAN,
	OWNERSHIP,
	INTERNAL
}

const OCEAN_WIDTH := 10.4
const OCEAN_COLOR := Color.BLACK
const INTERNAL_COLOR := Color8(0x00, 0x00, 0x00, 50)

class BorderRecord extends RefCounted:
	var key: String = ""
	var region_id: int = -1
	var neighbor_id: int = -1
	var edge_id: int = -1
	var is_ocean: bool = false
	var base_points: PackedVector2Array = PackedVector2Array()
	var offset_direction: float = 1.0
	var line: Line2D
	var type: int = BorderType.INTERNAL
	var draw_line: bool = true

var _map_generator: MapGenerator
var _border_records: Dictionary = {}
var _region_keys: Dictionary = {}
var _map_size_scale: float = 1.0

func setup(generator: MapGenerator) -> void:
	_map_generator = generator
	_map_size_scale = Utils.get_map_size_icon_scale(_map_generator.map_size)
	_clear_existing_borders()
	_build_initial_borders()

func refresh_all_borders() -> void:
	for region_id in _region_keys.keys():
		_refresh_region(region_id)

func refresh_region_and_neighbors(region_id: int) -> void:
	_refresh_region(region_id)
	for neighbor_id in _collect_neighbor_ids(region_id):
		_refresh_region(neighbor_id)

func get_region_border_points(region_id: int) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	var keys: Array = _region_keys.get(region_id, [])
	for key in keys:
		var record: BorderRecord = _border_records[key]
		segments.append(record.base_points)
	return segments

func _clear_existing_borders() -> void:
	for record in _border_records.values():
		if record.line != null:
			record.line.queue_free()
	_border_records.clear()
	_region_keys.clear()

func _build_initial_borders() -> void:
	var borders_created := 0
	for region_data in _map_generator.regions:
		var region_id := int(region_data.get("id", -1))
		if region_id == -1 or bool(region_data.get("ocean", false)):
			continue
		var region_is_mountain := _is_mountain_region(region_data)
		var borders_node: Node2D = _get_borders_node(region_id)
		for edge in _map_generator.edges:
			var region1 := int(edge.get("region1", -1))
			var region2 := int(edge.get("region2", -1))
			if region1 != region_id and region2 != region_id:
				continue
			if region1 == -1 or region2 == -1:
				continue
			var neighbor_id := region1 if region2 == region_id else region2
			var neighbor_data: Dictionary = _map_generator.region_by_id.get(neighbor_id, {})
			if neighbor_data.is_empty():
				continue
			var skip_line := region_is_mountain and _is_mountain_region(neighbor_data)
			if bool(region_data.get("ocean", false)) and bool(neighbor_data.get("ocean", false)):
				continue
			var base_points := _create_noisy_segment(edge)
			if base_points.size() < 2:
				continue
			var record := _create_border_record(region_id, neighbor_id, edge, base_points, not skip_line)
			if record.draw_line:
				var line := _build_line(record)
				record.line = line
				_apply_border_state(record)
				borders_node.add_child(line)
				borders_created += 1
			_store_record(record)
	DebugLogger.log("MapGeneration", "Created " + str(borders_created) + " border lines via BorderManager")

func _get_borders_node(region_id: int) -> Node2D:
	var region_container: Node2D = _map_generator.region_container_by_id[region_id]
	return region_container.get_node("Borders") as Node2D

func _create_border_record(region_id: int, neighbor_id: int, edge: Dictionary, base_points: PackedVector2Array, draw_line: bool) -> BorderRecord:
	var record := BorderRecord.new()
	record.region_id = region_id
	record.neighbor_id = neighbor_id
	record.base_points = base_points
	record.offset_direction = _compute_offset_direction(region_id, base_points)
	var edge_id := int(edge.get("id", -1))
	if edge_id == -1:
		edge_id = abs(_generate_edge_seed(edge))
	record.edge_id = edge_id
	record.key = str(region_id) + ":" + str(edge_id)
	var neighbor_data: Dictionary = _map_generator.region_by_id.get(neighbor_id, {})
	record.is_ocean = bool(neighbor_data.get("ocean", false))
	record.draw_line = draw_line
	return record

func _build_line(record: BorderRecord) -> Line2D:
	var line := Line2D.new()
	line.closed = false
	line.points = record.base_points
	return line

func _store_record(record: BorderRecord) -> void:
	_border_records[record.key] = record
	if not _region_keys.has(record.region_id):
		_region_keys[record.region_id] = []
	_region_keys[record.region_id].append(record.key)

func _refresh_region(region_id: int) -> void:
	var keys: Array = _region_keys.get(region_id, [])
	for key in keys:
		var record: BorderRecord = _border_records[key]
		if record.is_ocean or record.line == null:
			continue
		_apply_border_state(record)

func _collect_neighbor_ids(region_id: int) -> Array[int]:
	var neighbors: Array[int] = []
	var keys: Array = _region_keys.get(region_id, [])
	for key in keys:
		var record: BorderRecord = _border_records[key]
		var neighbor_id := record.neighbor_id
		if neighbor_id == -1:
			continue
		if neighbors.has(neighbor_id):
			continue
		neighbors.append(neighbor_id)
	return neighbors

func _apply_border_state(record: BorderRecord) -> void:
	if record.line == null:
		return
	var new_type := _resolve_border_type(record)
	record.type = new_type
	record.line.name = _build_line_name(new_type, record.edge_id)
	match new_type:
		BorderType.OCEAN:
			record.line.points = record.base_points
			record.line.width = OCEAN_WIDTH
			record.line.default_color = OCEAN_COLOR
		BorderType.INTERNAL:
			record.line.points = record.base_points
			record.line.width = _internal_width()
			record.line.default_color = INTERNAL_COLOR
		BorderType.OWNERSHIP:
			record.line.points = _build_offset_points(record)
			record.line.width = _ownership_width()
			record.line.default_color = _get_player_border_color(_get_owner(record.region_id))

func _resolve_border_type(record: BorderRecord) -> int:
	if record.is_ocean:
		return BorderType.OCEAN
	var owner_id := _get_owner(record.region_id)
	if owner_id <= 0:
		return BorderType.INTERNAL
	var neighbor_owner := _get_owner(record.neighbor_id)
	if neighbor_owner <= 0:
		return BorderType.OWNERSHIP
	return BorderType.INTERNAL if neighbor_owner == owner_id else BorderType.OWNERSHIP

func _build_line_name(border_type: int, edge_id: int) -> String:
	match border_type:
		BorderType.OCEAN:
			return "OceanBorder@" + str(edge_id)
		BorderType.OWNERSHIP:
			return "OwnershipBorder@" + str(edge_id)
		_:
			return "InternalBorder@" + str(edge_id)

func _build_offset_points(record: BorderRecord) -> PackedVector2Array:
	var points := record.base_points
	var offset_points := PackedVector2Array()
	var offset_distance := 1.0 * _map_generator.polygon_scale * _map_size_scale
	for i in range(points.size()):
		var current_point := points[i]
		var offset_vector := _offset_vector(points, i, record.offset_direction, offset_distance)
		offset_points.append(current_point + offset_vector)
	return offset_points

func _offset_vector(points: PackedVector2Array, index: int, direction: float, distance: float) -> Vector2:
	if points.size() < 2:
		return Vector2.ZERO
	var current_point := points[index]
	if index == 0:
		var next_point := points[1]
		var dir := (next_point - current_point).normalized()
		return Vector2(-dir.y, dir.x) * distance * direction
	if index == points.size() - 1:
		var prev_point := points[index - 1]
		var dir2 := (current_point - prev_point).normalized()
		return Vector2(-dir2.y, dir2.x) * distance * direction
	var prev := points[index - 1]
	var nxt := points[index + 1]
	var dir_a := (current_point - prev).normalized()
	var dir_b := (nxt - current_point).normalized()
	var avg_dir := (dir_a + dir_b).normalized()
	return Vector2(-avg_dir.y, avg_dir.x) * distance * direction

func _internal_width() -> float:
	return 1.5 * _map_generator.polygon_scale * _map_size_scale

func _ownership_width() -> float:
	return 4.0 * _map_generator.polygon_scale * _map_size_scale

func _get_owner(region_id: int) -> int:
	var region: Region = _map_generator.region_container_by_id[region_id]
	var owner_id := region.get_region_owner()
	return owner_id if owner_id > 0 else -1

func _create_noisy_segment(edge: Dictionary) -> PackedVector2Array:
	var start_arr: Array = edge.get("start", [])
	var end_arr: Array = edge.get("end", [])
	var region1_center: Array = edge.get("region1_center", [])
	var region2_center: Array = edge.get("region2_center", [])
	if start_arr.size() != 2 or end_arr.size() != 2:
		return PackedVector2Array()
	if region1_center.size() != 2 or region2_center.size() != 2:
		return PackedVector2Array()
	var start := Vector2(start_arr[0], start_arr[1])
	var end := Vector2(end_arr[0], end_arr[1])
	var c0 := Vector2(region1_center[0], region1_center[1])
	var c1 := Vector2(region2_center[0], region2_center[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = _generate_edge_seed(edge)
	var points := PackedVector2Array()
	points.append(start)
	var mid_points := NoisyEdges.recursive_subdivision(
		start,
		end,
		c0,
		c1,
		rng,
		_map_generator.noisy_edge_length,
		_map_generator.noisy_edge_amplitude
	)
	for mp in mid_points:
		points.append(mp)
	points.append(end)
	return points

func _generate_edge_seed(edge: Dictionary) -> int:
	var start_arr: Array = edge.get("start", [])
	var end_arr: Array = edge.get("end", [])
	if start_arr.size() != 2 or end_arr.size() != 2:
		return _map_generator.noisy_edge_seed
	var x1 := float(start_arr[0])
	var y1 := float(start_arr[1])
	var x2 := float(end_arr[0])
	var y2 := float(end_arr[1])
	if x1 > x2 or (x1 == x2 and y1 > y2):
		var temp_x := x1
		var temp_y := y1
		x1 = x2
		y1 = y2
		x2 = temp_x
		y2 = temp_y
	var hash_value := int(x1 * 1000 + y1 * 1000000 + x2 * 1000000000 + y2 * 1000000000000)
	return _map_generator.noisy_edge_seed + hash_value

func _compute_offset_direction(region_id: int, edge_points: PackedVector2Array) -> float:
	if edge_points.size() < 2:
		return 1.0
	var region_data: Dictionary = _map_generator.region_by_id.get(region_id, {})
	var center_data: Array = region_data.get("center", [])
	if center_data.size() != 2:
		return 1.0
	var region_center := Vector2(center_data[0], center_data[1])
	var edge_start := edge_points[0]
	var edge_end := edge_points[edge_points.size() - 1]
	var edge_midpoint := (edge_start + edge_end) * 0.5
	var edge_direction := (edge_end - edge_start).normalized()
	var perpendicular := Vector2(-edge_direction.y, edge_direction.x)
	var to_center := (region_center - edge_midpoint).normalized()
	return 1.0 if perpendicular.dot(to_center) > 0 else -1.0

func _get_player_border_color(player_id: int) -> Color:
	var base_color := GameParameters.get_player_color(player_id)
	if player_id == 5:
		var grey_value: float = max(GameParameters.BORDER_MIN_VALUE, base_color.v - GameParameters.BORDER_VALUE_REDUCTION)
		return Color(grey_value, grey_value, grey_value, GameParameters.BORDER_OPACITY)
	var enhanced_saturation: float = min(1.0, base_color.s + GameParameters.BORDER_SATURATION_BOOST)
	var enhanced_value: float = max(GameParameters.BORDER_MIN_VALUE, base_color.v - GameParameters.BORDER_VALUE_REDUCTION)
	var border_color := Color.from_hsv(base_color.h, enhanced_saturation, enhanced_value)
	border_color.a = GameParameters.BORDER_OPACITY
	return border_color

func _is_mountain_region(region_data: Dictionary) -> bool:
	var biome_name := String(region_data.get("biome", "")).to_lower()
	return biome_name == "mountains"
