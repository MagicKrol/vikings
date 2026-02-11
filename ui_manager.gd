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

var region_tooltip: Control  # Can be RegionTooltip or RegionTooltip2
var battle_modal: BattleModal
var map_generator: MapGenerator
var last_hovered_region: Region = null

# Modal mode system
var is_modal_active: bool = false
var _turn_modal_suppressed: bool = false
var _overlay_suppressed: bool = false

# Modal references for centralized management
var _player_status_modal2: PlayerStatusModal2
var _turn_modal: TurnModal
var _info_modal: InfoModal
var _move_modal: MoveModal
var _prebattle_modal: PrebattleModal
var _message_modal: MessageModal
var _intro_message_modal: MessageModal
var _trade_modal: TradeModal
var _recruitment_modal: RecruitmentModal
var _transfer_select_modal: TransferSelectModal
var _transfer_soldiers_modal: TransferSoldiersModal
var _icons_modal: Control
var _icons_modal_was_visible: bool = false
var _call_to_arms_modal: CallToArmsModal
var _battle_summary_modal: BattleSummaryModal
var _next_player_modal: NextPlayerModal
var _game_menu_modal: Control
var _modal_nodes: Array[Control] = []
var _blocking_modal_nodes: Array[Control] = []
var _move_selection_active: bool = false
var _remembered_region: Region = null
var _remembered_army: Army = null

func _ready():
	# Ensure UI is on top but doesn't block input
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow mouse events to pass through
	
	# Get references with correct paths
	# Check if we should use debug tooltip or normal tooltip
	var game_manager = get_parent().get_parent().get_node("GameManager") as GameManager
	var use_debug_tooltip = game_manager and game_manager.debug_heatmap
	
	if use_debug_tooltip:
		# Use old tooltip for debug mode (with AI debug info)
		region_tooltip = get_parent().get_node_or_null("RegionTooltip")
		if not region_tooltip:
			# Fallback to new tooltip if old one not found
			region_tooltip = get_parent().get_node_or_null("RegionTooltip2")
	else:
		# Use new tooltip for normal game
		region_tooltip = get_parent().get_node_or_null("RegionTooltip2")
		if not region_tooltip:
			# Fallback to old tooltip if new one not found
			region_tooltip = get_parent().get_node_or_null("RegionTooltip")
	
	# BattleModal is sibling under UI
	battle_modal = get_parent().get_node("BattleModal") as BattleModal
	
	# Get modal references
	_player_status_modal2 = get_parent().get_node("PlayerStatusModal2") as PlayerStatusModal2
	_turn_modal = get_parent().get_node("TurnModal") as TurnModal
	_info_modal = get_parent().get_node("InfoModal") as InfoModal
	_move_modal = get_parent().get_node("MoveModal") as MoveModal
	_prebattle_modal = get_parent().get_node("PrebattleModal") as PrebattleModal
	_message_modal = get_parent().get_node("MessageModal") as MessageModal
	_intro_message_modal = get_parent().get_node_or_null("IntroMessageModal") as MessageModal
	_trade_modal = get_parent().get_node("TradeModal") as TradeModal
	_recruitment_modal = get_parent().get_node("RecruitmentModal") as RecruitmentModal
	_transfer_select_modal = get_parent().get_node("TransferSelectModal") as TransferSelectModal
	_transfer_soldiers_modal = get_parent().get_node("TransferSoldiersModal") as TransferSoldiersModal
	_icons_modal = get_parent().get_node("IconsModal") as Control
	_call_to_arms_modal = get_parent().get_node("CallToArmsModal") as CallToArmsModal
	_battle_summary_modal = get_parent().get_node("BattleSummaryModal") as BattleSummaryModal
	_next_player_modal = get_parent().get_node("NextPlayerModal") as NextPlayerModal
	_game_menu_modal = get_parent().get_node("GameMenuModal") as Control
	_build_modal_list()
	_build_blocking_modal_list()
	
	# Map is under root (UI parent's parent)
	map_generator = get_parent().get_parent().get_node("Map") as MapGenerator
	GlobalSignals.player_status_refresh_requested.connect(_on_player_status_refresh_requested)
	

func _process(_delta: float) -> void:
	_sync_modal_state()

func display_message(text: String) -> void:
	# Do not close other modals; just mark modal state and show MessageModal on top
	set_modal_active(true)
	_message_modal.displayMessage(text)


func set_modal_active(active: bool) -> void:
	"""Set the modal mode state"""
	is_modal_active = active
	_apply_icons_visibility()
	_update_turn_modal_visibility()
	if is_modal_active and region_tooltip and region_tooltip.visible:
		hide_region_tooltip()

func set_overlay_suppressed(active: bool) -> void:
	_overlay_suppressed = active
	_apply_icons_visibility()
	_update_turn_modal_visibility()

func _apply_icons_visibility() -> void:
	if _icons_modal == null:
		return
	if is_modal_active or _overlay_suppressed or _move_selection_active:
		if _icons_modal.visible:
			_icons_modal_was_visible = true
		_icons_modal.visible = false
	elif _icons_modal_was_visible:
		_icons_modal.visible = true
		_icons_modal_was_visible = false

func _build_modal_list() -> void:
	_modal_nodes = [
		battle_modal,
		_info_modal,
		_prebattle_modal,
		_message_modal,
		_intro_message_modal,
		_trade_modal,
		_recruitment_modal,
		_transfer_select_modal,
		_transfer_soldiers_modal,
		_call_to_arms_modal,
		_next_player_modal,
		_battle_summary_modal,
		_game_menu_modal
	]

func _build_blocking_modal_list() -> void:
	_blocking_modal_nodes = [
		_prebattle_modal,
		battle_modal,
		_battle_summary_modal,
		_recruitment_modal,
		_transfer_soldiers_modal,
		_intro_message_modal
	]

func _sync_modal_state() -> void:
	var should_be_active := _is_any_tracked_modal_visible()
	if should_be_active != is_modal_active:
		set_modal_active(should_be_active)

func _is_any_tracked_modal_visible() -> bool:
	for modal in _modal_nodes:
		if modal == _move_modal and _move_selection_active:
			continue
		if modal != null and _is_modal_forcing_active(modal):
			return true
	return false

func has_blocking_modal() -> bool:
	for modal in _blocking_modal_nodes:
		if modal != null and modal.visible:
			return true
	return false

func set_move_selection_active(active: bool) -> void:
	_move_selection_active = active
	_apply_icons_visibility()
	_update_turn_modal_visibility()

func _is_modal_forcing_active(modal: Control) -> bool:
	if modal == _message_modal:
		return modal.visible and modal.mouse_filter == Control.MOUSE_FILTER_STOP
	return modal.visible
	
func suppress_turn_modal_for_movement(enabled: bool) -> void:
	_turn_modal_suppressed = enabled
	_update_turn_modal_visibility()

func _update_turn_modal_visibility() -> void:
	if _turn_modal:
		_turn_modal.visible = not is_modal_active and not _turn_modal_suppressed and not _overlay_suppressed and not _move_selection_active

func hide_region_tooltip() -> void:
	DebugLogger.log("UIManager", "hide_region_tooltip called. visible=" + str(region_tooltip.visible))
	region_tooltip.hide_tooltip()
	last_hovered_region = null

func hide_tooltip_due_to(control: Control) -> void:
	DebugLogger.log("UIManager", "hide_tooltip_due_to called by " + control.name)
	hide_region_tooltip()

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
		return
	# Allow closing active modals with ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_modal_active:
			close_all_active_modals()
			set_modal_active(false)
			

func _handle_mouse_motion(event: InputEventMouseMotion):
	"""Handle mouse movement to show/hide region tooltips"""
	if not region_tooltip or not map_generator:
		return

	# Don't show tooltips when any modal is active
	if is_modal_active and not is_only_info_modal_visible():
		if region_tooltip.visible:
			hide_region_tooltip()
		return

	var hovered_control = get_viewport().gui_get_hovered_control()
	if hovered_control:
		DebugLogger.log("UIManager", "Hovered control: " + hovered_control.name)
	else:
		DebugLogger.log("UIManager", "Hovered control: null")
	if _is_blocking_control(hovered_control):
		hide_region_tooltip()
		return

	# Convert mouse position to world coordinates using same method as click manager
	var world_pos = _convert_screen_to_world_pos(event.global_position)

	# Find region under mouse
	var hovered_region = _get_region_under_mouse(world_pos)

	if hovered_region != last_hovered_region:
		if hovered_region:
			# Show tooltip for new region
			DebugLogger.log("UIManager", "Showing tooltip for region id=" + str(hovered_region.get_region_id()))
			region_tooltip.show_region_tooltip(hovered_region, event.position)
		else:
			# Hide tooltip when not over any region
			hide_region_tooltip()
		
		last_hovered_region = hovered_region
	elif hovered_region and region_tooltip.visible:
		# Update tooltip position if still hovering same region
		DebugLogger.log("UIManager", "Updating tooltip position for region id=" + str(hovered_region.get_region_id()))
		region_tooltip.update_position(event.position)

func _convert_screen_to_world_pos(screen_pos: Vector2) -> Vector2:
	"""Convert screen coordinates to world coordinates using same method as click manager"""
	# Get the camera and convert screen to world coordinates properly
	var camera := get_parent().get_parent().get_node("Camera2D") as Camera2D
	# Use camera's get_global_mouse_position for proper coordinate conversion
	var world_pos = camera.get_global_mouse_position()
	
	return world_pos

func _on_player_status_refresh_requested() -> void:
	if _player_status_modal2:
		_player_status_modal2.refresh_from_game_state()

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
			if region.is_ocean_region():
				continue
			if region.get_region_type() == RegionTypeEnum.Type.MOUNTAINS:
				continue
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

func _is_blocking_control(control: Control) -> bool:
	if control == null:
		DebugLogger.log("UIManager", "_is_blocking_control: control is null")
		return false
	if not control.is_visible_in_tree():
		DebugLogger.log("UIManager", "_is_blocking_control: control " + control.name + " not visible")
		return false
	# Allow tooltip itself and its children
	if control == region_tooltip or region_tooltip.is_ancestor_of(control):
		DebugLogger.log("UIManager", "_is_blocking_control: control " + control.name + " is tooltip or child")
		return false
	var blockers = [
		_turn_modal,
		_player_status_modal2,
		_info_modal,
		_move_modal,
		_prebattle_modal,
		battle_modal
	]
	for blocker in blockers:
		if blocker and blocker.is_visible_in_tree():
			if control == blocker or blocker.is_ancestor_of(control) or control.is_ancestor_of(blocker):
				DebugLogger.log("UIManager", "Blocking control detected: " + blocker.name)
				return true
	DebugLogger.log("UIManager", "_is_blocking_control: control " + control.name + " not blocking")
	return false

func close_all_active_modals(include_blocking: bool = false) -> void:
	"""Close any active modals"""
	DebugLogger.log("click", "UIManager: close_all_active_modals called include_blocking=" + str(include_blocking))
	if include_blocking and battle_modal and battle_modal.visible:
		battle_modal.hide_modal()
	if _info_modal and _info_modal.visible:
		_info_modal.hide_modal()
	if _move_modal and _move_modal.visible:
		_move_modal.hide_move_modal()
	if include_blocking and _prebattle_modal.visible:
		_prebattle_modal.hide_prebattle()
	if _trade_modal and _trade_modal.visible:
		_trade_modal.hide_modal()
	if _recruitment_modal and _recruitment_modal.visible:
		_recruitment_modal.hide_modal()
	if _transfer_select_modal and _transfer_select_modal.visible:
		_transfer_select_modal.hide_modal()
	if _transfer_soldiers_modal and _transfer_soldiers_modal.visible:
		_transfer_soldiers_modal.hide_modal()
	if include_blocking and _battle_summary_modal and _battle_summary_modal.visible:
		_battle_summary_modal.hide_summary()

func is_any_modal_visible() -> bool:
	"""Check if any modal is currently visible"""
	return _is_any_tracked_modal_visible()

func is_only_info_modal_visible() -> bool:
	if not _info_modal.visible:
		return false
	for modal in _modal_nodes:
		if modal == _move_modal and _move_selection_active:
			continue
		if modal == _info_modal:
			continue
		if modal != null and _is_modal_forcing_active(modal):
			return false
	return true

func get_player_status_modal2() -> PlayerStatusModal2:
	"""Get the PlayerStatusModal2 instance"""
	return _player_status_modal2

func get_turn_modal() -> TurnModal:
	"""Get the TurnModal instance"""
	return _turn_modal

func remember_region_select(region: Region) -> void:
	_remembered_region = region
	_remembered_army = null

func remember_army_select(army: Army, region: Region) -> void:
	_remembered_army = army
	_remembered_region = region

func clear_select_context() -> void:
	_remembered_region = null
	_remembered_army = null

func restore_select_context() -> void:
	if _remembered_army != null:
		_info_modal.show_army_info(_remembered_army)
	elif _remembered_region != null:
		_info_modal.show_region_info(_remembered_region)
