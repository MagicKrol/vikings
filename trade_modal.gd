extends Control
class_name TradeModal

const RESOURCE_TYPES := [
	ResourcesEnum.Type.FOOD,
	ResourcesEnum.Type.WOOD,
	ResourcesEnum.Type.STONE,
	ResourcesEnum.Type.IRON
]
const HOLD_DELAY_SECONDS: float = 0.5
const HOLD_INTERVAL_SECONDS: float = 1.0
const HOLD_STEP: int = 10

var ui_manager: UIManager
var player_manager: PlayerManagerNode
var trade_manager: TradeManager
var gold_value_label: Label
var close_button: Button
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
var _hold_active: bool = false
var _hold_resource_type: ResourcesEnum.Type = ResourcesEnum.Type.FOOD
var _hold_delta: int = 0
var _hold_is_buy: bool = true
var _hold_elapsed: float = 0.0
var _hold_interval_elapsed: float = 0.0
var _hold_after_delay_started: bool = false

func _ready() -> void:
	ui_manager = get_node("../UIManager") as UIManager
	player_manager = get_node("../../PlayerManager") as PlayerManagerNode
	game_manager = get_node("../../GameManager") as GameManager
	trade_manager = TradeManager.new(player_manager)
	gold_value_label = get_node("Trade/HBoxContainer/TotalSection/HBoxContainer/TotalGold") as Label
	close_button = get_node("Trade/HBoxContainer/TotalSection/HBoxContainer/Button") as Button
	_init_sections()
	_connect_buttons()
	_reset_trade_state()
	set_process(true)

func _process(delta: float) -> void:
	if not visible:
		return
	_process_hold(delta)

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
	_stop_hold()
	if ui_manager:
		ui_manager.set_modal_active(false)

func hide_for_ai_turn() -> void:
	hide_modal()

func set_allowed_for_turn(is_allowed: bool) -> void:
	allow_for_current_turn = is_allowed
	if not allow_for_current_turn:
		hide_modal()

func _init_sections() -> void:
	resource_sections[ResourcesEnum.Type.FOOD] = _build_section("Trade/HBoxContainer/Body/Units/FirstRow/Food")
	resource_sections[ResourcesEnum.Type.WOOD] = _build_section("Trade/HBoxContainer/Body/Units/FirstRow/Wood")
	resource_sections[ResourcesEnum.Type.STONE] = _build_section("Trade/HBoxContainer/Body/Units/SecondRow/Stone")
	resource_sections[ResourcesEnum.Type.IRON] = _build_section("Trade/HBoxContainer/Body/Units/SecondRow/Iron")

func _build_section(section_path: String) -> Dictionary:
	return {
		"owned_label": get_node(section_path + "/OwnedCount") as Label,
		"buy_count_label": get_node(section_path + "/BuyCount") as Label,
		"sell_count_label": get_node(section_path + "/SellCount") as Label,
		"price_buy_label": get_node(section_path + "/BuyPrice") as Label,
		"price_sell_label": get_node(section_path + "/SellPrice") as Label,
		"section_path": section_path,
		"buy_minus": get_node(section_path + "/BuyMinus") as TextureRect,
		"buy_plus": get_node(section_path + "/BuyPlus") as TextureRect,
		"sell_minus": get_node(section_path + "/SellMinus") as TextureRect,
		"sell_plus": get_node(section_path + "/SellPlus") as TextureRect,
		"buy_button": get_node(section_path + "/BuyButton") as Button,
		"sell_button": get_node(section_path + "/SellButton") as Button
	}

func _connect_buttons() -> void:
	close_button.pressed.connect(_on_close_pressed)
	for resource_type in RESOURCE_TYPES:
		_connect_resource_buttons(resource_type)

func _connect_resource_buttons(resource_type: ResourcesEnum.Type) -> void:
	var section: Dictionary = resource_sections[resource_type]
	(section["buy_minus"] as TextureRect).gui_input.connect(_on_buy_adjust_input.bind(resource_type, -1))
	(section["buy_plus"] as TextureRect).gui_input.connect(_on_buy_adjust_input.bind(resource_type, 1))
	(section["sell_minus"] as TextureRect).gui_input.connect(_on_sell_adjust_input.bind(resource_type, -1))
	(section["sell_plus"] as TextureRect).gui_input.connect(_on_sell_adjust_input.bind(resource_type, 1))
	(section["buy_button"] as Button).pressed.connect(_on_buy_button_pressed.bind(resource_type))
	(section["sell_button"] as Button).pressed.connect(_on_sell_button_pressed.bind(resource_type))

func _refresh_state() -> void:
	_reset_trade_state()
	_sync_base_state()
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
	pass

func _on_sell_pressed(resource_type: ResourcesEnum.Type, amount: int) -> void:
	pass

func _on_buy_adjust_input(event: InputEvent, resource_type: ResourcesEnum.Type, delta: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var step: int = HOLD_STEP if event.shift_pressed else 1
			_adjust_buy_amount(resource_type, delta * step)
			_start_hold(resource_type, delta, true)
		else:
			_stop_hold()

func _on_sell_adjust_input(event: InputEvent, resource_type: ResourcesEnum.Type, delta: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var step: int = HOLD_STEP if event.shift_pressed else 1
			_adjust_sell_amount(resource_type, delta * step)
			_start_hold(resource_type, delta, false)
		else:
			_stop_hold()

func _adjust_buy_amount(resource_type: ResourcesEnum.Type, delta: int) -> void:
	if delta == 0:
		return
	if sell_amounts.get(resource_type, 0) > 0:
		sell_amounts[resource_type] = 0
	var current_buy: int = buy_amounts.get(resource_type, 0)
	if delta > 0:
		var available_gold = _get_gold_balance()
		var affordable = _calculate_affordable_buy(resource_type, delta, available_gold)
		if affordable <= 0:
			return
		buy_amounts[resource_type] = current_buy + affordable
	else:
		var new_buy = max(0, current_buy + delta)
		buy_amounts[resource_type] = new_buy
	_update_after_change(resource_type)

func _adjust_sell_amount(resource_type: ResourcesEnum.Type, delta: int) -> void:
	if delta == 0:
		return
	if buy_amounts.get(resource_type, 0) > 0:
		buy_amounts[resource_type] = 0
	var current_sell: int = sell_amounts.get(resource_type, 0)
	if delta > 0:
		var available_to_sell = _get_current_resource_total(resource_type)
		var applied = min(delta, available_to_sell)
		if applied <= 0:
			return
		sell_amounts[resource_type] = current_sell + applied
	else:
		var new_sell = max(0, current_sell + delta)
		sell_amounts[resource_type] = new_sell
	_update_after_change(resource_type)

func _start_hold(resource_type: ResourcesEnum.Type, delta: int, is_buy: bool) -> void:
	_hold_active = true
	_hold_resource_type = resource_type
	_hold_delta = delta
	_hold_is_buy = is_buy
	_hold_elapsed = 0.0
	_hold_interval_elapsed = 0.0
	_hold_after_delay_started = false

func _stop_hold() -> void:
	_hold_active = false
	_hold_elapsed = 0.0
	_hold_interval_elapsed = 0.0
	_hold_after_delay_started = false

func _process_hold(delta: float) -> void:
	if not _hold_active:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_stop_hold()
		return
	_hold_elapsed += delta
	if _hold_elapsed < HOLD_DELAY_SECONDS:
		return
	if not _hold_after_delay_started:
		_hold_after_delay_started = true
		_hold_interval_elapsed = 0.0
		_apply_hold_step()
		return
	_hold_interval_elapsed += delta
	while _hold_interval_elapsed >= HOLD_INTERVAL_SECONDS:
		_hold_interval_elapsed -= HOLD_INTERVAL_SECONDS
		_apply_hold_step()

func _apply_hold_step() -> void:
	if _hold_is_buy:
		_adjust_buy_amount(_hold_resource_type, _hold_delta * HOLD_STEP)
	else:
		_adjust_sell_amount(_hold_resource_type, _hold_delta * HOLD_STEP)

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
	(section["owned_label"] as Label).text = str(total_amount)
	(section["buy_count_label"] as Label).text = str(buy_amounts.get(resource_type, 0))
	(section["sell_count_label"] as Label).text = str(sell_amounts.get(resource_type, 0))
	_set_label_color(section["owned_label"] as Label, total_amount - base_resources.get(resource_type, 0), false, total_amount)

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
	_set_label_color(gold_value_label, gold_after_trades - base_gold, true, gold_after_trades)

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

func _on_buy_button_pressed(resource_type: ResourcesEnum.Type) -> void:
	var amount: int = buy_amounts.get(resource_type, 0)
	if amount <= 0:
		return
	var result = trade_manager.buy(player_manager.current_player_id, resource_type, amount)
	if not result.get("success", false):
		return
	buy_amounts[resource_type] = 0
	_sync_base_state()
	_update_all_displays()

func _on_sell_button_pressed(resource_type: ResourcesEnum.Type) -> void:
	var amount: int = sell_amounts.get(resource_type, 0)
	if amount <= 0:
		return
	var result = trade_manager.sell(player_manager.current_player_id, resource_type, amount)
	if not result.get("success", false):
		return
	sell_amounts[resource_type] = 0
	_sync_base_state()
	_update_all_displays()

func _sync_base_state() -> void:
	var player = player_manager.get_current_player()
	base_gold = player.get_resource_amount(ResourcesEnum.Type.GOLD)
	for resource_type in RESOURCE_TYPES:
		base_resources[resource_type] = player.get_resource_amount(resource_type)

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

func _on_close_pressed() -> void:
	hide_modal()
