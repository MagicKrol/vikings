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

var attacking_army: Army
var defending_region: Region

var ui_manager: UIManager
var game_manager: GameManager
var sound_manager: SoundManager
var player_manager: PlayerManagerNode

const LADDER_DATA = {"points": 1, "wood": 2, "defense": 2, "max": 10}
const RAM_DATA = {"points": 4, "wood": 5, "defense": 5, "max": 2}
const TREB_DATA = {"points": 10, "wood": 10, "defense": 15, "max": 99}

var siege_points_total: int = 0
var siege_points_spent: int = 0
var siege_counts: Dictionary = {"ladders": 0, "rams": 0, "trebuchets": 0}
var _pending_ladder_damage: int = 0

func _ready():
	region_label = get_node("Panel/Army/Header/Region")
	attacker_label = get_node("Panel/Army/HeaderSection/HBoxContainer/AttackerName")
	defender_label = get_node("Panel/Army/HeaderSection/HBoxContainer/DefenderName")
	attacker_vigor_label = get_node("Panel/Army/HeaderSection/Status/AttackerVigorValue")
	defender_vigor_label = get_node("Panel/Army/HeaderSection/Status/DefenderVigorValue")
	defense_value_label = get_node("Panel/Army/HeaderSection/HBoxContainer2/DefenderDefenseValue")
	withdraw_button = get_node("Panel/Army/WithdrawSection/HBoxContainer/Button")
	attack_button = get_node("Panel/Army/AttackSection/HBoxContainer/Button")
	estimate_text_label = get_node("Panel/Army/TextSection2/Total/EstimateText")
	estimate_range_label = get_node("Panel/Army/EstimateSection/Total/Estimate")
	siege_available = get_node("Panel/Army/SiegeSection/Available")
	siege_not_available = get_node("Panel/Army/SiegeSection/Notavailable")
	siege_points_text = get_node("Panel/Army/SiegeSection/SiegeText/PointsText")
	siege_points_value = get_node("Panel/Army/SiegeSection/SiegeText/PointsValue")
	ladders_count_label = get_node("Panel/Army/SiegeSection/Available/Ladders/HiredRecruits")
	rams_count_label = get_node("Panel/Army/SiegeSection/Available/BatteringRams/HiredRecruits")
	treb_count_label = get_node("Panel/Army/SiegeSection/Available/Trebuchets/HiredRecruits")
	ladders_plus = get_node("Panel/Army/SiegeSection/Available/Ladders/Button1")
	ladders_minus = get_node("Panel/Army/SiegeSection/Available/Ladders/Button1m")
	rams_plus = get_node("Panel/Army/SiegeSection/Available/BatteringRams/Button1")
	rams_minus = get_node("Panel/Army/SiegeSection/Available/BatteringRams/Button1m")
	treb_plus = get_node("Panel/Army/SiegeSection/Available/Trebuchets/Button1")
	treb_minus = get_node("Panel/Army/SiegeSection/Available/Trebuchets/Button1m")
	game_manager = get_node("../../GameManager") as GameManager
	ui_manager = get_node("../UIManager") as UIManager
	sound_manager = get_node("../../SoundManager") as SoundManager
	player_manager = game_manager.player_manager
	withdraw_button.pressed.connect(_on_withdraw_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	ladders_plus.pressed.connect(func(): _adjust_siege_equipment("ladders", 1))
	ladders_minus.pressed.connect(func(): _adjust_siege_equipment("ladders", -1))
	rams_plus.pressed.connect(func(): _adjust_siege_equipment("rams", 1))
	rams_minus.pressed.connect(func(): _adjust_siege_equipment("rams", -1))
	treb_plus.pressed.connect(func(): _adjust_siege_equipment("trebuchets", 1))
	treb_minus.pressed.connect(func(): _adjust_siege_equipment("trebuchets", -1))
	visible = false

func show_prebattle(army: Army, region: Region) -> void:
	attacking_army = army
	defending_region = region
	_update_labels()
	ui_manager.set_modal_active(true)
	visible = true

func hide_prebattle() -> void:
	visible = false
	ui_manager.set_modal_active(false)

func is_showing_for(army: Army, region: Region) -> bool:
	return visible and attacking_army == army and defending_region == region

func _update_labels() -> void:
	region_label.text = "Battle for " + defending_region.get_region_name()
	attacker_label.text = "Army " + str(attacking_army.number) + " (Player " + str(attacking_army.get_player_id()) + ")"
	attacker_vigor_label.text = str(attacking_army.get_efficiency()) + "%"
	defender_label.text = defending_region.get_region_name() + " defenders"
	defender_vigor_label.text = "100%"
	var defense_bonus = GameParameters.get_castle_defense_bonus(defending_region.get_castle_type())
	defense_value_label.text = str(defense_bonus) + "%"
	_update_siege_visibility(defense_bonus)
	_reset_siege_state()
	_update_estimate()

func _update_siege_visibility(defense_bonus: int) -> void:
	var show_siege := defense_bonus > 0
	if show_siege:
		siege_available.visible = true
		siege_not_available.visible = false
		siege_points_text.visible = true
		siege_points_value.visible = true
	else:
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
		range_text = "More than " + str(min_val) + " soldiers."
	elif min_val == 0:
		range_text = "Less than " + str(max_val) + " soldiers."
	else:
		range_text = "Between " + str(min_val) + " and " + str(max_val) + " soldiers."
	estimate_range_label.text = range_text
	estimate_text_label.text = threshold["description"]

func _reset_siege_state() -> void:
	siege_counts = {"ladders": 0, "rams": 0, "trebuchets": 0}
	siege_points_spent = 0
	siege_points_total = _calculate_siege_points()
	_pending_ladder_damage = 0
	_refresh_siege_ui()

func _calculate_siege_points() -> int:
	return int(attacking_army.get_total_soldiers() / 10)

func _adjust_siege_equipment(kind: String, delta: int) -> void:
	if not siege_available.visible:
		return
	var data = _get_siege_data(kind)
	if data.is_empty() or delta == 0:
		return
	var current_count: int = siege_counts.get(kind, 0)
	if delta > 0:
		if current_count >= data["max"]:
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
	if player_manager == null:
		return false
	return player_manager.get_resource_amount(ResourcesEnum.Type.WOOD) >= cost

func _spend_wood(cost: int) -> bool:
	if player_manager == null:
		return false
	var ok = player_manager.spend_resource(ResourcesEnum.Type.WOOD, cost)
	if ok:
		_update_player_status_modal()
	return ok

func _refund_wood(amount: int) -> void:
	if player_manager == null:
		return
	var player_id = player_manager.current_player_id
	if player_manager.add_resources_to_player(player_id, ResourcesEnum.Type.WOOD, amount):
		_update_player_status_modal()

func _can_reduce_defense(reduction: int) -> bool:
	var base_defense = _get_base_defense()
	var min_defense = _get_min_defense()
	var new_defense = base_defense - (_get_structural_damage() + _get_total_defense_reduction() + reduction)
	return new_defense >= min_defense

func _get_base_defense() -> int:
	return GameParameters.get_castle_defense_bonus(defending_region.get_castle_type())

func _get_min_defense() -> int:
	return GameParameters.CASTLE_DEFENSE_BONUSES_MIN.get(defending_region.get_castle_type(), 0)

func _get_total_defense_reduction() -> int:
	return siege_counts.get("ladders", 0) * LADDER_DATA["defense"] + siege_counts.get("rams", 0) * RAM_DATA["defense"] + siege_counts.get("trebuchets", 0) * TREB_DATA["defense"]

func _get_structural_damage() -> int:
	return defending_region.gate_damage + defending_region.wall_damage

func _update_defense_value() -> void:
	var base_defense = _get_base_defense()
	var min_defense = _get_min_defense()
	var effective = max(min_defense, base_defense - _get_structural_damage() - _get_total_defense_reduction())
	defense_value_label.text = str(effective) + "%"
	defense_value_label.remove_theme_color_override("font_color")
	if base_defense > 0:
		if min_defense > 0 and effective <= min_defense:
			defense_value_label.add_theme_color_override("font_color", Color.html("#d13131"))
		elif effective < base_defense:
			defense_value_label.add_theme_color_override("font_color", GameParameters.UI_COLOR_WOUNDED)
	else:
		defense_value_label.add_theme_color_override("font_color", Color.WHITE)

func _refresh_siege_ui() -> void:
	siege_points_value.text = str(_get_remaining_points())
	ladders_count_label.text = str(siege_counts.get("ladders", 0))
	rams_count_label.text = str(siege_counts.get("rams", 0))
	treb_count_label.text = str(siege_counts.get("trebuchets", 0))
	_update_defense_value()
	_update_siege_buttons()

func _update_siege_buttons() -> void:
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
	if siege_counts.get(kind, 0) >= data["max"]:
		return false
	if not _has_enough_points(data["points"]):
		return false
	if not _can_spend_wood(data["wood"]):
		return false
	return _can_reduce_defense(data["defense"])

func _refund_all_siege_purchases() -> void:
	var wood_refund = siege_counts.get("ladders", 0) * LADDER_DATA["wood"] + siege_counts.get("rams", 0) * RAM_DATA["wood"] + siege_counts.get("trebuchets", 0) * TREB_DATA["wood"]
	if wood_refund > 0:
		_refund_wood(wood_refund)
	var points_refund = siege_counts.get("ladders", 0) * LADDER_DATA["points"] + siege_counts.get("rams", 0) * RAM_DATA["points"] + siege_counts.get("trebuchets", 0) * TREB_DATA["points"]
	if points_refund > 0:
		_refund_points(points_refund)
	_reset_siege_state()

func _apply_siege_damage_and_get_payload() -> Dictionary:
	var ladder_damage = siege_counts.get("ladders", 0) * LADDER_DATA["defense"]
	var gate_cap = 10
	var ram_damage = siege_counts.get("rams", 0) * RAM_DATA["defense"]
	var gate_room = max(0, gate_cap - defending_region.gate_damage)
	var gate_applied = min(gate_room, ram_damage)
	if gate_applied > 0:
		defending_region.gate_damage += gate_applied
	var base_defense = _get_base_defense()
	var min_defense = _get_min_defense()
	var wall_cap = max(0, base_defense - defending_region.gate_damage - min_defense)
	var trebs_damage = siege_counts.get("trebuchets", 0) * TREB_DATA["defense"]
	var wall_applied = min(wall_cap, trebs_damage)
	if wall_applied > 0:
		defending_region.wall_damage = min(wall_cap, defending_region.wall_damage + wall_applied)
	_pending_ladder_damage = ladder_damage
	return {"ladder_damage": ladder_damage}

func _update_player_status_modal() -> void:
	GlobalSignals.emit_signal("player_status_refresh_requested")

func _on_withdraw_pressed() -> void:
	sound_manager.click_sound()
	_refund_all_siege_purchases()
	hide_prebattle()
	await game_manager.handle_prebattle_withdraw(attacking_army)

func _on_attack_pressed() -> void:
	sound_manager.click_sound()
	var siege_payload = _apply_siege_damage_and_get_payload()
	hide_prebattle()
	game_manager.handle_prebattle_attack(attacking_army, defending_region, siege_payload)
