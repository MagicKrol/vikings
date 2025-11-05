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
var _region_highlight_tweens: Dictionary = {}
var _region_highlight_original_colors: Dictionary = {}
var _region_highlight_base_colors: Dictionary = {}
var _region_highlight_target_colors: Dictionary = {}
var _region_highlight_hover_overlays: Dictionary = {}
var _region_highlight_nodes: Dictionary = {}
var _region_highlight_temp_nodes: Dictionary = {}
var _region_highlight_hover_alphas: Dictionary = {}
var _current_hover_region: int = -1
var _move_highlight_ids: Array = []
var _map_hover_region_id: int = -1

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

func animate_region_highlight_on(region_id: int, params: Dictionary = {}) -> void:
	if _region_highlight_tweens.has(region_id):
		animate_region_highlight_off(region_id)
	var overlay_setup: Dictionary = _ensure_region_highlight_overlay(region_id)
	var overlay: Polygon2D = overlay_setup["overlay"]
	_region_highlight_nodes[region_id] = overlay
	var original_color = overlay.color
	_region_highlight_original_colors[region_id] = original_color
	var was_neutral: bool = params.get("force_neutral", original_color.a <= 0.01)
	var owned_base_alpha: float
	var owned_target_alpha: float
	var neutral_base_alpha: float
	var neutral_target_alpha: float
	var hover_alpha_neutral: float
	var hover_alpha_owned: float
	var animated_param = params.get("animated", true)
	var animated: bool = true
	if animated_param is bool:
		animated = animated_param
	else:
		animated = bool(animated_param)
	if animated:
		owned_base_alpha = params.get("owned_base_alpha", GameParameters.REGION_ANIM_OWNED_ALPHA_FROM)
		owned_target_alpha = params.get("owned_target_alpha", GameParameters.REGION_ANIM_OWNED_ALPHA_TO)
		neutral_base_alpha = params.get("neutral_base_alpha", GameParameters.REGION_ANIM_NEUTRAL_ALPHA_FROM)
		neutral_target_alpha = params.get("neutral_target_alpha", GameParameters.REGION_ANIM_NEUTRAL_ALPHA_TO)
		hover_alpha_neutral = params.get("hover_alpha_neutral", GameParameters.REGION_MOVE_HOVER_NEUTRAL_ALPHA)
		hover_alpha_owned = params.get("hover_alpha_owned", GameParameters.REGION_MOVE_HOVER_OWNED_ALPHA)
	else:
		owned_base_alpha = params.get("owned_base_alpha", GameParameters.REGION_MAP_HOVER_OWNED_BASE_ALPHA)
		owned_target_alpha = params.get("owned_target_alpha", GameParameters.REGION_MAP_HOVER_OWNED_BASE_ALPHA)
		neutral_base_alpha = params.get("neutral_base_alpha", GameParameters.REGION_MAP_HOVER_NEUTRAL_BASE_ALPHA)
		neutral_target_alpha = params.get("neutral_target_alpha", GameParameters.REGION_MAP_HOVER_NEUTRAL_BASE_ALPHA)
		hover_alpha_neutral = params.get("hover_alpha_neutral", GameParameters.REGION_MAP_HOVER_NEUTRAL_HOVER_ALPHA)
		hover_alpha_owned = params.get("hover_alpha_owned", GameParameters.REGION_MAP_HOVER_OWNED_HOVER_ALPHA)
	var base_color: Color
	var target_color: Color
	if params.has("base_color") and params.has("target_color"):
		base_color = params["base_color"]
		target_color = params["target_color"]
	else:
		if was_neutral:
			base_color = Color(original_color.r, original_color.g, original_color.b, neutral_base_alpha)
			target_color = Color(original_color.r, original_color.g, original_color.b, neutral_target_alpha)
		else:
			base_color = Color(original_color.r, original_color.g, original_color.b, owned_base_alpha)
			target_color = Color(original_color.r, original_color.g, original_color.b, owned_target_alpha)
	_region_highlight_base_colors[region_id] = base_color
	_region_highlight_target_colors[region_id] = target_color
	_region_highlight_hover_alphas[region_id] = {
		"neutral": hover_alpha_neutral,
		"owned": hover_alpha_owned
	}
	overlay.color = base_color
	var duration: float = params.get("duration", 1.0)
	if animated:
		var tween = overlay.create_tween()
		tween.set_loops()
		tween.tween_property(overlay, "color", target_color, duration)
		tween.tween_property(overlay, "color", base_color, duration)
		_region_highlight_tweens[region_id] = tween
	else:
		if _region_highlight_tweens.has(region_id):
			var existing_tween = _region_highlight_tweens[region_id]
			if existing_tween:
				existing_tween.kill()
			_region_highlight_tweens.erase(region_id)

func animate_region_highlight_off(region_id: int) -> void:
	if _region_highlight_tweens.has(region_id):
		var tween = _region_highlight_tweens[region_id]
		if tween:
			tween.kill()
		_region_highlight_tweens.erase(region_id)
	if _region_highlight_hover_overlays.has(region_id):
		var hover_overlay = _region_highlight_hover_overlays[region_id]
		if hover_overlay and is_instance_valid(hover_overlay):
			hover_overlay.queue_free()
		_region_highlight_hover_overlays.erase(region_id)
	var overlay: Polygon2D = _region_highlight_nodes.get(region_id, null)
	if overlay and is_instance_valid(overlay):
		overlay.visible = true
		if _region_highlight_original_colors.has(region_id):
			overlay.color = _region_highlight_original_colors[region_id]
		if _region_highlight_temp_nodes.has(region_id):
			overlay.queue_free()
			_region_highlight_temp_nodes.erase(region_id)
	_region_highlight_original_colors.erase(region_id)
	_region_highlight_base_colors.erase(region_id)
	_region_highlight_target_colors.erase(region_id)
	_region_highlight_nodes.erase(region_id)
	_region_highlight_hover_alphas.erase(region_id)
	if _current_hover_region == region_id:
		_current_hover_region = -1
	if _map_hover_region_id == region_id:
		_map_hover_region_id = -1

func animate_move_region_highlights(region_ids: Array) -> void:
	clear_move_region_highlights()
	if region_ids.is_empty():
		return
	if _map_hover_region_id != -1 and region_ids.has(_map_hover_region_id):
		animate_region_highlight_off(_map_hover_region_id)
		_map_hover_region_id = -1
	for region_id in region_ids:
		animate_region_highlight_on(region_id)
	_move_highlight_ids = region_ids.duplicate()

func clear_move_region_highlights() -> void:
	clear_move_region_hover()
	for region_id in _move_highlight_ids:
		animate_region_highlight_off(region_id)
	_move_highlight_ids.clear()

func has_move_region_highlights() -> bool:
	return not _move_highlight_ids.is_empty()

func get_move_region_highlight_ids() -> Array:
	return _move_highlight_ids.duplicate()

func set_move_region_hover(region_id: int) -> void:
	set_region_highlight_hover(region_id)

func set_region_highlight_hover(region_id: int) -> void:
	if region_id == _current_hover_region:
		return
	if _current_hover_region != -1:
		_clear_region_highlight_hover(_current_hover_region)
	if region_id == -1:
		return
	if not _region_highlight_original_colors.has(region_id):
		return
	var overlay: Polygon2D = _region_highlight_nodes.get(region_id, null)
	if overlay == null:
		return
	overlay.visible = false
	var original_color = _region_highlight_original_colors[region_id]
	var hover_overlay = Polygon2D.new()
	hover_overlay.name = "RegionHighlightHover"
	hover_overlay.polygon = overlay.polygon
	hover_overlay.position = overlay.position
	hover_overlay.rotation = overlay.rotation
	hover_overlay.scale = overlay.scale
	var hover_alpha_data: Dictionary = _region_highlight_hover_alphas.get(region_id, {
		"neutral": GameParameters.REGION_MOVE_HOVER_NEUTRAL_ALPHA,
		"owned": GameParameters.REGION_MOVE_HOVER_OWNED_ALPHA
	})
	var hover_alpha: float = hover_alpha_data["neutral"]
	if original_color.a > 0.01:
		hover_alpha = hover_alpha_data["owned"]
	hover_overlay.color = Color(original_color.r, original_color.g, original_color.b, hover_alpha)
	hover_overlay.z_index = overlay.z_index
	var parent = overlay.get_parent()
	if parent:
		parent.add_child(hover_overlay)
	_region_highlight_hover_overlays[region_id] = hover_overlay
	_current_hover_region = region_id

func clear_region_highlight_state(region_id: int) -> void:
	var overlay: Polygon2D = null
	if _region_highlight_nodes.has(region_id):
		overlay = _region_highlight_nodes[region_id]
	else:
		var region_container = _map_generator.get_region_container_by_id(region_id)
		if region_container != null and region_container.has_node("OwnershipOverlay"):
			overlay = region_container.get_node("OwnershipOverlay") as Polygon2D
	if _region_highlight_tweens.has(region_id):
		var tween = _region_highlight_tweens[region_id]
		if tween:
			tween.kill()
		_region_highlight_tweens.erase(region_id)
	if _region_highlight_hover_overlays.has(region_id):
		var hover_overlay = _region_highlight_hover_overlays[region_id]
		if hover_overlay and is_instance_valid(hover_overlay):
			hover_overlay.queue_free()
		_region_highlight_hover_overlays.erase(region_id)
	if overlay:
		overlay.visible = true
	_region_highlight_original_colors.erase(region_id)
	_region_highlight_base_colors.erase(region_id)
	_region_highlight_target_colors.erase(region_id)
	_region_highlight_hover_alphas.erase(region_id)
	_region_highlight_nodes.erase(region_id)
	_region_highlight_temp_nodes.erase(region_id)
	_move_highlight_ids.erase(region_id)
	if _current_hover_region == region_id:
		_current_hover_region = -1
	if _map_hover_region_id == region_id:
		_map_hover_region_id = -1

func clear_move_region_hover() -> void:
	clear_region_highlight_hover()

func clear_region_highlight_hover() -> void:
	if _current_hover_region == -1:
		return
	_clear_region_highlight_hover(_current_hover_region)
	_current_hover_region = -1

func _clear_region_highlight_hover(region_id: int) -> void:
	if not _region_highlight_original_colors.has(region_id):
		return
	var overlay: Polygon2D = _region_highlight_nodes.get(region_id, null)
	if overlay == null:
		return
	if _region_highlight_hover_overlays.has(region_id):
		var hover_overlay = _region_highlight_hover_overlays[region_id]
		if hover_overlay and is_instance_valid(hover_overlay):
			hover_overlay.queue_free()
		_region_highlight_hover_overlays.erase(region_id)
	overlay.visible = true

func set_map_hover_region(region_id: int) -> void:
	if region_id == _map_hover_region_id:
		return
	if _map_hover_region_id != -1:
		animate_region_highlight_off(_map_hover_region_id)
		_map_hover_region_id = -1
	if region_id == -1:
		return
	if _move_highlight_ids.has(region_id):
		return
	animate_region_highlight_on(region_id, {"animated": false})
	_map_hover_region_id = region_id

func _ensure_region_highlight_overlay(region_id: int) -> Dictionary:
	var region_container = _map_generator.get_region_container_by_id(region_id)
	var base_polygon = region_container.get_node("Polygon") as Polygon2D
	var overlay: Polygon2D
	var created_temp := false
	if region_container.has_node("OwnershipOverlay"):
		overlay = region_container.get_node("OwnershipOverlay") as Polygon2D
	else:
		overlay = _create_neutral_highlight_overlay(region_container, base_polygon)
		created_temp = true
	overlay.position = base_polygon.position
	overlay.rotation = base_polygon.rotation
	overlay.scale = base_polygon.scale
	_region_highlight_nodes[region_id] = overlay
	if created_temp:
		_region_highlight_temp_nodes[region_id] = true
	else:
		_region_highlight_temp_nodes.erase(region_id)
	return {
		"overlay": overlay,
		"temporary": created_temp
	}

func _create_neutral_highlight_overlay(region_container: Node, base_polygon: Polygon2D) -> Polygon2D:
	var overlay := Polygon2D.new()
	overlay.name = "OwnershipOverlay"
	overlay.polygon = base_polygon.polygon
	overlay.position = base_polygon.position
	overlay.rotation = base_polygon.rotation
	overlay.scale = base_polygon.scale
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.z_index = base_polygon.z_index + 1
	region_container.add_child(overlay)
	return overlay
