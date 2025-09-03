extends Control
class_name TurnModal

# Game manager reference
var game_manager: GameManager = null
# UI manager reference
var ui_manager: UIManager = null

func _ready():
	# Get manager references
	game_manager = get_node("../../GameManager") as GameManager
	ui_manager = get_node("../UIManager") as UIManager
	
	# Connect end turn button signal
	var end_turn_button = get_node("Panel/VBoxContainer/EndTurnButton")
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	
	# Make visible by default
	visible = true
	
	# Update display immediately when ready
	call_deferred("update_turn_display")

func update_turn_display() -> void:
	"""Update the turn and player information display"""
	if not game_manager:
		return
	
	var current_player = game_manager.get_current_player()
	var player_color = GameParameters.get_player_color(current_player)
	
	# Update turn number
	var turn_label = get_node("Panel/VBoxContainer/TurnNumber")
	if game_manager.is_castle_placing_mode():
		turn_label.text = "Place Castle"
	else:
		var turn_number = game_manager.get_current_turn()
		turn_label.text = "Turn " + str(turn_number)
	
	# Update player display
	var player_label = get_node("Panel/VBoxContainer/Player")
	player_label.text = "Player " + str(current_player)
	
	# Apply player color to text
	player_label.modulate = player_color
	
	# Update button text based on mode
	var end_turn_btn = get_node("Panel/VBoxContainer/EndTurnButton")
	if game_manager.is_castle_placing_mode():
		end_turn_btn.text = "SKIP"
	else:
		end_turn_btn.text = "END TURN"

func refresh_from_game_state() -> void:
	"""Refresh display from current game state"""
	update_turn_display()

func show_and_update() -> void:
	"""Show the modal and update it with current game state"""
	visible = true
	update_turn_display()

func _on_end_turn_button_pressed():
	"""Handle end turn button press"""
	if game_manager:
		game_manager.next_turn()
	else:
		DebugLogger.log("UISystem", "Error: Game manager not available")
