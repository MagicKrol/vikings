extends Control
class_name BattleModal

# Styling constants (same as other modals)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# UI elements - references to static nodes from main.tscn
var battle_title_label: Label
var attacker_header: Label
var defender_header: Label
var attacker_effectiveness: Label
var defender_effectiveness: Label
var attacker_units_container: VBoxContainer
var defender_units_container: VBoxContainer
var continue_button: Button

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
	# Get references to static UI elements from main.tscn
	battle_title_label = get_node("BorderMargin/MainContainer/TitleContainer/BattleTitleLabel")
	attacker_header = get_node("BorderMargin/MainContainer/MainContent/AttackerColumnMargin/AttackerColumn/AttackerHeader")
	defender_header = get_node("BorderMargin/MainContainer/MainContent/DefenderColumnMargin/DefenderColumn/DefenderHeader")
	attacker_effectiveness = get_node("BorderMargin/MainContainer/MainContent/AttackerColumnMargin/AttackerColumn/AttackerEffectiveness")
	defender_effectiveness = get_node("BorderMargin/MainContainer/MainContent/DefenderColumnMargin/DefenderColumn/DefenderEffectiveness")
	attacker_units_container = get_node("BorderMargin/MainContainer/MainContent/AttackerColumnMargin/AttackerColumn/AttackerUnitsContainer")
	defender_units_container = get_node("BorderMargin/MainContainer/MainContent/DefenderColumnMargin/DefenderColumn/DefenderUnitsContainer")
	continue_button = get_node("BorderMargin/MainContainer/ButtonContainer/ContinueButton")
	
	# Connect button signal
	continue_button.pressed.connect(_on_ok_pressed)
	
	# Get manager references
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	click_manager = get_node("../../ClickManager")
	
	# Create animated battle simulator
	animated_simulator = AnimatedBattleSimulator.new()
	animated_simulator.round_completed.connect(_on_battle_round_completed)
	animated_simulator.battle_finished.connect(_on_battle_finished)
	add_child(animated_simulator)
	
	# Initially hidden
	visible = false

func show_battle(army: Army, region: Region) -> void:
	"""Show the battle modal with army vs region information"""
	if army == null or region == null:
		hide_modal()
		return
	
	attacking_army = army
	defending_region = region
	
	# Show initial display BEFORE starting battle
	_update_display()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)
	
	# Run battle simulation AFTER showing initial state
	_run_battle_simulation()

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
	if continue_button:
		continue_button.disabled = false
		continue_button.text = "Continue"
	
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
	if continue_button:
		continue_button.text = "Continue"

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
	# Add margin before this row (except for the first row)
	if attacker_units_container.get_child_count() > 0:
		var margin = MarginContainer.new()
		margin.custom_minimum_size = Vector2(0, 5)
		attacker_units_container.add_child(margin)
	
	var row_container = HBoxContainer.new()
	row_container.add_theme_constant_override("separation", 0)
	attacker_units_container.add_child(row_container)
	
	# Unit name (left-aligned)
	var unit_label = Label.new()
	unit_label.text = SoldierTypeEnum.type_to_string(unit_type) + ":"
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	unit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_standard_theme(unit_label)
	row_container.add_child(unit_label)
	
	# Count (right-aligned, fixed width)
	var count_label = Label.new()
	count_label.text = str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.custom_minimum_size = Vector2(60, 0)
	_apply_standard_theme(count_label)
	row_container.add_child(count_label)

func _create_defender_loss_row(unit_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Create a loss row for defender: '<count> :Unit' with left-aligned count"""
	# Add margin before this row (except for the first row)
	if defender_units_container.get_child_count() > 0:
		var margin = MarginContainer.new()
		margin.custom_minimum_size = Vector2(0, 5)
		defender_units_container.add_child(margin)
	
	var row_container = HBoxContainer.new()
	row_container.add_theme_constant_override("separation", 0)
	defender_units_container.add_child(row_container)
	
	# Count (left-aligned, fixed width)
	var count_label = Label.new()
	count_label.text = str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	count_label.custom_minimum_size = Vector2(60, 0)
	_apply_standard_theme(count_label)
	row_container.add_child(count_label)
	
	# Unit name (right-aligned)
	var unit_label = Label.new()
	unit_label.text = " :" + SoldierTypeEnum.type_to_string(unit_type)
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	unit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_standard_theme(unit_label)
	row_container.add_child(unit_label)

func _create_no_losses_label(container: VBoxContainer, text: String) -> void:
	"""Create a 'no losses' label for cases where there were no casualties"""
	var no_loss_label = Label.new()
	no_loss_label.text = text
	no_loss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_standard_theme(no_loss_label)
	container.add_child(no_loss_label)

func _update_attacker_units() -> void:
	"""Update attacker unit display"""
	# Clear existing unit displays
	for child in attacker_units_container.get_children():
		child.queue_free()
	
	# Get current composition to display
	var composition_to_show: Dictionary
	var initial_composition: Dictionary = {}
	
	# Always get initial composition for color comparison
	var army_comp = attacking_army.get_composition()
	for unit_type in SoldierTypeEnum.get_all_types():
		var count = army_comp.get_soldier_count(unit_type)
		initial_composition[unit_type] = count
	
	if battle_in_progress:
		composition_to_show = current_attacker_composition
	elif battle_report != null:
		composition_to_show = battle_report.final_attacker
	else:
		composition_to_show = initial_composition
	
	# Create unit display rows for all unit types that were initially present
	for unit_type in SoldierTypeEnum.get_all_types():
		if initial_composition.get(unit_type, 0) > 0:
			var current_count = composition_to_show.get(unit_type, 0)
			_create_attacker_unit_row(unit_type, current_count, initial_composition[unit_type])

func _update_defender_units() -> void:
	"""Update defender unit display"""
	# Clear existing unit displays
	for child in defender_units_container.get_children():
		child.queue_free()
	
	# Get current composition to display
	var composition_to_show: Dictionary
	var initial_composition: Dictionary = {}
	
	# Always get initial composition for color comparison
	var garrison_comp = defending_region.get_garrison()
	for unit_type in SoldierTypeEnum.get_all_types():
		var count = garrison_comp.get_soldier_count(unit_type)
		initial_composition[unit_type] = count
	
	if battle_in_progress:
		composition_to_show = current_defender_composition
	elif battle_report != null:
		composition_to_show = battle_report.final_defender
	else:
		composition_to_show = initial_composition
	
	# Create unit display rows for all unit types that were initially present
	for unit_type in SoldierTypeEnum.get_all_types():
		if initial_composition.get(unit_type, 0) > 0:
			var current_count = composition_to_show.get(unit_type, 0)
			_create_defender_unit_row(unit_type, current_count, initial_composition[unit_type])

func _create_attacker_unit_row(unit_type: SoldierTypeEnum.Type, count: int, initial_count: int = 0) -> void:
	"""Create a unit row for attacker: 'Unit: <count>' with right-aligned count"""
	# Add margin before this row (except for the first row)
	if attacker_units_container.get_child_count() > 0:
		var margin = MarginContainer.new()
		margin.custom_minimum_size = Vector2(0, 5)
		attacker_units_container.add_child(margin)
	
	var row_container = HBoxContainer.new()
	row_container.add_theme_constant_override("separation", 0)
	attacker_units_container.add_child(row_container)
	
	# Unit name (left-aligned)
	var unit_label = Label.new()
	unit_label.text = SoldierTypeEnum.type_to_string(unit_type) + ":"
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	unit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_standard_theme(unit_label)
	row_container.add_child(unit_label)
	
	# Count (right-aligned, fixed width)
	var count_label = Label.new()
	count_label.text = str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.custom_minimum_size = Vector2(60, 0)
	_apply_standard_theme(count_label)
	
	# Apply color coding based on remaining units
	if count == 0:
		count_label.add_theme_color_override("font_color", Color.RED)
	elif count < initial_count:
		count_label.add_theme_color_override("font_color", Color.YELLOW)
	
	row_container.add_child(count_label)

func _create_defender_unit_row(unit_type: SoldierTypeEnum.Type, count: int, initial_count: int = 0) -> void:
	"""Create a unit row for defender: '<count> :Unit' with left-aligned count"""
	# Add margin before this row (except for the first row)
	if defender_units_container.get_child_count() > 0:
		var margin = MarginContainer.new()
		margin.custom_minimum_size = Vector2(0, 5)
		defender_units_container.add_child(margin)
	
	var row_container = HBoxContainer.new()
	row_container.add_theme_constant_override("separation", 0)
	defender_units_container.add_child(row_container)
	
	# Count (left-aligned, fixed width)
	var count_label = Label.new()
	count_label.text = str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	count_label.custom_minimum_size = Vector2(100, 0)
	_apply_standard_theme(count_label)
	
	# Apply color coding based on remaining units
	if count == 0:
		count_label.add_theme_color_override("font_color", Color.RED)
	elif count < initial_count:
		count_label.add_theme_color_override("font_color", Color.YELLOW)
	
	row_container.add_child(count_label)
	
	# Unit name (right-aligned)
	var unit_label = Label.new()
	unit_label.text = " :" + SoldierTypeEnum.type_to_string(unit_type)
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	unit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_standard_theme(unit_label)
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
	if continue_button:
		continue_button.disabled = true
		continue_button.text = "Battle in Progress..."
	
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
	if continue_button:
		continue_button.disabled = false
		continue_button.text = "Continue"
	
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
