extends ActionModalBase
class_name TransferSelectModal

# Current region and armies
var current_region: Region = null
var current_armies: Array[Army] = []
var source_army: Army = null  # The army that wants to transfer soldiers
var test: Army = null
# Additional references specific to transfer selection
var transfer_soldiers_modal: TransferSoldiersModal = null

func _ready():
	super._ready()
	_setup_transfer_references()

func _setup_transfer_references():
	transfer_soldiers_modal = get_node("../TransferSoldiersModal") as TransferSoldiersModal

func show_transfer_selection(source_army_param: Army, region: Region, other_armies: Array[Army]) -> void:
	"""Show the transfer selection modal with region and other armies"""
	if source_army_param == null or region == null:
		hide_modal()
		return
	
	source_army = source_army_param
	current_region = region
	current_armies = other_armies
	_create_buttons()
	visible = true
	
	if ui_manager:
		ui_manager.set_modal_active(true)

func hide_modal() -> void:
	super.hide_modal()
	source_army = null
	current_region = null
	current_armies.clear()

func _create_buttons() -> void:
	_clear_buttons()
	
	var font: Font = load("res://fonts/Cinzel.ttf")
	var button_count = 2 + current_armies.size()  # Header + Region + armies
	
	_resize_modal(button_count)
	
	# Header button
	var header_btn = _make_button("Select Target", true, false, font)
	header_btn.disabled = true
	button_container.add_child(header_btn)
	
	_add_separator()
	
	# Create region button - transfer to garrison
	var region_button = _make_button(current_region.get_region_name() + " (Garrison)", false, button_count == 2, font)
	region_button.pressed.connect(_on_region_button_pressed)
	region_button.mouse_entered.connect(_on_region_button_hovered)
	region_button.mouse_exited.connect(_on_button_unhovered)
	button_container.add_child(region_button)
	
	if button_count > 2:
		_add_separator()
	
	# Create army buttons for other armies in the region
	for i in range(current_armies.size()):
		var army = current_armies[i]
		# Skip the source army (shouldn't be in the list anyway, but safety check)
		if army == source_army:
			continue
		
		var is_last = i == current_armies.size() - 1
		var army_button = _make_button("Army " + str(army.number), false, is_last, font)
		army_button.pressed.connect(_on_army_button_pressed.bind(army))
		army_button.mouse_entered.connect(_on_army_button_hovered.bind(army))
		army_button.mouse_exited.connect(_on_button_unhovered)
		button_container.add_child(army_button)
		
		if not is_last:
			_add_separator()

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

func _on_region_button_hovered() -> void:
	if info_modal != null and current_region != null and is_instance_valid(info_modal) and is_instance_valid(current_region):
		info_modal.show_region_info(current_region, false)

func _on_army_button_hovered(army: Army) -> void:
	if info_modal != null and army != null and is_instance_valid(info_modal) and is_instance_valid(army):
		info_modal.show_army_info(army, false)

func _on_button_unhovered() -> void:
	if info_modal != null and info_modal.visible:
		info_modal.hide_modal(false)
