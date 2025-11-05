extends Control
class_name TransferSoldiersModal

# UI elements - references to static nodes from scene
var army_name_label: Label
var target_name_label: Label
const UNIT_CONTAINER_PATHS := [
	"Panel/Army/UnitsSection/Peasants",
	"Panel/Army/UnitsSection/Peasants2",
	"Panel/Army/UnitsSection/Peasants3",
	"Panel/Army/UnitsSection/Peasants4",
	"Panel/Army/UnitsSection/Peasants5",
	"Panel/Army/UnitsSection/Peasants6",
	"Panel/Army/UnitsSection/Peasants7",
	"Panel/Army/UnitsSection/Peasants8",
	"Panel/Army/UnitsSection/Peasants9"
]

var unit_value_labels: Array[Label] = []
var unit_target_value_labels: Array[Label] = []
var unit_total_counts: Array[int] = []
var unit_original_target_counts: Array[int] = []
var unit_desired_target_counts: Array[int] = []
var total_value_label: Label
var total_target_value_label: Label
var continue_button: Button

# Transfer data
var source_army: Army = null
var target_army: Army = null  # Can be null if transferring to garrison
var target_region: Region = null

# Unit types in order (matching scene structure)
var unit_types = [
	SoldierTypeEnum.Type.PEASANTS,
	SoldierTypeEnum.Type.ARCHERS,
	SoldierTypeEnum.Type.SPEARMEN,
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
var _ui_lock: bool = false

func _ready():
	# Get references to static UI elements from scene
	army_name_label = get_node("Panel/Army/HeaderSection/HBoxContainer/ArmyName")
	target_name_label = get_node("Panel/Army/HeaderSection/HBoxContainer/TargetName")
	total_value_label = get_node("Panel/Army/TotalSection/HBoxContainer/TotalValue")
	total_target_value_label = get_node("Panel/Army/TotalSection/HBoxContainer/TotalTargetValue")
	continue_button = get_node("Panel/Army/ButtonSection/HBoxContainer/Button")
	
	# Get references to unit UI elements
	_get_unit_ui_references()
	_connect_unit_buttons()
	
	# Connect button signal
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Get manager references
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	
	# Initially hidden
	visible = false


func _get_unit_ui_references():
	unit_value_labels.clear()
	unit_target_value_labels.clear()
	unit_total_counts.clear()
	unit_original_target_counts.clear()
	unit_desired_target_counts.clear()
	
	# Get references to sliders and value labels for each unit type
	DebugLogger.log("UISystem", "Getting UI references for " + str(UNIT_CONTAINER_PATHS.size()) + " unit containers")

	for container_path in UNIT_CONTAINER_PATHS:
		var value_label = get_node(container_path + "/Value") as Label
		var target_value_label = get_node(container_path + "/TargetValue") as Label
		unit_value_labels.append(value_label)
		unit_target_value_labels.append(target_value_label)

	DebugLogger.log("UISystem", "Cached arrays - Value labels: " + str(unit_value_labels.size()) + ", Target value labels: " + str(unit_target_value_labels.size()))

func _connect_unit_buttons():
	DebugLogger.log("UISystem", "Connecting transfer buttons. Unit count: " + str(UNIT_CONTAINER_PATHS.size()))
	for i in range(UNIT_CONTAINER_PATHS.size()):
		var base_path = UNIT_CONTAINER_PATHS[i]
		(get_node(base_path + "/Button10") as Button).pressed.connect(_on_transfer_button_pressed.bind(i, 10))
		(get_node(base_path + "/Button1") as Button).pressed.connect(_on_transfer_button_pressed.bind(i, 1))
		(get_node(base_path + "/Button1m") as Button).pressed.connect(_on_transfer_button_pressed.bind(i, -1))
		(get_node(base_path + "/Button10m") as Button).pressed.connect(_on_transfer_button_pressed.bind(i, -10))

func show_transfer_to_garrison(army: Army, region: Region) -> void:
	"""Show the transfer soldiers modal with army to garrison transfer"""
	if army == null or region == null:
		hide_modal()
		return
	
	source_army = army
	target_army = null  # Transfer to garrison
	target_region = region
	
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
	
	source_army = source
	target_army = target
	target_region = region
	
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
	# Reset state
	source_army = null
	target_army = null
	target_region = null
	
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _update_display() -> void:
	"""Update the display with current transfer information"""
	if target_region == null or source_army == null:
		hide_modal()
		return
	
	# Update army name
	army_name_label.text = source_army.name
	
	# Update target name
	if target_army != null:
		# Army to army transfer
		target_name_label.text = target_army.name
	else:
		# Army to garrison transfer
		target_name_label.text = target_region.get_region_name()
	
	# Update unit displays and sliders
	_update_unit_displays()
	
	# Update total row
	_update_total_row()

func _update_unit_displays() -> void:
	"""Update all unit value labels and pending transfer data"""
	_ui_lock = true
	unit_total_counts.clear()
	unit_original_target_counts.clear()
	unit_desired_target_counts.clear()
	for i in range(unit_types.size()):
		var unit_type = unit_types[i]
		var value_label = unit_value_labels[i]
		var target_value_label = unit_target_value_labels[i]
		var source_count = source_army.get_soldier_count(unit_type)
		var target_count: int
		if target_army != null:
			target_count = target_army.get_soldier_count(unit_type)
		else:
			target_count = target_region.get_garrison().get_soldier_count(unit_type)
		DebugLogger.log("UISystem", "Unit " + SoldierTypeEnum.type_to_string(unit_type) + ": source=" + str(source_count) + ", target=" + str(target_count))
		value_label.text = str(source_count)
		target_value_label.text = str(target_count)
		var total_units = source_count + target_count
		unit_total_counts.append(total_units)
		unit_original_target_counts.append(target_count)
		unit_desired_target_counts.append(target_count)
	_ui_lock = false
	_update_total_row()

func _update_total_row() -> void:
	"""Update the total row using pending transfer values"""
	var total_source = 0
	var total_target = 0
	for i in range(unit_desired_target_counts.size()):
		var target_count = unit_desired_target_counts[i]
		var total_units = unit_total_counts[i]
		total_target += target_count
		total_source += total_units - target_count
	total_value_label.text = str(total_source)
	total_target_value_label.text = str(total_target)

func _on_transfer_button_pressed(unit_index: int, delta: int) -> void:
	"""Handle transfer adjustments triggered by unit buttons"""
	if _ui_lock:
		return
	if unit_index >= unit_desired_target_counts.size() or unit_index >= unit_value_labels.size():
		DebugLogger.log("UISystem", "ERROR: Unit index " + str(unit_index) + " out of bounds for transfer buttons")
		return
	var total_units = unit_total_counts[unit_index]
	var current_target = unit_desired_target_counts[unit_index]
	var current_source = total_units - current_target
	var new_source = clamp(current_source + delta, 0, total_units)
	if new_source == current_source:
		return
	var new_target = total_units - new_source
	unit_desired_target_counts[unit_index] = new_target
	unit_value_labels[unit_index].text = str(new_source)
	unit_target_value_labels[unit_index].text = str(new_target)
	_update_total_row()

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
			source_army.remove_soldiers(unit_type, transfer_amount)
			if target_army != null:
				target_army.add_soldiers(unit_type, transfer_amount)
				DebugLogger.log("UISystem", "Transferred " + str(transfer_amount) + " " + SoldierTypeEnum.type_to_string(unit_type) + " from army " + str(source_army.number) + " to army " + str(target_army.number))
			else:
				target_region.get_garrison().add_soldiers(unit_type, transfer_amount)
				DebugLogger.log("UISystem", "Transferred " + str(transfer_amount) + " " + SoldierTypeEnum.type_to_string(unit_type) + " from army " + str(source_army.number) + " to garrison")
		else:
			# Transfer from target to source
			var actual_transfer = -transfer_amount
			if target_army != null:
				target_army.remove_soldiers(unit_type, actual_transfer)
				DebugLogger.log("UISystem", "Transferred " + str(actual_transfer) + " " + SoldierTypeEnum.type_to_string(unit_type) + " from army " + str(target_army.number) + " to army " + str(source_army.number))
			else:
				target_region.get_garrison().remove_soldiers(unit_type, actual_transfer)
				DebugLogger.log("UISystem", "Transferred " + str(actual_transfer) + " " + SoldierTypeEnum.type_to_string(unit_type) + " from garrison to army " + str(source_army.number))
			source_army.add_soldiers(unit_type, actual_transfer)
	if has_transfers:
		source_army.spend_movement_points(1)
		DebugLogger.log("UISystem", "Army " + str(source_army.number) + " spent 1 movement point for transfer (remaining: " + str(source_army.get_movement_points()) + ")")
