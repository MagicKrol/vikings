extends Control
class_name BattleModal

# UI elements - references to static nodes from updated scene
var battle_title_label: Label
var attacker_header: Label
var defender_header: Label
var attacker_effectiveness: Label
var defender_effectiveness: Label
var assault_value_label: Label
var attacker_units_container: VBoxContainer
var defender_units_container: VBoxContainer
var continue_button: Button
var withdraw_button: Button
var battle_logs_button: Button
var second_player_container: HBoxContainer
var second_player_withdraw_button: Button
var quick_resolve_button: Button
var message_label: Label
var defender_defense_value: Label
var buttons_margin: MarginContainer
var stats_panel: Control
var stats_header_label: Label
var logs_scroll: ScrollContainer
var logs_data: RichTextLabel
var progress_bar_army1: ProgressBar
var progress_bar_army2: ProgressBar
var siege_panel: SiegePanel
var siege_payload: Dictionary = {}

# Battle data
var attacking_army: Army = null
var defending_region: Region = null
var battle_report: BattleSimulator.BattleReport = null
var siege_view_state: Dictionary = {}
var siege_counts: Dictionary = {}
var animated_simulator: AnimatedBattleSimulator = null
var battle_in_progress: bool = false

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
var attacker_manual_withdraw_requested: bool = false
var _defender_start_recruits: int = 0

# Sound manager reference
var sound_manager: SoundManager = null
# UI manager reference for modal mode
var ui_manager: UIManager = null
# Click manager reference for conquest completion
var click_manager: Node = null
var tutorial_manager: TutorialManager = null
var speed_modal: SpeedModal = null
var assault_ratio_override: float = -1.0
var _is_siege_battle: bool = false
var _power_progress_style_background: StyleBoxTexture
var _power_progress_style_green: StyleBoxTexture
var _power_progress_style_yellow: StyleBoxTexture
var _power_progress_style_red: StyleBoxTexture
var _initial_attacker_power: int = 0
var _initial_defender_power: int = 0
var _initial_defender_vigor_percent: int = 100
var _attacker_terrain_vigor_penalty_percent: int = 0
var _ranged_terrain_penalty_percent: int = 0
var _battle_logs_started: bool = false
var _battle_withdrawal_logged_sides: Dictionary = {}

const POWER_PROGRESS_TEX_EMPTY: Texture2D = preload("res://images/progressbar_empty.png")
const POWER_PROGRESS_TEX_GREEN: Texture2D = preload("res://images/progressbar_green.png")
const POWER_PROGRESS_TEX_YELLOW: Texture2D = preload("res://images/progressbar_yellow.png")
const POWER_PROGRESS_TEX_RED: Texture2D = preload("res://images/progressbar_red.png")

func _ready():
	# Get references to static UI elements from updated scene structure
	battle_title_label = get_node("Battle/VBoxContainer/Header/Header")
	attacker_header = get_node("Battle/VBoxContainer/SubHeader/HBoxContainer/Target")
	defender_header = get_node("Battle/VBoxContainer/SubHeader/HBoxContainer/Source")
	attacker_effectiveness = get_node("Battle/VBoxContainer/Status/AttackerVigorValue")
	defender_effectiveness = get_node("Battle/VBoxContainer/Status/DefenderVigorValue")
	assault_value_label = get_node("Battle/VBoxContainer/HBoxContainer2/AssaultValue")
	attacker_units_container = get_node("Battle/VBoxContainer/Body/Units")
	defender_units_container = get_node("Battle/VBoxContainer/Body/Units")
	continue_button = get_node("Battle/VBoxContainer/ButtonSection/HBoxContainer/Button")
	battle_logs_button = get_node("BattleLogs")
	second_player_container = get_node("Battle/VBoxContainer/ButtonSection/HBoxContainer/SecondPlayer")
	second_player_withdraw_button = get_node("Battle/VBoxContainer/ButtonSection/HBoxContainer/SecondPlayer/Withdraw")
	quick_resolve_button = get_node("Battle/VBoxContainer/ButtonSection/HBoxContainer/QuickResolve")
	withdraw_button = get_node("Battle/VBoxContainer/ButtonSection/HBoxContainer/Button")
	message_label = get_node("Battle/VBoxContainer/MessageSection/HBoxContainer/Message")
	defender_defense_value = get_node("Battle/VBoxContainer/HBoxContainer2/DefenderDefenseValue")
	buttons_margin = get_node("Battle/VBoxContainer/ButtonSection/HBoxContainer/ButtonsMargin") as MarginContainer
	stats_panel = get_node("Stats") as Control
	stats_header_label = get_node("Stats/Header/Name") as Label
	logs_scroll = get_node("Stats/Body/LogsScroll") as ScrollContainer
	logs_data = get_node("Stats/Body/LogsScroll/Logsdata") as RichTextLabel
	progress_bar_army1 = get_node("ProgressBarArmy1") as ProgressBar
	progress_bar_army2 = get_node("ProgressBarArmy2") as ProgressBar
	siege_panel = get_node("Siege") as SiegePanel
	_initialize_power_bar_styles()
	_reset_army_power_bars()

	# Connect button signals - single button handles both continue and withdraw
	continue_button.pressed.connect(_on_button_pressed)
	battle_logs_button.pressed.connect(_on_battle_logs_pressed)
	second_player_withdraw_button.pressed.connect(_on_second_player_withdraw_pressed)
	quick_resolve_button.pressed.connect(_on_quick_resolve_pressed)
	withdraw_button = continue_button  # Both reference the same button
	continue_button.name = "continue"
	battle_logs_button.text = tr("Battle Logs Button").replace("|", "\n")
	stats_header_label.text = tr("Battle Logs")
	_apply_stats_panel_visibility()
	_set_message("")
	
	# Get manager references
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	click_manager = get_node("../../ClickManager")
	speed_modal = get_node("../SpeedModal") as SpeedModal
	var game_manager = get_node("../../GameManager") as GameManager
	if game_manager:
		tutorial_manager = game_manager.get_tutorial_manager()
		if tutorial_manager != null:
			continue_button.pressed.connect(func(): tutorial_manager.handle_ui_click("BattleModal/" + continue_button.name))
	if speed_modal:
		speed_modal.speed_changed.connect(_on_speed_modal_changed)
	
	# Create animated battle simulator
	animated_simulator = AnimatedBattleSimulator.new()
	animated_simulator.round_completed.connect(_on_battle_round_completed)
	animated_simulator.battle_finished.connect(_on_battle_finished)
	animated_simulator.ai_withdrawal_started.connect(_on_ai_withdrawal_started)
	add_child(animated_simulator)
	
	# Initially hidden
	visible = false
	
	# Try to find or create battle summary modal
	_setup_battle_summary_modal()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var turn_modal: TurnModal = get_node("../TurnModal") as TurnModal
	if turn_modal.try_handle_end_turn_hotkey(event):
		get_viewport().set_input_as_handled()
		return
	if _is_quick_resolve_hotkey(event):
		if battle_in_progress and quick_resolve_button.visible and not quick_resolve_button.disabled:
			_on_quick_resolve_pressed()
			get_viewport().set_input_as_handled()
			return
	if battle_in_progress:
		return
	if battle_report == null:
		return
	if _is_continue_hotkey(event):
		_on_button_pressed()
		get_viewport().set_input_as_handled()

func _is_quick_resolve_hotkey(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == KEY_SPACE

func _is_continue_hotkey(event: InputEvent) -> bool:
	var mapped_continue_close_pressed: bool = GameParameters.is_continue_close_key_pressed(event)
	if mapped_continue_close_pressed and not _is_tutorial_mode_active():
		return true
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.alt_pressed:
		return false
	return key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER

func _is_tutorial_mode_active() -> bool:
	var game_manager: GameManager = get_node("../../GameManager") as GameManager
	return game_manager.tutorial_enabled

func _on_battle_logs_pressed() -> void:
	var next_visible: bool = not GameParameters.get_battle_logs_visible()
	GameParameters.set_battle_logs_visible(next_visible)
	_apply_stats_panel_visibility()
	SaveGameManager.save_settings(sound_manager)

func _apply_stats_panel_visibility() -> void:
	if _is_tutorial_mode_active():
		battle_logs_button.visible = false
		stats_panel.visible = false
		return
	battle_logs_button.visible = true
	stats_panel.visible = GameParameters.get_battle_logs_visible()

func show_battle(army: Army, region: Region, siege_payload: Dictionary = {}) -> void:
	"""Show the battle modal with army vs region information"""
	if army == null or region == null:
		hide_modal()
		return
	var info_modal = get_node("../InfoModal") as InfoModal
	info_modal.hide_modal(false)
	
	DebugLogger.log("Withdrawal", "BattleModal.show_battle attacker=" + str(army.get_display_name()) + " defender_region=" + str(region.get_region_name()))
	attacker_manual_withdraw_requested = false
	attacking_army = army
	defending_region = region
	self.siege_payload = siege_payload.duplicate(true)
	siege_counts = siege_payload.get("siege_counts", {})
	siege_view_state = _build_siege_view_state_from_payload(siege_payload)
	assault_ratio_override = float(siege_payload.get("assault_ratio", -1.0))
	_is_siege_battle = defending_region.get_castle_type() != CastleTypeEnum.Type.NONE
	siege_panel.visible = _is_siege_battle

	_set_message("")
	_reset_battle_logs()
	sound_manager.play_battle_sound()
	quick_resolve_button.visible = true
	if buttons_margin:
		buttons_margin.visible = true
	if speed_modal:
		speed_modal.set_context("battle")
		speed_modal.visible = true
	_reset_army_power_bars()

	# Show initial display BEFORE starting battle
	_apply_siege_state()
	_update_display()
	_apply_stats_panel_visibility()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)
	
	# Run battle simulation AFTER showing initial state
	_run_battle_simulation()

func hide_modal() -> void:
	"""Hide the battle modal"""
	DebugLogger.log("UISystem", "Hiding modal and notifying click manager...")
	DebugLogger.log("Withdrawal", "BattleModal.hide_modal reset state")
	
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
	siege_payload = {}
	siege_view_state = {}
	siege_counts = {}
	battle_in_progress = false
	showing_battle_report = false
	current_round = 0
	current_attacker_composition.clear()
	current_defender_composition.clear()
	assault_ratio_override = -1.0
	_set_message("")
	_reset_battle_logs()
	_reset_army_power_bars()

	# Reset withdrawal state
	withdrawal_in_progress = false

	# Reset button
	_update_action_button()
	
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)
	if speed_modal:
		speed_modal.set_context("ai")
		var gm = get_node("../../GameManager") as GameManager
		var current_player_id := gm.get_current_player_id()
		var show_ai_speed := gm.is_player_computer(current_player_id) and not gm.is_castle_placing_mode()
		speed_modal.visible = show_ai_speed

func _update_display() -> void:
	"""Update the display with current battle information"""
	if attacking_army == null or defending_region == null:
		hide_modal()
		return
	
	_update_defense_bonus_display()
	_update_assault_value()

	if showing_battle_report:
		# Show battle report screen
		_display_battle_report()
	else:
		# Show normal battle screen
		# Update battle title
		var region_name = defending_region.get_region_name()
		battle_title_label.text = tr("Battle for %s") % region_name
		
		# Set appropriate headers for normal battle
		_update_attacker_header()
		_update_defender_header()
		attacker_effectiveness.visible = true
		defender_effectiveness.visible = true
		
		# Update vigor displays
		_update_effectiveness_displays()
		
		# Update attacker units
		_update_attacker_units()
		
		# Update defender units  
		_update_defender_units()
		
		_update_action_button()
	_update_army_power_bars()

func _build_siege_view_state_from_payload(siege_payload: Dictionary) -> Dictionary:
	var payload_state: Dictionary = siege_payload.get("siege_view_state", {})
	if not payload_state.is_empty():
		return payload_state
	var gate_state: Dictionary = siege_payload.get("gate_state", defending_region.get_gate_state())
	var ram_total: int = int(siege_counts.get("rams", 0))
	return SiegePanel.build_state(defending_region, gate_state, ram_total)

func _apply_siege_state() -> void:
	if not _is_siege_battle:
		return
	siege_panel.apply_state(siege_view_state)


func _update_effectiveness_displays() -> void:
	"""Update the vigor labels with current values"""
	if attacking_army == null or defending_region == null:
		return
	
	# Get attacking army vigor
	var attacker_vigor: int = GameParameters.get_battle_attacker_effective_vigor(attacking_army.get_efficiency(), defending_region.get_region_type())
	attacker_effectiveness.text = str(attacker_vigor) + "%"
	
	defender_effectiveness.text = str(_initial_defender_vigor_percent) + "%"


func _calculate_initial_defender_vigor_percent(defending_armies: Array[Army], garrison_comp: ArmyComposition) -> int:
	var weighted_vigor_sum: int = 0
	var total_units: int = 0
	for defending_army in defending_armies:
		var defending_army_units: int = 0
		for unit_type in SoldierTypeEnum.get_all_types():
			defending_army_units += defending_army.get_soldier_count(unit_type)
		if defending_army_units <= 0:
			continue
		var defending_army_vigor: int = defending_army.get_efficiency()
		weighted_vigor_sum += defending_army_units * defending_army_vigor
		total_units += defending_army_units
	var garrison_units: int = garrison_comp.get_total_soldiers()
	if garrison_units > 0:
		weighted_vigor_sum += garrison_units * 100
		total_units += garrison_units
	if total_units <= 0:
		return 100
	return int(round(float(weighted_vigor_sum) / float(total_units)))


func _display_battle_report() -> void:
	"""Display the battle report screen"""
	# Update title
	battle_title_label.text = tr("Battle Report")
	
	# Hide vigor labels (not needed for report)
	attacker_effectiveness.visible = false
	defender_effectiveness.visible = false
	
	# Change column headers
	attacker_header.text = tr("Your Losses")
	attacker_header.remove_theme_color_override("font_color")
	defender_header.text = tr("Enemy Losses")
	defender_header.remove_theme_color_override("font_color")
	
	# Display losses if we have battle report
	if battle_report != null:
		_display_army_losses()
	
	# Update button text for final screen
	if continue_button:
		continue_button.text = tr("Continue")

func _display_army_losses() -> void:
	"""Display losses for both armies in the report format"""
	# Update unit labels to show losses instead of remaining counts
	for unit_type in SoldierTypeEnum.get_all_types():
		var unit_name = _get_unit_section_name(unit_type)
		if unit_name == "":
			continue
		
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
	if unit_section_name == "Total":
		return
	var section_path = "Battle/VBoxContainer/Body/Units/" + unit_section_name
	
	var section_node = get_node(section_path)
	
	var attacker_label: Label = section_node.get_node("VBoxContainer/TextureRect/Label") as Label
	var defender_label: Label = section_node.get_node("VBoxContainer/TextureRect/Label2") as Label
	
	if is_attacker:
		attacker_label.text = str(loss_count)
		attacker_label.add_theme_color_override("font_color", Color.RED)
	
	if not is_attacker:
		defender_label.text = str(loss_count)
		defender_label.add_theme_color_override("font_color", Color.RED)

func _get_unit_section_name(unit_type: int) -> String:
	match unit_type:
		SoldierTypeEnum.Type.PEASANTS:
			return "Peasants"
		SoldierTypeEnum.Type.ARCHERS:
			return "Archers"
		SoldierTypeEnum.Type.SPEARMEN:
			return "Spearmen"
		SoldierTypeEnum.Type.SWORDSMEN:
			return "Swordsmen"
		SoldierTypeEnum.Type.CROSSBOWMEN:
			return "Crosbowmen"
		SoldierTypeEnum.Type.HORSEMEN:
			return "Horsemen"
		SoldierTypeEnum.Type.KNIGHTS:
			return "Knights"
		SoldierTypeEnum.Type.MOUNTED_KNIGHTS:
			return "MountedKnights"
		SoldierTypeEnum.Type.ROYAL_GUARD:
			return "RoyalGuard"
	return ""



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
	_update_unit_count_label("Crosbowmen", SoldierTypeEnum.Type.CROSSBOWMEN, composition_to_show, initial_composition, true)
	_update_unit_count_label("Horsemen", SoldierTypeEnum.Type.HORSEMEN, composition_to_show, initial_composition, true)
	_update_unit_count_label("Knights", SoldierTypeEnum.Type.KNIGHTS, composition_to_show, initial_composition, true)
	_update_unit_count_label("MountedKnights", SoldierTypeEnum.Type.MOUNTED_KNIGHTS, composition_to_show, initial_composition, true)
	_update_unit_count_label("RoyalGuard", SoldierTypeEnum.Type.ROYAL_GUARD, composition_to_show, initial_composition, true)
	
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
	_update_unit_count_label("Crosbowmen", SoldierTypeEnum.Type.CROSSBOWMEN, composition_to_show, initial_composition, false)
	_update_unit_count_label("Horsemen", SoldierTypeEnum.Type.HORSEMEN, composition_to_show, initial_composition, false)
	_update_unit_count_label("Knights", SoldierTypeEnum.Type.KNIGHTS, composition_to_show, initial_composition, false)
	_update_unit_count_label("MountedKnights", SoldierTypeEnum.Type.MOUNTED_KNIGHTS, composition_to_show, initial_composition, false)
	_update_unit_count_label("RoyalGuard", SoldierTypeEnum.Type.ROYAL_GUARD, composition_to_show, initial_composition, false)
	
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
	if unit_section_name == "Total":
		return
	var section_path = "Battle/VBoxContainer/Body/Units/" + unit_section_name
	
	var section_node = get_node(section_path)
	
	var attacker_label: Label = section_node.get_node("VBoxContainer/TextureRect/Label") as Label
	var defender_label: Label = section_node.get_node("VBoxContainer/TextureRect/Label2") as Label
	
	if is_attacker:
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
		if initial_count == 0:
			attacker_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
		elif current_count == 0:
			attacker_label.add_theme_color_override("font_color", Color.RED)
		elif current_count < initial_count:
			attacker_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			attacker_label.add_theme_color_override("font_color", Color.WHITE)
	
	if not is_attacker:
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
		if initial_count == 0:
			defender_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
		elif current_count == 0:
			defender_label.add_theme_color_override("font_color", Color.RED)
		elif current_count < initial_count:
			defender_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			defender_label.add_theme_color_override("font_color", Color.WHITE)


func _run_battle_simulation() -> void:
	"""Run the animated battle simulation between attacking army and region garrison"""
	if attacking_army == null or defending_region == null:
		return
	
	battle_in_progress = true
	current_round = 0
	
	# Reset display data
	current_attacker_composition = {}
	current_defender_composition = {}
	_initial_defender_vigor_percent = 100
	
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
	var pending_defending_armies: Array[Army] = bm.get_pending_defending_armies()
	for comp in def_comps:
		for unit_type in SoldierTypeEnum.get_all_types():
			var c = comp.get_soldier_count(unit_type)
			if c > 0:
				current_defender_composition[unit_type] = current_defender_composition.get(unit_type, 0) + c
	# Add garrison to display
	var garrison_comp = defending_region.get_garrison()
	_initial_defender_vigor_percent = _calculate_initial_defender_vigor_percent(pending_defending_armies, garrison_comp)
	for unit_type in SoldierTypeEnum.get_all_types():
		var gc = garrison_comp.get_soldier_count(unit_type)
		if gc > 0:
			current_defender_composition[unit_type] = current_defender_composition.get(unit_type, 0) + gc
	# Add recruits to live defender composition (used by round UI + power bar baseline)
	var summary_recruits: int = defending_region.get_base_available_recruits()
	_defender_start_recruits = summary_recruits
	if summary_recruits > 0:
		current_defender_composition[SoldierTypeEnum.Type.PEASANTS] = current_defender_composition.get(SoldierTypeEnum.Type.PEASANTS, 0) + summary_recruits
	
	# Store initial compositions for battle summary
	initial_attacker_comp = current_attacker_composition.duplicate()
	initial_defender_comp = current_defender_composition.duplicate()
	# Power bars baseline must match the exact live starting compositions.
	_initial_attacker_power = _compute_dict_power(current_attacker_composition)
	_initial_defender_power = _compute_dict_power(current_defender_composition)
	_update_army_power_bars()
	
	# During battle, show withdraw functionality
	_update_assault_value()
	_update_action_button()
	
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
	animated_simulator.set_round_time(GameParameters.get_battle_round_time())
	var attacker_base_efficiency: int = attacking_army.get_efficiency()
	var terrain_type = defending_region.get_region_type()
	_attacker_terrain_vigor_penalty_percent = GameParameters.get_battle_attacker_terrain_vigor_penalty(terrain_type)
	_ranged_terrain_penalty_percent = GameParameters.get_battle_ranged_terrain_penalty_for_region(terrain_type)
	var attacker_efficiency: int = GameParameters.get_battle_attacker_effective_vigor(attacker_base_efficiency, terrain_type)
	_append_attacker_terrain_vigor_penalty_log()
	_append_ranged_terrain_penalty_log()
	var castle_type = defending_region.get_castle_type()
	var defense_override = bm.get_effective_defense_for_region(defending_region)
	var attacker_withdraw_allowed = bm.get_attacker_withdraw_allowed()
	var defender_withdraw_allowed = bm.get_defender_withdraw_allowed()
	var attacker_effectiveness_ratio = bm.get_attacker_effectiveness_ratio()
	var ai_withdrawal_rules: Dictionary = bm.get_ai_withdrawal_rules()
	animated_simulator.start_animated_battle(attacking_compositions, defending_compositions, region_garrison, attacker_efficiency, 100, terrain_type, castle_type, attacker_withdraw_allowed, defender_withdraw_allowed, defense_override, attacker_effectiveness_ratio, siege_payload, ai_withdrawal_rules)
	
	DebugLogger.log("UISystem", "Starting animated battle simulation...")

func _on_battle_round_completed(round_data: Dictionary) -> void:
	"""Handle completion of a battle round"""
	if round_data.is_empty():
		return
	current_round = round_data["round"]
	current_attacker_composition = round_data["current_attackers"]
	current_defender_composition = round_data["current_defenders"]
	if round_data.has("assault_ratio"):
		assault_ratio_override = float(round_data["assault_ratio"])
	if round_data.has("gate_state"):
		var gate_state: Dictionary = round_data.get("gate_state", {})
		var active_rams: int = int(round_data.get("active_rams", 0))
		var reserve_rams: int = int(round_data.get("reserve_rams", 0))
		var total_rams: int = active_rams + reserve_rams
		var wall_state: Dictionary = siege_view_state.get("wall_state", {})
		siege_view_state = {
			"wall_state": wall_state,
			"gate_state": gate_state,
			"ram_count": total_rams,
			"active_rams": active_rams,
			"reserve_rams": reserve_rams
		}
		_apply_siege_state()
	
	# Update display with current round data
	_update_display()
	_append_battle_round_logs(round_data)
	
	DebugLogger.log("UISystem", "Round " + str(current_round) + " completed - Attackers: " + str(round_data["attacker_size"]) + ", Defenders: " + str(round_data["defender_size"]))

func _on_battle_finished(report: BattleSimulator.BattleReport) -> void:
	"""Handle battle completion"""
	battle_in_progress = false
	# Compute wounded before showing summary
	report.attacker_wounded = Utils.compute_wounded(report.attacker_losses)
	report.defender_wounded = Utils.compute_wounded(report.defender_losses)
	DebugLogger.log("Withdrawal", "BattleModal._on_battle_finished winner=" + str(report.winner) + " withdrawing_side=" + str(report.withdrawing_side) + " manual_request=" + str(attacker_manual_withdraw_requested))
	battle_report = report
	sound_manager.fade_out_battle_sound()
	quick_resolve_button.visible = false
	if buttons_margin:
		buttons_margin.visible = false

	# If AI modal is disabled for debugging, finalize immediately only when defender is not human
	var gm = get_node("../../GameManager") as GameManager
	var owner_id := gm.get_region_manager().get_region_owner(defending_region.get_region_id())
	var defender_is_human := (owner_id != -1 and gm.is_player_human(owner_id))
	if gm.debug_disable_battle_modal and gm.is_player_computer(attacking_army.get_player_id()) and not defender_is_human:
		gm.get_battle_manager().handle_battle_modal_closed()
		# Hide modal and stop here to avoid waiting for UI interaction
		hide_modal()
		return
	
	# Reset withdrawal state
	withdrawal_in_progress = false
	_set_message(tr("Battle has ended"))
	_update_action_button()

	# Final display update
	_update_display()
	if tutorial_manager != null:
		tutorial_manager.handle_battle_finished()
	
	DebugLogger.log("UISystem", "Battle finished! Winner: " + str(report.winner))

func _on_ai_withdrawal_started(side: int) -> void:
	"""Display notice when withdrawal begins (attacker=1, defender=2)."""
	var gm = get_node("../../GameManager") as GameManager
	var region_owner := gm.get_region_manager().get_region_owner(defending_region.get_region_id()) if gm and defending_region else -1
	var human_attacker := _player_controls_attacking_army()
	var human_defender := (gm and gm.is_player_human(region_owner)) or _player_has_defending_army()
	var human_side := 1 if human_attacker else (2 if human_defender else 0)
	if side == human_side:
		_set_message(tr("Your army is withdrawing"))
	else:
		_set_message(tr("Enemy is withdrawing"))
	_play_retreat_sound()
	withdrawal_in_progress = true
	_update_action_button()
	_append_withdrawal_log(side)

func _on_quick_resolve_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	animated_simulator.set_round_time(GameParameters.BATTLE_ROUND_TIME_QUICK)

func _on_button_pressed() -> void:
	"""Handle button press - either Continue or Withdraw based on battle state"""
	# Play click sound for button press
	if sound_manager:
		sound_manager.click_sound()
	
	if battle_in_progress:
		if _is_dual_human_battle():
			# In dual-human battle, this button withdraws Source/defender side.
			_on_withdraw_pressed_for_side(2, false)
		else:
			# Legacy behavior: button withdraws whichever human side is active.
			_on_withdraw_pressed()
	else:
		# After battle, button acts as continue
		_on_ok_pressed()

func _on_second_player_withdraw_pressed() -> void:
	"""Handle Target-side withdraw in dual-human battles."""
	if sound_manager:
		sound_manager.click_sound()
	_on_withdraw_pressed_for_side(1, false)

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
		DebugLogger.log("Withdrawal", "Withdraw click ignored: battle not in progress")
		return
	
	# Don't allow withdrawal if already withdrawing
	if withdrawal_in_progress:
		DebugLogger.log("Withdrawal", "Withdraw click ignored: already withdrawing")
		return
	
	# Play click sound for button press
	if sound_manager:
		sound_manager.click_sound()
	
	# Role-specific withdrawal handling
	var gm = get_node("../../GameManager") as GameManager
	var region_owner := gm.get_region_manager().get_region_owner(defending_region.get_region_id())
	var human_controls_attacker := _player_controls_attacking_army()
	var human_controls_defender := gm.is_player_human(region_owner) or _player_has_defending_army()
	DebugLogger.log("Withdrawal", "Withdraw click state round=" + str(current_round) + " attacker_controls=" + str(human_controls_attacker) + " defender_controls=" + str(human_controls_defender) + " withdraw_flag=" + str(withdrawal_in_progress))
	
	# Defender (human): retreat not simulated with attacker-only withdrawal rounds
	if human_controls_defender and not human_controls_attacker:
		_on_withdraw_pressed_for_side(2, false)
		return
	elif human_controls_attacker:
		_on_withdraw_pressed_for_side(1, false)
	else:
		# No human-controlled side detected; ignore button
		DebugLogger.log("Withdrawal", "Withdraw click ignored: no human-controlled side")
		return

func _on_withdraw_pressed_for_side(side: int, play_click_sound: bool = true) -> void:
	"""Start withdrawal for explicit side (1=attacker/Target, 2=defender/Source)."""
	if not battle_in_progress:
		DebugLogger.log("Withdrawal", "Withdraw click ignored: battle not in progress")
		return
	if withdrawal_in_progress:
		DebugLogger.log("Withdrawal", "Withdraw click ignored: already withdrawing")
		return
	if play_click_sound and sound_manager:
		sound_manager.click_sound()
	if not _is_withdraw_allowed_for_side(side):
		DebugLogger.log("Withdrawal", "Withdraw denied by eligibility for side " + str(side))
		return

	var gm = get_node("../../GameManager") as GameManager
	if side == 2:
		withdrawal_in_progress = true
		_set_message(tr("Your army is withdrawing"))
		_play_retreat_sound()
		_update_action_button()
		if animated_simulator:
			animated_simulator.start_withdrawal_round(2)
		DebugLogger.log("UISystem", "Starting withdrawal...")
		DebugLogger.log("Withdrawal", "Defender withdrawal started")
		return
	if side == 1:
		withdrawal_in_progress = true
		attacker_manual_withdraw_requested = true
		gm.get_battle_manager().mark_attacker_manual_withdrawal()
		_set_message(tr("Your army is withdrawing"))
		_play_retreat_sound()
		_update_action_button()
		if animated_simulator:
			animated_simulator.start_withdrawal_round(1)
		DebugLogger.log("UISystem", "Starting withdrawal...")
		DebugLogger.log("Withdrawal", "Attacker withdrawal started; def_withdraw_allowed=" + str(animated_simulator.defender_can_withdraw) + " timer=" + str(animated_simulator.battle_timer.wait_time))
		return

func _is_withdraw_allowed_for_current_role() -> bool:
	var gm = get_node("../../GameManager") as GameManager
	if gm == null:
		return false
	if _player_controls_attacking_army():
		return _is_withdraw_allowed_for_side(1)
	return _is_withdraw_allowed_for_side(2)

func _is_withdraw_allowed_for_side(side: int) -> bool:
	var gm = get_node("../../GameManager") as GameManager
	if gm == null:
		return false
	if side == 1:
		return _player_controls_attacking_army()
	if side != 2:
		return false
	if not _player_has_defending_army():
		return false
	if defending_region == null:
		return false
	var region_owner := gm.get_region_manager().get_region_owner(defending_region.get_region_id())
	if not gm.is_player_human(region_owner):
		return false
	if defending_region.get_castle_type() != CastleTypeEnum.Type.NONE:
		return false
	var neighbors := gm.get_region_manager().get_neighbor_regions(defending_region.get_region_id())
	for nid in neighbors:
		if gm.get_region_manager().get_region_owner(nid) == region_owner:
			return true
	return false


func _update_action_button() -> void:
	if continue_button == null:
		return
	if battle_in_progress:
		if not _player_has_army_in_battle():
			continue_button.visible = false
			second_player_container.visible = false
			return
		continue_button.visible = true
		var dual_human: bool = _is_dual_human_battle()
		second_player_container.visible = dual_human
		if withdrawal_in_progress:
			continue_button.text = tr("Continue")
			continue_button.disabled = true
			second_player_withdraw_button.disabled = true
		else:
			continue_button.text = tr("Withdraw")
			if dual_human:
				continue_button.disabled = not _is_withdraw_allowed_for_side(2)
				second_player_withdraw_button.disabled = not _is_withdraw_allowed_for_side(1)
			else:
				continue_button.disabled = not _is_withdraw_allowed_for_current_role()
				second_player_withdraw_button.disabled = true
	else:
		continue_button.visible = true
		continue_button.text = tr("Continue")
		continue_button.disabled = false
		second_player_container.visible = false
		second_player_withdraw_button.disabled = false

func _reset_battle_logs() -> void:
	logs_data.clear()
	_battle_logs_started = false
	_battle_withdrawal_logged_sides.clear()
	_attacker_terrain_vigor_penalty_percent = 0
	_ranged_terrain_penalty_percent = 0

func _append_attacker_terrain_vigor_penalty_log() -> void:
	if _attacker_terrain_vigor_penalty_percent <= 0:
		return
	var player_id: int = attacking_army.get_player_id()
	_append_log_line(tr("Player %d is fighting in difficult terrain. Vigor reduced by %d%%.") % [player_id, _attacker_terrain_vigor_penalty_percent])

func _append_ranged_terrain_penalty_log() -> void:
	if _ranged_terrain_penalty_percent <= 0:
		return
	_append_log_line(tr("Ranged units' effectiveness is reduced by dense forest by %d%%.") % _ranged_terrain_penalty_percent)

func _append_log_line(text: String = "") -> void:
	logs_data.append_text(text + "\n")
	_scroll_logs_to_bottom()

func _append_log_center(text: String) -> void:
	logs_data.append_text("[center]" + text + "[/center]\n")
	_scroll_logs_to_bottom()

func _scroll_logs_to_bottom() -> void:
	call_deferred("_scroll_logs_to_bottom_deferred")

func _scroll_logs_to_bottom_deferred() -> void:
	logs_data.scroll_to_line(max(0, logs_data.get_line_count() - 1))
	var vertical_scroll_bar: VScrollBar = logs_scroll.get_v_scroll_bar()
	logs_scroll.scroll_vertical = int(vertical_scroll_bar.max_value)

func _append_withdrawal_log(side: int) -> void:
	if side <= 0:
		return
	if _battle_withdrawal_logged_sides.has(side):
		return
	_battle_withdrawal_logged_sides[side] = true
	var player_id: int = _get_side_player_id(side == 1)
	_append_log_center(tr("Player %d withdraws") % player_id)

func _append_battle_round_logs(round_data: Dictionary) -> void:
	var attacker_breakdown: Dictionary = round_data.get("attacker_kill_breakdown", {}) as Dictionary
	var defender_breakdown: Dictionary = round_data.get("defender_kill_breakdown", {}) as Dictionary
	var is_volley: bool = round_data.has("is_ranged_volley") and bool(round_data["is_ranged_volley"])
	var is_withdrawal: bool = round_data.has("is_withdrawal") and bool(round_data["is_withdrawal"])
	if round_data.has("withdrawing_side"):
		_append_withdrawal_log(int(round_data.get("withdrawing_side", 0)))
	if is_volley:
		_append_log_line("")
		_append_log_center(tr("Prebattle volleys:"))
		var attacker_logged_volley: bool = _append_side_breakdown(attacker_breakdown, true)
		var defender_logged_volley: bool = _append_side_breakdown(defender_breakdown, false)
		if not attacker_logged_volley and not defender_logged_volley:
			_append_log_line(tr("No casulties inflicted."))
		return
	if not _battle_logs_started:
		_append_log_center(tr("Battle starts"))
		_battle_logs_started = true
	var round_number: int = int(round_data.get("round", 0))
	_append_log_line("")
	_append_log_center(tr("Round %d") % round_number)
	if is_withdrawal:
		_append_log_center("(" + tr("free hits") + ")")
	var attacker_logged: bool = _append_side_breakdown(attacker_breakdown, true)
	var defender_logged: bool = _append_side_breakdown(defender_breakdown, false)
	if not attacker_logged and not defender_logged:
		_append_log_line(tr("No casulties inflicted."))

func _append_side_breakdown(side_breakdown: Dictionary, is_attacker_side: bool) -> bool:
	var wrote_any: bool = false
	for attacker_unit_type in SoldierTypeEnum.get_all_types():
		if not side_breakdown.has(attacker_unit_type):
			continue
		var target_losses: Dictionary = side_breakdown.get(attacker_unit_type, {})
		var total_casualties: int = 0
		for target_unit_type in target_losses.keys():
			total_casualties += int(target_losses.get(target_unit_type, 0))
		if total_casualties <= 0:
			continue
		var player_id: int = _get_side_player_id(is_attacker_side)
		var player_color_hex: String = _get_player_color_hex(player_id)
		var unit_name: String = SoldierTypeEnum.type_to_display_string(attacker_unit_type)
		var colored_name: String = "[color=#" + player_color_hex + "]" + unit_name + "[/color]"
		var line_text: String = tr("%s inflicted %d casualties:") % [colored_name, total_casualties]
		_append_log_line(line_text)
		wrote_any = true
		for target_unit_type in SoldierTypeEnum.get_all_types():
			if not target_losses.has(target_unit_type):
				continue
			var target_hits: int = int(target_losses.get(target_unit_type, 0))
			if target_hits <= 0:
				continue
			var target_name: String = SoldierTypeEnum.type_to_display_string(target_unit_type)
			_append_log_line("- " + target_name + ": " + str(target_hits))
	return wrote_any

func _get_side_player_id(is_attacker_side: bool) -> int:
	if is_attacker_side:
		return attacking_army.get_player_id()
	var gm = get_node("../../GameManager") as GameManager
	return gm.get_region_manager().get_region_owner(defending_region.get_region_id())

func _get_player_color_hex(player_id: int) -> String:
	if player_id <= 0:
		return "f1d891"
	return GameParameters.get_player_color(player_id).to_html(false)

func _set_message(text: String) -> void:
	message_label.text = text

func _play_retreat_sound() -> void:
	if sound_manager:
		sound_manager.play_retreat_horn()

func _on_speed_modal_changed(context: String, value: float) -> void:
	if context == "battle" and animated_simulator:
		animated_simulator.set_round_time(GameParameters.get_battle_round_time())

func _update_attacker_header() -> void:
	var player_id = attacking_army.get_player_id()
	var player_name: String = tr("Player %d") % player_id
	attacker_header.text = tr("Army %s (%s)") % [attacking_army.number, player_name]
	var player_color = GameParameters.get_player_color(player_id)
	attacker_header.add_theme_color_override("font_color", player_color)

func _update_defense_bonus_display() -> void:
	var gm = get_node("../../GameManager") as GameManager
	var bm = gm.get_battle_manager()
	var defense_bonus = bm.get_effective_defense_for_region(defending_region)
	defender_defense_value.text = str(defense_bonus) + "%"
	defender_defense_value.remove_theme_color_override("font_color")
	var base_def = GameParameters.get_castle_defense_bonus(defending_region.get_castle_type())
	var min_def = GameParameters.CASTLE_DEFENSE_BONUSES_MIN.get(defending_region.get_castle_type(), 0)
	if base_def > 0:
		if min_def > 0 and defense_bonus <= min_def:
			defender_defense_value.add_theme_color_override("font_color", Color.html("#d13131"))
		elif defense_bonus < base_def:
			defender_defense_value.add_theme_color_override("font_color", GameParameters.UI_COLOR_WOUNDED)
		else:
			defender_defense_value.add_theme_color_override("font_color", Color.WHITE)
	else:
		defender_defense_value.add_theme_color_override("font_color", Color.WHITE)

func _update_assault_value() -> void:
	var percent := 0
	if not _is_siege_battle:
		percent = 100
	elif assault_ratio_override >= 0.0:
		percent = int(round(clampf(assault_ratio_override, 0.0, 1.0) * 100.0))
	else:
		var gm = get_node("../../GameManager") as GameManager
		var bm = gm.get_battle_manager()
		var ratio: float = bm.get_attacker_effectiveness_ratio()
		percent = int(round(ratio * 100.0))
	assault_value_label.text = str(percent) + "%"

func _initialize_power_bar_styles() -> void:
	_power_progress_style_background = StyleBoxTexture.new()
	_power_progress_style_background.texture = POWER_PROGRESS_TEX_EMPTY
	_power_progress_style_green = StyleBoxTexture.new()
	_power_progress_style_green.texture = POWER_PROGRESS_TEX_GREEN
	_power_progress_style_yellow = StyleBoxTexture.new()
	_power_progress_style_yellow.texture = POWER_PROGRESS_TEX_YELLOW
	_power_progress_style_red = StyleBoxTexture.new()
	_power_progress_style_red.texture = POWER_PROGRESS_TEX_RED

func _reset_army_power_bars() -> void:
	_initial_attacker_power = 0
	_initial_defender_power = 0
	_update_power_bar(progress_bar_army1, 100)
	_update_power_bar(progress_bar_army2, 100)

func _update_army_power_bars() -> void:
	var attacker_composition: Dictionary = _get_attacker_power_composition()
	var defender_composition: Dictionary = _get_defender_power_composition()
	var attacker_power: int = _compute_dict_power(attacker_composition)
	var defender_power: int = _compute_dict_power(defender_composition)
	var attacker_percent: int = _compute_power_percent(attacker_power, _initial_attacker_power)
	var defender_percent: int = _compute_power_percent(defender_power, _initial_defender_power)
	_update_power_bar(progress_bar_army1, attacker_percent)
	_update_power_bar(progress_bar_army2, defender_percent)

func _get_attacker_power_composition() -> Dictionary:
	if battle_in_progress:
		return current_attacker_composition
	if battle_report != null:
		return battle_report.final_attacker
	if not initial_attacker_comp.is_empty():
		return initial_attacker_comp
	var composition: Dictionary = {}
	var army_comp: ArmyComposition = attacking_army.get_composition()
	for unit_type in SoldierTypeEnum.get_all_types():
		var count: int = army_comp.get_soldier_count(unit_type)
		if count > 0:
			composition[unit_type] = count
	return composition

func _get_defender_power_composition() -> Dictionary:
	if battle_in_progress:
		return current_defender_composition
	if battle_report != null:
		return battle_report.final_defender
	if not initial_defender_comp.is_empty():
		return initial_defender_comp
	var composition: Dictionary = {}
	var garrison_comp: ArmyComposition = defending_region.get_garrison()
	for unit_type in SoldierTypeEnum.get_all_types():
		var count: int = garrison_comp.get_soldier_count(unit_type)
		if count > 0:
			composition[unit_type] = count
	var base_recruits: int = defending_region.get_base_available_recruits()
	if base_recruits > 0:
		composition[SoldierTypeEnum.Type.PEASANTS] = composition.get(SoldierTypeEnum.Type.PEASANTS, 0) + base_recruits
	return composition

func _compute_dict_power(comp_dict: Dictionary) -> int:
	var total_power: int = 0
	for unit_type in comp_dict.keys():
		var qty: int = int(comp_dict[unit_type])
		if qty <= 0:
			continue
		total_power += int(GameParameters.get_unit_stat(unit_type, "power")) * qty
	return total_power

func _compute_power_percent(current_power: int, initial_power: int) -> int:
	if initial_power <= 0:
		return 100
	var value: int = int(round((float(current_power) / float(initial_power)) * 100.0))
	return clampi(value, 0, 100)

func _update_power_bar(progress_bar: ProgressBar, percent: int) -> void:
	var clamped_percent: int = clampi(percent, 0, 100)
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = clamped_percent
	progress_bar.add_theme_stylebox_override("background", _power_progress_style_background)
	var fill_style: StyleBoxTexture = _power_progress_style_red
	if clamped_percent >= 67:
		fill_style = _power_progress_style_green
	elif clamped_percent >= 34:
		fill_style = _power_progress_style_yellow
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	progress_bar.queue_redraw()

func _update_defender_header() -> void:
	var region_name = defending_region.get_region_name()
	var gm = get_node("../../GameManager") as GameManager
	var owner_id = gm.get_region_manager().get_region_owner(defending_region.get_region_id())
	defender_header.text = tr("%s defenders") % region_name
	if owner_id == -1:
		defender_header.remove_theme_color_override("font_color")
	else:
		var owner_color = GameParameters.get_player_color(owner_id)
		defender_header.add_theme_color_override("font_color", owner_color)

func _player_controls_attacking_army() -> bool:
	var gm = get_node("../../GameManager") as GameManager
	if gm == null or attacking_army == null:
		return false
	return gm.is_player_human(attacking_army.get_player_id())

func _player_has_defending_army() -> bool:
	var gm = get_node("../../GameManager") as GameManager
	if gm == null or defending_region == null:
		return false
	for child in defending_region.get_children():
		if child is Army:
			var army_child := child as Army
			if army_child == attacking_army:
				continue
			if gm.is_player_human(army_child.get_player_id()):
				return true
	return false

func _player_has_army_in_battle() -> bool:
	return _player_controls_attacking_army() or _player_has_defending_army()

func _is_dual_human_battle() -> bool:
	if attacking_army == null or defending_region == null:
		return false
	var gm = get_node("../../GameManager") as GameManager
	if gm == null:
		return false
	var region_owner := gm.get_region_manager().get_region_owner(defending_region.get_region_id())
	return _player_controls_attacking_army() and region_owner != -1 and gm.is_player_human(region_owner)




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
