extends Node
class_name ClickManager

# ============================================================================
# CLICK MANAGER
# ============================================================================
# 
# Purpose: Focused input handling and click event coordination
# 
# Core Responsibilities:
# - Mouse input event processing and coordinate conversion
# - Region hit detection and polygon intersection testing
# - Click event delegation to appropriate game systems
# - Basic input validation and region accessibility checks
# 
# Required Functions:
# - _unhandled_input(): Process mouse and keyboard input events
# - _on_left_click(): Coordinate conversion and region detection
# - _handle_region_click(): Delegate clicks to GameManager or other systems
# - _point_in_polygon(): Geometric intersection testing
# 
# Integration Points:
# - GameManager: High-level game flow coordination and state management
# - UIManager: Modal state checking and UI interaction coordination  
# - Region: Basic region data access and mountain checking
# - Input system: Godot input event processing
# ============================================================================



func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			DebugLogger.log("click", "ClickManager: left click at " + str(event.position))
			if _is_ui_click(event.position, event.global_position):
				DebugLogger.log("click", "ClickManager: UI click detected, ignoring map click")
				return
			_on_left_click(event.global_position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click_button_event(event)
	elif event is InputEventMouseMotion:
		_handle_right_click_motion(event)
		_handle_mouse_motion()
	elif event is InputEventKey and event.pressed:
		# Editor quick-ownership mode: number keys 1..6 select owner, ESC cancels
		if _game_manager and _game_manager.enable_map_editor:
			var code: int = event.keycode
			if code >= KEY_1 and code <= KEY_6:
				_editor_ownership_mode = true
				_editor_owner_id = code - KEY_1 + 1
				return
			if code == KEY_ESCAPE:
				_editor_ownership_mode = false
				# fallthrough to any deselection below
		if event.keycode == KEY_ESCAPE:
			_ui_manager.handle_escape_action()

# Core system references
@onready var _map_script: MapGenerator = get_node("../Map") as MapGenerator
@onready var _ui_manager: UIManager = get_node("../UI/UIManager") as UIManager
@onready var _info_modal: InfoModal = get_node("../UI/InfoModal") as InfoModal
@onready var _move_modal: MoveModal = get_node("../UI/MoveModal") as MoveModal
@onready var _game_manager: GameManager = get_node("../GameManager") as GameManager

# Legacy manager references for backward compatibility during transition
@onready var _region_manager: RegionManager
@onready var _army_manager: ArmyManager
@onready var _move_tooltip: MoveTooltip = get_node("../UI/MoveTooltip") as MoveTooltip
var _tutorial_manager: TutorialManager

# Editor quick-ownership mode state
var _editor_ownership_mode: bool = false
var _editor_owner_id: int = 0
var _right_click_down: bool = false
var _right_click_dragging: bool = false
var _right_click_start_position: Vector2 = Vector2.ZERO
const RIGHT_CLICK_DRAG_THRESHOLD: float = 8.0

func _ready():
	# Managers will be provided by GameManager via set_managers()
	pass

func set_managers(region_manager: RegionManager, army_manager: ArmyManager) -> void:
	"""Set manager references from GameManager"""
	_region_manager = region_manager
	_army_manager = army_manager

func set_tutorial_manager(manager: TutorialManager) -> void:
	_tutorial_manager = manager

func get_region_manager() -> RegionManager:
	"""Get the RegionManager instance"""
	return _region_manager

func get_army_manager() -> ArmyManager:
	"""Get the ArmyManager instance"""
	return _army_manager

# Minimal state for input handling (game state now managed by GameManager)


func _handle_right_click_button_event(event: InputEventMouseButton) -> void:
	if GameParameters.get_army_move_trigger() != GameParameters.ArmyMoveTrigger.RIGHT_CLICK:
		return
	if event.pressed:
		_right_click_down = true
		_right_click_dragging = false
		_right_click_start_position = event.position
		return
	if not _right_click_down:
		return
	_right_click_down = false
	if _right_click_dragging:
		return
	if _is_ui_click(event.position, event.global_position):
		return
	_on_right_click(event.global_position)

func _handle_right_click_motion(event: InputEventMouseMotion) -> void:
	if not _right_click_down:
		return
	if _right_click_dragging:
		return
	if event.position.distance_to(_right_click_start_position) >= RIGHT_CLICK_DRAG_THRESHOLD:
		_right_click_dragging = true

func _on_left_click(screen_pos: Vector2) -> void:
	_on_map_click(screen_pos, MOUSE_BUTTON_LEFT)

func _on_right_click(screen_pos: Vector2) -> void:
	_on_map_click(screen_pos, MOUSE_BUTTON_RIGHT)

func _on_map_click(screen_pos: Vector2, button_index: int) -> void:
	if _is_ui_click(screen_pos, screen_pos):
		DebugLogger.log("click", "ClickManager: UI click detected in _on_left_click")
		return
	# Check if any modal is active and close them first, but allow move flow to proceed
	if _ui_manager and _ui_manager.is_modal_active:
		if _ui_manager.has_blocking_modal():
			return
		var move_flow_active := _is_move_flow_active()
		if not move_flow_active:
			if _ui_manager.is_any_modal_visible():
				if not _ui_manager.is_only_info_modal_visible():
					if _tutorial_manager != null and _tutorial_manager.is_ui_step_active():
						return
					if not (_tutorial_manager != null and _tutorial_manager.is_waiting_for_region()):
						DebugLogger.log("InputSystem", "Modal is active, attempting to close modals")
						DebugLogger.log("click", "ClickManager: closing modals due to active modal and non-move flow")
						# Don't close modals if BattleModal is in battle mode (battle_in_progress)
						var battle_modal = get_node("../UI/BattleModal") as BattleModal
						if battle_modal and battle_modal.visible and battle_modal.battle_in_progress:
							# Battle is active - don't allow closing the modal
							DebugLogger.log("InputSystem", "Battle is active, not closing modal")
							return
						_ui_manager.close_all_active_modals()
						DebugLogger.log("InputSystem", "Closed all active modals, returning")
						return
			else:
				_ui_manager.set_modal_active(false)
		else:
			_ui_manager.set_modal_active(false)
			_ui_manager.set_overlay_suppressed(true)
	
	# Get the camera and convert screen to world coordinates properly
	var camera := get_node("../Camera2D") as Camera2D
	# Use camera's get_global_mouse_position for proper coordinate conversion
	var world_pos = camera.get_global_mouse_position()
		
	# Search within Map/regions for Region containers
	var map_root := get_node("../Map") as Node
	
	
	var map_children = []
	for child in map_root.get_children():
		map_children.append(child.name)
	
	var regions_node := map_root.get_node("Regions") as Node
	
	var region_clicked = false
	
	# Iterate regions and test polygon hit (handles land and hidden ocean polygons)
	for region_container in regions_node.get_children():
		if not (region_container is Node):
			continue
		var hit := false
		for child in region_container.get_children():
			if child is Polygon2D:
				if _point_in_polygon(world_pos, child as Polygon2D):
					hit = true
					break
		if hit:
			_handle_region_click(region_container, button_index)
			region_clicked = true
			break

	# In editor mode, allow clicking ocean polygons (from Map/Ocean)
	if not region_clicked and _game_manager and _game_manager.enable_map_editor:
		var ocean_node := map_root.get_node("Ocean") as Node
		for ocean_pg in ocean_node.get_children():
			if ocean_pg is Polygon2D:
				if _point_in_polygon(world_pos, ocean_pg as Polygon2D):
					var rid := int(ocean_pg.get_meta("region_id"))
					var ocean_region_container := _map_script.get_region_container_by_id(rid)
					_handle_editor_region_click(ocean_region_container)
					region_clicked = true
					break

	# If no region was clicked and we have a selected army, deselect it (cancels move)
	if not region_clicked and _army_manager and _army_manager.selected_army != null:
		var move_trigger_right: bool = GameParameters.get_army_move_trigger() == GameParameters.ArmyMoveTrigger.RIGHT_CLICK
		if not (move_trigger_right and button_index == MOUSE_BUTTON_RIGHT):
			_army_manager.deselect_army()

func _point_in_polygon(p: Vector2, polygon: Polygon2D) -> bool:
	# Convert world position into polygon local space and use Geometry2D
	var local := polygon.to_local(p)
	return Geometry2D.is_point_in_polygon(local, polygon.polygon)

func _is_ui_click(screen_pos: Vector2, global_pos: Vector2) -> bool:
	var hovered_control = get_viewport().gui_get_hovered_control()
	if hovered_control != null:
		DebugLogger.log("click", "ClickManager: hovered_control=" + str(hovered_control.get_path()))
		if hovered_control == _info_modal or _info_modal.is_ancestor_of(hovered_control):
			DebugLogger.log("click", "ClickManager: hovered control inside InfoModal")
			return true
		if hovered_control == _move_modal or _move_modal.is_ancestor_of(hovered_control):
			DebugLogger.log("click", "ClickManager: hovered control inside MoveModal")
			return true
	if _info_modal and _info_modal.visible:
		if _is_point_in_control(_info_modal, screen_pos) or _is_point_in_control(_info_modal, global_pos):
			DebugLogger.log("click", "ClickManager: point inside InfoModal via transform")
			return true
		if hovered_control == null:
			DebugLogger.log("click", "ClickManager: no hovered control, screen_pos=" + str(screen_pos) + " global_pos=" + str(global_pos) + " info_rect=" + str(_info_modal.get_global_rect()))
	if _move_modal and _move_modal.visible:
		if _is_point_in_control(_move_modal, screen_pos) or _is_point_in_control(_move_modal, global_pos):
			DebugLogger.log("click", "ClickManager: point inside MoveModal via transform")
			return true
	return false

func _is_point_in_control(control: Control, screen_pos: Vector2) -> bool:
	var xform := control.get_global_transform_with_canvas()
	var local_pos := xform.affine_inverse() * screen_pos
	var rect := Rect2(Vector2.ZERO, control.size)
	return rect.has_point(local_pos)

func _handle_region_click(region_container: Node, button_index: int) -> void:
	# Optional guard: check if in map editor mode and handle differently
	if _game_manager and _game_manager.enable_map_editor:
		_handle_editor_region_click(region_container)
		return
	var tutorial_region_matched: bool = false
	var region: Region = region_container as Region
	if _tutorial_manager != null and _tutorial_manager.is_active() and _tutorial_manager.get_expected_action() == "region":
		if region == null:
			return
		if region.is_ocean_region():
			return
		if _is_mountain_region(region):
			return
		if not _tutorial_manager.handle_region_click(region):
			return
		tutorial_region_matched = true
	if _is_move_flow_active():
		var move_trigger_right: bool = GameParameters.get_army_move_trigger() == GameParameters.ArmyMoveTrigger.RIGHT_CLICK
		if _army_manager != null and region_container == _army_manager.selected_region_container:
			if not (move_trigger_right and button_index == MOUSE_BUTTON_RIGHT):
				_army_manager.deselect_army()
				if _info_modal and _info_modal.visible:
					_info_modal.switch_to_region_tab()
			return
		var visual_manager = _game_manager.get_visual_manager()
		if visual_manager and visual_manager.has_move_region_highlights():
			var allowed_ids = visual_manager.get_move_region_highlight_ids()
			if region and not allowed_ids.has(region.get_region_id()):
				var current_player_id = _game_manager.get_current_player_id()
				var region_owner = _region_manager.get_region_owner(region.get_region_id())
				if move_trigger_right and button_index == MOUSE_BUTTON_RIGHT:
					return
				if move_trigger_right and button_index == MOUSE_BUTTON_LEFT:
					pass
				elif region_owner == current_player_id:
					_army_manager.deselect_army()
					_info_modal.show_region_info(region)
					return
				else:
					return

	# Get region script to check if it's a mountain
	if region != null:
		# Ignore ocean regions in gameplay
		if region.is_ocean_region():
			return
		# Check if this is a mountain region - if so, ignore clicks
		if _is_mountain_region(region):
			return
	
	# Delegate to GameManager based on game state
	if _game_manager:
		if _game_manager.is_castle_placing_mode():
			# Only allow human players to place castles by clicking
			var current_player_id = _game_manager.get_current_player_id()
			if not _game_manager.is_player_human(current_player_id):
				DebugLogger.log("InputSystem", "Click ignored - current player (" + str(current_player_id) + ") is not human controlled")
				return
			
			# Check if castle placement is valid first
			if _game_manager.can_place_castle_in_region(region):
				_game_manager.handle_castle_placement(region)
			else:
				DebugLogger.log("InputSystem", "Cannot place castle - region already owned by another player")
		else:
			if _tutorial_manager != null and _tutorial_manager.is_active() and _tutorial_manager.get_expected_action() == "ui" and not tutorial_region_matched:
				return
			# For now, delegate army handling back to legacy system
			# TODO: Move to ArmyManager in future refactor
			_handle_army_selection_and_movement.call_deferred(region_container, button_index)

func _handle_mouse_motion() -> void:
	if _game_manager == null:
		_hide_move_hover_tooltips()
		return
	if _ui_manager and _ui_manager.is_modal_active:
		if _is_move_flow_active():
			_ui_manager.set_modal_active(false)
			_ui_manager.set_overlay_suppressed(true)
		elif not _ui_manager.is_only_info_modal_visible():
			var vm_modal := _game_manager.get_visual_manager()
			if vm_modal:
				vm_modal.clear_interaction_highlights()
			_hide_move_hover_tooltips()
			return
	var visual_manager = _game_manager.get_visual_manager()
	if visual_manager == null:
		_hide_move_hover_tooltips()
		return
	var camera := get_node("../Camera2D") as Camera2D
	var world_pos = camera.get_global_mouse_position()
	var regions_node := _map_script.get_node_or_null("Regions")
	if regions_node == null:
		visual_manager.clear_move_region_hover()
		visual_manager.set_map_hover_region(-1)
		_hide_move_hover_tooltips()
		return
	var highlighted_ids = visual_manager.get_move_region_highlight_ids()
	var hovered_move_region_id = -1
	var hovered_general_region_id = -1
	var hovered_move_region: Region = null
	for region_container in regions_node.get_children():
		if not (region_container is Region):
			continue
		var polygon = region_container.get_node_or_null("Polygon") as Polygon2D
		if polygon == null:
			continue
		if _point_in_polygon(world_pos, polygon):
			var region_ref: Region = region_container as Region
			var candidate_id = region_ref.get_region_id()
			if visual_manager.has_move_region_highlights() and _army_manager != null and _army_manager.selected_army != null and highlighted_ids.has(candidate_id):
				hovered_move_region_id = candidate_id
				hovered_move_region = region_ref
			elif _should_highlight_region_hover(region_ref) and not highlighted_ids.has(candidate_id):
				hovered_general_region_id = candidate_id
			break
	if visual_manager.has_move_region_highlights():
		visual_manager.set_map_hover_region(-1)
		if hovered_move_region_id != -1:
			visual_manager.set_move_region_hover(hovered_move_region_id)
			_show_move_tooltip(hovered_move_region)
			var tooltip_offset: Vector2 = Vector2(-2, 35)
			var region_tooltip_anchor_pos: Vector2 = _move_tooltip.position + tooltip_offset
			_ui_manager.show_region_tooltip_for_move(hovered_move_region, region_tooltip_anchor_pos)
		else:
			visual_manager.clear_move_region_hover()
			_hide_move_hover_tooltips()
	else:
		visual_manager.clear_move_region_hover()
		_hide_move_hover_tooltips()
	if not visual_manager.has_move_region_highlights():
		if hovered_general_region_id != -1:
			visual_manager.set_map_hover_region(hovered_general_region_id)
			visual_manager.set_region_highlight_hover(hovered_general_region_id)
		else:
			visual_manager.clear_region_highlight_hover()
			visual_manager.set_map_hover_region(-1)

func _is_move_flow_active() -> bool:
	var move_modal: MoveModal = get_node("../UI/MoveModal") as MoveModal
	return move_modal.visible and _army_manager != null and _army_manager.selected_army != null

func _show_move_tooltip(region: Region) -> void:
	var selected_army := _army_manager.selected_army
	var terrain_cost := _army_manager.get_terrain_cost(region, selected_army.get_player_id())
	var mouse_pos := get_viewport().get_mouse_position()
	_move_tooltip.show_move_tooltip(terrain_cost, mouse_pos)

func _hide_move_hover_tooltips() -> void:
	_move_tooltip.hide_tooltip()
	if _is_move_flow_active():
		_ui_manager.hide_region_tooltip()

func _is_mountain_region(region: Region) -> bool:
	"""Check if a region is a mountain region (unclickable)"""
	if region == null:
		return false
	var biome_name = region.get_biome().to_lower()
	return biome_name == "mountains"

func _should_highlight_region_hover(region: Region) -> bool:
	if region == null:
		return false
	if region.is_ocean_region():
		return false
	return not _is_mountain_region(region)

func _handle_editor_region_click(region_container: Node) -> void:
	"""Handle region clicks in map editor mode - do nothing for now"""
	var region = region_container as Region
	if region == null:
		return

	# If ownership mode is active, assign owner and update panel
	if _editor_ownership_mode:
		var region_id := region.get_region_id()
		_region_manager.set_region_ownership(region_id, _editor_owner_id)
		# Keep panel in sync with current region
		var map_editor2: MapEditor = get_node("../MapEditor") as MapEditor
		map_editor2.set_current_region(region)
		return

	# Update editor panel selection
	var map_editor: MapEditor = get_node("../MapEditor") as MapEditor
	map_editor.set_current_region(region)



func _handle_army_selection_and_movement(region_container: Node, button_index: int) -> void:
	var move_trigger_right: bool = GameParameters.get_army_move_trigger() == GameParameters.ArmyMoveTrigger.RIGHT_CLICK
	var is_move_click: bool = button_index == MOUSE_BUTTON_LEFT
	if move_trigger_right:
		is_move_click = button_index == MOUSE_BUTTON_RIGHT

	# If we have a selected army, prioritize movement to the clicked region
	if _army_manager.selected_army != null and _army_manager.selected_region_container != null:
		if region_container == _army_manager.selected_region_container:
			if button_index == MOUSE_BUTTON_LEFT:
				_army_manager.deselect_army()
			return
		var target_region = region_container as Region
		var target_region_id = target_region.get_region_id()
		var current_player_id = _game_manager.get_current_player_id()
		var region_owner = _region_manager.get_region_owner(target_region_id)
		var is_owned_region = region_owner == current_player_id
		var is_potential_target := _is_potential_move_target(_army_manager.selected_region_container, region_container)
		if is_move_click and is_potential_target:
			var movement_points = _army_manager.selected_army.get_movement_points()
			DebugLogger.log("InputSystem", "Selected army " + _army_manager.selected_army.name + " has " + str(movement_points) + " movement points")
			if movement_points > 0 and _army_manager.can_army_move_to_region(_army_manager.selected_army, region_container):
				var result = await _game_manager.perform_region_entry(_army_manager.selected_army, target_region_id, "human")
				if result == "blocked":
					_army_manager.deselect_army()
				return
			return
		if move_trigger_right:
			if button_index == MOUSE_BUTTON_RIGHT:
				return
			if is_owned_region:
				var friendly_army: Army = _army_manager.get_army_in_region(region_container, current_player_id)
				if friendly_army != null:
					_army_manager.select_army(friendly_army, region_container, current_player_id)
					return
				_army_manager.deselect_army()
				_info_modal.show_region_info(target_region)
				return
			return
		if is_owned_region:
			_army_manager.deselect_army()
			_info_modal.show_region_info(target_region)
			return
		else:
			return

	if move_trigger_right and button_index == MOUSE_BUTTON_RIGHT:
		return

	# Get all armies in this region
	var armies_in_region: Array[Army] = []
	for child in region_container.get_children():
		if child is Army:
			armies_in_region.append(child as Army)

	# If there are armies in this region, check for conquest or selection
	if not armies_in_region.is_empty():
		var region = region_container as Region
		var region_id = region.get_region_id()
		var region_owner = _region_manager.get_region_owner(region_id)
		var current_player_id = _game_manager.get_current_player_id()

		# Conquest scenario (player already has army in unowned/enemy region)
		var player_army_in_region = _army_manager.get_army_in_region(region_container, current_player_id)
		if player_army_in_region != null and region_owner != current_player_id:
			_game_manager.show_prebattle_modal(player_army_in_region, region)
			return

	# Show region info for owned regions, otherwise hide the modal
	var region = region_container as Region
	if region != null:
		var region_id = region.get_region_id()
		var region_owner = _region_manager.get_region_owner(region_id)
		var current_player_id = _game_manager.get_current_player_id()
		if region_owner == current_player_id:
			_info_modal.show_region_info(region)
		else:
			if _info_modal.visible:
				_info_modal.hide_modal()
			DebugLogger.log("InputSystem", "Clicked on region: " + region.get_region_name() + " (Owner: " + str(region_owner) + ")")

func _is_potential_move_target(source_region_container: Node, target_region_container: Node) -> bool:
	var source_region := source_region_container as Region
	var target_region := target_region_container as Region
	var source_region_id = source_region.get_region_id()
	var target_region_id = target_region.get_region_id()
	var neighbors := _region_manager.get_neighbor_regions(source_region_id)
	if not neighbors.has(target_region_id):
		return false
	if not target_region.is_passable():
		return false
	if _army_manager.is_region_at_army_cap(target_region_container):
		return false
	return true

# Legacy functions kept for compatibility - these now delegate to appropriate managers
func reset_army_moves() -> void:
	"""Reset all army movement points for a new turn - delegates to ArmyManager"""
	if _army_manager != null:
		_army_manager.reset_all_army_movement_points()
	else:
		DebugLogger.log("InputSystem", "Error: ArmyManager not available")

# Handle human battle completion - delegate to BattleManager which now calls GameManager
func on_battle_modal_closed() -> void:
	"""Handle human battle modal closure - BattleManager will handle conquest via GameManager"""
	var battle_manager = _game_manager.get_battle_manager() if _game_manager else null
	if battle_manager:
		battle_manager.handle_battle_modal_closed()
