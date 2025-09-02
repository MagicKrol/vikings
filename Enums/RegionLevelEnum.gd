extends RefCounted
class_name RegionLevelEnum

enum Level {
	L1,
	L2, 
	L3,
	L4,
	L5
}

static func level_to_string(level: Level) -> String:
	"""Convert region level enum to string"""
	match level:
		Level.L1:
			return "Shire"
		Level.L2:
			return "County"
		Level.L3:
			return "March"
		Level.L4:
			return "Duchy"
		Level.L5:
			return "Province"
		_:
			return "Unknown"

static func string_to_level(level_string: String) -> Level:
	"""Convert string to region level enum"""
	match level_string.to_lower():
		"shire":
			return Level.L1
		"county":
			return Level.L2
		"march":
			return Level.L3
		"duchy":
			return Level.L4
		"province":
			return Level.L5
		_:
			return Level.L1  # Default fallback

static func get_all_levels() -> Array[Level]:
	"""Get all available region levels"""
	return [Level.L1, Level.L2, Level.L3, Level.L4, Level.L5]

static func get_level_description(level: Level) -> String:
	"""Get description for each level"""
	match level:
		Level.L1:
			return "A frontier territory on the border"
		Level.L2:
			return "A basic administrative region"
		Level.L3:
			return "A rural administrative division"
		Level.L4:
			return "A substantial territorial division"
		Level.L5:
			return "A large noble domain"
		_:
			return "Unknown region level"