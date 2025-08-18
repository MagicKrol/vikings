extends Node
class_name GameManager

# Game state
var current_turn: int = 1
var current_player: int = 1
var total_players: int = 4

# Battle animation timing
# Battle timing now managed in GameParameters.gd

# Player management
var player_manager: PlayerManager

# References to other managers
var click_manager: Node = null

func _ready():
	# Find the click manager first (needed for RegionManager)
	click_manager = get_node_or_null("../ClickManager")
	if click_manager == null:
		push_error("[GameManager] CRITICAL: ClickManager not found - game cannot function")
		return
	
	# Wait for ClickManager to initialize RegionManager
	await get_tree().process_frame
	
	# Get RegionManager and MapGenerator - these are required components
	var region_manager: RegionManager = null
	var map_generator: MapGenerator = null
	
	if click_manager.has_method("get_region_manager"):
		region_manager = click_manager.get_region_manager()
	
	if region_manager == null:
		push_error("[GameManager] CRITICAL: RegionManager not available - resource system cannot function")
		return
	
	map_generator = get_node_or_null("../Map") as MapGenerator
	if map_generator == null:
		push_error("[GameManager] CRITICAL: MapGenerator not found - resource system cannot function")  
		return
	
	# Initialize player management system with required components
	player_manager = PlayerManager.new(total_players, region_manager, map_generator)
	
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

func _update_player_status_display() -> void:
	"""Update the player status display when resources or player changes"""
	print("[GameManager] Updating player status display...")
	
	var ui_node = get_node_or_null("../UI")
	if ui_node == null:
		print("[GameManager] ERROR: UI node not found")
		return
	
	var player_status_modal = ui_node.get_node_or_null("PlayerStatusModal") as PlayerStatusModal
	if player_status_modal == null:
		print("[GameManager] ERROR: PlayerStatusModal not found")
		return
	
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
func get_player_manager() -> PlayerManager:
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
