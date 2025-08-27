extends RefCounted
class_name RegionScorer

# ============================================================================
# REGION SCORER
# ============================================================================
# 
# Purpose: AI region evaluation and scoring system
# 
# Core Responsibilities:
# - Calculate strategic value scores for regions (0-100 scale)
# - Analyze population, resources, levels, and strategic position
# - Provide pathfinding utilities for distance calculations
# - Normalize scores to consistent 0-100 range
# 
# Scoring Factors:
# - Population value and recruitment potential
# - Resource availability (gold, food, wood, stone, iron)
# - Region and castle level strategic importance
# - Neighbor analysis (owned, neutral, enemy territories)
# - Distance to nearest enemy positions
# 
# Integration Points:
# - GameParameters: All scoring weights and normalization values
# - RegionManager: Territory ownership and neighbor relationships
# - Region: Population, resource, and infrastructure data
# - MapGenerator: Spatial region access and pathfinding data
# ============================================================================

# Manager references for data access
var region_manager: RegionManager
var map_generator: MapGenerator

func _init(region_mgr: RegionManager, map_gen: MapGenerator):
	region_manager = region_mgr
	map_generator = map_gen

## Core Scoring Methods

func calculate_region_score(region: Region, evaluating_player_id: int) -> float:
	"""Calculate total strategic score for a region (0-100 scale)"""
	if region == null:
		return 0.0
	
	var total_score = 0.0
	
	# Population scoring
	total_score += _calculate_population_score(region)
	
	# Resource scoring
	total_score += _calculate_resource_score(region)
	
	# Strategic infrastructure scoring
	total_score += _calculate_level_score(region)
	total_score += _calculate_castle_score(region)
	
	# Position and neighbor analysis
	total_score += _calculate_neighbor_score(region, evaluating_player_id)
	total_score += _calculate_distance_score(region, evaluating_player_id)
	
	# Clamp to 0-100 range
	return clamp(total_score, 0.0, 100.0)

func _calculate_population_score(region: Region) -> float:
	"""Score based on population size and recruitment potential"""
	var population = region.get_population()
	var normalized = min(population / float(GameParameters.AI_POPULATION_MAX_EXPECTED), 1.0)
	return normalized * 100.0 * GameParameters.AI_POPULATION_WEIGHT

func _calculate_resource_score(region: Region) -> float:
	"""Score based on available resources with individual weights"""
	var total_resource_score = 0.0
	
	# Gold resources
	var gold = region.get_resource_amount(ResourcesEnum.Type.GOLD)
	total_resource_score += _score_resource(gold, GameParameters.AI_GOLD_RESOURCE_WEIGHT)
	
	# Food resources  
	var food = region.get_resource_amount(ResourcesEnum.Type.FOOD)
	total_resource_score += _score_resource(food, GameParameters.AI_FOOD_RESOURCE_WEIGHT)
	
	# Wood resources
	var wood = region.get_resource_amount(ResourcesEnum.Type.WOOD)
	total_resource_score += _score_resource(wood, GameParameters.AI_WOOD_RESOURCE_WEIGHT)
	
	# Stone resources
	var stone = region.get_resource_amount(ResourcesEnum.Type.STONE)
	total_resource_score += _score_resource(stone, GameParameters.AI_STONE_RESOURCE_WEIGHT)
	
	# Iron resources
	var iron = region.get_resource_amount(ResourcesEnum.Type.IRON)
	total_resource_score += _score_resource(iron, GameParameters.AI_IRON_RESOURCE_WEIGHT)
	
	return total_resource_score

func _score_resource(amount: int, weight: float) -> float:
	"""Score individual resource with weight and normalization"""
	var normalized = min(amount / float(GameParameters.AI_MAX_EXPECTED_RESOURCE), 1.0)
	return normalized * weight

func _calculate_level_score(region: Region) -> float:
	"""Score based on region administrative level"""
	var level_int = _region_level_to_int(region.get_region_level())
	return level_int * GameParameters.AI_REGION_LEVEL_WEIGHT

func _calculate_castle_score(region: Region) -> float:
	"""Score based on castle level and defensive value"""
	var castle_level_int = _castle_type_to_int(region.get_castle_type())
	return castle_level_int * GameParameters.AI_CASTLE_LEVEL_WEIGHT

func _calculate_neighbor_score(region: Region, evaluating_player_id: int) -> float:
	"""Score based on neighbor analysis and strategic position"""
	var region_id = region.get_region_id()
	var neighbor_ids = region_manager.get_neighbor_regions(region_id)
	
	var owned_count = 0
	var neutral_count = 0
	var enemy_count = 0
	var total_count = neighbor_ids.size()
	
	# Analyze each neighbor
	for neighbor_id in neighbor_ids:
		var owner_id = region_manager.get_region_owner(neighbor_id)
		if owner_id == evaluating_player_id:
			owned_count += 1
		elif owner_id == -1:  # Neutral
			neutral_count += 1
		else:  # Enemy
			enemy_count += 1
	
	# Calculate weighted neighbor score
	var neighbor_score = 0.0
	neighbor_score += owned_count * GameParameters.AI_OWNED_NEIGHBOR_WEIGHT
	neighbor_score += neutral_count * GameParameters.AI_NEUTRAL_NEIGHBOR_WEIGHT
	neighbor_score += enemy_count * GameParameters.AI_ENEMY_NEIGHBOR_WEIGHT
	neighbor_score += total_count * GameParameters.AI_TOTAL_NEIGHBOR_WEIGHT
	
	return neighbor_score

func _calculate_distance_score(region: Region, evaluating_player_id: int) -> float:
	"""Score based on distance to nearest enemy region"""
	var distance = _find_distance_to_nearest_enemy(region, evaluating_player_id)
	
	if distance <= 0:
		return 0.0  # No enemies found or invalid distance
	
	# Closer enemies = higher strategic value (inverse relationship)
	var normalized_distance = min(distance / float(GameParameters.AI_MAX_EXPECTED_DISTANCE), 1.0)
	var proximity_score = (1.0 - normalized_distance) * GameParameters.AI_ENEMY_DISTANCE_WEIGHT
	
	return proximity_score

## Pathfinding and Distance Utilities

func _find_distance_to_nearest_enemy(region: Region, evaluating_player_id: int) -> int:
	"""Find shortest path distance to nearest enemy region using BFS"""
	var region_id = region.get_region_id()
	var visited = {}
	var queue = []
	
	# Initialize BFS
	queue.append({"region_id": region_id, "distance": 0})
	visited[region_id] = true
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_region_id = current.region_id
		var current_distance = current.distance
		
		# Check if current region is owned by an enemy
		var owner_id = region_manager.get_region_owner(current_region_id)
		if owner_id != -1 and owner_id != evaluating_player_id:
			return current_distance
		
		# Add unvisited neighbors to queue
		var neighbors = region_manager.get_neighbor_regions(current_region_id)
		for neighbor_id in neighbors:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append({"region_id": neighbor_id, "distance": current_distance + 1})
	
	return -1  # No enemy regions found

func calculate_movement_path_cost(from_region: Region, to_region: Region, player_id: int) -> int:
	"""Calculate movement points needed to reach target region (future: for AI army movement)"""
	# TODO: Implement movement cost pathfinding considering terrain and ownership
	# For now, return simple region distance
	return _calculate_region_distance(from_region.get_region_id(), to_region.get_region_id())

func _calculate_region_distance(from_region_id: int, to_region_id: int) -> int:
	"""Calculate shortest region path distance between two regions"""
	if from_region_id == to_region_id:
		return 0
	
	var visited = {}
	var queue = []
	
	# Initialize BFS
	queue.append({"region_id": from_region_id, "distance": 0})
	visited[from_region_id] = true
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_region_id = current.region_id
		var current_distance = current.distance
		
		# Check if we reached target
		if current_region_id == to_region_id:
			return current_distance
		
		# Add unvisited neighbors to queue
		var neighbors = region_manager.get_neighbor_regions(current_region_id)
		for neighbor_id in neighbors:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append({"region_id": neighbor_id, "distance": current_distance + 1})
	
	return -1  # No path found

## Helper Methods

func _region_level_to_int(region_level: RegionLevelEnum.Level) -> int:
	"""Convert region level enum to integer for scoring"""
	match region_level:
		RegionLevelEnum.Level.L1:
			return 1
		RegionLevelEnum.Level.L2:
			return 2
		RegionLevelEnum.Level.L3:
			return 3
		RegionLevelEnum.Level.L4:
			return 4
		RegionLevelEnum.Level.L5:
			return 5
		_:
			return 1

func _castle_type_to_int(castle_type: CastleTypeEnum.Type) -> int:
	"""Convert castle type to integer level for scoring"""
	match castle_type:
		CastleTypeEnum.Type.NONE:
			return 0
		CastleTypeEnum.Type.OUTPOST:
			return 1
		CastleTypeEnum.Type.KEEP:
			return 2
		CastleTypeEnum.Type.CASTLE:
			return 3
		CastleTypeEnum.Type.STRONGHOLD:
			return 4
		_:
			return 0

## Public Scoring Interface

func score_all_regions_for_player(player_id: int) -> Dictionary:
	"""Calculate scores for all regions from a player's perspective"""
	var scores = {}
	
	# Get all region containers from map generator
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		print("[RegionScorer] Warning: No Regions node found")
		return scores
	
	# Score each region
	for child in regions_node.get_children():
		if child is Region:
			var region = child as Region
			var region_id = region.get_region_id()
			var score = calculate_region_score(region, player_id)
			scores[region_id] = score
	
	return scores

func get_top_scored_regions(player_id: int, count: int) -> Array:
	"""Get the highest scoring regions for a player"""
	var all_scores = score_all_regions_for_player(player_id)
	var sorted_regions = []
	
	# Convert to array of dictionaries for sorting
	for region_id in all_scores:
		sorted_regions.append({
			"region_id": region_id,
			"score": all_scores[region_id]
		})
	
	# Sort by score descending
	sorted_regions.sort_custom(func(a, b): return a.score > b.score)
	
	# Return top N regions
	var top_regions = []
	for i in range(min(count, sorted_regions.size())):
		top_regions.append(sorted_regions[i])
	
	return top_regions