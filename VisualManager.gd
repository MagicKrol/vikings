extends RefCounted
class_name VisualManager

# ============================================================================
# VISUAL MANAGER
# ============================================================================
# 
# Purpose: Centralized visual creation and update system
# 
# Core Responsibilities:
# - Castle visual creation and placement on map
# - Army visual creation and positioning  
# - Map visual updates and coordination
# - Visual scaling and positioning calculations
# 
# Required Functions:
# - place_castle_visual(): Create castle sprites on regions based on castle type
# - update_castle_visual(): Update castle visual when castle type changes
# - remove_castle_visual(): Remove castle visual from region
# - place_army_visual(): Create army visuals via ArmyManager
# - update_region_visuals(): Coordinate map visual updates
# 
# Integration Points:
# - MapGenerator: Access to map scale and positioning data
# - RegionManager: Visual update coordination
# - ArmyManager: Army visual creation delegation
# - Region: Visual placement on region containers
# ============================================================================

# Manager references
var _map_generator: MapGenerator
var _region_manager: RegionManager
var _army_manager: ArmyManager
var _move_highlight_tweens: Dictionary = {}
var _move_highlight_original_colors: Dictionary = {}
var _move_highlight_base_colors: Dictionary = {}
var _move_highlight_target_colors: Dictionary = {}
var _move_highlight_hover_overlays: Dictionary = {}
var _current_hover_region: int = -1

func _init(map_generator: MapGenerator, region_manager: RegionManager, army_manager: ArmyManager):
	_map_generator = map_generator
	_region_manager = region_manager
	_army_manager = army_manager

func place_castle_visual(region_container: Node) -> void:
	"""Place a castle visual sprite on the specified region using the region's castle type"""
	# Get the region to determine castle type
	var region = region_container as Region
	if region == null:
		DebugLogger.log("UISystem", "Error: region_container is not a Region")
		return
	
	# Get castle type from region
	var castle_type = region.get_castle_type()
	if castle_type == CastleTypeEnum.Type.NONE:
		DebugLogger.log("UISystem", "Warning: Trying to place visual for no castle in " + region.get_region_name())
		return
	
	# Remove any existing castle immediately
	var existing_castle = region_container.get_node_or_null("Castle")
	if existing_castle != null:
		region_container.remove_child(existing_castle)
		existing_castle.queue_free()
		DebugLogger.log("UISystem", "Removed existing castle visual from " + region.get_region_name())
	
	# Get the appropriate icon path for this castle type
	var icon_path = CastleTypeEnum.get_icon_path(castle_type)
	if icon_path.is_empty():
		DebugLogger.log("UISystem", "Error: No icon path for castle type " + str(castle_type))
		return
	
	# Create castle sprite
	var castle := Sprite2D.new()
	castle.name = "Castle"
	castle.texture = load(icon_path)
	if castle.texture == null:
		DebugLogger.log("UISystem", "Error: Could not load castle texture from " + icon_path)
		return
	
	# Scale castle appropriately - 20% smaller than biome icons
	var castle_scale := 0.12  # 0.15 * 0.8 = 0.12 (20% smaller)
	var map_size_scale := 1.0
	if _map_generator != null:
		# Apply both polygon scale and map size scale
		map_size_scale = Utils.get_map_size_icon_scale(_map_generator.map_size)
		castle_scale = castle_scale * _map_generator.polygon_scale * map_size_scale
	
	# Position castle at region center (moved left and up by 5px, scaled)
	var polygon := region_container.get_node_or_null("Polygon") as Polygon2D
	if polygon != null:
		var center_meta = polygon.get_meta("center")
		if center_meta != null:
			var center := center_meta as Vector2
			castle.position = center + Vector2(-5 * map_size_scale, -5 * map_size_scale)  # Scaled offset
	
	castle.scale = Vector2(castle_scale, castle_scale)
	
	# Set z-index to appear above other elements
	castle.z_index = 100
	
	# Add castle to region container
	region_container.add_child(castle)
	
	DebugLogger.log("UISystem", "Placed " + CastleTypeEnum.type_to_string(castle_type) + " visual in " + region.get_region_name())

func place_army_visual(region_container: Node, player_id: int) -> void:
	"""Place an army visual in the specified region using ArmyManager"""
	if _army_manager != null:
		_army_manager.create_army(region_container, player_id)
	else:
		DebugLogger.log("UISystem", "Error: ArmyManager not available")

func update_region_visuals() -> void:
	"""Update the visual appearance of regions based on ownership"""
	if _region_manager != null:
		_region_manager.update_region_visuals()
	else:
		DebugLogger.log("UISystem", "Error: RegionManager not available")

func update_castle_visual(region_container: Node) -> void:
	"""Update castle visual when castle type changes (e.g., upgrade completion)"""
	# Simply replace the castle visual with the new one
	place_castle_visual(region_container)

func remove_castle_visual(region_container: Node) -> void:
	"""Remove castle visual from region"""
	var existing_castle = region_container.get_node_or_null("Castle")
	if existing_castle != null:
		region_container.remove_child(existing_castle)
		existing_castle.queue_free()
		DebugLogger.log("UISystem", "Removed castle visual from region")

func animate_move_region_highlights(region_ids: Array) -> void:
	clear_move_region_highlights()
	if region_ids.is_empty():
		return
	for region_id in region_ids:
		var overlay = _get_ownership_overlay(region_id)
		if overlay == null:
			continue
		var original_color = overlay.color
		_move_highlight_original_colors[region_id] = original_color
		var base_color = Color(original_color.r, original_color.g, original_color.b, 0.5)
		var highlight_color = Color(original_color.r, original_color.g, original_color.b, 0.75)
		_move_highlight_base_colors[region_id] = base_color
		_move_highlight_target_colors[region_id] = highlight_color
		overlay.color = base_color
		_start_move_highlight_tween(region_id, overlay, base_color, highlight_color)

func clear_move_region_highlights() -> void:
	clear_move_region_hover()
	for region_id in _move_highlight_tweens.keys():
		var tween = _move_highlight_tweens[region_id]
		if tween:
			tween.kill()
	_move_highlight_tweens.clear()
	_current_hover_region = -1
	for region_id in _move_highlight_original_colors.keys():
		var overlay = _get_ownership_overlay(region_id)
		if overlay:
			overlay.color = _move_highlight_original_colors[region_id]
	_move_highlight_original_colors.clear()
	_move_highlight_base_colors.clear()
	_move_highlight_target_colors.clear()
	for region_id in _move_highlight_hover_overlays.keys():
		var hover_overlay = _move_highlight_hover_overlays[region_id]
		if hover_overlay and is_instance_valid(hover_overlay):
			hover_overlay.queue_free()
	_move_highlight_hover_overlays.clear()

func _get_ownership_overlay(region_id: int) -> Polygon2D:
	var region_container = _map_generator.get_region_container_by_id(region_id)
	if region_container == null:
		return null
	return region_container.get_node_or_null("OwnershipOverlay") as Polygon2D

func has_move_region_highlights() -> bool:
	return not _move_highlight_original_colors.is_empty()

func get_move_region_highlight_ids() -> Array:
	return _move_highlight_original_colors.keys()

func set_move_region_hover(region_id: int) -> void:
	if region_id == _current_hover_region:
		return
	if _current_hover_region != -1:
		_clear_move_region_hover(_current_hover_region)
	if region_id == -1:
		return
	if not _move_highlight_original_colors.has(region_id):
		return
	var overlay = _get_ownership_overlay(region_id)
	if overlay == null:
		return
	overlay.visible = false
	var original_color = _move_highlight_original_colors[region_id]
	var hover_overlay = Polygon2D.new()
	hover_overlay.name = "MoveHighlightHover"
	hover_overlay.polygon = overlay.polygon
	hover_overlay.position = overlay.position
	hover_overlay.rotation = overlay.rotation
	hover_overlay.scale = overlay.scale
	hover_overlay.color = Color(original_color.r, original_color.g, original_color.b, 0.85)
	hover_overlay.z_index = overlay.z_index
	var parent = overlay.get_parent()
	if parent:
		parent.add_child(hover_overlay)
	_move_highlight_hover_overlays[region_id] = hover_overlay
	_current_hover_region = region_id

func clear_move_region_hover() -> void:
	if _current_hover_region == -1:
		return
	_clear_move_region_hover(_current_hover_region)
	_current_hover_region = -1

func _clear_move_region_hover(region_id: int) -> void:
	if not _move_highlight_original_colors.has(region_id):
		return
	var overlay = _get_ownership_overlay(region_id)
	if overlay == null:
		return
	if _move_highlight_hover_overlays.has(region_id):
		var hover_overlay = _move_highlight_hover_overlays[region_id]
		if hover_overlay and is_instance_valid(hover_overlay):
			hover_overlay.queue_free()
		_move_highlight_hover_overlays.erase(region_id)
	overlay.visible = true

func _start_move_highlight_tween(region_id: int, overlay: Polygon2D, base_color: Color, highlight_color: Color) -> void:
	var tween = overlay.create_tween()
	tween.set_loops()
	tween.tween_property(overlay, "color", highlight_color, 1.0)
	tween.tween_property(overlay, "color", base_color, 1.0)
	_move_highlight_tweens[region_id] = tween
