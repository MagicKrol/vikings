extends Control
class_name MessageModal

# Emitted when user clicks Continue
signal continue_clicked

# Styling constants (same as InfoModal)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

@onready var ui_manager: UIManager = get_node("../UIManager") as UIManager
@onready var sound_manager: SoundManager = get_node("../../SoundManager") as SoundManager
@onready var message_label: Label = get_node("PanelRoot/ContentContainer/MessageLabel")
@onready var continue_button: Button = get_node("PanelRoot/ContentContainer/ContinueButton")

func _ready():
	visible = false
	continue_button.pressed.connect(_on_continue_pressed)

func displayMessage(text: String) -> void:
	message_label.text = text
	_show_modal()

func display_message(header: String, message: String = "") -> void:
	if message.is_empty():
		displayMessage(header)
		return
	displayMessage(header + "\n\n" + message)

func hide_modal() -> void:
	_hide_modal()

func _show_modal() -> void:
	visible = true
	ui_manager.set_modal_active(true)

func _hide_modal() -> void:
	visible = false
	ui_manager.set_modal_active(false)

func _on_continue_pressed() -> void:
	sound_manager.click_sound()
	emit_signal("continue_clicked")
	_hide_modal()

func _draw():
	pass
