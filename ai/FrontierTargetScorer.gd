extends RefCounted
class_name FrontierTargetScorer

# ============================================================================
# FRONTIER TARGET SCORER
# ============================================================================
# 
# Purpose: Score frontier regions (enemy/neutral regions adjacent to owned)
# 
# Core Algorithm:
# 1. Identify frontier targets (enemy/neutral regions next to owned regions)
# 2. Score based on pure value: resources, population, level, ownership
# 3. No movement costs included in base scoring
# ============================================================================

# Scoring weights for frontier targets
const WEIGHTS = {
	"population": 0.30,    # Population importance for conquest
	"resources": 0.40,     # Resource value for economic gain
	"level": 0.20,         # Region development level
	"ownership": 0.10      # Ownership status bonus/penalty
}

# Manager references
var region_manager: RegionManager
var map_generator: MapGenerator

func _init(region_mgr: RegionManager, map_gen: MapGenerator):
	region_manager = region_mgr
	map_generator = map_gen
	DebugLogger.log("AIScoring", "Initialized with region and map manager references")

func get_frontier_targets(player_id: int) -> Array[int]:
	"""Get all enemy/neutral regions adjacent to player's owned regions"""
	var frontier_targets: Array[int] = []
	var added_targets = {}  # Track to avoid duplicates
	
	# Get all player's regions
	var player_regions = region_manager.get_player_regions(player_id)
	
	# For each owned region, check its neighbors
	for region_id in player_regions:
		var neighbors = region_manager.get_neighbor_regions(region_id)
		
		for neighbor_id in neighbors:
			# Skip if already added
			if added_targets.has(neighbor_id):
				continue
				
			var neighbor_owner = region_manager.get_region_owner(neighbor_id)
			
			# Add if enemy or neutral (not owned by player)
			if neighbor_owner != player_id:
				# Check if region is passable
				var neighbor_region = map_generator.get_region_container_by_id(neighbor_id) as Region
				if neighbor_region and neighbor_region.is_passable():
					frontier_targets.append(neighbor_id)
					added_targets[neighbor_id] = true
	
	return frontier_targets

func score_frontier_targets(player_id: int) -> Array:
	"""Score all frontier targets for the player"""
	var frontier_ids = get_frontier_targets(player_id)
	
	if frontier_ids.is_empty():
		DebugLogger.log("AIScoring", "No frontier targets found for Player " + str(player_id))
		return []
	
	DebugLogger.log("AIScoring", "Scoring " + str(frontier_ids.size()) + " frontier targets for Player " + str(player_id))
	
	var scored_targets = []
	
	for region_id in frontier_ids:
		var region_container = map_generator.get_region_container_by_id(region_id)
		if region_container == null:
			continue
			
		var region = region_container as Region
		if region == null:
			continue
		
		var score_data = _calculate_pure_region_score(region, player_id)
		score_data["region_id"] = region_id
		scored_targets.append(score_data)
	
	# Sort by score (highest first)
	scored_targets.sort_custom(func(a, b): return a.base_score > b.base_score)
	
	return scored_targets

func _calculate_pure_region_score(region: Region, player_id: int) -> Dictionary:
	"""Calculate pure value score without movement costs"""
	var region_name = region.get_region_name()
	
	# Calculate individual score components
	var population_score = _calculate_population_score(region)
	var resource_score = _calculate_resource_score(region)
	var level_score = _calculate_level_score(region)
	var ownership_score = _calculate_ownership_score(region, player_id)
	
	# Calculate weighted overall score
	var base_score = (
		population_score * WEIGHTS.population +
		resource_score * WEIGHTS.resources +
		level_score * WEIGHTS.level +
		ownership_score * WEIGHTS.ownership
	)
	
	return {
		"region_name": region_name,
		"population_score": population_score,
		"resource_score": resource_score,
		"level_score": level_score,
		"ownership_score": ownership_score,
		"base_score": base_score
	}

func _calculate_population_score(region: Region) -> float:
	"""Calculate normalized population score"""
	var population = region.get_population()
	
	# Simple linear normalization (200-400 range typical)
	var min_pop = 200.0
	var max_pop = 400.0
	
	var normalized_pop = clampf(
		(population - min_pop) / (max_pop - min_pop),
		0.0, 1.0
	)
	
	return normalized_pop

func _calculate_resource_score(region: Region) -> float:
	"""Calculate resource score based on total resource value"""
	var resource_composition = region.get_resources()
	if resource_composition == null:
		return 0.0
	
	# Weight different resources by importance
	var resource_weights = {
		ResourcesEnum.Type.FOOD: 1.5,
		ResourcesEnum.Type.WOOD: 1.0,
		ResourcesEnum.Type.STONE: 1.0,
		ResourcesEnum.Type.IRON: 1.2,
		ResourcesEnum.Type.GOLD: 2.0
	}
	
	var total_score = 0.0
	var max_possible = 0.0
	
	for resource_type in resource_weights:
		var quantity = resource_composition.get_resource_amount(resource_type)
		var weight = resource_weights[resource_type]
		
		# Assume max 20 for most resources
		var max_quantity = 20.0
		total_score += (quantity / max_quantity) * weight
		max_possible += weight
	
	# Normalize to 0-1
	return total_score / max_possible if max_possible > 0 else 0.0

func _calculate_level_score(region: Region) -> float:
	"""Calculate normalized level score"""
	var region_level = region.get_region_level()
	
	# Convert enum to integer (L1=1, L2=2, ... L5=5)
	var level_int = 1
	match region_level:
		RegionLevelEnum.Level.L1: level_int = 1
		RegionLevelEnum.Level.L2: level_int = 2
		RegionLevelEnum.Level.L3: level_int = 3
		RegionLevelEnum.Level.L4: level_int = 4
		RegionLevelEnum.Level.L5: level_int = 5
	
	# Normalize to 0-1 range
	return (level_int - 1.0) / 4.0

func _calculate_ownership_score(region: Region, player_id: int) -> float:
	"""Calculate ownership bonus/penalty"""
	var region_id = region.get_region_id()
	var current_owner = region_manager.get_region_owner(region_id)
	
	if current_owner == -1:
		# Neutral region - easier to capture
		return 0.8
	else:
		# Enemy region - harder but more valuable
		return 1.0