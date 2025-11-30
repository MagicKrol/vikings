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

var attacking_army: Army
var defending_region: Region

var ui_manager: UIManager
var game_manager: GameManager
var sound_manager: SoundManager

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
	game_manager = get_node("../../GameManager") as GameManager
	ui_manager = get_node("../UIManager") as UIManager
	sound_manager = get_node("../../SoundManager") as SoundManager
	withdraw_button.pressed.connect(_on_withdraw_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
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

func _on_withdraw_pressed() -> void:
	sound_manager.click_sound()
	hide_prebattle()
	await game_manager.handle_prebattle_withdraw(attacking_army)

func _on_attack_pressed() -> void:
	sound_manager.click_sound()
	hide_prebattle()
	game_manager.handle_prebattle_attack(attacking_army, defending_region)
