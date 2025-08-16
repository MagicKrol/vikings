extends Node
class_name GameManager

# Game state
var current_turn: int = 1
var current_player: int = 1
var total_players: int = 4

# References to other managers
var click_manager: Node = null

func _ready():
	# Find the click manager
	click_manager = get_node_or_null("../ClickManager")
	if click_manager == null:
		print("[GameManager] Warning: ClickManager not found")

func _unhandled_input(event: InputEvent) -> void:
	# Handle Enter key to end turn
	if event is InputEventKey and event.pressed:

		if event.keycode == KEY_ENTER:

			next_turn()

func next_turn():
	"""Advance to the next turn and perform turn-based actions"""

	
	# Reset movement points for all armies
	reset_movement_points()
	
	# Advance turn counter
	current_turn += 1
	
	# Advance to next player (cycle through players)
	current_player = (current_player % total_players) + 1
	


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
