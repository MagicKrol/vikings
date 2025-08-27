extends RefCounted
class_name ArmyTargetScorer

# ============================================================================
# ARMY TARGET SCORER
# ============================================================================
# 
# Purpose: Region-based scoring for army movement target selection
# 
# Core Algorithm:
# 1. Score individual target regions (no clustering)
# 2. Calculate population, resource, and level scores
# 3. Normalize scores based on individual region ranges
# 4. Combine with weighted scoring for final ranking
# 
# Key Features:
# - Individual region evaluation (no neighbors considered)
# - Resource balance scoring adapted from castle placement
# - Population and level importance
# - Conquest potential assessment
# ============================================================================

# Scoring weights for army target selection
const WEIGHTS = {
	"population": 0.30,    # Population importance for conquest
	"resources": 0.40,     # Resource value for economic gain
	"level": 0.20,         # Region development level
	"ownership": 0.10      # Ownership status bonus/penalty
}

# Population ranges from GameParameters (L1 level)
static func _get_population_range() -> Dictionary:
	return GameParameters.POPULATION_BY_LEVEL.get(RegionLevelEnum.Level.L1, {"min": 200, "max": 400})

# Resource ranges derived from GameParameters region resources
static func _get_resource_max(resource_type: ResourcesEnum.Type) -> float:
	var max_value = 0.0
	# Find maximum possible value across all region types
	for region_type in GameParameters.REGION_RESOURCES:
		var region_resources = GameParameters.REGION_RESOURCES[region_type]
		if region_resources.has(resource_type):
			var resource_range = region_resources[resource_type]
			if resource_range.has("max"):
				max_value = max(max_value, float(resource_range.max))
	return max_value

# Manager references
var region_manager: RegionManager
var map_generator: MapGenerator

func _init(region_mgr: RegionManager, map_gen: MapGenerator):
	region_manager = region_mgr
	map_generator = map_gen
	print("[ArmyTargetScorer] Initialized with region and map manager references")

func score_target_regions(target_region_ids: Array[int], player_id: int) -> Array:
	"""Score an array of target regions for army movement decisions"""
	print("[ArmyTargetScorer] Scoring ", target_region_ids.size(), " target regions for Player ", player_id)
	
	var scored_targets = []
	
	for region_id in target_region_ids:
		var region_container = map_generator.get_region_container_by_id(region_id)
		if region_container == null:
			continue
			
		var region = region_container as Region
		if region == null:
			continue
		
		var score_data = _calculate_region_score(region, player_id)
		scored_targets.append(score_data)
	
	# Sort by overall score (highest first)
	scored_targets.sort_custom(func(a, b): return a.overall_score > b.overall_score)
	
	print("[ArmyTargetScorer] Completed scoring, best target has score: ", 
		  scored_targets[0].overall_score if not scored_targets.is_empty() else "N/A")
	
	return scored_targets

func _calculate_region_score(region: Region, player_id: int) -> Dictionary:
	"""Calculate comprehensive score for a single region"""
	var region_id = region.get_region_id()
	var region_name = region.get_region_name()
	
	# Calculate individual score components
	var population_score = _calculate_population_score(region)
	var resource_score = _calculate_resource_score(region)
	var level_score = _calculate_level_score(region)
	var ownership_score = _calculate_ownership_score(region, player_id)
	
	# Calculate weighted overall score
	var overall_score = (
		population_score * WEIGHTS.population +
		resource_score * WEIGHTS.resources +
		level_score * WEIGHTS.level +
		ownership_score * WEIGHTS.ownership
	)
	
	return {
		"region_id": region_id,
		"region_name": region_name,
		"population_score": population_score,
		"resource_score": resource_score,
		"level_score": level_score,
		"ownership_score": ownership_score,
		"overall_score": overall_score
	}

func _calculate_population_score(region: Region) -> float:
	"""Calculate normalized population score for the region"""
	var population = region.get_population()
	
	# Get population range from GameParameters
	var pop_range = _get_population_range()
	var min_pop = float(pop_range.min)
	var max_pop = float(pop_range.max)
	
	# Linear normalization to 0-1 range
	var normalized_pop = 0.0
	if max_pop > min_pop:
		normalized_pop = clampf(
			(population - min_pop) / (max_pop - min_pop),
			0.0, 1.0
		)
	
	return normalized_pop

func _calculate_resource_score(region: Region) -> float:
	"""Calculate resource score based on resource composition and balance"""
	var resource_composition = region.get_resources()
	if resource_composition == null:
		return 0.0
	
	# Primary resources for balanced distribution (exclude gold)
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
		var quantity = resource_composition.get_resource_amount(resource_type)
		var max_val = _get_resource_max(resource_type)
		var min_val = 0.0  # Minimum is always 0
		
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
	
	# Gold bonus (separate calculation)
	var gold_quantity = resource_composition.get_resource_amount(ResourcesEnum.Type.GOLD)
	var gold_max = _get_resource_max(ResourcesEnum.Type.GOLD)
	var gold_min = 0.0
	var gold_normalized = 0.0
	if gold_max > gold_min:
		gold_normalized = clampf((gold_quantity - gold_min) / (gold_max - gold_min), 0.0, 1.0)
	
	# Gold bonus divided by 3 (following castle placement logic)
	var gold_bonus = gold_normalized / 3.0
	
	# Combine: 80% primary resources + 20% gold bonus
	var final_resource_score = 0.8 * primary_avg + 0.2 * gold_bonus
	
	return final_resource_score

func _calculate_level_score(region: Region) -> float:
	"""Calculate normalized level score for the region"""
	var region_level = region.get_region_level()
	
	# Convert enum to integer (L1=1, L2=2, ... L5=5)
	var level_int = 1  # Default to L1
	match region_level:
		RegionLevelEnum.Level.L1: level_int = 1
		RegionLevelEnum.Level.L2: level_int = 2
		RegionLevelEnum.Level.L3: level_int = 3
		RegionLevelEnum.Level.L4: level_int = 4
		RegionLevelEnum.Level.L5: level_int = 5
	
	# Normalize to 0-1 range (L1=0.0, L5=1.0)
	var normalized_level = (level_int - 1.0) / 4.0  # (1-5) -> (0-1)
	
	return normalized_level

func _calculate_ownership_score(region: Region, player_id: int) -> float:
	"""Calculate ownership bonus/penalty based on current ownership status"""
	var region_id = region.get_region_id()
	var current_owner = region_manager.get_region_owner(region_id)
	
	if current_owner == -1:
		# Neutral region - good target for expansion
		return 0.8
	elif current_owner == player_id:
		# Already owned by this player - low priority for conquest
		return 0.1
	else:
		# Owned by enemy - high priority for conquest
		return 1.0

func score_region_base(region_id: int) -> float:
	"""Calculate base region value (population/resources/level/ownership)"""
	var region_container = map_generator.get_region_container_by_id(region_id)
	if not region_container:
		return 0.0
	
	var region = region_container as Region
	if not region:
		return 0.0
	
	# Calculate pure base score (no army-specific adjustments)
	var population_score = _calculate_population_score(region)
	var resource_score = _calculate_resource_score(region)
	var level_score = _calculate_level_score(region)
	
	# Base score without ownership considerations (for neutral scoring)
	var base_score = (
		population_score * WEIGHTS.population +
		resource_score * WEIGHTS.resources +
		level_score * WEIGHTS.level
	)
	
	# Scale to reasonable range (0-100)
	return base_score * 100.0

func score_army_target(army: Army, region_id: int) -> Dictionary:
	"""Adjust base score for a specific army (add random jitter, subtract MP cost)"""
	var base_score = score_region_base(region_id)
	if base_score <= 0:
		return {"reachable": false}
	
	# Get army current position
	var current_region = army.get_parent()
	if not current_region or not current_region.has_method("get_region_id"):
		return {"reachable": false}
	var current_region_id = current_region.get_region_id()
	
	# Calculate path and MP cost
	var pathfinder = ArmyPathfinder.new(region_manager, null)  # Temporary pathfinder
	var path_result = pathfinder.find_path_to_target(current_region_id, region_id, army.get_player_id())
	
	if not path_result.success:
		return {"reachable": false}
	
	# Generate army-specific random jitter
	var army_hash = hash(army.name + str(army.get_player_id()))
	var rng = RandomNumberGenerator.new()
	rng.seed = army_hash
	var random_modifier = rng.randf() * GameParameters.AI_RANDOM_SCORE_MODIFIER
	
	# Calculate final score: BaseScore + RandomModifier - MovementCost
	var final_score = base_score + random_modifier - path_result.cost
	
	return {
		"army": army,
		"target_id": region_id,
		"base_score": base_score,
		"random_modifier": random_modifier,
		"mp_cost": path_result.cost,
		"final_score": final_score,
		"path": path_result.path,
		"reachable": true
	}

func get_best_target(target_region_ids: Array[int], player_id: int) -> Dictionary:
	"""Get the single best target region from a list of candidates"""
	var scored_targets = score_target_regions(target_region_ids, player_id)
	
	if scored_targets.is_empty():
		return {}
	
	return scored_targets[0]  # Highest scored target
