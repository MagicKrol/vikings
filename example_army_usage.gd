# Example script showing how to use the new army composition system
# This file is for reference only - you can delete it after understanding the usage

extends RefCounted

func example_usage():
	# Create a new army composition
	var army_comp = ArmyComposition.new()
	
	# Add soldiers using enum types
	army_comp.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, 12)
	army_comp.set_soldier_count(SoldierTypeEnum.Type.ARCHERS, 34)
	army_comp.set_soldier_count(SoldierTypeEnum.Type.KNIGHTS, 2)
	
	# Get information about the army
	print("Army composition: ", army_comp.get_composition_string())
	# Output: "12 Peasants, 34 Archers, 2 Knights"
	
	print("Total soldiers: ", army_comp.get_total_soldiers())
	# Output: 48
	
	print("Total attack power: ", army_comp.get_total_attack())
	# Output: 54 (12*1 + 34*2 + 2*4)
	
	print("Total defense: ", army_comp.get_total_defense())
	# Output: 52 (12*1 + 34*1 + 2*3)
	
	# Modify army composition
	army_comp.add_soldiers(SoldierTypeEnum.Type.KNIGHTS, 3)
	army_comp.remove_soldiers(SoldierTypeEnum.Type.PEASANTS, 5)
	
	print("Updated composition: ", army_comp.get_composition_string())
	# Output: "7 Peasants, 34 Archers, 5 Knights"
	
	# Convert to dictionary for saving/loading
	var save_data = army_comp.to_dictionary()
	print("Save data: ", save_data)
	# Output: {"Peasants": 7, "Archers": 34, "Knights": 5}
	
	# Load from dictionary
	var new_army = ArmyComposition.new()
	new_army.from_dictionary(save_data)
	print("Loaded army: ", new_army.get_composition_string())
	
func example_army_usage():
	# Get an army (from army manager or click manager)
	var _army: Army # This would be a real army instance
	
	# Access army composition
	# var composition = army.get_composition()
	# print("Army has: ", army.get_army_composition_string())
	# print("Army strength: ", army.get_army_strength())
	# print("Knight count: ", army.get_soldier_count(SoldierTypeEnum.Type.KNIGHTS))
	
	# Modify army
	# army.add_soldiers(SoldierTypeEnum.Type.PEASANTS, 5)
	# army.remove_soldiers(SoldierTypeEnum.Type.ARCHERS, 2)

func example_region_usage():
	# Get a region
	var _region: Region # This would be a real region instance
	
	# Access region garrison
	# var garrison = region.get_garrison()
	# print("Garrison: ", garrison.get_composition_string())
	# print("Has garrison: ", region.has_garrison())
	# print("Garrison strength: ", region.get_garrison_strength())
	
	# Modify garrison
	# region.add_soldiers_to_garrison(SoldierTypeEnum.Type.ARCHERS, 10)
	# region.remove_soldiers_from_garrison(SoldierTypeEnum.Type.PEASANTS, 3)
