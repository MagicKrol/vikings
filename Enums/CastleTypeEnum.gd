extends RefCounted
class_name CastleTypeEnum

enum Type {
	NONE,      # No castle
	OUTPOST,   # Level 1 - Basic fortification
	KEEP,      # Level 2 - Small fortress
	CASTLE,    # Level 3 - Major fortification
	STRONGHOLD # Level 4 - Massive fortress
}

static func type_to_string(castle_type: Type) -> String:
	"""Convert castle type enum to string"""
	match castle_type:
		Type.NONE:
			return "None"
		Type.OUTPOST:
			return "Outpost"
		Type.KEEP:
			return "Keep"
		Type.CASTLE:
			return "Castle"
		Type.STRONGHOLD:
			return "Stronghold"
		_:
			return "Unknown"

static func string_to_type(type_string: String) -> Type:
	"""Convert string to castle type enum"""
	match type_string.to_lower():
		"none":
			return Type.NONE
		"outpost":
			return Type.OUTPOST
		"keep":
			return Type.KEEP
		"castle":
			return Type.CASTLE
		"stronghold":
			return Type.STRONGHOLD
		_:
			return Type.NONE  # Default fallback

static func get_all_types() -> Array[Type]:
	"""Get all available castle types (excluding NONE)"""
	return [Type.OUTPOST, Type.KEEP, Type.CASTLE, Type.STRONGHOLD]

static func get_description(castle_type: Type) -> String:
	"""Get description for each castle type"""
	match castle_type:
		Type.NONE:
			return "No fortification"
		Type.OUTPOST:
			return "Basic wooden fortification providing minimal defense"
		Type.KEEP:
			return "Small stone fortress with basic defensive capabilities"
		Type.CASTLE:
			return "Major fortification with strong walls and defensive structures"
		Type.STRONGHOLD:
			return "Massive fortress providing maximum defense and prestige"
		_:
			return "Unknown castle type"

static func get_next_level(castle_type: Type) -> Type:
	"""Get the next castle level, or NONE if already at maximum"""
	match castle_type:
		Type.NONE:
			return Type.OUTPOST
		Type.OUTPOST:
			return Type.KEEP
		Type.KEEP:
			return Type.CASTLE
		Type.CASTLE:
			return Type.STRONGHOLD
		Type.STRONGHOLD:
			return Type.NONE  # Already at maximum
		_:
			return Type.NONE

static func can_upgrade(castle_type: Type) -> bool:
	"""Check if castle can be upgraded to next level"""
	return get_next_level(castle_type) != Type.NONE

static func get_icon_path(castle_type: Type) -> String:
	"""Get icon file path for castle type"""
	match castle_type:
		Type.OUTPOST:
			return "res://images/icons/outpost.png"
		Type.KEEP:
			return "res://images/icons/keep.png"
		Type.CASTLE:
			return "res://images/icons/castle.png"
		Type.STRONGHOLD:
			return "res://images/icons/stronghold.png"
		_:
			return "" # No icon for NONE or unknown types