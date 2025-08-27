extends RefCounted
class_name ResourceComposition

# Dictionary that maps ResourcesEnum.Type -> int (amount)
var resources: Dictionary = {}

func _init():
	# Initialize with zero resources of each type
	for resource_type in ResourcesEnum.get_all_types():
		resources[resource_type] = 0

# Set the amount for a specific resource type
func set_resource_amount(resource_type: ResourcesEnum.Type, amount: int) -> void:
	resources[resource_type] = max(0, amount)  # Ensure non-negative

# Get the amount for a specific resource type
func get_resource_amount(resource_type: ResourcesEnum.Type) -> int:
	return resources.get(resource_type, 0)

# Add resources of a specific type
func add_resources(resource_type: ResourcesEnum.Type, amount: int) -> void:
	resources[resource_type] = resources.get(resource_type, 0) + amount

# Remove resources of a specific type
func remove_resources(resource_type: ResourcesEnum.Type, amount: int) -> void:
	var current_amount = resources.get(resource_type, 0)
	resources[resource_type] = max(0, current_amount - amount)

# Get total resource value (simple sum of all resources)
func get_total_resources() -> int:
	var total = 0
	for resource_type in resources:
		total += resources[resource_type]
	return total

# Check if region has any resources
func has_resources() -> bool:
	return get_total_resources() > 0

# Get resource composition as a readable string
func get_composition_string() -> String:
	var parts: Array[String] = []
	for resource_type in ResourcesEnum.get_all_types():
		var amount = get_resource_amount(resource_type)
		var name = ResourcesEnum.type_to_string(resource_type)
		parts.append(name + ": " + str(amount))
	
	return "\n".join(parts)

# Get resource composition as a dictionary for serialization
func to_dictionary() -> Dictionary:
	var result = {}
	for resource_type in resources:
		var type_name = ResourcesEnum.type_to_string(resource_type)
		result[type_name] = resources[resource_type]
	return result

# Load resource composition from a dictionary
func from_dictionary(data: Dictionary) -> void:
	resources.clear()
	
	# Initialize with zeros
	for resource_type in ResourcesEnum.get_all_types():
		resources[resource_type] = 0
	
	# Load from dictionary
	for key in data:
		var resource_type = ResourcesEnum.string_to_type(key)
		resources[resource_type] = int(data[key])

# Copy composition from another ResourceComposition
func copy_from(other: ResourceComposition) -> void:
	resources.clear()
	for resource_type in other.resources:
		resources[resource_type] = other.resources[resource_type]

# Create a copy of this composition
func duplicate() -> ResourceComposition:
	var copy = ResourceComposition.new()
	copy.copy_from(self)
	return copy

# Merge another resource composition into this one
func merge_with(other: ResourceComposition) -> void:
	for resource_type in other.resources:
		add_resources(resource_type, other.resources[resource_type])

# Check if resource composition is empty
func is_empty() -> bool:
	return get_total_resources() == 0

# Get all resources as a dictionary (ResourcesEnum.Type -> amount)
func get_all_resources() -> Dictionary:
	return resources.duplicate()