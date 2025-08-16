extends RefCounted
class_name SoldierTypeEnum

# Soldier types for army composition
enum Type {
	PEASANTS,
	ARCHERS,
	KNIGHTS,
	# Easy to add more types here in the future
}

# Human-readable names for each soldier type
const SOLDIER_NAMES = {
	Type.PEASANTS: "Peasants",
	Type.ARCHERS: "Archers",
	Type.KNIGHTS: "Knights",
}

# Combat stats for each soldier type
const SOLDIER_STATS = {
	Type.PEASANTS: {
		"attack": 1,
		"defense": 1,
		"cost": 1,
		"recruitment_time": 1
	},
	Type.ARCHERS: {
		"attack": 2,
		"defense": 1,
		"cost": 2,
		"recruitment_time": 2
	},
	Type.KNIGHTS: {
		"attack": 4,
		"defense": 3,
		"cost": 5,
		"recruitment_time": 3
	}
}

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
	return [Type.PEASANTS, Type.ARCHERS, Type.KNIGHTS]

# Get soldier stats for a specific type
static func get_soldier_stats(soldier_type: Type) -> Dictionary:
	return SOLDIER_STATS.get(soldier_type, {})

# Get attack value for a soldier type
static func get_attack(soldier_type: Type) -> int:
	return SOLDIER_STATS.get(soldier_type, {}).get("attack", 1)

# Get defense value for a soldier type
static func get_defense(soldier_type: Type) -> int:
	return SOLDIER_STATS.get(soldier_type, {}).get("defense", 1)

# Get recruitment cost for a soldier type
static func get_cost(soldier_type: Type) -> int:
	return SOLDIER_STATS.get(soldier_type, {}).get("cost", 1)

# Get recruitment time for a soldier type
static func get_recruitment_time(soldier_type: Type) -> int:
	return SOLDIER_STATS.get(soldier_type, {}).get("recruitment_time", 1)
