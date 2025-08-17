extends Node2D
class_name Region

# Region properties - all data here
var region_id: int = -1
var region_name: String = ""
var biome: String = ""
var region_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND
var region_level: RegionLevelEnum.Level = RegionLevelEnum.Level.MARCH
var is_ocean: bool = false
var center: Vector2 = Vector2.ZERO

# Army composition stationed in this region
var garrison: ArmyComposition

func setup_region(region_data: Dictionary) -> void:
	"""Setup the region with data from the map generator"""
	region_id = int(region_data.get("id", -1))
	biome = String(region_data.get("biome", ""))
	region_type = RegionTypeEnum.string_to_type(biome)
	is_ocean = bool(region_data.get("ocean", false))
	
	# Initialize garrison
	garrison = ArmyComposition.new()
	
	# Set basic garrison composition for non-ocean regions
	if not is_ocean:
		var peasant_count = randi_range(10, 30)
		garrison.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, peasant_count)
	
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
