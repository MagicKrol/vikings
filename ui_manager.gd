extends Control
class_name UIManager

var region_tooltip: RegionTooltip
var battle_modal: BattleModal
var map_generator: MapGenerator
var last_hovered_region: Region = null

func _ready():
	# Ensure UI is on top but doesn't block input
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow mouse events to pass through
	
	# Get references with correct paths
	# RegionTooltip is sibling under UI
	region_tooltip = get_parent().get_node_or_null("RegionTooltip") as RegionTooltip
	
	# BattleModal is sibling under UI
	battle_modal = get_parent().get_node_or_null("BattleModal") as BattleModal
	
	# Map is under root (UI parent's parent)
	map_generator = get_parent().get_parent().get_node_or_null("Map") as MapGenerator
	
	if region_tooltip == null:
		print("[UIManager] Error: RegionTooltip not found")
	if battle_modal == null:
		print("[UIManager] Error: BattleModal not found")
	if map_generator == null:
		print("[UIManager] Error: MapGenerator not found")

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
			

func _handle_mouse_motion(event: InputEventMouseMotion):
	"""Handle mouse movement to show/hide region tooltips"""
	if not region_tooltip or not map_generator:
		return
	
	# Don't show tooltips when BattleModal is visible
	if battle_modal and battle_modal.visible:
		if region_tooltip.visible:
			region_tooltip.hide_tooltip()
		return
	
	# Convert mouse position to world coordinates using same method as click manager
	var world_pos = _convert_screen_to_world_pos(event.global_position)
	
	# Find region under mouse
	var hovered_region = _get_region_under_mouse(world_pos)
	
	if hovered_region != last_hovered_region:
		if hovered_region:
			# Show tooltip for new region
			region_tooltip.show_region_tooltip(hovered_region, event.position)
		else:
			# Hide tooltip when not over any region
			region_tooltip.hide_tooltip()
		
		last_hovered_region = hovered_region
	elif hovered_region and region_tooltip.visible:
		# Update tooltip position if still hovering same region
		region_tooltip.update_position(event.position)

func _convert_screen_to_world_pos(screen_pos: Vector2) -> Vector2:
	"""Convert screen coordinates to world coordinates using same method as click manager"""
	# Get the camera and convert screen to world coordinates properly
	var camera := get_parent().get_parent().get_node_or_null("Camera2D") as Camera2D
	var world_pos: Vector2
	if camera != null:
		# Use camera's get_global_mouse_position for proper coordinate conversion
		world_pos = camera.get_global_mouse_position()
	else:
		# Fallback to manual conversion if no camera found
		world_pos = get_viewport().canvas_transform.affine_inverse() * screen_pos
	
	return world_pos

func _get_region_under_mouse(mouse_pos: Vector2) -> Region:
	"""Find the region under the mouse cursor"""
	if not map_generator:
		return null
	
	# Get the regions container
	var regions_node = map_generator.get_node_or_null("Regions")
	if not regions_node:

		return null
	
	# Check each region container
	for child in regions_node.get_children():
		if child is Region:
			var region = child as Region
			if not region.is_ocean_region():
				if _is_point_in_region(mouse_pos, region):
					return region
	
	return null

func _is_point_in_region(point: Vector2, region: Region) -> bool:
	"""Check if a point is inside a region's polygon"""
	# Get the polygon from the region
	var polygon_node = region.get_node_or_null("Polygon") as Polygon2D
	if not polygon_node:

		return false
	
	# Check if polygon has valid points
	if polygon_node.polygon.size() < 3:
		return false
	
	# Convert point to local coordinates relative to the polygon
	var local_point = polygon_node.to_local(point)
	
	# Use Godot's built-in point-in-polygon test
	var is_inside = Geometry2D.is_point_in_polygon(local_point, polygon_node.polygon)
	

	
	return is_inside
