extends Control
class_name SelectModal

# Palette / styling
const FRAME_COLOR      = Color("#b7975e")     # warm brass for borders
const TEXT_COLOR       = Color(0.996, 0.918, 0.765)
const TEXT_COLOR_DISABLED = Color(1, 1, 1, 1.0)  # lighter/faded text for disabled
const BTN_BG           = Color(0, 0, 0, 0)
const BTN_BG_HOVER     = Color(0.18, 0.125, 0.047, 0.7)
const BTN_BG_PRESSED   = Color(0.18, 0.14, 0.10, 0.97)
const SEP_COLOR        = Color(0.392, 0.294, 0.133)
const BTN_CORNER       = 10
const BTN_BORDER_W     = 2

const BTN_HEIGHT = 58
const BORDER_PADDING = 0
const OUTER_PADDING = 0
const SEP_HEIGHT = 3
const INNER_PADDING = 0

# UI
@onready var button_container: VBoxContainer = $InnerPanel/ButtonContainer

# Current region and armies
var current_region: Region = null
var current_armies: Array[Army] = []

# References
var sound_manager: SoundManager = null
var ui_manager: UIManager = null
var army_modal: Control = null
var region_modal: RegionModal = null
var army_select_modal: ArmySelectModal = null
var region_select_modal: RegionSelectModal = null
var info_modal: InfoModal = null
var select_tooltip_modal: SelectTooltipModal = null

func _ready():
	# Get refs
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	army_modal = get_node("../ArmyModal") as Control
	region_modal = get_node("../RegionModal") as RegionModal
	army_select_modal = get_node("../ArmySelectModal") as ArmySelectModal
	region_select_modal = get_node("../RegionSelectModal") as RegionSelectModal
	info_modal = get_node("../InfoModal") as InfoModal
	select_tooltip_modal = get_node("../SelectTooltipModal") as SelectTooltipModal

	# Container spacing
	button_container.add_theme_constant_override("separation", 0)

	visible = false

func show_selection(region: Region, armies: Array[Army]) -> void:
	if region == null or armies.is_empty():
		hide_modal()
		return

	current_region = region
	current_armies = armies
	_resize_modal()
	_create_buttons()
	visible = true
	if ui_manager: ui_manager.set_modal_active(true)

func hide_modal() -> void:
	current_region = null
	current_armies.clear()
	_clear_buttons()
	visible = false
	if ui_manager: ui_manager.set_modal_active(false)

# -------- UI building --------

func _create_buttons() -> void:
	_clear_buttons()

	var font: Font = load("res://fonts/Cinzel.ttf")

	# --- Static first button ("Select target") ---
	var select_btn := _make_button("Select target", true, false, font)
	select_btn.disabled = true                  # static / non-clickable
	button_container.add_child(select_btn)

	# Separator after static button
	var sep0 := ColorRect.new()
	sep0.color = SEP_COLOR
	sep0.custom_minimum_size = Vector2(0, SEP_HEIGHT)
	sep0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_child(sep0)

	# --- Region button ---
	var region_btn := _make_button(
		current_region.get_region_name(),
		false,
		false,
		font
	)
	region_btn.pressed.connect(_on_region_button_pressed)
	region_btn.mouse_entered.connect(_on_region_button_hovered)
	region_btn.mouse_entered.connect(_on_region_tooltip_hovered)
	region_btn.mouse_exited.connect(_on_button_unhovered)
	button_container.add_child(region_btn)

	# Separator after region
	var sep := ColorRect.new()
	sep.color = SEP_COLOR
	sep.custom_minimum_size = Vector2(0, SEP_HEIGHT)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_child(sep)

	# --- Army buttons (last one gets bottom-rounded) ---
	for i in current_armies.size():
		var is_last := i == current_armies.size() - 1
		var army := current_armies[i]
		var b := _make_button("Army " + str(army.number), false, is_last, font)
		b.pressed.connect(_on_army_button_pressed.bind(army))
		b.mouse_entered.connect(_on_army_button_hovered.bind(army))
		b.mouse_entered.connect(_on_army_tooltip_hovered)
		b.mouse_exited.connect(_on_button_unhovered)
		button_container.add_child(b)

		if not is_last:
			var sep2 := ColorRect.new()
			sep2.color = SEP_COLOR
			sep2.custom_minimum_size = Vector2(0, SEP_HEIGHT)
			sep2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button_container.add_child(sep2)


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

# -------- helpers --------

func _clear_buttons() -> void:
	for child in button_container.get_children():
		child.queue_free()

# -------- interactions --------

func _on_region_button_pressed() -> void:
	var region_to_show = current_region
	if sound_manager: sound_manager.click_sound()
	hide_modal()
	if region_select_modal and region_to_show and is_instance_valid(region_select_modal) and is_instance_valid(region_to_show):
		region_select_modal.show_region_actions(region_to_show)

func _on_army_button_pressed(army: Army) -> void:
	var army_to_show = army
	var region_to_show = current_region
	if sound_manager: sound_manager.click_sound()
	hide_modal()
	if army_select_modal and army_to_show and is_instance_valid(army_select_modal) and is_instance_valid(army_to_show):
		army_select_modal.show_army_actions(army_to_show, region_to_show)

func _on_region_button_hovered() -> void:
	print("Region button hovered!")
	if info_modal and current_region and is_instance_valid(info_modal) and is_instance_valid(current_region):
		info_modal.show_region_info(current_region, false)

func _on_army_button_hovered(army: Army) -> void:
	if info_modal and army and is_instance_valid(info_modal) and is_instance_valid(army):
		info_modal.show_army_info(army, false)

func _on_button_unhovered() -> void:
	if info_modal and info_modal.visible:
		info_modal.hide_modal(false)
	if select_tooltip_modal:
		select_tooltip_modal.hide_tooltip()

func _on_region_tooltip_hovered() -> void:
	if select_tooltip_modal:
		select_tooltip_modal.show_tooltip("region")

func _on_army_tooltip_hovered() -> void:
	if select_tooltip_modal:
		select_tooltip_modal.show_tooltip("army")

func _resize_modal() -> void:
	var num_buttons = current_armies.size() + 2  # armies + region
	var num_separators = num_buttons - 1

	var inner_height = (BTN_HEIGHT * num_buttons) + (SEP_HEIGHT * num_separators) + INNER_PADDING
	var outer_height = inner_height + OUTER_PADDING
	var border_height = outer_height + BORDER_PADDING

	print(num_buttons)
	print(str(inner_height) + " " + str(outer_height) + " " + str(border_height))

	# Resize InnerPanel
	var inner_panel: Control = $InnerPanel
	inner_panel.size.y = inner_height

	# Resize OuterFrame
	var outer_panel: Control = $OuterFrame
	outer_panel.size.y = outer_height

	# Resize root (border frame)
	var border: Control = $Border
	border.size.y = border_height
