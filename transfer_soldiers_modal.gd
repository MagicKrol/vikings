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
var continue_button: Button

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
	continue_button = get_node("Transfer/VBoxContainer/Button")
	
	# Get references to unit UI elements
	_get_unit_ui_references()
	_connect_unit_sliders()
	
	# Connect button signal
	continue_button.pressed.connect(_on_continue_pressed)
	
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

func _update_display() -> void:
	"""Update the display with current transfer information"""
	if target_region == null or target_army == null:
		hide_modal()
		return
	
	# Update target name
	target_name_label.text = target_army.name
	
	# Update source name
	if source_army != null:
		source_name_label.text = source_army.name
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
		var total_units = source_count + target_count
		unit_total_counts.append(total_units)
		unit_original_target_counts.append(target_count)
		unit_desired_target_counts.append(target_count)
		slider.step = 1.0
		slider.min_value = 0.0
		slider.max_value = float(total_units)
		slider.value = float(source_count)
		slider.editable = total_units > 0
	_ui_lock = false

func _on_unit_slider_changed(value: float, unit_index: int) -> void:
	"""Handle transfer adjustments triggered by sliders"""
	if _ui_lock:
		return
	if unit_index >= unit_desired_target_counts.size() or unit_index >= unit_source_value_labels.size():
		DebugLogger.log("UISystem", "ERROR: Unit index " + str(unit_index) + " out of bounds for transfer sliders")
		return
	var total_units: int = unit_total_counts[unit_index]
	var new_source: int = clamp(int(value), 0, total_units)
	var new_target: int = total_units - new_source
	unit_desired_target_counts[unit_index] = new_target
	unit_target_value_labels[unit_index].text = str(new_target)
	unit_source_value_labels[unit_index].text = str(new_source)

func _on_continue_pressed() -> void:
	"""Handle Continue button press"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Apply transfers based on pending button selections
	_apply_transfer_changes()
	
	# Hide modal
	hide_modal()

func _apply_transfer_changes() -> void:
	"""Apply transfers based on current button selections"""
	var has_transfers = false
	for i in range(unit_types.size()):
		var unit_type = unit_types[i]
		var original_target_count = unit_original_target_counts[i]
		var desired_target_count = unit_desired_target_counts[i]
		var transfer_amount = desired_target_count - original_target_count
		if transfer_amount == 0:
			continue
		has_transfers = true
		if transfer_amount > 0:
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
			target_army.remove_soldiers(unit_type, actual_transfer)
			if source_army != null:
				source_army.add_soldiers(unit_type, actual_transfer)
				DebugLogger.log("UISystem", "Transferred " + str(actual_transfer) + " " + SoldierTypeEnum.type_to_string(unit_type) + " from army " + str(target_army.number) + " to army " + str(source_army.number))
			else:
				target_region.get_garrison().add_soldiers(unit_type, actual_transfer)
				DebugLogger.log("UISystem", "Transferred " + str(actual_transfer) + " " + SoldierTypeEnum.type_to_string(unit_type) + " from army " + str(target_army.number) + " to garrison")
	if has_transfers:
		target_army.spend_movement_points(1)
		DebugLogger.log("UISystem", "Army " + str(target_army.number) + " spent 1 movement point for transfer (remaining: " + str(target_army.get_movement_points()) + ")")
