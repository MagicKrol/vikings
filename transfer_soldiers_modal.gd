extends Control
class_name TransferSoldiersModal

# UI elements - references to static nodes from scene
var army_name_label: Label
var target_name_label: Label
var unit_sliders: Array[HSlider] = []
var unit_value_labels: Array[Label] = []
var unit_target_value_labels: Array[Label] = []
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
	
	# Connect button signal
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Connect slider signals
	_connect_slider_signals()
	
	# Get manager references
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	
	# Initially hidden
	visible = false

func _get_unit_ui_references():
	# Clear arrays first in case this is called multiple times
	unit_sliders.clear()
	unit_value_labels.clear()
	unit_target_value_labels.clear()
	
	# Get references to sliders and value labels for each unit type
	var unit_containers = [
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
	
	DebugLogger.log("UISystem", "Getting UI references for " + str(unit_containers.size()) + " unit containers")
	
	for i in range(unit_containers.size()):
		var container_path = unit_containers[i]
		var slider = get_node(container_path + "/Slider")
		var value_label = get_node(container_path + "/Value")
		var target_value_label = get_node(container_path + "/TargetValue")
		
		unit_sliders.append(slider)
		unit_value_labels.append(value_label)
		unit_target_value_labels.append(target_value_label)
	
	DebugLogger.log("UISystem", "Created arrays with sizes - Sliders: " + str(unit_sliders.size()) + ", Value labels: " + str(unit_value_labels.size()) + ", Target value labels: " + str(unit_target_value_labels.size()))

func _connect_slider_signals():
	DebugLogger.log("UISystem", "Connecting slider signals. Slider count: " + str(unit_sliders.size()) + ", Unit types count: " + str(unit_types.size()))
	for i in range(unit_sliders.size()):
		var slider = unit_sliders[i]
		var unit_type = unit_types[i]
		DebugLogger.log("UISystem", "Connecting slider " + str(i) + " for unit type: " + SoldierTypeEnum.type_to_string(unit_type))
		slider.value_changed.connect(_on_slider_value_changed.bind(i, unit_type))
		slider.step = 1.0

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
	"""Update all unit value labels and slider configurations"""
	_ui_lock = true
	for i in range(unit_types.size()):
		var unit_type = unit_types[i]
		var slider = unit_sliders[i]
		var value_label = unit_value_labels[i]
		var target_value_label = unit_target_value_labels[i]
		
		# Get original counts directly from armies
		var source_count = source_army.get_soldier_count(unit_type)
		var target_count: int
		if target_army != null:
			target_count = target_army.get_soldier_count(unit_type)
		else:
			target_count = target_region.get_garrison().get_soldier_count(unit_type)
		
		# Debug logging to see what we're getting
		DebugLogger.log("UISystem", "Unit " + SoldierTypeEnum.type_to_string(unit_type) + ": source=" + str(source_count) + ", target=" + str(target_count))
		
		# Set labels to show current army counts
		value_label.text = str(source_count)
		target_value_label.text = str(target_count)
		
		# Configure slider: min=0, max=total available units, current=target count
		var total_units = source_count + target_count
		slider.min_value = 0
		slider.max_value = total_units
		slider.value = target_count
		slider.step = 1.0
	# Unlock after finishing all sliders setup
	_ui_lock = false

func _update_total_row() -> void:
	"""Update the total row with source and target totals"""
	var total_source = 0
	var total_target = 0
	
	for unit_type in unit_types:
		total_source += source_army.get_soldier_count(unit_type)
		
		if target_army != null:
			total_target += target_army.get_soldier_count(unit_type)
		else:
			total_target += target_region.get_garrison().get_soldier_count(unit_type)
	
	total_value_label.text = str(total_source)
	total_target_value_label.text = str(total_target)

func _on_slider_value_changed(new_value: float, slider_index: int, unit_type: SoldierTypeEnum.Type) -> void:
	"""Handle slider value changes - update the displays"""
	if _ui_lock:
		return
	# Bounds check to prevent crashes
	if slider_index >= unit_target_value_labels.size() or slider_index >= unit_value_labels.size():
		DebugLogger.log("UISystem", "ERROR: Slider index " + str(slider_index) + " out of bounds. Array size: " + str(unit_target_value_labels.size()))
		return
	
	# Get original counts for THIS unit type only
	var original_source_count = source_army.get_soldier_count(unit_type)
	var original_target_count: int
	
	if target_army != null:
		original_target_count = target_army.get_soldier_count(unit_type)
	else:
		original_target_count = target_region.get_garrison().get_soldier_count(unit_type)
	
	# Calculate new distribution for this unit type
	var total_units_of_this_type = original_source_count + original_target_count
	var new_target_count = int(new_value)
	var new_source_count = total_units_of_this_type - new_target_count
	
	# Update labels for THIS unit type only
	unit_value_labels[slider_index].text = str(new_source_count)
	unit_target_value_labels[slider_index].text = str(new_target_count)
	
	# Update totals
	_update_totals_simple()

func _update_totals_simple() -> void:
	"""Update totals by simply reading the current label values"""
	var total_source = 0
	var total_target = 0
	
	for i in range(unit_value_labels.size()):
		var source_count = int(unit_value_labels[i].text)
		var target_count = int(unit_target_value_labels[i].text)
		
		total_source += source_count
		total_target += target_count
	
	total_value_label.text = str(total_source)
	total_target_value_label.text = str(total_target)

func _on_continue_pressed() -> void:
	"""Handle Continue button press"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Apply transfers based on slider positions
	_apply_slider_transfers()
	
	# Hide modal
	hide_modal()

func _apply_slider_transfers() -> void:
	"""Apply transfers based on current slider positions"""
	var has_transfers = false
	
	for i in range(unit_types.size()):
		var unit_type = unit_types[i]
		var slider = unit_sliders[i]
		
		# Get original counts
		var source_comp = source_army.get_composition()
		var original_source_count = source_comp.get_soldier_count(unit_type)
		var original_target_count: int
		
		if target_army != null:
			var target_comp = target_army.get_composition()
			original_target_count = target_comp.get_soldier_count(unit_type)
		else:
			original_target_count = target_region.get_garrison().get_soldier_count(unit_type)
		
		# Calculate desired target count from slider
		var desired_target_count = int(slider.value)
		var transfer_amount = desired_target_count - original_target_count
		
		if transfer_amount != 0:
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
	
	# Spend movement point if transfers were made
	if has_transfers and source_army != null:
		source_army.spend_movement_points(1)
		DebugLogger.log("UISystem", "Army " + str(source_army.number) + " spent 1 movement point for transfer (remaining: " + str(source_army.get_movement_points()) + ")")
