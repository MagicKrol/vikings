extends RefCounted
class_name CastlePlacementScorer

# ============================================================================
# CASTLE PLACEMENT SCORER
# ============================================================================
# 
# Purpose: Advanced castle placement evaluation using cluster-based scoring
# 
# Core Algorithm:
# 1. For each candidate region r, claim r + all passable neighbors as cluster C(r)
# 2. Aggregate population, resources, owned count, level across cluster
# 3. Calculate safety score based on distance to nearest enemy
# 4. Normalize all factors with percentile-based and soft-cap methods
# 5. Combine with weighted scoring for final ranking
# 
# Key Features:
# - Cluster-based evaluation (region + neighbors)
# - Resource balance using Shannon entropy
# - Diminishing returns via exponential soft-caps
# - Robust percentile-based normalization
# - Multi-factor weighted scoring
# ============================================================================

# Scoring weights (population reduced, safety remains critical)
const WEIGHTS = {
	"pop": 0.10,     # Reduced from 0.20 to 0.10 - population less important
	"res": 0.25, 
	"safety": 0.40,  # Safety is critical
	"size": 0.15,    # Increased size importance to compensate
	"level": 0.10    # Increased level importance to compensate
}

# Fixed normalization parameters based on GameParameters.gd ranges
# Individual region population: 200-400 (from POPULATION_BY_LEVEL)
const INDIVIDUAL_POPULATION_MIN = 200.0  
const INDIVIDUAL_POPULATION_MAX = 400.0  
# Cluster population: 1-8 regions × 200-400 each = 200-3200 total
const CLUSTER_POPULATION_MIN = 200.0    # 1 region × 200 min
const CLUSTER_POPULATION_MAX = 3200.0   # 8 regions × 400 max

# Resource ranges based on GameParameters.gd REGION_RESOURCES
# For clusters (1-8 regions), we use max possible values
const CLUSTER_RESOURCE_RANGES = {
	ResourcesEnum.Type.FOOD: {"min": 0.0, "max": 56.0},   # 8 regions × 7 max (grassland)
	ResourcesEnum.Type.WOOD: {"min": 0.0, "max": 64.0},   # 8 regions × 8 max (forest)
	ResourcesEnum.Type.STONE: {"min": 0.0, "max": 48.0},  # 8 regions × 6 max (hills)  
	ResourcesEnum.Type.IRON: {"min": 0.0, "max": 40.0},   # 8 regions × 5 max (hills)
	ResourcesEnum.Type.GOLD: {"min": 0.0, "max": 120.0}   # 8 regions × 15 max (hills)
}

# Safety scoring parameters
const LAMBDA = 4.0
const SAFE_FLOOR = 1.0

# Component references
var region_manager: RegionManager
var map_generator: MapGenerator

func _init(reg_manager: RegionManager, map_gen: MapGenerator):
	region_manager = reg_manager
	map_generator = map_gen

func score_castle_placement_candidates(enemy_region_ids: Array[int]) -> Array:
	"""
	Score all valid castle placement candidates using cluster-based algorithm.
	Returns sorted array of scoring results.
	"""
	
	# Get all passable regions as candidates
	var candidates = _get_passable_candidates()

	if candidates.is_empty():
		return []
	
	# Calculate clusters and aggregate metrics for each candidate
	var candidate_data = []
	for region_id in candidates:
		var cluster_data = _calculate_cluster_metrics(region_id, enemy_region_ids)
		if cluster_data != null:
			candidate_data.append(cluster_data)
	
	if candidate_data.is_empty():
		return []
	
	# Score each candidate using fixed normalization (no dynamic parameters needed)
	var scored_candidates: Array = []
	for data in candidate_data:
		var scores = _calculate_normalized_scores(data, {})  # Empty dict since we use fixed parameters now
		scores["regionId"] = data.region_id
		scored_candidates.append(scores)
	
	# Sort by OverallScore descending
	scored_candidates.sort_custom(func(a, b): return a.OverallScore > b.OverallScore)
	
	return scored_candidates

func _get_passable_candidates() -> Array[int]:
	"""Get all regions that can be used for castle placement (not mountains, not ocean, not already owned)"""
	var candidates: Array[int] = []
	
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		return candidates
	
	for child in regions_node.get_children():
		if child is Region:
			var region = child as Region
			# Skip mountains (impassable), oceans, and already owned regions
			if (region.get_region_type() != RegionTypeEnum.Type.MOUNTAINS and 
				not region.is_ocean_region() and 
				region.get_region_owner() == 0):  # Only neutral regions
				candidates.append(region.get_region_id())
	
	return candidates

func _calculate_cluster_metrics(region_id: int, enemy_region_ids: Array[int]) -> Dictionary:
	"""Calculate aggregated metrics for region + passable neighbors cluster"""
	var region = _get_region_by_id(region_id)
	if region == null:
		return {}
	
	# Build cluster: region + passable, unowned neighbors
	var cluster_regions = [region]
	var neighbor_ids = region_manager.get_neighbor_regions(region_id)
	
	for neighbor_id in neighbor_ids:
		var neighbor = _get_region_by_id(neighbor_id)
		if (neighbor != null and 
			neighbor.get_region_type() != RegionTypeEnum.Type.MOUNTAINS and
			neighbor.get_region_owner() == 0):  # Only include neutral neighbors
			cluster_regions.append(neighbor)
	
	# Aggregate metrics across cluster
	var total_population = 0
	var resource_totals = {
		ResourcesEnum.Type.FOOD: 0,
		ResourcesEnum.Type.WOOD: 0,
		ResourcesEnum.Type.STONE: 0,
		ResourcesEnum.Type.IRON: 0,
		ResourcesEnum.Type.GOLD: 0
	}
	var level_sum = 0
	
	for cluster_region in cluster_regions:
		# Population
		total_population += cluster_region.get_population()
		
		# Resources
		for resource_type in resource_totals:
			resource_totals[resource_type] += cluster_region.get_resource_amount(resource_type)
		
		# Level (convert enum to int)
		level_sum += _region_level_to_int(cluster_region.get_region_level())
	
	var level_avg = float(level_sum) / float(cluster_regions.size())
	var owned_count = cluster_regions.size()
	
	# Calculate distance to nearest enemy
	var distance_to_enemy = _calculate_distance_to_nearest_enemy(region_id, enemy_region_ids)
	
	return {
		"region_id": region_id,
		"total_population": total_population,
		"resource_totals": resource_totals,
		"owned_count": owned_count,
		"level_avg": level_avg,
		"distance_to_enemy": distance_to_enemy
	}

func _calculate_distance_to_nearest_enemy(start_region_id: int, enemy_region_ids: Array[int]) -> int:
	"""Calculate shortest path distance to nearest enemy using BFS"""
	if enemy_region_ids.is_empty():
		return 999  # No enemies, maximum safety
	
	# Multi-source BFS from all enemy regions
	var queue: Array[Dictionary] = []
	var visited: Dictionary = {}
	
	# Initialize with all enemy regions
	for enemy_id in enemy_region_ids:
		queue.append({"region_id": enemy_id, "distance": 0})
		visited[enemy_id] = 0
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_id = current.region_id
		var current_distance = current.distance
		
		# Check if we reached the start region
		if current_id == start_region_id:
			return current_distance
		
		# Explore neighbors
		var neighbor_ids = region_manager.get_neighbor_regions(current_id)
		for neighbor_id in neighbor_ids:
			if neighbor_id in visited:
				continue
			
			# Only traverse passable regions
			var neighbor = _get_region_by_id(neighbor_id)
			if neighbor == null or neighbor.get_region_type() == RegionTypeEnum.Type.MOUNTAINS:
				continue
			
			visited[neighbor_id] = current_distance + 1
			queue.append({"region_id": neighbor_id, "distance": current_distance + 1})
	
	print("[CastlePlacementScorer] No path found from region ", start_region_id, " to any enemy")
	return 999  # No path found

# REMOVED: _calculate_normalization_parameters function
# This function was causing score inflation as regions were claimed.
# All normalization now uses FIXED parameters defined at the top of the file.

func _calculate_normalized_scores(data: Dictionary, unused_params: Dictionary) -> Dictionary:
	"""Calculate all normalized scores for a candidate"""
	# Population normalization using GameParameters-based cluster ranges
	var pop_norm = clampf((data.total_population - CLUSTER_POPULATION_MIN) / (CLUSTER_POPULATION_MAX - CLUSTER_POPULATION_MIN), 0.0, 1.0)
	
	# Size normalization (1-8 regions)
	var size_score = clampf((data.owned_count - 1.0) / (8.0 - 1.0), 0.0, 1.0)
	
	# Resource scoring with balance using fixed parameters
	# Add debug flag for region 203
	var resource_totals_with_debug = data.resource_totals.duplicate()

	var resource_score = _calculate_resource_score(resource_totals_with_debug, {})
	
	# Safety scoring
	var safety_score = _calculate_safety_score(data.distance_to_enemy)

	# Level scoring
	var level_score = (data.level_avg - 1.0) / (2.0 - 1.0)  # Normalize to [0,1] for levels 1-2
	level_score = clampf(level_score, 0.0, 1.0)
	
	# Overall score (weighted combination)
	var overall_score = (
		WEIGHTS.pop * pop_norm +
		WEIGHTS.res * resource_score +
		WEIGHTS.safety * safety_score +
		WEIGHTS.size * size_score +
		WEIGHTS.level * level_score
	)
	
	# Calculate manual verification of the weighted sum
	var manual_calc = (WEIGHTS.pop * pop_norm + 
					   WEIGHTS.res * resource_score + 
					   WEIGHTS.safety * safety_score + 
					   WEIGHTS.size * size_score + 
					   WEIGHTS.level * level_score)
	
	return {
		"OverallScore": overall_score,
		"PopNorm": pop_norm,
		"ResourceScore": resource_score,
		"SafetyScore": safety_score,
		"SizeScore": size_score,
		"LevelScore": level_score,
		"cluster_data": data  # Include cluster data for tooltip access
	}

func _calculate_resource_score(resource_totals: Dictionary, unused_params: Dictionary) -> float:
	"""Calculate resource score - gold separate from distribution balance"""
	
	# Primary resources for distribution balance (exclude gold)
	var primary_resources = {
		ResourcesEnum.Type.FOOD: 1.5,   # Important for armies
		ResourcesEnum.Type.WOOD: 1.0,   # Building material
		ResourcesEnum.Type.STONE: 1.0,  # Building material  
		ResourcesEnum.Type.IRON: 1.2    # Advanced units
	}
	
	# Calculate primary resource score (balanced distribution)
	var primary_score = 0.0
	var total_weight = 0.0
	
	for resource_type in primary_resources:
		var quantity = resource_totals.get(resource_type, 0)
		var range_data = CLUSTER_RESOURCE_RANGES.get(resource_type, {"min": 0.0, "max": 1.0})
		var min_val = range_data.min
		var max_val = range_data.max
		
		# Linear normalization to 0-1
		var normalized = 0.0
		if max_val > min_val:
			normalized = clampf((quantity - min_val) / (max_val - min_val), 0.0, 1.0)
		
		# Add weighted contribution
		var weight = primary_resources[resource_type]
		primary_score += normalized * weight
		total_weight += weight
	
	# Average primary resources score
	var primary_avg = 0.0
	if total_weight > 0:
		primary_avg = primary_score / total_weight
	
	# Gold bonus (separate calculation, divided by 3)
	var gold_quantity = resource_totals.get(ResourcesEnum.Type.GOLD, 0)
	var gold_range = CLUSTER_RESOURCE_RANGES.get(ResourcesEnum.Type.GOLD, {"min": 0.0, "max": 120.0})
	var gold_normalized = 0.0
	if gold_range.max > gold_range.min:
		gold_normalized = clampf((gold_quantity - gold_range.min) / (gold_range.max - gold_range.min), 0.0, 1.0)
	
	# Gold bonus divided by 3 as requested
	var gold_bonus = gold_normalized / 3.0
	
	# Combine: 80% primary resources + 20% gold bonus
	var final_resource_score = 0.8 * primary_avg + 0.2 * gold_bonus
	
	return final_resource_score

func _calculate_safety_score(distance_to_enemy: int) -> float:
	"""Calculate safety score with exponential decay"""
	var adjusted_distance = max(distance_to_enemy - SAFE_FLOOR, 0.0)
	var safety_score = clampf(1.0 - exp(-adjusted_distance / LAMBDA), 0.0, 1.0)
	
	# Debug safety calculation - we'll check this in the calling function for region 203
	
	return safety_score

# Utility functions (percentile and median functions removed as they're no longer needed)

func _region_level_to_int(level: RegionLevelEnum.Level) -> int:
	"""Convert region level enum to integer"""
	match level:
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

func _get_region_by_id(region_id: int) -> Region:
	"""Get region by ID from map generator"""
	return map_generator.get_region_container_by_id(region_id) as Region

func calculate_individual_region_score(region: Region) -> float:
	"""Calculate a simple score for just this individual region using GameParameters ranges"""
	if region == null:
		return 0.0
	
	var score = 0.0
	
	# Population contribution (normalized using GameParameters individual ranges)
	var pop_norm = clampf((region.get_population() - INDIVIDUAL_POPULATION_MIN) / (INDIVIDUAL_POPULATION_MAX - INDIVIDUAL_POPULATION_MIN), 0.0, 1.0)
	score += pop_norm * WEIGHTS.pop
	
	# Individual resource contributions - gold separate from distribution balance
	var individual_resource_ranges = {
		ResourcesEnum.Type.FOOD: {"min": 0.0, "max": 7.0},   # Max from grassland
		ResourcesEnum.Type.WOOD: {"min": 0.0, "max": 8.0},   # Max from forest
		ResourcesEnum.Type.STONE: {"min": 0.0, "max": 6.0},  # Max from hills
		ResourcesEnum.Type.IRON: {"min": 0.0, "max": 5.0},   # Max from hills
		ResourcesEnum.Type.GOLD: {"min": 0.0, "max": 15.0}   # Max from hills
	}
	
	# Primary resources (exclude gold from distribution balance)
	var primary_resources = {
		ResourcesEnum.Type.FOOD: 1.5,
		ResourcesEnum.Type.WOOD: 1.0,
		ResourcesEnum.Type.STONE: 1.0,
		ResourcesEnum.Type.IRON: 1.2
	}
	
	# Calculate primary resources score
	var primary_score = 0.0
	var total_weight = 0.0
	
	for resource_type in primary_resources:
		var quantity = region.get_resource_amount(resource_type)
		var range_data = individual_resource_ranges.get(resource_type, {"min": 0.0, "max": 1.0})
		var normalized = clampf((quantity - range_data.min) / (range_data.max - range_data.min), 0.0, 1.0)
		var weight = primary_resources[resource_type]
		primary_score += normalized * weight
		total_weight += weight
	
	var primary_avg = 0.0
	if total_weight > 0:
		primary_avg = primary_score / total_weight
	
	# Gold bonus (separate, divided by 3)
	var gold_quantity = region.get_resource_amount(ResourcesEnum.Type.GOLD)
	var gold_range = individual_resource_ranges.get(ResourcesEnum.Type.GOLD, {"min": 0.0, "max": 15.0})
	var gold_normalized = clampf((gold_quantity - gold_range.min) / (gold_range.max - gold_range.min), 0.0, 1.0)
	var gold_bonus = gold_normalized / 3.0
	
	# Combine resources: 80% primary + 20% gold bonus
	var resource_score = 0.8 * primary_avg + 0.2 * gold_bonus
	score += resource_score * WEIGHTS.res
	
	# Region level contribution (1-5 levels, normalized to 0-1)
	var level_value = _region_level_to_int(region.get_region_level())
	var level_norm = (level_value - 1.0) / (5.0 - 1.0)  # Normalize 1-5 to 0-1
	score += level_norm * WEIGHTS.level
	
	# No safety or size component for individual regions (those are cluster-specific)
	
	return score

# Debug and utility methods

func print_top_candidates(candidates: Array[Dictionary], count: int = 10):
	pass

func get_candidate_details(region_id: int, enemy_region_ids: Array[int]) -> Dictionary:
	"""Get detailed breakdown for a specific candidate (for debugging) - DEPRECATED"""
	# This function is deprecated - use get_candidate_details_proper instead
	# which uses the correct fixed normalization parameters
	return get_candidate_details_proper(region_id, enemy_region_ids)

func get_candidate_details_proper(region_id: int, enemy_region_ids: Array[int]) -> Dictionary:
	"""Get detailed breakdown for a specific candidate using proper global normalization"""
	# Run full scoring to get proper normalization parameters
	var all_scores = score_castle_placement_candidates(enemy_region_ids)
	
	# Find this region's scores in the results
	for score_data in all_scores:
		if score_data.regionId == region_id:
			return score_data
	
	return {}
