extends RefCounted

class_name RegionManager

# Region ownership: region_id -> player_id
var region_ownership: Dictionary = {}

# Castle starting positions: player_id -> region_id
var castle_starting_positions: Dictionary = {}

# Reference to the region graph for neighbor lookups
var region_graph: Dictionary = {}

# Reference to the map generator for region data
var map_generator: MapGenerator

# Reference to the game manager for settings
var game_manager: GameManager = null

# Region name management
var available_names: Array[String] = []
var used_names: Dictionary = {}

func _init(map_gen: MapGenerator):
	map_generator = map_gen
	_load_region_names()
	_build_region_graph()

func set_game_manager(gm: GameManager) -> void:
	"""Set the GameManager reference for accessing settings"""
	game_manager = gm

func _load_region_names() -> void:
	"""Load region names from regions.json file"""
	var file = FileAccess.open("res://regions.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.data
			if data is Array:
				for name in data:
					if name is String:
						available_names.append(name)
	
		else:
			print("[RegionManager] Error parsing regions.json")

func assign_region_name(region: Region) -> String:
	"""Assign a random name to a region"""
	if available_names.is_empty():
		return "Unknown_" + str(region.get_region_id())
	
	# Get available names that haven't been used
	var unused_names = []
	for name in available_names:
		if not used_names.has(name):
			unused_names.append(name)
	
	if unused_names.is_empty():
		# If all names are used, use region ID
		return "Region_" + str(region.get_region_id())
	else:
		# Pick a random unused name
		var random_index = randi() % unused_names.size()
		var chosen_name = unused_names[random_index]
		used_names[chosen_name] = true
		return chosen_name

func _build_region_graph() -> void:
	"""Build the region adjacency graph using the existing RegionGraph class"""
	if map_generator == null:
		return
	
	var Graph := load("res://region_graph.gd")
	if Graph != null:
		region_graph = Graph.build_non_ocean_adjacency(map_generator.regions, map_generator.edges)

func get_neighbor_regions(region_id: int) -> Array[int]:
	"""Get all neighboring regions for a given region ID"""
	if region_graph.has(region_id):
		var neighbors = region_graph[region_id]
		# Convert to Array[int] if needed
		var result: Array[int] = []
		for neighbor in neighbors:
			result.append(int(neighbor))
		return result
	return []

func set_region_ownership(region_id: int, player_id: int) -> void:
	"""Set ownership of a region to a specific player"""
	region_ownership[region_id] = player_id
	
	# Show region point or borders based on GameManager setting
	if _should_use_region_points():
		# Show the region point to indicate ownership
		_show_region_point_for_ownership(region_id, player_id)
	else:
		# Use colored borders instead - trigger border recalculation
		if map_generator and map_generator.has_method("regenerate_borders_for_region"):
			map_generator.regenerate_borders_for_region(region_id)
		elif map_generator and map_generator.has_method("regenerate_borders"):
			# Fallback to full regeneration
			map_generator.regenerate_borders()

func get_region_owner(region_id: int) -> int:
	"""Get the player ID that owns a region, or -1 if unowned"""
	return region_ownership.get(region_id, -1)

func set_castle_starting_position(region_id: int, player_id: int) -> void:
	"""Set a castle starting position for a player and claim the region"""
	# Check if region is already owned
	if get_region_owner(region_id) != -1:

		return
	
	# Set the castle starting position
	castle_starting_positions[player_id] = region_id
	
	# Claim the starting region
	set_region_ownership(region_id, player_id)
	
	# Claim neighboring regions (expansion)
	var neighbors = get_neighbor_regions(region_id)
	for neighbor_id in neighbors:
		if get_region_owner(neighbor_id) == -1:  # Only claim unowned regions
			set_region_ownership(neighbor_id, player_id)
	
	

func get_castle_starting_position(player_id: int) -> int:
	"""Get the region ID where a player's castle is located, or -1 if not set"""
	return castle_starting_positions.get(player_id, -1)

func is_region_owned(region_id: int) -> bool:
	"""Check if a region is owned by any player"""
	return get_region_owner(region_id) != -1

func get_player_regions(player_id: int) -> Array[int]:
	"""Get all regions owned by a specific player"""
	var player_regions: Array[int] = []
	for region_id in region_ownership.keys():
		if region_ownership[region_id] == player_id:
			player_regions.append(region_id)
	return player_regions

func update_region_visuals() -> void:
	"""Update the visual appearance of regions based on ownership"""
	# This function is intentionally empty - no polygon tinting
	pass

func _show_region_point_for_ownership(region_id: int, player_id: int) -> void:
	"""Show region point for a newly owned region"""
	if map_generator == null:
		return
	
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		return
	
	# Find the region container using the map generator's helper
	var region_container = map_generator.get_region_container_by_id(region_id)
	if region_container == null:
		return
	
	# Check if region point already exists
	var region_point = region_container.get_node_or_null("RegionPoint")
	if region_point != null:
		# Update color based on player
		RegionPoints.update_inner_color(region_point, _get_player_color(player_id))
		# Check visibility based on buildings and armies
		_update_region_point_visibility(region_container)
		return
	
	# Create new region point if it doesn't exist
	var polygon = region_container.get_node_or_null("Polygon") as Polygon2D
	if polygon == null:
		return
	
	var center_meta = polygon.get_meta("center")
	if center_meta == null:
		return
	
	var center = center_meta as Vector2
	var scale = 1.0
	if map_generator != null:
		scale = map_generator.polygon_scale
	
	var new_region_point = RegionPoints.create_region_point(center, scale, _get_player_color(player_id))
	new_region_point.name = "RegionPoint"
	region_container.add_child(new_region_point)
	
	# Check visibility based on buildings and armies
	_update_region_point_visibility(region_container)
	
	

func _update_region_point_visibility(region_container: Node) -> void:
	"""Update region point visibility based on buildings and armies in the region"""
	var region_point = region_container.get_node_or_null("RegionPoint")
	if region_point == null:
		return
	
	# Check for buildings (castles) - permanently hide if present
	var castle = region_container.get_node_or_null("Castle")
	if castle != null:
		region_point.visible = false
		return
	
	# Check for armies - hide if present
	for child in region_container.get_children():
		if child is Army:
			region_point.visible = false
			return
	
	# No buildings or armies, show the region point
	region_point.visible = true

func hide_region_point_for_army(region_container: Node) -> void:
	"""Hide region point when army enters a region"""
	_update_region_point_visibility(region_container)

func show_region_point_for_army_exit(region_container: Node) -> void:
	"""Show region point when army leaves a region"""
	var region_point = region_container.get_node_or_null("RegionPoint")
	if region_point == null:
		return
	
	# Check for buildings (castles) - permanently hide if present
	var castle = region_container.get_node_or_null("Castle")
	if castle != null:
		region_point.visible = false
		return
	
	# No castle present, show the region point
	region_point.visible = true

func _should_use_region_points() -> bool:
	"""Check if we should use region points based on GameManager setting"""
	if game_manager != null:
		return not game_manager.USE_COLORED_BORDERS
	# Default to region points if GameManager not found
	return true

func _get_player_color(player_id: int) -> Color:
	"""Get the color for a specific player"""
	var player_colors = {
		1: Color.RED,
		2: Color.from_string("#61727a", Color.BLUE),  # Custom blue-gray
		3: Color.GREEN,
		4: Color.YELLOW
	}
	return player_colors.get(player_id, Color.WHITE)
