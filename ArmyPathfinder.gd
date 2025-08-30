extends RefCounted
class_name ArmyPathfinder

# ============================================================================
# ARMY PATHFINDER
# ============================================================================
# 
# Purpose: Limited Dijkstra pathfinding for army movement planning
# 
# Core Responsibilities:
# - Calculate all reachable regions within MP horizon (R turns)
# - Provide movement cost calculations with ownership bonuses
# - Generate valid movement paths with MP consumption tracking
# - Support multi-turn strategic planning within MP limits
# 
# Key Features:
# - Limited Dijkstra with configurable horizon (default R=3 turns = 15 MP)
# - Uniform enterCost() calculation respecting terrain and ownership
# - Path reconstruction with MP trimming for valid moves
# - Pure pathfinding logic without target scoring integration
# 
# Integration Points:
# - RegionManager: Region adjacency and ownership information
# - ArmyManager: Terrain cost calculation with ownership bonuses
# - GameParameters: Algorithm parameters and movement constraints
# ============================================================================

# Manager references
var region_manager: RegionManager
var army_manager: ArmyManager

func _init(region_mgr: RegionManager, army_mgr: ArmyManager):
	region_manager = region_mgr
	army_manager = army_mgr

func find_reachable_regions(start_region_id: int, player_id: int, max_mp: int = -1) -> Dictionary:
	"""
	Find all regions reachable within MP limit using optimized Dijkstra.
	Returns Dictionary: region_id -> {cost: int, path: Array[int], parent: int}
	"""
	if max_mp == -1:
		max_mp = GameParameters.ARMY_PATHFINDER_HORIZON_MP
	
	# Initialize Dijkstra structures with optimized data structures
	var distances: Dictionary = {}  # region_id -> int (MP cost)
	var parents: Dictionary = {}    # region_id -> int (parent region_id)
	var visited: Dictionary = {}    # region_id -> bool
	var in_queue: Dictionary = {}   # region_id -> bool (prevent duplicates)
	var priority_queue = BinaryHeap.new()  # Efficient O(log n) priority queue
	
	# Start with the initial region
	distances[start_region_id] = 0
	parents[start_region_id] = -1
	priority_queue.insert({"region_id": start_region_id, "cost": 0})
	in_queue[start_region_id] = true
	
	var iterations = 0
	var max_iterations = 1000  # Safety limit
	
	while not priority_queue.is_empty() and iterations < max_iterations:
		iterations += 1
		
		# Extract minimum cost node with O(log n) efficiency
		var current = priority_queue.extract_min()
		var current_region_id = current.region_id
		var current_cost = current.cost
		in_queue.erase(current_region_id)  # Remove from queue tracking
		
		# Skip if already visited
		if visited.has(current_region_id):
			continue
		
		visited[current_region_id] = true
		
		# Explore neighbors
		var neighbors = region_manager.get_neighbor_regions(current_region_id)
		
		for neighbor_id in neighbors:
			if visited.has(neighbor_id):
				continue
			
			# Calculate movement cost to neighbor
			var enter_cost = _calculate_enter_cost(neighbor_id, player_id)
			if enter_cost == -1:  # Impassable terrain
				continue
			
			var new_cost = current_cost + enter_cost
			
			# Skip if exceeds MP horizon
			if new_cost > max_mp:
				continue
			
			# Update if better path found
			if not distances.has(neighbor_id) or new_cost < distances[neighbor_id]:
				distances[neighbor_id] = new_cost
				parents[neighbor_id] = current_region_id
				
				# Only add to queue if not already queued (prevent duplicates)
				if not in_queue.has(neighbor_id):
					priority_queue.insert({"region_id": neighbor_id, "cost": new_cost})
					in_queue[neighbor_id] = true
	
	
	# Build result with path reconstruction
	var result: Dictionary = {}
	for region_id in distances:
		var path = _reconstruct_path(parents, start_region_id, region_id)
		result[region_id] = {
			"cost": distances[region_id],
			"path": path,
			"parent": parents.get(region_id, -1)
		}
	
	return result

func _calculate_enter_cost(region_id: int, player_id: int) -> int:
	"""
	Calculate the MP cost to enter a region with ownership bonus.
	Returns -1 for impassable terrain.
	"""
	# Use centralized terrain cost calculation from RegionManager
	if region_manager != null:
		return region_manager.calculate_terrain_cost(region_id, player_id)
	
	# Fallback: calculate manually when region_manager not available
	var region_container = _get_region_container(region_id)
	if region_container == null:
		return -1
	
	var region = region_container as Region
	if region == null:
		return -1
	
	# Check if region is passable
	if not region.is_passable():
		return -1
	
	return region.get_movement_cost()

func _get_region_container(region_id: int) -> Node:
	"""Get region container node from region ID"""
	if region_manager == null or region_manager.map_generator == null:
		return null
	
	return region_manager.map_generator.get_region_container_by_id(region_id)

func _reconstruct_path(parents: Dictionary, start_id: int, target_id: int) -> Array[int]:
	"""
	Reconstruct path from start to target using parent tracking.
	Returns path as Array[int] of region IDs from start to target.
	"""
	if target_id == start_id:
		var single_path: Array[int] = [start_id]
		return single_path
	
	if not parents.has(target_id):
		var empty_path: Array[int] = []
		return empty_path  # No path found
	
	var path: Array[int] = []
	var current_id = target_id
	
	# Build path backwards from target to start
	while current_id != -1:
		path.append(current_id)
		current_id = parents.get(current_id, -1)
		
		# Safety check to prevent infinite loops
		if path.size() > 100:
			print("[ArmyPathfinder] Warning: Path reconstruction exceeded safety limit")
			break
	
	# Reverse to get path from start to target
	path.reverse()
	return path

func get_valid_moves_for_army(army: Army, current_region_id: int) -> Dictionary:
	"""
	Get all valid moves for an army based on its current MP.
	Returns Dictionary: region_id -> {cost: int, path: Array[int], remaining_mp: int}
	"""
	if army == null or not is_instance_valid(army):
		return {}
	
	var player_id = army.get_player_id()
	var current_mp = army.get_movement_points()
	
	# Find all reachable regions within current MP
	var reachable = find_reachable_regions(current_region_id, player_id, current_mp)
	
	# Filter for valid moves and add remaining MP calculation
	var valid_moves: Dictionary = {}
	for region_id in reachable:
		var region_data = reachable[region_id]
		var move_cost = region_data.cost
		
		# Skip start region
		if region_id == current_region_id:
			continue
		
		# Skip if army can't afford the move
		if move_cost > current_mp:
			continue
		
		# Check if army can actually move to this region
		var region_container = _get_region_container(region_id)
		if region_container != null and (army_manager == null or army_manager.can_army_move_to_region(army, region_container)):
			valid_moves[region_id] = {
				"cost": move_cost,
				"path": region_data.path,
				"remaining_mp": current_mp - move_cost
			}
	
	return valid_moves

func trim_path_to_mp_limit(path: Array[int], player_id: int, mp_limit: int) -> Array[int]:
	"""
	Trim a path to fit within MP limit.
	Returns the longest valid subpath from start that fits within MP.
	"""
	DebugLogger.log("ArmyPathfinder", "Trimming path with MP limit %d: %s" % [mp_limit, str(path)], 1)
	
	if path.size() <= 1:
		return path
	
	var trimmed_path: Array[int] = [path[0]]  # Always include start
	var total_cost = 0
	
	for i in range(1, path.size()):
		var region_id = path[i]
		var enter_cost = _calculate_enter_cost(region_id, player_id)
		
		DebugLogger.log("ArmyPathfinder", "  Step %d: Region %d, enter_cost=%d, total_cost=%d, limit=%d" % 
			[i, region_id, enter_cost, total_cost + enter_cost, mp_limit], 1)
		
		if enter_cost == -1 or total_cost + enter_cost > mp_limit:
			DebugLogger.log("ArmyPathfinder", "  Breaking: can't afford step (enter_cost=%d, total_would_be=%d, limit=%d)" % 
				[enter_cost, total_cost + enter_cost, mp_limit], 1)
			break  # Stop here, can't afford next step
		
		total_cost += enter_cost
		trimmed_path.append(region_id)
	
	DebugLogger.log("ArmyPathfinder", "Trimmed path result: %s (total_cost=%d)" % [str(trimmed_path), total_cost], 1)
	return trimmed_path

func calculate_path_cost(path: Array[int], player_id: int) -> int:
	"""
	Calculate total MP cost for a path.
	Returns -1 if path contains impassable regions.
	"""
	if path.size() <= 1:
		return 0
	
	var total_cost = 0
	
	for i in range(1, path.size()):
		var region_id = path[i]
		var enter_cost = _calculate_enter_cost(region_id, player_id)
		if enter_cost == -1:
			return -1  # Impassable region in path
		total_cost += enter_cost
	
	return total_cost

func find_path_to_target(start_region_id: int, target_region_id: int, player_id: int) -> Dictionary:
	"""
	Find shortest path from start to specific target region with early termination.
	Returns: {success: bool, path: Array[int], cost: int}
	"""
	# Use optimized Dijkstra with early termination for single target
	var result = _find_path_to_single_target(start_region_id, target_region_id, player_id)
	
	if not result.success:
		return {"success": false, "reason": "Target unreachable"}
	
	var path = result.path as Array[int]
	
	# Recalculate cost by summing individual region enter costs along the path
	var recalculated_cost = calculate_path_cost(path, player_id)
	
	return {
		"success": true,
		"path": path,
		"cost": recalculated_cost if recalculated_cost != -1 else result.cost
	}

func _find_path_to_single_target(start_region_id: int, target_region_id: int, player_id: int) -> Dictionary:
	"""
	Optimized Dijkstra with early termination for single target pathfinding.
	Stops immediately when target is found, providing optimal path with minimal exploration.
	Returns: {success: bool, path: Array[int], cost: int}
	"""
	if start_region_id == target_region_id:
		var single_path: Array[int] = [start_region_id]
		return {"success": true, "path": single_path, "cost": 0}
	
	# Initialize optimized Dijkstra structures
	var distances: Dictionary = {}  # region_id -> int (MP cost)
	var parents: Dictionary = {}    # region_id -> int (parent region_id)
	var visited: Dictionary = {}    # region_id -> bool
	var in_queue: Dictionary = {}   # region_id -> bool (prevent duplicates)
	var priority_queue = BinaryHeap.new()  # Efficient O(log n) priority queue
	
	# Start with the initial region
	distances[start_region_id] = 0
	parents[start_region_id] = -1
	priority_queue.insert({"region_id": start_region_id, "cost": 0})
	in_queue[start_region_id] = true
	
	var iterations = 0
	var max_iterations = 2000  # Higher limit for long-distance paths
	
	while not priority_queue.is_empty() and iterations < max_iterations:
		iterations += 1
		
		# Extract minimum cost node with O(log n) efficiency
		var current = priority_queue.extract_min()
		var current_region_id = current.region_id
		var current_cost = current.cost
		in_queue.erase(current_region_id)  # Remove from queue tracking
		
		# Skip if already visited
		if visited.has(current_region_id):
			continue
		
		visited[current_region_id] = true
		
		# EARLY TERMINATION: Stop immediately when target is reached
		if current_region_id == target_region_id:
			var path = _reconstruct_path(parents, start_region_id, target_region_id)
			return {"success": true, "path": path, "cost": current_cost}
		
		# Explore neighbors
		var neighbors = region_manager.get_neighbor_regions(current_region_id)
		
		for neighbor_id in neighbors:
			if visited.has(neighbor_id):
				continue
			
			# Calculate movement cost to neighbor
			var enter_cost = _calculate_enter_cost(neighbor_id, player_id)
			if enter_cost == -1:  # Impassable terrain
				continue
			
			var new_cost = current_cost + enter_cost
			
			# Update if better path found
			if not distances.has(neighbor_id) or new_cost < distances[neighbor_id]:
				distances[neighbor_id] = new_cost
				parents[neighbor_id] = current_region_id
				
				# Only add to queue if not already queued (prevent duplicates)
				if not in_queue.has(neighbor_id):
					priority_queue.insert({"region_id": neighbor_id, "cost": new_cost})
					in_queue[neighbor_id] = true
	
	var empty_path: Array[int] = []
	return {"success": false, "path": empty_path, "cost": -1}

func log_frontier_regions_summary(frontier_regions: Array, army_location: int, player_id: int) -> void:
	"""
	Log frontier regions with their paths and costs in a clear format.
	"""
	if frontier_regions.is_empty():
		DebugLogger.log("AIPathfinding", "No frontier regions found")
		return
	
	DebugLogger.log("AIPathfinding", "=== FRONTIER REGIONS FROM REGION %d ===" % army_location)
	
	for frontier_id in frontier_regions:
		# Find path to this frontier region
		var path_result = find_path_to_target(army_location, frontier_id, player_id)
		
		if not path_result.success:
			DebugLogger.log("AIPathfinding", "Region %d - UNREACHABLE" % frontier_id)
			continue
		
		var path = path_result.path
		var total_cost = path_result.cost
		
		# Build path string with MP costs for each step
		var path_parts: Array[String] = []
		
		for i in range(path.size()):
			var region_id = path[i]
			
			if i == 0:
				path_parts.append("Region %d (start)" % region_id)
			else:
				# Calculate the cost to enter this region
				var enter_cost = _calculate_enter_cost(region_id, player_id)
				if enter_cost > 0:
					path_parts.append("Region %d (%dMP)" % [region_id, enter_cost])
		
		var path_string = ", ".join(path_parts)
		DebugLogger.log("AIPathfinding", "Region %d - MP:%d, path: %s" % [frontier_id, total_cost, path_string])
