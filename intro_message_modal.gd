extends MessageModal
class_name IntroMessageModal

# Dedicated intro modal; inherits all behavior from MessageModal
const PLACE_CASTLE_BUTTON_TEXT: String = "Place Castle"
const CONTINUE_BUTTON_TEXT: String = "Continue"
const END_MISSION_BUTTON_TEXT: String = "End Mission"
@onready var message_scroll: ScrollContainer = get_node("PanelRoot/ContentContainer/MessageScroll") as ScrollContainer
@onready var scroll_message_label: Label = get_node("PanelRoot/ContentContainer/MessageScroll/ScrollMessageLabel") as Label

func _ready() -> void:
	super._ready()
	_set_modal_text(message_label.text)

func displayMessage(_text: String) -> void:
	# Keep the baked-in intro text; only show and block input like base class
	continue_button.text = tr(PLACE_CASTLE_BUTTON_TEXT)
	continue_button.visible = true
	_set_modal_text(scroll_message_label.text)
	_set_mouse_block(true)
	_show_modal()

func display_intro_text(text: String) -> void:
	continue_button.text = tr(CONTINUE_BUTTON_TEXT)
	continue_button.visible = true
	_set_modal_text(tr(text))
	_set_mouse_block(true)
	_show_modal()

func display_default_intro_text_with_continue() -> void:
	continue_button.text = tr(CONTINUE_BUTTON_TEXT)
	continue_button.visible = true
	_set_modal_text(scroll_message_label.text)
	_set_mouse_block(true)
	_show_modal()

func display_outro_text(text: String) -> void:
	continue_button.text = tr(END_MISSION_BUTTON_TEXT)
	continue_button.visible = true
	_set_modal_text(tr(text))
	_set_mouse_block(true)
	_show_modal()

func display_message(_header: String, _message: String = "") -> void:
	# Preserve default label text
	displayMessage("")

func show_tutorial_message(_text: String, show_continue: bool, block_input: bool) -> void:
	# Preserve default label text; honor continue visibility and blocking
	continue_button.visible = show_continue
	_set_mouse_block(block_input)
	visible = true
	if block_input:
		ui_manager.set_modal_active(true)
	else:
		ui_manager.set_modal_active(false)

func _set_modal_text(text: String) -> void:
	message_label.text = text
	scroll_message_label.text = text
	_apply_message_font_size_for_text(text)
	scroll_message_label.add_theme_font_size_override(&"font_size", message_label.get_theme_font_size(&"font_size", &"Label"))
	message_scroll.scroll_vertical = 0
