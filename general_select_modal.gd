extends ActionModalBase
class_name GeneralSelectModal

const HEADER_TEXT := "Select Target"
const BUTTON_FONT: Font = preload("res://fonts/Cinzel.ttf")

# Current region and armies
var current_region: Region = null
var current_armies: Array[Army] = []

# Additional references specific to selection
var army_select_modal: ArmySelectModal = null
var region_select_modal: RegionSelectModal = null

@onready var header_label: Label = get_node("InnerPanel/HeaderSection/HeaderLabel")

func _ready():
	super._ready()
	_setup_select_references()

func _setup_select_references():
	army_select_modal = get_node("../ArmySelectModal") as ArmySelectModal
	region_select_modal = get_node("../RegionSelectModal") as RegionSelectModal

func show_selection(region: Region, armies: Array[Army]) -> void:
	if region == null or armies.is_empty():
		hide_modal()
		return

	current_region = region
	current_armies = armies
	_create_buttons()
	visible = true
	if ui_manager: ui_manager.set_modal_active(true)

func hide_modal() -> void:
	super.hide_modal()
	current_region = null
	current_armies.clear()

# -------- UI building --------

func _create_buttons() -> void:
	_clear_buttons()
	_update_header()

	_add_region_button(BUTTON_FONT)
	_add_army_buttons(BUTTON_FONT)


func _update_header() -> void:
	header_label.text = HEADER_TEXT


func _add_region_button(font: Font) -> void:
	var is_last := current_armies.is_empty()
	var region_btn := _make_button(current_region.get_region_name(), true, is_last, font)
	region_btn.pressed.connect(_on_region_button_pressed)
	region_btn.mouse_entered.connect(_on_region_button_hovered)
	region_btn.mouse_entered.connect(_on_region_tooltip_hovered)
	region_btn.mouse_exited.connect(_on_button_unhovered)
	_prepare_button(region_btn)
	button_container.add_child(region_btn)
	_add_separator()


func _add_army_buttons(font: Font) -> void:
	for i in current_armies.size():
		var army := current_armies[i]
		var is_last := i == current_armies.size() - 1
		var button := _make_button("Army " + str(army.number), false, is_last, font)
		button.pressed.connect(_on_army_button_pressed.bind(army))
		button.mouse_entered.connect(_on_army_button_hovered.bind(army))
		button.mouse_entered.connect(_on_army_tooltip_hovered)
		button.mouse_exited.connect(_on_button_unhovered)
		_prepare_button(button)
		button_container.add_child(button)
		_add_separator()


func _prepare_button(button: Button) -> void:
	button.size_flags_vertical = Control.SIZE_FILL
	button.custom_minimum_size.y = 40
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 22)



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
	if info_modal and current_region and is_instance_valid(info_modal) and is_instance_valid(current_region):
		info_modal.show_region_info(current_region, false)

func _on_army_button_hovered(army: Army) -> void:
	if info_modal and army and is_instance_valid(info_modal) and is_instance_valid(army):
		info_modal.show_army_info(army, false)

func _on_button_unhovered() -> void:
	if info_modal and info_modal.visible:
		info_modal.hide_modal(false)
	hide_tooltips()

func _on_region_tooltip_hovered() -> void:
	show_message_tooltip("region")

func _on_army_tooltip_hovered() -> void:
	show_message_tooltip("army")
