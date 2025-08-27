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
var player_label: RichTextLabel = null

# Timer for auto-hide
var hide_timer: Timer = null

func _ready():
	# Get references
	ui_manager = get_node("../UIManager") as UIManager
	sound_manager = get_node("../../SoundManager") as SoundManager
	
	# Get UI element references
	header_label = get_node("ContentContainer/HeaderLabel") as Label
	player_label = get_node("ContentContainer/PlayerLabel") as RichTextLabel
	
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
	var player_color = GameParameters.get_player_color(player_id)
	var color_hex = "#%02x%02x%02x" % [int(player_color.r * 255), int(player_color.g * 255), int(player_color.b * 255)]
	
	# Update header based on mode
	if is_castle_mode:
		if header_label:
			header_label.text = "Castle Placement"
	else:
		if header_label:
			header_label.text = "Next Turn"
	
	# Update player label with color-coded text
	if player_label:
		if is_castle_mode:
			player_label.text = "[center][color=" + color_hex + "]Player " + str(player_id) + "[/color]\nPlace Your Castle[/center]"
		else:
			player_label.text = "[center][color=" + color_hex + "]Player " + str(player_id) + "'s Turn[/color][/center]"
	
	# Show modal
	visible = true
	
	# Set modal mode active (but allow it to be non-blocking)
	if ui_manager:
		ui_manager.set_modal_active(true)
	
	# Start auto-hide timer
	if hide_timer:
		hide_timer.start()
	
	# Play notification sound
	if sound_manager:
		sound_manager.click_sound()

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

func _draw():
	# Draw shadow first (behind everything)
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)
	
	# Draw background fill
	var bg_rect = Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, FRAME_COLOR)
	
	# Draw black border on top
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)