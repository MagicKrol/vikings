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
var player_manager: PlayerManagerNode = null
var game_manager: GameManager = null

func _init(region_mgr: RegionManager, map_gen: MapGenerator, player_mgr: PlayerManagerNode = null, game_mgr: GameManager = null):
	region_manager = region_mgr
	map_generator = map_gen
	player_manager = player_mgr
	game_manager = game_mgr
	_ensure_runtime_references()
	DebugLogger.log("AIScoring", "Initialized with region and map manager references")

func set_runtime_references(player_mgr: PlayerManagerNode, game_mgr: GameManager) -> void:
	if player_mgr != null:
		player_manager = player_mgr
	if game_mgr != null:
		game_manager = game_mgr
	_ensure_runtime_references()

func _ensure_runtime_references() -> void:
	if map_generator == null:
		return
	var have_player := player_manager != null
	var have_game := game_manager != null
	if have_player and have_game:
		return
	var current: Node = map_generator
	while current != null:
		var parent := current.get_parent()
		if parent == null:
			break
		if not have_player:
			var pm_node = parent.get_node_or_null("PlayerManager")
			if pm_node != null and pm_node is PlayerManagerNode:
				player_manager = pm_node
				have_player = true
		if not have_game:
			var gm_node = parent.get_node_or_null("GameManager")
			if gm_node != null and gm_node is GameManager:
				game_manager = gm_node
				have_game = true
		if have_player and have_game:
			break
		current = parent

func score_target_regions(target_region_ids: Array[int], player_id: int) -> Array:
	"""Score an array of target regions for army movement decisions"""
	DebugLogger.log("AIScoring", "Scoring " + str(target_region_ids.size()) + " target regions for Player " + str(player_id))
	
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
	
	DebugLogger.log("AIScoring", "Completed scoring, best target has score: " + 
		  (str(scored_targets[0].overall_score) if not scored_targets.is_empty() else "N/A"))
	
	return scored_targets

func _calculate_region_score(region: Region, player_id: int) -> Dictionary:
	"""Calculate comprehensive score for a single region (normalized 0..1)"""
	var region_id = region.get_region_id()
	var region_name = region.get_region_name()

	# New components (capped):
	# - Strategic point score: 0..10 (stored on Region)
	# - Population: population/100 capped to 10
	# - Level: level_int * 2 / 2(max L5 -> 5)
	# - Resources: dynamic need-weighted 0..10
	var strategic: float = region.get_strategic_point_score()  # 0..10
	var pop_component: float = min(10.0, float(region.get_population()) / 50.0)
	var level_component: float = _level_component_out_of_10(region)
	var res_component: float = _resource_component_out_of_10(region, player_id)

	var raw_total: float = strategic + pop_component + level_component + res_component  # max ~40
	var overall_score: float = 0.0
	if raw_total > 0.0:
		overall_score = clampf(raw_total / 40.0, 0.0, 1.0)  # normalize to 0..1

	return {
		"region_id": region_id,
		"region_name": region_name,
		"strategic_score": strategic,
		"population_component": pop_component,
		"level_component": int(level_component/2),
		"resource_component": res_component,
		"overall_score": overall_score
	}

func _level_component_out_of_10(region: Region) -> float:
	var level_int = 1
	match region.get_region_level():
		RegionLevelEnum.Level.L1: level_int = 1
		RegionLevelEnum.Level.L2: level_int = 2
		RegionLevelEnum.Level.L3: level_int = 3
		RegionLevelEnum.Level.L4: level_int = 4
		RegionLevelEnum.Level.L5: level_int = 5
	return float(level_int) * 2.0

func _get_resource_weight(rt: ResourcesEnum.Type) -> float:
	"""Get weight for resource type from GameParameters"""
	match rt:
		ResourcesEnum.Type.FOOD:
			return GameParameters.AI_FOOD_RESOURCE_WEIGHT
		ResourcesEnum.Type.WOOD:
			return GameParameters.AI_WOOD_RESOURCE_WEIGHT
		ResourcesEnum.Type.STONE:
			return GameParameters.AI_STONE_RESOURCE_WEIGHT
		ResourcesEnum.Type.IRON:
			return GameParameters.AI_IRON_RESOURCE_WEIGHT
		ResourcesEnum.Type.GOLD:
			return GameParameters.AI_GOLD_RESOURCE_WEIGHT
		_:
			return 1.0

func _get_player_income_by_resource(player_id: int) -> Dictionary:
	"""Get player's per-turn resource income from owned regions"""
	_ensure_runtime_references()
	var income = {
		ResourcesEnum.Type.FOOD: 0.0,
		ResourcesEnum.Type.WOOD: 0.0,
		ResourcesEnum.Type.STONE: 0.0,
		ResourcesEnum.Type.IRON: 0.0,
		ResourcesEnum.Type.GOLD: 0.0
	}
	
	var owned_regions = region_manager.get_player_regions(player_id)
	for region_id in owned_regions:
		var region_container = map_generator.get_region_container_by_id(region_id)
		if region_container != null:
			var region = region_container as Region
			if region != null:
				for rt in income.keys():
					income[rt] += float(region.get_resource_amount(rt))
	
	return income

func _get_player_stockpile_by_resource(player_id: int) -> Dictionary:
	"""Get player's current resource stockpile"""
	_ensure_runtime_references()
	var stockpile = {
		ResourcesEnum.Type.FOOD: 0.0,
		ResourcesEnum.Type.WOOD: 0.0,
		ResourcesEnum.Type.STONE: 0.0,
		ResourcesEnum.Type.IRON: 0.0,
		ResourcesEnum.Type.GOLD: 0.0
	}
	
	if player_manager != null:
		var player = player_manager.get_player(player_id)
		if player != null:
			for rt in stockpile.keys():
				stockpile[rt] = float(player.get_resource_amount(rt))
	
	return stockpile

func _get_player_net_food_change(player_id: int) -> float:
	"""Get player's net food change (income - upkeep)"""
	_ensure_runtime_references()
	var income = _get_player_income_by_resource(player_id)
	var food_income = income.get(ResourcesEnum.Type.FOOD, 0.0)
	
	# Calculate total food upkeep (armies + garrisons)
	var food_upkeep = 0.0
	if player_manager != null:
		food_upkeep = player_manager.calculate_total_army_food_cost(player_id)
	
	return food_income - food_upkeep

func _resource_component_out_of_10(region: Region, player_id: int) -> float:
	"""Calculate resource component using simple weighted sum with modifiers"""
	var res = region.get_resources()
	if res == null:
		return 0.0
	
	# Get player data for modifiers
	var income = _get_player_income_by_resource(player_id)
	var stockpile = _get_player_stockpile_by_resource(player_id)
	var net_food_change = _get_player_net_food_change(player_id)
	
	var types = [ResourcesEnum.Type.FOOD, ResourcesEnum.Type.WOOD, ResourcesEnum.Type.STONE, ResourcesEnum.Type.IRON, ResourcesEnum.Type.GOLD]
	var total = 0.0
	
	for rt in types:
		var qty = float(res.get_resource_amount(rt))
		var weight = _get_resource_weight(rt)
		var modifier = 1.0
		
		# Low income modifier
		if rt == ResourcesEnum.Type.FOOD:
			if net_food_change < 5.0:
				modifier *= 3.0
		else:
			if income.get(rt, 0.0) < 5.0:
				modifier *= 3.0
		
		# High stockpile modifier (except gold)
		if rt != ResourcesEnum.Type.GOLD and stockpile.get(rt, 0.0) > 100.0:
			modifier *= 0.5
		
		var contrib = qty * weight * modifier
		total += contrib
	
	return total

func _calculate_ownership_score(region: Region, player_id: int) -> float:
	# Keep ownership used only for debug visualizer frontier mode legacy
	return 0.0

func _calculate_population_score(region: Region) -> float:
	return min(1.0, float(region.get_population()) / 1000.0)

func score_region_base(region_id: int) -> float:
	"""Calculate base region value (population/resources/level/ownership)"""
	_ensure_runtime_references()
	var region_container = map_generator.get_region_container_by_id(region_id)
	if not region_container:
		return 0.0

	var region = region_container as Region
	if not region:
		return 0.0

	# Use new normalized model (0..1) scaled to 0..100
	var score_data = _calculate_region_score(region, 1)
	return float(score_data.overall_score) * 100.0

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
	var region_container = map_generator.get_region_container_by_id(region_id)
	if region_container == null:
		return {"reachable": false}
	var region = region_container as Region
	if region == null:
		return {"reachable": false}
	
	# Generate army-specific random jitter
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var random_modifier = rng.randf() * GameParameters.AI_RANDOM_SCORE_MODIFIER

	var enemy_adjustment := _calculate_enemy_army_adjustment(army, region_id)
	
	# Calculate final score: BaseScore + RandomModifier - MovementCost
	var ownership_bonus := 0.0
	if region_manager != null:
		var owner_id := region_manager.get_region_owner(region_id)
		if owner_id > 0 and owner_id != army.get_player_id():
			ownership_bonus = float(GameParameters.AI_ENEMY_REGION_SCORE_BONUS)

	var pursuit_bonus := _get_pursuit_bonus(army, region_id)
	var castle_bonus := _get_castle_bonus(region, army.get_player_id())
	var final_score = base_score + ownership_bonus + random_modifier + pursuit_bonus + castle_bonus - path_result.cost + enemy_adjustment.get("delta", 0.0)
	if enemy_adjustment.get("nullify", false):
		final_score = 0.0

	return {
		"army": army,
		"target_id": region_id,
		"base_score": base_score,
		"ownership_bonus": ownership_bonus,
		"random_modifier": random_modifier,
		"mp_cost": path_result.cost,
		"final_score": final_score,
		"enemy_adjustment": enemy_adjustment,
		"path": path_result.path,
		"reachable": true
	}

func is_target_overmatched_by_known_enemy(army: Army, region_id: int) -> bool:
	_ensure_runtime_references()
	if army == null or not is_instance_valid(army):
		return false
	if game_manager == null or player_manager == null:
		return false
	var known := _get_known_enemy_power(army.get_player_id(), region_id)
	if not known.get("has_data", false):
		return false
	var defender_power: float = float(known.get("power", 0))
	if defender_power <= 0.0:
		return false
	var attacker_power: float = float(army.get_army_power())
	if attacker_power <= 0.0:
		return false
	var region_container = map_generator.get_region_container_by_id(region_id)
	if region_container == null:
		return false
	var region := region_container as Region
	if region == null:
		return false
	var castle_type: CastleTypeEnum.Type = region.get_castle_type()
	var defense_bonus: int = GameParameters.get_castle_defense_bonus(castle_type)
	# Castle gate: require attacker to exceed defended power before siege prep
	if castle_type != CastleTypeEnum.Type.NONE:
		if game_manager.should_ai_withdraw_by_power(attacker_power, defender_power, 1.0, defense_bonus, 1.0):
			return true
	# Standard withdrawal threshold without siege bonuses
	return game_manager.should_ai_withdraw_by_power(attacker_power, defender_power, 1.0, defense_bonus, GameParameters.AI_WITHDRAW_POWER_THRESHOLD)

func _get_pursuit_bonus(army: Army, region_id: int) -> float:
	_ensure_runtime_references()
	if army == null or not is_instance_valid(army):
		return 0.0
	if game_manager == null or player_manager == null:
		return 0.0
	var known := _get_known_enemy_power(army.get_player_id(), region_id)
	if not known.get("has_data", false):
		return 0.0
	var defender_power: float = float(known.get("power", 0))
	if defender_power <= 0.0:
		return 0.0
	var attacker_power: float = float(army.get_army_power())
	if attacker_power <= 0.0:
		return 0.0
	var region_container = map_generator.get_region_container_by_id(region_id)
	if region_container == null:
		return 0.0
	var region := region_container as Region
	if region == null:
		return 0.0
	var castle_type: CastleTypeEnum.Type = region.get_castle_type()
	var defense_bonus: int = GameParameters.get_castle_defense_bonus(castle_type)
	var assault_multiplier: float = 1.0
	var meets_ratio := not game_manager.should_ai_withdraw_by_power(attacker_power, defender_power, assault_multiplier, defense_bonus, GameParameters.AI_PURSUIT_POWER_RATIO)
	if meets_ratio:
		return float(GameParameters.AI_PURSUIT_SCORE_BONUS)
	return 0.0

func _get_known_enemy_power(observer_id: int, region_id: int) -> Dictionary:
	var region_container = map_generator.get_region_container_by_id(region_id)
	if region_container == null:
		return {"power": 0, "has_data": false}
	var total_power: int = 0
	var has_data: bool = false
	for child in region_container.get_children():
		if not (child is Army):
			continue
		var enemy_army: Army = child
		if enemy_army.get_player_id() == observer_id:
			continue
		var key := Player.get_enemy_tracker_key(enemy_army)
		if key == "":
			continue
		var tracked_power: int = player_manager.get_tracked_enemy_power(observer_id, key)
		if tracked_power < 0:
			continue
		total_power += tracked_power
		if tracked_power > 0:
			has_data = true
	var tracked_garrison: int = player_manager.get_tracked_enemy_garrison_power(observer_id, region_id)
	if tracked_garrison >= 0:
		total_power += tracked_garrison
		if tracked_garrison > 0:
			has_data = true
	return {"power": total_power, "has_data": has_data}

func _get_castle_bonus(region: Region, player_id: int) -> float:
	if region == null:
		return 0.0
	var owner_id := region.get_region_owner()
	if owner_id == player_id:
		return 0.0
	var castle_type: CastleTypeEnum.Type = region.get_castle_type()
	if castle_type == CastleTypeEnum.Type.NONE:
		return 0.0
	var level_bonus: int = region.get_castle_type()
	return 4.0 + float(level_bonus)

func _calculate_enemy_army_adjustment(army: Army, region_id: int) -> Dictionary:
	_ensure_runtime_references()
	if army == null or not is_instance_valid(army):
		return {"delta": 0.0, "nullify": false}
	if game_manager == null or player_manager == null:
		return {"delta": 0.0, "nullify": false}
	var observer_id := army.get_player_id()
	if not game_manager.is_player_computer(observer_id):
		return {"delta": 0.0, "nullify": false}
	var our_power := army.get_army_power()
	if our_power <= 0:
		return {"delta": 0.0, "nullify": false}
	var region_container = map_generator.get_region_container_by_id(region_id)
	if region_container == null:
		return {"delta": 0.0, "nullify": false}
	var total_enemy_power := 0
	var max_ratio: float = 0.0
	var min_ratio: float = INF
	var has_data := false
	var saw_enemy_army := false
	var missing_army_info := false
	for child in region_container.get_children():
		if not (child is Army):
			continue
		var enemy_army := child as Army
		if enemy_army == null:
			continue
		if enemy_army.get_player_id() == observer_id:
			continue
		saw_enemy_army = true
		var key := Player.get_enemy_tracker_key(enemy_army)
		if key == "":
			continue
		var tracked_power := player_manager.get_tracked_enemy_power(observer_id, key)
		if tracked_power < 0:
			missing_army_info = true
			break
		has_data = true
		var ratio := float(tracked_power) / float(max(1, our_power))
		if ratio > max_ratio:
			max_ratio = ratio
		if ratio < min_ratio:
			min_ratio = ratio
		total_enemy_power += tracked_power
	if missing_army_info:
		return {"delta": 0.0, "nullify": false}
	var tracked_garrison := player_manager.get_tracked_enemy_garrison_power(observer_id, region_id)
	if tracked_garrison >= 0:
		has_data = true
		var g_ratio := float(tracked_garrison) / float(max(1, our_power))
		if g_ratio > max_ratio:
			max_ratio = g_ratio
		if g_ratio < min_ratio:
			min_ratio = g_ratio
		total_enemy_power += tracked_garrison
	if not has_data:
		return {"delta": 0.0, "nullify": false}
	if saw_enemy_army and total_enemy_power <= 0:
		return {"delta": 0.0, "nullify": false}
	if not saw_enemy_army and tracked_garrison < 0:
		return {"delta": 0.0, "nullify": false}
	if total_enemy_power <= 0:
		return {"delta": 0.0, "nullify": false}
	var combined_ratio := float(total_enemy_power) / float(max(1, our_power))
	if combined_ratio >= 1.25:
		return {"delta": 0.0, "nullify": true}
	if combined_ratio > 1.0:
		var percent_over := combined_ratio - 1.0
		var steps_over := int(ceil(percent_over / 0.05))
		return {"delta": float(-steps_over), "nullify": false}
	var percent_under := 1.0 - combined_ratio
	if percent_under <= 0.0:
		return {"delta": 0.0, "nullify": false}
	var steps_under := int(floor(percent_under / 0.05))
	steps_under = min(10, max(0, steps_under))
	return {"delta": float(steps_under), "nullify": false}

func get_base_region_score(region: Region, player_id: int) -> Dictionary:
	"""Public API: Get base region score (0..100) with component breakdown"""
	if region == null:
		return {}
	
	# Use existing internal calculation
	var score_data = _calculate_region_score(region, player_id)
	
	# Repackage for public API with 0..100 scale
	return {
		"region_id": region.get_region_id(),
		"region_name": region.get_region_name(),
		"base_score_0_100": score_data.overall_score * 100.0,  # 0..100 scale
		"overall_score_0_1": score_data.overall_score,  # Keep original 0..1
		"strategic_component_0_10": score_data.strategic_score,
		"population_component_0_10": score_data.population_component,
		"level_component_0_10": score_data.level_component,
		"resource_component_0_10": score_data.resource_component
	}

func get_final_army_score(army: Army, region_id: int) -> Dictionary:
	"""Public API: Get final army score with all components (base, random, mp, final)"""
	if army == null or not is_instance_valid(army):
		return {"reachable": false, "reason": "Invalid army"}
	
	# Get region for base scoring
	var region_container = map_generator.get_region_container_by_id(region_id)
	if not region_container:
		return {"reachable": false, "reason": "Invalid region"}
	
	var region = region_container as Region
	if not region:
		return {"reachable": false, "reason": "Invalid region"}
	
	# Use existing score_army_target implementation
	var result = score_army_target(army, region_id)
	
	# If not reachable, return as-is
	if not result.get("reachable", false):
		return result
	
	# Add the base region data for completeness
	var base_data = get_base_region_score(region, army.get_player_id())
	result["base_score_0_100"] = base_data.get("base_score_0_100", 0.0)
	result["strategic_component_0_10"] = base_data.get("strategic_component_0_10", 0.0)
	result["population_component_0_10"] = base_data.get("population_component_0_10", 0.0)
	result["level_component_0_10"] = base_data.get("level_component_0_10", 0.0)
	result["resource_component_0_10"] = base_data.get("resource_component_0_10", 0.0)
	
	return result

func get_base_region_score_raw(region: Region, player_id: int) -> Dictionary:
	"""Public API: Get raw base score sum and components (no normalization)"""
	if region == null:
		return {}
	
	# Use existing internal calculation
	var score_data = _calculate_region_score(region, player_id)
	
	# Compute raw total without normalization
	var base_raw_total = score_data.strategic_score + score_data.population_component + score_data.level_component + score_data.resource_component
	
	return {
		"region_id": region.get_region_id(),
		"region_name": region.get_region_name(),
		"base_raw_total": base_raw_total,
		"strategic_0_10": score_data.strategic_score,
		"population_0_10": score_data.population_component,
		"level_0_10": score_data.level_component,
		"resource_0_10": score_data.resource_component
	}

func get_resource_component_breakdown_out_of_10(region: Region, player_id: int) -> Dictionary:
	"""Public API: Get per-resource contributions using weighted sum with modifiers"""
	if region == null:
		return {}
	
	var res = region.get_resources()
	if res == null:
		return {"food": 0.0, "wood": 0.0, "stone": 0.0, "iron": 0.0, "gold": 0.0, "total": 0.0}
	
	# Get player data for modifiers
	var income = _get_player_income_by_resource(player_id)
	var stockpile = _get_player_stockpile_by_resource(player_id)
	var net_food_change = _get_player_net_food_change(player_id)
	
	var types = [ResourcesEnum.Type.FOOD, ResourcesEnum.Type.WOOD, ResourcesEnum.Type.STONE, ResourcesEnum.Type.IRON, ResourcesEnum.Type.GOLD]
	var contributions = {}
	var total = 0.0
	
	for rt in types:
		var qty = float(res.get_resource_amount(rt))
		var weight = _get_resource_weight(rt)
		var modifier = 1.0
		
		# Low income modifier
		if rt == ResourcesEnum.Type.FOOD:
			if net_food_change < 5.0:
				modifier *= 3.0
		else:
			if income.get(rt, 0.0) < 5.0:
				modifier *= 3.0
		
		# High stockpile modifier (except gold)
		if rt != ResourcesEnum.Type.GOLD and stockpile.get(rt, 0.0) > 100.0:
			modifier *= 0.5
		
		var contrib = qty * weight * modifier
		contributions[rt] = contrib
		total += contrib
	
	return {
		"food": contributions.get(ResourcesEnum.Type.FOOD, 0.0),
		"wood": contributions.get(ResourcesEnum.Type.WOOD, 0.0),
		"stone": contributions.get(ResourcesEnum.Type.STONE, 0.0),
		"iron": contributions.get(ResourcesEnum.Type.IRON, 0.0),
		"gold": contributions.get(ResourcesEnum.Type.GOLD, 0.0),
		"total": total
	}

func get_final_army_score_raw(army: Army, region_id: int) -> Dictionary:
	"""Public API: Get final army score with raw base and resource breakdown"""
	if army == null or not is_instance_valid(army):
		return {"reachable": false, "reason": "Invalid army"}
	
	# Get region for base scoring
	var region_container = map_generator.get_region_container_by_id(region_id)
	if not region_container:
		return {"reachable": false, "reason": "Invalid region"}
	
	var region = region_container as Region
	if not region:
		return {"reachable": false, "reason": "Invalid region"}
	
	# Get army current position
	var current_region = army.get_parent()
	if not current_region or not current_region.has_method("get_region_id"):
		return {"reachable": false, "reason": "Invalid army position"}
	var current_region_id = current_region.get_region_id()
	
	# Calculate path and MP cost
	var pathfinder = ArmyPathfinder.new(region_manager, null)
	var path_result = pathfinder.find_path_to_target(current_region_id, region_id, army.get_player_id())
	
	if not path_result.success:
		return {"reachable": false, "reason": "Unreachable"}
	
	# Generate army-specific random jitter
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var random_modifier = rng.randf() * GameParameters.AI_RANDOM_SCORE_MODIFIER
	
	# Get raw base score and components
	var base_data = get_base_region_score_raw(region, army.get_player_id())
	var base_raw_total = base_data.get("base_raw_total", 0.0)
	
	# Get resource breakdown
	var resources_breakdown = get_resource_component_breakdown_out_of_10(region, army.get_player_id())
	
	# Calculate final raw score: base_raw + random - mp
	var final_raw = base_raw_total + random_modifier - path_result.cost
	
	return {
		"army": army,
		"target_id": region_id,
		"base_raw_total": base_raw_total,
		"random_modifier": random_modifier,
		"mp_cost": path_result.cost,
		"final_raw": final_raw,
		"path": path_result.path,
		"reachable": true,
		"strategic_0_10": base_data.get("strategic_0_10", 0.0),
		"population_0_10": base_data.get("population_0_10", 0.0),
		"level_0_10": base_data.get("level_0_10", 0.0),
		"resource_0_10": base_data.get("resource_0_10", 0.0),
		"resources_breakdown": resources_breakdown
	}

func get_best_target(target_region_ids: Array[int], player_id: int) -> Dictionary:
	"""Get the single best target region from a list of candidates"""
	var scored_targets = score_target_regions(target_region_ids, player_id)
	
	if scored_targets.is_empty():
		return {}
	
	return scored_targets[0]  # Highest scored target
