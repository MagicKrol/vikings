extends Control
class_name TransferSoldiersModal

# Styling constants (same as other modals)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# UI elements - references to static nodes from scene
var transfer_title_label: Label
var army_header_label: Label
var transfer_header_label: Label
var region_header_label: Label
var army_units_container: VBoxContainer
var total_army_label: Label
var total_region_label: Label
var continue_button: Button

# Transfer data
var source_army: Army = null
var target_army: Army = null  # Can be null if transferring to garrison
var target_region: Region = null
var transfer_counts: Dictionary = {} # unit_type -> count to transfer (positive = source to target, negative = target to source)

# Manager references
var sound_manager: SoundManager = null
var ui_manager: UIManager = null

func _ready():
	# Get references to static UI elements from scene
	transfer_title_label = get_node("BorderMargin/MainContainer/TitleContainer/TransferTitleLabel")
	army_header_label = get_node("BorderMargin/MainContainer/HeaderContainer/HeaderRow/ArmyHeaderLabel")
	transfer_header_label = get_node("BorderMargin/MainContainer/HeaderContainer/HeaderRow/TransferHeaderLabel")
	region_header_label = get_node("BorderMargin/MainContainer/HeaderContainer/HeaderRow/RegionHeaderLabel")
	army_units_container = get_node("BorderMargin/MainContainer/MainContent/ArmyUnitsContainer")
	total_army_label = get_node("BorderMargin/MainContainer/TotalRow/TotalRowContainer/TotalArmyLabel")
	total_region_label = get_node("BorderMargin/MainContainer/TotalRow/TotalRowContainer/TotalRegionLabel")
	continue_button = get_node("BorderMargin/MainContainer/ButtonContainer/ContinueButton")
	
	# Connect button signal
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Get manager references
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	
	# Initially hidden
	visible = false

func show_transfer_to_garrison(army: Army, region: Region) -> void:
	"""Show the transfer soldiers modal with army to garrison transfer"""
	if army == null or region == null:
		hide_modal()
		return
	
	source_army = army
	target_army = null  # Transfer to garrison
	target_region = region
	
	# Reset transfer state
	transfer_counts.clear()
	
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
	
	# Reset transfer state
	transfer_counts.clear()
	
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
	transfer_counts.clear()
	
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _update_display() -> void:
	"""Update the display with current transfer information"""
	if target_region == null or source_army == null:
		hide_modal()
		return
	
	# Update title
	transfer_title_label.text = "Transfer Soldiers"
	
	# Update headers
	army_header_label.text = "Army " + str(source_army.number)
	if target_army != null:
		# Army to army transfer
		region_header_label.text = "Army " + str(target_army.number)
	else:
		# Army to garrison transfer
		region_header_label.text = target_region.get_region_name()
	
	# Update transfer rows (single column layout)
	_update_transfer_display()
	
	# Update total row
	_update_total_row()

func _update_transfer_display() -> void:
	"""Update transfer controls and unit displays"""
	# Clear existing displays
	for child in army_units_container.get_children():
		child.queue_free()
	
	# Create transfer rows for all unit types (including peasants)
	for unit_type in SoldierTypeEnum.get_all_types():
		_create_transfer_row(unit_type)

func _create_transfer_row(unit_type: SoldierTypeEnum.Type) -> void:
	"""Create a single transfer row with: Unit Name | Army Count | Buttons | Garrison Count | Unit Name"""
	# Add margin before this row (except for the first row)
	if army_units_container.get_child_count() > 0:
		var margin = MarginContainer.new()
		margin.custom_minimum_size = Vector2(0, 5)
		army_units_container.add_child(margin)
	
	# Main row container
	var row_container = HBoxContainer.new()
	row_container.add_theme_constant_override("separation", 0)
	army_units_container.add_child(row_container)
	
	# Unit name (left-aligned, 200px width)
	var unit_label = Label.new()
	unit_label.text = SoldierTypeEnum.type_to_string(unit_type) + ":"
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	unit_label.custom_minimum_size = Vector2(200, 0)
	unit_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_standard_theme(unit_label)
	row_container.add_child(unit_label)
	
	# Current source army count (right-aligned, 80px width)
	var source_comp = source_army.get_composition()
	var source_count = source_comp.get_soldier_count(unit_type)
	var pending_transfer = transfer_counts.get(unit_type, 0)
	var display_source_count = source_count - pending_transfer
	
	var army_count_label = Label.new()
	army_count_label.text = str(display_source_count)
	army_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	army_count_label.custom_minimum_size = Vector2(80, 0)
	army_count_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_standard_theme(army_count_label)
	row_container.add_child(army_count_label)
	
	# Margin 50px
	var margin1 = Control.new()
	margin1.custom_minimum_size = Vector2(50, 0)
	row_container.add_child(margin1)
	
	# Transfer buttons: |< < > >|
	var transfer_all_to_army_button = Button.new()
	transfer_all_to_army_button.text = "|<"
	transfer_all_to_army_button.custom_minimum_size = Vector2(30, 25)
	transfer_all_to_army_button.pressed.connect(_on_transfer_all_to_army_pressed.bind(unit_type))
	row_container.add_child(transfer_all_to_army_button)
	
	var transfer_one_to_army_button = Button.new()
	transfer_one_to_army_button.text = "<"
	transfer_one_to_army_button.custom_minimum_size = Vector2(25, 25)
	transfer_one_to_army_button.pressed.connect(_on_transfer_one_to_army_pressed.bind(unit_type))
	row_container.add_child(transfer_one_to_army_button)
	
	var transfer_one_to_region_button = Button.new()
	transfer_one_to_region_button.text = ">"
	transfer_one_to_region_button.custom_minimum_size = Vector2(25, 25)
	transfer_one_to_region_button.pressed.connect(_on_transfer_one_to_region_pressed.bind(unit_type))
	row_container.add_child(transfer_one_to_region_button)
	
	var transfer_all_to_region_button = Button.new()
	transfer_all_to_region_button.text = ">|"
	transfer_all_to_region_button.custom_minimum_size = Vector2(30, 25)
	transfer_all_to_region_button.pressed.connect(_on_transfer_all_to_region_pressed.bind(unit_type))
	row_container.add_child(transfer_all_to_region_button)
	
	# Current target count (garrison or army) (right-aligned, 80px width)
	var target_count: int
	if target_army != null:
		# Army to army transfer
		var target_comp = target_army.get_composition()
		target_count = target_comp.get_soldier_count(unit_type)
	else:
		# Army to garrison transfer
		target_count = target_region.get_garrison().get_soldier_count(unit_type)
	var display_target_count = target_count + pending_transfer
	
	var target_count_label = Label.new()
	target_count_label.text = str(display_target_count)
	target_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	target_count_label.custom_minimum_size = Vector2(80, 0)
	target_count_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_standard_theme(target_count_label)
	row_container.add_child(target_count_label)
	
	# Margin 20px
	var margin3 = Control.new()
	margin3.custom_minimum_size = Vector2(20, 0)
	row_container.add_child(margin3)
	
	# Unit name for target (left-aligned, 120px width)
	var target_unit_label = Label.new()
	target_unit_label.text = SoldierTypeEnum.type_to_string(unit_type)
	target_unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	target_unit_label.custom_minimum_size = Vector2(120, 0)
	target_unit_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_standard_theme(target_unit_label)
	row_container.add_child(target_unit_label)

func _update_total_row() -> void:
	"""Update the total row with source and target totals"""
	# Calculate total units in source army
	var total_source_units = 0
	var source_comp = source_army.get_composition()
	for unit_type in SoldierTypeEnum.get_all_types():
		var count = source_comp.get_soldier_count(unit_type)
		var pending = transfer_counts.get(unit_type, 0)
		total_source_units += (count - pending)
	
	# Calculate total units in target (garrison or army)
	var total_target_units = 0
	for unit_type in SoldierTypeEnum.get_all_types():
		var count: int
		if target_army != null:
			# Army to army transfer
			var target_comp = target_army.get_composition()
			count = target_comp.get_soldier_count(unit_type)
		else:
			# Army to garrison transfer
			count = target_region.get_garrison().get_soldier_count(unit_type)
		var pending = transfer_counts.get(unit_type, 0)
		total_target_units += (count + pending)
	
	# Update labels
	total_army_label.text = str(total_source_units)
	total_region_label.text = str(total_target_units)

# Button handlers
func _on_transfer_all_to_region_pressed(unit_type: SoldierTypeEnum.Type) -> void:
	"""Transfer all units of this type from source army to target"""
	var source_comp = source_army.get_composition()
	var source_count = source_comp.get_soldier_count(unit_type)
	var pending_transfer = transfer_counts.get(unit_type, 0)
	var available_to_transfer = source_count - pending_transfer
	
	if available_to_transfer > 0:
		# Play click sound
		if sound_manager:
			sound_manager.click_sound()
		
		transfer_counts[unit_type] = source_count
		_update_transfer_display()
		_update_total_row()

func _on_transfer_one_to_region_pressed(unit_type: SoldierTypeEnum.Type) -> void:
	"""Transfer one unit of this type from source army to target"""
	var source_comp = source_army.get_composition()
	var source_count = source_comp.get_soldier_count(unit_type)
	var pending_transfer = transfer_counts.get(unit_type, 0)
	
	# Check if we can transfer (source army has units available)
	if (source_count - pending_transfer) > 0:
		# Play click sound
		if sound_manager:
			sound_manager.click_sound()
		
		transfer_counts[unit_type] = pending_transfer + 1
		_update_transfer_display()
		_update_total_row()

func _on_transfer_one_to_army_pressed(unit_type: SoldierTypeEnum.Type) -> void:
	"""Transfer one unit of this type from target to source army"""
	var target_count: int
	if target_army != null:
		# Army to army transfer
		var target_comp = target_army.get_composition()
		target_count = target_comp.get_soldier_count(unit_type)
	else:
		# Army to garrison transfer
		target_count = target_region.get_garrison().get_soldier_count(unit_type)
	var pending_transfer = transfer_counts.get(unit_type, 0)
	
	# Check if we can transfer (target has units available)
	if (target_count + pending_transfer) > 0:
		# Play click sound
		if sound_manager:
			sound_manager.click_sound()
		
		transfer_counts[unit_type] = pending_transfer - 1
		_update_transfer_display()
		_update_total_row()

func _on_transfer_all_to_army_pressed(unit_type: SoldierTypeEnum.Type) -> void:
	"""Transfer all units of this type from target to source army"""
	var target_count: int
	if target_army != null:
		# Army to army transfer
		var target_comp = target_army.get_composition()
		target_count = target_comp.get_soldier_count(unit_type)
	else:
		# Army to garrison transfer
		target_count = target_region.get_garrison().get_soldier_count(unit_type)
	var pending_transfer = transfer_counts.get(unit_type, 0)
	var available_to_transfer = target_count + pending_transfer
	
	if available_to_transfer > 0:
		# Play click sound
		if sound_manager:
			sound_manager.click_sound()
		
		transfer_counts[unit_type] = -target_count
		_update_transfer_display()
		_update_total_row()

func _on_continue_pressed() -> void:
	"""Handle Continue button press"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Apply transfers if any were made
	if not transfer_counts.is_empty():
		_apply_transfers()
		# Spend 1 movement point from source army for transfer operation
		if source_army != null:
			source_army.spend_movement_points(1)
			DebugLogger.log("UISystem", "Army " + str(source_army.number) + " spent 1 movement point for transfer (remaining: " + str(source_army.get_movement_points()) + ")")
	
	# Clear state and hide modal
	source_army = null
	target_army = null
	target_region = null
	transfer_counts.clear()
	
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _apply_transfers() -> void:
	"""Apply the transfers between source and target"""
	for unit_type in transfer_counts:
		var transfer_amount = transfer_counts[unit_type]
		if transfer_amount == 0:
			continue
		
		if transfer_amount > 0:
			# Transfer from source army to target
			source_army.remove_soldiers(unit_type, transfer_amount)
			if target_army != null:
				# Army to army transfer
				target_army.add_soldiers(unit_type, transfer_amount)
				DebugLogger.log("UISystem", "Transferred " + str(transfer_amount) + " " + SoldierTypeEnum.type_to_string(unit_type) + " from army " + str(source_army.number) + " to army " + str(target_army.number))
			else:
				# Army to garrison transfer
				target_region.get_garrison().add_soldiers(unit_type, transfer_amount)
				DebugLogger.log("UISystem", "Transferred " + str(transfer_amount) + " " + SoldierTypeEnum.type_to_string(unit_type) + " from army " + str(source_army.number) + " to garrison")
		else:
			# Transfer from target to source army
			var actual_transfer = -transfer_amount
			if target_army != null:
				# Army to army transfer
				target_army.remove_soldiers(unit_type, actual_transfer)
				DebugLogger.log("UISystem", "Transferred " + str(actual_transfer) + " " + SoldierTypeEnum.type_to_string(unit_type) + " from army " + str(target_army.number) + " to army " + str(source_army.number))
			else:
				# Army to garrison transfer
				target_region.get_garrison().remove_soldiers(unit_type, actual_transfer)
				DebugLogger.log("UISystem", "Transferred " + str(actual_transfer) + " " + SoldierTypeEnum.type_to_string(unit_type) + " from garrison to army " + str(source_army.number))
			source_army.add_soldiers(unit_type, actual_transfer)

func _apply_standard_theme(label: Label) -> void:
	"""Apply standard theme to a label"""
	label.theme = preload("res://themes/standard_text_theme.tres")
	label.add_theme_color_override("font_color", Color.WHITE)

func _draw():
	# Draw shadow first (behind everything)
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)
	
	# Draw background fill
	var bg_rect = Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, FRAME_COLOR)
	
	# Draw black border on top
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)