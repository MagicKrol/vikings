## Immutable Small-profile mesh compatible with the reference JavaScript generator.
##
## The reference generator caches this topology for every Small map and only
## recalculates the world data for each seed.
class_name MapgenMesh
extends RefCounted

const REFERENCE_PATHS: Dictionary = {
	"XS": "res://mapgen/reference_mesh_xs.json",
	"S": "res://mapgen/reference_small_mesh.json",
	"M": "res://mapgen/reference_mesh_m.json",
	"L": "res://mapgen/reference_mesh_l.json"
}

var points: Array[Vector2] = []
var triangles: PackedInt32Array = PackedInt32Array()
var halfedges: PackedInt32Array = PackedInt32Array()
var _side_of_region: PackedInt32Array = PackedInt32Array()
var triangle_points: Array[Vector2] = []
var num_boundary_regions: int = 0
var num_solid_sides: int = 0
var num_regions: int = 0
var num_solid_regions: int = 0
var num_sides: int = 0
var num_triangles: int = 0
var num_solid_triangles: int = 0

static func load_small() -> MapgenMesh:
	return load_size("S")

static func load_size(size: String) -> MapgenMesh:
	var file: FileAccess = FileAccess.open(str(REFERENCE_PATHS[size]), FileAccess.READ)
	var json: JSON = JSON.new()
	json.parse(file.get_as_text())
	var raw: Dictionary = json.data as Dictionary
	var mesh: MapgenMesh = MapgenMesh.new()
	mesh._load(raw)
	return mesh

static func side_from_triangle(side: int) -> int:
	return side / 3

static func previous_side(side: int) -> int:
	return side + 2 if side % 3 == 0 else side - 1

static func next_side(side: int) -> int:
	return side - 2 if side % 3 == 2 else side + 1

func _load(raw: Dictionary) -> void:
	num_boundary_regions = int(raw["numBoundaryPoints"])
	num_solid_sides = int(raw["numSolidSides"])
	var raw_points: Array = raw["points"] as Array
	for raw_point in raw_points:
		if raw_point is Array:
			var point: Array = raw_point as Array
			if point[0] == null:
				points.append(Vector2(NAN, NAN))
			else:
				var x_coordinate: float = point[0]
				var y_coordinate: float = point[1]
				points.append(Vector2(x_coordinate, y_coordinate))
		else:
			points.append(Vector2(NAN, NAN))
	var raw_triangles: Array = raw["triangles"] as Array
	triangles.resize(raw_triangles.size())
	for index in range(raw_triangles.size()):
		triangles[index] = int(raw_triangles[index])
	var raw_halfedges: Array = raw["halfedges"] as Array
	halfedges.resize(raw_halfedges.size())
	for index in range(raw_halfedges.size()):
		halfedges[index] = int(raw_halfedges[index])
	_build_derived_data()

func _build_derived_data() -> void:
	num_sides = triangles.size()
	num_regions = points.size()
	num_solid_regions = num_regions - 1
	num_triangles = num_sides / 3
	num_solid_triangles = num_solid_sides / 3
	_side_of_region.resize(num_regions)
	triangle_points.resize(num_triangles)
	for side in range(num_sides):
		var endpoint: int = triangles[next_side(side)]
		if _side_of_region[endpoint] == 0 or halfedges[side] == -1:
			_side_of_region[endpoint] = side
	for side in range(0, num_sides, 3):
		var triangle: int = side_from_triangle(side)
		var first: Vector2 = points[triangles[side]]
		var second: Vector2 = points[triangles[side + 1]]
		var third: Vector2 = points[triangles[side + 2]]
		if is_ghost_side(side):
			var delta: Vector2 = second - first
			var scale: float = 10.0 / delta.length()
			triangle_points[triangle] = Vector2(
				0.5 * (first.x + second.x) + delta.y * scale,
				0.5 * (first.y + second.y) - delta.x * scale
			)
		else:
			triangle_points[triangle] = (first + second + third) / 3.0

func position_of_region(region: int) -> Vector2:
	return points[region]

func position_of_triangle(triangle: int) -> Vector2:
	return triangle_points[triangle]

func region_beginning_side(side: int) -> int:
	return triangles[side]

func region_ending_side(side: int) -> int:
	return triangles[next_side(side)]

func inner_triangle_side(side: int) -> int:
	return side_from_triangle(side)

func outer_triangle_side(side: int) -> int:
	return side_from_triangle(halfedges[side])

func opposite_side(side: int) -> int:
	return halfedges[side]

func sides_around_triangle(triangle: int) -> Array[int]:
	return [3 * triangle, 3 * triangle + 1, 3 * triangle + 2]

func regions_around_triangle(triangle: int) -> Array[int]:
	return [triangles[3 * triangle], triangles[3 * triangle + 1], triangles[3 * triangle + 2]]

func triangles_around_triangle(triangle: int) -> Array[int]:
	return [outer_triangle_side(3 * triangle), outer_triangle_side(3 * triangle + 1), outer_triangle_side(3 * triangle + 2)]

func sides_around_region(region: int) -> Array[int]:
	var first_incoming: int = _side_of_region[region]
	var incoming: int = first_incoming
	var output: Array[int] = []
	while true:
		output.append(halfedges[incoming])
		var outgoing: int = next_side(incoming)
		incoming = halfedges[outgoing]
		if incoming == -1 or incoming == first_incoming:
			break
	return output

func regions_around_region(region: int) -> Array[int]:
	var first_incoming: int = _side_of_region[region]
	var incoming: int = first_incoming
	var output: Array[int] = []
	while true:
		output.append(region_beginning_side(incoming))
		var outgoing: int = next_side(incoming)
		incoming = halfedges[outgoing]
		if incoming == -1 or incoming == first_incoming:
			break
	return output

func triangles_around_region(region: int) -> Array[int]:
	var first_incoming: int = _side_of_region[region]
	var incoming: int = first_incoming
	var output: Array[int] = []
	while true:
		output.append(side_from_triangle(incoming))
		var outgoing: int = next_side(incoming)
		incoming = halfedges[outgoing]
		if incoming == -1 or incoming == first_incoming:
			break
	return output

func is_ghost_side(side: int) -> bool:
	return side >= num_solid_sides

func is_ghost_region(region: int) -> bool:
	return region == num_regions - 1

func is_ghost_triangle(triangle: int) -> bool:
	return is_ghost_side(3 * triangle)

func is_boundary_side(side: int) -> bool:
	return is_ghost_side(side) and side % 3 == 0

func is_boundary_region(region: int) -> bool:
	return region < num_boundary_regions
