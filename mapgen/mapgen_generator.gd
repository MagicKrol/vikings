## Exact Small-profile generation pipeline and JS-compatible export builder.
class_name MapgenGenerator
extends RefCounted

const EXTRACTION_EDGE_MARGIN: float = 22.0
const MAPGEN_WATER: Script = preload("res://mapgen/mapgen_water.gd")
const MAPGEN_ELEVATION: Script = preload("res://mapgen/mapgen_elevation.gd")
const MAPGEN_RIVERS: Script = preload("res://mapgen/mapgen_rivers.gd")
const MAPGEN_MOISTURE: Script = preload("res://mapgen/mapgen_moisture.gd")
const MAPGEN_BIOMES: Script = preload("res://mapgen/mapgen_biomes.gd")
const MAPGEN_NOISY_EDGES: Script = preload("res://mapgen/mapgen_noisy_edges.gd")

static func generate(seed: int, requested_parameters: Dictionary = {}) -> Dictionary:
	var parameters: Dictionary = MapgenConfig.normalize_parameters(requested_parameters)
	var profile: Dictionary = MapgenConfig.get_size_profile(str(parameters["size"]))
	var mesh: MapgenMesh = MapgenMesh.load_size(str(parameters["size"]))
	var shape_noise: MapgenSimplexNoise = MapgenSimplexNoise.new(MapgenPrng.new(seed))
	var base_land_fraction: float = float(profile["land_fraction"])
	var target_land_fraction: float = MapgenConfig.get_target_land_fraction(parameters, profile)
	var water: Array[bool] = MAPGEN_WATER.assign_water(mesh, shape_noise, seed, base_land_fraction, target_land_fraction, float(profile["lake_frequency"]))
	var ocean: Array[bool] = MAPGEN_WATER.assign_ocean(mesh, water)
	var elevation: Dictionary = MAPGEN_ELEVATION.assign(mesh, ocean, water, MapgenSimplexNoise.new(MapgenPrng.new(int(parameters["noise_seed"]))), MapgenPrng.new(MapgenConfig.VARIANT), MapgenConfig.ELEVATION_BIAS)
	var rivers: Dictionary = MAPGEN_RIVERS.calculate(mesh, water, elevation["triangles"] as Array[float], elevation["downslope_sides"] as PackedInt32Array, MapgenConfig.VARIANT)
	var flow_sides: PackedInt32Array = rivers["flow_sides"] as PackedInt32Array
	var moisture: Dictionary = MAPGEN_MOISTURE.assign(mesh, flow_sides, ocean, water, MapgenConfig.get_forest_bias(parameters))
	var biome_data: Dictionary = MAPGEN_BIOMES.assign(mesh, ocean, water, elevation["regions"] as Array[float], moisture["regions"] as Array[float], shape_noise)
	MAPGEN_ELEVATION.apply_hills(elevation["regions"] as Array[float], mesh, water, float(parameters["hills"]))
	MAPGEN_ELEVATION.apply_mountains(elevation["regions"] as Array[float], mesh, water, float(parameters["mountains"]))
	return {
		"seed": seed,
		"parameters": parameters,
		"profile": profile,
		"mesh": mesh,
		"water": water,
		"ocean": ocean,
		"elevation_triangles": elevation["triangles"],
		"elevation_regions": elevation["regions"],
		"coast_distance_triangles": elevation["coast_distance"],
		"downslope_sides": elevation["downslope_sides"],
		"river_springs": rivers["springs"],
		"river_triangles": rivers["river_triangles"],
		"flow_sides": flow_sides,
		"water_distance": moisture["water_distance"],
		"moisture": moisture["regions"],
		"coast": biome_data["coast"],
		"temperature": biome_data["temperature"],
		"biomes": biome_data["biomes"],
		"noisy_lines": MAPGEN_NOISY_EDGES.assign_lines(mesh)
	}

static func build_export(generated: Dictionary) -> Dictionary:
	var mesh: MapgenMesh = generated["mesh"] as MapgenMesh
	var water: Array[bool] = (generated["water"] as Array[bool]).duplicate()
	var ocean: Array[bool] = (generated["ocean"] as Array[bool]).duplicate()
	var coast: Array[bool] = (generated["coast"] as Array[bool]).duplicate()
	var elevation: Array[float] = generated["elevation_regions"] as Array[float]
	var moisture: Array[float] = generated["moisture"] as Array[float]
	var temperature: Array[float] = generated["temperature"] as Array[float]
	var biomes: Array[String] = generated["biomes"] as Array[String]
	var flow_sides: PackedInt32Array = generated["flow_sides"] as PackedInt32Array
	var noisy_lines: Array = generated["noisy_lines"] as Array
	var boundary_mask: Array[bool] = _build_extraction_boundary_mask(mesh)
	for region_id in range(mesh.num_solid_regions):
		if boundary_mask[region_id]:
			water[region_id] = true
			ocean[region_id] = true
			coast[region_id] = false
	var edge_data: Dictionary = _build_edges(mesh)
	var side_to_edge: PackedInt32Array = edge_data["side_to_edge"] as PackedInt32Array
	var regions: Array[Dictionary] = _build_regions(mesh, boundary_mask, water, ocean, coast, elevation, temperature, moisture, biomes, side_to_edge)
	return {
		"meta": MapgenConfig.build_metadata(int(generated["seed"]), generated["parameters"] as Dictionary, mesh.num_solid_regions),
		"bounds": {"width": MapgenConfig.BOUNDS_SIZE, "height": MapgenConfig.BOUNDS_SIZE},
		"regions": regions,
		"edges": edge_data["edges"],
		"rivers": _build_polylines(mesh, noisy_lines, boundary_mask, flow_sides, ocean, true),
		"coasts": _build_polylines(mesh, noisy_lines, boundary_mask, flow_sides, ocean, false)
	}

static func _build_extraction_boundary_mask(mesh: MapgenMesh) -> Array[bool]:
	var mask: Array[bool] = []
	mask.resize(mesh.num_regions)
	mask.fill(false)
	var maximum: float = MapgenConfig.BOUNDS_SIZE - EXTRACTION_EDGE_MARGIN
	for region_id in range(mesh.num_solid_regions):
		if mesh.is_boundary_region(region_id):
			mask[region_id] = true
			continue
		var position: Vector2 = mesh.position_of_region(region_id)
		if position.x <= EXTRACTION_EDGE_MARGIN or position.x >= maximum or position.y <= EXTRACTION_EDGE_MARGIN or position.y >= maximum:
			mask[region_id] = true
			continue
		for triangle_id in mesh.triangles_around_region(region_id):
			var triangle_position: Vector2 = mesh.position_of_triangle(triangle_id)
			if triangle_position.x <= EXTRACTION_EDGE_MARGIN or triangle_position.x >= maximum or triangle_position.y <= EXTRACTION_EDGE_MARGIN or triangle_position.y >= maximum:
				mask[region_id] = true
				break
	return mask

static func _build_regions(mesh: MapgenMesh, boundary_mask: Array[bool], water: Array[bool], ocean: Array[bool], coast: Array[bool], elevation: Array[float], temperature: Array[float], moisture: Array[float], biomes: Array[String], side_to_edge: PackedInt32Array) -> Array[Dictionary]:
	var regions: Array[Dictionary] = []
	for region_id in range(mesh.num_solid_regions):
		var polygon: Array[Array] = []
		var region_edges: Array[int] = []
		for side in mesh.sides_around_region(region_id):
			polygon.append(_point_array(mesh.position_of_triangle(mesh.outer_triangle_side(side))))
			region_edges.append(side_to_edge[side])
		var region_elevation: float = minf(elevation[region_id], -0.01) if boundary_mask[region_id] else elevation[region_id]
		var region_type: String = "ocean" if boundary_mask[region_id] else MAPGEN_BIOMES.map_region_type(biomes[region_id], elevation[region_id])
		regions.append({
			"id": region_id,
			"center": _point_array(mesh.position_of_region(region_id)),
			"polygon": polygon,
			"biome": region_type,
			"elevation": region_elevation,
			"temperature": temperature[region_id],
			"moisture": moisture[region_id],
			"water": water[region_id],
			"ocean": ocean[region_id],
			"coast": coast[region_id],
			"edges": region_edges
		})
	return regions

static func _build_edges(mesh: MapgenMesh) -> Dictionary:
	var edges: Array[Dictionary] = []
	var side_to_edge: PackedInt32Array = PackedInt32Array()
	side_to_edge.resize(mesh.num_sides)
	side_to_edge.fill(-1)
	for side in range(mesh.num_solid_sides):
		var first_region: int = mesh.region_beginning_side(side)
		var second_region: int = mesh.region_ending_side(side)
		if first_region > second_region:
			continue
		var edge_id: int = edges.size()
		edges.append({
			"id": edge_id,
			"start": _point_array(mesh.position_of_triangle(mesh.inner_triangle_side(side))),
			"end": _point_array(mesh.position_of_triangle(mesh.outer_triangle_side(side))),
			"region1": first_region,
			"region2": second_region,
			"region1_center": _point_array(mesh.position_of_region(first_region)),
			"region2_center": _point_array(mesh.position_of_region(second_region))
		})
		side_to_edge[side] = edge_id
		side_to_edge[mesh.opposite_side(side)] = edge_id
	return {"edges": edges, "side_to_edge": side_to_edge}

static func _build_polylines(mesh: MapgenMesh, noisy_lines: Array, boundary_mask: Array[bool], flow_sides: PackedInt32Array, ocean: Array[bool], rivers: bool) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for side in range(mesh.num_solid_sides):
		var first_region: int = mesh.region_beginning_side(side)
		var second_region: int = mesh.region_ending_side(side)
		if first_region > second_region:
			continue
		var include_side: bool
		if rivers:
			include_side = not boundary_mask[first_region] and not boundary_mask[second_region] and (flow_sides[side] > 0 or flow_sides[mesh.opposite_side(side)] > 0)
		else:
			include_side = ocean[first_region] != ocean[second_region]
		if not include_side:
			continue
		var polyline: Array[Array] = [_point_array(mesh.position_of_triangle(mesh.inner_triangle_side(side)))]
		var line: PackedVector2Array = noisy_lines[side] as PackedVector2Array
		for point in line:
			polyline.append(_point_array(point))
		output.append({"side": side, "r0": first_region, "r1": second_region, "polyline": polyline})
	return output

static func _point_array(point: Vector2) -> Array:
	return [point.x, point.y]
