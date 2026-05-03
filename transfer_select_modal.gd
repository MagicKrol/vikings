extends ActionModalBase
class_name TransferSelectModal

# Current region and armies
var current_region: Region = null
var current_armies: Array[Army] = []
var source_army: Army = null

# Additional references specific to transfer selection
var transfer_soldiers_modal: TransferSoldiersModal = null
var move_modal: MoveModal = null

const HEADER_TEXT := "Select Target"
const BUTTON_FONT: Font = preload("res://fonts/Cinzel.ttf")

@onready var header_label: Label = get_node("InnerPanel/HeaderSection/HeaderLabel")
@onready var no_actions_tooltip: SelectTooltipModalNoRes = get_node("NoActions") as SelectTooltipModalNoRes

func _ready():
	super._ready()
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_transfer_references()

func _setup_transfer_references():
	transfer_soldiers_modal = get_node("../TransferSoldiersModal") as TransferSoldiersModal
	move_modal = get_node("../MoveModal") as MoveModal

func show_transfer_selection(source_army_param: Army, region: Region, other_armies: Array[Army]) -> void:
	"""Show the transfer selection modal with region and other armies"""
	if source_army_param == null or region == null:
		hide_modal()
		return
	ui_manager.remember_army_select(source_army_param, region)
	
	source_army = source_army_param
	current_region = region
	current_armies = other_armies
	_create_buttons()
	visible = true
	if move_modal != null:
		move_modal.hide_move_modal()
	
	if ui_manager:
		ui_manager.set_modal_active(true)

func hide_modal() -> void:
	_clear_buttons()
	visible = false
	if ui_manager:
		ui_manager.set_modal_active(false)
	hide_tooltips()
	source_army = null
	current_region = null
	current_armies.clear()

func _create_buttons() -> void:
	_clear_buttons()
	header_label.text = tr(HEADER_TEXT)

	var definitions := _build_button_definitions()
	for i in definitions.size():
		var button := _create_button_from_definition(
			definitions[i],
			i == 0,
			i == definitions.size() - 1
		)
		button_container.add_child(button)
		_add_separator()


func _build_button_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []

	definitions.append({
		"text": current_region.get_region_name(),
		"enabled": true,
		"action": "_on_region_button_pressed"
	})

	for army in current_armies:
		var entry := _create_army_definition(army)
		if entry.is_empty():
			continue
		definitions.append(entry)

	definitions.append({
		"text": tr("Back"),
		"enabled": true,
		"action": "_on_back_button_pressed"
	})

	return definitions


func _create_army_definition(army: Army) -> Dictionary:
	if army == source_army:
		return {}

	return {
		"text": tr("Army %s") % army.number,
		"enabled": army.get_movement_points() > 0,
		"tooltip_key": "army_has_no_movement_points",
		"action": "_on_army_button_pressed",
		"action_target": army
	}


func _create_button_from_definition(definition: Dictionary, is_first: bool, is_last: bool) -> Button:
	var button: Button
	var enabled: bool = definition.get("enabled", true)
	var text := definition.get("text", "") as String
	if enabled:
		button = _make_button(text, is_first, is_last, BUTTON_FONT)
		_prepare_button(button)
		_connect_button_action(button, definition)
	else:
		button = _make_disabled_action_button(text, is_first, is_last, BUTTON_FONT)
		_prepare_disabled_button(button)
		_connect_disabled_button_tooltip(button, definition)

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


func _connect_button_action(button: Button, definition: Dictionary) -> void:
	if not definition.has("action"):
		return

	var action_name := definition.action as String
	if definition.has("action_target"):
		button.pressed.connect(Callable(self, action_name).bind(definition.action_target))
	else:
		button.pressed.connect(Callable(self, action_name))

func _connect_disabled_button_tooltip(button: Button, definition: Dictionary) -> void:
	if not definition.has("tooltip_key"):
		return
	var tooltip_key: String = String(definition.get("tooltip_key", ""))
	if tooltip_key == "":
		return
	button.mouse_entered.connect(func(): _show_disabled_button_tooltip(tooltip_key))
	button.mouse_exited.connect(func(): _hide_disabled_button_tooltip())

func _show_disabled_button_tooltip(tooltip_key: String) -> void:
	no_actions_tooltip.show_tooltip(tooltip_key)

func _hide_disabled_button_tooltip() -> void:
	no_actions_tooltip.hide_tooltip()

func hide_tooltips() -> void:
	super.hide_tooltips()
	_hide_disabled_button_tooltip()


func _on_back_button_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	var selected_for_move: Army = source_army
	hide_modal()
	ui_manager.restore_select_context()
	if move_modal != null and selected_for_move != null:
		move_modal.show_move_modal(selected_for_move)

func _on_region_button_pressed() -> void:
	# Store references before hiding modal
	var army_to_transfer = source_army
	var region_to_transfer = current_region
	
	if sound_manager:
		sound_manager.click_sound()
	
	hide_modal()
	
	# Show TransferSoldiersModal for army to garrison transfer
	if transfer_soldiers_modal != null and army_to_transfer != null and region_to_transfer != null:
		transfer_soldiers_modal.show_transfer_to_garrison(army_to_transfer, region_to_transfer)

func _on_army_button_pressed(target_army: Army) -> void:
	# Store references before hiding modal
	var source_army_ref = source_army
	var target_army_ref = target_army
	var region_ref = current_region
	
	if sound_manager:
		sound_manager.click_sound()
	
	hide_modal()
	
	# Show TransferSoldiersModal for army to army transfer
	if transfer_soldiers_modal != null and source_army_ref != null and target_army_ref != null and region_ref != null:
		transfer_soldiers_modal.show_transfer_to_army(source_army_ref, target_army_ref, region_ref)
