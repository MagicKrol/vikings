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

func _find_army_modal() -> void:
	"""Find and store reference to the army modal"""
	# This will be called later when the scene is ready
	# For now, we'll set it to null and find it when needed

func create_army(region_container: Node, player_id: int, is_raised: bool = false) -> Army:
	"""Create a new army in the specified region"""
	if is_raised:
		DebugLogger.log("ArmyManagement", "create_army called for raised army, player " + str(player_id) + " in region " + region_container.name)
	
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
		army.setup_army(player_id, roman_number)
	
	# Position army at region center with appropriate offset
	var polygon := region_container.get_node_or_null("Polygon") as Polygon2D
	if polygon != null:
		var center_meta = polygon.get_meta("center")
		if center_meta != null:
			var center := center_meta as Vector2
			army.position = center + _get_army_position_offset(region_container)
	
	# Add army to region container
	region_container.add_child(army)
	
	# Track army in our dictionary
	if not armies_by_player.has(player_id):
		armies_by_player[player_id] = []
	armies_by_player[player_id].append(army)
	
	if is_raised:
		DebugLogger.log("ArmyManagement", "Raised new army for player " + str(player_id) + " in region " + region_container.name)
	
	return army

func create_raised_army(region_container: Node, player_id: int) -> Army:
	"""Create a new raised army with 0 movement points and no soldiers"""
	return create_army(region_container, player_id, true)

func _get_army_position_offset(region_container: Node) -> Vector2:
	"""Get the appropriate position offset for army based on region contents"""
	# Check if there's a castle in the region
	var castle = region_container.get_node_or_null("Castle")
	if castle != null:
		return Vector2(15, 0)  # Army positioned to the right of castle
	
	# Default positioning when no castle is present
	return Vector2(0, -5)  # Army positioned slightly above center

func select_army(army: Army, region_container: Node, current_player_id: int = -1) -> void:
	"""Select an army for movement - only allow selecting armies owned by current player"""
	if army == null or not is_instance_valid(army):
		return
	
	if region_container == null:
		return
	
	# Check if army belongs to current player (if current_player_id is provided)
	if current_player_id != -1 and army.get_player_id() != current_player_id:
		DebugLogger.log("ArmyManagement", "Cannot select army owned by Player " + str(army.get_player_id()) + " (current player is " + str(current_player_id) + ")")
		return
	
	selected_army = army
	selected_region_container = region_container

	# Show army modal
	if army_modal != null:
		army_modal.show_army_info(army)

	# Only show move arrows for human players
	if _should_show_human_arrows():
		_show_move_arrows(region_container)

func deselect_army() -> void:
	"""Deselect the currently selected army"""
	selected_army = null
	selected_region_container = null

	# Hide army modal
	if army_modal != null:
		army_modal.hide_modal()

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
	var result = move_army_to_region(target_region)
	
	# Restore previous selection
	selected_army = previous_selection
	selected_region_container = previous_region
	
	return result

func move_army_to_region(target_region_container: Node) -> bool:
	"""Move the selected army to the target region. Returns true if successful."""
	# Validate prerequisites
	if not _validate_movement_prerequisites(target_region_container):
		return false
	
	# Get region IDs from Region scripts
	var source_region = selected_region_container
	var target_region_node = target_region_container
	if not source_region.has_method("get_region_id") or not target_region_node.has_method("get_region_id"):
		DebugLogger.log("ArmyManagement", "Error: Region containers don't have get_region_id method")
		return false
	
	var source_region_id = source_region.get_region_id()
	var target_region_id = target_region_node.get_region_id()
	
	# Check if target region is a neighbor of source region
	var neighbors = region_manager.get_neighbor_regions(source_region_id)
	if not neighbors.has(target_region_id):

		return false
	
	# Get terrain cost once for the entire function (with ownership bonus)
	var terrain_cost = get_terrain_cost(target_region_container, selected_army.get_player_id())
	
	# Check if army can move to this region
	if not can_army_move_to_region(selected_army, target_region_container):
		var check_region = target_region_container as Region
		if check_region != null and not check_region.is_passable():
			var _region_type_name = RegionTypeEnum.type_to_string(check_region.get_region_type())
		else:
			var current_points = selected_army.get_movement_points()
			DebugLogger.log("ArmyManagement", "Movement blocked - not enough movement points (need " + str(terrain_cost) + ", have " + str(current_points) + ")")
		return false
	
	# Battle conditions will be handled after movement by click_manager
	var target_region = target_region_container as Region
	
	# Store previous region for potential retreat
	army_previous_regions[selected_army] = selected_region_container
	
	# Move the army
	selected_army.get_parent().remove_child(selected_army)
	target_region_container.add_child(selected_army)
	
	# Update army position to new region center
	var polygon = target_region_container.get_node_or_null("Polygon") as Polygon2D
	if polygon != null:
		var center_meta = polygon.get_meta("center")
		if center_meta != null:
			var center = center_meta as Vector2
			selected_army.position = center + _get_army_position_offset(target_region_container)
	
	# Check if we should change ownership (only for already owned regions or friendly moves)
	var target_region_owner = region_manager.get_region_owner(target_region_id)
	var army_player_id = selected_army.player_id
	
	# Only set ownership if ownership is actually changing (neutral territory without garrison)
	if target_region_owner == -1 and not target_region.has_garrison():
		var game_manager = _get_game_manager()
		if game_manager:
			game_manager.claim_peaceful_region(target_region_id, army_player_id)
		else:
			DebugLogger.log("ArmyManagement", "Warning: Could not get GameManager for peaceful region claiming")
	
	# Deduct movement points
	selected_army.spend_movement_points(terrain_cost)

	# Reduce efficiency by 5 for movement
	selected_army.reduce_efficiency(5)

	# Store remaining movement points for logging
	var remaining_points = selected_army.get_movement_points()
	# Per-move debug: region, cost, MP left this turn
	DebugLogger.log("ArmyManagement", "Moved to region %d, Cost: %d, MP left: %d/%d" % [target_region_id, terrain_cost, remaining_points, GameParameters.MOVEMENT_POINTS_PER_TURN])
	
	# Check if we moved to an unowned region - handle combat scenarios
	if target_region_owner != army_player_id and target_region_owner != -1:
		# Moved to enemy territory - trigger combat
		_trigger_combat_if_needed(selected_army, target_region)
		DebugLogger.log("ArmyManagement", "Army moved to enemy territory (cost: " + str(terrain_cost) + ", remaining points: " + str(remaining_points) + ") - combat triggered")
	elif target_region_owner == -1 and target_region.has_garrison():
		# Moved to neutral territory with garrison - trigger combat
		_trigger_combat_if_needed(selected_army, target_region)
		DebugLogger.log("ArmyManagement", "Army moved to neutral territory with garrison (cost: " + str(terrain_cost) + ", remaining points: " + str(remaining_points) + ") - combat triggered")
	else:
		# Moved to friendly territory - keep army selected
		# Update selected region container to the new region
		selected_region_container = target_region_container
		
		# Clear old arrows and show new ones for the new position (only for human players)
		_clear_move_arrows()
		if _should_show_human_arrows():
			_show_move_arrows(target_region_container)
		
		# Update army modal with new movement points
		if army_modal != null and selected_army != null:
			army_modal.show_army_info(selected_army, false)  # Don't manage modal mode - allow continued movement
		
		DebugLogger.log("ArmyManagement", "Army moved to friendly territory (cost: " + str(terrain_cost) + ", remaining points: " + str(remaining_points) + ")")
	
	DebugLogger.log("ArmyManagement", "Army moved (cost: " + str(terrain_cost) + ", remaining points: " + str(remaining_points) + ")")
	
	# Play click sound for successful army movement
	if sound_manager:
		sound_manager.click_sound()
	
	return true

func _show_move_arrows(region_container: Node) -> void:
	"""Show arrows pointing to all available move destinations"""
	# Clear any existing arrows first
	_clear_move_arrows()
	
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
		
		# Create arrow (disabled if cannot move)
		var arrow = _create_move_arrow(source_center, neighbor_center, !can_move)
		if arrow != null:
			move_arrows.append(arrow)
			arrows_container.add_child(arrow)
	


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
	
	# Scale the arrow
	arrow.scale = Vector2(0.2, 0.2)
	
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
			# If AI modal disabled, let GameManager.perform_region_entry handle battle; skip showing modal here
			if game_manager.debug_disable_battle_modal and game_manager.is_player_computer(attacking_army.get_player_id()):
				return
			var battle_manager = game_manager.get_battle_manager()
			if battle_manager:
				# Set up battle through BattleManager
				battle_manager.set_pending_conquest(attacking_army, defending_region)
				DebugLogger.log("ArmyManagement", "Combat triggered: Army " + attacking_army.name + " vs Region " + defending_region.get_region_name())
				
				# Show battle modal for AI combat (non-interactive)
				if battle_modal:
					battle_modal.show_battle(attacking_army, defending_region)
				
				# Deselect army since combat is now handling it
				deselect_army()
				return
		
		DebugLogger.log("ArmyManagement", "Warning: Could not trigger combat - BattleManager not available")

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
				continue
			
			i += 1

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
	
	# Also remove from previous regions tracking
	if army_previous_regions.has(army):
		army_previous_regions.erase(army)

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
	
	# Move army back to previous region
	var current_parent = army.get_parent()
	if current_parent != null:
		current_parent.remove_child(army)
	
	previous_region.add_child(army)
	
	# Update army position to previous region center
	var polygon = previous_region.get_node_or_null("Polygon") as Polygon2D
	if polygon != null:
		var center_meta = polygon.get_meta("center")
		if center_meta != null:
			var center = center_meta as Vector2
			army.position = center + _get_army_position_offset(previous_region)
	
	DebugLogger.log("ArmyManagement", "Army " + army.name + " retreated to " + previous_region.name)
	
	# Clear the previous region tracking since army is back there
	army_previous_regions.erase(army)

func _should_show_human_arrows() -> bool:
	"""Check if human path arrows should be shown (only for human players)"""
	var game_manager = _get_game_manager()
	if game_manager == null:
		return true  # Default to showing arrows if GameManager not available
	
	var current_player_id = game_manager.get_current_player_id()
	return game_manager.is_player_human(current_player_id)
