extends RefCounted
class_name UnitTraitEnum

# Generic unit trait constants - names can be changed without changing const names
enum Type {
	UNIT_TRAIT_1,   # long_spears
	UNIT_TRAIT_2,   # ranged
	UNIT_TRAIT_3,   # mobility
	UNIT_TRAIT_4,   # flanker
	UNIT_TRAIT_5,   # charge
	UNIT_TRAIT_6,   # multi_attack
	UNIT_TRAIT_7,   # armor_piercing
	UNIT_TRAIT_8,   # no_armor
	UNIT_TRAIT_9,   # light_armor
	UNIT_TRAIT_10,  # medium_armor
	UNIT_TRAIT_11   # heavy_armor
}

# Map generic trait constants to actual trait names from traits.txt
const TRAIT_NAMES = {
	Type.UNIT_TRAIT_1: "long_spears",
	Type.UNIT_TRAIT_2: "ranged",
	Type.UNIT_TRAIT_3: "mobility", 
	Type.UNIT_TRAIT_4: "flanker",
	Type.UNIT_TRAIT_5: "charge",
	Type.UNIT_TRAIT_6: "multi_attack",
	Type.UNIT_TRAIT_7: "armor_piercing",
	Type.UNIT_TRAIT_8: "no_armor",
	Type.UNIT_TRAIT_9: "light_armor",
	Type.UNIT_TRAIT_10: "medium_armor",
	Type.UNIT_TRAIT_11: "heavy_armor"
}

# Human-readable display names for each trait
const TRAIT_DISPLAY_NAMES = {
	Type.UNIT_TRAIT_1: "Long-spears",
	Type.UNIT_TRAIT_2: "Ranged",
	Type.UNIT_TRAIT_3: "Mobility", 
	Type.UNIT_TRAIT_4: "Flanker",
	Type.UNIT_TRAIT_5: "Charge",
	Type.UNIT_TRAIT_6: "Multi attack",
	Type.UNIT_TRAIT_7: "Armor Piercing",
	Type.UNIT_TRAIT_8: "No armor",
	Type.UNIT_TRAIT_9: "Light armor",
	Type.UNIT_TRAIT_10: "Medium armor",
	Type.UNIT_TRAIT_11: "Heavy armor"
}

# Descriptions for each trait (from traits.txt)
const TRAIT_DESCRIPTIONS = {
	Type.UNIT_TRAIT_1: "Effective against cavalry with long spear formations",
	Type.UNIT_TRAIT_2: "Can attack from range",
	Type.UNIT_TRAIT_3: "Enhanced movement capabilities",
	Type.UNIT_TRAIT_4: "Can flank enemy formations",
	Type.UNIT_TRAIT_5: "Devastating charge attacks",
	Type.UNIT_TRAIT_6: "Can perform multiple attacks",
	Type.UNIT_TRAIT_7: "Can pierce through armor",
	Type.UNIT_TRAIT_8: "No armor protection",
	Type.UNIT_TRAIT_9: "Light armor protection",
	Type.UNIT_TRAIT_10: "Medium armor protection",
	Type.UNIT_TRAIT_11: "Heavy armor protection"
}

# Convert enum type to internal trait name
static func type_to_string(trait_type: Type) -> String:
	return TRAIT_NAMES.get(trait_type, "unknown")

# Convert enum type to display name
static func type_to_display_name(trait_type: Type) -> String:
	return TRAIT_DISPLAY_NAMES.get(trait_type, "Unknown")

# Convert string name to enum type
static func string_to_type(trait_name: String) -> Type:
	for type in TRAIT_NAMES:
		if TRAIT_NAMES[type].to_lower() == trait_name.to_lower():
			return type
	return Type.UNIT_TRAIT_1  # Default fallback

# Get trait description
static func get_description(trait_type: Type) -> String:
	return TRAIT_DESCRIPTIONS.get(trait_type, "No description available")

# Get all trait types as an array
static func get_all_types() -> Array[Type]:
	return [
		Type.UNIT_TRAIT_1,
		Type.UNIT_TRAIT_2,
		Type.UNIT_TRAIT_3,
		Type.UNIT_TRAIT_4,
		Type.UNIT_TRAIT_5,
		Type.UNIT_TRAIT_6,
		Type.UNIT_TRAIT_7,
		Type.UNIT_TRAIT_8,
		Type.UNIT_TRAIT_9,
		Type.UNIT_TRAIT_10,
		Type.UNIT_TRAIT_11
	]