extends RefCounted
class_name ArmyManager

# ============================================================================
# ARMY MANAGER
# ============================================================================
# 
# Purpose: Army creation, movement, selection, and lifecycle management
# 
# Core Responsibilities:
# - Army creation and visual placement on regions
# - Army selection, movement, and pathfinding
# - Turn-based movement point management and reset
# - Army lifecycle management (creation, tracking, destruction)
# - Battle initiation and army coordination
# 
# Required Functions:
# - create_army(): Create and place armies on regions
# - move_army_to_region(): Handle army movement with validation
# - reset_all_army_movement_points(): Turn-based movement reset
# - remove_destroyed_armies(): Clean up defeated armies
# - select/deselect_army(): Army selection state management
# 
# Integration Points:
# - MapGenerator: Region positioning and scale data
# - RegionManager: Ownership validation and movement rules
# - BattleModal: Combat initiation and UI updates
# - Army: Individual army state management
# ============================================================================

# Reference to the map generator for region data
var map_generator: MapGenerator

# Reference to the region manager for ownership and movement validation
var region_manager: RegionManager

# Reference to the army modal for UI updates
var army_modal: InfoModal = null

# Reference to the battle modal for UI updates
var battle_modal: BattleModal = null

# Reference to the sound manager for sound effects
var sound_manager: SoundManager = null

# Reference to the move modal for UI updates
var move_modal: MoveModal = null

# Reference to the UI manager for modal coordination
var ui_manager: UIManager = null

# Reference to the visual manager for ownership animations
var visual_manager: VisualManager = null
var _ready_highlight_player_id: int = -1

# All armies in the game: player_id -> Array[Army]
var armies_by_player: Dictionary = {}

# Track previous region for each army (for withdrawal retreat)
var army_previous_regions: Dictionary = {}  # Army -> Node (region_container)

# Currently selected army for movement
var selected_army: Army = null
var selected_region_container: Node = null

# Arrow system for showing available moves
var move_arrows: Array[Node] = []
var arrows_container: Node = null

func _init(map_gen: MapGenerator, region_mgr: RegionManager):
	map_generator = map_gen
	region_manager = region_mgr
	# Try to find the army modal
	_find_army_modal()

func set_army_modal(modal: InfoModal) -> void:
	"""Set the army modal reference"""
	army_modal = modal

func set_battle_modal(modal: BattleModal) -> void:
	"""Set the battle modal reference"""
	battle_modal = modal

func set_sound_manager(manager: SoundManager) -> void:
	"""Set the sound manager reference"""
	sound_manager = manager

func set_move_modal(modal: MoveModal) -> void:
	"""Set the move modal reference"""
	move_modal = modal
	if move_modal:
		move_modal.set_army_manager(self)

func set_ui_manager(manager: UIManager) -> void:
	ui_manager = manager

func set_visual_manager(manager: VisualManager) -> void:
	"""Set the visual manager reference"""
	visual_manager = manager
	if _ready_highlight_player_id != -1:
		update_ready_highlights_for_player(_ready_highlight_player_id)

func _find_army_modal() -> void:
	"""Find and store reference to the army modal"""
	# This will be called later when the scene is ready
	# For now, we'll set it to null and find it when needed

func create_army(region_container: Node, player_id: int, is_raised: bool = false) -> Army:
	"""Create a new army in the specified region"""
	if is_raised:
		DebugLogger.log("ArmyManagement", "create_army called for raised army, player " + str(player_id) + " in region " + region_container.name)
	
	if is_region_at_army_cap(region_container):
		DebugLogger.log("ArmyManagement", "Cannot create army in " + region_container.name + " - max armies reached")
		return null
	
	# Create army instance with Roman numeral naming
	var army := Sprite2D.new()
	# Explicitly attach the Army script
	army.set_script(load("res://army.gd"))
	var roman_number = _get_next_army_roman_numeral(player_id)
	army.name = "Army " + roman_number
	
	# Setup army based on type
	if is_raised:
		army.setup_raised_army(player_id, roman_number)
	else:
		var starting_composition := _get_starting_army_composition(player_id)
		army.setup_army(player_id, roman_number, starting_composition)
	
	# Position army at region center with appropriate offset
	var polygon := region_container.get_node_or_null("Polygon") as Polygon2D
	if polygon != null:
		var center_meta = polygon.get_meta("center")
		if center_meta != null:
			var center := center_meta as Vector2
			army.position = center + _get_army_position_offset(region_container)
	
	# Apply map size scaling
	if map_generator != null:
		army.apply_map_size_scaling(map_generator)
	
	# Add army to region container
	region_container.add_child(army)
	
	# Track army in our dictionary
	if not armies_by_player.has(player_id):
		armies_by_player[player_id] = []
	armies_by_player[player_id].append(army)
	army.movement_points_changed.connect(_on_army_movement_points_changed)

	if is_raised:
		DebugLogger.log("ArmyManagement", "Raised new army for player " + str(player_id) + " in region " + region_container.name)

	# Reposition all armies in region to avoid overlap
	_apply_army_offsets_for_region(region_container)

	if player_id == _ready_highlight_player_id:
		update_ready_highlights_for_player(player_id)

	return army

func create_raised_army(region_container: Node, player_id: int) -> Army:
	"""Create a new raised army with 0 movement points and no soldiers"""
	return create_army(region_container, player_id, true)

func _get_army_position_offset(region_container: Node) -> Vector2:
	"""Get the appropriate position offset for army based on region contents"""
	# Get map size scaling factor
	var map_size_scale := 1.0
	if map_generator != null:
		map_size_scale = Utils.get_map_size_icon_scale(map_generator.map_size)
	
	# Check if there's a castle in the region
	var castle = region_container.get_node_or_null("Castle")
	if castle != null:
		return Vector2(15 * map_size_scale, -10 * map_size_scale)  # Army positioned to the right of castle (scaled)
	
	# Default positioning when no castle is present (scaled)
	return Vector2(0, -5 * map_size_scale)  # Army positioned slightly above center

func _on_army_movement_points_changed(army: Army, new_points: int) -> void:
	if army == null or not is_instance_valid(army):
		return
	if army.get_player_id() != _ready_highlight_player_id:
		return
	update_ready_highlights_for_player(_ready_highlight_player_id)

func set_ready_highlight_player(player_id: int) -> void:
	_ready_highlight_player_id = player_id
	if visual_manager == null:
		return
	if player_id == -1:
		visual_manager.clear_ready_army_highlights()
	else:
		update_ready_highlights_for_player(player_id)

func update_ready_highlights_for_player(player_id: int) -> void:
	if visual_manager == null:
		return
	if player_id == -1:
		visual_manager.clear_ready_army_highlights()
		return
	var game_manager := _get_game_manager()
	if game_manager != null and not game_manager.is_player_human(player_id):
		visual_manager.clear_ready_army_highlights()
		return
	if player_id != _ready_highlight_player_id:
		return
	var ready_regions: Array = []
	if armies_by_player.has(player_id):
		for army in armies_by_player[player_id]:
			if army == null or not is_instance_valid(army):
				continue
			if army.get_movement_points() <= 0:
				continue
			var region = army.get_parent()
			if region is Region:
				var region_id = (region as Region).get_region_id()
				if region_id != -1 and not ready_regions.has(region_id) and region.current_owner_id == army.get_player_id():
					ready_regions.append(region_id)
	visual_manager.update_ready_army_highlights(player_id, ready_regions)

func _apply_army_offsets_for_region(region_container: Node, skip_army: Army = null) -> void:
	"""Reposition all armies in a region using stacked offsets and z-index order.
	If skip_army is provided, its position will not be set here (useful for animation)."""
	var polygon := region_container.get_node_or_null("Polygon") as Polygon2D
	if polygon == null:
		return
	var center_meta = polygon.get_meta("center")
	if center_meta == null:
		return
	var center := center_meta as Vector2
	var base_offset := _get_army_position_offset(region_container)
	var map_size_scale := 1.0
	if map_generator != null:
		map_size_scale = Utils.get_map_size_icon_scale(map_generator.map_size)
	var extra_offsets: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(-15, -10),
		Vector2(-30, -20),
		Vector2(15, -10),
		Vector2(30, -20)
	]
	var armies: Array[Army] = []
	for child in region_container.get_children():
		if child is Army:
			armies.append(child as Army)
	for i in armies.size():
		var army := armies[i]
		var idx := i if i < extra_offsets.size() else 0
		var extra: Vector2 = (extra_offsets[idx] as Vector2) * map_size_scale
		var base_z := 125 + army.get_player_id()
		if i >= 1 and i <= 4:
			army.z_index = base_z - i
		else:
			army.z_index = base_z
		if skip_army != null and army == skip_army:
			continue
		army.position = center + base_offset + extra

func _compute_army_target_position(region_container: Node, army: Army) -> Vector2:
	"""Compute the stacked target position for a specific army in a region."""
	var polygon := region_container.get_node_or_null("Polygon") as Polygon2D
	var center_meta = polygon.get_meta("center")
	var center := center_meta as Vector2
	var base_offset := _get_army_position_offset(region_container)
	var map_size_scale := 1.0
	if map_generator != null:
		map_size_scale = Utils.get_map_size_icon_scale(map_generator.map_size)
	var extra_offsets: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(-15, -10),
		Vector2(-30, -20),
		Vector2(15, -10),
		Vector2(30, -20)
	]
	var armies: Array[Army] = []
	for child in region_container.get_children():
		if child is Army:
			armies.append(child as Army)
	var idx := 0
	for i in armies.size():
		if armies[i] == army:
			idx = i
			break
	var extra: Vector2 = (extra_offsets[idx if idx < extra_offsets.size() else 0] as Vector2) * map_size_scale
	return center + base_offset + extra

func select_army(army: Army, region_container: Node, current_player_id: int = -1) -> void:
	"""Select an army for movement - only allow selecting armies owned by current player"""
	DebugLogger.log("ArmyManagement", "select_army called for army " + (army.name if army else "null"))
	
	if army == null or not is_instance_valid(army):
		DebugLogger.log("ArmyManagement", "Army is null or invalid")
		return
	
	if region_container == null:
		DebugLogger.log("ArmyManagement", "Region container is null")
		return
	
	# Check if army belongs to current player (if current_player_id is provided)
	if current_player_id != -1 and army.get_player_id() != current_player_id:
		DebugLogger.log("ArmyManagement", "Cannot select army owned by Player " + str(army.get_player_id()) + " (current player is " + str(current_player_id) + ")")
		return
	
	DebugLogger.log("ArmyManagement", "Setting selected_army to " + army.name)
	selected_army = army
	selected_region_container = region_container
	if ui_manager:
		ui_manager.suppress_turn_modal_for_movement(true)
		ui_manager.set_move_selection_active(true)

	# Show army modal
	if army_modal != null:
		DebugLogger.log("ArmyManagement", "Showing army modal")
		army_modal.show_army_info(army)
	else:
		DebugLogger.log("ArmyManagement", "Army modal is null")

	# Only show move arrows for human players
	if _should_show_human_arrows():
		DebugLogger.log("ArmyManagement", "Showing move arrows for human player")
		_show_move_arrows(region_container)
		# Show move modal when arrows are shown
		if move_modal:
			move_modal.show_move_modal(army)
	else:
		DebugLogger.log("ArmyManagement", "Not showing move arrows (not human player)")

func deselect_army() -> void:
	"""Deselect the currently selected army"""
	selected_army = null
	selected_region_container = null
	if ui_manager:
		ui_manager.suppress_turn_modal_for_movement(false)
		ui_manager.set_move_selection_active(false)

	# Hide army modal
	if army_modal != null:
		army_modal.hide_modal()
	
	# Hide move modal
	if move_modal != null:
		move_modal.hide_move_modal()

	_clear_move_arrows()

func move_army(army: Army, target_region: Region) -> bool:
	"""Move a specific army to target region. Returns true if successful."""
	if army == null or not is_instance_valid(army):
		return false
	if target_region == null:
		return false
	
	var source_region_container = army.get_parent()
	if source_region_container == null:
		return false
	
	# Temporarily set selection to use existing logic
	var previous_selection = selected_army
	var previous_region = selected_region_container
	
	selected_army = army
	selected_region_container = source_region_container
	
	# Use existing movement logic
	var result = await move_army_to_region(target_region)
	
	# Restore previous selection
	if is_instance_valid(previous_selection) and is_instance_valid(previous_region):
		selected_army = previous_selection
		selected_region_container = previous_region
	else:
		selected_army = null
		selected_region_container = null
	
	return result

func move_army_to_region(target_region_container: Node) -> bool:
	"""Move the selected army to the target region. Returns true if successful."""
	# Validate prerequisites
	if not _validate_movement_prerequisites(target_region_container):
		return false
	
	var moving_army := selected_army
	if moving_army == null or not is_instance_valid(moving_army):
		DebugLogger.log("AIMovement", "Cannot move army - no valid selection")
		return false
	
	# Get region IDs from Region scripts
	var source_region = selected_region_container
	var target_region_node = target_region_container
	if not source_region.has_method("get_region_id") or not target_region_node.has_method("get_region_id"):
		DebugLogger.log("AIMovement", "Error: Region containers don't have get_region_id method")
		return false
	
	var source_region_id = source_region.get_region_id()
	var target_region_id = target_region_node.get_region_id()
	
	# Check if target region is a neighbor of source region
	var neighbors = region_manager.get_neighbor_regions(source_region_id)
	if not neighbors.has(target_region_id):

		return false
	
	# Get terrain cost once for the entire function (with ownership bonus)
	var terrain_cost = get_terrain_cost(target_region_container, moving_army.get_player_id())
	
	# Check if army can move to this region
	if not can_army_move_to_region(moving_army, target_region_container):
		var check_region = target_region_container as Region
		if check_region != null and not check_region.is_passable():
			var _region_type_name = RegionTypeEnum.type_to_string(check_region.get_region_type())
		else:
			var current_points = moving_army.get_movement_points()
			DebugLogger.log("AIMovement", "Movement blocked - not enough movement points (need " + str(terrain_cost) + ", have " + str(current_points) + ")")
		return false

	_play_move_click(moving_army)
	
	# Battle conditions will be handled after movement by click_manager
	var target_region = target_region_container as Region
	
	# Store previous region for potential retreat
	army_previous_regions[moving_army] = selected_region_container
	
	# Move the army node, keeping its global start position
	var start_global := moving_army.global_position
	moving_army.get_parent().remove_child(moving_army)
	target_region_container.add_child(moving_army)
	moving_army.global_position = start_global

	# Reposition remaining armies in source region (selected army removed)
	_apply_army_offsets_for_region(source_region)

	# Compute stacked target for selected army in target region and apply others immediately
	var target_local := _compute_army_target_position(target_region_container, moving_army)
	_apply_army_offsets_for_region(target_region_container, moving_army)
	# Animate the moving army to its target position (use global for robust animation)
	var target_global: Vector2 = target_region_container.to_global(target_local)
	var gm := _get_game_manager()
	var is_ai_player := gm != null and gm.is_player_computer(moving_army.get_player_id())
	var move_duration := GameParameters.get_move_animation_duration(is_ai_player)
	var tween: Tween = moving_army.animate_move_to(target_global, move_duration, true)
	await tween.finished
	# Do not re-apply offsets for the moving army here; let the tween finish
	
	# After animation completes, check if we should change ownership (only for already owned regions or friendly moves)
	var target_region_owner = region_manager.get_region_owner(target_region_id)
	var army_player_id = moving_army.player_id
	
	# Only set ownership if ownership is actually changing (neutral territory without garrison)
	if target_region_owner == -1 and not target_region.has_garrison():
		var game_manager = _get_game_manager()
		if game_manager:
			game_manager.claim_peaceful_region(target_region_id, army_player_id)
		else:
			DebugLogger.log("AIMovement", "Warning: Could not get GameManager for peaceful region claiming")
	
	# Deduct movement points
	moving_army.spend_movement_points(terrain_cost)

	# Reduce efficiency by 5 for movement
	moving_army.reduce_efficiency(5)

	# Store remaining movement points for logging
	var remaining_points = moving_army.get_movement_points()
	# Per-move debug: region, cost, MP left this turn
	DebugLogger.log("AIMovement", "Moved to region %d, Cost: %d, MP left: %d/%d" % [target_region_id, terrain_cost, remaining_points, GameParameters.MOVEMENT_POINTS_PER_TURN])
	
	# Check if we moved to an unowned region - handle combat scenarios
	if target_region_owner != army_player_id and target_region_owner != -1:
		# Moved to enemy territory - trigger combat
		_trigger_combat_if_needed(moving_army, target_region)
		DebugLogger.log("AIMovement", "Army moved to enemy territory (cost: " + str(terrain_cost) + ", remaining points: " + str(remaining_points) + ") - combat triggered")
	elif target_region_owner == -1 and target_region.has_garrison():
		# Moved to neutral territory with garrison - trigger combat
		_trigger_combat_if_needed(moving_army, target_region)
		DebugLogger.log("AIMovement", "Army moved to neutral territory with garrison (cost: " + str(terrain_cost) + ", remaining points: " + str(remaining_points) + ") - combat triggered")
	else:
		# Moved to friendly territory - keep army selected
		# Update selected region container to the new region
		selected_region_container = target_region_container
		
	# Clear old arrows and show new ones for the new position (only for human players)
		_clear_move_arrows()
		if _should_show_human_arrows():
			_show_move_arrows(target_region_container)
			# Update move modal with current army
			if move_modal and moving_army == selected_army:
				move_modal.show_move_modal(selected_army)
		
		# Update army modal with new movement points
		if army_modal != null and moving_army == selected_army:
			army_modal.show_army_info(selected_army, false)  # Don't manage modal mode - allow continued movement
		
		DebugLogger.log("AIMovement", "Army moved to friendly territory (cost: " + str(terrain_cost) + ", remaining points: " + str(remaining_points) + ")")
	
	DebugLogger.log("AIMovement", "Army moved (cost: " + str(terrain_cost) + ", remaining points: " + str(remaining_points) + ")")
	
	if moving_army.get_player_id() == _ready_highlight_player_id:
		update_ready_highlights_for_player(_ready_highlight_player_id)
	
	return true

func _show_move_arrows(region_container: Node) -> void:
	"""Show arrows pointing to all available move destinations"""
	# Clear any existing arrows first
	_clear_move_arrows()
	var move_target_regions: Array = []
	
	# Get current movement points for selected army
	var _current_points = 5  # Default
	if selected_army != null and is_instance_valid(selected_army):
		_current_points = selected_army.get_movement_points()
	
	# Get region ID from the Region script
	var region = region_container
	if not region.has_method("get_region_id"):
		DebugLogger.log("ArmyManagement", "Error: Region container doesn't have get_region_id method: " + region_container.name)
		return
	
	var region_id = region.get_region_id()
	if region_id <= 0:
		DebugLogger.log("ArmyManagement", "Error: Invalid region ID: " + str(region_id))
		return
	
	# Get neighboring regions
	var neighbors = region_manager.get_neighbor_regions(region_id)
	if neighbors.is_empty():

		return
	
	# Get source region center
	var source_polygon = region_container.get_node_or_null("Polygon") as Polygon2D
	if source_polygon == null:

		return
	
	var source_center_meta = source_polygon.get_meta("center")
	if source_center_meta == null:

		return
	
	var source_center = source_center_meta as Vector2
	
	# Create arrows container if it doesn't exist
	if arrows_container == null:
		arrows_container = Node2D.new()
		arrows_container.name = "MoveArrows"
		arrows_container.z_index = 200  # High z-index to appear above other elements
		
		# Add to the scene tree
		if map_generator != null:
			map_generator.add_child(arrows_container)
		else:

			return
	
	# Create arrows for each neighbor
	for neighbor_id in neighbors:
		# Find the neighbor region container
		if map_generator == null:
			continue
		
		var regions_node = map_generator.get_node_or_null("Regions")
		if regions_node == null:
			continue
		
		var neighbor_container = map_generator.get_region_container_by_id(neighbor_id)
		if neighbor_container == null:
			continue
		
		# Get neighbor region center
		var neighbor_polygon = neighbor_container.get_node_or_null("Polygon") as Polygon2D
		if neighbor_polygon == null:
			continue
		
		var neighbor_center_meta = neighbor_polygon.get_meta("center")
		if neighbor_center_meta == null:
			continue
		
		var neighbor_center = neighbor_center_meta as Vector2
		
		# Check if move is possible (not impassable and enough points)
		var can_move = false
		if selected_army != null:
			can_move = can_army_move_to_region(selected_army, neighbor_container)
		if can_move:
			move_target_regions.append(neighbor_id)
		
		# Create arrow (disabled if cannot move)
		var arrow = _create_move_arrow(source_center, neighbor_center, !can_move)
		if arrow != null:
			move_arrows.append(arrow)
			arrows_container.add_child(arrow)
	if visual_manager:
		if move_target_regions.is_empty():
			visual_manager.clear_move_region_highlights()
		else:
			visual_manager.animate_move_region_highlights(move_target_regions)
	


func _create_move_arrow(from_pos: Vector2, to_pos: Vector2, disabled: bool = false) -> Node:
	"""Create an arrow sprite pointing from one position to another"""
	var arrow := Sprite2D.new()
	
	# Choose texture based on whether army has moved
	if disabled:
		arrow.texture = load("res://images/icons/arrow_disabled.png")
	else:
		arrow.texture = load("res://images/icons/arrow2.png")
	
	if arrow.texture == null:

		return null
	
	# Scale arrows like castle icons: baseline × polygon_scale × map_size_scale
	var scale_factor := 0.12
	if map_generator != null:
		var mss := Utils.get_map_size_icon_scale(map_generator.map_size)
		scale_factor *= (map_generator.polygon_scale * mss)
	arrow.scale = Vector2(scale_factor, scale_factor)
	
	# Calculate position (65% towards target, 35% from source)
	arrow.position = from_pos + (to_pos - from_pos) * 0.65
	
	# Calculate angle between the two points
	var direction = to_pos - from_pos
	var angle = atan2(direction.y, direction.x)
	
	# Rotate the arrow (default arrow points right, so we use the calculated angle)
	arrow.rotation = angle
	
	# Set z-index
	arrow.z_index = 200
	
	return arrow

func _clear_move_arrows() -> void:
	"""Remove all move arrows"""
	if arrows_container != null:
		for arrow in move_arrows:
			if arrow != null and is_instance_valid(arrow):
				arrow.queue_free()
		move_arrows.clear()
	if visual_manager:
		visual_manager.clear_interaction_highlights()


func reset_all_army_movement_points() -> void:
	"""Reset movement points for all armies for a new turn"""
	var total_armies = 0
	
	for player_id in armies_by_player:
		for army in armies_by_player[player_id]:
			if is_instance_valid(army):
				army.reset_movement_points()
				total_armies += 1
	
	# Update army modal if an army is currently selected
	if army_modal != null and selected_army != null:
		army_modal.show_army_info(selected_army, false)  # Don't manage modal mode - just update info
	if _ready_highlight_player_id != -1:
		update_ready_highlights_for_player(_ready_highlight_player_id)

	DebugLogger.log("ArmyManagement", "Reset movement points for " + str(total_armies) + " armies")

func get_army_in_region(region_container: Node, player_id: int) -> Army:
	"""Get the army for a specific player in a region, or null if not found"""
	# Search through children since we now use Roman numeral naming
	for child in region_container.get_children():
		if child is Army and child.get_player_id() == player_id:
			return child as Army
	return null

func get_all_armies() -> Array[Army]:
	"""Get all armies in the game"""
	var all_armies: Array[Army] = []
	for player_id in armies_by_player:
		for army in armies_by_player[player_id]:
			if is_instance_valid(army):
				all_armies.append(army)
	return all_armies

func get_player_armies(player_id: int) -> Array[Army]:
	"""Get all armies for a specific player"""
	var player_armies: Array[Army] = []
	if armies_by_player.has(player_id):
		for army in armies_by_player[player_id]:
			if is_instance_valid(army):
				player_armies.append(army)
	return player_armies

func get_armies_in_region(region_container: Node) -> Array[Army]:
	"""Collect all armies currently in the region."""
	var armies: Array[Army] = []
	for child in region_container.get_children():
		if child is Army:
			armies.append(child as Army)
	return armies

func get_army_count_in_region(region_container: Node) -> int:
	"""Count armies in the given region."""
	var count := 0
	for child in region_container.get_children():
		if child is Army:
			count += 1
	return count

func is_region_at_army_cap(region_container: Node) -> bool:
	"""Check if the region already holds the maximum allowed armies."""
	return get_army_count_in_region(region_container) >= GameParameters.MAX_ARMIES_PER_REGION

# Legacy constants - now using RegionTypeEnum for movement costs

func can_army_move_to_region(army: Army, region_container: Node) -> bool:
	"""Check if army can move to the given region"""
	if army == null or not is_instance_valid(army):
		return false
	
	if region_container == null:
		return false
	
	# Get region script to access proper terrain type
	var region = region_container as Region
	if region == null:
		return false
	
	# Check if region is passable
	if not region.is_passable():
		return false
	
	# Enforce army stack cap
	if is_region_at_army_cap(region_container):
		return false
	
	# Check if army has enough movement points (with ownership bonus)
	var terrain_cost = get_terrain_cost(region_container, army.get_player_id())
	var current_movement_points = army.get_movement_points()
	return current_movement_points >= terrain_cost

func get_terrain_cost(region_container: Node, player_id: int = -1) -> int:
	"""Get the movement cost for a region based on its terrain type and ownership"""
	if region_container == null:
		return -1  # Return impassable for safety
	
	# Get region script to access region ID
	var region = region_container as Region
	if region == null:
		return -1  # Return impassable for safety
	
	# Use centralized terrain cost calculation from RegionManager
	if region_manager != null:
		return region_manager.calculate_terrain_cost(region.get_region_id(), player_id)
	
	# Fallback if region_manager is not available
	var base_cost = region.get_movement_cost()
	if base_cost == -1:
		return -1
	
	return base_cost

func _validate_movement_prerequisites(target_region_container: Node) -> bool:
	"""Validate that movement prerequisites are met. Returns true if valid."""
	if selected_army == null or selected_region_container == null:

		return false
	
	if target_region_container == null:

		return false
	
	if not is_instance_valid(selected_army):

		deselect_army()
		return false
	
	return true

func _should_trigger_battle(attacking_army: Army, target_region: Region) -> bool:
	"""Check if moving to this region should trigger a battle - delegates to GameManager"""
	var game_manager = _get_game_manager()
	if game_manager and game_manager.has_method("_should_trigger_battle"):
		return game_manager._should_trigger_battle(attacking_army, target_region)
	
	# Fallback to original logic if GameManager not available
	if attacking_army == null or target_region == null:
		return false
	
	var region_owner = region_manager.get_region_owner(target_region.get_region_id())
	var army_player = attacking_army.get_player_id()
	
	if region_owner != -1 and region_owner != army_player:
		return true
	
	if target_region.has_garrison() and (region_owner == -1 or region_owner != army_player):
		return true
	
	return false

func _trigger_combat_if_needed(attacking_army: Army, defending_region: Region) -> void:
	"""Trigger combat when army moves into hostile territory"""
	# Check if this should trigger battle
	if _should_trigger_battle(attacking_army, defending_region):
		# Find GameManager and BattleManager
		var game_manager = _get_game_manager()
		if game_manager:
			if game_manager.should_show_prebattle_for_army(attacking_army):
				if ui_manager:
					ui_manager.set_overlay_suppressed(true)
				game_manager.show_prebattle_modal(attacking_army, defending_region)
				deselect_army()
				return
			# If AI modal disabled, let GameManager.perform_region_entry handle battle; skip showing modal here
			if game_manager.debug_disable_battle_modal and game_manager.is_player_computer(attacking_army.get_player_id()):
				return
			var battle_manager = game_manager.get_battle_manager()
			if battle_manager:
				# Start battle through BattleManager (this will handle army storage for re-selection)
				battle_manager.start_battle(attacking_army, defending_region.get_region_id())
				DebugLogger.log("ArmyManagement", "Combat triggered: Army " + attacking_army.name + " vs Region " + defending_region.get_region_name())
				
				# Deselect army since combat is now handling it
				deselect_army()
				return
		
		DebugLogger.log("ArmyManagement", "Warning: Could not trigger combat - BattleManager not available")

func _play_move_click(moving_army: Army) -> void:
	if sound_manager == null or moving_army == null:
		return
	var game_manager := _get_game_manager()
	if game_manager != null and game_manager.is_player_human(moving_army.get_player_id()):
		sound_manager.click_sound()

func _get_starting_army_composition(player_id: int) -> Dictionary:
	return _get_game_manager().get_starting_army_composition_for_player(player_id)

func _get_game_manager() -> GameManager:
	"""Get GameManager reference"""
	# Since ArmyManager is RefCounted, we need to get GameManager through the map_generator reference
	if map_generator == null:
		return null
	
	# GameManager is a sibling of Map in the Main scene
	var main_node = map_generator.get_parent()  # Should be Main
	if main_node == null:
		return null
	
	var game_manager = main_node.get_node_or_null("GameManager") as GameManager
	return game_manager

func _show_battle_modal(attacking_army: Army, defending_region: Region) -> void:
	"""Show the battle modal with army vs region information"""
	if battle_modal != null:
		battle_modal.show_battle(attacking_army, defending_region)
	else:
		DebugLogger.log("ArmyManagement", "Error: BattleModal not available")

func _get_next_army_roman_numeral(player_id: int) -> String:
	"""Get the next Roman numeral for army naming based on existing armies"""
	var army_count = 0
	
	# Count all armies for this player across all regions
	if armies_by_player.has(player_id):
		army_count = armies_by_player[player_id].size()
	
	# Convert to Roman numeral (next number)
	return _int_to_roman(army_count + 1)

func _int_to_roman(num: int) -> String:
	"""Convert integer to Roman numeral"""
	if num <= 0:
		return "I"  # Default to I for invalid numbers
	
	var values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var symbols = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	
	var result = ""
	for i in range(values.size()):
		while num >= values[i]:
			result += symbols[i]
			num -= values[i]
	
	return result

func transfer_all_soldiers(donor: Army, receiver: Army) -> bool:
	"""Move all active and wounded soldiers from donor to receiver"""
	if donor == null or receiver == null or donor == receiver:
		return false
	var moved := false
	for soldier_type in SoldierTypeEnum.get_all_types():
		var count = donor.get_soldier_count(soldier_type)
		if count > 0:
			receiver.add_soldiers(soldier_type, count)
			donor.composition.set_soldier_count(soldier_type, 0)
			moved = true
	if donor.get_wounded_composition() != null:
		var receiver_wounded = receiver.get_wounded_composition()
		if receiver_wounded != null:
			for soldier_type in SoldierTypeEnum.get_all_types():
				var wounded = donor.get_wounded_composition().get_soldier_count(soldier_type)
				if wounded > 0:
					receiver_wounded.add_soldiers(soldier_type, wounded)
					donor.get_wounded_composition().set_soldier_count(soldier_type, 0)
	return moved

func calc_reinforcement_threshold(turn_number: int) -> float:
	"""Calculate the power threshold below which an army needs reinforcement"""
	# L1 max = 20; +3% per turn (linear scaling)
	# threshold = 20 * (1 + 0.03 * turn_number)
	# then * PEASANTS.power * 2
	var base_max := 20.0
	var scaled := base_max * (1.0 + 0.03 * float(turn_number))
	var peasant_power: int = GameParameters.get_unit_stat(SoldierTypeEnum.Type.PEASANTS, "power")
	return scaled * float(peasant_power) * 2.0

func remove_destroyed_armies() -> void:
	"""Remove armies that have no soldiers left after battle"""
	var dirty_players: Dictionary = {}
	for player_id in armies_by_player:
		var armies = armies_by_player[player_id]
		var i = 0
		while i < armies.size():
			var army = armies[i]
			if army == null or not is_instance_valid(army):
				armies.remove_at(i)
				continue
			
			# Check if army has no soldiers left
			if army.get_total_soldiers() <= 0:
				# Skip freshly raised AI armies that still need recruits
				if army.just_raised:
					i += 1
					continue
				DebugLogger.log("ArmyManagement", "Removing destroyed army: " + army.name)
				# Remove from scene
				if army.get_parent() != null:
					army.get_parent().remove_child(army)
				# Remove from previous regions tracking
				if army_previous_regions.has(army):
					army_previous_regions.erase(army)
				army.queue_free()
				# Remove from tracking
				armies.remove_at(i)
				dirty_players[player_id] = true
				continue
			
			i += 1
	if _ready_highlight_player_id != -1 and dirty_players.has(_ready_highlight_player_id):
		update_ready_highlights_for_player(_ready_highlight_player_id)

func remove_army_from_tracking(army: Army) -> void:
	"""Remove a specific army from tracking (used when army is defeated)"""
	if army == null:
		return
	
	var player_id = army.get_player_id()
	if armies_by_player.has(player_id):
		var armies = armies_by_player[player_id]
		var index = armies.find(army)
		if index != -1:
			armies.remove_at(index)
			DebugLogger.log("ArmyManagement", "Removed army " + army.name + " from player " + str(player_id) + " tracking")
			if player_id == _ready_highlight_player_id:
				update_ready_highlights_for_player(player_id)
	
	# Also remove from previous regions tracking
	if army_previous_regions.has(army):
		army_previous_regions.erase(army)

func get_previous_region_for_army(army: Army) -> Region:
	"""Access the previous region stored for an army (used for camera focus on retreat)."""
	if army_previous_regions.has(army):
		var previous = army_previous_regions[army]
		if previous is Region and is_instance_valid(previous):
			return previous
	return null

func retreat_army_to_previous_region(army: Army) -> void:
	"""Move army back to its previous region after withdrawal"""
	if army == null or not is_instance_valid(army):
		DebugLogger.log("ArmyManagement", "Cannot retreat: invalid army")
		return
	
	# Check if we have a previous region stored
	if not army_previous_regions.has(army):
		DebugLogger.log("ArmyManagement", "Warning: No previous region stored for army " + army.name)
		return
	
	var previous_region = army_previous_regions[army]
	if previous_region == null or not is_instance_valid(previous_region):
		DebugLogger.log("ArmyManagement", "Warning: Previous region is invalid for army " + army.name)
		army_previous_regions.erase(army)
		return
	
	DebugLogger.log("ArmyManagement", "Retreating army " + army.name + " to previous region")
	
	# Move army back to previous region, keep global start
	var current_parent = army.get_parent()
	var start_global := army.global_position
	if current_parent != null:
		current_parent.remove_child(army)
	previous_region.add_child(army)
	army.global_position = start_global
	# Reposition others in source, compute and animate target for this army, then apply others in dest
	if current_parent != null:
		_apply_army_offsets_for_region(current_parent)
	var target_local := _compute_army_target_position(previous_region, army)
	_apply_army_offsets_for_region(previous_region, army)
	var target_global: Vector2 = previous_region.to_global(target_local)
	var gm: GameManager = _get_game_manager()
	var is_ai_player: bool = gm.is_player_computer(army.get_player_id())
	var retreat_duration: float = GameParameters.get_move_animation_duration(is_ai_player)
	var retreat_tween: Tween = army.animate_move_to(target_global, retreat_duration, true)
	await retreat_tween.finished
	
	DebugLogger.log("ArmyManagement", "Army " + army.name + " retreated to " + previous_region.name)
	
	# Clear the previous region tracking since army is back there
	army_previous_regions.erase(army)
	update_ready_highlights_for_player(_ready_highlight_player_id)

func reposition_army_in_region_with_animation(army: Army) -> void:
	"""Re-apply offsets in the current region and animate the given army to its slot."""
	if army == null or not is_instance_valid(army):
		DebugLogger.log("ArmyManagement", "Cannot reposition: invalid army")
		return
	var region := army.get_parent() as Region
	if region == null:
		DebugLogger.log("ArmyManagement", "Cannot reposition: army has no region parent")
		return
	# Place other armies instantly, compute target for this one, then animate it
	var target_local := _compute_army_target_position(region, army)
	_apply_army_offsets_for_region(region, army)
	var target_global: Vector2 = region.to_global(target_local)
	var gm: GameManager = _get_game_manager()
	var is_ai_player: bool = gm.is_player_computer(army.get_player_id())
	var move_duration: float = GameParameters.get_move_animation_duration(is_ai_player)
	var tween := army.animate_move_to(target_global, move_duration, true)
	await tween.finished
	_apply_army_offsets_for_region(region)


func _should_show_human_arrows() -> bool:
	"""Check if human path arrows should be shown (only for human players)"""
	var game_manager = _get_game_manager()
	if game_manager == null:
		return true  # Default to showing arrows if GameManager not available
	
	var current_player_id = game_manager.get_current_player_id()
	return game_manager.is_player_human(current_player_id)
