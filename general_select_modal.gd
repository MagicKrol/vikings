extends ActionModalBase
class_name GeneralSelectModal

const HEADER_TEXT := "Select Target"
const BUTTON_FONT: Font = preload("res://fonts/Cinzel.ttf")

# Current region and armies
var current_region: Region = null
var current_armies: Array[Army] = []

# Additional references specific to selection
var region_select_modal: RegionSelectModal = null
var tutorial_manager: TutorialManager = null
var game_manager: GameManager = null
var army_manager: ArmyManager = null

@onready var header_label: Label = get_node("InnerPanel/HeaderSection/HeaderLabel")

func _ready():
	super._ready()
	_setup_select_references()

func _setup_select_references():
	game_manager = get_node("../../GameManager") as GameManager
	army_manager = game_manager.get_army_manager()
	region_select_modal = get_node("../RegionSelectModal") as RegionSelectModal
	tutorial_manager = game_manager.get_tutorial_manager()

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
	var is_conquered := current_region.get_ownership_turns() == 0
	var region_btn: Button
	if is_conquered:
		region_btn = _make_disabled_action_button(current_region.get_region_name(), true, is_last, font)
		_prepare_disabled_button(region_btn)
		region_btn.mouse_entered.connect(func(): show_message_tooltip("conquered_region_blocked"))
		region_btn.mouse_exited.connect(_on_button_unhovered)
	else:
		region_btn = _make_button(current_region.get_region_name(), true, is_last, font)
		region_btn.pressed.connect(_on_region_button_pressed)
		region_btn.mouse_entered.connect(_on_region_button_hovered)
		region_btn.mouse_exited.connect(_on_button_unhovered)
		region_btn.mouse_entered.connect(_on_region_tooltip_hovered)
		_prepare_button(region_btn)
	button_container.add_child(region_btn)
	_add_separator()


func _add_army_buttons(font: Font) -> void:
	for i in current_armies.size():
		var army := current_armies[i]
		var is_last := i == current_armies.size() - 1
		var button := _make_button("Army " + str(army.number), false, is_last, font)
		button.name = "ArmyButton" + str(i)
		button.pressed.connect(_on_army_button_pressed.bind(army))
		if tutorial_manager:
			button.pressed.connect(func(): tutorial_manager.handle_ui_click("GeneralSelectModal/" + button.name))
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

func _prepare_disabled_button(button: Button) -> void:
	button.size_flags_vertical = Control.SIZE_FILL
	button.custom_minimum_size.y = 40
	button.add_theme_font_size_override("font_size", 22)
	button.focus_mode = Control.FOCUS_NONE



# -------- interactions --------

func _on_region_button_pressed() -> void:
	var region_to_show = current_region
	if sound_manager: sound_manager.click_sound()
	hide_modal()
	if region_select_modal and region_to_show and is_instance_valid(region_select_modal) and is_instance_valid(region_to_show):
		region_select_modal.show_region_actions(region_to_show)

func _on_army_button_pressed(army: Army) -> void:
	var region := current_region
	sound_manager.click_sound()
	hide_modal()
	_start_army_move_selection(army, region)

func _start_army_move_selection(army: Army, region: Region) -> void:
	var current_player_id = game_manager.get_current_player_id()
	army_manager.select_army(army, region, current_player_id)
	if ui_manager:
		ui_manager.set_modal_active(false)

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
