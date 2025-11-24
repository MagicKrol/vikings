@tool
extends Node2D

# Generates a simple Voronoi preview in the editor using seeded random points.
@export_range(0, 2147483647, 1, "or_greater") var seed: int = 1337:
	set(value):
		_seed_internal = value
		_queue_regenerate()
	get:
		return _seed_internal
@export var random_seed: bool = false:
	set(value):
		if not value:
			return
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_seed_internal = int(rng.randi())
		_queue_regenerate()
	get:
		return false
@export_range(2, 200, 1, "or_greater") var size: int = 80:
	set(value):
		_size_internal = max(2, value)
		_queue_regenerate()
	get:
		return _size_internal
@export_range(0.1, 4.0, 0.05) var noise_frequency: float = 1.4:
	set(value):
		_noise_frequency_internal = max(0.0001, value)
		_queue_regenerate()
	get:
		return _noise_frequency_internal
@export_range(1, 6, 1) var noise_octaves: int = 4:
	set(value):
		_noise_octaves_internal = max(1, value)
		_queue_regenerate()
	get:
		return _noise_octaves_internal
@export_range(0.2, 0.8, 0.05) var noise_gain: float = 0.5:
	set(value):
		_noise_gain_internal = clampf(value, 0.0, 1.0)
		_queue_regenerate()
	get:
		return _noise_gain_internal
@export_range(0.0, 1.0, 0.05) var water_level: float = 0.45:
	set(value):
		_water_level_internal = clampf(value, 0.0, 1.0)
		_queue_regenerate()
	get:
		return _water_level_internal
@export_range(0, 5, 1) var edge_clear_level: int = 1:
	set(value):
		_edge_clear_level_internal = max(0, value)
		_queue_regenerate()
	get:
		return _edge_clear_level_internal
@export_range(0.0, 1.0, 0.05) var elevation_profile: float = 0.5:
	set(value):
		_elevation_profile_internal = clampf(value, 0.0, 1.0)
		_queue_regenerate()
	get:
		return _elevation_profile_internal
@export_range(0.0, 1.0, 0.05) var hill_split: float = 0.5:
	set(value):
		_hill_split_internal = clampf(value, 0.0, 1.0)
		_queue_regenerate()
	get:
		return _hill_split_internal
@export var save_map: bool = false:
	set(value):
		if not value:
			return
		_save_to_file()
	get:
		return false

const BOUNDS_SIZE := 1024.0
const POINT_COLOR := Color.RED
const POINT_HALF_SIZE := 4.0
const WATER_COLOR := Color(0.15, 0.35, 0.65, 0.8)
const LAND_COLOR := Color(0.35, 0.65, 0.3, 0.9)
const HILL_COLOR := Color(0.55, 0.42, 0.22, 0.9)
const MOUNTAIN_COLOR := Color(0.55, 0.55, 0.55, 0.9)

var _seed_internal: int = seed
var _size_internal: int = size
var _noise_frequency_internal: float = noise_frequency
var _noise_octaves_internal: int = noise_octaves
var _noise_gain_internal: float = noise_gain
var _water_level_internal: float = water_level
var _edge_clear_level_internal: int = edge_clear_level
var _elevation_profile_internal: float = elevation_profile
var _hill_split_internal: float = hill_split
var _pending_regeneration: bool = false
var _cells: Array = []
var _sites: Array[Vector2] = []
var _colors: Array = []
var _is_water: Array[bool] = []
var _draw_logged: bool = false
var _noise: FastNoiseLite
var _triangles: PackedInt32Array = PackedInt32Array()
var _tri_circumcenters: Array[Vector2] = []
var _edges: Array = []

func _ready() -> void:
	_queue_regenerate()

func _queue_regenerate() -> void:
	if _pending_regeneration:
		return
	_pending_regeneration = true
	call_deferred("_regenerate")

func _regenerate() -> void:
	_pending_regeneration = false
	var rng := _create_rng()
	_noise = _create_noise()
	_sites = _generate_sites_mapgen2()
	_build_delaunay()
	_cells = _build_cells(_sites)
	_edges = _build_edges()
	_colors.clear()
	_is_water.clear()
	var water_count := 0
	var forced_edge_water := 0
	for i in range(_cells.size()):
		var site := _sites[i]
		var is_edge := _is_trimmed(site)
		var elevation := _sample_elevation(site)
		var is_water := is_edge or elevation < _water_level_internal
		_is_water.append(is_water)
		if is_water:
			_colors.append(WATER_COLOR)
			water_count += 1
			if is_edge:
				forced_edge_water += 1
		else:
			_colors.append(_color_for_elevation(elevation))
	_draw_logged = false
	_log_debug("Regenerated: seed=%s size=%s cells=%s sites=%s water=%s edge_forced=%s" % [_seed_internal, _size_internal, _cells.size(), _sites.size(), water_count, forced_edge_water])
	queue_redraw()

func _create_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_internal
	return rng

func _create_geom_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	return rng

func _compute_spacing() -> float:
	var target: float = max(10.0, float(_size_internal))
	var base_spacing := 18.0
	var base_regions := 500.0
	var scale := sqrt(base_regions / target)
	return clamp(base_spacing * scale, 6.0, 80.0)

func _compat_boundary_points(spacing: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var N := int(ceil(BOUNDS_SIZE / spacing))
	for i in range(N + 1):
		var t := (float(i) + 0.5) / (float(N) + 1.0)
		var w := BOUNDS_SIZE * t
		var offset := pow(t - 0.5, 2.0)
		points.append(Vector2(offset, w))
		points.append(Vector2(BOUNDS_SIZE - offset, w))
		points.append(Vector2(w, offset))
		points.append(Vector2(w, BOUNDS_SIZE - offset))
	return points

func _generate_sites_mapgen2() -> Array[Vector2]:
	var spacing := _compute_spacing()
	var geom_rng := _create_geom_rng()
	var samples: Array[Vector2] = _compat_boundary_points(spacing)
	var grid_cell := spacing / sqrt(2.0)
	var grid_w := int(ceil(BOUNDS_SIZE / grid_cell))
	var grid_h := int(ceil(BOUNDS_SIZE / grid_cell))
	var grid := []
	grid.resize(grid_w * grid_h)
	for p in samples:
		_place_in_grid(grid, grid_w, grid_cell, p)
	var active: Array[Vector2] = samples.duplicate()
	var attempts := 0
	while active.size() > 0 and attempts < 50000:
		attempts += 1
		var idx := int(geom_rng.randi() % active.size())
		var point := active[idx]
		var found := false
		for _i in range(20):
			var candidate := _sample_annulus(point, spacing, geom_rng)
			if candidate.x < 0.0 or candidate.y < 0.0 or candidate.x > BOUNDS_SIZE or candidate.y > BOUNDS_SIZE:
				continue
			if _valid_point(candidate, spacing, grid, grid_w, grid_cell):
				samples.append(candidate)
				active.append(candidate)
				_place_in_grid(grid, grid_w, grid_cell, candidate)
				found = true
		if not found:
			active.remove_at(idx)
	return samples

func _place_in_grid(grid: Array, grid_w: int, cell: float, p: Vector2) -> void:
	var gx := int(p.x / cell)
	var gy := int(p.y / cell)
	var index := gy * grid_w + gx
	if index >= 0 and index < grid.size():
		grid[index] = p

func _valid_point(p: Vector2, spacing: float, grid: Array, grid_w: int, cell: float) -> bool:
	var gx := int(p.x / cell)
	var gy := int(p.y / cell)
	for y in range(max(0, gy - 2), min(gy + 3, int(ceil(BOUNDS_SIZE / cell)))):
		for x in range(max(0, gx - 2), min(gx + 3, grid_w)):
			var idx := y * grid_w + x
			if idx >= 0 and idx < grid.size():
				var other = grid[idx]
				if other == null:
					continue
				if p.distance_squared_to(other) < spacing * spacing:
					return false
	return true

func _sample_annulus(center: Vector2, spacing: float, rng: RandomNumberGenerator) -> Vector2:
	var angle := rng.randf_range(0.0, TAU)
	var radius := spacing * (1.0 + rng.randf_range(0.0, 1.0))
	return center + Vector2(cos(angle), sin(angle)) * radius

func _create_noise() -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = _seed_internal
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0
	return noise

func _generate_sites(rng: RandomNumberGenerator) -> Array[Vector2]:
	var sites: Array[Vector2] = []
	var bounds := Rect2(Vector2.ZERO, Vector2(BOUNDS_SIZE, BOUNDS_SIZE))
	var area := bounds.size.x * bounds.size.y
	var target_spacing := sqrt(area / float(max(1, _size_internal))) * 0.6
	var attempts := 0
	var max_attempts := _size_internal * 40
	while sites.size() < _size_internal and attempts < max_attempts:
		attempts += 1
		var pos := Vector2(
			rng.randf_range(bounds.position.x, bounds.end.x),
			rng.randf_range(bounds.position.y, bounds.end.y)
		)
		if _is_far_enough(pos, sites, target_spacing):
			sites.append(pos)
	if sites.size() < _size_internal:
		_log_debug("Filled sites with fallback, accepted=%s requested=%s" % [sites.size(), _size_internal])
	return sites

func _is_far_enough(candidate: Vector2, existing: Array[Vector2], min_distance: float) -> bool:
	for site in existing:
		if candidate.distance_to(site) < min_distance:
			return false
	return true

func _build_cells(sites: Array[Vector2]) -> Array:
	var cells: Array = []
	for site_index in range(sites.size()):
		var cell := _initial_bounds()
		var site: Vector2 = sites[site_index]
		for other_index in range(sites.size()):
			if other_index == site_index:
				continue
			cell = _clip_cell(cell, site, sites[other_index])
			if cell.is_empty():
				break
		cell = _sort_polygon(cell, site)
		cells.append(cell)
	return cells

func _initial_bounds() -> Array:
	return [
		Vector2(0.0, 0.0),
		Vector2(BOUNDS_SIZE, 0.0),
		Vector2(BOUNDS_SIZE, BOUNDS_SIZE),
		Vector2(0.0, BOUNDS_SIZE)
	]

func _clip_cell(cell: Array, site: Vector2, other: Vector2) -> Array:
	var result: Array = []
	var midpoint := (site + other) * 0.5
	var direction := other - site
	var previous_point: Vector2 = cell[cell.size() - 1]
	var previous_inside := _is_point_closer(previous_point, midpoint, direction)
	for current_point in cell:
		var inside := _is_point_closer(current_point, midpoint, direction)
		if inside:
			if not previous_inside:
				result.append(_intersection(previous_point, current_point, midpoint, direction))
			result.append(current_point)
		elif previous_inside:
			result.append(_intersection(previous_point, current_point, midpoint, direction))
		previous_point = current_point
		previous_inside = inside
	return result

func _is_point_closer(point: Vector2, midpoint: Vector2, direction: Vector2) -> bool:
	return (point - midpoint).dot(direction) <= 0.0

func _intersection(a: Vector2, b: Vector2, midpoint: Vector2, direction: Vector2) -> Vector2:
	var ab := b - a
	var denom := ab.dot(direction)
	if abs(denom) < 0.000001:
		return midpoint
	var t := - (a - midpoint).dot(direction) / denom
	return a + ab * t

func _build_delaunay() -> void:
	var packed := PackedVector2Array(_sites)
	_triangles = Geometry2D.triangulate_delaunay(packed)
	_tri_circumcenters.clear()
	for i in range(0, _triangles.size(), 3):
		var a := _sites[_triangles[i]]
		var b := _sites[_triangles[i + 1]]
		var c := _sites[_triangles[i + 2]]
		_tri_circumcenters.append(_circumcenter(a, b, c))

func _circumcenter(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var d := 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if abs(d) < 0.000001:
		return (a + b + c) / 3.0
	var ux := ((a.length_squared() * (b.y - c.y)) + (b.length_squared() * (c.y - a.y)) + (c.length_squared() * (a.y - b.y))) / d
	var uy := ((a.length_squared() * (c.x - b.x)) + (b.length_squared() * (a.x - c.x)) + (c.length_squared() * (b.x - a.x))) / d
	return Vector2(ux, uy)

func _draw() -> void:
	if _cells.is_empty():
		if not _draw_logged:
			_log_debug("Draw skipped: no cells")
			_draw_logged = true
		return
	if not _draw_logged:
		_log_debug("Draw pass: cells=%s sites=%s" % [_cells.size(), _sites.size()])
		_draw_logged = true
	for i in range(_cells.size()):
		var cell: Array = _cells[i]
		if cell.is_empty():
			continue
		var color: Color = _colors[i]
		draw_colored_polygon(PackedVector2Array(cell), color)
	for site in _sites:
		var half := POINT_HALF_SIZE
		var rect := Rect2(site - Vector2(half, half), Vector2(half * 2.0, half * 2.0))
		draw_rect(rect, POINT_COLOR)

func _is_site_water(site: Vector2) -> bool:
	var elevation := _sample_elevation(site)
	return elevation < _water_level_internal

func _sample_elevation(pos: Vector2) -> float:
	if _noise == null:
		return 1.0
	var nx := (pos.x / BOUNDS_SIZE) - 0.5
	var ny := (pos.y / BOUNDS_SIZE) - 0.5
	var amplitude := 1.0
	var frequency := _noise_frequency_internal
	var amplitude_sum := 0.0
	var value := 0.0
	for i in range(_noise_octaves_internal):
		var sample := _noise.get_noise_2d(nx * frequency, ny * frequency)
		value += sample * amplitude
		amplitude_sum += amplitude
		amplitude *= _noise_gain_internal
		frequency *= 2.0
	if amplitude_sum == 0.0:
		return 1.0
	var normalized := value / amplitude_sum
	normalized = normalized * 0.5 + 0.5
	return clampf(normalized, 0.0, 1.0)

func _is_trimmed(site: Vector2) -> bool:
	if _edge_clear_level_internal <= 0:
		return false
	var margin := float(_edge_clear_level_internal) * 32.0
	return site.x <= margin or site.y <= margin or site.x >= (BOUNDS_SIZE - margin) or site.y >= (BOUNDS_SIZE - margin)

func _sort_polygon(points: Array, center: Vector2) -> Array:
	points.sort_custom(func(a, b):
		var ang_a := atan2(a.y - center.y, a.x - center.x)
		var ang_b := atan2(b.y - center.y, b.x - center.x)
		return ang_a < ang_b
	)
	return points

func _color_for_elevation(elevation: float) -> Color:
	var mountain_threshold := _mountain_threshold()
	var hill_threshold := _hill_threshold(mountain_threshold)
	if elevation >= mountain_threshold:
		return MOUNTAIN_COLOR
	if elevation >= hill_threshold:
		return HILL_COLOR
	return LAND_COLOR

func _hill_threshold(mountain_threshold: float) -> float:
	var base: float = lerp(0.45, 0.65, _hill_split_internal)
	return clampf(min(base, mountain_threshold - 0.02), 0.0, 1.0)

func _mountain_threshold() -> float:
	return clampf(lerp(0.8, 0.55, _elevation_profile_internal), 0.0, 1.0)

func _log_debug(message: String) -> void:
	print("VoronoiMapGenerator: " + message)

func _save_to_file() -> void:
	var data := _build_map_data()
	var json := JSON.stringify(data, "\t")
	var file_path := "res://mapdata/mapdata-" + str(_seed_internal) + "-medium.json"
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		_log_debug("Failed to open file for save: " + file_path)
		return
	file.store_string(json)
	file.close()
	_log_debug("Saved map to " + file_path)

func _build_map_data() -> Dictionary:
	var result := {
		"bounds": {
			"x": 0,
			"y": 0,
			"width": BOUNDS_SIZE,
			"height": BOUNDS_SIZE
		},
		"meta": {
			"size": "medium",
			"seed": _seed_internal,
			"generator": "voronoi_map_generator",
			"noisyEdge": {
				"length": 1.0,
				"amplitude": 0.2,
				"seed": 12345
			}
		},
		"coasts": [],
		"rivers": [],
		"edges": [],
		"regions": []
	}
	for i in range(_sites.size()):
		if i >= _cells.size():
			break
		var site: Vector2 = _sites[i]
		var cell: Array = _cells[i]
		if cell.size() < 3:
			continue
		var elevation := _sample_elevation(site)
		var is_ocean := _is_water[i]
		var region_data := {
			"id": i,
			"center": [site.x, site.y],
			"polygon": _vector_array_to_list(cell),
			"ocean": is_ocean,
			"biome": _biome_for_elevation(is_ocean, elevation),
			"elevation": elevation,
			"moisture": 0.5,
			"edges": []
		}
		result["regions"].append(region_data)
	for edge in _edges:
		result["edges"].append({
			"id": edge["id"],
			"start": edge["start"],
			"end": edge["end"],
			"region1": edge["region1"],
			"region2": edge["region2"],
			"region1_center": edge["region1_center"],
			"region2_center": edge["region2_center"]
		})
	for region in result["regions"]:
		var rid := int(region["id"])
		region["edges"] = _edge_ids_for_region(rid)
	return result

func _vector_array_to_list(points: Array) -> Array:
	var result: Array = []
	for p in points:
		result.append([p.x, p.y])
	return result

func _biome_for_elevation(is_ocean: bool, elevation: float) -> String:
	if is_ocean:
		return "ocean"
	var mountain_threshold := _mountain_threshold()
	var hill_threshold := _hill_threshold(mountain_threshold)
	if elevation >= mountain_threshold:
		return "mountain"
	if elevation >= hill_threshold:
		return "hill"
	return "grassland"

func _edge_ids_for_region(region_id: int) -> Array:
	var ids: Array = []
	for edge in _edges:
		if edge["region1"] == region_id or edge["region2"] == region_id:
			ids.append(edge["id"])
	return ids

func _build_edges() -> Array:
	var rng := _create_geom_rng()
	var edge_map: Dictionary = {}
	var edges: Array = []
	for i in range(_cells.size()):
		var poly: Array = _cells[i]
		for j in range(poly.size()):
			var a: Vector2 = poly[j]
			var b: Vector2 = poly[(j + 1) % poly.size()]
			var key := _segment_key(a, b)
			if edge_map.has(key):
				var other: int = int(edge_map[key])
				edges.append({
					"id": edges.size(),
					"start": [a.x, a.y],
					"end": [b.x, b.y],
					"region1": other,
					"region2": i,
					"region1_center": [_sites[other].x, _sites[other].y],
					"region2_center": [_sites[i].x, _sites[i].y],
					"polyline": _noisy_polyline(a, b, _sites[other], _sites[i], rng)
				})
				edge_map.erase(key)
			else:
				edge_map[key] = i
	return edges

func _segment_key(a: Vector2, b: Vector2) -> String:
	var ax := int(a.x * 1000.0)
	var ay := int(a.y * 1000.0)
	var bx := int(b.x * 1000.0)
	var by := int(b.y * 1000.0)
	if ax > bx or (ax == bx and ay > by):
		return str(bx) + ":" + str(by) + ":" + str(ax) + ":" + str(ay)
	return str(ax) + ":" + str(ay) + ":" + str(bx) + ":" + str(by)

func _noisy_polyline(a: Vector2, b: Vector2, p: Vector2, q: Vector2, rng: RandomNumberGenerator) -> Array:
	var divisor := 0x10000000
	var length_limit := 1.0
	var amplitude := 0.2
	var result: Array = []
	var stack: Array = [[a, b, p, q]]
	while stack.size() > 0:
		var item = stack.pop_back()
		var p0: Vector2 = item[0]
		var p1: Vector2 = item[1]
		var pa: Vector2 = item[2]
		var pb: Vector2 = item[3]
		var dx := p0.x - p1.x
		var dy := p0.y - p1.y
		if dx * dx + dy * dy < length_limit * length_limit:
			result.append(p1)
			continue
		var ap := p0.lerp(pa, 0.5)
		var bp := p1.lerp(pa, 0.5)
		var aq := p0.lerp(pb, 0.5)
		var bq := p1.lerp(pb, 0.5)
		var division := 0.5 * (1.0 - amplitude) + (float(rng.randi() % divisor) / float(divisor)) * amplitude
		var center := pa.lerp(pb, division)
		stack.append([p0, center, ap, aq])
		stack.append([center, p1, bp, bq])
	return result
