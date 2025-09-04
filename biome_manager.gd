extends RefCounted

class_name BiomeManager

# Mapping of biome substring matches to icon textures
const BIOME_ICON_RULES := [
	{"match": "FOREST",       "path": "res://images/icons/forest.png"},
	{"match": "FOREST2",       "path": "res://images/icons/forest.png"},
	{"match": "HILL_FOREST", "path": "res://images/icons/hill_forest8.png"},
	{"match": "HILLS",        "path": "res://images/icons/hill.png"},
	{"match": "MOUNTAINS",    "path": "res://images/icons/mountain.png"},
]

static func get_biome_color(biome: String) -> Color:
	return Color.MAGENTA  # Debug color for missing biomes

static func get_icon_path_for_biome(biome_name: String) -> String:
	var biome_lower := biome_name.to_lower()

	# if biome_lower == "forest" or biome_lower == "forest2":
	# return get_random_forest_icon()

	for rule in BIOME_ICON_RULES:
		var needle := String(rule.get("match", "")).to_lower()
		if needle != "" and biome_lower == needle:
			return String(rule.get("path", ""))
	return ""

static func get_random_forest_icon() -> String:
	"""Get a random forest icon from forest4, forest5, forest6"""
	var forest_icons = [
		"res://images/icons/forest4.png",
		"res://images/icons/forest5.png", 
		"res://images/icons/forest6.png"
	]
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return forest_icons[rng.randi() % forest_icons.size()]
