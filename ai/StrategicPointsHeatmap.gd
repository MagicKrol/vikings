extends Node2D
class_name StrategicPointsHeatmap

# Standalone heatmap generator for ocean-border path centrality
# Usage:
# 1) Add this node to the scene (e.g., under Main) before castle placement
# 2) Call initialize(region_manager, map_generator)
# 3) Press key '8' to toggle heatmap overlay

var region_manager: RegionManager
var map_generator: MapGenerator

var ocean_border_regions: Array[int] = []
var heat_scores: Dictionary = {} # region_id -> int
var overlays_root: Node2D = null
var initialized: bool = false
var computed: bool = false
var use_multiplicity: bool = true  # true: count all parallel shortest paths; false: fractional like standard betweenness
var enable_key_toggle: bool = true

const TOGGLE_KEY := KEY_8

func initialize(region_mgr: RegionManager, map_gen: MapGenerator) -> void:
	region_manager = region_mgr
	map_generator = map_gen
	_initialized_setup()

func _ready() -> void:
	# Try auto-setup if not explicitly initialized, but keep KISS
	if region_manager == null or map_generator == null:
		var mg = get_node_or_null("../Map") as MapGenerator
		var gm = get_node_or_null("../GameManager") as GameManager
		if mg != null:
			map_generator = mg
		if gm != null:
			region_manager = gm.get_region_manager()
	_initialized_setup()

func _initialized_setup() -> void:
	if region_manager == null or map_generator == null:
		return
	initialized = true
	ocean_border_regions = _find_ocean_border_regions()
	# Pre-fill heat map with zeros for all land regions
	for rid in map_generator.region_by_id.keys():
		var rdata: Dictionary = map_generator.region_by_id[rid]
		if not bool(rdata.get("ocean", false)):
			heat_scores[int(rid)] = 0

func _unhandled_input(event: InputEvent) -> void:
	if not initialized or not enable_key_toggle:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == TOGGLE_KEY:
			if not computed:
				_compute_heat_scores()
				_build_overlays()
				computed = true
			_toggle_overlays()

func compute_and_show() -> void:
	# Convenience for debug mode: compute once and show overlay immediately
	if not initialized:
		return
	if not computed:
		_compute_heat_scores()
		_apply_scores_to_regions()
		_build_overlays()
		computed = true
	if overlays_root != null:
		overlays_root.visible = true

func compute_and_store() -> void:
	# Compute scores and write them into Region nodes; no overlays, no input
	if not initialized:
		return
	if not computed:
		_compute_heat_scores()
		_apply_scores_to_regions()
		computed = true

func _find_ocean_border_regions() -> Array[int]:
	# Identify non-ocean regions with any edge adjacent to an ocean region
	var ocean_set: Dictionary = {}
	for r in map_generator.regions:
		if bool(r.get("ocean", false)):
			ocean_set[int(r.get("id", -1))] = true
	
	var border_set: Dictionary = {}
	for e in map_generator.edges:
		var r0 := int(e.get("region1", -1))
		var r1 := int(e.get("region2", -1))
		if r0 == -1 or r1 == -1:
			continue
		var ocean0 := ocean_set.has(r0)
		var ocean1 := ocean_set.has(r1)
		if ocean0 == ocean1:
			continue
		# Add the land region id to border set
		var land_id := r1 if ocean0 else r0
		border_set[land_id] = true
	
	var out: Array[int] = []
	for k in border_set.keys(): out.append(int(k))
	return out

func _compute_heat_scores() -> void:
	# Brandes-like accumulation restricted to ocean-border targets.
	var target_set: Dictionary = {}
	for rid in ocean_border_regions:
		target_set[int(rid)] = true
	for s in ocean_border_regions:
		# Single-source shortest paths
		var S: Array[int] = []
		var Q: Array[int] = []
		var P: Dictionary = {}         # int -> Array[int]
		var sigma: Dictionary = {}     # int -> int
		var dist: Dictionary = {}      # int -> int
		# init
		sigma[int(s)] = 1
		dist[int(s)] = 0
		Q.append(int(s))
		while not Q.is_empty():
			var v: int = int(Q.pop_front())
			S.append(v)
			var neigh: Array[int] = region_manager.get_neighbor_regions(v)
			for w in neigh:
				if not dist.has(w):
					dist[w] = -1
				if int(dist[w]) < 0:
					Q.append(int(w))
					dist[w] = int(dist[v]) + 1
				if int(dist[w]) == int(dist[v]) + 1:
					sigma[w] = int(sigma.get(w, 0)) + int(sigma.get(v, 0))
					var plist: Array[int] = []
					if P.has(w):
						plist = P[w]
					if not plist.has(v):
						plist.append(v)
					P[w] = plist
		# Endpoint weights for restricted targets
		var endpoint_weight: Dictionary = {}  # int -> float
		for t in ocean_border_regions:
			if int(t) == int(s):
				continue
			# Only count reachable targets
			if dist.has(int(t)) and int(dist[int(t)]) >= 0 and sigma.has(int(t)) and int(sigma[int(t)]) > 0:
				endpoint_weight[int(t)] = float(sigma[int(t)]) if use_multiplicity else 1.0
		# Accumulation
		var delta: Dictionary = {}  # int -> float
		while not S.is_empty():
			var w: int = int(S.pop_back())
			var ew: float = float(endpoint_weight.get(w, 0.0))
			var dw: float = float(delta.get(w, 0.0))
			var denom: float = float(sigma.get(w, 0))
			if P.has(w) and denom > 0.0:
				var preds: Array[int] = P[w]
				for v in preds:
					var add := (float(sigma.get(v, 0)) / denom) * (ew + dw)
					delta[v] = float(delta.get(v, 0.0)) + add
			if w != int(s):
				# Add only dependency (excludes endpoints), accumulate as float
				heat_scores[w] = float(heat_scores.get(w, 0.0)) + float(delta.get(w, 0.0))

func _bfs_shortest_path(start_id: int, goal_id: int) -> Array[int]:
	# BFS over RegionManager adjacency (non-ocean graph)
	if start_id == goal_id:
		return [start_id]
	var queue: Array[int] = []
	var visited: Dictionary = {}
	var parent: Dictionary = {}
	queue.append(start_id)
	visited[start_id] = true
	parent[start_id] = -1
	while not queue.is_empty():
		var cur: int = int(queue.pop_front())
		if cur == goal_id:
			break
		var neigh: Array[int] = region_manager.get_neighbor_regions(cur)
		for nb in neigh:
			if not visited.has(nb):
				visited[nb] = true
				parent[nb] = cur
				queue.append(nb)
	# Reconstruct
	if not parent.has(goal_id):
		return []
	var path: Array[int] = []
	var node_id: int = goal_id
	while node_id != -1:
		path.append(node_id)
		node_id = int(parent.get(node_id, -1))
	path.reverse()
	return path

func _build_overlays() -> void:
	if overlays_root != null and is_instance_valid(overlays_root):
		overlays_root.queue_free()
		overlays_root = null
	
	overlays_root = Node2D.new()
	overlays_root.name = "HeatmapOverlays"
	overlays_root.z_index = 180
	add_child(overlays_root)

	# Determine min/max for normalization
	var min_v := 1e9
	var max_v := -1e9
	for rid in heat_scores.keys():
		var v := float(heat_scores[rid])
		min_v = min(min_v, v)
		max_v = max(max_v, v)
	if max_v < min_v: max_v = min_v

	# Create overlays for land regions
	for rid in map_generator.region_container_by_id.keys():
		var region_node = map_generator.get_region_container_by_id(int(rid))
		if region_node == null: continue
		var region := region_node as Region
		if region == null: continue
		if region.is_ocean_region(): continue
		var poly_node := region_node.get_node_or_null("Polygon") as Polygon2D
		if poly_node == null: continue
		var pg := Polygon2D.new()
		pg.name = "Heat_" + str(rid)
		pg.polygon = poly_node.polygon
		pg.z_index = 1 + poly_node.z_index
		var val := float(heat_scores.get(int(rid), 0))
		var t := 0.0
		if max_v > 0.0:
			t = val / max_v
		# Color gradient: white (low) -> deep red (high)
		var col := Color(1.0, 1.0 - t, 1.0 - t, 0.5)
		pg.color = col
		overlays_root.add_child(pg)

func _toggle_overlays() -> void:
	if overlays_root == null:
		return
	overlays_root.visible = not overlays_root.visible

func _apply_scores_to_regions() -> void:
	# Write normalized/absolute scores into Region nodes for future use
	# Store normalized score in [0..10], where max heat value maps to 10.0
	var max_v: float = 0.0
	for rid in heat_scores.keys():
		max_v = max(max_v, float(heat_scores[rid]))
	for rid in map_generator.region_container_by_id.keys():
		var region_node = map_generator.get_region_container_by_id(int(rid))
		var region := region_node as Region
		if region == null: continue
		if region.is_ocean_region():
			region.set_strategic_point_score(0.0)
			continue
		var raw := float(heat_scores.get(int(rid), 0.0))
		var norm := 0.0
		if max_v > 0.0:
			norm = (raw / max_v) * 10.0
		region.set_strategic_point_score(norm)
