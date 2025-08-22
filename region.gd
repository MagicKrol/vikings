extends Node2D
class_name Region

# ============================================================================
# REGION
# ============================================================================
# 
# Purpose: Individual region data container and territory management
# 
# Core Responsibilities:
# - Region properties storage (ID, name, biome, type, level, population)
# - Garrison and resource composition management
# - Movement cost and passability determination based on terrain
# - Population tracking and level-based management
# - Integration with regional systems and map display
# 
# Required Functions:
# - setup_region(): Initialize region from map generator data
# - get/set_region_level(): Administrative level management
# - garrison management: add/remove/get garrison composition
# - resource management: access to region resource composition
# - population management: get/set population values
# 
# Integration Points:
# - RegionManager: Territory ownership and resource generation
# - MapGenerator: Region initialization and positioning data
# - GameParameters: Population and garrison generation rules
# - Enums: Region type, level, and resource type definitions
# ============================================================================

# Region properties - all data here
var region_id: int = -1
var region_name: String = ""
var biome: String = ""
var region_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND
var region_level: RegionLevelEnum.Level = RegionLevelEnum.Level.L1
var is_ocean: bool = false
var center: Vector2 = Vector2.ZERO

# Army composition stationed in this region
var garrison: ArmyComposition

# Resource composition available in this region
var resources: ResourceComposition

# Population in this region
var population: int = 0

# Available recruits in this region
var available_recruits: int = 0

# Last turn's population growth (for UI display)
var last_population_growth: int = 0

# Castle information
var castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE
var castle_under_construction: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE
var castle_build_turns_remaining: int = 0

# Mining system information
var ore_search_attempts_remaining: int = 0  # Number of ore search attempts left
var discovered_ores: Array[ResourcesEnum.Type] = []  # Which ores have been discovered
var ore_search_used_this_turn: bool = false  # Track if ore search was used this turn

func setup_region(region_data: Dictionary) -> void:
	"""Setup the region with data from the map generator"""
	region_id = int(region_data.get("id", -1))
	biome = String(region_data.get("biome", ""))
	region_type = RegionTypeEnum.string_to_type(biome)
	is_ocean = bool(region_data.get("ocean", false))
	
	# Initialize garrison and resources
	garrison = ArmyComposition.new()
	resources = ResourceComposition.new()
	
	# Set basic garrison composition and population for non-ocean regions
	if not is_ocean:
		var peasant_count = GameParameters.generate_garrison_size(region_level)
		garrison.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, peasant_count)
		# Generate population based on region level
		population = GameParameters.generate_population_size(region_level)
		# Initialize available recruits based on population
		available_recruits = GameParameters.calculate_max_recruits(population)
		# Initialize ore search attempts if region can have ores
		if GameParameters.can_search_for_ore_in_region(region_type):
			ore_search_attempts_remaining = GameParameters.ORE_SEARCH_CHANCES_PER_REGION
	
	# Set center position
	var center_data = region_data.get("center", [])
	if center_data.size() == 2:
		center = Vector2(center_data[0], center_data[1])

func set_region_name(new_name: String) -> void:
	"""Set the region name (called by RegionManager)"""
	region_name = new_name
	# Use the actual region name as the node name
	name = new_name

func get_region_name() -> String:
	"""Get the region name"""
	return region_name

func get_region_id() -> int:
	"""Get the region ID"""
	return region_id

func get_biome() -> String:
	"""Get the biome type"""
	return biome

func get_region_type() -> RegionTypeEnum.Type:
	"""Get the region type enum"""
	return region_type

func get_movement_cost() -> int:
	"""Get the movement cost for this region"""
	return RegionTypeEnum.get_movement_cost(region_type)

func is_passable() -> bool:
	"""Check if this region is passable for armies"""
	return RegionTypeEnum.is_passable(region_type)

func is_ocean_region() -> bool:
	"""Check if this is an ocean region"""
	return is_ocean

func get_region_level() -> RegionLevelEnum.Level:
	"""Get the region level"""
	return region_level

func set_region_level(level: RegionLevelEnum.Level) -> void:
	"""Set the region level"""
	region_level = level

func get_region_level_string() -> String:
	"""Get the region level as a string"""
	return RegionLevelEnum.level_to_string(region_level)

func get_region_type_display_string() -> String:
	"""Get the simplified region type as a display string (grassland, forest, hills, forest hills, mountains)"""
	return RegionTypeEnum.type_to_display_string(region_type)

# Garrison management methods
func get_garrison() -> ArmyComposition:
	"""Get the army composition stationed in this region"""
	return garrison

func add_soldiers_to_garrison(soldier_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Add soldiers to the region's garrison"""
	garrison.add_soldiers(soldier_type, count)

func remove_soldiers_from_garrison(soldier_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Remove soldiers from the region's garrison"""
	garrison.remove_soldiers(soldier_type, count)

func get_garrison_strength() -> int:
	"""Get total combat strength of the garrison"""
	return garrison.get_total_attack()

func has_garrison() -> bool:
	"""Check if region has any garrison soldiers"""
	return garrison.has_soldiers()

func get_garrison_composition_string() -> String:
	"""Get garrison composition as a readable string"""
	return garrison.get_composition_string()

# Resource management methods
func get_resources() -> ResourceComposition:
	"""Get the resource composition in this region"""
	return resources

func get_resource_amount(resource_type: ResourcesEnum.Type) -> int:
	"""Get amount of specific resource type"""
	return resources.get_resource_amount(resource_type)

func has_resources() -> bool:
	"""Check if region has any resources"""
	return resources.has_resources()

func get_resource_composition_string() -> String:
	"""Get resource composition as a readable string"""
	return resources.get_composition_string()

# Population management methods
func get_population() -> int:
	"""Get current population in this region"""
	return population

func set_population(new_population: int) -> void:
	"""Set population for this region"""
	population = max(0, new_population)
	# Recalculate max recruits when population changes
	var max_recruits = GameParameters.calculate_max_recruits(population)
	# Ensure available recruits don't exceed new maximum
	available_recruits = min(available_recruits, max_recruits)

# Recruit management methods
func get_available_recruits() -> int:
	"""Get current available recruits in this region"""
	return available_recruits

func get_max_recruits() -> int:
	"""Get maximum recruits based on current population"""
	return GameParameters.calculate_max_recruits(population)

func hire_recruits(count: int) -> int:
	"""Hire recruits from this region, returns actual hired count"""
	var actual_hired = min(count, available_recruits)
	if actual_hired > 0:
		available_recruits -= actual_hired
		# Reduce population by hired recruits
		population -= actual_hired
		# Recalculate max recruits after population reduction
		var max_recruits = GameParameters.calculate_max_recruits(population)
		# Ensure available recruits don't exceed new maximum
		available_recruits = min(available_recruits, max_recruits)
	return actual_hired

func replenish_recruits() -> void:
	"""Replenish recruits based on current population (called each turn)"""
	var replenishment = GameParameters.calculate_recruit_replenishment(population)
	var max_recruits = GameParameters.calculate_max_recruits(population)
	available_recruits = min(available_recruits + replenishment, max_recruits)

func grow_population() -> void:
	"""Grow population per turn based on recruitment impact (called each turn)"""
	if is_ocean:
		return  # Ocean regions don't have population
	
	# Base growth rate from GameParameters
	var base_growth_rate = GameParameters.POPULATION_GROWTH_RATE
	
	# Calculate current recruit ratio (available / max) but cap at 1.0 to prevent Call to Arms from boosting growth above 3%
	var max_recruits = GameParameters.calculate_max_recruits(population)
	var recruit_ratio = 0.0
	if max_recruits > 0:
		recruit_ratio = min(1.0, float(available_recruits) / float(max_recruits))
	
	# Growth rate is modified by recruit availability: base_rate * (available_recruits / max_recruits), capped at base_rate
	var actual_growth_rate = base_growth_rate * recruit_ratio
	
	# Calculate population growth (rounded down)
	var population_growth = int(population * actual_growth_rate)
	
	# Track the growth for UI display
	last_population_growth = population_growth
	
	if population_growth > 0:
		var old_population = population
		population += population_growth
		
		# Recalculate max recruits based on new population, but don't change available recruits
		# (the available recruits will be updated in the next recruit replenishment phase)
		print("[Region] ", region_name, " population grew from ", old_population, " to ", population, " (+" , population_growth, ", rate: ", actual_growth_rate * 100, "%)")

# Castle management methods
func get_castle_type() -> CastleTypeEnum.Type:
	"""Get the current castle type"""
	return castle_type

func set_castle_type(new_castle_type: CastleTypeEnum.Type) -> void:
	"""Set the castle type (used when construction completes)"""
	castle_type = new_castle_type

func has_castle() -> bool:
	"""Check if region has any castle"""
	return castle_type != CastleTypeEnum.Type.NONE

func get_castle_type_string() -> String:
	"""Get the castle type as a string"""
	return CastleTypeEnum.type_to_string(castle_type)

func is_castle_under_construction() -> bool:
	"""Check if a castle is currently being built"""
	return castle_under_construction != CastleTypeEnum.Type.NONE

func get_castle_under_construction() -> CastleTypeEnum.Type:
	"""Get the castle type being constructed"""
	return castle_under_construction

func get_castle_build_turns_remaining() -> int:
	"""Get remaining turns for castle construction"""
	return castle_build_turns_remaining

func start_castle_construction(castle_type_to_build: CastleTypeEnum.Type) -> void:
	"""Start construction of a castle type"""
	castle_under_construction = castle_type_to_build
	castle_build_turns_remaining = GameParameters.get_castle_build_time(castle_type_to_build)
	print("[Region] Started construction of ", CastleTypeEnum.type_to_string(castle_type_to_build), " in ", region_name, " (", castle_build_turns_remaining, " turns remaining)")

func process_castle_construction() -> bool:
	"""Process castle construction for one turn. Returns true if construction completed."""
	if not is_castle_under_construction():
		return false
	
	castle_build_turns_remaining -= 1
	print("[Region] Castle construction in ", region_name, ": ", castle_build_turns_remaining, " turns remaining")
	
	if castle_build_turns_remaining <= 0:
		# Construction completed
		var completed_castle_type = castle_under_construction
		castle_type = castle_under_construction
		castle_under_construction = CastleTypeEnum.Type.NONE
		castle_build_turns_remaining = 0
		print("[Region] Castle construction completed in ", region_name, "! Built: ", CastleTypeEnum.type_to_string(completed_castle_type))
		
		# Trigger visual update by finding and calling the visual manager
		_update_castle_visual()
		
		return true
	
	return false

func _update_castle_visual() -> void:
	"""Update the castle visual when construction completes"""
	# Find the GameManager and get the VisualManager
	var game_manager = get_node("/root/Main/GameManager") as GameManager
	if game_manager == null:
		print("[Region] Warning: Could not find GameManager for visual update")
		return
	
	var visual_manager = game_manager.get_visual_manager()
	if visual_manager == null:
		print("[Region] Warning: Could not find VisualManager for visual update")
		return
	
	# Update the castle visual (this will place the correct icon)
	visual_manager.update_castle_visual(self)
	print("[Region] Updated castle visual for ", region_name)

func can_build_castle() -> bool:
	"""Check if a castle can be built in this region"""
	# Cannot build if already has castle or construction in progress
	if has_castle() or is_castle_under_construction():
		return false
	
	# Cannot build in ocean regions
	if is_ocean:
		return false
	
	return true

func can_upgrade_castle() -> bool:
	"""Check if the current castle can be upgraded"""
	# Must have a castle and not be under construction
	if not has_castle() or is_castle_under_construction():
		return false
	
	# Check if castle can be upgraded to next level
	return CastleTypeEnum.can_upgrade(castle_type)

# Mining system methods
func can_search_for_ore() -> bool:
	"""Check if ore search is possible in this region"""
	# Must be a region that can have ores
	if not GameParameters.can_search_for_ore_in_region(region_type):
		return false
	
	# Must have search attempts remaining
	if ore_search_attempts_remaining <= 0:
		return false
	
	# Cannot search if already used this turn
	if ore_search_used_this_turn:
		return false
	
	# Cannot search in ocean regions
	if is_ocean:
		return false
	
	return true

func get_ore_search_attempts_remaining() -> int:
	"""Get the number of ore search attempts remaining"""
	return ore_search_attempts_remaining

func search_for_ore() -> Dictionary:
	"""Perform ore search. Returns {success: bool, ore_type: ResourcesEnum.Type, message: String}"""
	if not can_search_for_ore():
		return {"success": false, "ore_type": ResourcesEnum.Type.GOLD, "message": "Cannot search for ore in this region"}
	
	# Use up one attempt
	ore_search_attempts_remaining -= 1
	ore_search_used_this_turn = true
	
	# Roll for discovery
	var discovery_successful = GameParameters.roll_ore_discovery()
	
	if discovery_successful:
		# Roll for ore type
		var ore_type = GameParameters.roll_ore_type()
		
		# Add to discovered ores if not already found
		if ore_type not in discovered_ores:
			discovered_ores.append(ore_type)
		
		print("[Region] Ore discovered in ", region_name, "! Found: ", ResourcesEnum.type_to_string(ore_type))
		return {"success": true, "ore_type": ore_type, "message": "Discovered " + ResourcesEnum.type_to_string(ore_type) + " ore!"}
	else:
		print("[Region] No ore found in ", region_name, " (", ore_search_attempts_remaining, " attempts remaining)")
		return {"success": false, "ore_type": ResourcesEnum.Type.GOLD, "message": "No ore found this time"}

func has_discovered_ore(ore_type: ResourcesEnum.Type) -> bool:
	"""Check if a specific ore type has been discovered in this region"""
	return ore_type in discovered_ores

func get_discovered_ores() -> Array[ResourcesEnum.Type]:
	"""Get all discovered ore types"""
	return discovered_ores.duplicate()

func can_collect_resource(resource_type: ResourcesEnum.Type) -> bool:
	"""Check if a resource can be collected (for Gold/Iron, must be discovered first)"""
	# For Gold and Iron, must be discovered first
	if resource_type == ResourcesEnum.Type.GOLD or resource_type == ResourcesEnum.Type.IRON:
		return has_discovered_ore(resource_type)
	
	# Other resources can be collected normally
	return get_resource_amount(resource_type) > 0

func reset_ore_search_turn_usage() -> void:
	"""Reset the ore search usage flag for the new turn"""
	ore_search_used_this_turn = false

func get_ore_search_status_string() -> String:
	"""Get a human-readable string describing ore search status"""
	if not GameParameters.can_search_for_ore_in_region(region_type):
		return "No ores in this region type"
	
	if ore_search_attempts_remaining <= 0:
		return "All ore search attempts exhausted"
	
	var status = str(ore_search_attempts_remaining) + " search attempts remaining"
	if ore_search_used_this_turn:
		status += " (used this turn)"
	
	if not discovered_ores.is_empty():
		status += "\nDiscovered ores: "
		var ore_names: Array[String] = []
		for ore in discovered_ores:
			ore_names.append(ResourcesEnum.type_to_string(ore))
		status += ", ".join(ore_names)
	
	return status
