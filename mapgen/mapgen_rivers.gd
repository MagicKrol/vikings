## River source and flow assignment ported from Red Blob Games mapgen2 (Apache-2.0).
class_name MapgenRivers
extends RefCounted

const MIN_SPRING_ELEVATION: float = 0.3
const MAX_SPRING_ELEVATION: float = 0.9
const DEFAULT_RIVER_COUNT: int = 30

static func assign(mesh: MapgenMesh, water: Array[bool], elevation_triangles: Array[float], downslope_sides: PackedInt32Array, seed: int) -> PackedInt32Array:
	return calculate(mesh, water, elevation_triangles, downslope_sides, seed)["flow_sides"] as PackedInt32Array

static func calculate(mesh: MapgenMesh, water: Array[bool], elevation_triangles: Array[float], downslope_sides: PackedInt32Array, seed: int) -> Dictionary:
	var springs: Array[int] = _find_springs(mesh, water, elevation_triangles)
	MapgenUtil.random_shuffle(springs, MapgenPrng.new(seed))
	var river_count: int = mini(DEFAULT_RIVER_COUNT, springs.size())
	var river_triangles: Array[int] = []
	for index in range(river_count):
		river_triangles.append(springs[index])
	return {
		"springs": springs,
		"river_triangles": river_triangles,
		"flow_sides": _assign_flow(mesh, downslope_sides, river_triangles)
	}

static func _find_springs(mesh: MapgenMesh, water: Array[bool], elevation_triangles: Array[float]) -> Array[int]:
	var springs: Array[int] = []
	for triangle_id in range(mesh.num_solid_triangles):
		if elevation_triangles[triangle_id] < MIN_SPRING_ELEVATION or elevation_triangles[triangle_id] > MAX_SPRING_ELEVATION:
			continue
		var has_water: bool = false
		for region_id in mesh.regions_around_triangle(triangle_id):
			if water[region_id]:
				has_water = true
				break
		if not has_water:
			springs.append(triangle_id)
	return springs

static func _assign_flow(mesh: MapgenMesh, downslope_sides: PackedInt32Array, river_triangles: Array[int]) -> PackedInt32Array:
	var flow_sides: PackedInt32Array = PackedInt32Array()
	flow_sides.resize(mesh.num_sides)
	flow_sides.fill(0)
	for spring_triangle in river_triangles:
		var triangle_id: int = spring_triangle
		while true:
			var side: int = downslope_sides[triangle_id]
			if side == -1:
				break
			flow_sides[side] += 1
			var next_triangle: int = mesh.outer_triangle_side(side)
			if next_triangle == triangle_id:
				break
			triangle_id = next_triangle
	return flow_sides
