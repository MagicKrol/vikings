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

# Hover-based single region heatmap
var hover_overlays_root: Node2D = null
var current_hover_region_id: int = -1
var single_region_paths: Dictionary = {}  # region_id -> Array of paths to ocean borders

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
	
	# Handle mouse hover for single-region heatmap (only when heatmap is shown)
	if event is InputEventMouseMotion and overlays_root != null and (overlays_root.visible or hover_overlays_root != null):
		_handle_mouse_hover()

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
				endpoint_weight[int(t)] = 1.0
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

func _handle_mouse_hover() -> void:
	"""Handle mouse hover to show single-region heatmap"""
	# Get the global mouse position
	var world_pos = get_global_mouse_position()
	
	# Find which region is under the mouse
	var hovered_region_id = _find_region_at_position(world_pos)
	
	# If hovering over a different region, update the display
	if hovered_region_id != current_hover_region_id:
		current_hover_region_id = hovered_region_id
		
		# Only show single-region heatmap if hovering over an ocean-bordering region
		if hovered_region_id in ocean_border_regions:
			_show_single_region_heatmap(hovered_region_id)
		else:
			# Not hovering over ocean border - restore full heatmap
			_restore_full_heatmap()

func _find_region_at_position(world_pos: Vector2) -> int:
	"""Find which region contains the given world position"""
	for rid in map_generator.region_container_by_id.keys():
		var region_node = map_generator.get_region_container_by_id(int(rid))
		if region_node == null: continue
		
		var polygon_node = region_node.get_node_or_null("Polygon") as Polygon2D
		if polygon_node == null: continue
		
		# Convert world position to polygon's local position
		var local_pos = polygon_node.global_transform.affine_inverse() * world_pos
		
		# Check if point is inside polygon
		if Geometry2D.is_point_in_polygon(local_pos, polygon_node.polygon):
			return int(rid)
	
	return -1

func _is_ocean_region(region_id: int) -> bool:
	"""Check if a region is an ocean region"""
	var rdata = map_generator.region_by_id.get(region_id, {})
	return bool(rdata.get("ocean", false))

func _show_single_region_heatmap(start_region_id: int) -> void:
	"""Show single-source Brandes dependency heatmap from one ocean-border region"""
	if overlays_root == null:
		return

	# Hide the main heatmap overlay
	overlays_root.visible = false
	
	# Clear existing hover overlays
	if hover_overlays_root != null and is_instance_valid(hover_overlays_root):
		hover_overlays_root.queue_free()
	
	hover_overlays_root = Node2D.new()
	hover_overlays_root.name = "HoverHeatmapOverlays"
	hover_overlays_root.z_index = 181  # Above regular heatmap
	add_child(hover_overlays_root)
	
	# Compute Brandes single-source dependencies (delta) from hovered region
	var hover_values: Dictionary = _compute_single_source_dependencies(start_region_id)

	# Find max value for normalization
	var max_val: float = 0.0
	for v in hover_values.values():
		max_val = max(max_val, float(v))
	
	# Create colored overlays for all land regions
	for rid in map_generator.region_container_by_id.keys():
		var region_node = map_generator.get_region_container_by_id(int(rid))
		if region_node == null: continue
		
		var region := region_node as Region
		if region == null or region.is_ocean_region(): continue
		
		var poly_node := region_node.get_node_or_null("Polygon") as Polygon2D
		if poly_node == null: continue
		
		var pg := Polygon2D.new()
		pg.name = "HoverHeat_" + str(rid)
		pg.polygon = poly_node.polygon
		pg.z_index = 2 + poly_node.z_index
		
		# Get the dependency value for this region
		var val: float = float(hover_values.get(int(rid), 0.0))
		if int(rid) == start_region_id:
			# Highlight the start region in green
			pg.color = Color(0.0, 1.0, 0.0, 0.7)
		elif val > 0.0:
			# On corridor - gradient from white to red based on dependency value
			var t: float = 0.0
			if max_val > 0.0:
				t = val / max_val
			pg.color = Color(1.0, 1.0 - t, 1.0 - t, 0.5)  # White to red gradient
		else:
			# Not on any path - dim gray
			pg.color = Color(0.3, 0.3, 0.3, 0.2)
		
		hover_overlays_root.add_child(pg)

func _restore_full_heatmap() -> void:
	"""Restore the full strategic points heatmap"""
	# Clear hover overlays
	if hover_overlays_root != null and is_instance_valid(hover_overlays_root):
		hover_overlays_root.queue_free()
		hover_overlays_root = null
	
	# Restore main heatmap visibility
	if overlays_root != null:
		overlays_root.visible = true
	
	current_hover_region_id = -1

func _compute_single_source_dependencies(start_region_id: int) -> Dictionary:
	"""Brandes single-source accumulation restricted to ocean-border endpoints"""
	var result: Dictionary = {}
	if start_region_id == -1:
		return result
	
	# Build target set (all coast-adjacent land regions)
	var target_set: Dictionary = {}
	for rid in ocean_border_regions:
		target_set[int(rid)] = true
	
	# Standard Brandes BFS from single source
	var S: Array[int] = []
	var Q: Array[int] = []
	var P: Dictionary = {}         # int -> Array[int]
	var sigma: Dictionary = {}     # int -> int
	var dist: Dictionary = {}      # int -> int

	for rid in map_generator.region_by_id.keys():
		dist[int(rid)] = -1
		sigma[int(rid)] = 0

	dist[start_region_id] = 0
	sigma[start_region_id] = 1
	Q.append(start_region_id)

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

	# Endpoints contribute unit weight if reachable (exclude source itself)
	var endpoint_weight: Dictionary = {}
	for t in ocean_border_regions:
		if int(t) == int(start_region_id):
			continue
		if dist.has(int(t)) and int(dist[int(t)]) >= 0 and sigma.has(int(t)) and int(sigma[int(t)]) > 0:
			endpoint_weight[int(t)] = 1.0

	# Back-propagate dependencies
	var delta: Dictionary = {}
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
		if w != int(start_region_id):
			# Store dependency value for non-source nodes
			result[w] = float(delta.get(w, 0.0))

	return result

func _find_all_shortest_paths(start_id: int, goal_id: int) -> Array:
	"""Find all shortest paths from start to goal using BFS"""
	var all_paths: Array = []
	
	if start_id == goal_id:
		return [[start_id]]
	
	var queue: Array = []
	var visited_at_depth: Dictionary = {}  # region_id -> depth when first visited
	var parent_lists: Dictionary = {}  # region_id -> Array of parent region_ids
	
	queue.append([start_id, 0])  # [region_id, depth]
	visited_at_depth[start_id] = 0
	parent_lists[start_id] = []
	
	var goal_depth = -1
	
	# BFS to find all shortest paths
	while not queue.is_empty():
		var current_data = queue.pop_front()
		var current_id = current_data[0]
		var current_depth = current_data[1]
		
		# If we've already found the goal at a shallower depth, stop exploring
		if goal_depth != -1 and current_depth > goal_depth:
			break
		
		var neighbors = region_manager.get_neighbor_regions(current_id)
		for neighbor_id in neighbors:
			var neighbor_depth = current_depth + 1
			
			# If we've found the goal
			if neighbor_id == goal_id:
				if goal_depth == -1:
					goal_depth = neighbor_depth
				if neighbor_depth == goal_depth:
					# Add current as a parent of goal
					if not parent_lists.has(goal_id):
						parent_lists[goal_id] = []
					parent_lists[goal_id].append(current_id)
			
			# Process neighbor if not visited or visited at same depth (multiple shortest paths)
			if not visited_at_depth.has(neighbor_id):
				visited_at_depth[neighbor_id] = neighbor_depth
				parent_lists[neighbor_id] = [current_id]
				queue.append([neighbor_id, neighbor_depth])
			elif visited_at_depth[neighbor_id] == neighbor_depth:
				# Found another shortest path to this neighbor
				parent_lists[neighbor_id].append(current_id)
	
	# If no path found
	if not parent_lists.has(goal_id):
		return []
	
	# Reconstruct all paths
	_reconstruct_all_paths(start_id, goal_id, parent_lists, [], all_paths)
	
	return all_paths

func _reconstruct_all_paths(start_id: int, current_id: int, parent_lists: Dictionary, current_path: Array, all_paths: Array) -> void:
	"""Recursively reconstruct all shortest paths"""
	current_path.append(current_id)
	
	if current_id == start_id:
		# Found a complete path
		var complete_path = current_path.duplicate()
		complete_path.reverse()
		all_paths.append(complete_path)
	else:
		# Recurse through all parents
		var parents = parent_lists.get(current_id, [])
		for parent_id in parents:
			_reconstruct_all_paths(start_id, parent_id, parent_lists, current_path.duplicate(), all_paths)
