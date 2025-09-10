extends Control
class_name BattleSummaryModal

# Sound manager reference
var sound_manager: SoundManager = null
# UI manager reference for modal mode
var ui_manager: UIManager = null

# Battle data
var attacking_army: Army = null
var defending_region: Region = null
var battle_report: BattleSimulator.BattleReport = null
var initial_attacker_composition: Dictionary = {}
var initial_defender_composition: Dictionary = {}

# UI element references
var battle_status_label: Label
var attacker_name_label: Label
var defender_name_label: Label
var continue_button: Button
var units_section: VBoxContainer
var total_section: VBoxContainer

func _ready():
	# Get UI element references
	battle_status_label = get_node("Panel/Army/Header/RecruitmentRegion")
	attacker_name_label = get_node("Panel/Army/HeaderSection/HBoxContainer/AttackerName")
	defender_name_label = get_node("Panel/Army/HeaderSection/HBoxContainer/DefenderName")
	continue_button = get_node("Panel/Army/ButtonSection/HBoxContainer/Button")
	units_section = get_node("Panel/Army/UnitsSection")
	total_section = get_node("Panel/Army/TotalSection")
	
	# Connect button signal
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Get manager references
	var main_node = get_node("/root/Main")
	if main_node:
		sound_manager = main_node.get_node_or_null("SoundManager") as SoundManager
		ui_manager = main_node.get_node_or_null("UI/UIManager") as UIManager
	
	# Initially hidden
	visible = false

func show_battle_summary(army: Army, region: Region, report: BattleSimulator.BattleReport, initial_attacker: Dictionary, initial_defender: Dictionary) -> void:
	"""Show the battle summary modal with battle results"""
	if army == null or region == null or report == null:
		return
	
	attacking_army = army
	defending_region = region
	battle_report = report
	initial_attacker_composition = initial_attacker
	initial_defender_composition = initial_defender
	
	# Update display
	_update_display()
	
	# Show modal
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)

func hide_modal() -> void:
	"""Hide the battle summary modal"""
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)
	
	# Reset data
	attacking_army = null
	defending_region = null
	battle_report = null
	initial_attacker_composition.clear()
	initial_defender_composition.clear()

func _update_display() -> void:
	"""Update all display elements with battle data"""
	if battle_report == null:
		return
	
	# Update battle status (won/lost)
	if battle_report.winner == "Attackers":
		battle_status_label.text = "Battle Won!"
	else:
		battle_status_label.text = "Battle Lost!"
	
	# Update army and region names
	if attacking_army:
		attacker_name_label.text = "Army " + str(attacking_army.number)
	if defending_region:
		defender_name_label.text = defending_region.get_region_name()
	
	# Update unit sections
	_update_unit_sections()
	
	# Update totals
	_update_totals()

func _update_unit_sections() -> void:
	"""Update all unit type rows with battle data"""
	# Define unit types in order matching the scene structure
	var unit_types = [
		"Peasants",
		"Archers", 
		"Spearmen",
		"Swordmen",
		"Crossbowmen",
		"Horsemen",
		"Knights",
		"Mounted Knights",
		"Royal Gouard"  # Note: Scene has typo "Gouard" instead of "Guard"
	]
	
	# Map display names to SoldierTypeEnum types
	var type_mapping = {
		"Peasants": SoldierTypeEnum.Type.PEASANTS,
		"Archers": SoldierTypeEnum.Type.ARCHERS,
		"Spearmen": SoldierTypeEnum.Type.SPEARMEN,
		"Swordmen": SoldierTypeEnum.Type.SWORDSMEN,
		"Crossbowmen": SoldierTypeEnum.Type.CROSSBOWMEN,
		"Horsemen": SoldierTypeEnum.Type.HORSEMEN,
		"Knights": SoldierTypeEnum.Type.KNIGHTS,
		"Mounted Knights": SoldierTypeEnum.Type.MOUNTED_KNIGHTS,
		"Royal Gouard": SoldierTypeEnum.Type.ROYAL_GUARD
	}
	
	for unit_name in unit_types:
		var unit_node = units_section.get_node_or_null(unit_name)
		if unit_node == null:
			continue
		
		var soldier_type = type_mapping.get(unit_name)
		if soldier_type == null:
			continue
		
		# Get initial counts
		var attacker_initial = initial_attacker_composition.get(soldier_type, 0)
		var defender_initial = initial_defender_composition.get(soldier_type, 0)
		
		# Get final counts from battle report
		var attacker_final = 0
		var defender_final = 0
		if battle_report.final_attacker != null:
			attacker_final = battle_report.final_attacker.get(soldier_type, 0)
		if battle_report.final_defender != null:
			defender_final = battle_report.final_defender.get(soldier_type, 0)
		
		# Calculate wounded from report if available
		var aw := 0
		var dw := 0
		if battle_report.attacker_wounded != null:
			aw = int(battle_report.attacker_wounded.get(type_mapping[unit_name], 0))
		if battle_report.defender_wounded != null:
			dw = int(battle_report.defender_wounded.get(type_mapping[unit_name], 0))
		# Calculate dead excluding wounded
		var attacker_dead = max(0, attacker_initial - attacker_final - aw)
		var defender_dead = max(0, defender_initial - defender_final - dw)
		
		# Update labels with color coding
		_update_unit_row(unit_node, attacker_dead, aw, attacker_final, defender_dead, dw, defender_final, attacker_initial, defender_initial)

func _update_unit_row(unit_node: Node, attacker_dead: int, attacker_wounded: int, attacker_remain: int,
					  defender_dead: int, defender_wounded: int, defender_remain: int,
					  attacker_initial: int = 0, defender_initial: int = 0) -> void:
	"""Update a single unit row with values and color coding"""
	# Update attacker values
	var attacker_dead_label = unit_node.get_node_or_null("AttackerDead")
	if attacker_dead_label:
		attacker_dead_label.text = str(attacker_dead)
	
	var attacker_wounded_label = unit_node.get_node_or_null("AttackerWounded")
	if attacker_wounded_label:
		attacker_wounded_label.text = str(attacker_wounded)
	
	var attacker_remain_label = unit_node.get_node_or_null("AttackerRemaining")
	if attacker_remain_label:
		attacker_remain_label.text = str(attacker_remain)
		# Apply color coding for attacker remaining units
		var atk_had_losses := (attacker_dead + attacker_wounded) > 0
		_apply_remain_color(attacker_remain_label, attacker_remain, atk_had_losses)
	
	# Update defender values
	var defender_dead_label = unit_node.get_node_or_null("DefenderDead")
	if defender_dead_label:
		defender_dead_label.text = str(defender_dead)
	
	var defender_wounded_label = unit_node.get_node_or_null("DefenderWounded")
	if defender_wounded_label:
		defender_wounded_label.text = str(defender_wounded)
	
	var defender_remain_label = unit_node.get_node_or_null("DefenderRemaining")
	if defender_remain_label:
		defender_remain_label.text = str(defender_remain)
		# Apply color coding for defender remaining units
		var def_had_losses := (defender_dead + defender_wounded) > 0
		_apply_remain_color(defender_remain_label, defender_remain, def_had_losses)

func _update_totals() -> void:
	"""Update the total row with aggregated values"""
	var total_node = total_section.get_node_or_null("Total")
	if total_node == null:
		return
	
	# Calculate totals
	var total_attacker_dead = 0
	var total_attacker_wounded = 0
	var total_attacker_remain = 0
	var total_attacker_initial = 0
	var total_defender_dead = 0
	var total_defender_wounded = 0
	var total_defender_remain = 0
	var total_defender_initial = 0
	
	# Sum up all unit types
	for unit_type in SoldierTypeEnum.get_all_types():
		var attacker_initial = initial_attacker_composition.get(unit_type, 0)
		var defender_initial = initial_defender_composition.get(unit_type, 0)
		
		var attacker_final = 0
		var defender_final = 0
		if battle_report.final_attacker != null:
			attacker_final = battle_report.final_attacker.get(unit_type, 0)
		if battle_report.final_defender != null:
			defender_final = battle_report.final_defender.get(unit_type, 0)
		var aw := 0
		var dw := 0
		if battle_report.attacker_wounded != null:
			aw = int(battle_report.attacker_wounded.get(unit_type, 0))
		if battle_report.defender_wounded != null:
			dw = int(battle_report.defender_wounded.get(unit_type, 0))
		
		total_attacker_initial += attacker_initial
		total_attacker_dead += max(0, attacker_initial - attacker_final - aw)
		total_attacker_remain += attacker_final
		total_attacker_wounded += aw
		total_defender_initial += defender_initial
		total_defender_dead += max(0, defender_initial - defender_final - dw)
		total_defender_remain += defender_final
		total_defender_wounded += dw
	
	# Update total labels
	var attacker_dead_label = total_node.get_node_or_null("AttackerDead")
	if attacker_dead_label:
		attacker_dead_label.text = str(total_attacker_dead)
	
	var attacker_wounded_label = total_node.get_node_or_null("AttackerWounded")
	if attacker_wounded_label:
		attacker_wounded_label.text = str(total_attacker_wounded)
	
	var attacker_remain_label = total_node.get_node_or_null("AttackerRemaining")
	if attacker_remain_label:
		attacker_remain_label.text = str(total_attacker_remain)
		# Apply color coding for total attacker remaining
		var atk_losses_total: bool = (total_attacker_dead + total_attacker_wounded) > 0
		_apply_remain_color(attacker_remain_label, total_attacker_remain, atk_losses_total)
	
	var defender_dead_label = total_node.get_node_or_null("DefenderDead")
	if defender_dead_label:
		defender_dead_label.text = str(total_defender_dead)
	
	var defender_wounded_label = total_node.get_node_or_null("DefenderWounded")
	if defender_wounded_label:
		defender_wounded_label.text = str(total_defender_wounded)
	
	var defender_remain_label = total_node.get_node_or_null("DefenderRemaining")
	if defender_remain_label:
		defender_remain_label.text = str(total_defender_remain)
		# Apply color coding for total defender remaining
		var def_losses_total: bool = (total_defender_dead + total_defender_wounded) > 0
		_apply_remain_color(defender_remain_label, total_defender_remain, def_losses_total)

func _apply_remain_color(label: Label, remaining: int, had_losses: bool) -> void:
	"""Apply color: red if remaining==0; yellow if any losses; else default."""
	if remaining == 0:
		label.add_theme_color_override("font_color", GameParameters.UI_COLOR_DEAD)
		return
	if had_losses:
		label.add_theme_color_override("font_color", GameParameters.UI_COLOR_WOUNDED)
		return
	# Reset to default when no losses
	if label.has_theme_color_override("font_color"):
		label.remove_theme_color_override("font_color")

func _on_continue_pressed() -> void:
	"""Handle continue button press"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Hide modal
	hide_modal()
	
	# Notify the battle modal that summary is closed
	var battle_modal = get_node_or_null("/root/Main/UI/BattleModal")
	if battle_modal and battle_modal.has_method("_on_summary_closed"):
		battle_modal._on_summary_closed()
