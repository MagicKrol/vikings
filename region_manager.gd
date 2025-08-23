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

# Castle starting positions: player_id -> region_id
var castle_starting_positions: Dictionary = {}

# Reference to the region graph for neighbor lookups
var region_graph: Dictionary = {}

# Reference to the map generator for region data
var map_generator: MapGenerator

# Region name management
var available_names: Array[String] = []
var used_names: Dictionary = {}

func _init(map_gen: MapGenerator):
	map_generator = map_gen
	_load_region_names()
	_build_region_graph()
	_generate_all_region_resources()

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
			print("[RegionManager] Error parsing regions.json")

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
	region_ownership[region_id] = player_id
	
	# Update the region's ownership tracking
	var region_container = map_generator.get_region_container_by_id(region_id)
	if region_container != null:
		var region = region_container as Region
		if region != null:
			region.set_region_owner(player_id)
	
	# Create colored overlay for owned region
	if map_generator and map_generator.has_method("create_ownership_overlay"):
		map_generator.create_ownership_overlay(region_id, player_id)
	
	# Trigger border recalculation for colored borders
	if map_generator and map_generator.has_method("regenerate_borders_for_region"):
		map_generator.regenerate_borders_for_region(region_id)
	elif map_generator and map_generator.has_method("regenerate_borders"):
		# Fallback to full regeneration
		map_generator.regenerate_borders()

func set_initial_region_ownership(region_id: int, player_id: int) -> void:
	"""Set initial ownership of a region for castle placement with full recruitment"""
	region_ownership[region_id] = player_id
	
	# Update the region's ownership tracking with full recruitment counter
	var region_container = map_generator.get_region_container_by_id(region_id)
	if region_container != null:
		var region = region_container as Region
		if region != null:
			region.set_initial_region_owner(player_id)
	
	# Create colored overlay for owned region
	if map_generator and map_generator.has_method("create_ownership_overlay"):
		map_generator.create_ownership_overlay(region_id, player_id)
	
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
		print("[RegionManager] Cannot place castle - region ", region_id, " is already owned by Player ", current_owner)
		return false
	
	# Set the castle starting position
	castle_starting_positions[player_id] = region_id
	
	# Claim the starting region with full recruitment counter
	set_initial_region_ownership(region_id, player_id)
	
	# Claim neighboring regions (expansion) with full recruitment counter
	var neighbors = get_neighbor_regions(region_id)
	for neighbor_id in neighbors:
		if get_region_owner(neighbor_id) == -1:  # Only claim unowned regions
			set_initial_region_ownership(neighbor_id, player_id)
	
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
	var region_level = region.get_region_level()
	
	# Clear existing resources
	region.resources = ResourceComposition.new()
	
	# Generate base resources based on region type using GameParameters
	for resource_type in ResourcesEnum.get_all_types():
		var base_amount = GameParameters.generate_resource_amount(biome_type, resource_type)
		if base_amount > 0:
			# Apply region level bonus: base_amount * (1 + (region_level - 1) * REGION_RESOURCE_LEVEL_MULTIPLIER)
			var level_int = _region_level_to_int(region_level)
			var level_multiplier = 1.0 + (level_int - 1) * GameParameters.REGION_RESOURCE_LEVEL_MULTIPLIER
			var final_amount = round(base_amount * level_multiplier)
			region.resources.set_resource_amount(resource_type, int(final_amount))

func _region_level_to_int(region_level: RegionLevelEnum.Level) -> int:
	"""Convert region level enum to integer"""
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
			return 1  # Default to level 1

func upgrade_castle_regions(castle_region: Region) -> void:
	"""Upgrade castle region to L3 and neighboring regions to L2, recalculate population"""
	# Upgrade castle region to L3
	castle_region.set_region_level(RegionLevelEnum.Level.L3)
	var castle_population = GameParameters.generate_population_size(RegionLevelEnum.Level.L3)
	castle_region.set_population(castle_population)
	# Initialize recruits for castle region (will have outpost castle type)
	castle_region.available_recruits = GameParameters.calculate_max_recruits(castle_population, CastleTypeEnum.Type.OUTPOST)
	
	# Get neighboring regions and upgrade them to L2
	var neighbor_ids = get_neighbor_regions(castle_region.get_region_id())
	var regions_node = map_generator.get_node("Regions")
	for neighbor_id in neighbor_ids:
		for child in regions_node.get_children():
			if child is Region and child.get_region_id() == neighbor_id:
				var neighbor_region = child as Region
				neighbor_region.set_region_level(RegionLevelEnum.Level.L2)
				var neighbor_population = GameParameters.generate_population_size(RegionLevelEnum.Level.L2)
				neighbor_region.set_population(neighbor_population)
				# Initialize recruits for neighbor region (no castle)
				neighbor_region.available_recruits = GameParameters.calculate_max_recruits(neighbor_population, CastleTypeEnum.Type.NONE)
				break

func _generate_all_region_resources() -> void:
	"""Generate resources for all regions when the RegionManager is initialized"""
	if map_generator == null:
		return
	
	# Get all region containers from the map generator
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		print("[RegionManager] Warning: No Regions node found in map generator")
		return
	
	# Generate resources for each region
	var regions_generated = 0
	for child in regions_node.get_children():
		if child is Region:
			generate_region_resources(child)
			regions_generated += 1
	
	print("[RegionManager] Generated resources for ", regions_generated, " regions")

func replenish_all_recruits() -> void:
	"""Replenish recruits for all regions (called each turn)"""
	if map_generator == null:
		return
	
	# Get all region containers from the map generator
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		print("[RegionManager] Warning: No Regions node found in map generator")
		return
	
	# Replenish recruits for each region
	var regions_replenished = 0
	for child in regions_node.get_children():
		if child is Region:
			child.replenish_recruits()
			regions_replenished += 1
	
	print("[RegionManager] Replenished recruits for ", regions_replenished, " regions")

func grow_all_populations() -> void:
	"""Grow population for all regions (called each turn)"""
	if map_generator == null:
		return
	
	# Get all region containers from the map generator
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		print("[RegionManager] Warning: No Regions node found in map generator")
		return
	
	# Grow population for each region
	var regions_grown = 0
	for child in regions_node.get_children():
		if child is Region:
			child.grow_population()
			regions_grown += 1
	
	print("[RegionManager] Processed population growth for ", regions_grown, " regions")

func process_all_castle_construction() -> void:
	"""Process castle construction for all regions (called each turn)"""
	if map_generator == null:
		return
	
	# Get all region containers from the map generator
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		print("[RegionManager] Warning: No Regions node found in map generator")
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
		print("[RegionManager] Completed ", completed_constructions, " castle constructions this turn")
	print("[RegionManager] Processed castle construction for ", regions_processed, " regions")

func reset_all_ore_search_turn_usage() -> void:
	"""Reset ore search turn usage for all regions (called each turn)"""
	if map_generator == null:
		return
	
	# Get all region containers from the map generator
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		print("[RegionManager] Warning: No Regions node found in map generator")
		return
	
	# Reset ore search usage for each region
	var regions_reset = 0
	for child in regions_node.get_children():
		if child is Region:
			child.reset_ore_search_turn_usage()
			regions_reset += 1
	
	print("[RegionManager] Reset ore search turn usage for ", regions_reset, " regions")

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
	print("[RegionManager] Player ", player_id, " spent ", search_cost, " gold for ore search in ", region.get_region_name())
	
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
				print("[RegionManager] Made ", generated_amount, " ", ResourcesEnum.type_to_string(ore_type), " available for collection in ", region.get_region_name())
	
	return search_result
