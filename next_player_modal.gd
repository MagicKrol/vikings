extends Control
class_name NextPlayerModal

signal continue_acknowledged(player_id: int)

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
var continue_button: Button = null

# Timer for auto-hide
var hide_timer: Timer = null
var _manual_ack_required: bool = false
var _active_player_id: int = -1

func _ready():
	_resolve_ui_refs()
	
	# Initially hidden
	visible = false

func _resolve_ui_refs() -> void:
	ui_manager = get_node("../UIManager") as UIManager
	sound_manager = get_node("../../SoundManager") as SoundManager
	header_label = get_node("ContentContainer/HeaderLabel") as Label
	player_label = get_node("ContentContainer/PlayerLabel") as Label
	continue_button = get_node("ContentContainer/Button") as Button
	hide_timer = get_node("HideTimer") as Timer
	hide_timer.wait_time = DISPLAY_DURATION
	hide_timer.one_shot = true
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.add_theme_constant_override("outline_size", 5)
	player_label.add_theme_color_override("font_outline_color", Color.BLACK)
	if not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	if not hide_timer.timeout.is_connected(_on_timer_timeout):
		hide_timer.timeout.connect(_on_timer_timeout)

func show_next_player(player_id: int, turn_number: int, manual_ack_required: bool = false) -> void:
	"""Display next player modal with player-specific styling"""
	_resolve_ui_refs()
	var player_color = _get_player_label_color(GameParameters.get_player_color(player_id))
	_active_player_id = player_id
	_manual_ack_required = manual_ack_required
	
	header_label.text = "Turn " + str(turn_number)
	
	# Update player label with color-coded text
	player_label.add_theme_color_override("font_color", player_color)
	player_label.text = "Player " + str(player_id)
	
	# Show modal
	visible = true
	continue_button.visible = manual_ack_required
	continue_button.disabled = false
	
	# Set modal mode active (but allow it to be non-blocking)
	ui_manager.set_modal_active(true)
	
	# Start auto-hide timer only in non-blocking mode
	if not manual_ack_required:
		hide_timer.start()
	else:
		hide_timer.stop()

func _on_timer_timeout() -> void:
	"""Handle timer timeout - hide modal automatically"""
	hide_modal()

func _on_continue_pressed() -> void:
	_resolve_ui_refs()
	if sound_manager:
		sound_manager.click_sound()
	hide_modal()
	emit_signal("continue_acknowledged", _active_player_id)

func hide_modal() -> void:
	"""Hide the modal"""
	_resolve_ui_refs()
	visible = false
	
	# Stop timer if running
	if not hide_timer.is_stopped():
		hide_timer.stop()
	
	# Set modal mode inactive
	ui_manager.set_modal_active(false)

func _get_player_label_color(base_color: Color) -> Color:
	return Color.from_hsv(base_color.h, base_color.s, 0.6, base_color.a)
