extends Control
class_name TransferSoldiersModal

# UI elements - references to static nodes from scene
var target_name_label: Label
var source_name_label: Label
const UNIT_CONTAINER_PATHS := [
	"Transfer/VBoxContainer/Body/Units/Peasants",
	"Transfer/VBoxContainer/Body/Units/Spearmen",
	"Transfer/VBoxContainer/Body/Units/Archers",
	"Transfer/VBoxContainer/Body/Units/Swordsmen",
	"Transfer/VBoxContainer/Body/Units/Crosbowmen",
	"Transfer/VBoxContainer/Body/Units/Horsemen",
	"Transfer/VBoxContainer/Body/Units/Knights",
	"Transfer/VBoxContainer/Body/Units/MountedKnights",
	"Transfer/VBoxContainer/Body/Units/RoyalGuard"
]

var unit_target_value_labels: Array[Label] = []
var unit_source_value_labels: Array[Label] = []
var unit_sliders: Array[HSlider] = []
var unit_total_counts: Array[int] = []
var unit_original_target_counts: Array[int] = []
var unit_desired_target_counts: Array[int] = []
var transfer_button: Button
var cancel_button: Button

# Transfer data
var source_army: Army = null
var target_army: Army = null  # Can be null if transferring to garrison
var target_region: Region = null

# Unit types in order (matching scene structure)
var unit_types = [
	SoldierTypeEnum.Type.PEASANTS,
	SoldierTypeEnum.Type.SPEARMEN,
	SoldierTypeEnum.Type.ARCHERS,
	SoldierTypeEnum.Type.SWORDSMEN,
	SoldierTypeEnum.Type.CROSSBOWMEN,
	SoldierTypeEnum.Type.HORSEMEN,
	SoldierTypeEnum.Type.KNIGHTS,
	SoldierTypeEnum.Type.MOUNTED_KNIGHTS,
	SoldierTypeEnum.Type.ROYAL_GUARD
]

# Manager references
var sound_manager: SoundManager = null
var ui_manager: UIManager = null
var info_modal: InfoModal = null
var move_modal: MoveModal = null
var _ui_lock: bool = false

func _ready():
	# Get references to static UI elements from scene
	target_name_label = get_node("Transfer/VBoxContainer/SubHeader/HBoxContainer/Target")
	source_name_label = get_node("Transfer/VBoxContainer/SubHeader/HBoxContainer/Source")
	transfer_button = get_node("Transfer/VBoxContainer/Buttons/Transfer")
	cancel_button = get_node("Transfer/VBoxContainer/Buttons/Cancel")
	
	# Get references to unit UI elements
	_get_unit_ui_references()
	_connect_unit_sliders()
	
	# Connect button signals
	transfer_button.pressed.connect(_on_transfer_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Get manager references
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	info_modal = get_node("../InfoModal") as InfoModal
	move_modal = get_node("../MoveModal") as MoveModal
	
	# Initially hidden
	visible = false


func _get_unit_ui_references():
	unit_target_value_labels.clear()
	unit_source_value_labels.clear()
	unit_sliders.clear()
	unit_total_counts.clear()
	unit_original_target_counts.clear()
	unit_desired_target_counts.clear()
	
	# Get references to sliders and value labels for each unit type
	DebugLogger.log("UISystem", "Getting UI references for " + str(UNIT_CONTAINER_PATHS.size()) + " unit containers")

	for container_path in UNIT_CONTAINER_PATHS:
		var target_value_label = get_node(container_path + "/VBoxContainer/TextureRect/Label") as Label
		var source_value_label = get_node(container_path + "/VBoxContainer/TextureRect/Label2") as Label
		var slider = get_node(container_path + "/VBoxContainer/TextureRect/HSlider") as HSlider
		unit_target_value_labels.append(target_value_label)
		unit_source_value_labels.append(source_value_label)
		unit_sliders.append(slider)

	DebugLogger.log("UISystem", "Cached arrays - Target labels: " + str(unit_target_value_labels.size()) + ", Source labels: " + str(unit_source_value_labels.size()) + ", Sliders: " + str(unit_sliders.size()))

func _connect_unit_sliders():
	DebugLogger.log("UISystem", "Connecting transfer sliders. Unit count: " + str(unit_sliders.size()))
	for i in range(unit_sliders.size()):
		unit_sliders[i].value_changed.connect(_on_unit_slider_changed.bind(i))

func show_transfer_to_garrison(army: Army, region: Region) -> void:
	"""Show the transfer soldiers modal with army to garrison transfer"""
	if army == null or region == null:
		hide_modal()
		return
	ui_manager.remember_army_select(army, region)
	
	target_army = army
	source_army = null  # Transfer from garrison
	target_region = region
	move_modal.hide_move_modal()
	
	# Update display
	_update_display()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)
	_update_transfer_button_state()

func show_transfer_to_army(source: Army, target: Army, region: Region) -> void:
	"""Show the transfer soldiers modal with army to army transfer"""
	if source == null or target == null or region == null:
		hide_modal()
		return
	ui_manager.remember_army_select(source, region)
	
	target_army = source
	source_army = target
	target_region = region
	move_modal.hide_move_modal()
	
	# Update display
	_update_display()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)
	_update_transfer_button_state()

# Legacy function for backwards compatibility
func show_transfer(army: Army, region: Region) -> void:
	"""Legacy function - show army to garrison transfer"""
	show_transfer_to_garrison(army, region)

func hide_modal() -> void:
	"""Hide the transfer soldiers modal"""
	var reopen_army: Army = target_army
	# Reset state
	source_army = null
	target_army = null
	target_region = null
	
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)
		ui_manager.restore_select_context()
	if move_modal != null and reopen_army != null:
		move_modal.show_move_modal(reopen_army)

func _has_pending_changes() -> bool:
	for i in range(unit_desired_target_counts.size()):
		if int(unit_desired_target_counts[i]) != int(unit_original_target_counts[i]):
			return true
	return false

func _update_transfer_button_state() -> void:
	transfer_button.disabled = not _has_pending_changes()

func _update_display() -> void:
	"""Update the display with current transfer information"""
	if target_region == null or target_army == null:
		hide_modal()
		return
	
	# Update target name
	target_name_label.text = tr("Army %s") % target_army.number
	
	# Update source name
	if source_army != null:
		source_name_label.text = tr("Army %s") % source_army.number
	else:
		source_name_label.text = target_region.get_region_name()
	
	# Update unit displays and sliders
	_update_unit_displays()

func _update_unit_displays() -> void:
	"""Update all unit value labels and pending transfer data"""
	_ui_lock = true
	unit_total_counts.clear()
	unit_original_target_counts.clear()
	unit_desired_target_counts.clear()
	for i in range(unit_types.size()):
		var unit_type = unit_types[i]
		var target_value_label = unit_target_value_labels[i]
		var source_value_label = unit_source_value_labels[i]
		var slider = unit_sliders[i]
		var target_count: int = target_army.get_soldier_count(unit_type)
		var source_count: int
		if source_army != null:
			source_count = source_army.get_soldier_count(unit_type)
		else:
			source_count = target_region.get_garrison().get_soldier_count(unit_type)
		DebugLogger.log("UISystem", "Unit " + SoldierTypeEnum.type_to_string(unit_type) + ": target=" + str(target_count) + ", source=" + str(source_count))
		target_value_label.text = str(target_count)
		source_value_label.text = str(source_count)
		var total_units: int = source_count + target_count
		unit_total_counts.append(total_units)
		unit_original_target_counts.append(target_count)
		unit_desired_target_counts.append(target_count)
		slider.step = 1.0
		slider.min_value = 0.0
		slider.max_value = float(total_units)
		slider.value = float(source_count)
		slider.editable = total_units > 0
	_ui_lock = false
	_update_transfer_button_state()

func _on_unit_slider_changed(value: float, unit_index: int) -> void:
	"""Handle transfer adjustments triggered by sliders"""
	if _ui_lock:
		return
	if unit_index >= unit_desired_target_counts.size() or unit_index >= unit_source_value_labels.size():
		DebugLogger.log("UISystem", "ERROR: Unit index " + str(unit_index) + " out of bounds for transfer sliders")
		return
	var total_units: int = unit_total_counts[unit_index]
	var new_source: int = clampi(int(value), 0, total_units)
	var new_target: int = total_units - new_source
	var clamped_target: int = _clamp_target_count_for_army_constraints(unit_index, new_target)
	if clamped_target != new_target:
		new_target = clamped_target
		new_source = total_units - new_target
		_ui_lock = true
		unit_sliders[unit_index].value = float(new_source)
		_ui_lock = false
	unit_desired_target_counts[unit_index] = new_target
	unit_target_value_labels[unit_index].text = str(new_target)
	unit_source_value_labels[unit_index].text = str(new_source)
	_update_transfer_button_state()

func _clamp_target_count_for_army_constraints(unit_index: int, proposed_target_count: int) -> int:
	var total_units_for_type: int = unit_total_counts[unit_index]
	var clamped_target_count: int = clampi(proposed_target_count, 0, total_units_for_type)
	var other_target_total: int = _sum_desired_target_counts_excluding(unit_index)
	var min_target_for_row: int = maxi(0, 1 - other_target_total)
	if clamped_target_count < min_target_for_row:
		clamped_target_count = min_target_for_row
	if source_army != null:
		var max_total_target_units: int = _sum_all_unit_totals() - 1
		var max_target_for_row: int = max_total_target_units - other_target_total
		max_target_for_row = clampi(max_target_for_row, 0, total_units_for_type)
		if clamped_target_count > max_target_for_row:
			clamped_target_count = max_target_for_row
	return clamped_target_count

func _sum_desired_target_counts_excluding(skip_index: int) -> int:
	var total: int = 0
	for i in range(unit_desired_target_counts.size()):
		if i == skip_index:
			continue
		total += int(unit_desired_target_counts[i])
	return total

func _sum_all_unit_totals() -> int:
	var total: int = 0
	for count in unit_total_counts:
		total += int(count)
	return total

func _on_transfer_pressed() -> void:
	"""Handle Transfer button press"""
	if transfer_button.disabled:
		return
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Apply transfers based on pending button selections
	_apply_transfer_changes()
	
	# Hide modal
	hide_modal()

func _on_cancel_pressed() -> void:
	"""Handle Cancel button press"""
	if sound_manager:
		sound_manager.click_sound()
	hide_modal()

func _apply_transfer_changes() -> void:
	"""Apply transfers based on current button selections"""
	var has_transfers = false
	var total_to_target: int = 0
	var total_to_source: int = 0
	for i in range(unit_types.size()):
		var unit_type = unit_types[i]
		var original_target_count = unit_original_target_counts[i]
		var desired_target_count = unit_desired_target_counts[i]
		var transfer_amount = desired_target_count - original_target_count
		if transfer_amount == 0:
			continue
		has_transfers = true
		if transfer_amount > 0:
			total_to_target += transfer_amount
			# Transfer from source to target
			if source_army != null:
				source_army.remove_soldiers(unit_type, transfer_amount)
				DebugLogger.log("UISystem", "Transferred " + str(transfer_amount) + " " + SoldierTypeEnum.type_to_string(unit_type) + " from army " + str(source_army.number) + " to army " + str(target_army.number))
			else:
				target_region.get_garrison().remove_soldiers(unit_type, transfer_amount)
				DebugLogger.log("UISystem", "Transferred " + str(transfer_amount) + " " + SoldierTypeEnum.type_to_string(unit_type) + " from garrison to army " + str(target_army.number))
			target_army.add_soldiers(unit_type, transfer_amount)
		else:
			# Transfer from target to source
			var actual_transfer = -transfer_amount
			total_to_source += actual_transfer
			target_army.remove_soldiers(unit_type, actual_transfer)
			if source_army != null:
				source_army.add_soldiers(unit_type, actual_transfer)
				DebugLogger.log("UISystem", "Transferred " + str(actual_transfer) + " " + SoldierTypeEnum.type_to_string(unit_type) + " from army " + str(target_army.number) + " to army " + str(source_army.number))
			else:
				target_region.get_garrison().add_soldiers(unit_type, actual_transfer)
				DebugLogger.log("UISystem", "Transferred " + str(actual_transfer) + " " + SoldierTypeEnum.type_to_string(unit_type) + " from army " + str(target_army.number) + " to garrison")
	if has_transfers:
		if source_army != null:
			var target_mp_before: int = target_army.get_movement_points()
			var source_mp_before: int = source_army.get_movement_points()
			var receiver_army: Army = target_army
			if total_to_source > total_to_target:
				receiver_army = source_army
			var min_mp: int = mini(target_mp_before, source_mp_before)
			receiver_army.set_movement_points_clamped(min_mp)
			target_army.spend_movement_points_clamped(1)
			source_army.spend_movement_points_clamped(1)
			DebugLogger.log("UISystem", "Army transfer MP update: receiver=Army " + str(receiver_army.number) + " min_mp=" + str(min_mp) + " | Army " + str(target_army.number) + " MP " + str(target_mp_before) + "->" + str(target_army.get_movement_points()) + ", Army " + str(source_army.number) + " MP " + str(source_mp_before) + "->" + str(source_army.get_movement_points()))
		else:
			var army_mp_before: int = target_army.get_movement_points()
			target_army.spend_movement_points_clamped(1)
			DebugLogger.log("UISystem", "Army " + str(target_army.number) + " spent 1 movement point for transfer with garrison (MP " + str(army_mp_before) + "->" + str(target_army.get_movement_points()) + ")")
