extends ActionModalBase
class_name MainSelectModal

# Current region and armies
var current_region: Region = null
var current_armies: Array[Army] = []

# Additional references specific to selection
var army_modal: Control = null
var region_modal: RegionModal = null
var army_select_modal: ArmySelectModal = null
var region_select_modal: RegionSelectModal = null

func _ready():
	super._ready()
	_setup_select_references()

func _setup_select_references():
	army_modal = get_node("../ArmyModal") as Control
	region_modal = get_node("../RegionModal") as RegionModal
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

	var font: Font = load("res://fonts/Cinzel.ttf")
	var num_buttons = current_armies.size() + 2

	_resize_modal(num_buttons)

	# --- Static first button ("Select target") ---
	var select_btn := _make_button("Select target", true, false, font)
	select_btn.disabled = true
	button_container.add_child(select_btn)

	_add_separator()

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

	_add_separator()

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
			_add_separator()



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
