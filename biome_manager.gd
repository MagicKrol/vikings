extends RefCounted

class_name BiomeManager

# Mapping of biome substring matches to icon textures
const BIOME_ICON_RULES := [
	{"match": "forest", "path": "res://images/icons/forest.png"},
	{"match": "hill_forest", "path": "res://images/icons/icons.png"},
	{"match": "hills", "path": "res://images/icons/hill.png"},
	{"match": "mountains", "path": "res://images/icons/mountain.png"},
]

static func get_biome_color(biome: String) -> Color:
	# JS discrete colors from colormap.js
	var discrete_colors := {
		"OCEAN": "#44447a",
		"LAKE": "#336699",
		"MARSH": "#2f6666",
		"ICE": "#99ffff",
		"BEACH": "#a09077",
		"SNOW": "#ffffff",
		"TUNDRA": "#bbbbaa",
		"BARE": "#888888",
		"SCORCHED": "#555555",
		"TAIGA": "#99aa77",
		"SHRUBLAND": "#889977",
		"TEMPERATE_DESERT": "#c9d29b",
		"TEMPERATE_RAIN_FOREST": "#448855",
		"TEMPERATE_DECIDUOUS_FOREST": "#679459",
		"GRASSLAND": "#88aa55",
		"SUBTROPICAL_DESERT": "#d2b98b",
		"TROPICAL_RAIN_FOREST": "#337755",
		"TROPICAL_SEASONAL_FOREST": "#559944"
	}
	
	if biome in discrete_colors:
		return Utils.hex_to_color(discrete_colors[biome])
	else:
		return Color.MAGENTA  # Debug color for missing biomes

static func get_icon_path_for_biome(biome_name: String) -> String:
	var biome_lower := biome_name.to_lower()
	for rule in BIOME_ICON_RULES:
		var needle := String(rule.get("match", "")).to_lower()
		if needle != "" and biome_lower == needle:
			return String(rule.get("path", ""))
	return ""
