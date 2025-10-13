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
	mouse_entered.connect(_on_mouse_entered)
	DebugLogger.log("UIManager", "TurnModal ready, mouse_entered connected")
	DebugLogger.log("UIManager", "TurnModal mouse_filter=" + str(mouse_filter))
	var panel = get_node("Panel") as Control
	panel.mouse_entered.connect(_on_panel_mouse_entered)
	DebugLogger.log("UIManager", "TurnModal Panel mouse_filter=" + str(panel.mouse_filter))
	
	# Connect end turn button signal
	var end_turn_button = get_node("Panel/VBoxContainer/Button/EndTurnButton")
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	# In editor mode, keep hidden and skip updates
	if game_manager and game_manager.enable_map_editor:
		visible = false
		return
	# Make visible by default (non-editor) and update display
	visible = true
	call_deferred("update_turn_display")

func update_turn_display() -> void:
	"""Update the turn and player information display"""
	if not game_manager:
		return

	var current_player = game_manager.get_current_player()
	var player_color = _get_player_label_color(GameParameters.get_player_color(current_player))
	
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
	player_label.add_theme_color_override("font_color", player_color)

	# Update button text based on mode
	var end_turn_btn = get_node("Panel/VBoxContainer/Button/EndTurnButton")
	if game_manager.is_castle_placing_mode():
		end_turn_btn.text = "SKIP"
	else:
		end_turn_btn.text = "END TURN"

func _get_player_label_color(base_color: Color) -> Color:
	return Color.from_hsv(base_color.h, base_color.s, 0.6, base_color.a)

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

func _on_mouse_entered() -> void:
	DebugLogger.log("UIManager", "TurnModal mouse entered. Hiding tooltip")
	ui_manager.hide_tooltip_due_to(self)

func _on_panel_mouse_entered() -> void:
	DebugLogger.log("UIManager", "TurnModal Panel mouse entered. Hiding tooltip")
	ui_manager.hide_tooltip_due_to(self)
