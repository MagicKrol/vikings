extends Control
class_name BattleModal

# Styling constants (same as other modals)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# UI elements - references to static nodes from updated scene
var battle_title_label: Label
var attacker_header: Label
var defender_header: Label
var attacker_effectiveness: Label
var defender_effectiveness: Label
var attacker_units_container: VBoxContainer
var defender_units_container: VBoxContainer
var continue_button: Button
var withdraw_button: Button

# Battle data
var attacking_army: Army = null
var defending_region: Region = null
var battle_report: BattleSimulator.BattleReport = null
var animated_simulator: AnimatedBattleSimulator = null
var battle_in_progress: bool = false
var _def_ai_withdraw_notice_logged: bool = false

# Real-time battle display data
var current_round: int = 0
var current_attacker_composition: Dictionary = {}
var current_defender_composition: Dictionary = {}

# Battle report state
var showing_battle_report: bool = false
# Battle summary modal reference
var battle_summary_modal: BattleSummaryModal = null
# Store initial compositions for summary
var initial_attacker_comp: Dictionary = {}
var initial_defender_comp: Dictionary = {}

# Withdrawal state
var withdrawal_in_progress: bool = false
var _defender_start_recruits: int = 0

# Sound manager reference
var sound_manager: SoundManager = null
# UI manager reference for modal mode
var ui_manager: UIManager = null
# Click manager reference for conquest completion
var click_manager: Node = null

func _ready():
	# Get references to static UI elements from updated scene structure
	battle_title_label = get_node("Panel/Army/Header/Region")
	attacker_header = get_node("Panel/Army/HeaderSection/HBoxContainer/AttackerName")
	defender_header = get_node("Panel/Army/HeaderSection/HBoxContainer/DefenderName")
	attacker_effectiveness = get_node("Panel/Army/HeaderSection/Status/AttackerVigor")
	defender_effectiveness = get_node("Panel/Army/HeaderSection/Status/DefenderVigor")
	attacker_units_container = get_node("Panel/Army/UnitsSection")
	defender_units_container = get_node("Panel/Army/UnitsSection")
	continue_button = get_node("Panel/Army/ButtonSection/HBoxContainer/Button")
	withdraw_button = get_node("Panel/Army/ButtonSection/HBoxContainer/Button")
	
	# Connect button signals - single button handles both continue and withdraw
	continue_button.pressed.connect(_on_button_pressed)
	withdraw_button = continue_button  # Both reference the same button
	
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
	
	# Try to find or create battle summary modal
	_setup_battle_summary_modal()

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
	DebugLogger.log("UISystem", "Hiding modal and notifying click manager...")
	
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
	
	# Reset withdrawal state
	withdrawal_in_progress = false
	
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
		
		# Set appropriate headers for normal battle
		if attacking_army != null:
			attacker_header.text = "Army " + str(attacking_army.number)
		else:
			attacker_header.text = "Attacker"
		defender_header.text = defending_region.get_region_name()
		attacker_effectiveness.visible = true
		defender_effectiveness.visible = true
		
		# Update vigor displays
		_update_effectiveness_displays()
		
		# Update attacker units
		_update_attacker_units()
		
		# Update defender units  
		_update_defender_units()


func _update_effectiveness_displays() -> void:
	"""Update the vigor labels with current values"""
	if attacking_army == null or defending_region == null:
		return
	
	# Get attacking army vigor
	var attacker_vigor = attacking_army.get_efficiency()
	attacker_effectiveness.text = "Vigor: " + str(attacker_vigor) + "%"
	
	# Defender vigor: garrison always 100%, armies use their efficiency
	# For now, we're always fighting against garrison, so it's 100%
	defender_effectiveness.text = "Vigor: 100%"


func _display_battle_report() -> void:
	"""Display the battle report screen"""
	# Update title
	battle_title_label.text = "Battle Report"
	
	# Hide vigor labels (not needed for report)
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
	# Update unit labels to show losses instead of remaining counts
	for unit_type in SoldierTypeEnum.get_all_types():
		var unit_name = SoldierTypeEnum.type_to_string(unit_type).to_lower().capitalize() + "s"
		
		# Update attacker losses
		var attacker_losses = battle_report.attacker_losses.get(unit_type, 0)
		if attacker_losses > 0:
			_update_loss_label(unit_name, attacker_losses, true)
		
		# Update defender losses
		var defender_losses = battle_report.defender_losses.get(unit_type, 0)
		if defender_losses > 0:
			_update_loss_label(unit_name, defender_losses, false)
	
	# Update totals
	var total_attacker_losses = 0
	var total_defender_losses = 0
	for unit_type in battle_report.attacker_losses:
		total_attacker_losses += battle_report.attacker_losses[unit_type]
	for unit_type in battle_report.defender_losses:
		total_defender_losses += battle_report.defender_losses[unit_type]
	
	if total_attacker_losses > 0:
		_update_loss_label("Total", total_attacker_losses, true)
	if total_defender_losses > 0:
		_update_loss_label("Total", total_defender_losses, false)

func _update_loss_label(unit_section_name: String, loss_count: int, is_attacker: bool) -> void:
	"""Update loss labels in the static scene structure"""
	var section_path = "Panel/Army/UnitsSection/" + unit_section_name
	if unit_section_name == "Total":
		section_path = "Panel/Army/TotalSection/Total"
	
	var section_node = get_node_or_null(section_path)
	if not section_node:
		return
	
	var attacker_label = section_node.get_node_or_null("AttackerRemaining")
	var defender_label = section_node.get_node_or_null("DefenderRemaining")
	
	if is_attacker and attacker_label:
		attacker_label.text = str(loss_count)
		attacker_label.add_theme_color_override("font_color", Color.RED)
	
	if not is_attacker and defender_label:
		defender_label.text = str(loss_count)
		defender_label.add_theme_color_override("font_color", Color.RED)



func _update_attacker_units() -> void:
	"""Update attacker unit display using the new scene structure"""
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
	
	# Update each unit type in the static scene structure
	_update_unit_count_label("Peasants", SoldierTypeEnum.Type.PEASANTS, composition_to_show, initial_composition, true)
	_update_unit_count_label("Archers", SoldierTypeEnum.Type.ARCHERS, composition_to_show, initial_composition, true)
	_update_unit_count_label("Spearmen", SoldierTypeEnum.Type.SPEARMEN, composition_to_show, initial_composition, true)
	_update_unit_count_label("Swordsmen", SoldierTypeEnum.Type.SWORDSMEN, composition_to_show, initial_composition, true)
	_update_unit_count_label("Crossbowmen", SoldierTypeEnum.Type.CROSSBOWMEN, composition_to_show, initial_composition, true)
	_update_unit_count_label("Horsemen", SoldierTypeEnum.Type.HORSEMEN, composition_to_show, initial_composition, true)
	_update_unit_count_label("Knights", SoldierTypeEnum.Type.KNIGHTS, composition_to_show, initial_composition, true)
	_update_unit_count_label("Mounted Knights", SoldierTypeEnum.Type.MOUNTED_KNIGHTS, composition_to_show, initial_composition, true)
	_update_unit_count_label("Royal Guard", SoldierTypeEnum.Type.ROYAL_GUARD, composition_to_show, initial_composition, true)
	
	# Update total
	var total_current = 0
	var total_initial = 0
	for unit_type in composition_to_show:
		total_current += composition_to_show[unit_type]
	for unit_type in initial_composition:
		total_initial += initial_composition[unit_type]
	_update_unit_count_label("Total", null, {"total": total_current}, {"total": total_initial}, true)

func _update_defender_units() -> void:
	"""Update defender unit display using the new scene structure"""
	# Aggregate initial composition via BattleManager
	var initial_composition: Dictionary = {}
	var gm = get_node("../../GameManager") as GameManager
	var bm = gm.get_battle_manager()
	# Defending armies
	var def_comps: Array = bm.get_pending_defending_compositions()
	for comp in def_comps:
		for unit_type in SoldierTypeEnum.get_all_types():
			var c = comp.get_soldier_count(unit_type)
			if c > 0:
				initial_composition[unit_type] = initial_composition.get(unit_type, 0) + c
	# Garrison
	var garrison_comp = defending_region.get_garrison()
	for unit_type in SoldierTypeEnum.get_all_types():
		var gc = garrison_comp.get_soldier_count(unit_type)
		if gc > 0:
			initial_composition[unit_type] = initial_composition.get(unit_type, 0) + gc
	# Recruits (peasant-only)
	var base_recruits = defending_region.get_base_available_recruits()
	if base_recruits > 0:
		initial_composition[SoldierTypeEnum.Type.PEASANTS] = initial_composition.get(SoldierTypeEnum.Type.PEASANTS, 0) + base_recruits

	# Composition to show
	var composition_to_show: Dictionary
	if battle_in_progress:
		composition_to_show = current_defender_composition
	elif battle_report != null:
		composition_to_show = battle_report.final_defender
	else:
		composition_to_show = initial_composition

	# Update each unit type in the static scene structure
	_update_unit_count_label("Peasants", SoldierTypeEnum.Type.PEASANTS, composition_to_show, initial_composition, false)
	_update_unit_count_label("Archers", SoldierTypeEnum.Type.ARCHERS, composition_to_show, initial_composition, false)
	_update_unit_count_label("Spearmen", SoldierTypeEnum.Type.SPEARMEN, composition_to_show, initial_composition, false)
	_update_unit_count_label("Swordsmen", SoldierTypeEnum.Type.SWORDSMEN, composition_to_show, initial_composition, false)
	_update_unit_count_label("Crossbowmen", SoldierTypeEnum.Type.CROSSBOWMEN, composition_to_show, initial_composition, false)
	_update_unit_count_label("Horsemen", SoldierTypeEnum.Type.HORSEMEN, composition_to_show, initial_composition, false)
	_update_unit_count_label("Knights", SoldierTypeEnum.Type.KNIGHTS, composition_to_show, initial_composition, false)
	_update_unit_count_label("Mounted Knights", SoldierTypeEnum.Type.MOUNTED_KNIGHTS, composition_to_show, initial_composition, false)
	_update_unit_count_label("Royal Guard", SoldierTypeEnum.Type.ROYAL_GUARD, composition_to_show, initial_composition, false)
	
	# Update total
	var total_current = 0
	var total_initial = 0
	for unit_type in composition_to_show:
		total_current += composition_to_show[unit_type]
	for unit_type in initial_composition:
		total_initial += initial_composition[unit_type]
	_update_unit_count_label("Total", null, {"total": total_current}, {"total": total_initial}, false)

func _update_unit_count_label(unit_section_name: String, unit_type, current_composition: Dictionary, initial_composition: Dictionary, is_attacker: bool) -> void:
	"""Update unit count labels in the static scene structure"""
	var section_path = "Panel/Army/UnitsSection/" + unit_section_name
	if unit_section_name == "Total":
		section_path = "Panel/Army/TotalSection/Total"
	
	var section_node = get_node_or_null(section_path)
	if not section_node:
		return
	
	var attacker_label = section_node.get_node_or_null("AttackerRemaining")
	var defender_label = section_node.get_node_or_null("DefenderRemaining")
	
	if is_attacker and attacker_label:
		var current_count = 0
		var initial_count = 0
		
		if unit_type == null:
			current_count = current_composition.get("total", 0)
			initial_count = initial_composition.get("total", 0)
		else:
			current_count = current_composition.get(unit_type, 0)
			initial_count = initial_composition.get(unit_type, 0)
		
		attacker_label.text = str(current_count)
		
		# Apply color coding
		if current_count == 0 and initial_count > 0:
			attacker_label.add_theme_color_override("font_color", Color.RED)
		elif current_count < initial_count:
			attacker_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			attacker_label.remove_theme_color_override("font_color")
	
	if not is_attacker and defender_label:
		var current_count = 0
		var initial_count = 0
		
		if unit_type == null:
			current_count = current_composition.get("total", 0)
			initial_count = initial_composition.get("total", 0)
		else:
			current_count = current_composition.get(unit_type, 0)
			initial_count = initial_composition.get(unit_type, 0)
		
		defender_label.text = str(current_count)
		
		# Apply color coding
		if current_count == 0 and initial_count > 0:
			defender_label.add_theme_color_override("font_color", Color.RED)
		elif current_count < initial_count:
			defender_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			defender_label.remove_theme_color_override("font_color")


func _run_battle_simulation() -> void:
	"""Run the animated battle simulation between attacking army and region garrison"""
	if attacking_army == null or defending_region == null:
		return
	
	battle_in_progress = true
	current_round = 0
	
	# Reset display data
	current_attacker_composition = {}
	current_defender_composition = {}
	
	# Store initial compositions for display (aggregate attackers/defenders via BattleManager)
	var gm = get_node("../../GameManager") as GameManager
	var bm = gm.get_battle_manager()
	# Prepare defender participants now for human path
	bm.prepare_human_battle(attacking_army, defending_region)
	# Aggregate attackers for display
	var atk_comps: Array = bm.get_pending_attacking_compositions()
	for comp in atk_comps:
		for unit_type in SoldierTypeEnum.get_all_types():
			var c = comp.get_soldier_count(unit_type)
			if c > 0:
				current_attacker_composition[unit_type] = current_attacker_composition.get(unit_type, 0) + c
	# Aggregate defenders: armies + garrison + recruits
	var def_comps: Array = bm.get_pending_defending_compositions()
	for comp in def_comps:
		for unit_type in SoldierTypeEnum.get_all_types():
			var c = comp.get_soldier_count(unit_type)
			if c > 0:
				current_defender_composition[unit_type] = current_defender_composition.get(unit_type, 0) + c
	# Add garrison to display
	var garrison_comp = defending_region.get_garrison()
	for unit_type in SoldierTypeEnum.get_all_types():
		var gc = garrison_comp.get_soldier_count(unit_type)
		if gc > 0:
			current_defender_composition[unit_type] = current_defender_composition.get(unit_type, 0) + gc
	
	# Store initial compositions for battle summary
	initial_attacker_comp = current_attacker_composition.duplicate()
	initial_defender_comp = current_defender_composition.duplicate()
	# Add recruits to initial defender composition
	var summary_recruits = defending_region.get_base_available_recruits()
	_defender_start_recruits = summary_recruits
	if summary_recruits > 0:
		initial_defender_comp[SoldierTypeEnum.Type.PEASANTS] = initial_defender_comp.get(SoldierTypeEnum.Type.PEASANTS, 0) + summary_recruits
	
	# During battle, show withdraw functionality
	if continue_button:
		continue_button.disabled = false
		continue_button.text = "Withdraw"
	
	# Get attacking compositions (all pending attackers)
	var attacking_compositions = bm.get_pending_attacking_compositions()
	
	# Get defending forces (armies + recruits as defending_compositions, garrison separate)
	var defending_compositions = bm.get_pending_defending_compositions()
	var region_garrison = defending_region.get_garrison()
	# Append recruits composition if available
	var available_recruits = defending_region.get_base_available_recruits()
	if available_recruits > 0:
		var recruits_comp := ArmyComposition.new()
		recruits_comp.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, available_recruits)
		defending_compositions.append(recruits_comp)
	
	# Start the animated battle with attacker efficiency
	var attacker_efficiency = attacking_army.get_efficiency()
	var terrain_type = defending_region.get_region_type()
	var castle_type = defending_region.get_castle_type()
	animated_simulator.start_animated_battle(attacking_compositions, defending_compositions, region_garrison, attacker_efficiency, 100, terrain_type, castle_type)
	
	DebugLogger.log("UISystem", "Starting animated battle simulation...")

func _on_battle_round_completed(round_data: Dictionary) -> void:
	"""Handle completion of a battle round"""
	current_round = round_data["round"]
	current_attacker_composition = round_data["current_attackers"]
	current_defender_composition = round_data["current_defenders"]
	
	# Update display with current round data
	_update_display()
	
	# AI withdraw check (attacker-side only)
	var gm = get_node("../../GameManager") as GameManager
	var bm = gm.get_battle_manager()
	if bm and animated_simulator and not animated_simulator.is_withdrawing:
		if bm.evaluate_ai_attacker_withdrawal(current_attacker_composition, current_defender_composition, defending_region.get_garrison(), _defender_start_recruits):
			animated_simulator.start_withdrawal_round()
		else:
			# Optional notice for defender AI (not yet supported)
			if not _def_ai_withdraw_notice_logged:
				var any_def_ai := false
				for d in bm._pending_defenders:
					if gm.is_player_computer(d.get_player_id()):
						any_def_ai = true
						break
				if any_def_ai:
					DebugLogger.log("BattleAI", "Defender AI withdrawal is not implemented in the current simulator (attacker-only).")
					_def_ai_withdraw_notice_logged = true
	
	DebugLogger.log("UISystem", "Round " + str(current_round) + " completed - Attackers: " + str(round_data["attacker_size"]) + ", Defenders: " + str(round_data["defender_size"]))

func _on_battle_finished(report: BattleSimulator.BattleReport) -> void:
	"""Handle battle completion"""
	battle_in_progress = false
	# Compute wounded before showing summary
	report.attacker_wounded = Utils.compute_wounded(report.attacker_losses)
	report.defender_wounded = Utils.compute_wounded(report.defender_losses)
	battle_report = report

	# If AI modal is disabled for debugging, finalize immediately only when defender is not human
	var gm = get_node("../../GameManager") as GameManager
	var owner_id := gm.get_region_manager().get_region_owner(defending_region.get_region_id())
	var defender_is_human := (owner_id != -1 and gm.is_player_human(owner_id))
	if gm.debug_disable_battle_modal and gm.is_player_computer(attacking_army.get_player_id()) and not defender_is_human:
		gm.get_battle_manager().handle_battle_modal_closed()
		# Hide modal and stop here to avoid waiting for UI interaction
		hide_modal()
		return
	
	# Re-enable continue button
	if continue_button:
		continue_button.disabled = false
		continue_button.text = "Continue"
	
	# Reset withdrawal state
	withdrawal_in_progress = false
	
	# Final display update
	_update_display()
	
	DebugLogger.log("UISystem", "Battle finished! Winner: " + str(report.winner))

func _on_button_pressed() -> void:
	"""Handle button press - either Continue or Withdraw based on battle state"""
	# Play click sound for button press
	if sound_manager:
		sound_manager.click_sound()
	
	if battle_in_progress:
		# During battle, button acts as withdraw
		_on_withdraw_pressed()
	else:
		# After battle, button acts as continue
		_on_ok_pressed()

func _on_ok_pressed() -> void:
	"""Handle Continue button press"""
	if showing_battle_report:
		# We're on the battle report screen - close the modal
		hide_modal()
	else:
		# We're on the battle screen - show the battle report
		_show_battle_report()

func _show_battle_report() -> void:
	"""Switch to showing the battle report screen using the new summary modal"""
	if battle_summary_modal and battle_report:
		# Hide the battle modal
		visible = false
		# Show the summary modal with battle data
		battle_summary_modal.show_battle_summary(attacking_army, defending_region, battle_report, initial_attacker_comp, initial_defender_comp)
	else:
		# Fallback to old display if summary modal not available
		showing_battle_report = true
		_update_display()

func _on_withdraw_pressed() -> void:
	"""Handle Withdraw button press"""
	# Don't allow withdrawal if battle is not in progress
	if not battle_in_progress:
		return
	
	# Don't allow withdrawal if already withdrawing
	if withdrawal_in_progress:
		return
	
	# Play click sound for button press
	if sound_manager:
		sound_manager.click_sound()
	
	# Start withdrawal process
	withdrawal_in_progress = true
	
	# Update button state during withdrawal
	if continue_button:
		continue_button.disabled = true
		continue_button.text = "Withdrawing..."
	
	# Tell the animated simulator to start withdrawal round
	if animated_simulator:
		animated_simulator.start_withdrawal_round()
	
	DebugLogger.log("UISystem", "Starting withdrawal...")




func _apply_standard_theme(label: Label) -> void:
	"""Apply standard theme to a label"""
	label.theme = preload("res://themes/standard_text_theme.tres")
	label.add_theme_color_override("font_color", Color.WHITE)

func _setup_battle_summary_modal() -> void:
	"""Setup reference to battle summary modal"""
	# First try to find existing modal in UI
	var ui_node = get_parent()
	if ui_node:
		battle_summary_modal = ui_node.get_node_or_null("BattleSummaryModal") as BattleSummaryModal
	
	# If not found, try to load and instantiate it
	if battle_summary_modal == null:
		var summary_scene = load("res://scenes/battle_summary_modal.tscn")
		if summary_scene:
			battle_summary_modal = summary_scene.instantiate()
			if ui_node:
				ui_node.add_child(battle_summary_modal)

func _on_summary_closed() -> void:
	"""Called when battle summary modal is closed"""
	# Hide the battle modal completely and notify closure
	hide_modal()

func _draw():
	# Draw shadow first (behind everything)
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)
	
	# Draw background fill
	var bg_rect = Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, FRAME_COLOR)
	
	# Draw black border on top
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)
