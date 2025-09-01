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

# Note: Scoring weights now handled by ArmyTargetScorer (single source)

# Manager references
var region_manager: RegionManager
var map_generator: MapGenerator
var army_target_scorer: ArmyTargetScorer

func _init(region_mgr: RegionManager, map_gen: MapGenerator):
	region_manager = region_mgr
	map_generator = map_gen
	DebugLogger.log("AIScoring", "Initialized with region and map manager references")
	army_target_scorer = ArmyTargetScorer.new(region_mgr, map_gen)

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
	"""Score all frontier targets for the player using canonical API"""
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
		
		# Use canonical raw base API
		var score_data = army_target_scorer.get_base_region_score_raw(region, player_id)
		if score_data.is_empty():
			continue
		
		# Package data using raw base total
		var frontier_data = {
			"region_id": region_id,
			"region_name": score_data.get("region_name", ""),
			"base_score": score_data.get("base_raw_total", 0.0),  # Raw total
			"region_score": score_data.get("base_raw_total", 0.0),  # Same as base_score
			# Store raw components for potential use
			"population_score": score_data.get("population_0_10", 0.0),
			"resource_score": score_data.get("resource_0_10", 0.0),
			"level_score": score_data.get("level_0_10", 0.0),
			"ownership_score": 0.0  # Not used anymore
		}
		scored_targets.append(frontier_data)
	
	# Sort by base score (highest first)
	scored_targets.sort_custom(func(a, b): return a.base_score > b.base_score)
	
	return scored_targets

