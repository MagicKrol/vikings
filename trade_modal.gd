extends Control
class_name TradeModal

const RESOURCE_TYPES := [
	ResourcesEnum.Type.FOOD,
	ResourcesEnum.Type.WOOD,
	ResourcesEnum.Type.STONE,
	ResourcesEnum.Type.IRON
]

var ui_manager: UIManager
var player_manager: PlayerManagerNode
var trade_manager: TradeManager
var gold_value_label: Label
var balance_gold_label: Label
var continue_button: Button
var cancel_button: Button
var game_manager: GameManager
var allow_for_current_turn: bool = true

var base_resources: Dictionary = {}
var buy_amounts: Dictionary = {}
var sell_amounts: Dictionary = {}
var base_gold: int = 0

var resource_sections: Dictionary = {}
var color_green := Color.html("#41b43e")
var color_red := Color.html("#d13131")
var color_yellow := Color.YELLOW
var color_white := Color.WHITE

func _ready() -> void:
	ui_manager = get_node("../UIManager") as UIManager
	player_manager = get_node("../../PlayerManager") as PlayerManagerNode
	game_manager = get_node("../../GameManager") as GameManager
	trade_manager = TradeManager.new(player_manager)
	gold_value_label = get_node("Panel/Army/AvailableRecruits/HBoxContainer/Value") as Label
	balance_gold_label = get_node("Panel/Army/TotalSection/HBoxContainer/TotalValue") as Label
	continue_button = get_node("Panel/Army/ButtonSection/HBoxContainer/Continue") as Button
	cancel_button = get_node("Panel/Army/ButtonSection/HBoxContainer/Cancel") as Button
	_init_sections()
	_connect_buttons()
	_reset_trade_state()

func show_modal() -> void:
	if not allow_for_current_turn:
		return
	if not game_manager.debug_mode and game_manager.is_player_computer(game_manager.get_current_player()):
		return
	_refresh_state()
	visible = true
	if ui_manager:
		ui_manager.set_modal_active(true)

func hide_modal() -> void:
	visible = false
	if ui_manager:
		ui_manager.set_modal_active(false)

func hide_for_ai_turn() -> void:
	hide_modal()

func set_allowed_for_turn(is_allowed: bool) -> void:
	allow_for_current_turn = is_allowed
	if not allow_for_current_turn:
		hide_modal()

func _init_sections() -> void:
	resource_sections[ResourcesEnum.Type.FOOD] = _build_section("Food", "FoodPrice")
	resource_sections[ResourcesEnum.Type.WOOD] = _build_section("Wood", "FoodPrice2")
	resource_sections[ResourcesEnum.Type.STONE] = _build_section("Stone", "FoodPrice3")
	resource_sections[ResourcesEnum.Type.IRON] = _build_section("Iron", "FoodPrice4")

func _build_section(section_name: String, price_container_name: String) -> Dictionary:
	var section_path = "Panel/Army/UnitsSection/" + section_name
	var price_path = "Panel/Army/UnitsSection/" + price_container_name
	return {
		"value_label": get_node(section_path + "/Value") as Label,
		"buy_label": get_node(section_path + "/Buy") as Label,
		"sell_label": get_node(section_path + "/Sell") as Label,
		"price_buy_label": get_node(price_path + "/Buy") as Label,
		"price_sell_label": get_node(price_path + "/Sell") as Label,
		"section_path": section_path,
		"buy_buttons": [
			{"button": get_node(section_path + "/Button100") as Button, "amount": 100},
			{"button": get_node(section_path + "/Button10") as Button, "amount": 10},
			{"button": get_node(section_path + "/Button1") as Button, "amount": 1}
		],
		"sell_buttons": [
			{"button": get_node(section_path + "/Button1m") as Button, "amount": 1},
			{"button": get_node(section_path + "/Button10m") as Button, "amount": 10},
			{"button": get_node(section_path + "/Button100m") as Button, "amount": 100}
		]
	}

func _connect_buttons() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	_connect_resource_buttons(ResourcesEnum.Type.FOOD)
	_connect_resource_buttons(ResourcesEnum.Type.WOOD)
	_connect_resource_buttons(ResourcesEnum.Type.STONE)
	_connect_resource_buttons(ResourcesEnum.Type.IRON)

func _connect_resource_buttons(resource_type: ResourcesEnum.Type) -> void:
	var section: Dictionary = resource_sections[resource_type]
	for buy_entry in section["buy_buttons"]:
		(buy_entry["button"] as Button).pressed.connect(_on_buy_pressed.bind(resource_type, buy_entry["amount"]))
	for sell_entry in section["sell_buttons"]:
		(sell_entry["button"] as Button).pressed.connect(_on_sell_pressed.bind(resource_type, sell_entry["amount"]))

func _refresh_state() -> void:
	_reset_trade_state()
	var player = player_manager.get_current_player()
	base_gold = player.get_resource_amount(ResourcesEnum.Type.GOLD)
	for resource_type in RESOURCE_TYPES:
		base_resources[resource_type] = player.get_resource_amount(resource_type)
	_update_all_displays()

func _reset_trade_state() -> void:
	base_gold = 0
	base_resources.clear()
	buy_amounts.clear()
	sell_amounts.clear()
	for resource_type in RESOURCE_TYPES:
		buy_amounts[resource_type] = 0
		sell_amounts[resource_type] = 0

func _on_buy_pressed(resource_type: ResourcesEnum.Type, amount: int) -> void:
	var remaining = amount
	var current_sell = sell_amounts.get(resource_type, 0)
	if current_sell > 0:
		var canceled = min(current_sell, remaining)
		sell_amounts[resource_type] -= canceled
		remaining -= canceled
	if remaining > 0:
		var available_gold = _get_gold_balance()
		var affordable = _calculate_affordable_buy(resource_type, remaining, available_gold)
		if affordable > 0:
			buy_amounts[resource_type] += affordable
	_update_after_change(resource_type)

func _on_sell_pressed(resource_type: ResourcesEnum.Type, amount: int) -> void:
	var remaining = amount
	var current_buy = buy_amounts.get(resource_type, 0)
	if current_buy > 0:
		var canceled = min(current_buy, remaining)
		buy_amounts[resource_type] -= canceled
		remaining -= canceled
	if remaining > 0:
		var available_to_sell = _get_current_resource_total(resource_type)
		var applied = min(remaining, available_to_sell)
		if applied > 0:
			sell_amounts[resource_type] += applied
	_update_after_change(resource_type)

func _update_after_change(resource_type: ResourcesEnum.Type) -> void:
	_update_price_display(resource_type)
	_update_resource_display(resource_type)
	_update_gold_display()

func _update_all_displays() -> void:
	for resource_type in RESOURCE_TYPES:
		_update_price_display(resource_type)
		_update_resource_display(resource_type)
	_update_gold_display()

func _update_resource_display(resource_type: ResourcesEnum.Type) -> void:
	var total_amount = _get_current_resource_total(resource_type)
	var section: Dictionary = resource_sections[resource_type]
	(section["value_label"] as Label).text = str(total_amount)
	(section["buy_label"] as Label).text = str(buy_amounts.get(resource_type, 0))
	(section["sell_label"] as Label).text = str(sell_amounts.get(resource_type, 0))
	_set_label_color(section["value_label"] as Label, total_amount - base_resources.get(resource_type, 0), false, total_amount)

func _update_price_display(resource_type: ResourcesEnum.Type) -> void:
	var section: Dictionary = resource_sections[resource_type]
	var player_id = player_manager.current_player_id
	var staged_net = _get_staged_net(resource_type)
	var effective = trade_manager.get_effective_traded_amount(player_id, resource_type, staged_net)
	var buy_price = trade_manager.get_buy_unit_price(resource_type, max(0, effective))
	var sell_price = trade_manager.get_sell_unit_price(resource_type, max(0, -effective))
	(section["price_buy_label"] as Label).text = _format_price(buy_price)
	(section["price_sell_label"] as Label).text = _format_price(sell_price)

func _update_gold_display() -> void:
	var gold_after_trades = _get_gold_balance()
	gold_value_label.text = str(gold_after_trades)
	var balance = gold_after_trades - base_gold
	balance_gold_label.text = str(balance)
	_set_label_color(balance_gold_label, balance, true, gold_after_trades)

func _get_gold_balance() -> int:
	return base_gold - _get_total_buy_cost() + _get_total_sell_income()

func _get_total_buy_cost() -> int:
	return trade_manager.calculate_total_buy_cost(player_manager.current_player_id, buy_amounts, sell_amounts)

func _get_total_sell_income() -> int:
	return trade_manager.calculate_total_sell_income(player_manager.current_player_id, buy_amounts, sell_amounts)

func _get_current_resource_total(resource_type: ResourcesEnum.Type) -> int:
	return base_resources.get(resource_type, 0) + buy_amounts.get(resource_type, 0) - sell_amounts.get(resource_type, 0)

func _get_effective_traded_amount(resource_type: ResourcesEnum.Type) -> int:
	return trade_manager.get_effective_traded_amount(player_manager.current_player_id, resource_type, _get_staged_net(resource_type))

func _get_staged_net(resource_type: ResourcesEnum.Type) -> int:
	return buy_amounts.get(resource_type, 0) - sell_amounts.get(resource_type, 0)

func _format_price(value: float) -> String:
	return "%0.1f" % value

func _calculate_affordable_buy(resource_type: ResourcesEnum.Type, requested: int, available_gold: int) -> int:
	var staged_net = _get_staged_net(resource_type)
	var player_id = player_manager.current_player_id
	for amount in range(requested, 0, -1):
		var incremental_cost = trade_manager.calculate_buy_cost(player_id, resource_type, staged_net, amount)
		if incremental_cost <= available_gold:
			return amount
	return 0

func _apply_trade() -> void:
	var result = trade_manager.apply_trade_batch(player_manager.current_player_id, buy_amounts, sell_amounts)
	if not result.get("success", false):
		return

func _set_label_color(label: Label, delta: int, balance: bool, current_total: int) -> void:
	if not balance:
		if current_total == 0:
			label.modulate = color_red
			return
		if delta > 0:
			label.modulate = color_green
			return
		if delta < 0:
			label.modulate = color_yellow
			return
		label.modulate = color_white
		return
	if delta > 0:
		label.modulate = color_green
	elif delta < 0:
		label.modulate = color_yellow
	else:
		label.modulate = color_white

func _on_continue_pressed() -> void:
	_apply_trade()
	hide_modal()

func _on_cancel_pressed() -> void:
	hide_modal()
