## Temperature and biome assignment ported from Red Blob Games mapgen2 (Apache-2.0).
class_name MapgenBiomes
extends RefCounted

static func assign(mesh: MapgenMesh, ocean: Array[bool], water: Array[bool], elevation: Array[float], moisture: Array[float], noise: MapgenSimplexNoise) -> Dictionary:
	var coast: Array[bool] = _assign_coast(mesh, water)
	var temperature: Array[float] = _assign_temperature(mesh, elevation)
	var biomes: Array[String] = []
	biomes.resize(mesh.num_regions)
	for region_id in range(mesh.num_regions):
		var region_temperature: float = temperature[region_id]
		var region_moisture: float = moisture[region_id]
		var position: Vector2 = mesh.position_of_region(region_id)
		if not mesh.is_ghost_region(region_id):
			var nx: float = (position.x - 500.0) / 500.0
			var ny: float = (position.y - 500.0) / 500.0
			var moisture_noise: float = (MapgenUtil.fbm_noise(noise, [0.5, 0.25, 0.125], nx * 1.5 + 37.1, ny * 1.5 - 12.3) + 1.0) * 0.5
			var temperature_noise: float = (MapgenUtil.fbm_noise(noise, [0.5, 0.25, 0.125], nx * 1.5 - 8.7, ny * 1.5 + 55.6) + 1.0) * 0.5
			region_moisture = clampf(MapgenUtil.lerp_value(region_moisture, moisture_noise, 0.4), 0.0, 1.0)
			region_temperature = clampf(MapgenUtil.lerp_value(region_temperature, temperature_noise, 0.2), 0.0, 1.0)
		biomes[region_id] = _classify(ocean[region_id], water[region_id], coast[region_id], region_temperature, region_moisture)
	return {"coast": coast, "temperature": temperature, "biomes": biomes}

static func map_region_type(biome: String, elevation: float) -> String:
	if elevation > 0.75:
		return "mountains"
	if elevation >= 0.55:
		return "hill_forest" if "FOREST" in biome or biome == "TAIGA" else "hills"
	if biome == "OCEAN":
		return "ocean"
	if biome == "LAKE":
		return "lake"
	if "FOREST" in biome or biome == "TAIGA":
		return "forest"
	return "grassland"

static func _assign_coast(mesh: MapgenMesh, water: Array[bool]) -> Array[bool]:
	var coast: Array[bool] = []
	coast.resize(mesh.num_regions)
	coast.fill(false)
	for region_id in range(mesh.num_regions):
		if water[region_id]:
			continue
		for neighbor_id in mesh.regions_around_region(region_id):
			if water[neighbor_id]:
				coast[region_id] = true
				break
	return coast

static func _assign_temperature(mesh: MapgenMesh, elevation: Array[float]) -> Array[float]:
	var temperature: Array[float] = []
	temperature.resize(mesh.num_regions)
	for region_id in range(mesh.num_regions):
		temperature[region_id] = 1.0 - 0.4 * maxf(0.0, elevation[region_id])
	return temperature

static func _classify(ocean: bool, water: bool, _coast: bool, temperature: float, moisture: float) -> String:
	if ocean:
		return "OCEAN"
	if water:
		if temperature > 0.9:
			return "MARSH"
		if temperature < 0.2:
			return "ICE"
		return "LAKE"
	if temperature < 0.2:
		if moisture > 0.50:
			return "SNOW"
		if moisture > 0.33:
			return "TUNDRA"
		if moisture > 0.16:
			return "BARE"
		return "SCORCHED"
	if temperature < 0.4:
		if moisture > 0.66:
			return "TAIGA"
		if moisture > 0.33:
			return "SHRUBLAND"
		return "TEMPERATE_DESERT"
	if temperature < 0.7:
		if moisture > 0.92:
			return "TEMPERATE_RAIN_FOREST"
		if moisture > 0.75:
			return "TEMPERATE_DECIDUOUS_FOREST"
		return "GRASSLAND"
	if moisture > 0.85:
		return "TROPICAL_RAIN_FOREST"
	if moisture > 0.65:
		return "TROPICAL_SEASONAL_FOREST"
	return "GRASSLAND"
