extends Node

# This script finds the first non-ocean region center from MapGenerator
# and positions Army1 there, scaled appropriately.

@onready var map_generator: MapGenerator = get_node_or_null("MapGenerator") as MapGenerator
@onready var army1: Sprite2D = get_node_or_null("Players/Player1/Armies/Army1") as Sprite2D

func _ready() -> void:
	# If MapGenerator already has data, try to place immediately; otherwise, defer a bit
	_call_deferred_placement()

func _call_deferred_placement() -> void:
	# Defer to next frame to ensure MapGenerator finished
	await get_tree().process_frame
	# Wait a few frames if regions not yet loaded
	var tries := 0
	while tries < 30 and (map_generator == null or map_generator.regions.is_empty()):
		await get_tree().process_frame
		tries += 1
	_place_army1_on_first_land_center()

func _place_army1_on_first_land_center() -> void:
	if map_generator == null or army1 == null:
		return
	# Iterate regions to find the first non-ocean with a valid center
	for region_data in map_generator.regions:
		var is_ocean := bool(region_data.get("ocean", false))
		if is_ocean:
			continue
		var center_data = region_data.get("center", [])
		if center_data.size() == 2:
			var center := Vector2(center_data[0], center_data[1])
			army1.position = center
			# Ensure consistent scale reduction (sprite already scaled to 0.2x in scene)
			return
