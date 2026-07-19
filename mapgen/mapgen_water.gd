## Water and ocean assignment ported from Red Blob Games mapgen2 (Apache-2.0).
class_name MapgenWater
extends RefCounted

static func assign_water(mesh: MapgenMesh, noise: MapgenSimplexNoise, seed: int, base_land_fraction: float = 0.52, target_land_fraction: float = 0.52, lake_frequency: float = 0.10) -> Array[bool]:
	var random: MapgenPrng = MapgenPrng.new(seed)
	var water: Array[bool] = []
	var scores: Array[float] = []
	water.resize(mesh.num_regions)
	scores.resize(mesh.num_regions)
	for region_id in range(mesh.num_regions):
		water[region_id] = true
		scores[region_id] = -INF
	for region_id in range(mesh.num_regions):
		if mesh.is_ghost_region(region_id) or mesh.is_boundary_region(region_id):
			continue
		var position: Vector2 = mesh.position_of_region(region_id)
		var warp_x: float = 0.15 * 80.0 * MapgenUtil.fbm_noise(noise, [0.5, 1.0 / 3.0], position.x / 1000.0 * 0.9 + 11.3, position.y / 1000.0 * 0.9 - 7.1)
		var warp_y: float = 0.15 * 80.0 * MapgenUtil.fbm_noise(noise, [0.5, 1.0 / 3.0], position.x / 1000.0 * 0.9 - 5.7, position.y / 1000.0 * 0.9 + 9.9)
		var nx: float = (position.x + warp_x - 500.0) / 500.0
		var ny: float = (position.y + warp_y - 500.0) / 500.0
		var base_noise: float = MapgenUtil.fbm_noise(noise, [1.0, 0.5, 0.25, 0.125, 0.0625], nx + float(seed) * 0.01, ny - float(seed) * 0.01)
		var shaped: float = MapgenUtil.lerp_value(base_noise, 0.5, 0.5)
		var distance: float = maxf(absf(nx), absf(ny))
		var score: float = shaped - 0.6 * distance * distance
		var sea_noise: float = (MapgenUtil.fbm_noise(noise, [0.5, 0.25], ((position.x - 500.0) / 500.0) * 0.7 + 3.1, ((position.y - 500.0) / 500.0) * 0.7 - 6.7) + 1.0) * 0.5
		scores[region_id] = score - 0.12 * sea_noise
	var interior_scores: Array[float] = []
	for region_id in range(mesh.num_regions):
		if not mesh.is_ghost_region(region_id) and not mesh.is_boundary_region(region_id):
			interior_scores.append(scores[region_id])
	interior_scores.sort()
	var base_sea_level: float = _get_sea_threshold(interior_scores, base_land_fraction)
	for region_id in range(mesh.num_regions):
		if mesh.is_ghost_region(region_id) or mesh.is_boundary_region(region_id):
			water[region_id] = true
		else:
			water[region_id] = scores[region_id] < base_sea_level
	_force_edge_ocean(mesh, water)
	_connect_land(mesh, water, random)
	_carve_lakes(mesh, water, noise, random, lake_frequency)
	_apply_monotonic_sea_level(mesh, water, scores, interior_scores, base_land_fraction, target_land_fraction)
	return water

static func _get_sea_threshold(sorted_scores: Array[float], land_fraction: float) -> float:
	var sea_index: int = clampi(floori((1.0 - land_fraction) * float(sorted_scores.size())), 0, sorted_scores.size() - 1)
	return sorted_scores[sea_index]

static func _apply_monotonic_sea_level(mesh: MapgenMesh, water: Array[bool], scores: Array[float], sorted_scores: Array[float], base_land_fraction: float, target_land_fraction: float) -> void:
	if is_equal_approx(target_land_fraction, base_land_fraction):
		return
	var target_sea_level: float = _get_sea_threshold(sorted_scores, target_land_fraction)
	for region_id in range(mesh.num_regions):
		if mesh.is_ghost_region(region_id) or mesh.is_boundary_region(region_id):
			continue
		if target_land_fraction < base_land_fraction:
			water[region_id] = water[region_id] or scores[region_id] < target_sea_level
		else:
			water[region_id] = water[region_id] and scores[region_id] < target_sea_level
	_force_edge_ocean(mesh, water)

static func assign_ocean(mesh: MapgenMesh, water: Array[bool]) -> Array[bool]:
	var ocean: Array[bool] = []
	ocean.resize(mesh.num_regions)
	for region_id in range(mesh.num_regions):
		ocean[region_id] = false
	var stack: Array[int] = [mesh.num_regions - 1]
	while not stack.is_empty():
		var region_id: int = stack.pop_back()
		for neighbor_id in mesh.regions_around_region(region_id):
			if water[neighbor_id] and not ocean[neighbor_id]:
				ocean[neighbor_id] = true
				stack.append(neighbor_id)
	return ocean

static func _force_edge_ocean(mesh: MapgenMesh, water: Array[bool]) -> void:
	for region_id in range(mesh.num_regions):
		if mesh.is_ghost_region(region_id) or mesh.is_boundary_region(region_id):
			continue
		var position: Vector2 = mesh.position_of_region(region_id)
		if position.x <= 18.0 or position.x >= 982.0 or position.y <= 18.0 or position.y >= 982.0:
			water[region_id] = true
			continue
		for triangle_id in mesh.triangles_around_region(region_id):
			var triangle_position: Vector2 = mesh.position_of_triangle(triangle_id)
			if triangle_position.x <= 18.0 or triangle_position.x >= 982.0 or triangle_position.y <= 18.0 or triangle_position.y >= 982.0:
				water[region_id] = true
				break

static func _connect_land(mesh: MapgenMesh, water: Array[bool], random: MapgenPrng) -> void:
	var components: Array = _land_components(mesh, water)
	if components.size() <= 1:
		return
	var total_land: int = 0
	for component_value in components:
		var land_component: Array[int] = component_value as Array[int]
		total_land += land_component.size()
	components.sort_custom(func(first: Array, second: Array) -> bool:
		return first.size() > second.size()
	)
	var main: Array[int] = components[0] as Array[int]
	var main_set: Dictionary = {}
	for region_id in main:
		main_set[region_id] = true
	for component_index in range(1, components.size()):
		var component: Array[int] = components[component_index] as Array[int]
		if float(component.size()) / float(total_land) < 0.003:
			for region_id in component:
				water[region_id] = true
			continue
		var queue: Array[int] = component.duplicate()
		var previous: PackedInt32Array = PackedInt32Array()
		previous.resize(mesh.num_regions)
		previous.fill(-1)
		var visited: Array[bool] = []
		visited.resize(mesh.num_regions)
		for region_id in range(mesh.num_regions):
			visited[region_id] = false
		for region_id in queue:
			visited[region_id] = true
		var queue_index: int = 0
		var goal: int = -1
		while queue_index < queue.size() and goal == -1:
			var current: int = queue[queue_index]
			queue_index += 1
			for neighbor_id in mesh.regions_around_region(current):
				if mesh.is_ghost_region(neighbor_id) or visited[neighbor_id]:
					continue
				visited[neighbor_id] = true
				previous[neighbor_id] = current
				if main_set.has(neighbor_id):
					goal = neighbor_id
					break
				queue.append(neighbor_id)
		if goal == -1:
			continue
		var bridge_length: int = 0
		var bridge_region: int = previous[goal]
		while bridge_region != -1 and not main_set.has(bridge_region):
			bridge_length += 1
			bridge_region = previous[bridge_region]
		if bridge_length > 260:
			for region_id in component:
				water[region_id] = true
			continue
		var corridor: int = previous[goal]
		while corridor != -1 and not main_set.has(corridor):
			var radius_queue: Array[Vector2i] = [Vector2i(corridor, 0)]
			var radius_seen: Dictionary = {}
			var radius_index: int = 0
			while radius_index < radius_queue.size():
				var queue_entry: Vector2i = radius_queue[radius_index]
				radius_index += 1
				var current: int = queue_entry.x
				var depth: int = queue_entry.y
				if radius_seen.has(current):
					continue
				radius_seen[current] = true
				water[current] = false
				main_set[current] = true
				main.append(current)
				if depth >= 3:
					continue
				for neighbor_id in mesh.regions_around_region(current):
					if mesh.is_ghost_region(neighbor_id) or radius_seen.has(neighbor_id):
						continue
					if not water[neighbor_id]:
						continue
					if depth > 0 and random.next_water_float() < 0.25:
						continue
					radius_queue.append(Vector2i(neighbor_id, depth + 1))
			corridor = previous[corridor]
		for region_id in component:
			if not main_set.has(region_id):
				main_set[region_id] = true
				main.append(region_id)

static func _land_components(mesh: MapgenMesh, water: Array[bool]) -> Array:
	var seen: Array[bool] = []
	seen.resize(mesh.num_regions)
	for region_id in range(mesh.num_regions):
		seen[region_id] = false
	var components: Array = []
	for region_id in range(mesh.num_regions):
		if seen[region_id] or water[region_id] or mesh.is_ghost_region(region_id):
			continue
		var component: Array[int] = []
		var stack: Array[int] = [region_id]
		seen[region_id] = true
		while not stack.is_empty():
			var current: int = stack.pop_back()
			component.append(current)
			for neighbor_id in mesh.regions_around_region(current):
				if not seen[neighbor_id] and not water[neighbor_id] and not mesh.is_ghost_region(neighbor_id):
					seen[neighbor_id] = true
					stack.append(neighbor_id)
		components.append(component)
	return components

static func _carve_lakes(mesh: MapgenMesh, water: Array[bool], noise: MapgenSimplexNoise, random: MapgenPrng, lake_frequency: float) -> void:
	var candidates: Array[int] = []
	for region_id in range(mesh.num_regions):
		if water[region_id] or mesh.is_ghost_region(region_id) or mesh.is_boundary_region(region_id):
			continue
		var position: Vector2 = mesh.position_of_region(region_id)
		var sample: float = (MapgenUtil.fbm_noise(noise, [0.5, 0.25, 0.125], ((position.x - 500.0) / 500.0) * 0.9 + 7.1, ((position.y - 500.0) / 500.0) * 0.9 - 13.3) + 1.0) * 0.5
		if sample < lake_frequency:
			candidates.append(region_id)
	MapgenUtil.random_shuffle(candidates, random)
	var seen: Array[bool] = []
	seen.resize(mesh.num_regions)
	for region_id in range(mesh.num_regions):
		seen[region_id] = false
	for seed_id in candidates:
		if seen[seed_id]:
			continue
		var queue: Array[Vector2i] = [Vector2i(seed_id, 0)]
		seen[seed_id] = true
		var queue_index: int = 0
		while queue_index < queue.size():
			var queue_entry: Vector2i = queue[queue_index]
			queue_index += 1
			var current: int = queue_entry.x
			var distance: int = queue_entry.y
			water[current] = true
			if distance >= 2:
				continue
			for neighbor_id in mesh.regions_around_region(current):
				if water[neighbor_id] or seen[neighbor_id] or mesh.is_ghost_region(neighbor_id):
					continue
				seen[neighbor_id] = true
				queue.append(Vector2i(neighbor_id, distance + 1))
