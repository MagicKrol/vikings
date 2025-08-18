extends Resource

class_name RegionGraph

# Holds adjacency for non-ocean regions: region_id -> Array[int] neighbor ids
var adjacency: Dictionary = {}

# region_id -> Vector2 center
var centers: Dictionary = {}

static func _is_mountain_region(region_data: Dictionary) -> bool:
	"""Check if a region is a mountain region (non-interactive terrain like ocean)"""
	var biome_name := String(region_data.get("biome", "")).to_lower()
	return biome_name == "mountains"

static func build_non_ocean_adjacency(regions: Array, edges: Array) -> Dictionary:
	var region_by_id: Dictionary = {}
	for r in regions:
		var rid := int(r.get("id", -1))
		if rid >= 0:
			region_by_id[rid] = r

	var graph: Dictionary = {}
	# Initialize nodes for non-ocean, non-mountain regions
	for r in regions:
		var is_ocean = bool(r.get("ocean", false))
		var is_mountain = _is_mountain_region(r)
		if not is_ocean and not is_mountain:
			var rid := int(r.get("id", -1))
			if rid >= 0:
				graph[rid] = []

	# Add edges between neighboring non-ocean, non-mountain regions
	for e in edges:
		var r0 := int(e.get("region1", -1))
		var r1 := int(e.get("region2", -1))
		if r0 == -1 or r1 == -1:
			continue
		var reg0: Dictionary = region_by_id.get(r0, {})
		var reg1: Dictionary = region_by_id.get(r1, {})
		if reg0.is_empty() or reg1.is_empty():
			continue
		var ocean0 := bool(reg0.get("ocean", false))
		var ocean1 := bool(reg1.get("ocean", false))
		var mountain0 := _is_mountain_region(reg0)
		var mountain1 := _is_mountain_region(reg1)
		if ocean0 or ocean1 or mountain0 or mountain1:
			continue

		if not graph.has(r0):
			graph[r0] = []
		if not graph.has(r1):
			graph[r1] = []
		if not graph[r0].has(r1):
			graph[r0].append(r1)
		if not graph[r1].has(r0):
			graph[r1].append(r0)

	return graph

static func compute_region_centers(regions: Array) -> Dictionary:
	var centers: Dictionary = {}
	for r in regions:
		var is_ocean = bool(r.get("ocean", false))
		var is_mountain = _is_mountain_region(r)
		if not is_ocean and not is_mountain:
			var rid := int(r.get("id", -1))
			var cdata: Array = r.get("center", [])
			if rid >= 0 and cdata.size() == 2:
				centers[rid] = Vector2(cdata[0], cdata[1])
	return centers
