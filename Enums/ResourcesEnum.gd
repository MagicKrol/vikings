extends RefCounted
class_name ResourcesEnum

# Resource types for player economy
enum Type {
	GOLD,
	FOOD,
	WOOD,
	IRON,
	STONE
}

# Human-readable names for each resource type
const RESOURCE_NAMES = {
	Type.GOLD: "Gold",
	Type.FOOD: "Food",
	Type.WOOD: "Wood",
	Type.IRON: "Iron",
	Type.STONE: "Stone"
}

# Resource icons (optional, for UI display)
const RESOURCE_ICONS = {
	Type.GOLD: "res://images/icons/gold.png",
	Type.FOOD: "res://images/icons/food.png", 
	Type.WOOD: "res://images/icons/wood.png",
	Type.IRON: "res://images/icons/iron.png",
	Type.STONE: "res://images/icons/stone.png"
}

# Starting resources now managed in GameParameters.gd

# Convert enum type to string name
static func type_to_string(resource_type: Type) -> String:
	return RESOURCE_NAMES.get(resource_type, "Unknown")

# Convert string name to enum type
static func string_to_type(resource_name: String) -> Type:
	for type in RESOURCE_NAMES:
		if RESOURCE_NAMES[type].to_lower() == resource_name.to_lower():
			return type
	return Type.GOLD  # Default to gold for unknown types

# Get all resource types as an array
static func get_all_types() -> Array[Type]:
	return [Type.GOLD, Type.FOOD, Type.WOOD, Type.IRON, Type.STONE]

# Get starting amount for a resource type
static func get_starting_amount(resource_type: Type) -> int:
	return GameParameters.get_starting_resource_amount(resource_type)

# Get icon path for a resource type
static func get_icon_path(resource_type: Type) -> String:
	return RESOURCE_ICONS.get(resource_type, "")

# Format resource amount for display (with commas for large numbers)
static func format_amount(amount: int) -> String:
	if amount < 1000:
		return str(amount)
	elif amount < 1000000:
		return str(amount / 1000) + "K"
	else:
		return str(amount / 1000000) + "M"