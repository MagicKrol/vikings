## Builds the Godot side of the versioned JavaScript parity fixture.
class_name MapgenDiagnostics
extends RefCounted

const SCHEMA_VERSION: int = 1
const SAMPLE_SIDES: Array[int] = [0, 1, 10, 100, 500, 1000, 1500]
const MAPGEN_BIOMES: Script = preload("res://mapgen/mapgen_biomes.gd")

static func build(seed: int, requested_parameters: Dictionary = {}) -> Dictionary:
	var generated: Dictionary = MapgenGenerator.generate(seed, requested_parameters)
	var mesh: MapgenMesh = generated["mesh"] as MapgenMesh
	var parameters: Dictionary = generated["parameters"] as Dictionary
	var profile: Dictionary = generated["profile"] as Dictionary
	var water: Array[bool] = generated["water"] as Array[bool]
	var ocean: Array[bool] = generated["ocean"] as Array[bool]
	var elevation_regions: Array[float] = generated["elevation_regions"] as Array[float]
	var biomes: Array[String] = generated["biomes"] as Array[String]
	var region_types: Array[String] = []
	for region_id in range(mesh.num_regions):
		region_types.append(MAPGEN_BIOMES.map_region_type(biomes[region_id], elevation_regions[region_id]))
	return {
		"schemaVersion": SCHEMA_VERSION,
		"profile": _build_profile(seed, parameters, profile),
		"mesh": _build_mesh(mesh),
		"noise": _build_noise(seed, int(parameters["noise_seed"])),
		"stages": {
			"water": water,
			"ocean": ocean,
			"elevationTriangles": generated["elevation_triangles"],
			"elevationRegions": elevation_regions,
			"coastDistanceTriangles": generated["coast_distance_triangles"],
			"downslopeSides": generated["downslope_sides"],
			"riverSprings": generated["river_springs"],
			"riverTriangles": generated["river_triangles"],
			"flowSides": generated["flow_sides"],
			"waterDistanceRegions": _normalize_water_distance(generated["water_distance"] as Array[int]),
			"moistureRegions": generated["moisture"],
			"coast": generated["coast"],
			"temperatureRegions": _normalize_temperature(generated["temperature"] as Array[float]),
			"biomes": biomes,
			"regionTypes": region_types,
			"noisyEdgeSamples": _build_noisy_edge_samples(generated["noisy_lines"] as Array)
		},
		"summary": _build_summary(mesh, water, ocean, elevation_regions, biomes, region_types),
		"exportData": MapgenGenerator.build_export(generated)
	}

static func _build_profile(seed: int, parameters: Dictionary, size_profile: Dictionary) -> Dictionary:
	var diagnostic_parameters: Dictionary = {
		"size": parameters["size"],
		"biomeSeed": parameters["noise_seed"],
		"forests": parameters["forests"],
		"hills": parameters["hills"],
		"mountains": parameters["mountains"],
		"seaLevel": parameters["sea_level"]
	}
	var is_default: bool = diagnostic_parameters == {"size": "S", "biomeSeed": MapgenConfig.NOISE_SEED, "forests": 0.5, "hills": 0.0, "mountains": 0.0, "seaLevel": 0.5}
	return {
		"name": "godot-small-default" if is_default else "godot-parameterized",
		"seed": seed,
		"noiseSeed": parameters["noise_seed"],
		"variant": MapgenConfig.VARIANT,
		"spacing": size_profile["spacing"],
		"parameters": diagnostic_parameters,
		"shape": {
			"round": 0.5,
			"inflate": 0.4,
			"amplitudes": [1.0, 0.5, 0.25, 0.125, 0.0625],
			"mode": "continent",
			"continents": 1,
			"connect": true,
			"inlandSea": 0.12,
			"bridgeBias": 0.35,
			"splitBias": 0.12,
			"maxBridgeLength": 260,
			"bridgeRadius": 3,
			"lakeFrequency": size_profile["lake_frequency"],
			"lakeSize": 2,
			"landFraction": MapgenConfig.get_target_land_fraction(parameters, size_profile),
			"baseLandFraction": size_profile["land_fraction"],
			"macroSeeds": 1,
			"warpStrength": 0.15,
			"warpScale": 0.9,
			"seawayFrequency": 0.05,
			"edgeOceanMargin": 18,
			"seed": seed
		},
		"elevation": {
			"mode": "fbm",
			"scale": 4.2,
			"octaves": 5,
			"lacunarity": 2.0,
			"gain": 0.5,
			"ridgeSharpness": 1.8,
			"warpStrength": 0.62,
			"relief": 0.0,
			"hills": parameters["hills"],
			"mountains": parameters["mountains"],
			"exponent": 1.35,
			"contrast": 1.15,
			"bias": MapgenConfig.ELEVATION_BIAS,
			"seaLevel": 0.46
		},
		"biomeBias": {
			"north_temperature": 0.0,
			"south_temperature": 0.0,
			"moisture": MapgenConfig.get_forest_bias(parameters)
		}
	}

static func _build_mesh(mesh: MapgenMesh) -> Dictionary:
	var points: Array[Array] = []
	for region_id in range(mesh.num_regions):
		if mesh.is_ghost_region(region_id):
			points.append([null, null])
		else:
			var point: Vector2 = mesh.position_of_region(region_id)
			points.append([point.x, point.y])
	return {
		"numBoundaryRegions": mesh.num_boundary_regions,
		"numSolidRegions": mesh.num_solid_regions,
		"numRegions": mesh.num_regions,
		"numSolidSides": mesh.num_solid_sides,
		"numSides": mesh.num_sides,
		"numSolidTriangles": mesh.num_solid_triangles,
		"numTriangles": mesh.num_triangles,
		"points": points,
		"triangles": mesh.triangles,
		"halfedges": mesh.halfedges
	}

static func _build_noise(seed: int, biome_seed: int) -> Dictionary:
	var shape_noise: MapgenSimplexNoise = MapgenSimplexNoise.new(MapgenPrng.new(seed))
	var elevation_noise: MapgenSimplexNoise = MapgenSimplexNoise.new(MapgenPrng.new(biome_seed))
	var coordinates: Array[Array] = []
	var shape: Array[float] = []
	var elevation: Array[float] = []
	for y_index in range(9):
		for x_index in range(9):
			var x_coordinate: float = -1.0 + float(x_index) * 0.25
			var y_coordinate: float = -1.0 + float(y_index) * 0.25
			coordinates.append([x_coordinate, y_coordinate])
			shape.append(shape_noise.noise_2d(x_coordinate, y_coordinate))
			elevation.append(elevation_noise.noise_2d(x_coordinate, y_coordinate))
	return {"coordinates": coordinates, "shape": shape, "elevation": elevation}

static func _normalize_water_distance(water_distance: Array[int]) -> Array:
	var output: Array = []
	for distance in water_distance:
		output.append(null if distance < 0 else distance)
	return output

static func _normalize_temperature(temperature: Array[float]) -> Array:
	var output: Array = []
	for region_id in range(temperature.size() - 1):
		output.append(temperature[region_id])
	output.append(null)
	return output

static func _build_noisy_edge_samples(noisy_lines: Array) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	for side in SAMPLE_SIDES:
		if side >= noisy_lines.size():
			continue
		var points: Array[Array] = []
		var line: PackedVector2Array = noisy_lines[side] as PackedVector2Array
		for point in line:
			points.append([point.x, point.y])
		samples.append({"side": side, "points": points})
	return samples

static func _build_summary(mesh: MapgenMesh, water: Array[bool], ocean: Array[bool], elevation: Array[float], biomes: Array[String], region_types: Array[String]) -> Dictionary:
	var water_count: int = 0
	var ocean_count: int = 0
	var minimum_land_elevation: float = INF
	var maximum_land_elevation: float = -INF
	var biome_counts: Dictionary = {}
	var region_type_counts: Dictionary = {}
	for region_id in range(mesh.num_regions):
		if water[region_id]:
			water_count += 1
		if ocean[region_id]:
			ocean_count += 1
	for region_id in range(mesh.num_solid_regions):
		if not water[region_id]:
			minimum_land_elevation = minf(minimum_land_elevation, elevation[region_id])
			maximum_land_elevation = maxf(maximum_land_elevation, elevation[region_id])
		_increment_count(biome_counts, biomes[region_id])
		_increment_count(region_type_counts, region_types[region_id])
	return {
		"waterRegions": water_count,
		"oceanRegions": ocean_count,
		"landElevationMinimum": minimum_land_elevation,
		"landElevationMaximum": maximum_land_elevation,
		"biomeCounts": biome_counts,
		"regionTypeCounts": region_type_counts
	}

static func _increment_count(counts: Dictionary, value: String) -> void:
	counts[value] = int(counts.get(value, 0)) + 1
