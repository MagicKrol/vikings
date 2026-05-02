extends MessageModal
class_name IntroMessageModal

# Dedicated intro modal; inherits all behavior from MessageModal
const PLACE_CASTLE_BUTTON_TEXT: String = "Place Castle"
const CONTINUE_BUTTON_TEXT: String = "Continue"
const END_MISSION_BUTTON_TEXT: String = "End Mission"
const SKIRMISH_INTRO_TEXT_KEY: String = "skirmish-intro"
const CONTINUE_ACTION_PLACE_CASTLE: String = "place_castle"
const CONTINUE_ACTION_CONTINUE: String = "continue"
const CONTINUE_ACTION_END_MISSION: String = "end_mission"
@onready var message_scroll: ScrollContainer = get_node("PanelRoot/ContentContainer/MessageScroll") as ScrollContainer
@onready var scroll_message_label: Label = get_node("PanelRoot/ContentContainer/MessageScroll/ScrollMessageLabel") as Label
var _continue_action: String = CONTINUE_ACTION_PLACE_CASTLE
var _has_played_intro_horn: bool = false

func _ready() -> void:
	super._ready()
	_continue_action = CONTINUE_ACTION_PLACE_CASTLE
	_set_modal_text(_build_skirmish_intro_text())

func displayMessage(_text: String) -> void:
	# Keep the baked-in intro text; only show and block input like base class
	continue_button.text = tr(PLACE_CASTLE_BUTTON_TEXT)
	_continue_action = CONTINUE_ACTION_PLACE_CASTLE
	continue_button.visible = true
	_set_modal_text(_build_skirmish_intro_text())
	_set_mouse_block(true)
	_show_modal()

func display_intro_text(text: String) -> void:
	continue_button.text = tr(CONTINUE_BUTTON_TEXT)
	_continue_action = CONTINUE_ACTION_CONTINUE
	continue_button.visible = true
	_set_modal_text(tr(text))
	_set_mouse_block(true)
	_show_modal()

func display_default_intro_text_with_continue() -> void:
	continue_button.text = tr(CONTINUE_BUTTON_TEXT)
	_continue_action = CONTINUE_ACTION_CONTINUE
	continue_button.visible = true
	_set_modal_text(_build_skirmish_intro_text())
	_set_mouse_block(true)
	_show_modal()

func display_outro_text(text: String) -> void:
	continue_button.text = tr(END_MISSION_BUTTON_TEXT)
	_continue_action = CONTINUE_ACTION_END_MISSION
	continue_button.visible = true
	_set_modal_text(tr(text))
	_set_mouse_block(true)
	_show_modal()

func display_message(_header: String, _message: String = "") -> void:
	# Preserve default label text
	displayMessage("")

func show_tutorial_message(_text: String, show_continue: bool, block_input: bool) -> void:
	# Preserve default label text; honor continue visibility and blocking
	_continue_action = CONTINUE_ACTION_CONTINUE
	continue_button.visible = show_continue
	_set_mouse_block(block_input)
	visible = true
	if block_input:
		ui_manager.set_modal_active(true)
	else:
		ui_manager.set_modal_active(false)

func _on_continue_pressed() -> void:
	if not _has_played_intro_horn:
		sound_manager.play_horn_sound()
		_has_played_intro_horn = true
	else:
		sound_manager.click_sound()
	emit_signal("continue_clicked")
	_hide_modal()

func _build_skirmish_intro_text() -> String:
	var game_manager: GameManager = get_node("/root/Main/GameManager") as GameManager
	var intro_text: String = tr(SKIRMISH_INTRO_TEXT_KEY)
	var victory_text: String = game_manager.get_custom_victory_condition_description()
	if victory_text == "":
		return intro_text
	return intro_text + "\n\n" + victory_text + "\n"

func _set_modal_text(text: String) -> void:
	message_label.text = text
	scroll_message_label.text = text
	_apply_message_font_size_for_text(text)
	scroll_message_label.add_theme_font_size_override(&"font_size", message_label.get_theme_font_size(&"font_size", &"Label"))
	message_scroll.scroll_vertical = 0
