extends Control
class_name PrebattleModal

var region_label: Label
var attacker_label: Label
var defender_label: Label
var attacker_vigor_label: Label
var defender_vigor_label: Label
var defense_value_label: Label
var withdraw_button: Button
var attack_button: Button
var estimate_text_label: Label
var estimate_range_label: Label
var assault_value_label: Label
var siege_available: VBoxContainer
var siege_not_available: VBoxContainer
var siege_points_text: Label
var siege_points_value: Label
var ladders_count_label: Label
var rams_count_label: Label
var treb_count_label: Label
var ladders_plus: Button
var ladders_minus: Button
var rams_plus: Button
var rams_minus: Button
var treb_plus: Button
var treb_minus: Button
var message_label: Label
var battle_bottom_margin: MarginContainer

var siege_panel: Control
var walls_breached_value: Label
var walls_damaged_value: Label
var walls_intact_value: Label
var wall_sections_total_value: Label
var gate_rows: Array[Dictionary] = []
var gate_buttons_container: HBoxContainer
var siege_reserve_row: HBoxContainer
var siege_target_row: HBoxContainer
var ram_rows: Array[HBoxContainer] = []
var ram_reserve_label: Label

var info_panel: Control
var info_header_label: Label
var info_ladders_body: Label
var info_rams_body: Label
var info_trebuchet_body: Label
var info_body_map: Dictionary = {}

var attacking_army: Army
var defending_region: Region

var ui_manager: UIManager
var game_manager: GameManager
var sound_manager: SoundManager
var player_manager: PlayerManagerNode
var move_tooltip: MoveTooltip
var tutorial_manager: TutorialManager = null

const LADDER_DATA = {"points": 1, "wood": 0, "defense": 0, "max": 99, "effectiveness": GameParameters.LADDER_EFFECTIVENESS_PER}
const RAM_DATA = {"points": 2, "wood": 2, "defense": 0, "max": 99}
const TREB_DATA = {"points": 4, "wood": 5, "defense": 5, "max": 99}
const TREBUCHET_SHOTS: int = 4
const TREBUCHET_HIT_CHANCE: float = 0.5
const BOMBARD_TEXT := "Bombard"
const CONTINUE_TEXT := "Attack"
const BATTLE_BOTTOM_MARGIN_WITH_SIEGE_Y: float = 90.0
const BATTLE_BOTTOM_MARGIN_WITHOUT_SIEGE_Y: float = 118.0

var siege_points_total: int = 0
var siege_points_spent: int = 0
var siege_counts: Dictionary = {"ladders": 0, "rams": 0, "trebuchets": 0}
var bombard_performed: bool = false
var trebuchet_bombard_result: Dictionary = {}

func _ready():
	region_label = get_node("Battle/VBoxContainer/Header/Header")
	attacker_label = get_node("Battle/VBoxContainer/SubHeader/HBoxContainer/Target")
	defender_label = get_node("Battle/VBoxContainer/SubHeader/HBoxContainer/Source")
	attacker_vigor_label = get_node("Battle/VBoxContainer/Status/AttackerVigorValue")
	defender_vigor_label = get_node("Battle/VBoxContainer/Status/DefenderVigorValue")
	defense_value_label = get_node("Battle/VBoxContainer/HBoxContainer2/DefenderDefenseValue")
	assault_value_label = get_node("Battle/VBoxContainer/HBoxContainer2/AssaultValue")
	withdraw_button = get_node("Battle/VBoxContainer/AttackSection/HBoxContainer/WithdrawButton")
	attack_button = get_node("Battle/VBoxContainer/AttackSection/HBoxContainer/AttackButton")
	estimate_text_label = get_node("Battle/VBoxContainer/Body/TextSection2/Total/EstimateText")
	estimate_range_label = get_node("Battle/VBoxContainer/Body/EstimateSection/Total/Estimate")
	siege_available = get_node("Battle/VBoxContainer/Body/SiegeSection/Available")
	siege_not_available = get_node("Battle/VBoxContainer/Body/SiegeSection/Notavailable")
	siege_points_text = get_node("Battle/VBoxContainer/Body/SiegeSection/SiegeText/PointsText")
	siege_points_value = get_node("Battle/VBoxContainer/Body/SiegeSection/SiegeText/PointsValue")
	ladders_count_label = get_node("Battle/VBoxContainer/Body/SiegeSection/Available/Ladders/HiredRecruits")
	rams_count_label = get_node("Battle/VBoxContainer/Body/SiegeSection/Available/BatteringRams/HiredRecruits")
	treb_count_label = get_node("Battle/VBoxContainer/Body/SiegeSection/Available/Trebuchets/HiredRecruits")
	ladders_plus = get_node("Battle/VBoxContainer/Body/SiegeSection/Available/Ladders/Button1")
	ladders_minus = get_node("Battle/VBoxContainer/Body/SiegeSection/Available/Ladders/Button1m")
	rams_plus = get_node("Battle/VBoxContainer/Body/SiegeSection/Available/BatteringRams/Button1")
	rams_minus = get_node("Battle/VBoxContainer/Body/SiegeSection/Available/BatteringRams/Button1m")
	treb_plus = get_node("Battle/VBoxContainer/Body/SiegeSection/Available/Trebuchets/Button1")
	treb_minus = get_node("Battle/VBoxContainer/Body/SiegeSection/Available/Trebuchets/Button1m")
	message_label = get_node("Battle/VBoxContainer/MessageSection/HBoxContainer/Message")
	battle_bottom_margin = get_node("Battle/VBoxContainer/MarginContainer4") as MarginContainer
	game_manager = get_node("../../GameManager") as GameManager
	ui_manager = get_node("../UIManager") as UIManager
	sound_manager = get_node("../../SoundManager") as SoundManager
	player_manager = game_manager.player_manager
	move_tooltip = get_node("../MoveTooltip") as MoveTooltip
	if game_manager:
		tutorial_manager = game_manager.get_tutorial_manager()
	withdraw_button.pressed.connect(_on_withdraw_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	ladders_plus.pressed.connect(func(): _adjust_siege_equipment("ladders", 1))
	ladders_minus.pressed.connect(func(): _adjust_siege_equipment("ladders", -1))
	rams_plus.pressed.connect(func(): _adjust_siege_equipment("rams", 1))
	rams_minus.pressed.connect(func(): _adjust_siege_equipment("rams", -1))
	treb_plus.pressed.connect(func(): _adjust_siege_equipment("trebuchets", 1))
	treb_minus.pressed.connect(func(): _adjust_siege_equipment("trebuchets", -1))
	_setup_info_panel()
	_connect_info_signals()
	_setup_siege_status_nodes()
	if tutorial_manager != null:
		attack_button.name = "continue"
		attack_button.pressed.connect(func(): tutorial_manager.handle_ui_click("PrebattleModal/" + attack_button.name))
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if attack_button.disabled:
		return
	if _is_attack_hotkey(event):
		attack_button.emit_signal("pressed")
		get_viewport().set_input_as_handled()

func _is_attack_hotkey(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == KEY_SPACE

func _setup_info_panel() -> void:
	info_panel = get_node("Info")
	info_header_label = get_node("Info/Header/Name")
	info_ladders_body = get_node("Info/Body/Ladders")
	info_rams_body = get_node("Info/Body/SiegeRams")
	info_trebuchet_body = get_node("Info/Body/Trebuchet")
	info_ladders_body.text = tr("prebattle_info_ladders")
	info_rams_body.text = tr("prebattle_info_siege_rams")
	info_trebuchet_body.text = tr("prebattle_info_trebuchet")
	info_body_map = {
		"Ladders": info_ladders_body,
		"Siege Rams": info_rams_body,
		"Trebuchets": info_trebuchet_body
	}
	_reset_info_panel()

func _connect_info_signals() -> void:
	var ladders_row: HBoxContainer = get_node("Battle/VBoxContainer/Body/SiegeSection/Available/Ladders")
	var rams_row: HBoxContainer = get_node("Battle/VBoxContainer/Body/SiegeSection/Available/BatteringRams")
	var trebuchet_row: HBoxContainer = get_node("Battle/VBoxContainer/Body/SiegeSection/Available/Trebuchets")
	_connect_info_hover_group(ladders_row, ladders_plus, ladders_minus, "Ladders")
	_connect_info_hover_group(rams_row, rams_plus, rams_minus, "Siege Rams")
	_connect_info_hover_group(trebuchet_row, treb_plus, treb_minus, "Trebuchets")

func _connect_info_hover_group(container: Control, add_button: Button, remove_button: Button, label: String) -> void:
	container.mouse_entered.connect(func(): _show_info(label))
	container.mouse_exited.connect(_hide_info_panel)
	add_button.mouse_entered.connect(func(): _show_info(label))
	add_button.mouse_exited.connect(_hide_info_panel)
	remove_button.mouse_entered.connect(func(): _show_info(label))
	remove_button.mouse_exited.connect(_hide_info_panel)

func _setup_siege_status_nodes() -> void:
	siege_panel = get_node("Siege")
	var siege_body: Control = siege_panel.get_node("Body")
	walls_breached_value = siege_body.get_node("Breached/Value")
	walls_damaged_value = siege_body.get_node("Danaged/Value")
	walls_intact_value = siege_body.get_node("Intact/Value")
	wall_sections_total_value = siege_body.get_node("WallSections/Value")
	gate_rows.clear()
	ram_rows.clear()
	for i in range(1, 4):
		var row: HBoxContainer = siege_body.get_node("Gate" + str(i) + "Body/Gate" + str(i))
		var name_label: Label = row.get_node("Name")
		var value_label: Label = row.get_node("Value")
		var bar: ProgressBar = row.get_node("ProgressBar")
		gate_rows.append({"container": row, "name": name_label, "value": value_label, "bar": bar})
		row.visible = false
		var ram_row: HBoxContainer = siege_body.get_node("Gate" + str(i) + "Body/Ram" + str(i))
		ram_rows.append(ram_row)
		ram_row.visible = false
	siege_reserve_row = siege_body.get_node("Reserve")
	ram_reserve_label = siege_reserve_row.get_node("Value")
	gate_buttons_container = get_node("Siege/GatesSelector")
	gate_buttons_container.visible = false

func _show_info(label: String) -> void:
	_hide_all_info_bodies()
	info_header_label.text = label
	var body_label: Label = info_body_map[label]
	body_label.visible = true
	info_panel.visible = true

func _hide_info_panel() -> void:
	_reset_info_panel()

func _hide_all_info_bodies() -> void:
	for body_node in info_body_map.values():
		var body_label: Label = body_node
		body_label.visible = false

func _reset_info_panel() -> void:
	_hide_all_info_bodies()
	info_header_label.text = ""
	info_panel.visible = false

func _update_siege_status_panel() -> void:
	if defending_region == null or siege_panel == null:
		return
	var wall_state: Dictionary = defending_region.get_wall_state()
	var wall_sections: int = int(wall_state.get("wall_sections", 0))
	var destroyed: int = int(wall_state.get("destroyed_sections", 0))
	var damaged: int = int(wall_state.get("damaged_sections", 0))
	var intact: int = max(0, wall_sections - destroyed - damaged)
	wall_sections_total_value.text = str(wall_sections)
	walls_breached_value.text = str(destroyed)
	walls_damaged_value.text = str(damaged)
	walls_intact_value.text = str(intact)
	_update_gate_rows(defending_region.get_gate_state())

func _update_gate_rows(gate_state: Dictionary) -> void:
	var base_hp: int = int(gate_state.get("gate_hp", 0))
	var gate_values: Array = gate_state.get("gate_values", [])
	var gates: int = int(gate_state.get("gates", gate_values.size()))
	for i in range(gate_rows.size()):
		var row_data: Dictionary = gate_rows[i]
		var container: HBoxContainer = row_data["container"]
		var ram_row: HBoxContainer = ram_rows[i]
		if i < gates and base_hp > 0:
			container.visible = true
			var name_label: Label = row_data["name"]
			var value_label: Label = row_data["value"]
			var bar: ProgressBar = row_data["bar"]
			var current_hp: float = float(base_hp)
			if i < gate_values.size():
				current_hp = float(gate_values[i])
			name_label.text = tr("Gate %d") % (i + 1)
			var percent: int = int(round(float(current_hp) / float(base_hp) * 100.0))
			value_label.text = str(percent) + "%"
			bar.max_value = base_hp
			bar.value = current_hp
		else:
			container.visible = false
			ram_row.visible = false

func _update_ram_rows() -> void:
	if defending_region == null:
		return
	var gates: int = int(defending_region.get_gate_state().get("gates", 0))
	var ram_total: int = siege_counts.get("rams", 0)
	var visible_rams: int = min(ram_total, gates, ram_rows.size())
	for i in range(ram_rows.size()):
		ram_rows[i].visible = i < visible_rams
	var reserve: int = max(0, ram_total - visible_rams)
	ram_reserve_label.text = str(reserve)
	siege_reserve_row.visible = ram_total > 0

func show_prebattle(army: Army, region: Region) -> void:
	attacking_army = army
	defending_region = region
	var info_modal = get_node("../InfoModal") as InfoModal
	info_modal.hide_modal(false)
	move_tooltip.hide_tooltip()
	ui_manager.hide_region_tooltip()
	_reset_info_panel()
	_update_labels()
	ui_manager.set_modal_active(true)
	ui_manager.set_overlay_suppressed(true)
	visible = true

func hide_prebattle() -> void:
	visible = false
	ui_manager.set_modal_active(false)
	ui_manager.set_overlay_suppressed(false)
	_reset_info_panel()

func is_showing_for(army: Army, region: Region) -> bool:
	return visible and attacking_army == army and defending_region == region

func _update_labels() -> void:
	region_label.text = tr("Battle for %s") % defending_region.get_region_name()
	attacker_label.text = tr("Army %s (Player %d)") % [attacking_army.number, attacking_army.get_player_id()]
	attacker_vigor_label.text = str(GameParameters.get_battle_attacker_effective_vigor(attacking_army.get_efficiency(), defending_region.get_region_type())) + "%"
	defender_label.text = tr("%s defenders") % defending_region.get_region_name()
	defender_vigor_label.text = tr("100%")
	var defense_bonus = GameParameters.get_castle_defense_bonus(defending_region.get_castle_type())
	defense_value_label.text = str(defense_bonus) + "%"
	_update_assault_value()
	_update_siege_visibility(defense_bonus)
	_reset_siege_state()
	_update_estimate()

func _update_siege_visibility(defense_bonus: int) -> void:
	var show_siege := defense_bonus > 0
	if show_siege:
		battle_bottom_margin.custom_minimum_size = Vector2(0.0, BATTLE_BOTTOM_MARGIN_WITH_SIEGE_Y)
		if siege_panel:
			siege_panel.visible = true
		siege_available.visible = true
		siege_not_available.visible = false
		siege_points_text.visible = true
		siege_points_value.visible = true
	else:
		battle_bottom_margin.custom_minimum_size = Vector2(0.0, BATTLE_BOTTOM_MARGIN_WITHOUT_SIEGE_Y)
		if siege_panel:
			siege_panel.visible = false
		siege_available.visible = false
		siege_not_available.visible = true
		siege_points_text.visible = false
		siege_points_value.visible = false
		_reset_siege_state()

func _calculate_defender_total() -> int:
	var owner_id = game_manager.get_region_manager().get_region_owner(defending_region.get_region_id())
	var total = defending_region.get_garrison().get_total_soldiers()
	total += defending_region.get_base_available_recruits()
	for child in defending_region.get_children():
		if child is Army:
			var army := child as Army
			if army != attacking_army and army.get_player_id() == owner_id:
				total += army.get_total_soldiers()
	return total

func _update_estimate() -> void:
	var total_defenders = _calculate_defender_total()
	var threshold = GameParameters.get_scout_threshold_entry(total_defenders)
	var min_val: int = threshold["min"]
	var max_val: int = threshold["max"]
	var range_text := ""
	if max_val == -1:
		range_text = tr("More than %d soldiers.") % min_val
	elif min_val == 0:
		range_text = tr("Less than %d soldiers.") % max_val
	else:
		range_text = tr("Between %d and %d soldiers.") % [min_val, max_val]
	estimate_range_label.text = range_text
	estimate_text_label.text = tr(String(threshold["description"]))

func _reset_siege_state() -> void:
	siege_counts = {"ladders": 0, "rams": 0, "trebuchets": 0}
	siege_points_spent = 0
	siege_points_total = _calculate_siege_points()
	bombard_performed = false
	trebuchet_bombard_result = {}
	message_label.text = ""
	_refresh_siege_ui()

func _calculate_siege_points() -> int:
	if attacking_army == null:
		return 0
	return GameParameters.calculate_siege_points_for_composition(attacking_army.get_composition())

func _adjust_siege_equipment(kind: String, delta: int) -> void:
	if not siege_available.visible:
		return
	if bombard_performed and kind == "trebuchets":
		return
	var data = _get_siege_data(kind)
	if data.is_empty() or delta == 0:
		return
	var current_count: int = siege_counts.get(kind, 0)
	if delta > 0:
		if current_count >= data["max"]:
			return
		if kind == "ladders" and not _has_ladder_capacity_for(1):
			return
		if not _has_enough_points(data["points"]):
			return
		if not _can_spend_wood(data["wood"]):
			return
		if not _can_reduce_defense(data["defense"]):
			return
		if not _spend_points(data["points"]):
			return
		if not _spend_wood(data["wood"]):
			_refund_points(data["points"])
			return
		siege_counts[kind] = current_count + 1
	else:
		if current_count <= 0:
			return
		siege_counts[kind] = current_count - 1
		_refund_points(data["points"])
		_refund_wood(data["wood"])
	_refresh_siege_ui()

func _get_siege_data(kind: String) -> Dictionary:
	match kind:
		"ladders":
			return LADDER_DATA
		"rams":
			return RAM_DATA
		"trebuchets":
			return TREB_DATA
		_:
			return {}

func _has_enough_points(cost: int) -> bool:
	return _get_remaining_points() >= cost

func _get_remaining_points() -> int:
	return max(0, siege_points_total - siege_points_spent)

func _spend_points(cost: int) -> bool:
	if _get_remaining_points() < cost:
		return false
	siege_points_spent += cost
	return true

func _refund_points(amount: int) -> void:
	siege_points_spent = max(0, siege_points_spent - amount)

func _can_spend_wood(cost: int) -> bool:
	if cost <= 0:
		return true
	if player_manager == null:
		return false
	return cost <= _get_siege_wood_budget()

func _get_siege_wood_budget() -> int:
	var player = player_manager.get_player(attacking_army.get_player_id())
	if player == null:
		return 0
	var available: int = player.get_resource_amount(ResourcesEnum.Type.WOOD)
	return max(0, available)

func _spend_wood(cost: int) -> bool:
	if cost <= 0:
		return true
	if player_manager == null:
		return false
	var player_id := attacking_army.get_player_id() if attacking_army != null else player_manager.current_player_id
	var ok = player_manager.remove_resources_from_player(player_id, ResourcesEnum.Type.WOOD, cost)
	if ok:
		_update_player_status_modal()
	return ok

func _refund_wood(amount: int) -> void:
	if player_manager == null:
		return
	var player_id := attacking_army.get_player_id() if attacking_army != null else player_manager.current_player_id
	if player_manager.add_resources_to_player(player_id, ResourcesEnum.Type.WOOD, amount):
		_update_player_status_modal()

func _can_reduce_defense(reduction: int) -> bool:
	if reduction <= 0:
		return true
	var base_defense = _get_base_defense()
	var min_defense = _get_min_defense()
	var new_defense = base_defense - (_get_structural_damage() + _get_total_defense_reduction() + reduction)
	return new_defense >= min_defense

func _get_base_defense() -> int:
	return GameParameters.get_castle_defense_bonus(defending_region.get_castle_type())

func _get_min_defense() -> int:
	return GameParameters.CASTLE_DEFENSE_BONUSES_MIN.get(defending_region.get_castle_type(), 0)

func _calculate_wall_defense_penalty() -> int:
	var wall_state: Dictionary = defending_region.get_wall_state()
	var data: Dictionary = GameParameters.CASTLE_WALLS_GATES.get(defending_region.get_castle_type(), {})
	var per_section: int = int(data.get("trebuchet_damage_to_defense", 0))
	if per_section <= 0:
		return 0
	var destroyed: int = int(wall_state.get("destroyed_sections", 0))
	var damaged: int = int(wall_state.get("damaged_sections", 0))
	var destroyed_penalty: int = destroyed * per_section
	var damaged_penalty_per_section: int = int(round(float(per_section) * 0.5))
	var damaged_penalty: int = damaged * damaged_penalty_per_section
	return destroyed_penalty + damaged_penalty

func _get_total_defense_reduction() -> int:
	return _calculate_wall_defense_penalty()

func _get_structural_damage() -> int:
	return 0

func _update_defense_value() -> void:
	var base_defense: int = _get_base_defense()
	var reduction: int = _get_total_defense_reduction()
	var min_defense: int = _get_min_defense()
	var effective_defense: int = max(min_defense, base_defense - reduction)
	defense_value_label.text = str(effective_defense) + "%"
	defense_value_label.remove_theme_color_override("font_color")
	if base_defense > 0:
		if min_defense > 0 and effective_defense <= min_defense:
			defense_value_label.add_theme_color_override("font_color", Color.html("#d13131"))
		elif effective_defense < base_defense:
			defense_value_label.add_theme_color_override("font_color", GameParameters.UI_COLOR_WOUNDED)
		else:
			defense_value_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		defense_value_label.add_theme_color_override("font_color", Color.WHITE)

func _refresh_siege_ui() -> void:
	_recalculate_siege_points_total()
	siege_points_value.text = str(_get_remaining_points())
	ladders_count_label.text = str(siege_counts.get("ladders", 0))
	rams_count_label.text = str(siege_counts.get("rams", 0))
	treb_count_label.text = str(siege_counts.get("trebuchets", 0))
	_update_ram_rows()
	_update_assault_value()
	_update_defense_value()
	_update_siege_buttons()
	_update_attack_button_text()
	_update_siege_status_panel()
	_update_attack_button_state()

func _recalculate_siege_points_total() -> void:
	if attacking_army == null:
		return
	var fresh_total: int = GameParameters.calculate_siege_points_for_composition(attacking_army.get_composition())
	if fresh_total != siege_points_total:
		siege_points_total = fresh_total
		siege_points_spent = min(siege_points_spent, siege_points_total)

func _has_ladder_capacity_for(additional: int) -> bool:
	var bm := _get_battle_manager()
	var capacity := bm.compute_ladder_capacity(defending_region)
	return siege_counts.get("ladders", 0) + additional <= capacity

func _update_siege_buttons() -> void:
	if bombard_performed:
		ladders_plus.disabled = true
		rams_plus.disabled = true
		treb_plus.disabled = true
		ladders_minus.disabled = true
		rams_minus.disabled = true
		treb_minus.disabled = true
		return
	ladders_plus.disabled = not _can_purchase("ladders")
	rams_plus.disabled = not _can_purchase("rams")
	treb_plus.disabled = not _can_purchase("trebuchets")
	ladders_minus.disabled = siege_counts.get("ladders", 0) <= 0
	rams_minus.disabled = siege_counts.get("rams", 0) <= 0
	treb_minus.disabled = siege_counts.get("trebuchets", 0) <= 0

func _can_purchase(kind: String) -> bool:
	var data = _get_siege_data(kind)
	if data.is_empty():
		return false
	var max_allowed: int = int(data.get("max", 0))
	if max_allowed > 0 and siege_counts.get(kind, 0) >= max_allowed:
		return false
	if kind == "ladders" and not _has_ladder_capacity_for(1):
		return false
	if not _has_enough_points(data["points"]):
		return false
	if not _can_spend_wood(data["wood"]):
		return false
	return _can_reduce_defense(data["defense"])

func _refund_all_siege_purchases() -> void:
	if bombard_performed:
		_reset_siege_state()
		return
	var wood_refund = siege_counts.get("ladders", 0) * LADDER_DATA["wood"] + siege_counts.get("rams", 0) * RAM_DATA["wood"] + siege_counts.get("trebuchets", 0) * TREB_DATA["wood"]
	if wood_refund > 0:
		_refund_wood(wood_refund)
	var points_refund = siege_counts.get("ladders", 0) * LADDER_DATA["points"] + siege_counts.get("rams", 0) * RAM_DATA["points"] + siege_counts.get("trebuchets", 0) * TREB_DATA["points"]
	if points_refund > 0:
		_refund_points(points_refund)
	_reset_siege_state()

func _apply_siege_damage_and_get_payload() -> Dictionary:
	var apply_trebuchet_damage := not bombard_performed
	var payload := defending_region.apply_siege_damage(siege_counts, LADDER_DATA, RAM_DATA, TREB_DATA, apply_trebuchet_damage)
	var ladder_raw := _get_ladder_effectiveness_raw()
	var ladder_ratio := _calculate_ladder_effectiveness_ratio_from_raw(ladder_raw)
	var wall_ratio := _calculate_wall_effectiveness_ratio()
	var gate_ratio := _calculate_gate_effectiveness_ratio()
	var total_assault := clampf(ladder_ratio + wall_ratio + gate_ratio, 0.0, 1.0)
	payload["ladder_effectiveness_ratio"] = ladder_ratio
	payload["ladder_effectiveness_raw"] = ladder_raw
	payload["wall_effectiveness_ratio"] = wall_ratio
	payload["gate_effectiveness_ratio"] = gate_ratio
	payload["assault_ratio"] = total_assault
	payload["trebuchet_bombard"] = _get_bombard_payload()
	payload["siege_counts"] = siege_counts.duplicate()
	var gate_state: Dictionary = payload.get("gate_state", defending_region.get_gate_state())
	payload["siege_view_state"] = SiegePanel.build_state(defending_region, gate_state, int(siege_counts.get("rams", 0)))
	return payload

func _calculate_assault_effectiveness_ratio() -> float:
	if defending_region.get_castle_type() == CastleTypeEnum.Type.NONE:
		return 1.0
	var ladder_ratio := _calculate_ladder_effectiveness_ratio()
	var wall_ratio := _calculate_wall_effectiveness_ratio()
	var gate_ratio := _calculate_gate_effectiveness_ratio()
	return clampf(ladder_ratio + wall_ratio + gate_ratio, 0.0, 1.0)

func _calculate_ladder_effectiveness_ratio() -> float:
	if attacking_army == null:
		return 0.0
	var raw := _get_ladder_effectiveness_raw()
	return _calculate_ladder_effectiveness_ratio_from_raw(raw)

func _calculate_ladder_effectiveness_ratio_from_raw(raw: int) -> float:
	if raw <= 0:
		return 0.0
	var non_ranged := GameParameters.calculate_non_ranged_count(attacking_army.get_composition())
	if non_ranged <= 0:
		return 0.0
	return clampf(float(raw) / float(non_ranged), 0.0, 1.0)

func _calculate_wall_effectiveness_ratio() -> float:
	return _get_battle_manager().compute_wall_assault_ratio(defending_region, attacking_army.get_composition())

func _calculate_gate_effectiveness_ratio() -> float:
	return _get_battle_manager().compute_gate_assault_ratio(defending_region)

func _get_ladder_effectiveness_raw() -> int:
	var bm := _get_battle_manager()
	return bm.compute_ladder_effectiveness_raw(defending_region, siege_counts.get("ladders", 0))

func _update_assault_value() -> void:
	if assault_value_label == null:
		return
	var percent := int(round(_calculate_assault_effectiveness_ratio() * 100.0))
	assault_value_label.text = str(percent) + "%"

func _get_battle_manager() -> BattleManager:
	return game_manager.get_battle_manager()

func _update_player_status_modal() -> void:
	GlobalSignals.emit_signal("player_status_refresh_requested")

func _on_withdraw_pressed() -> void:
	sound_manager.click_sound()
	_refund_all_siege_purchases()
	hide_prebattle()
	await game_manager.handle_prebattle_withdraw(attacking_army)

func _on_attack_pressed() -> void:
	sound_manager.click_sound()
	if _should_bombard_first():
		_perform_trebuchet_bombard()
		return
	var siege_payload = _apply_siege_damage_and_get_payload()
	hide_prebattle()
	game_manager.handle_prebattle_attack(attacking_army, defending_region, siege_payload)

func _should_bombard_first() -> bool:
	return siege_counts.get("trebuchets", 0) > 0 and not bombard_performed and siege_available.visible

func _update_attack_button_text() -> void:
	if _should_bombard_first():
		attack_button.text = tr(BOMBARD_TEXT)
	else:
		attack_button.text = tr(CONTINUE_TEXT)

func _update_attack_button_state() -> void:
	if _should_bombard_first():
		attack_button.disabled = false
		return
	var ladders: int = siege_counts.get("ladders", 0)
	var rams: int = siege_counts.get("rams", 0)
	var assault_ratio: float = _calculate_assault_effectiveness_ratio()
	var allow_attack := ladders > 0 or rams > 0 or assault_ratio > 0.0
	attack_button.disabled = not allow_attack

func _perform_trebuchet_bombard() -> void:
	bombard_performed = true
	sound_manager.play_catapult_sound()
	var total_damage := _roll_trebuchet_damage()
	var breach_result: Dictionary = {}
	if total_damage > 0:
		breach_result = defending_region.apply_wall_section_damage(total_damage)
		_update_defense_value()
	else:
		breach_result = _get_wall_breach_snapshot()
	var destroyed_sections := int(breach_result.get("destroyed_sections", 0))
	var damaged_sections := int(breach_result.get("damaged_sections", 0))
	_update_bombard_message(destroyed_sections, damaged_sections)
	trebuchet_bombard_result = {
		"total_damage": total_damage,
		"destroyed_sections": destroyed_sections,
		"damaged_sections": damaged_sections,
		"section_damage": int(breach_result.get("section_damage", 0)),
		"wall_section_hp": int(breach_result.get("wall_section_hp", 0)),
		"wall_sections": int(breach_result.get("wall_sections", 0))
	}
	_update_attack_button_text()
	_update_siege_buttons()
	_update_assault_value()
	_update_siege_status_panel()
	_update_attack_button_state()

func _get_wall_breach_snapshot() -> Dictionary:
	var wall_state := defending_region.get_wall_state()
	return {
		"destroyed_sections": int(wall_state.get("destroyed_sections", 0)),
		"damaged_sections": int(wall_state.get("damaged_sections", 0)),
		"wall_section_hp": int(wall_state.get("wall_section_hp", 0)),
		"wall_sections": int(wall_state.get("wall_sections", 0)),
		"section_damage": int(wall_state.get("section_damage", 0))
	}

func _roll_trebuchet_damage() -> int:
	var treb_count: int = int(siege_counts.get("trebuchets", 0))
	var total_damage := 0
	for i in range(treb_count):
		for shot in range(TREBUCHET_SHOTS):
			if randf() <= TREBUCHET_HIT_CHANCE:
				total_damage += 1
	return total_damage

func _get_bombard_payload() -> Dictionary:
	if trebuchet_bombard_result.is_empty():
		var wall_state := defending_region.get_wall_state()
		return {
			"total_damage": 0,
			"destroyed_sections": int(wall_state.get("destroyed_sections", 0)),
			"damaged_sections": int(wall_state.get("damaged_sections", 0)),
			"section_damage": int(wall_state.get("section_damage", 0)),
			"wall_section_hp": int(wall_state.get("wall_section_hp", 0)),
			"wall_sections": int(wall_state.get("wall_sections", 0)),
			"wall_effectiveness_raw": _get_battle_manager().compute_wall_assault_raw(defending_region),
			"wall_effectiveness_ratio": _calculate_wall_effectiveness_ratio(),
			"gate_effectiveness_ratio": _calculate_gate_effectiveness_ratio(),
			"assault_ratio": _calculate_assault_effectiveness_ratio()
		}
	var wall_state := defending_region.get_wall_state()
	trebuchet_bombard_result["wall_section_hp"] = int(wall_state.get("wall_section_hp", 0))
	trebuchet_bombard_result["wall_sections"] = int(wall_state.get("wall_sections", 0))
	trebuchet_bombard_result["wall_effectiveness_raw"] = _get_battle_manager().compute_wall_assault_raw(defending_region)
	trebuchet_bombard_result["wall_effectiveness_ratio"] = _calculate_wall_effectiveness_ratio()
	trebuchet_bombard_result["gate_effectiveness_ratio"] = _calculate_gate_effectiveness_ratio()
	trebuchet_bombard_result["assault_ratio"] = _calculate_assault_effectiveness_ratio()
	return trebuchet_bombard_result

func _update_bombard_message(destroyed_sections: int, damaged_sections: int) -> void:
	message_label.text = tr("%d wall sections destroyed, %d damaged by trebuchets.") % [destroyed_sections, damaged_sections]
