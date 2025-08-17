extends Node

# Handles mouse clicks on non-ocean regions.
# On left-click: detect which land region polygon was clicked, and place castle if in castle placing mode.



func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_left_click(event.global_position)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _army_manager != null:
				_army_manager.deselect_army()

@onready var _map_script: MapGenerator = get_node_or_null("../Map") as MapGenerator
@onready var _region_manager: RegionManager
@onready var _army_manager: ArmyManager
@onready var _army_modal: InfoModal = get_node_or_null("../UI/InfoModal") as InfoModal
@onready var _battle_modal: BattleModal = get_node_or_null("../UI/BattleModal") as BattleModal
@onready var _select_modal: SelectModal = get_node_or_null("../UI/SelectModal") as SelectModal
@onready var _region_modal: RegionModal = get_node_or_null("../UI/RegionModal") as RegionModal
@onready var _region_select_modal: RegionSelectModal = get_node_or_null("../UI/RegionSelectModal") as RegionSelectModal
@onready var _army_select_modal: ArmySelectModal = get_node_or_null("../UI/ArmySelectModal") as ArmySelectModal
@onready var _ui_manager: UIManager = get_node_or_null("../UI/UIManager") as UIManager
@onready var _sound_manager: SoundManager = get_node_or_null("../SoundManager") as SoundManager

func _ready():
	# Initialize managers early so they're available during map generation
	if _map_script:
		if _region_manager == null:
			_region_manager = RegionManager.new(_map_script)
		
		if _army_manager == null and _region_manager != null:
			_army_manager = ArmyManager.new(_map_script, _region_manager)
			
		# Connect army modal to army manager
		if _army_manager != null and _army_modal != null:
			_army_manager.set_army_modal(_army_modal)
		
		# Connect battle modal to army manager
		if _army_manager != null and _battle_modal != null:
			_army_manager.set_battle_modal(_battle_modal)
		
		# Connect sound manager to army manager
		if _army_manager != null and _sound_manager != null:
			_army_manager.set_sound_manager(_sound_manager)

func get_region_manager() -> RegionManager:
	"""Get the RegionManager instance"""
	return _region_manager

func get_army_manager() -> ArmyManager:
	"""Get the ArmyManager instance"""
	return _army_manager

# Castle placing mode
var castle_placing_mode: bool = true
var current_player_id: int = 1


func _on_left_click(screen_pos: Vector2) -> void:
	# Check if any modal is active and close them first
	if _ui_manager and _ui_manager.is_modal_active:
		_close_active_modals()
		return
	
	# Get the camera and convert screen to world coordinates properly
	var camera := get_node_or_null("../Camera2D") as Camera2D
	var world_pos: Vector2
	if camera != null:
		# Use camera's get_global_mouse_position for proper coordinate conversion
		world_pos = camera.get_global_mouse_position()
	else:
		# Fallback to manual conversion if no camera found
		world_pos = get_viewport().canvas_transform.affine_inverse() * screen_pos
		
	# Search within Map/regions for Region containers
	var map_root := get_node_or_null("../Map") as Node
	if map_root == null:
		map_root = get_node_or_null("Map")
	if map_root == null:
		print("[ClickManager] Error: Map node not found")
		return
	
	
	var map_children = []
	for child in map_root.get_children():
		map_children.append(child.name)
	
	var regions_node := map_root.get_node_or_null("Regions") as Node
	if regions_node == null:
		print("[ClickManager] Error: Regions node not found under Map")

		return
	
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
	if castle_placing_mode:
		_handle_castle_placement(region_container)
	else:
		_handle_army_selection_and_movement(region_container)

func _handle_castle_placement(region_container: Node) -> void:
	# Get region ID from the Region script
	var region = region_container as Region
	if region == null:
		print("[ClickManager] Error: Region container is not a Region: ", region_container.name)
		return
	
	var region_id = region.get_region_id()
	if region_id <= 0:
		print("[ClickManager] Error: Invalid region ID: ", region_id)
		return
	
	# Set castle starting position (this will also claim neighboring regions)
	_region_manager.set_castle_starting_position(region_id, current_player_id)
	
	# Update region visuals to show ownership
	_region_manager.update_region_visuals()
	
	# Place castle visual
	_place_castle_visual(region_container)
	
	# Place army in the same region
	_place_army_visual(region_container, current_player_id)
	
	# Hide region point in castle region (since castle is present)
	_region_manager.hide_region_point_for_army(region_container)
	
	# End castle placing mode after placing one castle
	castle_placing_mode = false
	
	# Play click sound for castle placement
	if _sound_manager:
		_sound_manager.click_sound()

func _handle_army_selection_and_movement(region_container: Node) -> void:
	# Get all armies in this region
	var armies_in_region: Array[Army] = []
	for child in region_container.get_children():
		if child is Army:
			armies_in_region.append(child as Army)
	
	# If there are armies in this region, show SelectModal
	if not armies_in_region.is_empty():
		var region = region_container as Region
		if region != null and _select_modal != null:
			_select_modal.show_selection(region, armies_in_region)
			# Play click sound for opening modal
			if _sound_manager:
				_sound_manager.click_sound()
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
		return
	
	# If no armies in region and no selected army, check ownership
	var region = region_container as Region
	if region != null:
		var region_id = region.get_region_id()
		var region_owner = _region_manager.get_region_owner(region_id)
		
		# If region is owned by current player, open RegionSelectModal
		if region_owner == current_player_id and _region_select_modal != null:
			_region_select_modal.show_region_actions(region)
			# Play click sound for opening modal
			if _sound_manager:
				_sound_manager.click_sound()
		# Otherwise, open RegionModal for unowned/enemy regions
		elif _region_modal != null:
			_region_modal.show_region_info(region)
			# Play click sound for opening modal
			if _sound_manager:
				_sound_manager.click_sound()

func _place_castle_visual(region_container: Node) -> void:
	# Remove any existing castle
	var existing_castle = region_container.get_node_or_null("Castle")
	if existing_castle != null:
		existing_castle.queue_free()
	
	# Create castle sprite
	var castle := Sprite2D.new()
	castle.name = "Castle"
	castle.texture = load("res://images/icons/castle.png")
	if castle.texture == null:
		print("[ClickManager] Error: Could not load castle texture")
		return
	
	# Position castle at region center (moved left and up by 5px)
	var polygon := region_container.get_node_or_null("Polygon") as Polygon2D
	if polygon != null:
		var center_meta = polygon.get_meta("center")
		if center_meta != null:
			var center := center_meta as Vector2
			castle.position = center + Vector2(-5, -5)  # Move left and up by 5px
	
	# Scale castle appropriately - 20% smaller than biome icons
	var castle_scale := 0.12  # 0.15 * 0.8 = 0.12 (20% smaller)
	if _map_script != null:
		castle_scale = castle_scale * _map_script.polygon_scale
	castle.scale = Vector2(castle_scale, castle_scale)
	
	# Set z-index to appear above other elements
	castle.z_index = 100
	
	# Add castle to region container
	region_container.add_child(castle)

func _place_army_visual(region_container: Node, player_id: int) -> void:
	"""Place an army in the specified region using ArmyManager"""
	if _army_manager != null:
		_army_manager.create_army(region_container, player_id)
	else:
		print("[ClickManager] Error: ArmyManager not available")

func reset_army_moves() -> void:
	"""Reset all army movement points for a new turn"""
	if _army_manager != null:
		_army_manager.reset_all_army_movement_points()
	else:
		print("[ClickManager] Error: ArmyManager not available")

func _close_active_modals() -> void:
	"""Close any active modals"""
	if _select_modal and _select_modal.visible:
		_select_modal.hide_modal()
	if _army_select_modal and _army_select_modal.visible:
		_army_select_modal.hide_modal()
	if _region_select_modal and _region_select_modal.visible:
		_region_select_modal.hide_modal()
	if _region_modal and _region_modal.visible:
		_region_modal.hide_modal()
