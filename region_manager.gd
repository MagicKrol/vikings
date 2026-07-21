extends RefCounted
class_name RegionManager

# ============================================================================
# REGION MANAGER
# ============================================================================
# 
# Purpose: Territory ownership management and region-based operations
# 
# Core Responsibilities:
# - Region ownership tracking and territory claims
# - Castle starting position management
# - Region resource generation and management
# - Region adjacency and graph operations
# - Region level upgrades and population management
# 
# Required Functions:
# - set_region_ownership(): Manage territory ownership changes
# - set_castle_starting_position(): Handle castle placement and claims
# - upgrade_castle_regions(): Level up castle and neighbor regions
# - generate_region_resources(): Create region-specific resources
# - get_neighbor_regions(): Region adjacency lookups
# 
# Integration Points:
# - MapGenerator: Region data and adjacency information
# - GameParameters: Resource generation and population rules
# - Region: Individual region data management
# - Player systems: Ownership and resource calculations
# ============================================================================

# Region ownership: region_id -> player_id
var region_ownership: Dictionary = {}

const CASTLE_PLACEMENT_CASTLE_POPULATION_BONUS: int = 200
const CASTLE_PLACEMENT_NEIGHBOR_POPULATION_BONUS: int = 100

# Castle starting positions: player_id -> region_id
var castle_starting_positions: Dictionary = {}

# Reference to the region graph for neighbor lookups
var region_graph: Dictionary = {}

# Reference to the map generator for region data
var map_generator: MapGenerator
var visual_manager: VisualManager
var army_manager: ArmyManager

# Region name management
var available_names: Array[String] = []
var used_names: Dictionary = {}

func _init(map_gen: MapGenerator):
	map_generator = map_gen
	_load_region_names()
	_build_region_graph()
	_generate_all_region_resources()

func set_visual_manager(vm: VisualManager) -> void:
	visual_manager = vm

func set_army_manager(am: ArmyManager) -> void:
	army_manager = am

func _load_region_names() -> void:
	"""Load region names from regions.json file"""
	var file = FileAccess.open("res://regions.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.data
			if data is Array:
				for name in data:
					if name is String:
						available_names.append(name)
	
		else:
			DebugLogger.log("RegionManagement", "Error parsing regions.json")

func assign_region_name(region: Region) -> String:
	"""Assign a random name to a region"""
	if available_names.is_empty():
		return "Unknown_" + str(region.get_region_id())
	
	# Get available names that haven't been used
	var unused_names = []
	for name in available_names:
		if not used_names.has(name):
			unused_names.append(name)
	
	if unused_names.is_empty():
		# If all names are used, use region ID
		return "Region_" + str(region.get_region_id())
	else:
		# Pick a random unused name
		var random_index = randi() % unused_names.size()
		var chosen_name = unused_names[random_index]
		used_names[chosen_name] = true
		return chosen_name

func _build_region_graph() -> void:
	"""Build the region adjacency graph using the existing RegionGraph class"""
	if map_generator == null:
		return
	
	var Graph := load("res://region_graph.gd")
	if Graph != null:
		region_graph = Graph.build_non_ocean_adjacency(map_generator.regions, map_generator.edges)

func rebuild_region_graph() -> void:
	_build_region_graph()

func get_neighbor_regions(region_id: int) -> Array[int]:
	"""Get all neighboring regions for a given region ID"""
	if region_graph.has(region_id):
		var neighbors = region_graph[region_id]
		# Convert to Array[int] if needed
		var result: Array[int] = []
		for neighbor in neighbors:
			result.append(int(neighbor))
		return result
	return []

func set_region_ownership(region_id: int, player_id: int) -> void:
	"""Set ownership of a region to a specific player"""
	var previous_owner: int = get_region_owner(region_id)
	# Neutral/clear ownership when player_id <= 0
	if player_id <= 0:
		if region_ownership.has(region_id):
			region_ownership.erase(region_id)
		# Update Region node
		var region_container = map_generator.get_region_container_by_id(region_id)
		if region_container != null:
			var region = region_container as Region
			if region != null:
				region.set_region_owner(0)
				region.just_conquered_this_turn = false
		# Remove overlay if present
		if map_generator and map_generator.has_method("remove_ownership_overlay"):
			map_generator.remove_ownership_overlay(region_id)
		if visual_manager:
			visual_manager.clear_region_highlight_state(region_id)
	else:
		# Assign ownership to player_id
		region_ownership[region_id] = player_id
		# Update the region's ownership tracking
		var region_container2 = map_generator.get_region_container_by_id(region_id)
		if region_container2 != null:
			var region2 = region_container2 as Region
			if region2 != null:
				region2.set_region_owner(player_id)
				region2.just_conquered_this_turn = previous_owner != player_id
				# Create or update colored overlay for owned region
				if map_generator:
					if previous_owner == -1:
						map_generator.create_ownership_overlay(region_id, player_id)
					else:
						map_generator.update_ownership_overlay(region_id, player_id)
				if visual_manager:
					visual_manager.clear_region_highlight_state(region_id)
	
	# Trigger border recalculation for colored borders
	if map_generator and map_generator.has_method("regenerate_borders_for_region"):
		map_generator.regenerate_borders_for_region(region_id)
	elif map_generator and map_generator.has_method("regenerate_borders"):
		# Fallback to full regeneration
		map_generator.regenerate_borders()
	var region_after_change: Region = map_generator.get_region_container_by_id(region_id) as Region
	army_manager.on_region_owner_changed(region_after_change)

func set_initial_region_ownership(region_id: int, player_id: int, clear_existing_garrison: bool = false) -> void:
	"""Set initial ownership of a region for castle placement with full recruitment"""
	region_ownership[region_id] = player_id
	
	# Update the region's ownership tracking with full recruitment counter
	var region_container = map_generator.get_region_container_by_id(region_id)
	if region_container != null:
		var region = region_container as Region
		if region != null:
			region.set_initial_region_owner(player_id)
			if clear_existing_garrison:
				region.clear_garrison()
	
	# Create colored overlay for owned region
	if map_generator and map_generator.has_method("create_ownership_overlay"):
		map_generator.create_ownership_overlay(region_id, player_id)
	if visual_manager:
		visual_manager.clear_region_highlight_state(region_id)
	
	# Trigger border recalculation for colored borders
	if map_generator and map_generator.has_method("regenerate_borders_for_region"):
		map_generator.regenerate_borders_for_region(region_id)
	elif map_generator and map_generator.has_method("regenerate_borders"):
		# Fallback to full regeneration
		map_generator.regenerate_borders()

func get_region_owner(region_id: int) -> int:
	"""Get the player ID that owns a region, or -1 if unowned"""
	return region_ownership.get(region_id, -1)

func set_castle_starting_position(region_id: int, player_id: int) -> bool:
	"""Set a castle starting position for a player and claim the region. Returns true if successful."""
	# Check if region is already owned by another player
	var current_owner = get_region_owner(region_id)
	if current_owner != -1 and current_owner != player_id:
		DebugLogger.log("RegionManagement", "Cannot place castle - region " + str(region_id) + " is already owned by Player " + str(current_owner))
		return false
	
	# Set the castle starting position
	castle_starting_positions[player_id] = region_id
	
	# Claim the starting region with full recruitment counter
	set_initial_region_ownership(region_id, player_id, true)
	
	# Claim neighboring regions (expansion) with full recruitment counter
	var neighbors = get_neighbor_regions(region_id)
	for neighbor_id in neighbors:
		if get_region_owner(neighbor_id) == -1:  # Only claim unowned regions
			set_initial_region_ownership(neighbor_id, player_id, true)
	
	return true

func get_castle_starting_position(player_id: int) -> int:
	"""Get the region ID where a player's castle is located, or -1 if not set"""
	return castle_starting_positions.get(player_id, -1)

func is_region_owned(region_id: int) -> bool:
	"""Check if a region is owned by any player"""
	return get_region_owner(region_id) != -1

func get_player_regions(player_id: int) -> Array[int]:
	"""Get all regions owned by a specific player"""
	var player_regions: Array[int] = []
	for region_id in region_ownership.keys():
		if region_ownership[region_id] == player_id:
			player_regions.append(region_id)
	return player_regions

func heal_wounded_for_player(player_id: int) -> void:
	"""Heal wounded garrisons and recruits in all regions owned by the player."""
	var owned = get_player_regions(player_id)
	for region_id in owned:
		var region_container = map_generator.get_region_container_by_id(region_id)
		var region = region_container as Region
		region.heal_all_wounded()

func decrement_promotion_cooldowns_for_player(player_id: int) -> void:
	"""Reduce promotion cooldown for all regions owned by player."""
	var owned = get_player_regions(player_id)
	for region_id in owned:
		var region_container = map_generator.get_region_container_by_id(region_id)
		if region_container != null:
			var region = region_container as Region
			if region != null:
				region.decrement_promotion_cooldown()

func increment_all_ownership_counters() -> void:
	"""Increment ownership counters for all owned regions (called each turn)"""
	for region_id in region_ownership:
		var region_container = map_generator.get_region_container_by_id(region_id)
		if region_container != null:
			var region = region_container as Region
			if region != null:
				region.increment_ownership_counter()

func update_region_visuals() -> void:
	"""Update the visual appearance of regions based on ownership"""
	# This function is intentionally empty - no polygon tinting
	pass

func _get_player_color(player_id: int) -> Color:
	"""Get the color for a specific player"""
	return GameParameters.get_player_color(player_id)

func generate_region_resources(region: Region) -> void:
	"""Generate random resources for a region based on its biome type and level bonuses"""
	if region == null or region.resources == null:
		return
	
	var biome_type = region.get_region_type()

	var base_comp = ResourceComposition.new()
	for resource_type in ResourcesEnum.get_all_types():
		var base_amount = GameParameters.generate_resource_amount(biome_type, resource_type)
		base_comp.set_resource_amount(resource_type, int(base_amount))
	region.set_base_resources(base_comp)

func upgrade_castle_regions(castle_region: Region) -> void:
	"""Upgrade castle region to L3 and neighboring regions to L2 with population bonuses."""
	# Upgrade castle region to L3
	castle_region.set_population(castle_region.get_population() + CASTLE_PLACEMENT_CASTLE_POPULATION_BONUS)
	castle_region.available_recruits = castle_region.get_max_recruits()
	castle_region.set_region_level_with_recruit_bonus(RegionLevelEnum.Level.L3)
	
	# Get neighboring regions and upgrade them to L2

	var neighbor_ids = get_neighbor_regions(castle_region.get_region_id())
	var regions_node = map_generator.get_node("Regions")
	for neighbor_id in neighbor_ids:
		for child in regions_node.get_children():
			if child is Region and child.get_region_id() == neighbor_id:
				var neighbor_region: Region = child as Region
				neighbor_region.set_population(neighbor_region.get_population() + CASTLE_PLACEMENT_NEIGHBOR_POPULATION_BONUS)
				neighbor_region.available_recruits = neighbor_region.get_max_recruits()
				neighbor_region.set_region_level_with_recruit_bonus(RegionLevelEnum.Level.L2)
				break

func _generate_all_region_resources() -> void:
	"""Generate resources for all regions when the RegionManager is initialized"""
	if map_generator == null:
		return
	
	# Get all region containers from the map generator
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		DebugLogger.log("RegionManagement", "Warning: No Regions node found in map generator")
		return
	
	# Generate resources for each region
	var regions_generated = 0
	for child in regions_node.get_children():
		if not (child is Region):
			continue
		var region := child as Region
		if region.is_ocean:
			continue
		if region.get_region_type() == RegionTypeEnum.Type.MOUNTAINS:
			continue
		generate_region_resources(region)
		regions_generated += 1

func replenish_all_recruits() -> void:
	"""Replenish recruits for all regions (called each turn)"""
	if map_generator == null:
		return
	
	# Get all region containers from the map generator
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		DebugLogger.log("RegionManagement", "Warning: No Regions node found in map generator")
		return
	
	# Replenish recruits for each region
	var regions_replenished = 0
	for child in regions_node.get_children():
		if child is Region:
			child.replenish_recruits()
			regions_replenished += 1
	
	DebugLogger.log("RegionManagement", "Replenished recruits for " + str(regions_replenished) + " regions")

func grow_all_populations() -> void:
	"""Grow population for all regions (called each turn)"""
	if map_generator == null:
		return
	
	# Get all region containers from the map generator
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		DebugLogger.log("RegionManagement", "Warning: No Regions node found in map generator")
		return
	
	# Grow population for each region
	var regions_grown = 0
	for child in regions_node.get_children():
		if child is Region:
			child.grow_population()
			regions_grown += 1
	
	DebugLogger.log("RegionManagement", "Processed population growth for " + str(regions_grown) + " regions")

func process_all_castle_construction() -> void:
	"""Process castle construction for all regions (called each turn)"""
	if map_generator == null:
		return
	
	# Get all region containers from the map generator
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		DebugLogger.log("RegionManagement", "Warning: No Regions node found in map generator")
		return
	
	# Process castle construction for each region
	var regions_processed = 0
	var completed_constructions = 0
	for child in regions_node.get_children():
		if child is Region:
			if child.process_castle_construction():
				completed_constructions += 1
			regions_processed += 1
	
	if completed_constructions > 0:
		DebugLogger.log("RegionManagement", "Completed " + str(completed_constructions) + " castle constructions this turn")
	DebugLogger.log("RegionManagement", "Processed castle construction for " + str(regions_processed) + " regions")

func process_all_castle_repairs() -> void:
	if map_generator == null:
		return
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		return
	var completed = 0
	for child in regions_node.get_children():
		if child is Region:
			if child.process_castle_repair():
				completed += 1
	if completed > 0:
		DebugLogger.log("RegionManagement", "Completed " + str(completed) + " castle repairs this turn")

func process_castle_progress_for_player(player_id: int, player: Player) -> void:
	if map_generator == null:
		return
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		return
	var completed_builds := 0
	var completed_repairs := 0
	var completed_region_downgrades := 0
	var completed_castle_downgrades := 0
	for child in regions_node.get_children():
		if child is Region:
			var region := child as Region
			if region.current_owner_id != player_id:
				continue
			if region.process_castle_construction():
				completed_builds += 1
			if region.process_castle_repair():
				completed_repairs += 1
			if region.process_region_downgrade():
				player.add_resources(ResourcesEnum.Type.FOOD, 5)
				completed_region_downgrades += 1
			var dismantled_castle_type: CastleTypeEnum.Type = region.process_castle_downgrade()
			if dismantled_castle_type != CastleTypeEnum.Type.NONE:
				var construction_cost: Dictionary = GameParameters.get_castle_building_cost(dismantled_castle_type)
				for resource_type in [ResourcesEnum.Type.WOOD, ResourcesEnum.Type.STONE, ResourcesEnum.Type.IRON]:
					var returned_amount: int = int(float(construction_cost.get(resource_type, 0)) / 4.0)
					player.add_resources(resource_type, returned_amount)
				completed_castle_downgrades += 1
	if completed_builds > 0:
		DebugLogger.log("RegionManagement", "Completed " + str(completed_builds) + " castle constructions for player " + str(player_id))
	if completed_repairs > 0:
		DebugLogger.log("RegionManagement", "Completed " + str(completed_repairs) + " castle repairs for player " + str(player_id))
	if completed_region_downgrades > 0 or completed_castle_downgrades > 0:
		DebugLogger.log("RegionManagement", "Completed " + str(completed_region_downgrades) + " region downgrades and " + str(completed_castle_downgrades) + " castle downgrades for player " + str(player_id))

func apply_castle_maintenance_penalty(player_id: int, resource_type: ResourcesEnum.Type, missing_amount: int) -> void:
	if missing_amount <= 0:
		return
	var castle_regions: Array[Region] = []
	var total_weight: int = 0
	for region_id: int in get_player_regions(player_id):
		var region: Region = map_generator.get_region_container_by_id(region_id) as Region
		var castle_type: CastleTypeEnum.Type = region.get_castle_type()
		if castle_type == CastleTypeEnum.Type.NONE:
			continue
		var upkeep: Dictionary = GameParameters.get_castle_upkeep_cost(castle_type)
		var weight: int = int(upkeep.get(resource_type, 0))
		if weight <= 0:
			continue
		castle_regions.append(region)
		total_weight += weight
	if total_weight <= 0:
		return
	var penalty_pool: float = float(missing_amount) * GameParameters.CASTLE_DEFENSE_PENALTY_PER_MISSING_RESOURCE
	for region: Region in castle_regions:
		var castle_upkeep: Dictionary = GameParameters.get_castle_upkeep_cost(region.get_castle_type())
		var castle_weight: int = int(castle_upkeep.get(resource_type, 0))
		var penalty_share: float = penalty_pool * float(castle_weight) / float(total_weight)
		region.add_maintenance_defense_penalty(penalty_share)
	DebugLogger.log("RegionManagement", "Applied " + str(penalty_pool) + " castle maintenance defense penalty from missing " + ResourcesEnum.type_to_string(resource_type) + " for player " + str(player_id))

func try_repair_castle(region: Region, player: Player) -> bool:
	if region == null or player == null:
		return false
	if not region.has_castle_damage():
		return false
	if region.is_castle_under_repair():
		return false
	var cost = region.get_castle_repair_cost()
	if cost.is_empty():
		return false
	if not player.can_afford_cost(cost):
		return false
	if not player.pay_cost(cost):
		return false
	region.start_castle_repair()
	return true

func get_regions_with_castles(player_id: int) -> Array[Region]:
	var regions: Array[Region] = []
	var region_ids = get_player_regions(player_id)
	for rid in region_ids:
		var r = map_generator.get_region_container_by_id(rid) as Region
		if r != null and r.has_castle():
			regions.append(r)
	return regions

func reset_all_ore_search_turn_usage() -> void:
	"""Reset per-turn usage flags for all regions (ore search, raise army, promotion)"""
	if map_generator == null:
		return
	
	# Get all region containers from the map generator
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		DebugLogger.log("RegionManagement", "Warning: No Regions node found in map generator")
		return
	
	# Reset ore search usage for each region
	var regions_reset = 0
	for child in regions_node.get_children():
		if child is Region:
			child.reset_turn_actions_usage()
			regions_reset += 1
	
	DebugLogger.log("RegionManagement", "Reset turn usage flags for " + str(regions_reset) + " regions")

func calculate_terrain_cost(region_id: int, player_id: int) -> int:
	"""
	Calculate the movement cost for a region based on its terrain type and ownership.
	This is the single source of truth for terrain cost calculations.
	Returns -1 for impassable terrain.
	"""
	var region_container = map_generator.get_region_container_by_id(region_id)
	if region_container == null:
		return -1  # Region not found
	
	var region = region_container as Region
	if region == null:
		return -1  # Invalid region
	
	# Check if region is passable
	if not region.is_passable():
		return -1
	
	var base_cost = region.get_movement_cost()
	
	# If base cost is -1 (impassable), don't modify it
	if base_cost == -1:
		return -1
	
	# Apply ownership bonus: reduce cost by 1 for owned territories (minimum cost of 1)
	if player_id != -1:
		var region_owner = get_region_owner(region_id)
		if region_owner == player_id:
			# Reduce movement cost by 1 for owned territory, minimum cost of 1
			return max(1, base_cost - 1)
	
	return base_cost

func get_frontier_regions(player_id: int) -> Array[int]:
	"""Get all frontier regions (non-owned neighbors of owned regions)"""
	var owned_regions = get_player_regions(player_id)
	var frontier: Array[int] = []
	var seen_regions: Dictionary = {}
	
	# Find all neighbors of owned regions that are not owned by this player
	for owned_id in owned_regions:
		var neighbors = get_neighbor_regions(owned_id)
		for neighbor_id in neighbors:
			# Skip if already processed
			if seen_regions.has(neighbor_id):
				continue
			seen_regions[neighbor_id] = true
			
			# Only include if not owned by this player
			var neighbor_owner = get_region_owner(neighbor_id)
			if neighbor_owner != player_id:
				frontier.append(neighbor_id)

	if frontier.is_empty():
		DebugLogger.log("AITurnManager", "[TurnController] No frontier regions available")
	
	return frontier

func get_castle_level(region_id: int) -> int:
	"""Get the castle level for a region (0 if no castle)"""
	var region_container = map_generator.get_region_container_by_id(region_id)
	if not region_container:
		return 0
	
	var region = region_container as Region
	if not region:
		return 0
		
	# Get castle type and convert to level
	var castle_type = region.get_castle_type()
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

func find_best_recruitment_castle(from_region_id: int, owner_id: int, include_origin: bool = false, exclude_army: Army = null, friendly_only: bool = true) -> Dictionary:
	"""Find owned castles scored by (recruits / distance) * (1 + 0.2 * level).
	Returns {"best_region_id": int, "candidates": Array[Dictionary]}.
	Set include_origin=true to consider the starting castle (distance clamped to >=1).
	"""
	if friendly_only and get_region_owner(from_region_id) != owner_id:
		return {
			"best_region_id": -1,
			"candidates": []
		}
	var visited: Dictionary = {}
	var queue: Array = [[from_region_id, 0]]
	visited[from_region_id] = true
	var best_castle_id := -1
	var best_score: float = -1.0
	var candidates: Array = []
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_id: int = current[0]
		var distance: int = current[1]
		
		var consider_region := include_origin or current_id != from_region_id
		if consider_region:
			var region_owner = get_region_owner(current_id)
			if region_owner == owner_id:
				var castle_level = get_castle_level(current_id)
				if castle_level >= 1:
					var recruit_sources = get_available_recruits_from_region_and_neighbors(current_id, owner_id)
					var total_recruits := 0
					for source in recruit_sources:
						total_recruits += int(source.get("amount", 0))
					if total_recruits > 0:
						var distance_for_score := float(max(1, distance))
						var needy_armies := _count_recruitment_needy_armies(current_id, owner_id, exclude_army)
						var requesting_armies: int = max(1, needy_armies + 1)
						var recruits_for_score: int = int(float(total_recruits) / float(requesting_armies))
						var distance_score := float(recruits_for_score) / distance_for_score
						var level_bonus := 1.0 + (0.2 * float(castle_level))
						var region_node = map_generator.get_region_container_by_id(current_id) as Region
						var region_name: String = region_node.get_region_name()
						var garrison_power: int = region_node.get_garrison_strength()
						var garrison_power_bonus: int = 0
						if needy_armies == 0 and _has_no_nearby_enemy_threats(region_node):
							garrison_power_bonus = garrison_power
						var total_score := (distance_score * level_bonus) + float(garrison_power_bonus)
						var candidate_info := {
							"region_id": current_id,
							"region_name": region_name,
							"distance": distance,
							"recruits": total_recruits,
							"needs_recruitment_armies": needy_armies,
							"power": garrison_power,
							"castle_level": castle_level,
							"score": total_score
						}
						candidates.append(candidate_info)
						if total_score > best_score:
							best_score = total_score
							best_castle_id = current_id
		
		var neighbors = get_neighbor_regions(current_id)
		for neighbor_id in neighbors:
			if friendly_only and get_region_owner(neighbor_id) != owner_id:
				continue
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append([neighbor_id, distance + 1])
	
	if candidates.size() > 1:
		candidates.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	
	return {
		"best_region_id": best_castle_id,
		"candidates": candidates
	}

func _has_no_nearby_enemy_threats(region: Region) -> bool:
	var enemy_army_ids: Dictionary = region.castle_nearby_entities.get("enemy_army_ids", {})
	return enemy_army_ids.is_empty()

func _count_recruitment_needy_armies(region_id: int, owner_id: int, exclude_army: Army = null) -> int:
	"""Count armies belonging to owner_id in the region that requested recruitment."""
	var region_container: Region = map_generator.get_region_container_by_id(region_id)
	var count := 0
	for child in region_container.get_children():
		if child is Army:
			var army := child as Army
			if army == exclude_army:
				continue
			if army.get_player_id() == owner_id and army.is_recruitment_requested():
				count += 1
	return count

func get_available_recruits_from_region_and_neighbors(region_id: int, player_id: int) -> Array:
	"""Get available recruits from a region and all owned neighboring regions. Returns array of {region_id: int, amount: int}"""
	var recruit_sources: Array = []
	
	# Get the main region
	var main_region = map_generator.get_region_container_by_id(region_id)
	var main_owner: int = get_region_owner(region_id)
	if main_owner == player_id:
		var main_recruits = main_region.get_available_recruits()
		if main_recruits > 0:
			recruit_sources.append({"region_id": region_id, "amount": main_recruits})
	
	# Get neighboring regions owned by the same player
	var neighbors = get_neighbor_regions(region_id)
	for neighbor_id in neighbors:
		var neighbor_owner = get_region_owner(neighbor_id)
		if neighbor_owner == player_id:
			var neighbor_region = map_generator.get_region_container_by_id(neighbor_id)
			var neighbor_recruits = neighbor_region.get_available_recruits()
			if neighbor_recruits > 0:
				recruit_sources.append({"region_id": neighbor_id, "amount": neighbor_recruits})
	
	return recruit_sources

func get_available_recruits_total_from_region_and_neighbors(region_id: int, player_id: int) -> int:
	"""Total available recruits from a region and all owned neighboring regions."""
	var recruit_sources: Array = get_available_recruits_from_region_and_neighbors(region_id, player_id)
	var total: int = 0
	for source in recruit_sources:
		total += int(source.amount)
	return total

func get_max_recruits_total_from_region_and_neighbors(region_id: int, player_id: int) -> int:
	"""Total max recruits from a region and all owned neighboring regions."""
	var total: int = 0
	var main_owner: int = get_region_owner(region_id)
	if main_owner == player_id:
		var main_region: Region = map_generator.get_region_container_by_id(region_id)
		total += main_region.get_max_recruits()
	var neighbors = get_neighbor_regions(region_id)
	for neighbor_id in neighbors:
		var neighbor_owner: int = get_region_owner(neighbor_id)
		if neighbor_owner == player_id:
			var neighbor_region: Region = map_generator.get_region_container_by_id(neighbor_id)
			total += neighbor_region.get_max_recruits()
	return total

func deduct_recruits_proportionally_from_region_and_neighbors(region_id: int, player_id: int, total_to_deduct: int) -> void:
	"""Deduct recruits proportionally from a region and all owned neighboring regions."""
	if total_to_deduct <= 0:
		return
	var recruit_sources: Array = get_available_recruits_from_region_and_neighbors(region_id, player_id)
	_deduct_recruits_proportionally(total_to_deduct, recruit_sources)

func _deduct_recruits_proportionally(total_to_deduct: int, recruit_sources: Array) -> void:
	if recruit_sources.is_empty() or total_to_deduct <= 0:
		return
	var total_available: int = 0
	for s in recruit_sources:
		total_available += int(s.amount)
	if total_available <= 0:
		return
	var deduction_target: int = min(total_to_deduct, total_available)
	var shares: Array[Dictionary] = []
	var assigned_total: int = 0
	for src in recruit_sources:
		var amount: int = int(src.amount)
		var ideal: float = (float(amount) / float(total_available)) * float(deduction_target)
		var base_share: int = min(amount, int(floor(ideal)))
		assigned_total += base_share
		shares.append({
			"region_id": int(src.region_id),
			"amount": amount,
			"assigned": base_share,
			"fraction": ideal - float(base_share)
		})
	var remaining: int = deduction_target - assigned_total
	while remaining > 0:
		var best_idx: int = -1
		var best_fraction: float = -1.0
		var best_amount: int = -1
		var best_region_id: int = 2147483647
		for i in range(shares.size()):
			var share: Dictionary = shares[i]
			var amount: int = int(share.get("amount", 0))
			var assigned: int = int(share.get("assigned", 0))
			if assigned >= amount:
				continue
			var fraction: float = float(share.get("fraction", 0.0))
			var region_id: int = int(share.get("region_id", 0))
			if fraction > best_fraction or (is_equal_approx(fraction, best_fraction) and (amount > best_amount or (amount == best_amount and region_id < best_region_id))):
				best_idx = i
				best_fraction = fraction
				best_amount = amount
				best_region_id = region_id
		if best_idx == -1:
			break
		shares[best_idx]["assigned"] = int(shares[best_idx].get("assigned", 0)) + 1
		remaining -= 1
	for share in shares:
		var to_deduct: int = int(share.get("assigned", 0))
		if to_deduct <= 0:
			continue
		var reg: Region = map_generator.get_region_container_by_id(int(share.get("region_id", -1)))
		reg.hire_recruits(to_deduct)

func perform_ore_search(region: Region, player_id: int, player_manager: PlayerManagerNode) -> Dictionary:
	"""Perform ore search in a region for a player. Returns search result."""
	if region == null:
		return {"success": false, "message": "Invalid region"}
	
	if player_manager == null:
		return {"success": false, "message": "Invalid player manager"}
	
	# Check if region can be searched
	if not region.can_search_for_ore():
		return {"success": false, "message": "Cannot search for ore in this region"}
	
	# Check if player can afford the search cost
	var search_cost = GameParameters.get_ore_search_cost()
	var current_player = player_manager.get_player(player_id)
	if current_player == null:
		return {"success": false, "message": "Player not found"}
	
	if current_player.get_resource_amount(ResourcesEnum.Type.GOLD) < search_cost:
		return {"success": false, "message": "Not enough gold (requires " + str(search_cost) + " gold)"}
	
	# Deduct the search cost
	current_player.remove_resources(ResourcesEnum.Type.GOLD, search_cost)
	DebugLogger.log("RegionManagement", "Player " + str(player_id) + " spent " + str(search_cost) + " gold for ore search in " + region.get_region_name())
	
	# Perform the search
	var search_result = region.search_for_ore()
	
	# If ore was discovered, make it available in the region's resources
	if search_result.success:
		var ore_type = search_result.ore_type
		# Check if this ore type already has a resource amount, if not, add it based on the region's potential
		var current_amount = region.get_resource_amount(ore_type)
		if current_amount == 0:
			# Generate initial ore amount based on region type
			var generated_amount = GameParameters.generate_resource_amount(region.get_region_type(), ore_type)
			if generated_amount > 0:
				region.resources.set_resource_amount(ore_type, generated_amount)
				DebugLogger.log("RegionManagement", "Made " + str(generated_amount) + " " + ResourcesEnum.type_to_string(ore_type) + " available for collection in " + region.get_region_name())
	
	return search_result
