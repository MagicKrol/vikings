extends Node

# This script finds the first non-ocean region center from MapGenerator
# and creates the initial army there using proper Roman numeral naming.

@onready var map_generator: MapGenerator = get_node("Map") as MapGenerator

func _ready() -> void:
	# Place army after map generation completes
	map_generator.map_generated.connect(_on_map_generated)
	# If map already built, proceed immediately
	if not map_generator.regions.is_empty():
		_on_map_generated()

func _on_map_generated() -> void:
	_create_initial_army()

func _create_initial_army() -> void:
	if map_generator == null:
		return
	
	# Find the first non-ocean region
	var target_region_container = null
	for region_data in map_generator.regions:
		var is_ocean := bool(region_data.get("ocean", false))
		if is_ocean:
			continue
		
		# Get the region ID to find the corresponding region container
		var region_id = region_data.get("id", -1)
		if region_id > 0:
			var regions_node = map_generator.get_node_or_null("Regions")
			if regions_node != null:
				target_region_container = regions_node.get_node_or_null("Region" + str(region_id))
				if target_region_container != null:
					break
	
	if target_region_container == null:
		DebugLogger.log("GameInit", "No suitable region found for initial army")
		return
	
	# Get army manager from ClickManager
	var click_manager = get_node("ClickManager")
	if not click_manager.has_method("get_army_manager"):
		DebugLogger.log("GameInit", "Cannot find army manager")
		return
	
	var army_manager = click_manager.get_army_manager()
	if army_manager == null:
		DebugLogger.log("GameInit", "Army manager is null")
		return
	
	DebugLogger.log("GameInit", "Army manager found, armies_by_player: " + str(army_manager.armies_by_player))
	
	# Create the initial army using proper Roman numeral naming
	DebugLogger.log("GameInit", "Creating initial army in region: " + target_region_container.name)
	var new_army = army_manager.create_army(target_region_container, 1)
	
	if new_army != null:
		DebugLogger.log("GameInit", "Successfully created initial army: " + new_army.name)
	else:
		DebugLogger.log("GameInit", "Failed to create initial army")
