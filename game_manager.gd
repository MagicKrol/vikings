extends Node
class_name GameManager

# Game state
var current_turn: int = 1
var current_player: int = 1
var total_players: int = 4

# Battle animation timing
const BATTLE_ROUND_TIME: float = 0.8  # Seconds between battle rounds

# Player management
var player_manager: PlayerManager

# References to other managers
var click_manager: Node = null

func _ready():
	# Initialize player management system
	player_manager = PlayerManager.new(total_players)
	
	# Find the click manager
	click_manager = get_node_or_null("../ClickManager")
	if click_manager == null:
		print("[GameManager] Warning: ClickManager not found")
	
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
	
	# Process resource income for all players
	player_manager.process_resource_income()
	
	# Reset movement points for all armies
	reset_movement_points()
	
	# Advance turn counter
	current_turn += 1
	
	# Advance to next player (cycle through players)
	current_player = (current_player % total_players) + 1
	player_manager.set_current_player(current_player)
	


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
