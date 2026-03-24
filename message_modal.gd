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
const CLOSE_KEYCODES: Array[int] = [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]

@onready var ui_manager: UIManager = get_node("../UIManager") as UIManager
@onready var sound_manager: SoundManager = get_node("../../SoundManager") as SoundManager
@onready var message_label: Label = get_node("PanelRoot/ContentContainer/MessageLabel")
@onready var continue_button: Button = get_node("PanelRoot/ContentContainer/ContinueButton")
@onready var panel_root: Control = get_node("PanelRoot")
var original_panel_offsets: Rect2

func _ready():
	visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	original_panel_offsets = Rect2(
		panel_root.position,
		panel_root.size
	)

func displayMessage(text: String) -> void:
	continue_button.visible = true
	message_label.text = text
	_set_mouse_block(true)
	_show_modal()

func display_message(header: String, message: String = "") -> void:
	if message.is_empty():
		displayMessage(header)
		return
	displayMessage(header + "\n\n" + message)

func show_tutorial_message(text: String, show_continue: bool, block_input: bool) -> void:
	message_label.text = text
	continue_button.visible = show_continue
	_set_mouse_block(block_input)
	_move_modal_to_front()
	visible = true
	if block_input:
		ui_manager.set_modal_active(true)
	else:
		ui_manager.set_modal_active(false)

func hide_modal() -> void:
	_hide_modal()

func _show_modal() -> void:
	_move_modal_to_front()
	visible = true
	ui_manager.set_modal_active(true)

func _hide_modal() -> void:
	visible = false
	ui_manager.set_modal_active(false)

func _on_continue_pressed() -> void:
	sound_manager.click_sound()
	emit_signal("continue_clicked")
	_hide_modal()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and CLOSE_KEYCODES.has(key_event.keycode):
			_on_continue_pressed()
			get_viewport().set_input_as_handled()

func _draw():
	pass

func _set_mouse_block(blocked: bool) -> void:
	var mode = Control.MOUSE_FILTER_STOP if blocked else Control.MOUSE_FILTER_IGNORE
	mouse_filter = mode
	if panel_root:
		panel_root.mouse_filter = mode

func _move_modal_to_front() -> void:
	move_to_front()

func set_panel_position(pos: Vector2) -> void:
	panel_root.position = pos

func reset_panel_position() -> void:
	panel_root.position = original_panel_offsets.position
