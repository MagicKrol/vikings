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
var _current_player_won: bool = true
var _current_is_dual_human_battle: bool = false
var _defeat_sound_played: bool = false

# UI element references
var battle_status_label: Label
var attacker_name_label: Label
var defender_name_label: Label
var continue_button: Button
var units_section: VBoxContainer
var total_section: VBoxContainer
var tutorial_manager: TutorialManager = null

func _ready():
	# Get UI element references
	battle_status_label = get_node("Panel/Army/Header/HBoxContainer/RecruitmentRegion")
	attacker_name_label = get_node("Panel/Army/HeaderSection/HBoxContainer/AttackerName")
	defender_name_label = get_node("Panel/Army/HeaderSection/HBoxContainer/DefenderName")
	continue_button = get_node("Panel/Army/ButtonSection/HBoxContainer/Button")
	units_section = get_node("Panel/Army/UnitsSection")
	total_section = get_node("Panel/Army/TotalSection")
	
	# Connect button signal
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.name = "continue"
	
	# Get manager references
	var main_node = get_node("/root/Main")
	if main_node:
		sound_manager = main_node.get_node_or_null("SoundManager") as SoundManager
		ui_manager = main_node.get_node_or_null("UI/UIManager") as UIManager
		var gm = main_node.get_node_or_null("GameManager") as GameManager
		if gm:
			tutorial_manager = gm.get_tutorial_manager()
			if tutorial_manager != null:
				continue_button.pressed.connect(func(): tutorial_manager.handle_ui_click("BattleSummaryModal/" + continue_button.name))
	
	# Initially hidden
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _is_continue_hotkey(event):
		_on_continue_pressed()
		get_viewport().set_input_as_handled()

func _is_continue_hotkey(event: InputEvent) -> bool:
	var mapped_continue_close_pressed: bool = GameParameters.is_continue_close_key_pressed(event)
	if mapped_continue_close_pressed and not _is_tutorial_mode_active():
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			return key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER
	return false

func _is_tutorial_mode_active() -> bool:
	var game_manager: GameManager = get_node("../../GameManager") as GameManager
	return game_manager.tutorial_enabled

func show_battle_summary(army: Army, region: Region, report: BattleSimulator.BattleReport, initial_attacker: Dictionary, initial_defender: Dictionary) -> void:
	"""Show the battle summary modal with battle results"""
	if army == null or region == null or report == null:
		return
	var info_modal = get_node("../InfoModal") as InfoModal
	info_modal.hide_modal(false)
	
	attacking_army = army
	defending_region = region
	battle_report = report
	initial_attacker_composition = initial_attacker
	initial_defender_composition = initial_defender
	_defeat_sound_played = false
	
	# Update display
	_update_display()
	
	# Show modal
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)
	_play_defeat_sound_if_needed()

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
	_current_player_won = true
	_current_is_dual_human_battle = false
	_defeat_sound_played = false

func _update_display() -> void:
	"""Update all display elements with battle data"""
	if battle_report == null:
		return

	# Update battle status (won/lost) from the human player's perspective
	var gm = get_node("../../GameManager") as GameManager
	var attacker_pid = attacking_army.get_player_id() if attacking_army else -2
	var defender_owner = -3
	if gm and defending_region:
		defender_owner = gm.get_region_manager().get_region_owner(defending_region.get_region_id())
	# Determine human perspective ID (prefer human among attacker/defender)
	var perspective_id = -1
	if gm:
		if gm.is_player_human(attacker_pid):
			perspective_id = attacker_pid
		elif gm.is_player_human(defender_owner):
			perspective_id = defender_owner
		else:
			perspective_id = gm.get_current_player_id()
	else:
		perspective_id = defender_owner
	var player_is_attacker = perspective_id == attacker_pid
	var player_is_defender = perspective_id == defender_owner
	var attacker_human: bool = false
	var defender_human: bool = false
	if gm:
		attacker_human = gm.is_player_human(attacker_pid)
		defender_human = gm.is_player_human(defender_owner)
	var player_won = false
	match battle_report.winner:
		"Attackers":
			player_won = player_is_attacker
		"Defenders":
			player_won = player_is_defender
		"Withdrawal":
			# Decide winner based on withdrawing side (1=attacker withdrew, 2=defender withdrew)
			if int(battle_report.withdrawing_side) == 1:
				player_won = player_is_defender
			elif int(battle_report.withdrawing_side) == 2:
				player_won = player_is_attacker
			else:
				player_won = false
		_:
			player_won = false
	_current_player_won = player_won
	_current_is_dual_human_battle = attacker_human and defender_human
	# Set label
	battle_status_label.text = tr("Battle Won!") if player_won else tr("Battle Lost!")
	
	# Update army and region names
	if attacking_army:
		attacker_name_label.text = tr("Army %s") % attacking_army.number
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
		_apply_nonremain_color(attacker_dead_label, attacker_dead, attacker_initial)
	
	var attacker_wounded_label = unit_node.get_node_or_null("AttackerWounded")
	if attacker_wounded_label:
		attacker_wounded_label.text = str(attacker_wounded)
		_apply_nonremain_color(attacker_wounded_label, attacker_wounded, attacker_initial)
	
	var attacker_remain_label = unit_node.get_node_or_null("AttackerRemaining")
	if attacker_remain_label:
		attacker_remain_label.text = str(attacker_remain)
		# Apply color coding for attacker remaining units
		var atk_had_losses := (attacker_dead + attacker_wounded) > 0
		_apply_remain_color(attacker_remain_label, attacker_remain, atk_had_losses, attacker_initial)
	
	# Update defender values
	var defender_dead_label = unit_node.get_node_or_null("DefenderDead")
	if defender_dead_label:
		defender_dead_label.text = str(defender_dead)
		_apply_nonremain_color(defender_dead_label, defender_dead, defender_initial)
	
	var defender_wounded_label = unit_node.get_node_or_null("DefenderWounded")
	if defender_wounded_label:
		defender_wounded_label.text = str(defender_wounded)
		_apply_nonremain_color(defender_wounded_label, defender_wounded, defender_initial)
	
	var defender_remain_label = unit_node.get_node_or_null("DefenderRemaining")
	if defender_remain_label:
		defender_remain_label.text = str(defender_remain)
		# Apply color coding for defender remaining units
		var def_had_losses := (defender_dead + defender_wounded) > 0
		_apply_remain_color(defender_remain_label, defender_remain, def_had_losses, defender_initial)

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
		_apply_nonremain_color(attacker_dead_label, total_attacker_dead, total_attacker_initial)
	
	var attacker_wounded_label = total_node.get_node_or_null("AttackerWounded")
	if attacker_wounded_label:
		attacker_wounded_label.text = str(total_attacker_wounded)
		_apply_nonremain_color(attacker_wounded_label, total_attacker_wounded, total_attacker_initial)
	
	var attacker_remain_label = total_node.get_node_or_null("AttackerRemaining")
	if attacker_remain_label:
		attacker_remain_label.text = str(total_attacker_remain)
		# Apply color coding for total attacker remaining
		var atk_losses_total: bool = (total_attacker_dead + total_attacker_wounded) > 0
		_apply_remain_color(attacker_remain_label, total_attacker_remain, atk_losses_total, total_attacker_initial)
	
	var defender_dead_label = total_node.get_node_or_null("DefenderDead")
	if defender_dead_label:
		defender_dead_label.text = str(total_defender_dead)
		_apply_nonremain_color(defender_dead_label, total_defender_dead, total_defender_initial)
	
	var defender_wounded_label = total_node.get_node_or_null("DefenderWounded")
	if defender_wounded_label:
		defender_wounded_label.text = str(total_defender_wounded)
		_apply_nonremain_color(defender_wounded_label, total_defender_wounded, total_defender_initial)
	
	var defender_remain_label = total_node.get_node_or_null("DefenderRemaining")
	if defender_remain_label:
		defender_remain_label.text = str(total_defender_remain)
		# Apply color coding for total defender remaining
		var def_losses_total: bool = (total_defender_dead + total_defender_wounded) > 0
		_apply_remain_color(defender_remain_label, total_defender_remain, def_losses_total, total_defender_initial)

func _apply_remain_color(label: Label, remaining: int, had_losses: bool, initial_count: int) -> void:
	"""Apply color based on remaining count and initial presence."""
	if initial_count <= 0:
		label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
		return
	if remaining == 0:
		label.add_theme_color_override("font_color", GameParameters.UI_COLOR_DEAD)
		return
	if had_losses:
		label.add_theme_color_override("font_color", GameParameters.UI_COLOR_WOUNDED)
		return
	# Default color
	label.add_theme_color_override("font_color", Color.WHITE)

func _apply_nonremain_color(label: Label, value: int, initial_count: int) -> void:
	if initial_count <= 0:
		label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
		return
	label.add_theme_color_override("font_color", Color.WHITE)

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

func _play_defeat_sound_if_needed() -> void:
	if _defeat_sound_played:
		return
	if _current_is_dual_human_battle:
		return
	if _current_player_won:
		return
	sound_manager.play_defeat_sound(3.0)
	_defeat_sound_played = true
