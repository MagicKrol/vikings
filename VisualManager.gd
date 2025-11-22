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
var _ready_highlight_regions: Dictionary = {}
var _ready_highlight_player_id: int = -1
var _ready_highlights_suspended: bool = false
var _animated_highlight_regions: Dictionary = {}
var _highlight_cycle_anchor_time: float = -1.0
var _highlight_cycle_duration: float = 1.0

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
	var castle_scale := 0.18  # 0.15 * 0.8 = 0.12 (20% smaller)
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
			castle.position = center + Vector2(0 * map_size_scale, -20 * map_size_scale)  # Scaled offset
	
	castle.scale = Vector2(castle_scale, castle_scale)
	
	# Set z-index to appear above other elements
	castle.z_index = 151
	
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
	DebugLogger.log("Animation", "animate_region_highlight_on: " + str(region_id))
	if _region_highlight_tweens.has(region_id):
		animate_region_highlight_off(region_id)
	var overlay_setup: Dictionary = _ensure_region_highlight_overlay(region_id)
	var overlay: Polygon2D = overlay_setup["overlay"] as Polygon2D
	_region_highlight_nodes[region_id] = overlay
	var original_color = overlay.color
	_region_highlight_original_colors[region_id] = original_color
	var was_neutral := bool(params.get("force_neutral", original_color.a <= 0.01))
	var owned_base_alpha: float
	var owned_target_alpha: float
	var neutral_base_alpha: float
	var neutral_target_alpha: float
	var hover_alpha_neutral: float
	var hover_alpha_owned: float
	var animated := bool(params.get("animated", true))
	if animated:
		owned_base_alpha = float(params.get("owned_base_alpha", GameParameters.REGION_ANIM_OWNED_ALPHA_FROM))
		owned_target_alpha = float(params.get("owned_target_alpha", GameParameters.REGION_ANIM_OWNED_ALPHA_TO))
		neutral_base_alpha = float(params.get("neutral_base_alpha", GameParameters.REGION_ANIM_NEUTRAL_ALPHA_FROM))
		neutral_target_alpha = float(params.get("neutral_target_alpha", GameParameters.REGION_ANIM_NEUTRAL_ALPHA_TO))
		hover_alpha_neutral = float(params.get("hover_alpha_neutral", GameParameters.REGION_MOVE_HOVER_NEUTRAL_ALPHA))
		hover_alpha_owned = float(params.get("hover_alpha_owned", GameParameters.REGION_MOVE_HOVER_OWNED_ALPHA))
	else:
		owned_base_alpha = float(params.get("owned_base_alpha", GameParameters.REGION_MAP_HOVER_OWNED_BASE_ALPHA))
		owned_target_alpha = float(params.get("owned_target_alpha", GameParameters.REGION_MAP_HOVER_OWNED_BASE_ALPHA))
		neutral_base_alpha = float(params.get("neutral_base_alpha", GameParameters.REGION_MAP_HOVER_NEUTRAL_BASE_ALPHA))
		neutral_target_alpha = float(params.get("neutral_target_alpha", GameParameters.REGION_MAP_HOVER_NEUTRAL_BASE_ALPHA))
		hover_alpha_neutral = float(params.get("hover_alpha_neutral", GameParameters.REGION_MAP_HOVER_NEUTRAL_HOVER_ALPHA))
		hover_alpha_owned = float(params.get("hover_alpha_owned", GameParameters.REGION_MAP_HOVER_OWNED_HOVER_ALPHA))
	var base_color: Color
	var target_color: Color
	if params.has("base_color") and params.has("target_color"):
		base_color = params["base_color"] as Color
		target_color = params["target_color"] as Color
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
	var duration := float(params.get("duration", 1.0))
	if animated:
		_animated_highlight_regions[region_id] = true
		_start_synced_highlight_tween(region_id, overlay, base_color, target_color, duration)
	else:
		if _animated_highlight_regions.has(region_id):
			_animated_highlight_regions.erase(region_id)
			_reset_highlight_anchor_if_needed()
		overlay.color = base_color
		if _region_highlight_tweens.has(region_id):
			var existing_tween = _region_highlight_tweens[region_id]
			if existing_tween:
				existing_tween.kill()
			_region_highlight_tweens.erase(region_id)

func animate_region_highlight_off(region_id: int) -> void:
	DebugLogger.log("Animation", "animate_region_highlight_off: " + str(region_id))
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
	if _animated_highlight_regions.has(region_id):
		_animated_highlight_regions.erase(region_id)
		_reset_highlight_anchor_if_needed()
	var overlay: Polygon2D = _region_highlight_nodes.get(region_id, null) as Polygon2D
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

func _start_synced_highlight_tween(region_id: int, overlay: Polygon2D, base_color: Color, target_color: Color, duration: float) -> void:
	var effective_duration: float = max(duration, 0.01)
	var phase := _get_highlight_phase(effective_duration)
	overlay.visible = true
	if phase <= 0.0001:
		overlay.color = base_color
		_begin_looping_highlight(region_id, overlay, base_color, target_color, effective_duration, false)
		return
	if phase < effective_duration:
		var progress: float = phase / effective_duration
		var current_color := base_color.lerp(target_color, progress)
		overlay.color = current_color
		var remaining_up: float = effective_duration - phase
		if remaining_up <= 0.0001:
			overlay.color = target_color
			_begin_looping_highlight(region_id, overlay, base_color, target_color, effective_duration, true)
			return
		var partial_up: Tween = overlay.create_tween()
		_region_highlight_tweens[region_id] = partial_up
		partial_up.tween_property(overlay, "color", target_color, remaining_up)
		partial_up.finished.connect(func() -> void:
			if not _animated_highlight_regions.has(region_id):
				return
			if _region_highlight_tweens.get(region_id) == partial_up:
				_region_highlight_tweens.erase(region_id)
			if not is_instance_valid(overlay):
				return
			_begin_looping_highlight(region_id, overlay, base_color, target_color, effective_duration, true)
		)
	else:
		var down_phase: float = phase - effective_duration
		var progress_down: float = down_phase / effective_duration
		var current_down_color := target_color.lerp(base_color, progress_down)
		overlay.color = current_down_color
		var remaining_down: float = effective_duration - down_phase
		if remaining_down <= 0.0001:
			overlay.color = base_color
			_begin_looping_highlight(region_id, overlay, base_color, target_color, effective_duration, false)
			return
		var partial_down: Tween = overlay.create_tween()
		_region_highlight_tweens[region_id] = partial_down
		partial_down.tween_property(overlay, "color", base_color, remaining_down)
		partial_down.finished.connect(func() -> void:
			if not _animated_highlight_regions.has(region_id):
				return
			if _region_highlight_tweens.get(region_id) == partial_down:
				_region_highlight_tweens.erase(region_id)
			if not is_instance_valid(overlay):
				return
			_begin_looping_highlight(region_id, overlay, base_color, target_color, effective_duration, false)
		)

func _get_highlight_phase(duration: float) -> float:
	if _highlight_cycle_anchor_time < 0.0 or abs(duration - _highlight_cycle_duration) > 0.001:
		_highlight_cycle_anchor_time = float(Time.get_ticks_msec()) / 1000.0
		_highlight_cycle_duration = duration
		return 0.0
	var elapsed: float = float(Time.get_ticks_msec()) / 1000.0 - _highlight_cycle_anchor_time
	var cycle: float = duration * 2.0
	if cycle <= 0.0:
		return 0.0
	return fmod(elapsed, cycle)

func _reset_highlight_anchor_if_needed() -> void:
	if _animated_highlight_regions.is_empty():
		_highlight_cycle_anchor_time = -1.0

func _begin_looping_highlight(region_id: int, overlay: Polygon2D, base_color: Color, target_color: Color, duration: float, start_from_target: bool) -> void:
	if not is_instance_valid(overlay):
		return
	var loop_tween: Tween = overlay.create_tween()
	loop_tween.set_loops()
	if start_from_target:
		loop_tween.tween_property(overlay, "color", base_color, duration)
		loop_tween.tween_property(overlay, "color", target_color, duration)
	else:
		loop_tween.tween_property(overlay, "color", target_color, duration)
		loop_tween.tween_property(overlay, "color", base_color, duration)
	_region_highlight_tweens[region_id] = loop_tween

func _resume_ready_highlights_if_needed() -> void:
	DebugLogger.log("Animation", "resume_ready_highlights_if_needed")
	if not _ready_highlights_suspended:
		return
	_ready_highlights_suspended = false
	if _ready_highlight_regions.is_empty():
		return
	for region_id in _ready_highlight_regions.keys():
		if _move_highlight_ids.has(region_id):
			continue
		if region_id == _map_hover_region_id:
			continue
		if region_id == _current_hover_region:
			continue
		animate_region_highlight_on(region_id)

func animate_move_region_highlights(region_ids: Array) -> void:
	DebugLogger.log("Animation", "animate_move_region_highlights: " + str(region_ids))
	clear_move_region_highlights()
	if region_ids.is_empty():
		_resume_ready_highlights_if_needed()
		return
	if _map_hover_region_id != -1 and region_ids.has(_map_hover_region_id):
		animate_region_highlight_off(_map_hover_region_id)
		_map_hover_region_id = -1
	if not _ready_highlight_regions.is_empty():
		for region_id in _ready_highlight_regions.keys():
			if _region_highlight_tweens.has(region_id):
				animate_region_highlight_off(region_id)
		_ready_highlights_suspended = true
	var params: Dictionary = {
		"owned_base_alpha": GameParameters.REGION_ANIM_OWNED_ALPHA_FROM,
		"owned_target_alpha": GameParameters.REGION_ANIM_OWNED_ALPHA_TO,
		"neutral_base_alpha": GameParameters.REGION_ANIM_NEUTRAL_ALPHA_FROM,
		"neutral_target_alpha": GameParameters.REGION_ANIM_NEUTRAL_ALPHA_TO,
		"hover_alpha_neutral": GameParameters.REGION_MOVE_HOVER_NEUTRAL_ALPHA,
		"hover_alpha_owned": GameParameters.REGION_MOVE_HOVER_OWNED_ALPHA
	}
	for region_id in region_ids:
		animate_region_highlight_on(region_id, params)
		DebugLogger.log("Animation", "Highlight region: " + str(region_id))
	_move_highlight_ids = region_ids.duplicate()

func clear_move_region_highlights() -> void:
	clear_move_region_hover()
	if _move_highlight_ids.is_empty():
		_resume_ready_highlights_if_needed()
		return
	var to_restore: Array = []
	for region_id in _move_highlight_ids:
		if _ready_highlight_regions.has(region_id):
			to_restore.append(region_id)
		animate_region_highlight_off(region_id)
		DebugLogger.log("Animation", "Unhighlight region: " + str(region_id))
	_move_highlight_ids.clear()
	if not _ready_highlights_suspended:
		for region_id in to_restore:
			animate_region_highlight_on(region_id)
			DebugLogger.log("Animation", "Highlight suspended region: " + str(region_id))
	_resume_ready_highlights_if_needed()

func clear_interaction_highlights() -> void:
	"""Clear all move targets and map-hover overlays (used when UI modals block interaction)."""
	clear_move_region_highlights()
	if _map_hover_region_id != -1:
		set_map_hover_region(-1)

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
	var overlay: Polygon2D = _region_highlight_nodes.get(region_id, null) as Polygon2D
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
	var hover_alpha := float(hover_alpha_data.get("neutral", GameParameters.REGION_MOVE_HOVER_NEUTRAL_ALPHA))
	if original_color.a > 0.01:
		hover_alpha = float(hover_alpha_data.get("owned", GameParameters.REGION_MOVE_HOVER_OWNED_ALPHA))
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
		overlay = _region_highlight_nodes[region_id] as Polygon2D
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
	var overlay: Polygon2D = _region_highlight_nodes.get(region_id, null) as Polygon2D
	if overlay == null:
		return
	if _region_highlight_hover_overlays.has(region_id):
		var hover_overlay = _region_highlight_hover_overlays[region_id]
		if hover_overlay and is_instance_valid(hover_overlay):
			hover_overlay.queue_free()
		_region_highlight_hover_overlays.erase(region_id)
	overlay.visible = true

func set_map_hover_region(region_id: int) -> void:
	DebugLogger.log("Animation", "set_map_hover_region: " + str(region_id))
	if region_id == _map_hover_region_id:
		return
	var previous_hover := _map_hover_region_id
	if _map_hover_region_id != -1:
		animate_region_highlight_off(_map_hover_region_id)
		_map_hover_region_id = -1
		if _ready_highlight_regions.has(previous_hover):
			animate_region_highlight_on(previous_hover)
	if region_id == -1:
		return
	if _move_highlight_ids.has(region_id):
		return
	animate_region_highlight_on(region_id, {"animated": false})
	_map_hover_region_id = region_id

func update_ready_army_highlights(player_id: int, region_ids: Array) -> void:
	DebugLogger.log("Animation", "update_ready_army_highlights: " + str(player_id) + ", " + str(region_ids))
	if player_id == -1:
		clear_ready_army_highlights()
		return
	if _ready_highlight_player_id != player_id:
		clear_ready_army_highlights()
		_ready_highlight_player_id = player_id
	var new_regions: Dictionary = {}
	var apply_visuals := not _ready_highlights_suspended
	for region_id in region_ids:
		new_regions[region_id] = true
		if apply_visuals and not _ready_highlight_regions.has(region_id) and not _move_highlight_ids.has(region_id) and region_id != _map_hover_region_id:
			animate_region_highlight_on(region_id)
	var existing_ids := _ready_highlight_regions.keys()
	for region_id in existing_ids:
		if not new_regions.has(region_id):
			_remove_region_highlight_if_unused(region_id)
	_ready_highlight_regions = new_regions

func clear_ready_army_highlights() -> void:
	if _ready_highlight_regions.is_empty():
		_ready_highlight_player_id = -1
		_ready_highlights_suspended = false
		return
	var existing_ids := _ready_highlight_regions.keys()
	for region_id in existing_ids:
		_remove_region_highlight_if_unused(region_id)
	_ready_highlight_regions.clear()
	_ready_highlight_player_id = -1
	_ready_highlights_suspended = false

func _remove_region_highlight_if_unused(region_id: int) -> void:
	if _move_highlight_ids.has(region_id):
		return
	if region_id == _map_hover_region_id:
		return
	if region_id == _current_hover_region:
		return
	animate_region_highlight_off(region_id)

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
