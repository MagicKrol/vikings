extends Control
class_name TurnModal

# Game manager reference
var game_manager: GameManager = null
# UI manager reference
var ui_manager: UIManager = null
var tutorial_manager: TutorialManager = null
var end_turn_button: Button = null

func _ready():
	# Get manager references
	game_manager = get_node("../../GameManager") as GameManager
	ui_manager = get_node("../UIManager") as UIManager
	if game_manager:
		tutorial_manager = game_manager.get_tutorial_manager()
	mouse_entered.connect(_on_mouse_entered)
	DebugLogger.log("UIManager", "TurnModal ready, mouse_entered connected")
	DebugLogger.log("UIManager", "TurnModal mouse_filter=" + str(mouse_filter))
	var panel = get_node("Panel") as Control
	panel.mouse_entered.connect(_on_panel_mouse_entered)
	DebugLogger.log("UIManager", "TurnModal Panel mouse_filter=" + str(panel.mouse_filter))
	
	# Connect end turn button signal
	end_turn_button = get_node("Panel/VBoxContainer/Button/EndTurnButton") as Button
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	if tutorial_manager != null:
		end_turn_button.pressed.connect(func(): tutorial_manager.handle_ui_click("TurnModal/" + end_turn_button.name ))
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

	var current_player: int = game_manager.get_current_player()
	var player_color: Color = GameParameters.get_player_color(current_player)
	
	# Update turn number
	var turn_label = get_node("Panel/VBoxContainer/TurnNumber")
	if game_manager.is_castle_placing_mode():
		turn_label.text = tr("Place Castle")
	else:
		var turn_number: int = game_manager.get_current_turn()
		turn_label.text = tr("Turn {turn}").format({"turn": turn_number})

	# Update player display
	var player_label = get_node("Panel/VBoxContainer/Player")
	player_label.text = tr("Player %d") % current_player
	player_label.add_theme_color_override("font_color", player_color)

	# Update button text based on mode
	if game_manager.is_castle_placing_mode():
		end_turn_button.text = ""
		end_turn_button.disabled = false
	else:
		if game_manager.is_player_ai(current_player):
			end_turn_button.text = tr("in progress")
			end_turn_button.disabled = true
		else:
			end_turn_button.text = tr("END TURN")
			end_turn_button.disabled = false

func refresh_from_game_state() -> void:
	"""Refresh display from current game state"""
	update_turn_display()

func show_and_update() -> void:
	"""Show the modal and update it with current game state"""
	visible = true
	update_turn_display()

func set_end_turn_button_visible(is_visible: bool) -> void:
	end_turn_button = get_node("Panel/VBoxContainer/Button/EndTurnButton") as Button
	end_turn_button.visible = is_visible

func _on_end_turn_button_pressed():
	"""Handle end turn button press"""
	if ui_manager:
		ui_manager.close_all_active_modals()
	if game_manager:
		game_manager.handle_human_end_turn()
	else:
		DebugLogger.log("UISystem", "Error: Game manager not available")

func _on_mouse_entered() -> void:
	DebugLogger.log("UIManager", "TurnModal mouse entered. Hiding tooltip")
	ui_manager.hide_tooltip_due_to(self)

func _on_panel_mouse_entered() -> void:
	DebugLogger.log("UIManager", "TurnModal Panel mouse entered. Hiding tooltip")
	ui_manager.hide_tooltip_due_to(self)
