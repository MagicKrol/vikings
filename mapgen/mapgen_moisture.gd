## Moisture propagation ported from Red Blob Games mapgen2 (Apache-2.0).
class_name MapgenMoisture
extends RefCounted

static func assign(mesh: MapgenMesh, flow_sides: PackedInt32Array, ocean: Array[bool], water: Array[bool], forest_bias: float = 0.0) -> Dictionary:
	var fresh_seeds: Array[int] = _find_fresh_seeds(mesh, flow_sides, ocean, water)
	var coast_seeds: Array[int] = _find_coastland(mesh, ocean, water)
	var water_distance: Array[int] = []
	water_distance.resize(mesh.num_regions)
	water_distance.fill(-1)
	var moisture: Array[float] = []
	moisture.resize(mesh.num_regions)
	var queue: Array[int] = []
	for region_id in fresh_seeds:
		water_distance[region_id] = 0
		queue.append(region_id)
	for region_id in coast_seeds:
		if water_distance[region_id] == -1:
			water_distance[region_id] = 1
			queue.append(region_id)
	var maximum_distance: int = 1
	var queue_index: int = 0
	while queue_index < queue.size():
		var current: int = queue[queue_index]
		queue_index += 1
		for neighbor_id in mesh.regions_around_region(current):
			if not water[neighbor_id] and water_distance[neighbor_id] == -1:
				var new_distance: int = water_distance[current] + 1
				water_distance[neighbor_id] = new_distance
				maximum_distance = maxi(maximum_distance, new_distance)
				queue.append(neighbor_id)
	for region_id in range(mesh.num_regions):
		if water[region_id]:
			moisture[region_id] = 1.0
		else:
			moisture[region_id] = 1.0 - pow(float(water_distance[region_id]) / float(maximum_distance), 0.4)
	_redistribute(moisture, mesh, water, forest_bias)
	return {"regions": moisture, "water_distance": water_distance}

static func _find_fresh_seeds(mesh: MapgenMesh, flow_sides: PackedInt32Array, ocean: Array[bool], water: Array[bool]) -> Array[int]:
	var seeds: Array[int] = []
	var seen: Array[bool] = []
	seen.resize(mesh.num_regions)
	seen.fill(false)
	for side in range(mesh.num_solid_sides):
		if flow_sides[side] > 0:
			_append_seed(mesh.region_beginning_side(side), seeds, seen)
			_append_seed(mesh.region_ending_side(side), seeds, seen)
	for side in range(mesh.num_solid_sides):
		var first_region: int = mesh.region_beginning_side(side)
		if water[first_region] and not ocean[first_region]:
			_append_seed(first_region, seeds, seen)
			_append_seed(mesh.region_ending_side(side), seeds, seen)
	return seeds

static func _find_coastland(mesh: MapgenMesh, ocean: Array[bool], water: Array[bool]) -> Array[int]:
	var coast: Array[int] = []
	var seen: Array[bool] = []
	seen.resize(mesh.num_regions)
	seen.fill(false)
	for side in range(mesh.num_solid_sides):
		var first_region: int = mesh.region_beginning_side(side)
		var second_region: int = mesh.region_ending_side(side)
		var first_is_ocean: bool = water[first_region] and ocean[first_region]
		var second_is_ocean: bool = water[second_region] and ocean[second_region]
		if first_is_ocean and not water[second_region]:
			_append_seed(second_region, coast, seen)
		if second_is_ocean and not water[first_region]:
			_append_seed(first_region, coast, seen)
	return coast

static func _append_seed(region_id: int, seeds: Array[int], seen: Array[bool]) -> void:
	if not seen[region_id]:
		seen[region_id] = true
		seeds.append(region_id)

static func _redistribute(moisture: Array[float], mesh: MapgenMesh, water: Array[bool], forest_bias: float) -> void:
	var land: Array[int] = []
	for region_id in range(mesh.num_solid_regions):
		if not water[region_id]:
			land.append(region_id)
	land.sort_custom(func(first: int, second: int) -> bool:
		if moisture[first] == moisture[second]:
			return first < second
		return moisture[first] < moisture[second]
	)
	for index in range(land.size()):
		moisture[land[index]] = forest_bias + float(index) / float(land.size() - 1)
