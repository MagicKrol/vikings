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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_left_click(event.global_position)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _army_manager != null:
				_army_manager.deselect_army()

# Core system references
@onready var _map_script: MapGenerator = get_node("../Map") as MapGenerator
@onready var _ui_manager: UIManager = get_node("../UI/UIManager") as UIManager
@onready var _game_manager: GameManager = get_node("../GameManager") as GameManager

# Legacy manager references for backward compatibility during transition
@onready var _region_manager: RegionManager
@onready var _army_manager: ArmyManager

func _ready():
	# Managers will be provided by GameManager via set_managers()
	pass

func set_managers(region_manager: RegionManager, army_manager: ArmyManager) -> void:
	"""Set manager references from GameManager"""
	_region_manager = region_manager
	_army_manager = army_manager

func get_region_manager() -> RegionManager:
	"""Get the RegionManager instance"""
	return _region_manager

func get_army_manager() -> ArmyManager:
	"""Get the ArmyManager instance"""
	return _army_manager

# Minimal state for input handling (game state now managed by GameManager)


func _on_left_click(screen_pos: Vector2) -> void:
	# Check if any modal is active and close them first
	if _ui_manager and _ui_manager.is_modal_active:
		# Don't close modals if BattleModal is in battle mode (battle_in_progress)
		var battle_modal = get_node("../UI/BattleModal") as BattleModal
		if battle_modal and battle_modal.visible and battle_modal.battle_in_progress:
			# Battle is active - don't allow closing the modal
			return
		_ui_manager.close_all_active_modals()
		return
	
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
	
	# Iterate regions and test polygon hit
	for region_container in regions_node.get_children():
		if not (region_container is Node):
			continue
		var polygon := region_container.get_node_or_null("Polygon") as Polygon2D
		if polygon == null:
			continue
		# Only non-ocean regions have Polygon nodes here
		if _point_in_polygon(world_pos, polygon):
			_handle_region_click(region_container)
			region_clicked = true
			break
	
	# If no region was clicked and we have a selected army, deselect it
	if not region_clicked and _army_manager and _army_manager.selected_army != null:
		_army_manager.deselect_army()

func _point_in_polygon(p: Vector2, polygon: Polygon2D) -> bool:
	# Convert world position into polygon local space and use Geometry2D
	var local := polygon.to_local(p)
	return Geometry2D.is_point_in_polygon(local, polygon.polygon)

func _handle_region_click(region_container: Node) -> void:
	# Get region script to check if it's a mountain
	var region = region_container as Region
	if region != null:
		# Check if this is a mountain region - if so, ignore clicks
		if _is_mountain_region(region):
			return
	
	# Delegate to GameManager based on game state
	if _game_manager:
		if _game_manager.is_castle_placing_mode():
			# Check if castle placement is valid first
			if _game_manager.can_place_castle_in_region(region):
				_game_manager.handle_castle_placement(region)
			else:
				# Show info modal for invalid placement
				var region_modal = get_node("../UI/RegionModal") as RegionModal
				region_modal.show_region_info(region)
				print("[ClickManager] Cannot place castle - region already owned by another player")
		else:
			# For now, delegate army handling back to legacy system
			# TODO: Move to ArmyManager in future refactor
			_handle_army_selection_and_movement(region_container)

func _is_mountain_region(region: Region) -> bool:
	"""Check if a region is a mountain region (unclickable)"""
	if region == null:
		return false
	var biome_name = region.get_biome().to_lower()
	return biome_name == "mountains"


func _handle_army_selection_and_movement(region_container: Node) -> void:
	# Get all armies in this region
	var armies_in_region: Array[Army] = []
	for child in region_container.get_children():
		if child is Army:
			armies_in_region.append(child as Army)
	
	# If there are armies in this region, check for conquest first
	if not armies_in_region.is_empty():
		var region = region_container as Region
		if region != null:
			var region_id = region.get_region_id()
			var region_owner = _region_manager.get_region_owner(region_id)
			
			# Check if this is a conquest scenario (player army in unowned region)
			var current_player_id = _game_manager.get_current_player_id() if _game_manager else 1
			var player_army_in_region = _army_manager.get_army_in_region(region_container, current_player_id)
			if player_army_in_region != null and region_owner != current_player_id:
				# Player has army in unowned region - delegate to BattleManager
				var battle_manager = _game_manager.get_battle_manager()
				if battle_manager:
					battle_manager.set_pending_conquest(player_army_in_region, region)
					
					# Show battle modal
					var battle_modal = get_node("../UI/BattleModal") as BattleModal
					battle_modal.show_battle(player_army_in_region, region)
				return
			
			# Not a conquest scenario - filter armies by current player ownership
			var current_player_armies: Array[Army] = []
			for army in armies_in_region:
				if army.get_player_id() == current_player_id:
					current_player_armies.append(army)
			
			# Only show SelectModal if current player has armies in this region
			if not current_player_armies.is_empty():
				var select_modal = get_node("../UI/SelectModal") as SelectModal
				select_modal.show_selection(region, current_player_armies)
		return
	
	# If we have a selected army, try to move it to this region
	if _army_manager.selected_army != null and _army_manager.selected_region_container != null:
		# Check if selected army has movement points
		if _army_manager.selected_army.get_movement_points() <= 0:
			# Deselect army if no movement points
			_army_manager.deselect_army()
			return
		
		# Try to move army - if it fails (unreachable), deselect army
		var move_success = _army_manager.move_army_to_region(region_container)
		if not move_success:
			_army_manager.deselect_army()
			return  # Only return if movement failed
		
		# If movement succeeded, always return to prevent conquest detection in same click
		return
	
	# If no armies in region and no selected army, show region info
	var region = region_container as Region
	if region != null:
		var region_id = region.get_region_id()
		var region_owner = _region_manager.get_region_owner(region_id)
		var current_player_id = _game_manager.get_current_player_id() if _game_manager else 1
		
		# If region is owned by current player, open RegionSelectModal
		if region_owner == current_player_id:
			var region_select_modal = get_node("../UI/RegionSelectModal") as RegionSelectModal
			region_select_modal.show_region_actions(region)
		# Otherwise, open RegionModal for unowned/enemy regions
		else:
			var region_modal = get_node("../UI/RegionModal") as RegionModal
			region_modal.show_region_info(region)

# Legacy functions kept for compatibility - these now delegate to appropriate managers
func reset_army_moves() -> void:
	"""Reset all army movement points for a new turn - delegates to ArmyManager"""
	if _army_manager != null:
		_army_manager.reset_all_army_movement_points()
	else:
		print("[ClickManager] Error: ArmyManager not available")

# Legacy functions now handled by BattleManager - kept for compatibility during transition
func on_battle_modal_closed() -> void:
	"""Delegate battle modal closure to BattleManager"""
	var battle_manager = _game_manager.get_battle_manager() if _game_manager else null
	if battle_manager:
		battle_manager.handle_battle_modal_closed()
