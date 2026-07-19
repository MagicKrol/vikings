## Deterministic noisy edge paths ported from Red Blob Games mapgen2 (Apache-2.0).
class_name MapgenNoisyEdges
extends RefCounted

const DIVISOR: float = 268435456.0

static func assign_lines(mesh: MapgenMesh) -> Array:
	var random: MapgenPrng = MapgenPrng.new(12345)
	var lines: Array = []
	lines.resize(mesh.num_sides)
	for side in range(mesh.num_sides):
		var first_region: int = mesh.region_beginning_side(side)
		var second_region: int = mesh.region_ending_side(side)
		if first_region >= second_region:
			continue
		var inner_triangle: int = mesh.inner_triangle_side(side)
		var outer_triangle: int = mesh.outer_triangle_side(side)
		var path: PackedVector2Array
		if mesh.is_ghost_side(side):
			path = PackedVector2Array([mesh.position_of_triangle(outer_triangle)])
		else:
			path = _subdivide(
				mesh.position_of_triangle(inner_triangle),
				mesh.position_of_triangle(outer_triangle),
				mesh.position_of_region(first_region),
				mesh.position_of_region(second_region),
				random
			)
		lines[side] = path
		var reversed_path: PackedVector2Array = PackedVector2Array()
		for index in range(path.size() - 2, -1, -1):
			reversed_path.append(path[index])
		reversed_path.append(mesh.position_of_triangle(inner_triangle))
		lines[mesh.opposite_side(side)] = reversed_path
	return lines

static func _subdivide(start: Vector2, finish: Vector2, first_region: Vector2, second_region: Vector2, random: MapgenPrng) -> PackedVector2Array:
	if start.distance_squared_to(finish) < 1.0:
		return PackedVector2Array([finish])
	var start_to_first: Vector2 = start.lerp(first_region, 0.5)
	var finish_to_first: Vector2 = finish.lerp(first_region, 0.5)
	var start_to_second: Vector2 = start.lerp(second_region, 0.5)
	var finish_to_second: Vector2 = finish.lerp(second_region, 0.5)
	var division: float = 0.4 + float(random.next_int(268435456)) / DIVISOR * 0.2
	var center: Vector2 = first_region.lerp(second_region, division)
	var first_half: PackedVector2Array = _subdivide(start, center, start_to_first, start_to_second, random)
	var second_half: PackedVector2Array = _subdivide(center, finish, finish_to_first, finish_to_second, random)
	first_half.append_array(second_half)
	return first_half
