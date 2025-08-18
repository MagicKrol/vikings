extends Control
class_name BattleModal

# Styling constants (same as other modals)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# UI elements - new layout
var main_container: VBoxContainer
var battle_title_label: Label
var attacker_column: VBoxContainer  
var defender_column: VBoxContainer
var attacker_header: Label
var defender_header: Label
var attacker_effectiveness: Label
var defender_effectiveness: Label
var attacker_units_container: VBoxContainer
var defender_units_container: VBoxContainer
var close_button: Button

# Battle data
var attacking_army: Army = null
var defending_region: Region = null
var battle_report: BattleSimulator.BattleReport = null
var animated_simulator: AnimatedBattleSimulator = null
var battle_in_progress: bool = false

# Real-time battle display data
var current_round: int = 0
var current_attacker_composition: Dictionary = {}
var current_defender_composition: Dictionary = {}

# Battle report state
var showing_battle_report: bool = false

# Sound manager reference
var sound_manager: SoundManager = null
# UI manager reference for modal mode
var ui_manager: UIManager = null
# Click manager reference for conquest completion
var click_manager: Node = null

func _ready():
	# Get manager references
	sound_manager = get_node_or_null("../../SoundManager") as SoundManager
	ui_manager = get_node_or_null("../UIManager") as UIManager
	click_manager = get_node_or_null("../../ClickManager")
	
	# Create UI programmatically first
	_create_ui()
	
	# Then create animated battle simulator
	animated_simulator = AnimatedBattleSimulator.new()
	animated_simulator.round_completed.connect(_on_battle_round_completed)
	animated_simulator.battle_finished.connect(_on_battle_finished)
	add_child(animated_simulator)
	
	# Initially hidden
	visible = false

func _create_ui():
	"""Create the UI layout programmatically"""
	# Clear any existing children from the scene
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	# Main container - 3 rows: title, main content, button
	# Add margin container to leave space for border and shadow
	var border_margin = MarginContainer.new()
	border_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border_margin.add_theme_constant_override("margin_left", int(BORDER_WIDTH))
	border_margin.add_theme_constant_override("margin_right", int(BORDER_WIDTH + SHADOW_OFFSET.x))
	border_margin.add_theme_constant_override("margin_top", int(BORDER_WIDTH))
	border_margin.add_theme_constant_override("margin_bottom", int(BORDER_WIDTH + SHADOW_OFFSET.y))
	add_child(border_margin)
	
	main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 0)
	border_margin.add_child(main_container)
	
	# Top row (10% height) - Battle title
	var title_container = Control.new()
	title_container.custom_minimum_size = Vector2(0, 60)  # Fixed height for title
	main_container.add_child(title_container)
	
	battle_title_label = Label.new()
	battle_title_label.text = "Battle for Region"
	battle_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	battle_title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_header_theme(battle_title_label, 40)  # 32 * 1.25 = 40
	title_container.add_child(battle_title_label)
	
	# Main row (80% height) - Two columns
	var main_content = HBoxContainer.new()
	main_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_content.add_theme_constant_override("separation", 20)  # Gap between columns
	main_container.add_child(main_content)
	
	# Attacker column (left)
	_create_attacker_column(main_content)
	
	# Defender column (right)  
	_create_defender_column(main_content)
	
	# Bottom row (10% height) - Close button
	var button_container = Control.new()
	button_container.custom_minimum_size = Vector2(0, 60)  # Fixed height for button
	main_container.add_child(button_container)
	
	close_button = Button.new()
	close_button.text = "Continue"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.custom_minimum_size = Vector2(120, 40)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	close_button.pressed.connect(_on_ok_pressed)
	button_container.add_child(close_button)

func _create_attacker_column(parent: Control):
	"""Create the attacker (left) column"""
	# Column container with margins
	var column_margin = MarginContainer.new()
	column_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column_margin.add_theme_constant_override("margin_left", 20)
	column_margin.add_theme_constant_override("margin_right", 10)
	column_margin.add_theme_constant_override("margin_top", 10)
	column_margin.add_theme_constant_override("margin_bottom", 10)
	parent.add_child(column_margin)
	
	attacker_column = VBoxContainer.new()
	attacker_column.add_theme_constant_override("separation", 5)
	column_margin.add_child(attacker_column)
	
	# Header
	attacker_header = Label.new()
	attacker_header.text = "Attacker"
	attacker_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attacker_header.add_theme_constant_override("margin_top", 10)
	attacker_header.add_theme_constant_override("margin_bottom", 10)
	_apply_header_theme(attacker_header, 30)  # 24 * 1.25 = 30
	attacker_column.add_child(attacker_header)
	
	# Effectiveness
	attacker_effectiveness = Label.new()
	attacker_effectiveness.text = "Effectiveness: 80%"
	attacker_effectiveness.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	attacker_effectiveness.add_theme_constant_override("margin_bottom", 15)
	_apply_standard_theme(attacker_effectiveness, 22)  # 18 * 1.25 = 22.5, rounded to 22
	attacker_column.add_child(attacker_effectiveness)
	
	# Units container
	attacker_units_container = VBoxContainer.new()
	attacker_units_container.add_theme_constant_override("separation", 3)
	attacker_column.add_child(attacker_units_container)

func _create_defender_column(parent: Control):
	"""Create the defender (right) column"""
	# Column container with margins
	var column_margin = MarginContainer.new()
	column_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column_margin.add_theme_constant_override("margin_left", 10)
	column_margin.add_theme_constant_override("margin_right", 20)
	column_margin.add_theme_constant_override("margin_top", 10)
	column_margin.add_theme_constant_override("margin_bottom", 10)
	parent.add_child(column_margin)
	
	defender_column = VBoxContainer.new()
	defender_column.add_theme_constant_override("separation", 5)
	column_margin.add_child(defender_column)
	
	# Header
	defender_header = Label.new()
	defender_header.text = "Defender"
	defender_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defender_header.add_theme_constant_override("margin_top", 10)
	defender_header.add_theme_constant_override("margin_bottom", 10)
	_apply_header_theme(defender_header, 30)  # 24 * 1.25 = 30
	defender_column.add_child(defender_header)
	
	# Effectiveness
	defender_effectiveness = Label.new()
	defender_effectiveness.text = "Effectiveness: 75%"
	defender_effectiveness.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	defender_effectiveness.add_theme_constant_override("margin_bottom", 15)
	_apply_standard_theme(defender_effectiveness, 22)  # 18 * 1.25 = 22.5, rounded to 22
	defender_column.add_child(defender_effectiveness)
	
	# Units container
	defender_units_container = VBoxContainer.new()
	defender_units_container.add_theme_constant_override("separation", 3)
	defender_column.add_child(defender_units_container)

func show_battle(army: Army, region: Region) -> void:
	"""Show the battle modal with army vs region information"""
	if army == null or region == null:
		hide_modal()
		return
	
	attacking_army = army
	defending_region = region
	
	# Run battle simulation
	_run_battle_simulation()
	
	_update_display()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)

func hide_modal() -> void:
	"""Hide the battle modal"""
	print("[BattleModal] Hiding modal and notifying click manager...")
	
	# Stop any ongoing battle animation
	if animated_simulator and animated_simulator.is_running():
		animated_simulator.stop_battle()
	
	# Notify click manager about battle modal closure for conquest completion
	if click_manager and click_manager.has_method("on_battle_modal_closed"):
		click_manager.on_battle_modal_closed()
	
	# Reset state
	attacking_army = null
	defending_region = null
	battle_report = null
	battle_in_progress = false
	showing_battle_report = false
	current_round = 0
	current_attacker_composition.clear()
	current_defender_composition.clear()
	
	# Reset button
	if close_button:
		close_button.disabled = false
		close_button.text = "Continue"
	
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _update_display() -> void:
	"""Update the display with current battle information"""
	if attacking_army == null or defending_region == null:
		hide_modal()
		return
	
	if showing_battle_report:
		# Show battle report screen
		_display_battle_report()
	else:
		# Show normal battle screen
		# Update battle title
		var region_name = defending_region.get_region_name()
		battle_title_label.text = "Battle for " + region_name
		
		# Ensure headers and effectiveness are visible for normal battle
		attacker_header.text = "Attacker"
		defender_header.text = "Defender"
		attacker_effectiveness.visible = true
		defender_effectiveness.visible = true
		
		# Update attacker units
		_update_attacker_units()
		
		# Update defender units  
		_update_defender_units()

func _display_battle_report() -> void:
	"""Display the battle report screen"""
	# Update title
	battle_title_label.text = "Battle Report"
	
	# Clear both unit containers for report display
	for child in attacker_units_container.get_children():
		child.queue_free()
	for child in defender_units_container.get_children():
		child.queue_free()
	
	# Hide effectiveness labels (not needed for report)
	attacker_effectiveness.visible = false
	defender_effectiveness.visible = false
	
	# Change column headers
	attacker_header.text = "Your Losses"
	defender_header.text = "Enemy Losses"
	
	# Display losses if we have battle report
	if battle_report != null:
		_display_army_losses()
	
	# Update button text for final screen
	if close_button:
		close_button.text = "Continue"

func _display_army_losses() -> void:
	"""Display losses for both armies in the report format"""
	# Display attacker losses (your losses)
	if not battle_report.attacker_losses.is_empty():
		for unit_type in SoldierTypeEnum.get_all_types():
			if battle_report.attacker_losses.has(unit_type) and battle_report.attacker_losses[unit_type] > 0:
				_create_attacker_loss_row(unit_type, battle_report.attacker_losses[unit_type])
	else:
		# No losses
		_create_no_losses_label(attacker_units_container, "No losses!")
	
	# Display defender losses (enemy losses)
	if not battle_report.defender_losses.is_empty():
		for unit_type in SoldierTypeEnum.get_all_types():
			if battle_report.defender_losses.has(unit_type) and battle_report.defender_losses[unit_type] > 0:
				_create_defender_loss_row(unit_type, battle_report.defender_losses[unit_type])
	else:
		# No losses
		_create_no_losses_label(defender_units_container, "No losses!")

func _create_attacker_loss_row(unit_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Create a loss row for attacker: 'Unit: <count>' with right-aligned count"""
	var row_container = HBoxContainer.new()
	row_container.add_theme_constant_override("separation", 0)
	attacker_units_container.add_child(row_container)
	
	# Unit name (left-aligned)
	var unit_label = Label.new()
	unit_label.text = SoldierTypeEnum.type_to_string(unit_type) + ":"
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	unit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_standard_theme(unit_label, 20)
	row_container.add_child(unit_label)
	
	# Count (right-aligned, fixed width)
	var count_label = Label.new()
	count_label.text = str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.custom_minimum_size = Vector2(60, 0)
	_apply_standard_theme(count_label, 20)
	row_container.add_child(count_label)

func _create_defender_loss_row(unit_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Create a loss row for defender: '<count> :Unit' with left-aligned count"""
	var row_container = HBoxContainer.new()
	row_container.add_theme_constant_override("separation", 0)
	defender_units_container.add_child(row_container)
	
	# Count (left-aligned, fixed width)
	var count_label = Label.new()
	count_label.text = str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	count_label.custom_minimum_size = Vector2(60, 0)
	_apply_standard_theme(count_label, 20)
	row_container.add_child(count_label)
	
	# Unit name (right-aligned)
	var unit_label = Label.new()
	unit_label.text = " :" + SoldierTypeEnum.type_to_string(unit_type)
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	unit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_standard_theme(unit_label, 20)
	row_container.add_child(unit_label)

func _create_no_losses_label(container: VBoxContainer, text: String) -> void:
	"""Create a 'no losses' label for cases where there were no casualties"""
	var no_loss_label = Label.new()
	no_loss_label.text = text
	no_loss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_standard_theme(no_loss_label, 20)
	container.add_child(no_loss_label)

func _update_attacker_units() -> void:
	"""Update attacker unit display"""
	# Clear existing unit displays
	for child in attacker_units_container.get_children():
		child.queue_free()
	
	# Get current composition to display
	var composition_to_show: Dictionary
	if battle_in_progress:
		composition_to_show = current_attacker_composition
	elif battle_report != null:
		composition_to_show = battle_report.final_attacker
	else:
		# Initial composition
		composition_to_show = {}
		var army_comp = attacking_army.get_composition()
		for unit_type in SoldierTypeEnum.get_all_types():
			var count = army_comp.get_soldier_count(unit_type)
			if count > 0:
				composition_to_show[unit_type] = count
	
	# Create unit display rows
	for unit_type in SoldierTypeEnum.get_all_types():
		if composition_to_show.has(unit_type) and composition_to_show[unit_type] > 0:
			_create_attacker_unit_row(unit_type, composition_to_show[unit_type])

func _update_defender_units() -> void:
	"""Update defender unit display"""
	# Clear existing unit displays
	for child in defender_units_container.get_children():
		child.queue_free()
	
	# Get current composition to display
	var composition_to_show: Dictionary
	if battle_in_progress:
		composition_to_show = current_defender_composition
	elif battle_report != null:
		composition_to_show = battle_report.final_defender
	else:
		# Initial composition
		composition_to_show = {}
		var garrison_comp = defending_region.get_garrison()
		for unit_type in SoldierTypeEnum.get_all_types():
			var count = garrison_comp.get_soldier_count(unit_type)
			if count > 0:
				composition_to_show[unit_type] = count
	
	# Create unit display rows
	for unit_type in SoldierTypeEnum.get_all_types():
		if composition_to_show.has(unit_type) and composition_to_show[unit_type] > 0:
			_create_defender_unit_row(unit_type, composition_to_show[unit_type])

func _create_attacker_unit_row(unit_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Create a unit row for attacker: 'Unit: <count>' with right-aligned count"""
	var row_container = HBoxContainer.new()
	row_container.add_theme_constant_override("separation", 0)
	attacker_units_container.add_child(row_container)
	
	# Unit name (left-aligned)
	var unit_label = Label.new()
	unit_label.text = SoldierTypeEnum.type_to_string(unit_type) + ":"
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	unit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_standard_theme(unit_label, 20)  # 16 * 1.25 = 20
	row_container.add_child(unit_label)
	
	# Count (right-aligned, fixed width)
	var count_label = Label.new()
	count_label.text = str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.custom_minimum_size = Vector2(60, 0)  # Fixed width for counts
	_apply_standard_theme(count_label, 20)  # 16 * 1.25 = 20
	row_container.add_child(count_label)

func _create_defender_unit_row(unit_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Create a unit row for defender: '<count> :Unit' with left-aligned count"""
	var row_container = HBoxContainer.new()
	row_container.add_theme_constant_override("separation", 0)
	defender_units_container.add_child(row_container)
	
	# Count (left-aligned, fixed width)
	var count_label = Label.new()
	count_label.text = str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	count_label.custom_minimum_size = Vector2(60, 0)  # Fixed width for counts
	_apply_standard_theme(count_label, 20)  # 16 * 1.25 = 20
	row_container.add_child(count_label)
	
	# Unit name (right-aligned)
	var unit_label = Label.new()
	unit_label.text = " :" + SoldierTypeEnum.type_to_string(unit_type)
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	unit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_standard_theme(unit_label, 20)  # 16 * 1.25 = 20
	row_container.add_child(unit_label)

func _run_battle_simulation() -> void:
	"""Run the animated battle simulation between attacking army and region garrison"""
	if attacking_army == null or defending_region == null:
		return
	
	battle_in_progress = true
	current_round = 0
	
	# Reset display data
	current_attacker_composition = {}
	current_defender_composition = {}
	
	# Store initial compositions for display
	var army_comp = attacking_army.get_composition()
	for unit_type in SoldierTypeEnum.get_all_types():
		var count = army_comp.get_soldier_count(unit_type)
		if count > 0:
			current_attacker_composition[unit_type] = count
	
	var garrison_comp = defending_region.get_garrison()
	for unit_type in SoldierTypeEnum.get_all_types():
		var count = garrison_comp.get_soldier_count(unit_type)
		if count > 0:
			current_defender_composition[unit_type] = count
	
	# Disable close button during battle
	if close_button:
		close_button.disabled = true
		close_button.text = "Battle in Progress..."
	
	# Get attacking armies (just one for now)
	var attacking_compositions = [attacking_army.get_composition()]
	
	# Get defending forces (region garrison)
	var defending_compositions = []
	var region_garrison = defending_region.get_garrison()
	
	# Start the animated battle
	animated_simulator.start_animated_battle(attacking_compositions, defending_compositions, region_garrison)
	
	print("[BattleModal] Starting animated battle simulation...")

func _on_battle_round_completed(round_data: Dictionary) -> void:
	"""Handle completion of a battle round"""
	current_round = round_data["round"]
	current_attacker_composition = round_data["current_attackers"]
	current_defender_composition = round_data["current_defenders"]
	
	# Update display with current round data
	_update_display()
	
	print("[BattleModal] Round ", current_round, " completed - Attackers: ", round_data["attacker_size"], ", Defenders: ", round_data["defender_size"])

func _on_battle_finished(report: BattleSimulator.BattleReport) -> void:
	"""Handle battle completion"""
	battle_in_progress = false
	battle_report = report
	
	# Re-enable close button
	if close_button:
		close_button.disabled = false
		close_button.text = "Continue"
	
	# Final display update
	_update_display()
	
	print("[BattleModal] Battle finished! Winner: ", report.winner)

func _on_ok_pressed() -> void:
	"""Handle Continue button press"""
	# Don't allow interaction during battle
	if battle_in_progress:
		return
	
	# Play click sound for button press
	if sound_manager:
		sound_manager.click_sound()
	
	if showing_battle_report:
		# We're on the battle report screen - close the modal
		hide_modal()
	else:
		# We're on the battle screen - show the battle report
		_show_battle_report()

func _show_battle_report() -> void:
	"""Switch to showing the battle report screen"""
	showing_battle_report = true
	_update_display()

func _apply_header_theme(label: Label, font_size: int = 30) -> void:
	"""Apply header theme to a label (default size increased by 25%)"""
	label.theme = preload("res://themes/header_text_theme.tres")
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", font_size)

func _apply_standard_theme(label: Label, font_size: int = 22) -> void:
	"""Apply standard theme to a label (default size increased by 25%)"""
	label.theme = preload("res://themes/standard_text_theme.tres")
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", font_size)

func _draw():
	# Draw shadow first (behind everything)
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)
	
	# Draw background fill
	var bg_rect = Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, FRAME_COLOR)
	
	# Draw black border on top
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)
