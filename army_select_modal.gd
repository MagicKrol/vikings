extends ActionModalBase
class_name ArmySelectModal

const HEADER_TEXT := "Army Actions"
const BUTTON_FONT: Font = preload("res://fonts/Cinzel.ttf")

# Current army and region
var current_army: Army = null
var current_region: Region = null

# Additional references specific to army actions
var select_modal: GeneralSelectModal = null
var recruitment_modal: RecruitmentModal = null
var transfer_soldiers_modal: TransferSoldiersModal = null
var transfer_select_modal: TransferSelectModal = null
var army_manager: ArmyManager = null
var game_manager: GameManager = null

@onready var header_label: Label = get_node("InnerPanel/HeaderSection/HeaderLabel")

func _ready():
	super._ready()
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_army_references()
	size.x = 300

func _setup_army_references():
	select_modal = get_node("../GeneralSelectModal") as GeneralSelectModal
	recruitment_modal = get_node("../RecruitmentModal") as RecruitmentModal
	transfer_soldiers_modal = get_node("../TransferSoldiersModal") as TransferSoldiersModal
	transfer_select_modal = get_node("../TransferSelectModal") as TransferSelectModal
	
	var click_manager = get_node("../../ClickManager")
	if click_manager and click_manager.has_method("get_army_manager"):
		army_manager = click_manager.get_army_manager()
	
	game_manager = get_node("../../GameManager") as GameManager

func show_army_actions(army: Army, region: Region) -> void:
	if army == null:
		hide_modal()
		return
	
	current_army = army
	current_region = region
	_create_action_buttons()
	visible = true
	
	if ui_manager:
		ui_manager.set_modal_active(true)
	
	if info_modal != null and current_army != null:
		info_modal.show_army_info(current_army, false)

func hide_modal() -> void:
	super.hide_modal()
	current_army = null
	current_region = null

func _create_action_buttons() -> void:
	_clear_buttons()
	header_label.text = HEADER_TEXT

	var button_definitions := _build_button_definitions()
	if button_definitions.is_empty():
		return

	for i in button_definitions.size():
		var button := _create_button_from_definition(
			button_definitions[i],
			i == 0,
			i == button_definitions.size() - 1
		)
		button_container.add_child(button)
		_add_separator()


func _build_button_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []

	definitions.append({
		"text": "Move Army",
		"enabled": current_army != null and current_region != null,
		"action": "_on_move_army_pressed",
		"tooltip": Callable(self, "_on_tooltip_hovered").bind("move_army")
	})

	definitions.append({
		"text": "Make Camp",
		"enabled": current_army != null and current_army.has_method("make_camp"),
		"action": "_on_make_camp_pressed",
		"tooltip": Callable(self, "_on_tooltip_hovered").bind("make_camp")
	})

	definitions.append({
		"text": "Transfer Soldiers",
		"enabled": current_region != null,
		"action": "_on_transfer_soldiers_pressed",
		"tooltip": Callable(self, "_on_tooltip_hovered").bind("transfer_soldiers")
	})

	definitions.append({
		"text": "Recruit Soldiers",
		"enabled": current_army != null and current_region != null,
		"action": "_on_recruit_soldiers_pressed",
		"tooltip": Callable(self, "_on_tooltip_hovered").bind("recruit_soldiers")
	})

	definitions.append({
		"text": "Back",
		"enabled": current_region != null,
		"action": "_on_back_pressed",
		"tooltip": Callable(self, "_on_tooltip_hovered").bind("back")
	})

	return definitions


func _create_button_from_definition(button_data: Dictionary, is_first: bool, is_last: bool) -> Button:
	var button: Button
	var enabled: bool = button_data.get("enabled", true)
	var text := button_data.get("text", "") as String
	if enabled:
		button = _make_button(text, is_first, is_last, BUTTON_FONT)
		_prepare_button(button)
		if button_data.has("action"):
			button.pressed.connect(Callable(self, button_data.action))
	else:
		button = _make_disabled_action_button(text, is_first, is_last, BUTTON_FONT)
		_prepare_disabled_button(button)

	_attach_tooltip(button_data, button)
	return button


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


func _attach_tooltip(button_data: Dictionary, button: Button) -> void:
	if not button_data.has("tooltip"):
		return

	var tooltip_value = button_data.tooltip
	if tooltip_value is Callable:
		button.mouse_entered.connect(tooltip_value)
	else:
		button.mouse_entered.connect(Callable(self, "_on_tooltip_hovered").bind(tooltip_value))
	button.mouse_exited.connect(_on_tooltip_unhovered)

func _on_move_army_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	if army_manager != null and current_army != null and current_region != null and game_manager != null:
		var region_container = current_army.get_parent()
		if region_container != null:
			var current_player_id = game_manager.get_current_player_id()
			army_manager.select_army(current_army, region_container, current_player_id)
	
	current_army = null
	current_region = null
	_clear_buttons()
	visible = false
	
	if ui_manager:
		ui_manager.set_modal_active(false)

func _on_make_camp_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	if current_army and current_army.has_method("make_camp"):
		current_army.make_camp()
		
		if info_modal != null and info_modal.visible:
			info_modal.show_army_info(current_army, false)

func _on_transfer_soldiers_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	var army_to_transfer = current_army
	var region_to_transfer = current_region
	
	var other_armies: Array[Army] = []
	if region_to_transfer != null:
		for child in region_to_transfer.get_children():
			if child is Army and child != army_to_transfer:
				other_armies.append(child as Army)
	
	hide_modal()
	
	if other_armies.size() > 0:
		if transfer_select_modal != null and army_to_transfer != null and region_to_transfer != null:
			transfer_select_modal.show_transfer_selection(army_to_transfer, region_to_transfer, other_armies)
	else:
		if transfer_soldiers_modal != null and army_to_transfer != null and region_to_transfer != null:
			transfer_soldiers_modal.show_transfer_to_garrison(army_to_transfer, region_to_transfer)

func _on_recruit_soldiers_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	var army_to_recruit = current_army
	var region_to_recruit = current_region
	
	hide_modal()
	
	if recruitment_modal != null and army_to_recruit != null and region_to_recruit != null:
		recruitment_modal.show_recruitment(army_to_recruit, region_to_recruit)

func _on_back_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	var region_to_show = current_region
	var armies_in_region: Array[Army] = []
	
	if region_to_show != null:
		for child in region_to_show.get_children():
			if child is Army:
				armies_in_region.append(child as Army)
		
		if armies_in_region.is_empty() and current_army != null:
			armies_in_region = [current_army]
	
	hide_modal()
	
	if select_modal != null and region_to_show != null and is_instance_valid(select_modal) and is_instance_valid(region_to_show):
		select_modal.show_selection(region_to_show, armies_in_region)
