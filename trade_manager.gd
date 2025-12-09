extends RefCounted
class_name TradeManager

const TRADE_RESOURCE_TYPES := [
	ResourcesEnum.Type.FOOD,
	ResourcesEnum.Type.WOOD,
	ResourcesEnum.Type.STONE,
	ResourcesEnum.Type.IRON
]

var player_manager: PlayerManagerNode

func _init(pm: PlayerManagerNode):
	player_manager = pm

func get_effective_traded_amount(player_id: int, resource_type: ResourcesEnum.Type, staged_net: int) -> int:
	return player_manager.get_traded_resource_amount(player_id, resource_type) + staged_net

func get_buy_unit_price(resource_type: ResourcesEnum.Type, total_quantity: int) -> float:
	var base_price = float(GameParameters.TRADE_PRICES.get(resource_type, {}).get("buy", 0))
	return _get_dynamic_unit_price(base_price, true, total_quantity)

func get_sell_unit_price(resource_type: ResourcesEnum.Type, total_quantity: int) -> float:
	var base_price = float(GameParameters.TRADE_PRICES.get(resource_type, {}).get("sell", 0))
	return _get_dynamic_unit_price(base_price, false, total_quantity)

func calculate_buy_cost(player_id: int, resource_type: ResourcesEnum.Type, current_staged_net: int, buy_amount: int) -> int:
	if buy_amount <= 0:
		return 0
	var effective_before = get_effective_traded_amount(player_id, resource_type, current_staged_net)
	var base_quantity = max(0, effective_before)
	var before_cost = _total_buy_cost(resource_type, base_quantity)
	var after_quantity = base_quantity + buy_amount
	var after_cost = _total_buy_cost(resource_type, after_quantity)
	return after_cost - before_cost

func calculate_sell_income(player_id: int, resource_type: ResourcesEnum.Type, current_staged_net: int, sell_amount: int) -> int:
	if sell_amount <= 0:
		return 0
	var effective_before = get_effective_traded_amount(player_id, resource_type, current_staged_net)
	var base_quantity = max(0, -effective_before)
	var before_income = _total_sell_income(resource_type, base_quantity)
	var after_quantity = base_quantity + sell_amount
	var after_income = _total_sell_income(resource_type, after_quantity)
	return after_income - before_income

func calculate_total_buy_cost(player_id: int, buy_amounts: Dictionary, sell_amounts: Dictionary) -> int:
	var total_cost = 0
	for resource_type in TRADE_RESOURCE_TYPES:
		var amount = int(buy_amounts.get(resource_type, 0))
		if amount <= 0:
			continue
		var staged_net = int(buy_amounts.get(resource_type, 0) - sell_amounts.get(resource_type, 0))
		var net_before = staged_net - amount
		total_cost += calculate_buy_cost(player_id, resource_type, net_before, amount)
	return total_cost

func calculate_total_sell_income(player_id: int, buy_amounts: Dictionary, sell_amounts: Dictionary) -> int:
	var total_income = 0
	for resource_type in TRADE_RESOURCE_TYPES:
		var amount = int(sell_amounts.get(resource_type, 0))
		if amount <= 0:
			continue
		var staged_net = int(buy_amounts.get(resource_type, 0) - sell_amounts.get(resource_type, 0))
		var net_before = staged_net + amount
		total_income += calculate_sell_income(player_id, resource_type, net_before, amount)
	return total_income

func buy(player_id: int, resource_type: ResourcesEnum.Type, amount: int) -> Dictionary:
	var player = player_manager.get_player(player_id)
	if player == null or amount <= 0:
		return {"success": false, "reason": "invalid_request"}
	var cost = calculate_buy_cost(player_id, resource_type, 0, amount)
	if cost <= 0:
		return {"success": false, "reason": "no_cost"}
	if player.get_resource_amount(ResourcesEnum.Type.GOLD) < cost:
		return {"success": false, "reason": "insufficient_gold", "cost": cost}
	player.remove_resources(ResourcesEnum.Type.GOLD, cost)
	player.add_resources(resource_type, amount)
	player.add_traded_resource_amount(resource_type, amount)
	player_manager.update_player_wealth_status(player_id)
	GlobalSignals.emit_signal("player_status_refresh_requested")
	return {"success": true, "gold_change": -cost, "amount": amount}

func sell(player_id: int, resource_type: ResourcesEnum.Type, amount: int) -> Dictionary:
	var player = player_manager.get_player(player_id)
	if player == null or amount <= 0:
		return {"success": false, "reason": "invalid_request"}
	var income = calculate_sell_income(player_id, resource_type, 0, amount)
	if income <= 0:
		return {"success": false, "reason": "no_income"}
	if player.get_resource_amount(resource_type) < amount:
		return {"success": false, "reason": "insufficient_resource"}
	player.remove_resources(resource_type, amount)
	player.add_resources(ResourcesEnum.Type.GOLD, income)
	player.add_traded_resource_amount(resource_type, -amount)
	player_manager.update_player_wealth_status(player_id)
	GlobalSignals.emit_signal("player_status_refresh_requested")
	return {"success": true, "gold_change": income, "amount": amount}

func apply_trade_batch(player_id: int, buy_amounts: Dictionary, sell_amounts: Dictionary) -> Dictionary:
	var player = player_manager.get_player(player_id)
	if player == null:
		return {"success": false, "reason": "invalid_player"}
	var total_buy_cost = calculate_total_buy_cost(player_id, buy_amounts, sell_amounts)
	var total_sell_income = calculate_total_sell_income(player_id, buy_amounts, sell_amounts)
	var gold_change = total_sell_income - total_buy_cost
	if gold_change < 0 and player.get_resource_amount(ResourcesEnum.Type.GOLD) < -gold_change:
		return {"success": false, "reason": "insufficient_gold"}
	for resource_type in TRADE_RESOURCE_TYPES:
		var buy_amount = int(buy_amounts.get(resource_type, 0))
		var sell_amount = int(sell_amounts.get(resource_type, 0))
		var available = player.get_resource_amount(resource_type) + buy_amount
		if available < sell_amount:
			return {"success": false, "reason": "insufficient_resource", "resource": resource_type}
	for resource_type in TRADE_RESOURCE_TYPES:
		var buy_amount = int(buy_amounts.get(resource_type, 0))
		var sell_amount = int(sell_amounts.get(resource_type, 0))
		if buy_amount > 0:
			player.add_resources(resource_type, buy_amount)
		if sell_amount > 0:
			player.remove_resources(resource_type, sell_amount)
		var net_change = buy_amount - sell_amount
		if net_change != 0:
			player.add_traded_resource_amount(resource_type, net_change)
	if gold_change > 0:
		player.add_resources(ResourcesEnum.Type.GOLD, gold_change)
	elif gold_change < 0:
		player.remove_resources(ResourcesEnum.Type.GOLD, -gold_change)
	player_manager.update_player_wealth_status(player_id)
	GlobalSignals.emit_signal("player_status_refresh_requested")
	return {"success": true, "gold_change": gold_change}

func _get_dynamic_unit_price(base_price: float, is_buy: bool, quantity: int) -> float:
	var min_price = GameParameters.TRADE_MARKET_MIN_PRICE
	var qty = max(0, quantity)
	if is_buy:
		return base_price + (base_price - min_price) * (1.0 - exp(-GameParameters.TRADE_MARKET_K * float(qty)))
	return min_price + (base_price - min_price) * exp(-GameParameters.TRADE_MARKET_K * float(qty))

func _total_buy_cost(resource_type: ResourcesEnum.Type, quantity: int) -> int:
	var unit_price = get_buy_unit_price(resource_type, quantity)
	return _round_value(unit_price * float(quantity))

func _total_sell_income(resource_type: ResourcesEnum.Type, quantity: int) -> int:
	var unit_price = get_sell_unit_price(resource_type, quantity)
	return _round_value(unit_price * float(quantity))

func _round_value(value: float) -> int:
	return int(floor(value + 0.5))
