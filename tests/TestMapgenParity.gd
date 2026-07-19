extends TestCase

const FIXTURE_DIRECTORY: String = "res://tests/fixtures/"
const COORDINATE_TOLERANCE: float = 0.0002
const CALCULATION_TOLERANCE: float = 0.00001
const MAPGEN_DIAGNOSTICS: Script = preload("res://mapgen/mapgen_diagnostics.gd")
const MAPGEN_WATER: Script = preload("res://mapgen/mapgen_water.gd")

func test_seed_187_matches_javascript_reference() -> void:
	_compare_seed(187)

func test_seed_1066987705_matches_javascript_reference() -> void:
	_compare_seed(1066987705)

func test_parameterized_medium_map_matches_javascript_reference() -> void:
	_compare_fixture(
		454911730,
		"mapgen-parameterized-m-seed-454911730.diagnostics.json",
		{"size": "M", "noise_seed": 424242, "forests": 0.75, "hills": 0.4, "mountains": 0.65, "sea_level": 0.7}
	)

func test_mountains_only_promote_existing_hills() -> void:
	var base: Dictionary = MapgenGenerator.generate(187, {"hills": 0.4, "mountains": 0.0})
	var promoted: Dictionary = MapgenGenerator.generate(187, {"hills": 0.4, "mountains": 1.0})
	assert_equals(promoted["moisture"], base["moisture"], "Mountains must not change moisture")
	assert_equals(promoted["biomes"], base["biomes"], "Mountains must not change biome classification")
	var mesh: MapgenMesh = base["mesh"] as MapgenMesh
	var base_elevation: Array[float] = base["elevation_regions"] as Array[float]
	var promoted_elevation: Array[float] = promoted["elevation_regions"] as Array[float]
	var water: Array[bool] = base["water"] as Array[bool]
	for region_id in range(mesh.num_solid_regions):
		if water[region_id]:
			continue
		if base_elevation[region_id] >= 0.55 and base_elevation[region_id] < 0.75:
			assert_true(promoted_elevation[region_id] > 0.75, "Existing hill %d should be promoted" % region_id)
		else:
			assert_equals(promoted_elevation[region_id], base_elevation[region_id], "Non-hill %d must not be changed by Mountains" % region_id)

func test_zero_hills_and_mountains_are_flat() -> void:
	var generated: Dictionary = MapgenGenerator.generate(187, {"hills": 0.0, "mountains": 0.0})
	var mesh: MapgenMesh = generated["mesh"] as MapgenMesh
	var elevation: Array[float] = generated["elevation_regions"] as Array[float]
	var water: Array[bool] = generated["water"] as Array[bool]
	for region_id in range(mesh.num_solid_regions):
		if not water[region_id]:
			assert_true(elevation[region_id] < 0.55, "Land region %d must be flat when Hills and Mountains are zero" % region_id)

func test_hills_control_matches_land_region_percentage() -> void:
	var generated: Dictionary = MapgenGenerator.generate(187, {"hills": 0.01, "mountains": 0.0})
	var mesh: MapgenMesh = generated["mesh"] as MapgenMesh
	var elevation: Array[float] = generated["elevation_regions"] as Array[float]
	var water: Array[bool] = generated["water"] as Array[bool]
	var land_count: int = 0
	var hill_count: int = 0
	for region_id in range(mesh.num_solid_regions):
		if water[region_id]:
			continue
		land_count += 1
		if elevation[region_id] >= 0.55 and elevation[region_id] < 0.75:
			hill_count += 1
	assert_equals(hill_count, roundi(float(land_count) * 0.01), "Hills 0.01 must convert approximately one percent of land regions")

func test_forests_parameter_has_minimum_of_point_25() -> void:
	var parameters: Dictionary = MapgenConfig.normalize_parameters({"forests": 0.0})
	assert_equals(parameters["forests"], 0.25, "Forests must be clamped to the visible useful range")

func test_size_meshes_match_javascript_region_counts() -> void:
	var expected_counts: Dictionary = {"XS": 137, "S": 264, "M": 504, "L": 1040}
	for size in expected_counts.keys():
		var mesh: MapgenMesh = MapgenMesh.load_size(size as String)
		assert_equals(mesh.num_solid_regions, int(expected_counts[size]), "%s mesh region count must match JavaScript" % size)

func test_sea_level_flooding_is_monotonic() -> void:
	var mesh: MapgenMesh = MapgenMesh.load_size("S")
	var profile: Dictionary = MapgenConfig.get_size_profile("S")
	var previous_water: Array[bool] = []
	for level_index in range(11):
		var sea_level: float = float(level_index) / 10.0
		var parameters: Dictionary = MapgenConfig.normalize_parameters({"size": "S", "sea_level": sea_level})
		var noise: MapgenSimplexNoise = MapgenSimplexNoise.new(MapgenPrng.new(187))
		var water: Array[bool] = MAPGEN_WATER.assign_water(mesh, noise, 187, float(profile["land_fraction"]), MapgenConfig.get_target_land_fraction(parameters, profile), float(profile["lake_frequency"]))
		if not previous_water.is_empty():
			for region_id in range(mesh.num_solid_regions):
				if previous_water[region_id]:
					assert_true(water[region_id], "Region %d reappeared when sea level increased to %.1f" % [region_id, sea_level])
		previous_water = water

func _compare_seed(seed: int) -> void:
	_compare_fixture(seed, "mapgen-small-seed-%d.diagnostics.json" % seed, {})

func _compare_fixture(seed: int, fixture_name: String, parameters: Dictionary) -> void:
	var fixture_path: String = FIXTURE_DIRECTORY + fixture_name
	var expected: Dictionary = _load_fixture(fixture_path)
	var actual: Dictionary = MAPGEN_DIAGNOSTICS.build(seed, parameters)
	var sections: Array[String] = ["schemaVersion", "profile", "mesh", "noise"]
	for section in sections:
		var mismatch: String = _find_mismatch(expected[section], actual[section], section)
		if mismatch != "":
			fail("Seed %d parity mismatch: %s" % [seed, mismatch])
			return
	var expected_stages: Dictionary = expected["stages"] as Dictionary
	var actual_stages: Dictionary = actual["stages"] as Dictionary
	for stage_name in expected_stages.keys():
		var stage: String = stage_name as String
		var mismatch: String = _find_mismatch(expected_stages[stage], actual_stages[stage], "stages.%s" % stage)
		if mismatch != "":
			fail("Seed %d parity mismatch: %s" % [seed, mismatch])
			return
	for section in ["summary", "exportData"]:
		var mismatch: String = _find_mismatch(expected[section], actual[section], section)
		if mismatch != "":
			fail("Seed %d parity mismatch: %s" % [seed, mismatch])
			return
	assert_true(true, "Seed %d matches the JavaScript parity fixture" % seed)

func _load_fixture(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	assert_equals(error, OK, "Fixture must contain valid JSON: %s" % path)
	return json.data as Dictionary

func _find_mismatch(expected: Variant, actual: Variant, path: String) -> String:
	if expected == null or actual == null:
		return "" if expected == actual else "%s expected %s, got %s" % [path, expected, actual]
	if expected is Dictionary:
		if not actual is Dictionary:
			return "%s expected Dictionary, got %s" % [path, type_string(typeof(actual))]
		var expected_dictionary: Dictionary = expected as Dictionary
		var actual_dictionary: Dictionary = actual as Dictionary
		if expected_dictionary.size() != actual_dictionary.size():
			return "%s expected %d keys, got %d" % [path, expected_dictionary.size(), actual_dictionary.size()]
		for key in expected_dictionary.keys():
			if not actual_dictionary.has(key):
				return "%s missing key %s" % [path, key]
			var dictionary_mismatch: String = _find_mismatch(expected_dictionary[key], actual_dictionary[key], "%s.%s" % [path, key])
			if dictionary_mismatch != "":
				return dictionary_mismatch
		return ""
	if _is_sequence(expected):
		if not _is_sequence(actual):
			return "%s expected sequence, got %s" % [path, type_string(typeof(actual))]
		var expected_size: int = expected.size()
		var actual_size: int = actual.size()
		if expected_size != actual_size:
			return "%s expected length %d, got %d" % [path, expected_size, actual_size]
		for index in range(expected_size):
			var sequence_mismatch: String = _find_mismatch(expected[index], actual[index], "%s[%d]" % [path, index])
			if sequence_mismatch != "":
				return sequence_mismatch
		return ""
	if expected is float or actual is float:
		if not (expected is float or expected is int) or not (actual is float or actual is int):
			return "%s expected %s, got %s" % [path, expected, actual]
		var tolerance: float = _tolerance_for_path(path)
		if absf(float(expected) - float(actual)) > tolerance:
			return "%s expected %.12f, got %.12f (tolerance %.7f)" % [path, float(expected), float(actual), tolerance]
		return ""
	return "" if expected == actual else "%s expected %s, got %s" % [path, expected, actual]

func _is_sequence(value: Variant) -> bool:
	return value is Array or value is PackedInt32Array or value is PackedFloat32Array

func _tolerance_for_path(path: String) -> float:
	if "points" in path or "center" in path or "polygon" in path or "polyline" in path or ".start[" in path or ".end[" in path:
		return COORDINATE_TOLERANCE
	return CALCULATION_TOLERANCE
