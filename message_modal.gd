extends Control
class_name MessageModal

# Styling constants (same as InfoModal)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# UI manager reference for modal mode
var ui_manager: UIManager = null
# Sound manager reference
var sound_manager: SoundManager = null

# UI elements
var header_label: Label = null
var message_label: Label = null
var continue_button: Button = null

func _ready():
	# Get references
	ui_manager = get_node("../UIManager") as UIManager
	sound_manager = get_node("../../SoundManager") as SoundManager
	
	# Get UI element references
	header_label = get_node("ContentContainer/HeaderLabel") as Label
	message_label = get_node("ContentContainer/MessageLabel") as Label
	continue_button = get_node("ContentContainer/ContinueButton") as Button
	
	# Connect button signal
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	
	# Initially hidden
	visible = false

func display_message(header: String, message: String) -> void:
	"""Display a message modal with header and message text"""
	if header_label:
		header_label.text = header
	
	if message_label:
		message_label.text = message
	
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)

func _on_continue_pressed() -> void:
	"""Handle Continue button press - hide modal"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	hide_modal()

func hide_modal() -> void:
	"""Hide the modal"""
	visible = false
	
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