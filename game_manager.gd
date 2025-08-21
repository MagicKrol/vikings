extends Node
class_name GameManager

# ============================================================================
# GAME MANAGER
# ============================================================================
# 
# Purpose: Central game state coordination and high-level game flow management
# 
# Core Responsibilities:
# - Game state management (turns, players, game modes)
# - Manager initialization and dependency injection
# - High-level game flow coordination (castle placement, conquest)
# - Turn management and resource processing
# 
# Required Functions:
# - next_turn(): Process turn advancement and updates
# - initialize_managers(): Set up all game systems
# - handle_castle_placement(): Coordinate castle placement flow
# - get/set game state: Access to current turn, player, mode
# 
# Integration Points:
# - PlayerManager: Resource and player state management
# - All other managers: Initialization and coordination
# - UI systems: Game state updates and notifications
# ============================================================================

# Game state
var current_turn: int = 1
var current_player: int = 1
var total_players: int = 4

# Game mode state
var castle_placing_mode: bool = true

# Player management
var player_manager: PlayerManagerNode

# Manager references
var _region_manager: RegionManager
var _army_manager: ArmyManager
var _battle_manager: BattleManager
var _visual_manager: VisualManager
var _ui_manager: UIManager

# Modal references  
var _battle_modal: BattleModal
var _sound_manager: SoundManager

# References to other managers
var click_manager: Node = null

func _ready():
	# Initialize all game systems
	initialize_managers()
	
	# Start the game audio sequence after a brief delay to ensure sound manager is ready
	await get_tree().process_frame
	if _sound_manager:
		print("[GameManager] Starting game audio sequence...")
		_sound_manager.play_game_start_sequence()
	else:
		print("[GameManager] Error: Sound manager not found!")

func initialize_managers():
	"""Initialize all game managers and establish dependencies"""
	# Get core components - these are required
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	
	# Initialize core managers directly
	_region_manager = RegionManager.new(map_generator)
	if _region_manager == null:
		push_error("[GameManager] CRITICAL: Failed to create RegionManager")
		return
		
	_army_manager = ArmyManager.new(map_generator, _region_manager)
	if _army_manager == null:
		push_error("[GameManager] CRITICAL: Failed to create ArmyManager")
		return
	
	# Find the click manager and provide it with manager references
	click_manager = get_node("../ClickManager")
	# Provide managers to ClickManager for backward compatibility
	if click_manager.has_method("set_managers"):
		click_manager.set_managers(_region_manager, _army_manager)
	
	# Get UI components
	var ui_node = get_node("../UI")
	_battle_modal = ui_node.get_node("BattleModal") as BattleModal
	_ui_manager = ui_node.get_node("UIManager") as UIManager
	
	# Connect UI components to ArmyManager
	var army_modal = ui_node.get_node("InfoModal") as InfoModal
	if _army_manager:
		_army_manager.set_army_modal(army_modal)
		_army_manager.set_battle_modal(_battle_modal)
	
	_sound_manager = get_node("../SoundManager") as SoundManager
	
	# Connect sound manager to ArmyManager
	if _army_manager:
		_army_manager.set_sound_manager(_sound_manager)
	
	# Initialize specialized managers
	_battle_manager = BattleManager.new(_region_manager, _army_manager, _battle_modal, _sound_manager)
	_visual_manager = VisualManager.new(map_generator, _region_manager, _army_manager)
	
	# Get the PlayerManager node and initialize it with required components
	player_manager = get_node("../PlayerManager") as PlayerManagerNode
	if player_manager:
		player_manager.initialize_with_managers(_region_manager, map_generator)
		player_manager.set_army_manager(_army_manager)
	
	# Run battle system test on startup (remove this after testing)
	BattleSimulator.run_test_battle()
	
	# Print initial player resources
	print("[GameManager] Game initialized with ", total_players, " players")
	player_manager.print_all_resources()

func _unhandled_input(event: InputEvent) -> void:
	# Handle Enter key to end turn
	if event is InputEventKey and event.pressed:

		if event.keycode == KEY_ENTER:

			next_turn()

func next_turn():
	"""Advance to the next turn and perform turn-based actions"""
	
	print("[GameManager] === Starting turn ", current_turn + 1, " ===")
	
	# Process resource income for all players
	print("[GameManager] Processing resource income...")
	player_manager.process_resource_income()
	
	# Deduct food costs for armies and garrisons
	print("[GameManager] Deducting army food costs...")
	_process_army_food_costs()
	
	# Grow population for all regions (before recruit replenishment)
	print("[GameManager] Growing regional populations...")
	if _region_manager:
		_region_manager.grow_all_populations()
	
	# Replenish recruits for all regions (after population growth)
	print("[GameManager] Replenishing recruits...")
	if _region_manager:
		_region_manager.replenish_all_recruits()
	
	# Reset movement points for all armies
	reset_movement_points()
	
	# Advance turn counter
	current_turn += 1
	
	# Stay on Player 1 (human player) - no AI players for now
	current_player = 1
	player_manager.set_current_player(current_player)
	
	# Update player status display
	print("[GameManager] Turn ", current_turn, " - Player 1 continues")
	_update_player_status_display()
	


func reset_movement_points():
	"""Reset movement points for all armies on the map"""

	if click_manager != null:
		var army_manager = click_manager.get_army_manager()
		if army_manager != null:

			army_manager.reset_all_army_movement_points()
		else:
			print("[GameManager] Warning: Cannot reset army moves - ArmyManager not found")
	else:
		print("[GameManager] Warning: Cannot reset army moves - ClickManager not found")

func _process_army_food_costs() -> void:
	"""Process food costs for all armies and garrisons"""
	# Currently only processing for Player 1 (human player)
	var player_id = 1
	var player = player_manager.get_player(player_id)
	if player == null:
		print("[GameManager] Warning: Player 1 not found for food cost processing")
		return
	
	# Calculate total food cost for all armies and garrisons
	var total_food_cost = player_manager.calculate_total_army_food_cost(player_id)
	
	if total_food_cost > 0:
		# Convert float cost to integer (round up)
		var food_cost_int = int(ceil(total_food_cost))
		
		print("[GameManager] Total army food cost for Player 1: ", total_food_cost, " (rounded: ", food_cost_int, ")")
		
		# Check if player has enough food
		var current_food = player.get_resource_amount(ResourcesEnum.Type.FOOD)
		if current_food >= food_cost_int:
			# Deduct the food cost
			player.remove_resources(ResourcesEnum.Type.FOOD, food_cost_int)
			print("[GameManager] Deducted ", food_cost_int, " food from Player 1 (", current_food - food_cost_int, " remaining)")
		else:
			# Player doesn't have enough food - this could lead to penalties
			print("[GameManager] WARNING: Player 1 doesn't have enough food! Required: ", food_cost_int, ", Available: ", current_food)
			# For now, just deduct all available food
			if current_food > 0:
				player.remove_resources(ResourcesEnum.Type.FOOD, current_food)
				print("[GameManager] Deducted all available food (", current_food, ") from Player 1")
	else:
		print("[GameManager] No army food costs for Player 1")

func _update_player_status_display() -> void:
	"""Update the player status display when resources or player changes"""
	print("[GameManager] Updating player status display...")
	
	var ui_node = get_node("../UI")
	var player_status_modal = ui_node.get_node("PlayerStatusModal") as PlayerStatusModal
	
	print("[GameManager] Calling PlayerStatusModal.refresh_from_game_state()")
	player_status_modal.refresh_from_game_state()

func get_current_turn() -> int:
	"""Get the current turn number"""
	return current_turn

func get_current_player() -> int:
	"""Get the current player number"""
	return current_player

func get_total_players() -> int:
	"""Get the total number of players"""
	return total_players

# Player resource management
func get_player_manager() -> PlayerManagerNode:
	"""Get the player manager instance"""
	return player_manager

func get_current_player_data() -> Player:
	"""Get the current player's data"""
	if player_manager == null:
		return null
	return player_manager.get_current_player()

func get_player_resources(player_id: int) -> Dictionary:
	"""Get all resources for a specific player"""
	if player_manager == null:
		return {}
	var player = player_manager.get_player(player_id)
	if player == null:
		return {}
	return player.get_all_resources()

func add_player_resources(player_id: int, resource_type: ResourcesEnum.Type, amount: int) -> bool:
	"""Add resources to a player"""
	if player_manager == null:
		return false
	return player_manager.add_resources_to_player(player_id, resource_type, amount)

func can_player_afford(player_id: int, cost: Dictionary) -> bool:
	"""Check if a player can afford a cost"""
	if player_manager == null:
		return false
	return player_manager.can_player_afford_cost(player_id, cost)

func charge_player(player_id: int, cost: Dictionary) -> bool:
	"""Charge a player for a cost"""
	if player_manager == null:
		return false
	return player_manager.charge_player(player_id, cost)

# Game state accessors
func is_castle_placing_mode() -> bool:
	"""Check if the game is in castle placing mode"""
	return castle_placing_mode

func set_castle_placing_mode(enabled: bool) -> void:
	"""Set castle placing mode"""
	castle_placing_mode = enabled

func get_current_player_id() -> int:
	"""Get the current active player ID"""
	return current_player

# Game flow coordination
func handle_castle_placement(region: Region) -> void:
	"""Coordinate the complete castle placement flow"""
	if not castle_placing_mode:
		return
		
	var region_id = region.get_region_id()
	
	# Set castle starting position (this will also claim neighboring regions)
	if _region_manager:
		_region_manager.set_castle_starting_position(region_id, current_player)
	
	# Upgrade castle region and neighboring regions
	if _region_manager:
		_region_manager.upgrade_castle_regions(region)
	
	# Update region visuals to show ownership
	if _visual_manager:
		_visual_manager.update_region_visuals()
	
	# Place castle visual
	if _visual_manager:
		var regions_node = get_node("../Map/Regions")
		for child in regions_node.get_children():
			if child is Region and child.get_region_id() == region_id:
				_visual_manager.place_castle_visual(child)
				break
	
	# Place army in the same region
	if _visual_manager:
		var regions_node = get_node("../Map/Regions")
		for child in regions_node.get_children():
			if child is Region and child.get_region_id() == region_id:
				_visual_manager.place_army_visual(child, current_player)
				break
	
	# End castle placing mode after placing one castle
	castle_placing_mode = false
	
	# Show player status modal with current state
	if _ui_manager:
		var player_status_modal = _ui_manager.get_player_status_modal()
		if player_status_modal:
			player_status_modal.show_and_update()
	
	# Play sound
	if _sound_manager:
		_sound_manager.click_sound()

# Manager accessors for external systems
func get_battle_manager() -> BattleManager:
	"""Get the BattleManager instance"""
	return _battle_manager

func get_visual_manager() -> VisualManager:
	"""Get the VisualManager instance"""
	return _visual_manager

func get_region_manager() -> RegionManager:
	"""Get the RegionManager instance"""
	return _region_manager

func get_army_manager() -> ArmyManager:
	"""Get the ArmyManager instance"""
	return _army_manager
