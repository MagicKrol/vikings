extends Control
class_name UIManager

# ============================================================================
# UI MANAGER
# ============================================================================
# 
# Purpose: Centralized UI state management and modal coordination
# 
# Core Responsibilities:
# - Modal state management and active modal tracking
# - Tooltip display coordination for region hover events
# - UI input handling and mouse interaction coordination
# - Modal visibility coordination and conflict resolution
# 
# Required Functions:
# - set_modal_active(): Control modal state and tooltip interactions
# - close_all_active_modals(): Centralized modal closure
# - handle_mouse_motion(): Region tooltip display management
# - coordinate_modal_display(): Manage modal conflicts and priorities
# 
# Integration Points:
# - All modal components: State coordination and conflict resolution
# - RegionTooltip: Hover state and display management
# - MapGenerator: Region interaction and coordinate conversion
# - Input system: Mouse event handling and processing
# ============================================================================

var region_tooltip: RegionTooltip
var battle_modal: BattleModal
var map_generator: MapGenerator
var last_hovered_region: Region = null

# Modal mode system
var is_modal_active: bool = false

# Modal references for centralized management
var _select_modal: SelectModal
var _army_select_modal: ArmySelectModal
var _region_select_modal: RegionSelectModal
var _region_modal: RegionModal
var _player_status_modal: PlayerStatusModal

func _ready():
	# Ensure UI is on top but doesn't block input
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow mouse events to pass through
	
	# Get references with correct paths
	# RegionTooltip is sibling under UI
	region_tooltip = get_parent().get_node("RegionTooltip") as RegionTooltip
	
	# BattleModal is sibling under UI
	battle_modal = get_parent().get_node("BattleModal") as BattleModal
	
	# Get modal references
	_select_modal = get_parent().get_node("SelectModal") as SelectModal
	_army_select_modal = get_parent().get_node("ArmySelectModal") as ArmySelectModal
	_region_select_modal = get_parent().get_node("RegionSelectModal") as RegionSelectModal
	_region_modal = get_parent().get_node("RegionModal") as RegionModal
	_player_status_modal = get_parent().get_node("PlayerStatusModal") as PlayerStatusModal
	
	# Map is under root (UI parent's parent)
	map_generator = get_parent().get_parent().get_node("Map") as MapGenerator
	

func set_modal_active(active: bool) -> void:
	"""Set the modal mode state"""
	is_modal_active = active
	if is_modal_active and region_tooltip and region_tooltip.visible:
		region_tooltip.hide_tooltip()

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
			

func _handle_mouse_motion(event: InputEventMouseMotion):
	"""Handle mouse movement to show/hide region tooltips"""
	if not region_tooltip or not map_generator:
		return
	
	# Don't show tooltips when any modal is active
	if is_modal_active:
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
	var camera := get_parent().get_parent().get_node("Camera2D") as Camera2D
	# Use camera's get_global_mouse_position for proper coordinate conversion
	var world_pos = camera.get_global_mouse_position()
	
	return world_pos

func _get_region_under_mouse(mouse_pos: Vector2) -> Region:
	"""Find the region under the mouse cursor"""
	if not map_generator:
		return null
	
	# Get the regions container
	var regions_node = map_generator.get_node("Regions")
	
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

func close_all_active_modals() -> void:
	"""Close any active modals"""
	if _select_modal and _select_modal.visible:
		_select_modal.hide_modal()
	if _army_select_modal and _army_select_modal.visible:
		_army_select_modal.hide_modal()
	if _region_select_modal and _region_select_modal.visible:
		_region_select_modal.hide_modal()
	if _region_modal and _region_modal.visible:
		_region_modal.hide_modal()
	if battle_modal and battle_modal.visible:
		battle_modal.hide_modal()

func is_any_modal_visible() -> bool:
	"""Check if any modal is currently visible"""
	var modals = [_select_modal, _army_select_modal, _region_select_modal, _region_modal, battle_modal]
	for modal in modals:
		if modal and modal.visible:
			return true
	return false

func get_player_status_modal() -> PlayerStatusModal:
	"""Get the PlayerStatusModal instance"""
	return _player_status_modal
