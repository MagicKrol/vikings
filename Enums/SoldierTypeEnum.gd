extends RefCounted
class_name SoldierTypeEnum

# Soldier types for army composition
enum Type {
	PEASANTS,
	SPEARMEN,
	SWORDSMEN,
	ARCHERS,
	CROSSBOWMEN,
	HORSEMEN,
	KNIGHTS,
	MOUNTED_KNIGHTS,
	ROYAL_GUARD,
	# Easy to add more types here in the future
}

# Human-readable names for each soldier type
const SOLDIER_NAMES = {
	Type.PEASANTS: "Peasants",
	Type.SPEARMEN: "Spearmen",
	Type.SWORDSMEN: "Swordsmen",
	Type.ARCHERS: "Archers",
	Type.CROSSBOWMEN: "Crossbowmen",
	Type.HORSEMEN: "Horsemen",
	Type.KNIGHTS: "Knights",
	Type.MOUNTED_KNIGHTS: "Mounted Knights",
	Type.ROYAL_GUARD: "Royal Guard",
}

# Combat stats for each soldier type
# Unit stats now managed in GameParameters.gd

# Convert enum type to string name
static func type_to_string(soldier_type: Type) -> String:
	return SOLDIER_NAMES.get(soldier_type, "Unknown")

# Convert string name to enum type
static func string_to_type(soldier_name: String) -> Type:
	for type in SOLDIER_NAMES:
		if SOLDIER_NAMES[type].to_lower() == soldier_name.to_lower():
			return type
	return Type.PEASANTS  # Default to peasants for unknown types

# Get all soldier types as an array
static func get_all_types() -> Array[Type]:
	return [
		Type.PEASANTS,
		Type.SPEARMEN,
		Type.SWORDSMEN,
		Type.ARCHERS,
		Type.CROSSBOWMEN,
		Type.HORSEMEN,
		Type.KNIGHTS,
		Type.MOUNTED_KNIGHTS,
		Type.ROYAL_GUARD
	]

# Get soldier stats for a specific type
static func get_soldier_stats(soldier_type: Type) -> Dictionary:
	return GameParameters.UNIT_STATS.get(soldier_type, {})

# Get attack value for a soldier type
static func get_attack(soldier_type: Type) -> int:
	return GameParameters.get_unit_stat(soldier_type, "attack")

# Get defense value for a soldier type
static func get_defense(soldier_type: Type) -> int:
	return GameParameters.get_unit_stat(soldier_type, "defense")

# Get recruitment cost for a soldier type
static func get_cost(soldier_type: Type) -> int:
	return GameParameters.get_unit_stat(soldier_type, "cost")

# Get recruitment time for a soldier type
static func get_recruitment_time(soldier_type: Type) -> int:
	return GameParameters.get_unit_stat(soldier_type, "recruitment_time")

# Get all traits for a soldier type
static func get_traits(soldier_type: Type) -> Array:
	return GameParameters.get_unit_traits(soldier_type)

# Check if a soldier type has a specific trait
static func has_trait(soldier_type: Type, trait_type) -> bool:
	return GameParameters.unit_has_trait(soldier_type, trait_type)

# Get trait names as strings for display
static func get_trait_names(soldier_type: Type) -> Array[String]:
	var trait_names: Array[String] = []
	var traits = get_traits(soldier_type)
	
	for unit_trait in traits:
		trait_names.append(UnitTraitEnum.type_to_display_name(unit_trait))
	
	return trait_names
