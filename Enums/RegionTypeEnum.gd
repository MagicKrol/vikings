extends RefCounted
class_name RegionTypeEnum

# Final region types for gameplay - only these 5 types exist in the game
enum Type {
	GRASSLAND,     # Easy terrain - low movement cost, basic resources
	HILLS,         # Difficult terrain - high movement cost, mineral resources  
	FOREST_HILLS,  # Difficult terrain - high movement cost, mixed forest/mineral resources
	FOREST,        # Difficult terrain - high movement cost, wood resources
	MOUNTAINS      # Impassable terrain - no resources, blocks movement
}

# Movement costs now managed in GameParameters.gd

# Convert string biome name to final region type
static func string_to_type(biome_string: String) -> Type:
	var biome_upper = biome_string.to_upper()
	
	# Mountains - impassable terrain
	if biome_upper.contains("MOUNTAIN"):
		return Type.MOUNTAINS
	
	# Hills - check if it's in a forest area (forest hills) or regular hills
	elif biome_upper.contains("HILL"):
		if _is_forest_biome(biome_string):
			return Type.FOREST_HILLS
		else:
			return Type.HILLS
	
	# Forest types - all forest biomes become FOREST
	elif _is_forest_biome(biome_string):
		return Type.FOREST
	
	# All other biomes become grassland (including deserts, tundra, etc.)
	else:
		return Type.GRASSLAND

# Convert enum type back to string
static func type_to_string(region_type: Type) -> String:
	match region_type:
		Type.GRASSLAND:
			return "GRASSLAND"
		Type.HILLS:
			return "HILLS"
		Type.FOREST_HILLS:
			return "FOREST_HILLS"
		Type.FOREST:
			return "FOREST"
		Type.MOUNTAINS:
			return "MOUNTAINS"
		_:
			return "GRASSLAND"

# Get movement cost for a terrain type
static func get_movement_cost(region_type: Type) -> int:
	return GameParameters.get_movement_cost(region_type)

# Check if terrain is passable (movement cost != -1)
static func is_passable(region_type: Type) -> bool:
	return get_movement_cost(region_type) != -1

# Check if terrain is forest-based
static func is_forest_terrain(region_type: Type) -> bool:
	return region_type == Type.FOREST or region_type == Type.FOREST_HILLS

# Check if terrain is mountainous/hilly
static func is_elevated_terrain(region_type: Type) -> bool:
	return region_type == Type.MOUNTAINS or region_type == Type.HILLS or region_type == Type.FOREST_HILLS

# Convert region type to display string for UI
static func type_to_display_string(region_type: Type) -> String:
	match region_type:
		Type.GRASSLAND:
			return "Grassland"
		Type.HILLS:
			return "Hills"
		Type.FOREST_HILLS:
			return "Forest Hills"
		Type.FOREST:
			return "Forest"
		Type.MOUNTAINS:
			return "Mountains"
		_:
			return "Grassland"  # Default fallback

# Helper function to check if biome string indicates forest terrain
static func _is_forest_biome(biome_string: String) -> bool:
	var biome_upper = biome_string.to_upper()
	return biome_upper.contains("FOREST") or biome_upper == "TAIGA"
