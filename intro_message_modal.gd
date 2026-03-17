extends MessageModal
class_name IntroMessageModal

# Dedicated intro modal; inherits all behavior from MessageModal
const PLACE_CASTLE_BUTTON_TEXT: String = "Place Castle"
const CONTINUE_BUTTON_TEXT: String = "Continue"

func displayMessage(_text: String) -> void:
	# Keep the baked-in intro text; only show and block input like base class
	continue_button.text = tr(PLACE_CASTLE_BUTTON_TEXT)
	continue_button.visible = true
	_set_mouse_block(true)
	_show_modal()

func display_intro_text(text: String) -> void:
	continue_button.text = tr(CONTINUE_BUTTON_TEXT)
	continue_button.visible = true
	message_label.text = tr(text)
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
