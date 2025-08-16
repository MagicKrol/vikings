extends RefCounted
class_name RegionTypeEnum

# Region/Terrain types for movement and gameplay mechanics
enum Type {
	OCEAN,                    # Water - impassable for armies
	LAKE,                     # Water - impassable for armies  
	MARSH,                    # Difficult terrain - high movement cost
	ICE,                      # Difficult terrain - high movement cost
	BEACH,                    # Easy terrain - low movement cost
	SNOW,                     # Difficult terrain - high movement cost
	TUNDRA,                   # Normal terrain - medium movement cost
	BARE,                     # Normal terrain - medium movement cost
	SCORCHED,                 # Difficult terrain - high movement cost
	TAIGA,                    # Forest terrain - high movement cost
	SHRUBLAND,                # Normal terrain - medium movement cost
	TEMPERATE_DESERT,         # Normal terrain - medium movement cost
	TEMPERATE_RAIN_FOREST,    # Forest terrain - high movement cost
	TEMPERATE_DECIDUOUS_FOREST, # Forest terrain - high movement cost
	GRASSLAND,                # Easy terrain - low movement cost
	SUBTROPICAL_DESERT,       # Normal terrain - medium movement cost
	TROPICAL_RAIN_FOREST,     # Forest terrain - high movement cost
	TROPICAL_SEASONAL_FOREST, # Forest terrain - high movement cost
	MOUNTAINS,                # Impassable terrain
	HILLS                     # Difficult terrain - high movement cost
}

# Movement costs for each terrain type
const MOVEMENT_COSTS = {
	Type.OCEAN: -1,                          # Impassable
	Type.LAKE: -1,                           # Impassable
	Type.MARSH: 4,                           # High cost
	Type.ICE: 3,                             # High cost
	Type.BEACH: 1,                           # Low cost
	Type.SNOW: 3,                            # High cost
	Type.TUNDRA: 2,                          # Medium cost
	Type.BARE: 2,                            # Medium cost
	Type.SCORCHED: 3,                        # High cost
	Type.TAIGA: 3,                           # High cost (forest)
	Type.SHRUBLAND: 2,                       # Medium cost
	Type.TEMPERATE_DESERT: 2,                # Medium cost
	Type.TEMPERATE_RAIN_FOREST: 3,           # High cost (forest)
	Type.TEMPERATE_DECIDUOUS_FOREST: 3,      # High cost (forest)
	Type.GRASSLAND: 1,                       # Low cost
	Type.SUBTROPICAL_DESERT: 2,              # Medium cost
	Type.TROPICAL_RAIN_FOREST: 3,            # High cost (forest)
	Type.TROPICAL_SEASONAL_FOREST: 3,        # High cost (forest)
	Type.MOUNTAINS: -1,                      # Impassable
	Type.HILLS: 3                            # High cost
}

# Convert string biome name to enum type
static func string_to_type(biome_string: String) -> Type:
	var biome_upper = biome_string.to_upper()
	
	# Handle special cases and variations
	if biome_upper.contains("MOUNTAIN"):
		return Type.MOUNTAINS
	elif biome_upper.contains("HILL"):
		return Type.HILLS
	elif biome_upper == "FOREST":
		return Type.TEMPERATE_DECIDUOUS_FOREST
	
	# Direct mapping for exact matches
	match biome_upper:
		"OCEAN":
			return Type.OCEAN
		"LAKE":
			return Type.LAKE
		"MARSH":
			return Type.MARSH
		"ICE":
			return Type.ICE
		"BEACH":
			return Type.BEACH
		"SNOW":
			return Type.SNOW
		"TUNDRA":
			return Type.TUNDRA
		"BARE":
			return Type.BARE
		"SCORCHED":
			return Type.SCORCHED
		"TAIGA":
			return Type.TAIGA
		"SHRUBLAND":
			return Type.SHRUBLAND
		"TEMPERATE_DESERT":
			return Type.TEMPERATE_DESERT
		"TEMPERATE_RAIN_FOREST":
			return Type.TEMPERATE_RAIN_FOREST
		"TEMPERATE_DECIDUOUS_FOREST":
			return Type.TEMPERATE_DECIDUOUS_FOREST
		"GRASSLAND":
			return Type.GRASSLAND
		"SUBTROPICAL_DESERT":
			return Type.SUBTROPICAL_DESERT
		"TROPICAL_RAIN_FOREST":
			return Type.TROPICAL_RAIN_FOREST
		"TROPICAL_SEASONAL_FOREST":
			return Type.TROPICAL_SEASONAL_FOREST
		"MOUNTAINS":
			return Type.MOUNTAINS
		"HILLS":
			return Type.HILLS
		_:
			return Type.GRASSLAND  # Default to grassland for unknown types

# Convert enum type back to string
static func type_to_string(region_type: Type) -> String:
	match region_type:
		Type.OCEAN:
			return "OCEAN"
		Type.LAKE:
			return "LAKE"
		Type.MARSH:
			return "MARSH"
		Type.ICE:
			return "ICE"
		Type.BEACH:
			return "BEACH"
		Type.SNOW:
			return "SNOW"
		Type.TUNDRA:
			return "TUNDRA"
		Type.BARE:
			return "BARE"
		Type.SCORCHED:
			return "SCORCHED"
		Type.TAIGA:
			return "TAIGA"
		Type.SHRUBLAND:
			return "SHRUBLAND"
		Type.TEMPERATE_DESERT:
			return "TEMPERATE_DESERT"
		Type.TEMPERATE_RAIN_FOREST:
			return "TEMPERATE_RAIN_FOREST"
		Type.TEMPERATE_DECIDUOUS_FOREST:
			return "TEMPERATE_DECIDUOUS_FOREST"
		Type.GRASSLAND:
			return "GRASSLAND"
		Type.SUBTROPICAL_DESERT:
			return "SUBTROPICAL_DESERT"
		Type.TROPICAL_RAIN_FOREST:
			return "TROPICAL_RAIN_FOREST"
		Type.TROPICAL_SEASONAL_FOREST:
			return "TROPICAL_SEASONAL_FOREST"
		Type.MOUNTAINS:
			return "MOUNTAINS"
		Type.HILLS:
			return "HILLS"
		_:
			return "GRASSLAND"

# Get movement cost for a terrain type
static func get_movement_cost(region_type: Type) -> int:
	return MOVEMENT_COSTS.get(region_type, 2)  # Default to medium cost

# Check if terrain is passable (movement cost != -1)
static func is_passable(region_type: Type) -> bool:
	return get_movement_cost(region_type) != -1

# Check if terrain is water-based
static func is_water_terrain(region_type: Type) -> bool:
	return region_type == Type.OCEAN or region_type == Type.LAKE

# Check if terrain is forest-based (high movement cost)
static func is_forest_terrain(region_type: Type) -> bool:
	return region_type in [
		Type.TAIGA,
		Type.TEMPERATE_RAIN_FOREST,
		Type.TEMPERATE_DECIDUOUS_FOREST,
		Type.TROPICAL_RAIN_FOREST,
		Type.TROPICAL_SEASONAL_FOREST
	]

# Check if terrain is mountainous/hilly
static func is_elevated_terrain(region_type: Type) -> bool:
	return region_type == Type.MOUNTAINS or region_type == Type.HILLS
