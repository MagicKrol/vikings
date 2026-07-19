## Fixed initial compatibility profile for the standalone map generator.
class_name MapgenConfig
extends RefCounted

const BOUNDS_SIZE: float = 1000.0
const SIZE: String = "small"
const INTERNAL_SIZE: String = "xtiny"
const SPACING: float = 55.0
const EXPECTED_REGION_COUNT: int = 264
const NOISE_SEED: int = 9137
const VARIANT: int = 0
const ELEVATION_BIAS: float = 0.3

static func default_parameters() -> Dictionary:
	return {
		"size": "S",
		"noise_seed": NOISE_SEED,
		"forests": 0.5,
		"hills": 0.0,
		"mountains": 0.0,
		"sea_level": 0.5
	}

static func normalize_parameters(parameters: Dictionary) -> Dictionary:
	var defaults: Dictionary = default_parameters()
	var size: String = str(parameters.get("size", defaults["size"]))
	if size not in ["XS", "S", "M", "L"]:
		size = "S"
	return {
		"size": size,
		"noise_seed": clampi(int(parameters.get("noise_seed", defaults["noise_seed"])), 0, 2147483647),
		"forests": clampf(float(parameters.get("forests", defaults["forests"])), 0.25, 1.0),
		"hills": clampf(float(parameters.get("hills", defaults["hills"])), 0.0, 1.0),
		"mountains": clampf(float(parameters.get("mountains", defaults["mountains"])), 0.0, 1.0),
		"sea_level": clampf(float(parameters.get("sea_level", defaults["sea_level"])), 0.0, 1.0)
	}

static func get_size_profile(size: String) -> Dictionary:
	match size:
		"XS":
			return {"ui_size": "tiny", "internal_size": "xxtiny", "spacing": 80.0, "regions": 137, "land_fraction": 0.50, "lake_frequency": 0.08}
		"M":
			return {"ui_size": "medium", "internal_size": "tiny", "spacing": 38.0, "regions": 504, "land_fraction": 0.55, "lake_frequency": 0.12}
		"L":
			return {"ui_size": "large", "internal_size": "small", "spacing": 26.0, "regions": 1040, "land_fraction": 0.58, "lake_frequency": 0.13}
		_:
			return {"ui_size": "small", "internal_size": "xtiny", "spacing": 55.0, "regions": 264, "land_fraction": 0.52, "lake_frequency": 0.10}

static func get_forest_bias(parameters: Dictionary) -> float:
	return float(parameters["forests"]) * 2.0 - 1.0

static func get_target_land_fraction(parameters: Dictionary, profile: Dictionary) -> float:
	return clampf(float(profile["land_fraction"]) + (0.5 - float(parameters["sea_level"])) * 0.45, 0.0, 1.0)

static func build_metadata(seed: int, parameters: Dictionary, actual_region_count: int) -> Dictionary:
	var profile: Dictionary = get_size_profile(str(parameters["size"]))
	return {
		"seed": seed,
		"noiseSeed": parameters["noise_seed"],
		"variant": VARIANT,
		"size": profile["ui_size"],
		"internalSize": profile["internal_size"],
		"requestedRegionCount": null,
		"actualRegionCount": actual_region_count,
		"persistence": 0.0,
		"elevation": {
			"mode": "fbm",
			"worldSeaLevel": parameters["sea_level"],
			"relief": 0.0,
			"hills": parameters["hills"],
			"mountains": parameters["mountains"],
			"scale": 4.2,
			"octaves": 5,
			"lacunarity": 2.0,
			"gain": 0.5,
			"ridgeSharpness": 1.8,
			"warpStrength": 0.62,
			"exponent": 1.35,
			"contrast": 1.15,
			"bias": ELEVATION_BIAS,
			"seaLevel": 0.46
		},
		"biomeBias": {
			"north_temperature": 0.0,
			"south_temperature": 0.0,
			"moisture": get_forest_bias(parameters)
		},
		"noisyEdge": {
			"length": 1.0,
			"amplitude": 0.2,
			"seed": 12345
		}
	}
