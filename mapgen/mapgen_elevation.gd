## Elevation and drainage ported from Red Blob Games mapgen2 (Apache-2.0).
class_name MapgenElevation
extends RefCounted

static func assign(mesh: MapgenMesh, ocean: Array[bool], water: Array[bool], noise: MapgenSimplexNoise, random: MapgenPrng, elevation_bias: float = 0.3) -> Dictionary:
	var elevation_triangles: Array[float] = []
	var coast_distance: Array[float] = []
	var downhill_sides: PackedInt32Array = PackedInt32Array()
	elevation_triangles.resize(mesh.num_triangles)
	coast_distance.resize(mesh.num_triangles)
	downhill_sides.resize(mesh.num_triangles)
	downhill_sides.fill(-1)
	for triangle_id in range(mesh.num_triangles):
		var position: Vector2 = mesh.position_of_triangle(triangle_id)
		var raw: float = _sample_fbm(noise, ((position.x / 1000.0) - 0.5) * 4.2, ((position.y / 1000.0) - 0.5) * 4.2)
		var height: float = _remap_height(raw, elevation_bias)
		coast_distance[triangle_id] = absf(height - 0.46)
		var is_water: bool = _triangle_has_water(mesh, triangle_id, water)
		if is_water:
			var depth: float = MapgenUtil.clamp_value((0.46 - height) / 0.46, 0.0, 1.0)
			elevation_triangles[triangle_id] = -depth * (1.0 if _triangle_has_ocean(mesh, triangle_id, ocean) else 0.35)
		else:
			elevation_triangles[triangle_id] = MapgenUtil.clamp_value((height - 0.46) / 0.54, 0.0, 1.0)
	for triangle_id in range(mesh.num_triangles):
		var sides: Array[int] = mesh.sides_around_triangle(triangle_id)
		var offset: int = random.next_int(sides.size())
		var best_side: int = -1
		var best_score: float = elevation_triangles[triangle_id] + float(triangle_id) * 0.000000001
		for side_offset in range(sides.size()):
			var side: int = sides[(side_offset + offset) % sides.size()]
			var neighbor: int = mesh.outer_triangle_side(side)
			var score: float = elevation_triangles[neighbor] + float(neighbor) * 0.000000001
			if score < best_score:
				best_score = score
				best_side = side
		downhill_sides[triangle_id] = best_side
	var elevation_regions: Array[float] = []
	elevation_regions.resize(mesh.num_regions)
	for region_id in range(mesh.num_regions):
		var triangles: Array[int] = mesh.triangles_around_region(region_id)
		var total: float = 0.0
		for triangle_id in triangles:
			total += elevation_triangles[triangle_id]
		var elevation: float = total / float(triangles.size())
		elevation_regions[region_id] = minf(elevation, -0.01) if ocean[region_id] else elevation
	return {
		"triangles": elevation_triangles,
		"regions": elevation_regions,
		"downslope_sides": downhill_sides,
		"coast_distance": coast_distance
	}

static func apply_hills(elevation_regions: Array[float], mesh: MapgenMesh, water: Array[bool], hills: float) -> void:
	const HILL_THRESHOLD: float = 0.55
	const MOUNTAIN_THRESHOLD: float = 0.75
	const EPSILON: float = 0.001
	var hill_band: float = MOUNTAIN_THRESHOLD - HILL_THRESHOLD
	var amount: float = MapgenUtil.clamp_value(hills, 0.0, 1.0)
	var land_regions: Array[int] = []
	var base_elevations: Array[float] = elevation_regions.duplicate()
	for region_id in range(mesh.num_solid_regions):
		if water[region_id]:
			continue
		land_regions.append(region_id)
		var base: float = elevation_regions[region_id]
		elevation_regions[region_id] = minf(base, HILL_THRESHOLD - EPSILON)
	land_regions.sort_custom(func(first: int, second: int) -> bool:
		if base_elevations[first] == base_elevations[second]:
			return first < second
		return base_elevations[first] > base_elevations[second]
	)
	var hill_count: int = mini(roundi(float(land_regions.size()) * amount), land_regions.size())
	for index in range(hill_count):
		var region_id: int = land_regions[index]
		var base: float = base_elevations[region_id]
		var normalized: float = MapgenUtil.clamp_value(base / MOUNTAIN_THRESHOLD, 0.0, 1.0)
		elevation_regions[region_id] = minf(HILL_THRESHOLD + EPSILON + normalized * (hill_band - 2.0 * EPSILON), MOUNTAIN_THRESHOLD - EPSILON)

static func apply_mountains(elevation_regions: Array[float], mesh: MapgenMesh, water: Array[bool], mountains: float) -> void:
	if mountains <= 0.0:
		return
	const HILL_THRESHOLD: float = 0.55
	const MOUNTAIN_THRESHOLD: float = 0.75
	const EPSILON: float = 0.001
	var hill_regions: Array[int] = []
	for region_id in range(mesh.num_solid_regions):
		if not water[region_id] and elevation_regions[region_id] >= HILL_THRESHOLD and elevation_regions[region_id] < MOUNTAIN_THRESHOLD:
			hill_regions.append(region_id)
	hill_regions.sort_custom(func(first: int, second: int) -> bool:
		if elevation_regions[first] == elevation_regions[second]:
			return first < second
		return elevation_regions[first] > elevation_regions[second]
	)
	var mountain_count: int = mini(roundi(float(hill_regions.size()) * mountains), hill_regions.size())
	for index in range(mountain_count):
		elevation_regions[hill_regions[index]] = MOUNTAIN_THRESHOLD + EPSILON

static func _triangle_has_water(mesh: MapgenMesh, triangle_id: int, water: Array[bool]) -> bool:
	for region_id in mesh.regions_around_triangle(triangle_id):
		if water[region_id]:
			return true
	return false

static func _triangle_has_ocean(mesh: MapgenMesh, triangle_id: int, ocean: Array[bool]) -> bool:
	for region_id in mesh.regions_around_triangle(triangle_id):
		if ocean[region_id]:
			return true
	return false

static func _sample_fbm(noise: MapgenSimplexNoise, x_value: float, y_value: float) -> float:
	var frequency: float = 1.0
	var amplitude: float = 1.0
	var total: float = 0.0
	var amplitude_total: float = 0.0
	for _octave in range(5):
		total += noise.noise_2d(x_value * frequency, y_value * frequency) * amplitude
		amplitude_total += amplitude
		frequency *= 2.0
		amplitude *= 0.5
	return total / amplitude_total

static func _remap_height(raw: float, elevation_bias: float) -> float:
	var height: float = (raw + 1.0) * 0.5
	height = MapgenUtil.clamp_value((height - 0.5) * 1.15 + 0.5 + elevation_bias, 0.0, 1.0)
	return pow(height, 1.35)
