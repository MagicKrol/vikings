extends RefCounted
class_name ArmyComposition

# Dictionary that maps SoldierTypeEnum.Type -> int (count)
var soldiers: Dictionary = {}

func _init():
	# Initialize with zero soldiers of each type
	for soldier_type in SoldierTypeEnum.get_all_types():
		soldiers[soldier_type] = 0

# Set the count for a specific soldier type
func set_soldier_count(soldier_type: SoldierTypeEnum.Type, count: int) -> void:
	soldiers[soldier_type] = max(0, count)  # Ensure non-negative

# Get the count for a specific soldier type
func get_soldier_count(soldier_type: SoldierTypeEnum.Type) -> int:
	return soldiers.get(soldier_type, 0)

# Add soldiers of a specific type
func add_soldiers(soldier_type: SoldierTypeEnum.Type, count: int) -> void:
	soldiers[soldier_type] = soldiers.get(soldier_type, 0) + count

# Remove soldiers of a specific type
func remove_soldiers(soldier_type: SoldierTypeEnum.Type, count: int) -> void:
	var current_count = soldiers.get(soldier_type, 0)
	soldiers[soldier_type] = max(0, current_count - count)

# Get total soldier count across all types
func get_total_soldiers() -> int:
	var total = 0
	for soldier_type in soldiers:
		total += soldiers[soldier_type]
	return total

# Check if army has any soldiers
func has_soldiers() -> bool:
	return get_total_soldiers() > 0

# Get army composition as a readable string
func get_composition_string() -> String:
	var parts: Array[String] = []
	for soldier_type in SoldierTypeEnum.get_all_types():
		var count = get_soldier_count(soldier_type)
		var name = SoldierTypeEnum.type_to_string(soldier_type)
		parts.append(name + ": " + str(count))
	
	return "\n".join(parts)

# Get army composition as a dictionary for serialization
func to_dictionary() -> Dictionary:
	var result = {}
	for soldier_type in soldiers:
		var type_name = SoldierTypeEnum.type_to_string(soldier_type)
		result[type_name] = soldiers[soldier_type]
	return result

# Load army composition from a dictionary
func from_dictionary(data: Dictionary) -> void:
	soldiers.clear()
	
	# Initialize with zeros
	for soldier_type in SoldierTypeEnum.get_all_types():
		soldiers[soldier_type] = 0
	
	# Load from dictionary
	for key in data:
		var soldier_type = SoldierTypeEnum.string_to_type(key)
		soldiers[soldier_type] = int(data[key])

# Calculate total army strength (attack power)
func get_total_attack() -> int:
	var total_attack = 0
	for soldier_type in soldiers:
		var count = soldiers[soldier_type]
		var attack = SoldierTypeEnum.get_attack(soldier_type)
		total_attack += count * attack
	return total_attack

# Calculate total army defense
func get_total_defense() -> int:
	var total_defense = 0
	for soldier_type in soldiers:
		var count = soldiers[soldier_type]
		var defense = SoldierTypeEnum.get_defense(soldier_type)
		total_defense += count * defense
	return total_defense

# Calculate total recruitment cost
func get_total_cost() -> int:
	var total_cost = 0
	for soldier_type in soldiers:
		var count = soldiers[soldier_type]
		var cost = SoldierTypeEnum.get_cost(soldier_type)
		total_cost += count * cost
	return total_cost

# Copy composition from another ArmyComposition
func copy_from(other: ArmyComposition) -> void:
	soldiers.clear()
	for soldier_type in other.soldiers:
		soldiers[soldier_type] = other.soldiers[soldier_type]

# Create a copy of this composition
func duplicate() -> ArmyComposition:
	var copy = ArmyComposition.new()
	copy.copy_from(self)
	return copy

# Merge another army composition into this one
func merge_with(other: ArmyComposition) -> void:
	for soldier_type in other.soldiers:
		add_soldiers(soldier_type, other.soldiers[soldier_type])

# Check if army composition is empty
func is_empty() -> bool:
	return get_total_soldiers() == 0

# Calculate total food cost per turn for this army composition
func get_total_food_cost() -> float:
	var total_food_cost = 0.0
	for soldier_type in soldiers:
		var count = soldiers[soldier_type]
		if count > 0:
			var unit_food_cost = GameParameters.get_unit_food_cost(soldier_type)
			total_food_cost += count * unit_food_cost
	return total_food_cost
