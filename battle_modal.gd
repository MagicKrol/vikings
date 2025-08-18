extends Control
class_name BattleModal

# Styling constants (same as other modals)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# UI elements
var army_label: Label
var army_composition_label: Label
var region_label: Label
var region_composition_label: Label
var ok_button: Button

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

# Sound manager reference
var sound_manager: SoundManager = null
# UI manager reference for modal mode
var ui_manager: UIManager = null
# Click manager reference for conquest completion
var click_manager: Node = null

func _ready():
	# Get references to UI elements from the scene tree
	army_label = get_node_or_null("LeftSide/ArmyLabel") as Label
	army_composition_label = get_node_or_null("LeftSide/ArmyCompositionLabel") as Label
	region_label = get_node_or_null("RightSide/RegionLabel") as Label
	region_composition_label = get_node_or_null("RightSide/RegionCompositionLabel") as Label
	ok_button = get_node_or_null("OkButton") as Button
	
	# Get sound manager reference
	sound_manager = get_node_or_null("../../SoundManager") as SoundManager
	
	# Get UI manager reference
	ui_manager = get_node_or_null("../UIManager") as UIManager
	
	# Get click manager reference
	click_manager = get_node_or_null("../../ClickManager")
	
	# Create animated battle simulator
	animated_simulator = AnimatedBattleSimulator.new()
	animated_simulator.round_completed.connect(_on_battle_round_completed)
	animated_simulator.battle_finished.connect(_on_battle_finished)
	add_child(animated_simulator)
	
	# Connect OK button
	if ok_button:
		ok_button.pressed.connect(_on_ok_pressed)
	
	# Apply text themes to match other modals
	_apply_text_themes()
	
	# Initially hidden
	visible = false

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
	current_round = 0
	current_attacker_composition.clear()
	current_defender_composition.clear()
	
	# Reset button
	if ok_button:
		ok_button.disabled = false
		ok_button.text = "Close"
	
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _update_display() -> void:
	"""Update the display with current battle information"""
	if attacking_army == null or defending_region == null:
		hide_modal()
		return
	
	# Update army information (left side)
	army_label.text = attacking_army.name
	
	var army_composition_text = ""
	
	if battle_in_progress:
		# Show current battle progress
		army_composition_text = "BATTLE ROUND " + str(current_round) + "\n\nCurrent Forces:"
		for unit_type in current_attacker_composition:
			var unit_name = SoldierTypeEnum.type_to_string(unit_type)
			army_composition_text += "\n" + unit_name + ": " + str(current_attacker_composition[unit_type])
	elif battle_report != null:
		# Show battle results
		army_composition_text = "BATTLE COMPLETE\n\nResult: " + battle_report.winner
		army_composition_text += "\nRounds: " + str(battle_report.rounds)
		army_composition_text += "\n\nFinal Forces:"
		for unit_type in battle_report.final_attacker:
			var unit_name = SoldierTypeEnum.type_to_string(unit_type)
			army_composition_text += "\n" + unit_name + ": " + str(battle_report.final_attacker[unit_type])
		if not battle_report.attacker_losses.is_empty():
			army_composition_text += "\n\nLosses:"
			for unit_type in battle_report.attacker_losses:
				var unit_name = SoldierTypeEnum.type_to_string(unit_type)
				army_composition_text += "\n- " + unit_name + ": " + str(battle_report.attacker_losses[unit_type])
	else:
		# Show initial composition
		army_composition_text = attacking_army.get_army_composition_string()
	
	army_composition_label.text = army_composition_text
	
	# Update region information (right side)
	var region_id = defending_region.get_region_id()
	var region_name = defending_region.get_region_name()
	region_label.text = "Region " + str(region_id) + "\n(" + region_name + ")"
	
	var region_composition_text = ""
	
	if battle_in_progress:
		# Show current defender forces
		region_composition_text = "Defending Forces:"
		for unit_type in current_defender_composition:
			var unit_name = SoldierTypeEnum.type_to_string(unit_type)
			region_composition_text += "\n" + unit_name + ": " + str(current_defender_composition[unit_type])
	elif battle_report != null:
		# Show final defender results
		region_composition_text = "Final Forces:"
		for unit_type in battle_report.final_defender:
			var unit_name = SoldierTypeEnum.type_to_string(unit_type)
			region_composition_text += "\n" + unit_name + ": " + str(battle_report.final_defender[unit_type])
		if not battle_report.defender_losses.is_empty():
			region_composition_text += "\n\nLosses:"
			for unit_type in battle_report.defender_losses:
				var unit_name = SoldierTypeEnum.type_to_string(unit_type)
				region_composition_text += "\n- " + unit_name + ": " + str(battle_report.defender_losses[unit_type])
	else:
		# Show initial garrison
		region_composition_text = defending_region.get_garrison_composition_string()
	
	region_composition_label.text = region_composition_text

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
	
	# Disable OK button during battle
	if ok_button:
		ok_button.disabled = true
		ok_button.text = "Battle in Progress..."
	
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
	
	# Re-enable OK button
	if ok_button:
		ok_button.disabled = false
		ok_button.text = "Close"
	
	# Final display update
	_update_display()
	
	print("[BattleModal] Battle finished! Winner: ", report.winner)

func _on_ok_pressed() -> void:
	"""Handle OK button press"""
	# Don't allow closing during battle
	if battle_in_progress:
		return
	
	# Play click sound for button press
	if sound_manager:
		sound_manager.click_sound()
	hide_modal()

func _apply_text_themes() -> void:
	"""Apply text themes to match other modals"""
	# Apply header theme to main labels (30px font size)
	if army_label:
		army_label.theme = preload("res://themes/header_text_theme.tres")
		army_label.add_theme_color_override("font_color", Color.WHITE)
		army_label.add_theme_font_size_override("font_size", 30)
		army_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if region_label:
		region_label.theme = preload("res://themes/header_text_theme.tres")
		region_label.add_theme_color_override("font_color", Color.WHITE)
		region_label.add_theme_font_size_override("font_size", 30)
		region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Apply standard theme to composition labels (20px font size)
	if army_composition_label:
		army_composition_label.theme = preload("res://themes/standard_text_theme.tres")
		army_composition_label.add_theme_color_override("font_color", Color.WHITE)
		army_composition_label.add_theme_font_size_override("font_size", 20)
		army_composition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	if region_composition_label:
		region_composition_label.theme = preload("res://themes/standard_text_theme.tres")
		region_composition_label.add_theme_color_override("font_color", Color.WHITE)
		region_composition_label.add_theme_font_size_override("font_size", 20)
		region_composition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _draw():
	# Draw black border
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)
	
	# Draw shadow
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)
