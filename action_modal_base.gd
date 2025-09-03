extends Control
class_name ActionModalBase

# Palette / styling - consistent across all action modals
const FRAME_COLOR      = Color("#b7975e")     # warm brass for borders
const TEXT_COLOR       = Color(0.996, 0.918, 0.765)
const TEXT_COLOR_DISABLED = Color(1, 1, 1, 1.0)  # lighter/faded text for disabled
const BTN_BG           = Color(0, 0, 0, 0)
const BTN_BG_HOVER     = Color(0.18, 0.125, 0.047, 0.7)
const BTN_BG_PRESSED   = Color(0.18, 0.14, 0.10, 0.97)
const SEP_COLOR        = Color(0.392, 0.294, 0.133)
const BTN_CORNER       = 10
const BTN_BORDER_W     = 2

const BTN_HEIGHT = 50
const BORDER_PADDING = 0
const OUTER_PADDING = 0
const SEP_HEIGHT = 3
const INNER_PADDING = 0

# UI elements - must be present in derived scenes (except for special modals like RecruitmentModal)
@onready var button_container: VBoxContainer = get_node_or_null("InnerPanel/ButtonContainer")

# Common references
var sound_manager: SoundManager = null
var ui_manager: UIManager = null
var info_modal: InfoModal = null
var select_tooltip_modal: SelectTooltipModal = null

func _ready():
	_setup_references()
	if button_container != null:
		button_container.add_theme_constant_override("separation", 0)
	visible = false

func _setup_references():
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	info_modal = get_node("../InfoModal") as InfoModal
	select_tooltip_modal = get_node("../SelectTooltipModal") as SelectTooltipModal

func hide_modal() -> void:
	if info_modal != null and info_modal.visible:
		info_modal.hide_modal(false)
	
	_clear_buttons()
	visible = false
	
	if ui_manager:
		ui_manager.set_modal_active(false)

func _make_button(text: String, is_first: bool, is_last: bool, font: Font) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 50)
	b.focus_mode = Control.FOCUS_ALL
	b.flat = false
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_color_override("font_color", TEXT_COLOR)
	b.add_theme_color_override("font_hover_color", TEXT_COLOR)
	b.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	b.add_theme_color_override("font_disabled_color", TEXT_COLOR_DISABLED)
	if font:
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 20)

	var tl = BTN_CORNER if is_first else 0
	var tr = BTN_CORNER if is_first else 0
	var bl = BTN_CORNER if is_last else 0
	var br = BTN_CORNER if is_last else 0

	var normal  := _style_button(BTN_BG,        FRAME_COLOR, tl, tr, bl, br)
	var hover   := _style_button(BTN_BG_HOVER,  FRAME_COLOR, tl, tr, bl, br)
	var pressed := _style_button(BTN_BG_PRESSED,FRAME_COLOR, tl, tr, bl, br)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("disabled", normal)
	return b

func _make_disabled_action_button(text: String, is_first: bool, is_last: bool, font: Font) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 50)
	b.focus_mode = Control.FOCUS_ALL
	b.flat = false
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.disabled = true
	b.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))  # Dark gray
	b.add_theme_color_override("font_hover_color", Color(0.4, 0.4, 0.4))
	b.add_theme_color_override("font_pressed_color", Color(0.4, 0.4, 0.4))
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))
	if font:
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 20)

	var tl = BTN_CORNER if is_first else 0
	var tr = BTN_CORNER if is_first else 0
	var bl = BTN_CORNER if is_last else 0
	var br = BTN_CORNER if is_last else 0

	# Grayish background for disabled action buttons
	var disabled_bg := Color(0.15, 0.15, 0.15, 0.5)
	var disabled_style := _style_button(disabled_bg, FRAME_COLOR, tl, tr, bl, br)

	b.add_theme_stylebox_override("normal", disabled_style)
	b.add_theme_stylebox_override("hover", disabled_style)
	b.add_theme_stylebox_override("pressed", disabled_style)
	b.add_theme_stylebox_override("focus", disabled_style)
	b.add_theme_stylebox_override("disabled", disabled_style)
	return b

func _style_button(bg: Color, border: Color, tl: int, tr: int, bl: int, br: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.draw_center = true
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.expand_margin_top = 0
	sb.expand_margin_bottom = 0
	sb.expand_margin_left = 0
	sb.expand_margin_right = 0
	sb.border_color = border
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	sb.corner_radius_top_left = tl
	sb.corner_radius_top_right = tr
	sb.corner_radius_bottom_left = bl
	sb.corner_radius_bottom_right = br
	sb.anti_aliasing = true
	return sb

func _add_separator():
	var sep := ColorRect.new()
	sep.color = SEP_COLOR
	sep.custom_minimum_size = Vector2(0, SEP_HEIGHT)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_child(sep)

func _clear_buttons() -> void:
	if button_container != null:
		for child in button_container.get_children():
			child.queue_free()

func _resize_modal(num_buttons: int) -> void:
	print("Owner:", self.name, " path:", self.get_path())
	print("Children:", get_children())
	print("Has InnerPanel:", has_node("InnerPanel"))
	var num_separators = num_buttons - 1

	var inner_height = (BTN_HEIGHT * num_buttons) + (SEP_HEIGHT * num_separators) + INNER_PADDING
	var outer_height = inner_height + OUTER_PADDING  
	var border_height = outer_height + BORDER_PADDING

	var inner_panel: Control = $InnerPanel
	inner_panel.size.y = inner_height

	var outer_panel: Control = $OuterFrame
	outer_panel.size.y = outer_height

	var border: Control = $Border
	border.size.y = border_height

func _on_tooltip_hovered(tooltip_key: String) -> void:
	if select_tooltip_modal != null:
		select_tooltip_modal.show_tooltip(tooltip_key)

func _on_tooltip_unhovered() -> void:
	if select_tooltip_modal != null:
		select_tooltip_modal.hide_tooltip()
