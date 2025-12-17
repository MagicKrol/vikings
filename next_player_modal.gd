extends Control
class_name NextPlayerModal

# Styling constants (same as MessageModal)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# Auto-hide timer duration
const DISPLAY_DURATION = 0.5

# UI manager reference for modal mode
var ui_manager: UIManager = null
# Sound manager reference
var sound_manager: SoundManager = null

# UI elements
var header_label: Label = null
var player_label: Label = null

# Timer for auto-hide
var hide_timer: Timer = null

func _ready():
	# Get references
	ui_manager = get_node("../UIManager") as UIManager
	sound_manager = get_node("../../SoundManager") as SoundManager
	
	# Get UI element references
	header_label = get_node("ContentContainer/HeaderLabel") as Label
	player_label = get_node("ContentContainer/PlayerLabel") as Label
	if player_label:
		player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_label.add_theme_constant_override("outline_size", 5)
		player_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Create and configure timer
	hide_timer = Timer.new()
	hide_timer.wait_time = DISPLAY_DURATION
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_timer_timeout)
	add_child(hide_timer)
	
	# Initially hidden
	visible = false

func show_next_player(player_id: int, is_castle_mode: bool = false) -> void:
	"""Display next player modal with player-specific styling"""
	var player_color = _get_player_label_color(GameParameters.get_player_color(player_id))
	
	# Update header based on mode
	if is_castle_mode:
		if header_label:
			header_label.text = "Place your castle"
	else:
		if header_label:
			header_label.text = "Your turn"
	
	# Update player label with color-coded text
	if player_label:
		player_label.add_theme_color_override("font_color", player_color)
		if is_castle_mode:
			player_label.text = "Player " + str(player_id)
		else:
			player_label.text = "Player " + str(player_id)
	
	# Show modal
	visible = true
	
	# Set modal mode active (but allow it to be non-blocking)
	if ui_manager:
		ui_manager.set_modal_active(true)
	
	# Start auto-hide timer
	if hide_timer:
		hide_timer.start()

func _on_timer_timeout() -> void:
	"""Handle timer timeout - hide modal automatically"""
	hide_modal()

func hide_modal() -> void:
	"""Hide the modal"""
	visible = false
	
	# Stop timer if running
	if hide_timer and not hide_timer.is_stopped():
		hide_timer.stop()
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _get_player_label_color(base_color: Color) -> Color:
	return Color.from_hsv(base_color.h, base_color.s, 0.6, base_color.a)
