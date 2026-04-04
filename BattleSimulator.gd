extends RefCounted
class_name BattleSimulator

# Unit stats now managed in GameParameters.gd

# Battle report structure
class BattleReport:
	var winner: String
	var rounds: int
	var attacker_losses: Dictionary
	var defender_losses: Dictionary
	var final_attacker: Dictionary
	var final_defender: Dictionary
	var attacker_wounded: Dictionary
	var defender_wounded: Dictionary
	var withdrawing_side: int
	var siege_payload: Dictionary
	var gate_plan_log: Array[String]
	
	func _init():
		attacker_losses = {}
		defender_losses = {}
		final_attacker = {}
		final_defender = {}
		attacker_wounded = {}
		defender_wounded = {}
		withdrawing_side = 0
		siege_payload = {}
		gate_plan_log = []

# Step-wise session container for animated battles
class BattleSession:
	var current_attackers: Dictionary
	var current_defenders: Dictionary
	var current_garrison: Dictionary
	var original_attackers: Dictionary
	var original_defenders: Dictionary
	var siege_state: Dictionary
	var siege_payload_base: Dictionary
	var attacker_efficiency: int
	var defender_efficiency: int
	var terrain_type: RegionTypeEnum.Type
	var castle_type: CastleTypeEnum.Type
	var castle_defense_override: int
	var attacker_can_withdraw: bool
	var defender_can_withdraw: bool
	var attacker_effectiveness_ratio: float
	var is_withdrawing: bool
	var withdrawing_side: int
	var withdrawal_rounds_remaining: int
	var mobility_withdrawal_rounds_remaining: int
	var current_round: int
	var max_rounds: int
	var is_battle_running: bool
	var is_siege_battle: bool
	var volley_done: bool
	var previous_power_ratio: float
	var losing_ratio_streak: int
	var ai_withdrawal_rules: Dictionary
	
	func _init():
		current_attackers = {}
		current_defenders = {}
		current_garrison = {}
		original_attackers = {}
		original_defenders = {}
		siege_state = {}
		siege_payload_base = {}
		attacker_efficiency = 100
		defender_efficiency = 100
		terrain_type = RegionTypeEnum.Type.GRASSLAND
		castle_type = CastleTypeEnum.Type.NONE
		castle_defense_override = -1
		attacker_can_withdraw = true
		defender_can_withdraw = false
		attacker_effectiveness_ratio = 0.0
		is_withdrawing = false
		withdrawing_side = 0
		withdrawal_rounds_remaining = 0
		mobility_withdrawal_rounds_remaining = 0
		current_round = 0
		max_rounds = 1000
		is_battle_running = false
		is_siege_battle = false
		volley_done = false
		previous_power_ratio = -1.0
		losing_ratio_streak = 0
		ai_withdrawal_rules = {}

func _calculate_non_ranged_from_dict(composition: Dictionary) -> int:
	var total := 0
	for unit_type in composition:
		var count: int = int(composition[unit_type])
		if count <= 0:
			continue
		if not GameParameters.unit_has_trait(unit_type, UnitTraitEnum.Type.UNIT_TRAIT_2):
			total += count
	return total

func _calculate_ranged_from_dict(composition: Dictionary) -> int:
	var total: int = 0
	for unit_type in composition:
		var count: int = int(composition[unit_type])
		if count <= 0:
			continue
		if GameParameters.unit_has_trait(unit_type, UnitTraitEnum.Type.UNIT_TRAIT_2):
			total += count
	return total

func _calculate_gate_ratio_from_raw(raw: int, attackers: Dictionary) -> float:
	if raw <= 0:
		return 0.0
	var non_ranged := _calculate_non_ranged_from_dict(attackers)
	if non_ranged <= 0:
		return 0.0
	return clampf(float(raw) / float(non_ranged), 0.0, 1.0)

func _calculate_gate_ratio_from_values(gate_hp: int, gate_values: Array, gates: int) -> float:
	if gate_hp <= 0 or gates <= 0:
		return 0.0
	var destroyed: int = 0
	for hp in gate_values:
		if float(hp) <= 0.01:
			destroyed += 1
	if gate_values.size() < gates:
		destroyed += gates - gate_values.size()
	return clampf(float(destroyed) / float(gates), 0.0, 1.0)

func _distribute_value_evenly(total: int, slots: int) -> Array[int]:
	if slots <= 0:
		return []
	var base_per_slot: int = int(total / slots)
	var remainder: int = total % slots
	var distribution: Array[int] = []
	for i in range(slots):
		var value: int = base_per_slot
		if i < remainder:
			value += 1
		distribution.append(value)
	return distribution

func _get_breach_chance_for_gate(ram_count: int, ranged_assigned: int) -> float:
	if ram_count <= 0:
		return 0.0
	var chance_table: Dictionary = GameParameters.GATE_BREACH_SUCCESS
	if chance_table.is_empty():
		return 0.0
	var sorted_buckets: Array = chance_table.keys()
	sorted_buckets.sort()
	var min_bucket: int = int(sorted_buckets[0])
	var max_bucket: int = int(sorted_buckets[sorted_buckets.size() - 1])
	if ranged_assigned < min_bucket:
		var base_chance: float = float(chance_table[min_bucket])
		return _scale_missing_archers_chance(base_chance, min_bucket, ranged_assigned)
	var chosen_bucket: int = min(ranged_assigned, max_bucket)
	for idx in range(sorted_buckets.size() - 1, -1, -1):
		var bucket_value: int = int(sorted_buckets[idx])
		if chosen_bucket >= bucket_value:
			return float(chance_table[bucket_value])
	return 0.0

func _get_archer_bucket(ram_count: int, ranged_assigned: int) -> int:
	if ram_count <= 0:
		return 0
	var chance_table: Dictionary = GameParameters.GATE_BREACH_SUCCESS
	if chance_table.is_empty():
		return 0
	var sorted_buckets: Array = chance_table.keys()
	sorted_buckets.sort()
	var min_bucket: int = int(sorted_buckets[0])
	var max_bucket: int = int(sorted_buckets[sorted_buckets.size() - 1])
	if ranged_assigned <= min_bucket:
		return min_bucket
	if ranged_assigned >= max_bucket:
		return max_bucket
	for idx in range(sorted_buckets.size() - 1, -1, -1):
		var bucket_value: int = int(sorted_buckets[idx])
		if ranged_assigned >= bucket_value:
			return bucket_value
	return min_bucket

func _scale_missing_archers_chance(base_chance: float, bucket: int, ranged_assigned: int) -> float:
	if bucket <= 0:
		return base_chance
	var shortage_ratio := clampf(1.0 - float(ranged_assigned) / float(bucket), 0.0, 1.0)
	return clampf(base_chance + (1.0 - base_chance) * shortage_ratio, 0.0, 1.0)

func _compute_progress_q(chance: float, roll: float) -> float:
	if chance <= 0.0:
		return 0.0
	if roll < chance:
		return 1.0
	if roll >= 1.0:
		return 0.0
	return 1.0 - ((roll - chance) / (1.0 - chance))

func _sum_ram_hp(queue: Array) -> float:
	var total: float = 0.0
	for hp in queue:
		total += float(hp)
	return total

func _format_ram_queue(queue: Array) -> String:
	var parts: Array[String] = []
	for hp in queue:
		parts.append(str(snappedf(float(hp), 0.01)))
	return "[" + ",".join(parts) + "]"

func _build_ram_damage_schedule(total_damage: float, turns: int) -> Array[float]:
	if turns <= 0 or total_damage <= 0.0:
		return []
	var weights: Array[float] = []
	var weight_sum: float = 0.0
	for i in range(1, turns + 1):
		var w := float(i)
		weights.append(w)
		weight_sum += w
	var schedule: Array[float] = []
	for w in weights:
		schedule.append(total_damage * (w / weight_sum))
	return schedule

func _get_ranged_for_gate(siege_state: Dictionary, gate_idx: int) -> int:
	var ranged_per_gate: Array = siege_state.get("ranged_per_gate", [])
	if gate_idx < ranged_per_gate.size():
		return int(ranged_per_gate[gate_idx])
	return 0

func _start_ram_plan_for_gate(siege_state: Dictionary, gate_idx: int, rng: RandomNumberGenerator) -> void:
	var gate_values: Array = siege_state.get("gate_values", [])
	if gate_idx < 0 or gate_idx >= gate_values.size():
		return
	var active_rams: Dictionary = siege_state.get("active_rams", {})
	if not active_rams.has(gate_idx):
		return
	var ram_hp: float = float(active_rams.get(gate_idx, 0.0))
	var gate_hp_current: float = float(gate_values[gate_idx])
	if gate_hp_current <= 0.0:
		return
	var ranged_assigned: int = _get_ranged_for_gate(siege_state, gate_idx)
	var archers_bucket: int = _get_archer_bucket(1, ranged_assigned)
	var chance: float = 0.0
	if archers_bucket > 0:
		chance = _get_breach_chance_for_gate(1, ranged_assigned)
	var roll: float = rng.randf()
	var turns_to_breach: int = rng.randi_range(int(ceil(gate_hp_current)), int(ceil(gate_hp_current)) + 2)
	var progress_q: float = 0.0
	if turns_to_breach > 0:
		progress_q = _compute_progress_q(chance, roll)
	var gate_damage_per_turn: float = 0.0
	if progress_q > 0.0 and turns_to_breach > 0:
		var base_gate_hp: float = float(siege_state.get("gate_hp", gate_hp_current))
		var gate_damage_total: float = base_gate_hp * progress_q
		gate_damage_per_turn = gate_damage_total / float(turns_to_breach)
	var ram_loss_fraction: float = 1.0
	if chance > 0.0 and roll < chance:
		ram_loss_fraction = clampf(roll / chance, 0.0, 1.0)
	var ram_damage_total: float = ram_hp * ram_loss_fraction
	var ram_damage_schedule: Array[float] = _build_ram_damage_schedule(ram_damage_total, turns_to_breach)
	var plan := {
		"chance": chance,
		"roll": roll,
		"progress_q": progress_q,
		"turns_to_breach": turns_to_breach,
		"turns_elapsed": 0,
		"gate_damage_per_turn": gate_damage_per_turn,
		"ram_damage_schedule": ram_damage_schedule,
		"archer_bucket": archers_bucket,
		"ranged_assigned": ranged_assigned,
		"ram_loss_fraction": ram_loss_fraction,
		"ram_hp_start": ram_hp,
		"gate_hp_start": gate_hp_current
	}
	var gate_plans: Dictionary = siege_state.get("gate_plans", {})
	var active_plan_by_gate: Dictionary = siege_state.get("active_plan_by_gate", {})
	if gate_plans.has(gate_idx):
		gate_plans[gate_idx].append(plan)
	else:
		gate_plans[gate_idx] = [plan]
	active_plan_by_gate[gate_idx] = plan
	siege_state["gate_plans"] = gate_plans
	siege_state["active_plan_by_gate"] = active_plan_by_gate
	DebugLogger.log("siege", "[Plan] gate=" + str(gate_idx + 1) + " P=" + str(snappedf(chance, 0.001)) + " roll=" + str(snappedf(roll, 0.001)) + " q=" + str(snappedf(progress_q, 0.001)) + " T=" + str(turns_to_breach) + " gate_dpt=" + str(snappedf(gate_damage_per_turn, 0.001)) + " ram_hp=" + str(snappedf(ram_hp, 0.01)) + " ram_frac=" + str(snappedf(ram_loss_fraction, 0.001)))

func _init_siege_state_from_payload(siege_payload: Dictionary, attackers: Dictionary, defenders: Dictionary = {}, rng: RandomNumberGenerator = null) -> Dictionary:
	if siege_payload.is_empty():
		DebugLogger.log("BattleCalculation", "[Siege] No siege payload provided.")
		return {}
	var local_rng: RandomNumberGenerator = rng
	if local_rng == null:
		local_rng = RandomNumberGenerator.new()
		local_rng.randomize()
	var gate_state: Dictionary = siege_payload.get("gate_state", {})
	var gate_hp: int = int(gate_state.get("gate_hp", 0))
	var gate_values_raw: Array = gate_state.get("gate_values", [])
	var gates: int = int(gate_state.get("gates", gate_values_raw.size()))
	var gate_values: Array[float] = []
	if gate_values_raw.is_empty() and gates > 0 and gate_hp > 0:
		for i in range(gates):
			gate_values.append(float(gate_hp))
	else:
		for i in range(gate_values_raw.size()):
			gate_values.append(float(gate_values_raw[i]))
		if gates > gate_values.size():
			for i in range(gate_values.size(), gates):
				gate_values.append(float(gate_hp))
	var siege_counts: Dictionary = siege_payload.get("siege_counts", {})
	var total_rams: int = int(siege_counts.get("rams", 0))
	var ladder_ratio := float(siege_payload.get("ladder_effectiveness_ratio", -1.0))
	if ladder_ratio < 0.0:
		var ladder_raw: int = int(siege_payload.get("ladder_effectiveness_raw", 0))
		if ladder_raw > 0:
			ladder_ratio = _calculate_gate_ratio_from_raw(ladder_raw, attackers)
		else:
			ladder_ratio = 0.0
	var wall_ratio := clampf(float(siege_payload.get("wall_effectiveness_ratio", 0.0)), 0.0, 1.0)
	var ranged_total: int = _calculate_ranged_from_dict(defenders)
	var ranged_per_gate: Array[int] = _distribute_value_evenly(ranged_total, gates)
	var gate_plans: Dictionary = {}
	var active_plan_by_gate: Dictionary = {}
	var active_rams: Dictionary = {}
	var reserve_rams: Array[float] = []
	var assignable: int = min(total_rams, gates)
	for i in range(assignable):
		active_rams[i] = float(GameParameters.SIEGE_RAM_HP)
	for i in range(assignable, total_rams):
		reserve_rams.append(float(GameParameters.SIEGE_RAM_HP))
	for gate_idx in range(gates):
		gate_plans[gate_idx] = []
		active_plan_by_gate[gate_idx] = null
	return {
		"gate_hp": gate_hp,
		"gate_values": gate_values,
		"gates": gates,
		"total_rams": total_rams,
		"active_rams": active_rams,
		"reserve_rams": reserve_rams,
		"gate_plans": gate_plans,
		"active_plan_by_gate": active_plan_by_gate,
		"gate_assault_raw": 0,
		"ladder_ratio": clampf(ladder_ratio, 0.0, 1.0),
		"wall_ratio": wall_ratio,
		"ranged_per_gate": ranged_per_gate,
		"ram_damage_managed": true,
		"non_ranged_attackers": _calculate_non_ranged_from_dict(attackers)
	}

func _rebalance_active_rams(siege_state: Dictionary) -> void:
	var gate_values: Array = siege_state.get("gate_values", [])
	var active_rams: Dictionary = siege_state.get("active_rams", {})
	var reserve_rams: Array = siege_state.get("reserve_rams", [])
	for gate_idx in range(gate_values.size()):
		var gate_hp: float = float(gate_values[gate_idx])
		if gate_hp <= 0.0:
			if active_rams.has(gate_idx):
				var returning_hp: float = float(active_rams[gate_idx])
				if returning_hp > 0.0:
					reserve_rams.append(returning_hp)
				active_rams.erase(gate_idx)
			continue
		if active_rams.has(gate_idx):
			continue
		if reserve_rams.is_empty():
			continue
		var next_hp: float = float(reserve_rams.pop_back())
		active_rams[gate_idx] = next_hp
	siege_state["active_rams"] = active_rams
	siege_state["reserve_rams"] = reserve_rams
	siege_state["total_rams"] = active_rams.size() + reserve_rams.size()
	DebugLogger.log("BattleCalculation", "[Siege] Rams assigned: active=" + str(_get_active_ram_count(siege_state)) + ", reserve=" + str(_get_reserve_ram_count(siege_state)))

func _get_active_ram_count(siege_state: Dictionary) -> int:
	return int(siege_state.get("active_rams", {}).size())

func _get_reserve_ram_count(siege_state: Dictionary) -> int:
	return int(siege_state.get("reserve_rams", []).size())

func _apply_ram_damage(siege_state: Dictionary, hits: int, rng: RandomNumberGenerator) -> void:
	if hits <= 0:
		return
	_rebalance_active_rams(siege_state)
	var active_rams: Dictionary = siege_state.get("active_rams", {})
	var active_keys: Array = active_rams.keys()
	if active_keys.is_empty():
		return
	var destroyed: int = 0
	for i in range(hits):
		if active_keys.is_empty():
			break
		var idx: int = int(active_keys[rng.randi() % active_keys.size()])
		var current_hp: float = float(active_rams.get(idx, 0.0)) - 1.0
		if current_hp <= 0.0:
			active_rams.erase(idx)
			siege_state["total_rams"] = max(0, int(siege_state.get("total_rams", 0)) - 1)
			destroyed += 1
		else:
			active_rams[idx] = current_hp
		active_keys = active_rams.keys()
	siege_state["active_rams"] = active_rams
	_rebalance_active_rams(siege_state)
	var active_after: int = _get_active_ram_count(siege_state)
	var reserve_after: int = _get_reserve_ram_count(siege_state)
	DebugLogger.log("BattleCalculation", "[Siege] Rams took " + str(hits) + " hits, destroyed=" + str(destroyed) + ", active=" + str(active_after) + ", reserve=" + str(reserve_after))

func _allocate_hits_to_rams(hits: int, target_army: Dictionary, siege_state: Dictionary, rng: RandomNumberGenerator) -> int:
	if hits <= 0:
		return 0
	if siege_state.get("ram_damage_managed", false):
		return 0
	var active_rams: int = _get_active_ram_count(siege_state)
	if active_rams <= 0:
		DebugLogger.log("BattleCalculation", "[Siege] Ram targeting skipped: no active rams, hits=" + str(hits))
		return 0
	var focus_cap: int = active_rams * GameParameters.SIEGE_RAM_FOCUS_RANGED
	var ram_hits: int = min(hits, focus_cap)
	DebugLogger.log("BattleCalculation", "[Siege] Ram targeting: hits=" + str(hits) + ", ram_hits=" + str(ram_hits) + ", active_rams=" + str(active_rams) + ", focus_cap=" + str(focus_cap))
	if ram_hits <= 0:
		return 0
	_apply_ram_damage(siege_state, ram_hits, rng)
	return ram_hits

func _apply_structured_ram_damage(siege_state: Dictionary, gate_idx: int, damage: float) -> void:
	if damage <= 0.0:
		return
	var active_rams: Dictionary = siege_state.get("active_rams", {})
	if not active_rams.has(gate_idx):
		return
	var current_hp: float = float(active_rams.get(gate_idx, 0.0))
	var remaining: float = damage
	var new_hp: float = current_hp - remaining
	if new_hp <= 0.01:
		remaining = max(0.0, -new_hp)
		active_rams.erase(gate_idx)
		siege_state["total_rams"] = max(0, int(siege_state.get("total_rams", 0)) - 1)
	else:
		active_rams[gate_idx] = new_hp
	siege_state["active_rams"] = active_rams
	_rebalance_active_rams(siege_state)

func _process_siege_ram_attacks(siege_state: Dictionary, rng: RandomNumberGenerator) -> void:
	if siege_state.is_empty():
		return
	var gate_values: Array = siege_state.get("gate_values", [])
	var gate_plans: Dictionary = siege_state.get("gate_plans", {})
	var active_plan_by_gate: Dictionary = siege_state.get("active_plan_by_gate", {})
	var active_rams: Dictionary = siege_state.get("active_rams", {})
	_rebalance_active_rams(siege_state)
	for gate_idx in range(gate_values.size()):
		if float(gate_values[gate_idx]) <= 0.0:
			active_plan_by_gate[gate_idx] = {}
			continue
		if not active_rams.has(gate_idx):
			active_plan_by_gate[gate_idx] = {}
			continue
		var plan = active_plan_by_gate.get(gate_idx, {})
		if plan == null or plan.is_empty():
			_start_ram_plan_for_gate(siege_state, gate_idx, rng)
			plan = active_plan_by_gate.get(gate_idx, {})
			if plan == null or plan.is_empty():
				DebugLogger.log("siege", "[PlanMiss] gate=" + str(gate_idx + 1) + " active_ram=" + str(snappedf(float(active_rams.get(gate_idx, 0.0)), 0.01)))
				continue
		var turns_to_breach: int = int(plan.get("turns_to_breach", 0))
		if turns_to_breach <= 0:
			active_plan_by_gate[gate_idx] = {}
			continue
		var turns_elapsed: int = int(plan.get("turns_elapsed", 0))
		if turns_elapsed >= turns_to_breach:
			active_plan_by_gate[gate_idx] = {}
			continue
		var gate_hp_before: float = float(gate_values[gate_idx])
		var ram_hp_before: float = float(active_rams.get(gate_idx, 0.0))
		turns_elapsed += 1
		plan["turns_elapsed"] = turns_elapsed
		var gate_hp_after: float = gate_hp_before
		var damage_per_turn: float = float(plan.get("gate_damage_per_turn", 0.0))
		if damage_per_turn > 0.0:
			gate_values[gate_idx] = max(0.0, gate_hp_after - damage_per_turn)
			gate_hp_after = float(gate_values[gate_idx])
		var ram_dmg_log: float = 0.0
		var ram_schedule: Array = plan.get("ram_damage_schedule", [])
		if turns_elapsed - 1 < ram_schedule.size():
			ram_dmg_log = float(ram_schedule[turns_elapsed - 1])
			if ram_dmg_log > 0.0:
				_apply_structured_ram_damage(siege_state, gate_idx, ram_dmg_log)
		var ram_hp_after: float = float(siege_state.get("active_rams", {}).get(gate_idx, 0.0))
		var gate_dpt_log: float = damage_per_turn
		DebugLogger.log("siege", "[Tick] gate=" + str(gate_idx + 1) + " turn=" + str(turns_elapsed) + "/" + str(turns_to_breach) + " gate_hp " + str(snappedf(gate_hp_before, 0.01)) + "->" + str(snappedf(gate_hp_after, 0.01)) + " gate_dmg=" + str(snappedf(gate_dpt_log, 0.01)) + " ram_dmg=" + str(snappedf(ram_dmg_log, 0.01)) + " ram_hp " + str(snappedf(ram_hp_before, 0.01)) + "->" + str(snappedf(ram_hp_after, 0.01)))
		if gate_hp_before > 0.0 and gate_hp_after <= 0.01:
			var current_raw: int = int(siege_state.get("gate_assault_raw", 0))
			siege_state["gate_assault_raw"] = current_raw + 5
			DebugLogger.log("siege", "[GateRaw] instant +5 (gate down) raw_before=" + str(current_raw) + " raw_after=" + str(siege_state["gate_assault_raw"]))
			if siege_state.get("active_rams", {}).has(gate_idx):
				var return_hp: float = float(siege_state.get("active_rams", {}).get(gate_idx, 0.0))
				siege_state["reserve_rams"].append(return_hp)
				siege_state["active_rams"].erase(gate_idx)
		if turns_elapsed >= turns_to_breach or not siege_state.get("active_rams", {}).has(gate_idx) or gate_hp_after <= 0.0:
			active_plan_by_gate[gate_idx] = {}
		else:
			active_plan_by_gate[gate_idx] = plan
	siege_state["gate_values"] = gate_values
	siege_state["active_plan_by_gate"] = active_plan_by_gate
	_rebalance_active_rams(siege_state)

func _count_destroyed_gates(gate_values: Array) -> int:
	var destroyed := 0
	for hp in gate_values:
		if float(hp) <= 0.01:
			destroyed += 1
	return destroyed

func _increment_gate_assault_raw(siege_state: Dictionary) -> void:
	var gate_values: Array = siege_state.get("gate_values", [])
	var destroyed := _count_destroyed_gates(gate_values)
	var current_raw: int = int(siege_state.get("gate_assault_raw", 0))
	var added := destroyed * 5
	var new_raw: int = current_raw + added
	siege_state["gate_assault_raw"] = new_raw
	DebugLogger.log("siege", "[GateRaw] destroyed=" + str(destroyed) + " added=" + str(added) + " raw_before=" + str(current_raw) + " raw_after=" + str(new_raw))

func _calculate_siege_assault_ratio(siege_state: Dictionary, attackers: Dictionary) -> float:
	if siege_state.is_empty():
		return 0.0
	var ladder_ratio := float(siege_state.get("ladder_ratio", 0.0))
	var wall_ratio := float(siege_state.get("wall_ratio", 0.0))
	var gate_raw: int = int(siege_state.get("gate_assault_raw", 0))
	var non_ranged := _calculate_non_ranged_from_dict(attackers)
	var gate_ratio_raw := _calculate_gate_ratio_from_raw(gate_raw, attackers)
	var gate_ratio := gate_ratio_raw
	var total := clampf(ladder_ratio + wall_ratio + gate_ratio, 0.0, 1.0)
	DebugLogger.log("siege", "[Assault] ladder=" + str(snappedf(ladder_ratio, 0.01)) + " wall=" + str(snappedf(wall_ratio, 0.01)) + " gate_raw=" + str(gate_raw) + " non_ranged=" + str(non_ranged) + " gate_ratio=" + str(snappedf(gate_ratio, 0.01)) + " total=" + str(snappedf(total, 0.01)))
	return total

func _build_gate_state_payload(siege_state: Dictionary) -> Dictionary:
	if siege_state.is_empty():
		return {}
	var gates: int = int(siege_state.get("gates", 0))
	var ram_hp_array: Array = []
	var active_rams: Dictionary = siege_state.get("active_rams", {})
	for i in range(gates):
		ram_hp_array.append(int(ceil(float(active_rams.get(i, 0.0)))))
	return {
		"gate_hp": int(siege_state.get("gate_hp", 0)),
		"gates": int(siege_state.get("gates", 0)),
		"gate_values": (siege_state.get("gate_values", []) as Array).duplicate(),
		"ram_hp": ram_hp_array,
		"ram_hp_max": GameParameters.SIEGE_RAM_HP,
		"reserve_rams": _get_reserve_ram_count(siege_state),
		"active_rams": _get_active_ram_count(siege_state)
	}

func _build_siege_payload_output(siege_state: Dictionary, original_payload: Dictionary, attackers: Dictionary) -> Dictionary:
	if siege_state.is_empty():
		return original_payload
	var output := original_payload.duplicate(true)
	output["gate_state"] = _build_gate_state_payload(siege_state)
	var gate_hp: int = int(siege_state.get("gate_hp", 0))
	var gates: int = int(siege_state.get("gates", 0))
	var gate_values: Array = siege_state.get("gate_values", [])
	var gate_raw: int = int(siege_state.get("gate_assault_raw", 0))
	output["gate_assault_raw"] = gate_raw
	output["gate_effectiveness_ratio"] = _calculate_gate_ratio_from_raw(gate_raw, attackers)
	output["assault_ratio"] = _calculate_siege_assault_ratio(siege_state, attackers)
	return output

func _build_gate_plan_log_lines(siege_state: Dictionary, battle_label: String) -> Array[String]:
	if siege_state.is_empty():
		return []
	var gate_plans: Dictionary = siege_state.get("gate_plans", {})
	if gate_plans.is_empty():
		return []
	var gate_values: Array = siege_state.get("gate_values", [])
	var keys: Array = gate_plans.keys()
	keys.sort()
	var lines: Array[String] = []
	var header: String = "Siege breach rolls"
	if battle_label != "":
		header += " - " + battle_label
	lines.append(header)
	for gate_key in keys:
		var idx: int = int(gate_key)
		var plan_list: Array = gate_plans[gate_key]
		if plan_list.is_empty():
			continue
		lines.append("Gate %d: " % (idx + 1))
		var gate_hp_value: float = float(siege_state.get("gate_hp", 0))
		if idx < gate_values.size():
			gate_hp_value = float(gate_values[idx])
		for i in range(plan_list.size()):
			var plan: Dictionary = plan_list[i]
			var chance: float = float(plan.get("chance", 0.0))
			var roll: float = float(plan.get("roll", 0.0))
			var chance_pct: int = int(round(chance * 100.0))
			var roll_pct: int = int(round(roll * 100.0))
			var turns: int = int(plan.get("turns_to_breach", 0))
			var gate_dpt: float = float(plan.get("gate_damage_per_turn", 0.0))
			var ram_schedule: Array = plan.get("ram_damage_schedule", [])
			var ram_total_loss: float = 0.0
			for dmg in ram_schedule:
				ram_total_loss += float(dmg)
			var ram_dpt: float = 0.0
			if turns > 0:
				ram_dpt = ram_total_loss / float(turns)
			var bucket: int = int(plan.get("archer_bucket", 0))
			var progress_q: float = float(plan.get("progress_q", 0.0))
			var ranged_assigned: int = int(plan.get("ranged_assigned", 0))
			lines.append("  Ram %d: ranged %d (bucket %d), roll %d/%d, turns %d, q=%.2f, gate_dpt=%.2f (hp=%.1f), ram_dpt=%.2f" % [
				i + 1,
				ranged_assigned,
				bucket,
				roll_pct,
				chance_pct,
				turns,
				progress_q,
				gate_dpt,
				gate_hp_value,
				ram_dpt
			])
	lines.append("")
	return lines

# Main battle function - accepts arrays of compositions for each side
func simulate_battle(attacking_armies: Array, defending_armies: Array, region_garrison: ArmyComposition = null, attacker_efficiency: int = 100, defender_efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE, attacker_label: String = "Attackers", defender_label: String = "Defenders", attacker_can_withdraw: bool = false, defender_can_withdraw: bool = false, castle_defense_bonus_override: int = -1, attacker_effectiveness_ratio: float = 0.0, siege_payload: Dictionary = {}, ai_log: AILogManager = null, ai_log_label: String = "", ai_withdrawal_rules: Dictionary = {}) -> BattleReport:
	"""
	Simulate a battle between multiple armies and defenders
	attacking_armies: Array of ArmyComposition objects
	defending_armies: Array of ArmyComposition objects  
	region_garrison: ArmyComposition of the region's garrison (optional)
	attacker_efficiency: Efficiency percentage for attacking armies (affects hit chances)
	defender_efficiency: Efficiency percentage for defending armies (affects hit chances, garrison always 100%)
	terrain_type: Terrain type of the region being fought over (affects terrain bonuses)
	castle_type: Castle type in the region (affects charge bonuses)
	"""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var is_siege_battle := castle_type != CastleTypeEnum.Type.NONE
	
	# Merge all attacking forces
	var merged_attackers = _merge_compositions(attacking_armies)
	
	# Merge all defending forces (including garrison)
	var all_defenders = defending_armies.duplicate()
	if region_garrison != null and not region_garrison.is_empty():
		all_defenders.append(region_garrison)
	var merged_defenders = _merge_compositions(all_defenders)
	var current_garrison = _create_garrison_composition(region_garrison)
	var attacker_stats := {}
	var defender_stats := {}
	var siege_state: Dictionary = {}
	var report = BattleReport.new()
	report.siege_payload = siege_payload
	
	# Store original compositions for loss calculation
	var original_attackers = _copy_composition_dict(merged_attackers)
	var original_defenders = _copy_composition_dict(merged_defenders)
	if is_siege_battle and not siege_payload.is_empty():
		siege_state = _init_siege_state_from_payload(siege_payload, merged_attackers, merged_defenders, rng)
		_rebalance_active_rams(siege_state)
		report.gate_plan_log = _build_gate_plan_log_lines(siege_state, ai_log_label)
		attacker_effectiveness_ratio = _calculate_siege_assault_ratio(siege_state, merged_attackers)
		DebugLogger.log("BattleCalculation", "[Siege] Init siege state: total_rams=" + str(int(siege_state.get("total_rams", 0))) + ", active=" + str(_get_active_ram_count(siege_state)) + ", reserve=" + str(_get_reserve_ram_count(siege_state)))
	else:
		DebugLogger.log("BattleCalculation", "[Siege] No siege state: is_siege_battle=" + str(is_siege_battle) + ", payload_empty=" + str(siege_payload.is_empty()))
	var attacker_effectiveness_value := attacker_effectiveness_ratio if is_siege_battle else 0.0
	var defender_effectiveness_value := 0.0 if is_siege_battle and attacker_effectiveness_value <= 0.0 else -1.0
	if DebugLogger.is_category_enabled("BattleCalculation") or DebugLogger.is_category_enabled("BattleSystem"):
		DebugLogger.log("BattleCalculation", "Assault effectiveness ratio=" + str(snappedf(attacker_effectiveness_value * 100.0, 0.1)) + "% (applied to non-ranged attackers)")
	
	var rounds = 0
	var max_rounds = 1000
	var withdrawal_tracker: Dictionary = {
		"previous_power_ratio": -1.0,
		"losing_ratio_streak": 0
	}
	
	# Ranged opening volley - both sides shoot simultaneously before main battle
	var attacker_ranged_kills = _process_ranged_unit_attacks(merged_attackers, merged_defenders, rng, attacker_efficiency, terrain_type, castle_type, attacker_stats, castle_defense_bonus_override, is_siege_battle, siege_state, false)
	var defender_ranged_kills = {}
	
	# Process garrison ranged attacks at 100% efficiency if garrison exists
	if not current_garrison.is_empty():
		var garrison_ranged_kills = _process_ranged_unit_attacks(current_garrison, merged_attackers, rng, 100, terrain_type, CastleTypeEnum.Type.NONE, defender_stats, -1, is_siege_battle, siege_state, true)
		_merge_kill_results(defender_ranged_kills, garrison_ranged_kills)
	
	# Process defending army ranged attacks at their efficiency if any defending armies exist
	var ranged_armies_only := _compute_army_composition(merged_defenders, current_garrison)
	if not ranged_armies_only.is_empty():
		var army_ranged_kills = _process_ranged_unit_attacks(ranged_armies_only, merged_attackers, rng, defender_efficiency, terrain_type, CastleTypeEnum.Type.NONE, defender_stats, -1, is_siege_battle, siege_state, true)
		_merge_kill_results(defender_ranged_kills, army_ranged_kills)
	
	# Apply ranged volley kills simultaneously
	_apply_kills(merged_defenders, attacker_ranged_kills)
	_apply_kills(merged_attackers, defender_ranged_kills)

	var withdraw_side = _decide_withdrawal(merged_attackers, merged_defenders, current_garrison, attacker_can_withdraw, defender_can_withdraw, castle_type, rng, rounds, attacker_effectiveness_ratio, siege_state, withdrawal_tracker, ai_withdrawal_rules)
	if withdraw_side != 0:
		var withdraw_rounds := _resolve_withdrawal_phase(merged_attackers, merged_defenders, current_garrison, attacker_efficiency, defender_efficiency, terrain_type, castle_type, rng, attacker_stats, defender_stats, withdraw_side, castle_defense_bonus_override, attacker_effectiveness_ratio, is_siege_battle, siege_state)
		rounds += withdraw_rounds
		var early_payload := _build_siege_payload_output(siege_state, siege_payload, merged_attackers)
		return _create_withdrawal_report(original_attackers, original_defenders, merged_attackers, merged_defenders, rounds, withdraw_side, early_payload)
	
	# Battle loop
	while _army_size(merged_attackers) > 0 and _army_size(merged_defenders) > 0 and rounds < max_rounds:
		rounds += 1
		var attacker_snapshot := _copy_composition_dict(merged_attackers)
		var defender_snapshot := _copy_composition_dict(merged_defenders)
		var attacker_hit_log := {}
		var attacker_hit_totals = null
		if DebugLogger.is_category_enabled("BattleCalculation"):
			attacker_hit_totals = _new_hit_totals()
		
		# Attack phases - unit-by-unit with trait-based targeting
		if is_siege_battle and not siege_state.is_empty():
			_process_siege_ram_attacks(siege_state, rng)
			_increment_gate_assault_raw(siege_state)
			attacker_effectiveness_ratio = _calculate_siege_assault_ratio(siege_state, merged_attackers)
			attacker_effectiveness_value = attacker_effectiveness_ratio
		var attacker_kills = _process_unit_attacks(merged_attackers, merged_defenders, rng, attacker_efficiency, terrain_type, castle_type, attacker_hit_log, attacker_stats, castle_defense_bonus_override, attacker_effectiveness_value, is_siege_battle, attacker_hit_totals, siege_state, false)
		
		# Defense phase - separate garrison and army processing for defenders
		var defender_kills = {}
		var defender_hit_totals = null
		if DebugLogger.is_category_enabled("BattleCalculation"):
			defender_hit_totals = _new_hit_totals()
		var defender_hit_log := {}
		
		# Process garrison attacks at 100% efficiency if garrison exists
		if not current_garrison.is_empty():
			var garrison_kills = _process_unit_attacks(current_garrison, merged_attackers, rng, 100, terrain_type, CastleTypeEnum.Type.NONE, defender_hit_log, defender_stats, -1, defender_effectiveness_value, is_siege_battle, defender_hit_totals, siege_state, true)
			_merge_kill_results(defender_kills, garrison_kills)
		
		# Process defending army attacks at their efficiency if any defending armies exist
		var defender_armies_only := _compute_army_composition(merged_defenders, current_garrison)
		if not defender_armies_only.is_empty():
			var army_kills = _process_unit_attacks(defender_armies_only, merged_attackers, rng, defender_efficiency, terrain_type, CastleTypeEnum.Type.NONE, defender_hit_log, defender_stats, -1, defender_effectiveness_value, is_siege_battle, defender_hit_totals, siege_state, true)
			_merge_kill_results(defender_kills, army_kills)
		
		_log_battle_round_debug(rounds, attacker_label, defender_label, attacker_snapshot, defender_snapshot, attacker_hit_log, defender_hit_log, attacker_kills, defender_kills)
		if DebugLogger.is_category_enabled("BattleCalculation"):
			_log_round_totals(rounds, attacker_label, defender_label, attacker_hit_totals, defender_hit_totals, attacker_kills, defender_kills, attacker_snapshot, defender_snapshot)
		
		# Apply kills simultaneously
		_apply_kills(merged_defenders, attacker_kills)
		_apply_kills(merged_attackers, defender_kills)
		_deduct_garrison_losses_from_snapshot(attacker_kills, defender_snapshot, current_garrison)

		var mid_withdraw_side = _decide_withdrawal(merged_attackers, merged_defenders, current_garrison, attacker_can_withdraw, defender_can_withdraw, castle_type, rng, rounds, attacker_effectiveness_ratio, siege_state, withdrawal_tracker, ai_withdrawal_rules)
		if mid_withdraw_side != 0:
			var withdraw_extra_rounds := _resolve_withdrawal_phase(merged_attackers, merged_defenders, current_garrison, attacker_efficiency, defender_efficiency, terrain_type, castle_type, rng, attacker_stats, defender_stats, mid_withdraw_side, castle_defense_bonus_override, attacker_effectiveness_ratio, is_siege_battle, siege_state)
			rounds += withdraw_extra_rounds
			var withdraw_payload := _build_siege_payload_output(siege_state, siege_payload, merged_attackers)
			return _create_withdrawal_report(original_attackers, original_defenders, merged_attackers, merged_defenders, rounds, mid_withdraw_side, withdraw_payload)
	
	# Determine winner
	var attacker_size = _army_size(merged_attackers)
	var defender_size = _army_size(merged_defenders)
	
	if attacker_size > 0 and defender_size == 0:
		report.winner = "Attackers"
	elif defender_size > 0 and attacker_size == 0:
		report.winner = "Defenders"
	else:
		report.winner = "Draw"
	
	# Calculate losses
	report.rounds = rounds
	report.attacker_losses = _calculate_losses(original_attackers, merged_attackers)
	report.defender_losses = _calculate_losses(original_defenders, merged_defenders)
	report.final_attacker = merged_attackers
	report.final_defender = merged_defenders
	report.siege_payload = _build_siege_payload_output(siege_state, siege_payload, merged_attackers)
	_log_effectiveness_stats(attacker_label + " Stats", attacker_stats)
	_log_effectiveness_stats(defender_label + " Stats", defender_stats)
	
	return report

func start_battle_session(attacking_armies: Array, defending_armies: Array, region_garrison: ArmyComposition = null, attacker_efficiency: int = 100, defender_efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE, attacker_can_withdraw: bool = true, defender_can_withdraw: bool = false, castle_defense_bonus_override: int = -1, attacker_effectiveness_ratio: float = 0.0, siege_payload: Dictionary = {}, ai_withdrawal_rules: Dictionary = {}) -> BattleSession:
	var session := BattleSession.new()
	session.attacker_efficiency = attacker_efficiency
	session.defender_efficiency = defender_efficiency
	session.terrain_type = terrain_type
	session.castle_type = castle_type
	session.castle_defense_override = castle_defense_bonus_override
	session.attacker_can_withdraw = attacker_can_withdraw
	session.defender_can_withdraw = defender_can_withdraw and castle_type == CastleTypeEnum.Type.NONE
	session.attacker_effectiveness_ratio = clampf(attacker_effectiveness_ratio, 0.0, 1.0)
	session.ai_withdrawal_rules = ai_withdrawal_rules.duplicate(true)
	session.is_siege_battle = castle_type != CastleTypeEnum.Type.NONE
	session.siege_payload_base = siege_payload.duplicate(true)
	session.current_attackers = _merge_compositions(attacking_armies)
	var all_defenders := defending_armies.duplicate()
	if region_garrison != null and not region_garrison.is_empty():
		all_defenders.append(region_garrison)
	session.current_defenders = _merge_compositions(all_defenders)
	session.current_garrison = _create_garrison_composition(region_garrison)
	session.original_attackers = _copy_composition_dict(session.current_attackers)
	session.original_defenders = _copy_composition_dict(session.current_defenders)
	if session.is_siege_battle and not session.siege_payload_base.is_empty():
		session.siege_state = _init_siege_state_from_payload(session.siege_payload_base, session.current_attackers, session.current_defenders)
		_rebalance_active_rams(session.siege_state)
		session.attacker_effectiveness_ratio = _calculate_siege_assault_ratio(session.siege_state, session.current_attackers)
	session.is_battle_running = true
	return session

func process_opening_volley_session(session: BattleSession, rng: RandomNumberGenerator) -> Dictionary:
	var result := {
		"round_data": null,
		"battle_report": null
	}
	if session == null or not session.is_battle_running or session.volley_done:
		return result
	session.volley_done = true
	if session.is_siege_battle and not session.siege_state.is_empty():
		_rebalance_active_rams(session.siege_state)
	var attacker_ranged_kills = _process_ranged_unit_attacks(session.current_attackers, session.current_defenders, rng, session.attacker_efficiency, session.terrain_type, session.castle_type, null, session.castle_defense_override, session.is_siege_battle, session.siege_state, false)
	var defender_ranged_kills = {}
	if not session.current_garrison.is_empty():
		var garrison_ranged_kills = _process_ranged_unit_attacks(session.current_garrison, session.current_attackers, rng, 100, session.terrain_type, CastleTypeEnum.Type.NONE, null, -1, session.is_siege_battle, session.siege_state, true)
		_merge_kill_results(defender_ranged_kills, garrison_ranged_kills)
	var armies_only := _get_armies_without_garrison(session.current_defenders, session.current_garrison)
	if not armies_only.is_empty():
		var army_ranged_kills = _process_ranged_unit_attacks(armies_only, session.current_attackers, rng, session.defender_efficiency, session.terrain_type, CastleTypeEnum.Type.NONE, null, -1, session.is_siege_battle, session.siege_state, true)
		_merge_kill_results(defender_ranged_kills, army_ranged_kills)
	var attacker_casualties := {}
	var defender_casualties := {}
	for unit_type in attacker_ranged_kills:
		var kills = attacker_ranged_kills[unit_type]
		var available = session.current_defenders.get(unit_type, 0)
		var actual_kills = min(kills, available)
		session.current_defenders[unit_type] = available - actual_kills
		if session.current_defenders[unit_type] <= 0:
			session.current_defenders.erase(unit_type)
		if actual_kills > 0:
			defender_casualties[unit_type] = actual_kills
	for unit_type in defender_ranged_kills:
		var kills_def = defender_ranged_kills[unit_type]
		var available_def = session.current_attackers.get(unit_type, 0)
		var actual_kills_def = min(kills_def, available_def)
		session.current_attackers[unit_type] = available_def - actual_kills_def
		if session.current_attackers[unit_type] <= 0:
			session.current_attackers.erase(unit_type)
		if actual_kills_def > 0:
			attacker_casualties[unit_type] = actual_kills_def
	var attacker_hits = 0
	for unit_type in attacker_ranged_kills:
		attacker_hits += attacker_ranged_kills[unit_type]
	var defender_hits = 0
	for unit_type in defender_ranged_kills:
		defender_hits += defender_ranged_kills[unit_type]
	if attacker_hits > 0 or defender_hits > 0:
		var volley_data := {
			"round": 0,
			"attacker_hits": attacker_hits,
			"defender_hits": defender_hits,
			"attacker_casualties": attacker_casualties,
			"defender_casualties": defender_casualties,
			"current_attackers": session.current_attackers.duplicate(),
			"current_defenders": session.current_defenders.duplicate(),
			"attacker_size": _army_size(session.current_attackers),
			"defender_size": _army_size(session.current_defenders),
			"is_ranged_volley": true
		}
		if session.is_siege_battle and not session.siege_state.is_empty():
			volley_data["gate_state"] = _build_gate_state_payload(session.siege_state)
			volley_data["active_rams"] = _get_active_ram_count(session.siege_state)
			volley_data["reserve_rams"] = _get_reserve_ram_count(session.siege_state)
		result["round_data"] = volley_data
	var withdrawal_tracker := {
		"previous_power_ratio": session.previous_power_ratio,
		"losing_ratio_streak": session.losing_ratio_streak
	}
	var withdraw_side = _decide_withdrawal(session.current_attackers, session.current_defenders, session.current_garrison, session.attacker_can_withdraw, session.defender_can_withdraw, session.castle_type, rng, session.current_round, session.attacker_effectiveness_ratio, session.siege_state, withdrawal_tracker, session.ai_withdrawal_rules)
	session.previous_power_ratio = float(withdrawal_tracker.get("previous_power_ratio", session.previous_power_ratio))
	session.losing_ratio_streak = int(withdrawal_tracker.get("losing_ratio_streak", session.losing_ratio_streak))
	if withdraw_side != 0:
		_start_withdrawal_round_session(session, withdraw_side)
		result["withdrawing_side"] = withdraw_side
	if _army_size(session.current_attackers) <= 0 or _army_size(session.current_defenders) <= 0:
		result["battle_report"] = _finish_battle_session(session)
	if result.get("round_data", null) == null:
		result["round_data"] = {}
	return result

func process_next_round_session(session: BattleSession, rng: RandomNumberGenerator) -> Dictionary:
	var result := {
		"round_data": null,
		"battle_report": null
	}
	if session == null or not session.is_battle_running:
		return result
	session.current_round += 1
	if _army_size(session.current_attackers) <= 0 or _army_size(session.current_defenders) <= 0 or session.current_round >= session.max_rounds:
		result["battle_report"] = _finish_battle_session(session)
		return result
	if session.is_withdrawing:
		return _process_withdrawal_round_session(session, rng)
	var withdrawal_tracker := {
		"previous_power_ratio": session.previous_power_ratio,
		"losing_ratio_streak": session.losing_ratio_streak
	}
	var withdraw_side = _decide_withdrawal(session.current_attackers, session.current_defenders, session.current_garrison, session.attacker_can_withdraw, session.defender_can_withdraw, session.castle_type, rng, session.current_round, session.attacker_effectiveness_ratio, session.siege_state, withdrawal_tracker, session.ai_withdrawal_rules)
	session.previous_power_ratio = float(withdrawal_tracker.get("previous_power_ratio", session.previous_power_ratio))
	session.losing_ratio_streak = int(withdrawal_tracker.get("losing_ratio_streak", session.losing_ratio_streak))
	if withdraw_side != 0:
		_start_withdrawal_round_session(session, withdraw_side)
		result["withdrawing_side"] = withdraw_side
		return result
	if session.is_siege_battle and not session.siege_state.is_empty():
		_process_siege_ram_attacks(session.siege_state, rng)
		_increment_gate_assault_raw(session.siege_state)
		session.attacker_effectiveness_ratio = _calculate_siege_assault_ratio(session.siege_state, session.current_attackers)
	var attacker_effectiveness_value := session.attacker_effectiveness_ratio if session.is_siege_battle else 0.0
	var defender_effectiveness_value := 0.0 if session.is_siege_battle and attacker_effectiveness_value <= 0.0 else -1.0
	var attacker_hit_totals: Dictionary = {}
	var defender_hit_totals: Dictionary = {}
	var track_hit_totals: bool = DebugLogger.is_category_enabled("BattleCalculation")
	if track_hit_totals:
		attacker_hit_totals = _new_hit_totals()
		defender_hit_totals = _new_hit_totals()
	var attacker_snapshot := session.current_attackers.duplicate()
	var defender_snapshot := session.current_defenders.duplicate()
	var attacker_hit_log: Dictionary = {}
	var attacker_kills = _process_unit_attacks(session.current_attackers, session.current_defenders, rng, session.attacker_efficiency, session.terrain_type, session.castle_type, attacker_hit_log, null, session.castle_defense_override, attacker_effectiveness_value, session.is_siege_battle, attacker_hit_totals if track_hit_totals else null, session.siege_state, false)
	var defender_kills: Dictionary = {}
	var defender_hit_log: Dictionary = {}
	if not session.current_garrison.is_empty():
		var garrison_kills = _process_unit_attacks(session.current_garrison, session.current_attackers, rng, 100, session.terrain_type, CastleTypeEnum.Type.NONE, defender_hit_log, null, -1, defender_effectiveness_value, session.is_siege_battle, defender_hit_totals if track_hit_totals else null, session.siege_state, true)
		_merge_kill_results(defender_kills, garrison_kills)
	var defender_armies_only := _compute_army_composition(session.current_defenders, session.current_garrison)
	if not defender_armies_only.is_empty():
		var army_kills = _process_unit_attacks(defender_armies_only, session.current_attackers, rng, session.defender_efficiency, session.terrain_type, CastleTypeEnum.Type.NONE, defender_hit_log, null, -1, defender_effectiveness_value, session.is_siege_battle, defender_hit_totals if track_hit_totals else null, session.siege_state, true)
		_merge_kill_results(defender_kills, army_kills)
	_apply_kills(session.current_defenders, attacker_kills)
	_apply_kills(session.current_attackers, defender_kills)
	_deduct_garrison_losses_from_snapshot(attacker_kills, defender_snapshot, session.current_garrison)
	var defender_casualties: Dictionary = {}
	for unit_type in attacker_kills:
		var actual_def: int = min(attacker_kills[unit_type], defender_snapshot.get(unit_type, 0))
		if actual_def > 0:
			defender_casualties[unit_type] = actual_def
	var attacker_casualties: Dictionary = {}
	for unit_type in defender_kills:
		var actual_atk: int = min(defender_kills[unit_type], attacker_snapshot.get(unit_type, 0))
		if actual_atk > 0:
			attacker_casualties[unit_type] = actual_atk
	var attacker_hits = 0
	for unit_type in attacker_kills:
		attacker_hits += attacker_kills[unit_type]
	var defender_hits = 0
	for unit_type in defender_kills:
		defender_hits += defender_kills[unit_type]
	var round_data := {
		"round": session.current_round,
		"attacker_hits": attacker_hits,
		"defender_hits": defender_hits,
		"attacker_casualties": attacker_casualties,
		"defender_casualties": defender_casualties,
		"current_attackers": session.current_attackers.duplicate(),
		"current_defenders": session.current_defenders.duplicate(),
		"attacker_size": _army_size(session.current_attackers),
		"defender_size": _army_size(session.current_defenders),
		"assault_ratio": session.attacker_effectiveness_ratio
	}
	if session.is_siege_battle and not session.siege_state.is_empty():
		round_data["gate_state"] = _build_gate_state_payload(session.siege_state)
		round_data["active_rams"] = _get_active_ram_count(session.siege_state)
		round_data["reserve_rams"] = _get_reserve_ram_count(session.siege_state)
	result["round_data"] = round_data
	if _army_size(session.current_attackers) <= 0 or _army_size(session.current_defenders) <= 0 or session.current_round >= session.max_rounds:
		result["battle_report"] = _finish_battle_session(session)
	return result

func _process_withdrawal_round_session(session: BattleSession, rng: RandomNumberGenerator) -> Dictionary:
	var result := {
		"round_data": null,
		"battle_report": null
	}
	var is_mobility_round = session.withdrawal_rounds_remaining <= 0 and session.mobility_withdrawal_rounds_remaining > 0
	var attacker_effectiveness_value = session.attacker_effectiveness_ratio if session.is_siege_battle else 0.0
	var defender_effectiveness_value = 0.0 if session.is_siege_battle and attacker_effectiveness_value <= 0.0 else -1.0
	var attacker_kills = {}
	var defender_kills = {}
	if session.withdrawing_side == 1:
		if is_mobility_round:
			if not session.current_garrison.is_empty():
				var mobility_garrison_kills = _process_mobility_attacks(session.current_garrison, session.current_attackers, rng, 100, session.terrain_type)
				_merge_kill_results(defender_kills, mobility_garrison_kills)
			var armies_comp = _get_armies_without_garrison(session.current_defenders, session.current_garrison)
			if not armies_comp.is_empty():
				var mobility_army_kills = _process_mobility_attacks(armies_comp, session.current_attackers, rng, session.defender_efficiency, session.terrain_type)
				_merge_kill_results(defender_kills, mobility_army_kills)
		else:
			if not session.current_garrison.is_empty():
				var garrison_kills = _process_unit_attacks(session.current_garrison, session.current_attackers, rng, 100, session.terrain_type, CastleTypeEnum.Type.NONE, null, null, -1, defender_effectiveness_value, session.is_siege_battle, null, session.siege_state, true)
				_merge_kill_results(defender_kills, garrison_kills)
			var armies_standard = _get_armies_without_garrison(session.current_defenders, session.current_garrison)
			if not armies_standard.is_empty():
				var army_kills = _process_unit_attacks(armies_standard, session.current_attackers, rng, session.defender_efficiency, session.terrain_type, CastleTypeEnum.Type.NONE, null, null, -1, defender_effectiveness_value, session.is_siege_battle, null, session.siege_state, true)
				_merge_kill_results(defender_kills, army_kills)
	else:
		var armies_only = _get_armies_without_garrison(session.current_defenders, session.current_garrison)
		if not armies_only.is_empty():
			if is_mobility_round:
				attacker_kills = _process_mobility_attacks(session.current_attackers, armies_only, rng, session.attacker_efficiency, session.terrain_type)
			else:
				attacker_kills = _process_unit_attacks(session.current_attackers, armies_only, rng, session.attacker_efficiency, session.terrain_type, session.castle_type, null, null, session.castle_defense_override, attacker_effectiveness_value, session.is_siege_battle, null, session.siege_state, false)
	var attacker_hits = 0
	var defender_hits = 0
	var attacker_casualties = {}
	var defender_casualties = {}
	if session.withdrawing_side == 1:
		for unit_type in defender_kills:
			var kills = defender_kills[unit_type]
			var available = session.current_attackers.get(unit_type, 0)
			var actual_kills = min(kills, available)
			session.current_attackers[unit_type] = available - actual_kills
			if session.current_attackers[unit_type] <= 0:
				session.current_attackers.erase(unit_type)
			if actual_kills > 0:
				attacker_casualties[unit_type] = actual_kills
				attacker_hits += actual_kills
	else:
		_apply_withdrawal_casualties_to_defenders(session.current_defenders, session.current_garrison, attacker_kills, defender_casualties)
		for unit_type in defender_casualties:
			defender_hits += defender_casualties[unit_type]
	if is_mobility_round:
		session.mobility_withdrawal_rounds_remaining -= 1
	else:
		session.withdrawal_rounds_remaining -= 1
	var round_data := {
		"round": session.current_round,
		"attacker_hits": attacker_hits,
		"defender_hits": defender_hits,
		"attacker_casualties": attacker_casualties,
		"defender_casualties": defender_casualties,
		"current_attackers": session.current_attackers.duplicate(),
		"current_defenders": session.current_defenders.duplicate(),
		"attacker_size": _army_size(session.current_attackers),
		"defender_size": _army_size(session.current_defenders),
		"is_withdrawal": true,
		"withdrawal_rounds_remaining": session.withdrawal_rounds_remaining,
		"mobility_withdrawal_rounds_remaining": session.mobility_withdrawal_rounds_remaining,
		"is_ranged_volley": false
	}
	result["round_data"] = round_data
	var defenders_armies_size = _army_size(_get_armies_without_garrison(session.current_defenders, session.current_garrison))
	if (session.withdrawal_rounds_remaining <= 0 and session.mobility_withdrawal_rounds_remaining <= 0) or _army_size(session.current_attackers) <= 0 or defenders_armies_size <= 0:
		result["battle_report"] = _finish_withdrawal_session(session)
	if result.get("round_data", null) == null:
		result["round_data"] = {}
	return result

func _start_withdrawal_round_session(session: BattleSession, side: int) -> void:
	if session == null or session.is_withdrawing or side == 0:
		return
	session.is_withdrawing = true
	session.withdrawing_side = side
	session.withdrawal_rounds_remaining = GameParameters.WITHDRAWAL_FREE_HIT_ROUNDS
	session.mobility_withdrawal_rounds_remaining = GameParameters.MOBILITY_EXTRA_WITHDRAWAL_ROUNDS

func _finish_battle_session(session: BattleSession) -> BattleReport:
	session.is_battle_running = false
	var attacker_size = _army_size(session.current_attackers)
	var defender_size = _army_size(session.current_defenders)
	var winner: String
	if attacker_size > 0 and defender_size == 0:
		winner = "Attackers"
	elif defender_size > 0 and attacker_size == 0:
		winner = "Defenders"
	else:
		winner = "Draw"
	var report = BattleReport.new()
	report.winner = winner
	report.rounds = session.current_round
	report.attacker_losses = _calculate_losses(session.original_attackers, session.current_attackers)
	report.defender_losses = _calculate_losses(session.original_defenders, session.current_defenders)
	report.final_attacker = session.current_attackers
	report.final_defender = session.current_defenders
	report.withdrawing_side = session.withdrawing_side
	if session.is_siege_battle:
		report.siege_payload = _build_siege_payload_output(session.siege_state, session.siege_payload_base, session.current_attackers)
		report.gate_plan_log = _build_gate_plan_log_lines(session.siege_state, "")
	return report

func _finish_withdrawal_session(session: BattleSession) -> BattleReport:
	var side := session.withdrawing_side
	session.is_battle_running = false
	session.is_withdrawing = false
	session.withdrawing_side = 0
	var report = BattleReport.new()
	report.winner = "Withdrawal"
	report.rounds = session.current_round
	report.attacker_losses = _calculate_losses(session.original_attackers, session.current_attackers)
	report.defender_losses = _calculate_losses(session.original_defenders, session.current_defenders)
	report.final_attacker = session.current_attackers
	report.final_defender = session.current_defenders
	report.withdrawing_side = side
	if session.is_siege_battle:
		report.siege_payload = _build_siege_payload_output(session.siege_state, session.siege_payload_base, session.current_attackers)
		report.gate_plan_log = _build_gate_plan_log_lines(session.siege_state, "")
	return report

func _merge_compositions(compositions: Array) -> Dictionary:
	"""Merge multiple ArmyComposition objects into a single dictionary"""
	var merged = {}
	
	# Initialize with all unit types
	for unit_type in SoldierTypeEnum.get_all_types():
		merged[unit_type] = 0
	
	# Sum up all compositions
	for composition in compositions:
		if composition == null:
			continue
		for unit_type in SoldierTypeEnum.get_all_types():
			merged[unit_type] += composition.get_soldier_count(unit_type)
	
	# Remove empty unit types
	var clean_merged = {}
	for unit_type in merged:
		if merged[unit_type] > 0:
			clean_merged[unit_type] = merged[unit_type]
	
	return clean_merged

func _copy_composition_dict(composition: Dictionary) -> Dictionary:
	"""Create a copy of a composition dictionary"""
	var copy = {}
	for unit_type in composition:
		copy[unit_type] = composition[unit_type]
	return copy

func _create_garrison_composition(region_garrison: ArmyComposition) -> Dictionary:
	if region_garrison == null or region_garrison.is_empty():
		return {}
	return _merge_compositions([region_garrison])

func _compute_army_composition(total_defenders: Dictionary, current_garrison: Dictionary) -> Dictionary:
	if current_garrison.is_empty():
		return total_defenders.duplicate()
	var armies_only := {}
	for unit_type in total_defenders:
		var total_count = int(total_defenders[unit_type])
		var garrison_count = int(current_garrison.get(unit_type, 0))
		var army_count = total_count - garrison_count
		if army_count > 0:
			armies_only[unit_type] = army_count
	return armies_only

func _deduct_garrison_losses_from_snapshot(attacker_kills: Dictionary, defender_snapshot: Dictionary, current_garrison: Dictionary) -> void:
	if current_garrison.is_empty():
		return
	for unit_type in attacker_kills:
		var kills = int(attacker_kills[unit_type])
		if kills <= 0:
			continue
		var garrison_before = int(current_garrison.get(unit_type, 0))
		if garrison_before <= 0:
			continue
		var total_before = int(defender_snapshot.get(unit_type, 0))
		if total_before <= 0:
			continue
		var garrison_loss = int(round(float(kills) * float(garrison_before) / float(total_before)))
		garrison_loss = clampi(garrison_loss, 0, garrison_before)
		var remaining = garrison_before - garrison_loss
		if remaining > 0:
			current_garrison[unit_type] = remaining
		else:
			current_garrison.erase(unit_type)

func _army_size(army: Dictionary) -> int:
	"""Calculate total size of an army"""
	var total = 0
	for unit_type in army:
		total += army[unit_type]
	return total

func _process_unit_attacks(attacking_army: Dictionary, defending_army: Dictionary, rng: RandomNumberGenerator, efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE, hit_log = null, stats_accumulator = null, castle_defense_bonus_override: int = -1, attack_effectiveness_ratio: float = -1.0, disable_siege_traits: bool = false, hit_totals = null, siege_state: Dictionary = {}, target_has_rams: bool = false) -> Dictionary:
	"""Process attacks unit-by-unit with trait-based targeting rules"""
	var total_kills = {}
	var apply_effectiveness := disable_siege_traits and attack_effectiveness_ratio >= 0.0
	var clamped_effectiveness := clampf(attack_effectiveness_ratio, 0.0, 1.0)
	var hit_records := []
	var total_non_ranged_hits := 0
	
	# Process each attacking unit type
	for attacker_unit_type in attacking_army:
		var attacker_count = attacking_army[attacker_unit_type]
		if attacker_count <= 0:
			continue
			
		var attack_sample := _compute_attack_hits(attacker_unit_type, attacker_count, efficiency, terrain_type, castle_type, rng, disable_siege_traits)
		var hits: int = int(attack_sample["hits"])
		var original_hits: int = hits
		var effective_unit_count: int = int(attack_sample["effective_unit_count"])
		var is_ranged_unit := GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_2)
		if apply_effectiveness and not is_ranged_unit:
			total_non_ranged_hits += hits
		hit_records.append({
			"unit_type": attacker_unit_type,
			"attacker_count": attacker_count,
			"effective_unit_count": effective_unit_count,
			"hits": hits,
			"original_hits": original_hits,
			"is_ranged": is_ranged_unit
		})
	
	if apply_effectiveness and clamped_effectiveness < 1.0 and total_non_ranged_hits > 0:
		var scaled_hits := _apply_multiplier_stochastic(total_non_ranged_hits, clamped_effectiveness, rng)
		_scale_non_ranged_hit_records(hit_records, scaled_hits, rng)
	
	for record in hit_records:
		var attacker_unit_type = record["unit_type"]
		var hits: int = int(record["hits"])
		var original_hits: int = int(record["original_hits"])
		var is_ranged_unit: bool = record["is_ranged"]
		if target_has_rams and is_ranged_unit:
			var ram_hits: int = _allocate_hits_to_rams(hits, defending_army, siege_state, rng)
			hits = max(0, hits - ram_hits)
		if hit_totals != null:
			_accumulate_hit_totals(hit_totals, is_ranged_unit, original_hits, hits)
		
		if stats_accumulator != null:
			_record_unit_stats(stats_accumulator, attacker_unit_type, int(record["effective_unit_count"]), hits)
		
		if hits <= 0:
			continue
		
		if hit_log != null:
			_record_unit_hits(hit_log, attacker_unit_type, int(record["attacker_count"]), hits)
			
		# Determine valid targets based on traits
		var valid_targets = _get_valid_targets(attacker_unit_type, attacking_army, defending_army, disable_siege_traits)
		
		if valid_targets.is_empty():
			continue
			
		# Distribute hits among valid targets
		var target_assigned = _distribute_hits_to_valid_targets(defending_army, valid_targets, hits, rng)
		
		# Apply long-spears bonus: double hits against cavalry if attacker has long-spears
		if not disable_siege_traits and GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_1):  # long_spears
			for defender_unit_type in target_assigned:
				if GameParameters.is_cavalry_unit(defender_unit_type):
					target_assigned[defender_unit_type] = _apply_multiplier_stochastic(target_assigned[defender_unit_type], GameParameters.LONG_SPEARS_CAVALRY_MULTIPLIER, rng)
		
		var target_kills = _defense_resolution_with_attacker_traits(target_assigned, attacker_unit_type, rng, castle_type, castle_defense_bonus_override)
		
		# Merge kills into total
		_merge_kill_results(total_kills, target_kills)
	
	return total_kills

func _process_mobility_attacks(defending_army: Dictionary, attacking_targets: Dictionary, rng: RandomNumberGenerator, efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND) -> Dictionary:
	var mobility_kills := {}
	for defender_unit_type in defending_army.keys():
		var defender_count = defending_army[defender_unit_type]
		if defender_count <= 0:
			continue
		if not GameParameters.unit_has_trait(defender_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_3):
			continue
		var attack_sample := _compute_attack_hits(defender_unit_type, defender_count, efficiency, terrain_type, CastleTypeEnum.Type.NONE, rng, true)
		var hits: int = int(attack_sample["hits"])
		if hits <= 0:
			continue
		var valid_targets = _get_valid_targets(defender_unit_type, defending_army, attacking_targets, true)
		if valid_targets.is_empty():
			continue
		var target_assigned = _distribute_hits_to_valid_targets(attacking_targets, valid_targets, hits, rng)
		if GameParameters.unit_has_trait(defender_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_1):
			for target_unit_type in target_assigned.keys():
				if GameParameters.is_cavalry_unit(target_unit_type):
					target_assigned[target_unit_type] = _apply_multiplier_stochastic(target_assigned[target_unit_type], GameParameters.LONG_SPEARS_CAVALRY_MULTIPLIER, rng)
		var target_kills = _defense_resolution_with_attacker_traits(target_assigned, defender_unit_type, rng, CastleTypeEnum.Type.NONE, -1)
		_merge_kill_results(mobility_kills, target_kills)
	return mobility_kills

func _decide_withdrawal(current_attackers: Dictionary, current_defenders: Dictionary, current_garrison: Dictionary, attacker_can_withdraw: bool, defender_can_withdraw: bool, castle_type: CastleTypeEnum.Type, rng: RandomNumberGenerator, current_round: int, attacker_effectiveness_ratio: float = 1.0, siege_state: Dictionary = {}, withdrawal_tracker: Dictionary = {}, ai_withdrawal_rules: Dictionary = {}) -> int:
	var siege_bailout_ratio: float = float(ai_withdrawal_rules.get("siege_bailout_ratio", 1.5))
	var withdraw_power_threshold: float = float(ai_withdrawal_rules.get("withdraw_power_threshold", GameParameters.AI_WITHDRAW_POWER_THRESHOLD))
	var withdraw_forced_threshold: float = float(ai_withdrawal_rules.get("withdraw_forced_threshold", GameParameters.AI_WITHDRAW_MAX_POWER_DIFFERENCE))
	var is_siege_battle := castle_type != CastleTypeEnum.Type.NONE
	if is_siege_battle:
		var atk_power: int = _compute_dict_power(current_attackers)
		var def_power: int = _compute_dict_power(current_defenders)
		if atk_power <= 0 or def_power <= 0:
			return 0
		if not attacker_can_withdraw:
			return 0
		var ratio: float = float(atk_power) / float(def_power)
		if ratio <= siege_bailout_ratio:
			DebugLogger.log("Withdrawal", "BattleSimulator.decide_withdrawal siege bailout side=1 ratio=" + str(snappedf(ratio, 0.003)))
			return 1
		var active_rams: int = _get_active_ram_count(siege_state)
		if active_rams > 0:
			withdrawal_tracker["previous_power_ratio"] = ratio
			withdrawal_tracker["losing_ratio_streak"] = 0
			return 0
		var prev_ratio: float = float(withdrawal_tracker.get("previous_power_ratio", -1.0))
		var losing_streak: int = int(withdrawal_tracker.get("losing_ratio_streak", 0))
		if prev_ratio < 0.0:
			withdrawal_tracker["previous_power_ratio"] = ratio
			withdrawal_tracker["losing_ratio_streak"] = losing_streak
			return 0
		if ratio < prev_ratio:
			losing_streak += 1
		else:
			losing_streak = 0
		withdrawal_tracker["previous_power_ratio"] = ratio
		withdrawal_tracker["losing_ratio_streak"] = losing_streak
		if current_round > 7 and losing_streak >= 3:
			DebugLogger.log("Withdrawal", "BattleSimulator.decide_withdrawal siege worsening side=1 streak=" + str(losing_streak) + " ratio=" + str(snappedf(ratio, 0.003)) + " round=" + str(current_round))
			return 1
		return 0
	var atk_power_open: int = _compute_dict_power(current_attackers)
	var def_power_open: int = _compute_dict_power(current_defenders)
	if atk_power_open <= 0 or def_power_open <= 0:
		return 0
	var withdrawing: int = 0
	var weaker: int = atk_power_open
	var stronger: int = def_power_open
	if atk_power_open < def_power_open:
		withdrawing = 1
		weaker = atk_power_open
		stronger = def_power_open
	elif def_power_open < atk_power_open:
		withdrawing = 2
		weaker = def_power_open
		stronger = atk_power_open
	else:
		return 0
	if withdrawing == 1 and not attacker_can_withdraw:
		return 0
	if withdrawing == 2:
		if castle_type != CastleTypeEnum.Type.NONE:
			return 0
		if not defender_can_withdraw:
			return 0
		var armies_only := _get_armies_without_garrison(current_defenders, current_garrison)
		if armies_only.is_empty():
			return 0
	var ratio_open := float(weaker) / float(stronger)
	if ratio_open > withdraw_power_threshold:
		return 0
	if ratio_open <= withdraw_forced_threshold:
		DebugLogger.log("Withdrawal", "BattleSimulator.decide_withdrawal forced side=" + str(withdrawing) + " atk_power=" + str(atk_power_open) + " def_power=" + str(def_power_open) + " ratio=" + str(snappedf(ratio_open, 0.003)))
		return withdrawing
	var gap := 1.0 - ratio_open
	var chance: float = clampf(gap, 0.0, 1.0)
	var roll := rng.randf()
	DebugLogger.log("Withdrawal", "BattleSimulator.decide_withdrawal roll side=" + str(withdrawing) + " ratio=" + str(snappedf(ratio_open, 0.003)) + " chance=" + str(snappedf(chance, 0.003)) + " roll=" + str(snappedf(roll, 0.003)))
	return withdrawing if roll < chance else 0

func _resolve_withdrawal_phase(current_attackers: Dictionary, current_defenders: Dictionary, current_garrison: Dictionary, attacker_efficiency: int, defender_efficiency: int, terrain_type: RegionTypeEnum.Type, castle_type: CastleTypeEnum.Type, rng: RandomNumberGenerator, attacker_stats: Dictionary, defender_stats: Dictionary, withdrawing_side: int, castle_defense_bonus_override: int = -1, attacker_effectiveness_ratio: float = -1.0, disable_siege_traits: bool = false, siege_state: Dictionary = {}) -> int:
	var extra_rounds := 0
	var standard_rounds := GameParameters.WITHDRAWAL_FREE_HIT_ROUNDS
	var mobility_rounds := GameParameters.MOBILITY_EXTRA_WITHDRAWAL_ROUNDS
	var garrison_dict := current_garrison.duplicate()
	DebugLogger.log("Withdrawal", "BattleSimulator.resolve_withdrawal start side=" + str(withdrawing_side) + " standard_rounds=" + str(standard_rounds) + " mobility_rounds=" + str(mobility_rounds))
	while _army_size(current_attackers) > 0 and (standard_rounds > 0 or mobility_rounds > 0):
		extra_rounds += 1
		var kills := {}
		if withdrawing_side == 1:
			var armies_only := _get_armies_without_garrison(current_defenders, garrison_dict)
			if standard_rounds > 0:
				if not garrison_dict.is_empty():
					var effective_block := disable_siege_traits and attacker_effectiveness_ratio <= 0.0
					var garrison_hits = _process_unit_attacks(garrison_dict, current_attackers, rng, 100, terrain_type, CastleTypeEnum.Type.NONE, null, defender_stats, -1, 0.0 if effective_block else -1.0, disable_siege_traits, null, siege_state, true)
					_merge_kill_results(kills, garrison_hits)
				if not armies_only.is_empty():
					var effective_block_army := disable_siege_traits and attacker_effectiveness_ratio <= 0.0
					var army_hits = _process_unit_attacks(armies_only, current_attackers, rng, defender_efficiency, terrain_type, CastleTypeEnum.Type.NONE, null, defender_stats, -1, 0.0 if effective_block_army else -1.0, disable_siege_traits, null, siege_state, true)
					_merge_kill_results(kills, army_hits)
				standard_rounds -= 1
			else:
				if not garrison_dict.is_empty():
					var garrison_mobility_hits = _process_mobility_attacks(garrison_dict, current_attackers, rng, 100, terrain_type)
					_merge_kill_results(kills, garrison_mobility_hits)
				if not armies_only.is_empty():
					var army_mobility_hits = _process_mobility_attacks(armies_only, current_attackers, rng, defender_efficiency, terrain_type)
					_merge_kill_results(kills, army_mobility_hits)
				mobility_rounds -= 1
			_apply_withdrawal_casualties(current_attackers, kills)
		else:
			var armies_only_def := _get_armies_without_garrison(current_defenders, garrison_dict)
			if armies_only_def.is_empty():
				break
			if standard_rounds > 0:
				kills = _process_unit_attacks(current_attackers, armies_only_def, rng, attacker_efficiency, terrain_type, castle_type, null, attacker_stats, castle_defense_bonus_override, 0.0, disable_siege_traits, null, siege_state, false)
				standard_rounds -= 1
			else:
				kills = _process_mobility_attacks(current_attackers, armies_only_def, rng, attacker_efficiency, terrain_type)
				mobility_rounds -= 1
			var unused_defender_casualties := {}
			_apply_withdrawal_casualties_to_defenders(current_defenders, garrison_dict, kills, unused_defender_casualties)
		if withdrawing_side == 1 and _army_size(current_attackers) <= 0:
			break
		if withdrawing_side == 2 and _army_size(_get_armies_without_garrison(current_defenders, garrison_dict)) <= 0:
			break
	return extra_rounds

func _get_armies_without_garrison(current_defenders: Dictionary, garrison_dict: Dictionary) -> Dictionary:
	if garrison_dict.is_empty():
		return current_defenders.duplicate()
	var armies_only := {}
	for unit_type in current_defenders.keys():
		var total: int = int(current_defenders[unit_type])
		var garrison_count: int = int(garrison_dict.get(unit_type, 0))
		var army_count: int = max(0, total - garrison_count)
		if army_count > 0:
			armies_only[unit_type] = army_count
	return armies_only

func _apply_withdrawal_casualties(current_attackers: Dictionary, defender_kills: Dictionary) -> void:
	for unit_type in defender_kills.keys():
		var kills: int = int(defender_kills[unit_type])
		if kills <= 0:
			continue
		var available: int = int(current_attackers.get(unit_type, 0))
		var remaining: int = max(0, available - kills)
		if remaining <= 0:
			current_attackers.erase(unit_type)
		else:
			current_attackers[unit_type] = remaining

func _apply_withdrawal_casualties_to_defenders(current_defenders: Dictionary, garrison_dict: Dictionary, attacker_kills: Dictionary, casualty_record: Dictionary) -> void:
	for unit_type in attacker_kills.keys():
		var kills: int = int(attacker_kills[unit_type])
		if kills <= 0:
			continue
		var total_def: int = int(current_defenders.get(unit_type, 0))
		var garrison_count: int = int(garrison_dict.get(unit_type, 0))
		var army_available: int = max(0, total_def - garrison_count)
		if army_available <= 0:
			continue
		var actual_kills: int = min(kills, army_available)
		current_defenders[unit_type] = total_def - actual_kills
		if current_defenders[unit_type] <= 0:
			current_defenders.erase(unit_type)
		if casualty_record != null and actual_kills > 0:
			casualty_record[unit_type] = actual_kills

func _compute_dict_power(comp_dict: Dictionary) -> int:
	var total := 0
	for ut in comp_dict.keys():
		var qty: int = int(comp_dict[ut])
		if qty > 0:
			total += GameParameters.get_unit_stat(ut, "power") * qty
	return total

func _create_withdrawal_report(original_attackers: Dictionary, original_defenders: Dictionary, current_attackers: Dictionary, current_defenders: Dictionary, rounds: int, withdrawing_side: int, siege_payload: Dictionary = {}) -> BattleReport:
	var report = BattleReport.new()
	report.winner = "Withdrawal"
	report.rounds = rounds
	report.attacker_losses = _calculate_losses(original_attackers, current_attackers)
	report.defender_losses = _calculate_losses(original_defenders, current_defenders)
	report.final_attacker = current_attackers.duplicate()
	report.final_defender = current_defenders.duplicate()
	report.withdrawing_side = withdrawing_side
	report.siege_payload = siege_payload
	return report

func _split_power_by_ranged(comp_dict: Dictionary) -> Dictionary:
	var ranged_power: float = 0.0
	var non_ranged_power: float = 0.0
	for ut in comp_dict.keys():
		var qty: int = int(comp_dict[ut])
		if qty <= 0:
			continue
		var unit_power: int = GameParameters.get_unit_stat(ut, "power")
		var contribution := float(unit_power * qty)
		if GameParameters.unit_has_trait(ut, UnitTraitEnum.Type.UNIT_TRAIT_2):
			ranged_power += contribution
		else:
			non_ranged_power += contribution
	return {
		"ranged": ranged_power,
		"non_ranged": non_ranged_power
	}

func _distribute_hits_across_defender(defender: Dictionary, total_hits: int, rng: RandomNumberGenerator) -> Dictionary:
	"""Distribute hits proportionally across defender unit types"""
	if total_hits <= 0 or defender.is_empty():
		return {}
	
	var unit_types = []
	var counts = []
	
	for unit_type in defender:
		if defender[unit_type] > 0:
			unit_types.append(unit_type)
			counts.append(defender[unit_type])
	
	if unit_types.is_empty():
		return {}
	
	var distributed_hits = _multinomial_sample(rng, total_hits, counts)
	var result = {}
	
	for i in range(unit_types.size()):
		if distributed_hits[i] > 0:
			result[unit_types[i]] = distributed_hits[i]
	
	return result

func _defense_resolution(assigned_hits: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	"""Apply defense chances to reduce assigned hits to actual kills"""
	var kills = {}
	
	for unit_type in assigned_hits:
		var hits = assigned_hits[unit_type]
		if hits <= 0:
			continue
		
		var defense_chance = GameParameters.get_unit_stat(unit_type, "defense") / 100.0
		var penetration_chance = max(0.0, 1.0 - defense_chance)
		var penetrating_hits = _binomial_sample(rng, hits, penetration_chance)
		
		if penetrating_hits > 0:
			kills[unit_type] = penetrating_hits
	
	return kills

func _defense_resolution_with_attacker_traits(assigned_hits: Dictionary, attacker_unit_type: SoldierTypeEnum.Type, rng: RandomNumberGenerator, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE, castle_defense_bonus_override: int = -1) -> Dictionary:
	"""Apply defense chances with consideration for attacker traits like armor piercing and castle defenses"""
	var kills = {}
	
	# Check if attacker has armor piercing trait
	var has_armor_piercing = GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_7)  # armor_piercing
	
	# Get castle defense bonus (hit avoidance percentage)
	var castle_defense_bonus = GameParameters.get_castle_defense_bonus(castle_type) / 100.0
	if castle_defense_bonus_override >= 0:
		castle_defense_bonus = float(castle_defense_bonus_override) / 100.0
	
	for defender_unit_type in assigned_hits:
		var hits = assigned_hits[defender_unit_type]
		if hits <= 0:
			continue
		
		# First layer: Castle defense (hit avoidance)
		var hits_after_castle_defense = hits
		if castle_defense_bonus > 0.0:
			var castle_hit_chance = max(0.0, 1.0 - castle_defense_bonus)
			hits_after_castle_defense = _binomial_sample(rng, hits, castle_hit_chance)
		
		if hits_after_castle_defense <= 0:
			continue
		
		# Second layer: Unit armor defense  
		var base_defense_chance = GameParameters.get_unit_stat(defender_unit_type, "defense") / 100.0
		var effective_defense_chance = base_defense_chance
		
		# Apply armor piercing reduction to unit armor only
		if has_armor_piercing:
			effective_defense_chance = max(0.0, base_defense_chance - GameParameters.ARMOR_PIERCING_DEFENSE_REDUCTION)
		
		var penetration_chance = max(0.0, 1.0 - effective_defense_chance)
		var penetrating_hits = _binomial_sample(rng, hits_after_castle_defense, penetration_chance)
		
		if penetrating_hits > 0:
			kills[defender_unit_type] = penetrating_hits
	
	return kills

func _apply_kills(army: Dictionary, kills: Dictionary) -> void:
	"""Apply kills to army, removing casualties"""
	for unit_type in kills:
		var kill_count = kills[unit_type]
		if kill_count <= 0:
			continue
		
		var available = army.get(unit_type, 0)
		if available <= 0:
			continue
		
		var actual_kills = min(kill_count, available)
		army[unit_type] = available - actual_kills
		
		# Remove unit type if no soldiers left
		if army[unit_type] <= 0:
			army.erase(unit_type)

func _calculate_losses(original: Dictionary, final: Dictionary) -> Dictionary:
	"""Calculate losses by comparing original and final compositions"""
	var losses = {}
	
	for unit_type in original:
		var original_count = original[unit_type]
		var final_count = final.get(unit_type, 0)
		var lost = original_count - final_count
		
		if lost > 0:
			losses[unit_type] = lost
	
	return losses

func _binomial_sample(rng: RandomNumberGenerator, n: int, p: float) -> int:
	"""Sample from binomial distribution B(n, p)"""
	if n <= 0 or p <= 0.0:
		return 0
	if p >= 1.0:
		return n
	
	var successes = 0
	for i in range(n):
		if rng.randf() < p:
			successes += 1
	
	return successes

func _multinomial_sample(rng: RandomNumberGenerator, n: int, weights: Array) -> Array:
	"""Sample from multinomial distribution with given weights"""
	if n <= 0 or weights.is_empty():
		return []
	
	# Normalize weights
	var total_weight = 0.0
	for weight in weights:
		total_weight += weight
	
	if total_weight <= 0:
		var empty_results = []
		empty_results.resize(weights.size())
		for i in range(empty_results.size()):
			empty_results[i] = 0
		return empty_results
	
	var probs = []
	for weight in weights:
		probs.append(weight / total_weight)
	
	# Sample n items
	var results = []
	results.resize(weights.size())
	for i in range(results.size()):
		results[i] = 0
	
	for i in range(n):
		var rand = rng.randf()
		var cumulative = 0.0
		
		for j in range(probs.size()):
			cumulative += probs[j]
			if rand <= cumulative:
				results[j] += 1
				break
	
	return results

func _get_valid_targets(attacker_unit_type: SoldierTypeEnum.Type, attacking_army: Dictionary, defending_army: Dictionary, disable_siege_traits: bool = false) -> Array[SoldierTypeEnum.Type]:
	"""Get valid target unit types based on trait-based combat rules"""
	var valid_targets: Array[SoldierTypeEnum.Type] = []
	var attacker_has_ranged = GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_2)  # ranged
	var attacker_has_flanker = not disable_siege_traits and GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_4)  # flanker
	
	# Check each defending unit type
	for defender_unit_type in defending_army:
		if defending_army[defender_unit_type] <= 0:
			continue
			
		var defender_has_ranged = GameParameters.unit_has_trait(defender_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_2)  # ranged
		
		# Rule 1: Ranged units can attack any unit
		if attacker_has_ranged:
			valid_targets.append(defender_unit_type)
			continue
		
		# Rule 2: Units with flanker trait can attack any unit (including ranged)
		if attacker_has_flanker:
			valid_targets.append(defender_unit_type)
			continue
		
		# Rule 3: Non-ranged units can attack ranged units only if 3:1 ratio rule is met
		if defender_has_ranged:
			if _can_attack_ranged_by_ratio(attacking_army, defending_army):
				valid_targets.append(defender_unit_type)
			# If ratio rule not met, cannot target this ranged unit
		else:
			# Non-ranged defender, can always be targeted by non-ranged attacker
			valid_targets.append(defender_unit_type)
	
	return valid_targets

func _can_attack_ranged_by_ratio(attacking_army: Dictionary, defending_army: Dictionary) -> bool:
	"""Check if attacking army meets 3:1 ratio to attack ranged defenders"""
	var attacker_non_ranged_count = 0
	var defender_non_ranged_count = 0
	
	# Count non-ranged attacking units
	for unit_type in attacking_army:
		if not GameParameters.unit_has_trait(unit_type, UnitTraitEnum.Type.UNIT_TRAIT_2):  # not ranged
			attacker_non_ranged_count += attacking_army[unit_type]
	
	# Count non-ranged defending units
	for unit_type in defending_army:
		if not GameParameters.unit_has_trait(unit_type, UnitTraitEnum.Type.UNIT_TRAIT_2):  # not ranged
			defender_non_ranged_count += defending_army[unit_type]
	
	# Ratio rule: attacker non-ranged must be at least 3 times defender non-ranged
	return attacker_non_ranged_count >= (defender_non_ranged_count * 3)

func _distribute_hits_to_valid_targets(defending_army: Dictionary, valid_targets: Array[SoldierTypeEnum.Type], total_hits: int, rng: RandomNumberGenerator) -> Dictionary:
	"""Distribute hits only among valid target unit types"""
	if total_hits <= 0 or valid_targets.is_empty():
		return {}
	
	var target_counts = []
	for target_type in valid_targets:
		target_counts.append(defending_army.get(target_type, 0))
	
	var distributed_hits = _multinomial_sample(rng, total_hits, target_counts)
	var result = {}
	
	for i in range(valid_targets.size()):
		if distributed_hits[i] > 0:
			result[valid_targets[i]] = distributed_hits[i]
	
	return result

func _get_terrain_attack_multiplier(unit_type: SoldierTypeEnum.Type, terrain_type: RegionTypeEnum.Type, castle_type: CastleTypeEnum.Type, disable_siege_traits: bool = false) -> float:
	"""Get terrain-based attack multipliers for units with specific traits"""
	var multiplier = 1.0
	
	# Charge bonus: 100% bonus on grassland unless attacking a region with any level of castle
	if not disable_siege_traits and GameParameters.unit_has_trait(unit_type, UnitTraitEnum.Type.UNIT_TRAIT_5):  # charge trait
		if terrain_type == RegionTypeEnum.Type.GRASSLAND and castle_type == CastleTypeEnum.Type.NONE:
			multiplier += GameParameters.CHARGE_BONUS_GRASSLAND
	
	return multiplier

func _process_ranged_unit_attacks(attacking_army: Dictionary, defending_army: Dictionary, rng: RandomNumberGenerator, efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE, stats_accumulator = null, castle_defense_bonus_override: int = -1, disable_siege_traits: bool = false, siege_state: Dictionary = {}, target_has_rams: bool = false) -> Dictionary:
	"""Process attacks from only ranged trait units during opening volley"""
	var ranged_kills = {}
	if target_has_rams:
		DebugLogger.log("BattleCalculation", "[Siege] Ranged volley vs rams: active=" + str(_get_active_ram_count(siege_state)) + ", reserve=" + str(_get_reserve_ram_count(siege_state)) + ", siege_state_empty=" + str(siege_state.is_empty()))
	
	# Only process units with ranged trait
	for attacker_unit_type in attacking_army:
		var attacker_count = attacking_army[attacker_unit_type]
		if attacker_count <= 0:
			continue
			
		# Check if this unit has ranged trait
		if not GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_2):  # ranged
			continue
			
		var attack_sample := _compute_attack_hits(attacker_unit_type, attacker_count, efficiency, terrain_type, castle_type, rng, disable_siege_traits)
		var effective_unit_count: int = int(attack_sample["effective_unit_count"])
		var hits: int = int(attack_sample["hits"])
		
		if target_has_rams:
			var ram_hits: int = _allocate_hits_to_rams(hits, defending_army, siege_state, rng)
			hits = max(0, hits - ram_hits)
		
		if stats_accumulator != null:
			_record_unit_stats(stats_accumulator, attacker_unit_type, effective_unit_count, hits)
		
		if hits <= 0:
			continue
			
		# Determine valid targets based on traits
		var valid_targets = _get_valid_targets(attacker_unit_type, attacking_army, defending_army, disable_siege_traits)
		
		if valid_targets.is_empty():
			continue
			
		# Distribute hits among valid targets
		var target_assigned = _distribute_hits_to_valid_targets(defending_army, valid_targets, hits, rng)
		
		# Apply long-spears bonus: double hits against cavalry if attacker has long-spears
		if not disable_siege_traits and GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_1):  # long_spears
			for defender_unit_type in target_assigned:
				if GameParameters.is_cavalry_unit(defender_unit_type):
					target_assigned[defender_unit_type] = _apply_multiplier_stochastic(target_assigned[defender_unit_type], GameParameters.LONG_SPEARS_CAVALRY_MULTIPLIER, rng)
		
		var target_kills = _defense_resolution_with_attacker_traits(target_assigned, attacker_unit_type, rng, castle_type, castle_defense_bonus_override)
		
		# Merge kills into total
		_merge_kill_results(ranged_kills, target_kills)
	
	return ranged_kills

func _scale_non_ranged_hit_records(hit_records: Array, target_total: int, rng: RandomNumberGenerator) -> void:
	var non_ranged_indices := []
	var remaining_hits := []
	var current_total := 0
	for i in range(hit_records.size()):
		var record = hit_records[i]
		if bool(record.get("is_ranged", false)):
			continue
		var hits: int = int(record.get("hits", 0))
		hit_records[i]["hits"] = 0
		if hits <= 0:
			continue
		non_ranged_indices.append(i)
		remaining_hits.append(hits)
		current_total += hits
	if current_total == 0:
		return
	if target_total >= current_total:
		for idx in range(non_ranged_indices.size()):
			var record_index = non_ranged_indices[idx]
			hit_records[record_index]["hits"] = remaining_hits[idx]
		return
	var hits_to_assign := target_total
	var total_remaining := current_total
	while hits_to_assign > 0 and total_remaining > 0:
		var pick := rng.randi_range(1, total_remaining)
		var cumulative := 0
		for idx in range(non_ranged_indices.size()):
			cumulative += remaining_hits[idx]
			if pick <= cumulative:
				var record_index = non_ranged_indices[idx]
				hit_records[record_index]["hits"] = int(hit_records[record_index]["hits"]) + 1
				remaining_hits[idx] -= 1
				total_remaining -= 1
				hits_to_assign -= 1
				break

func _apply_multiplier_stochastic(base_hits: int, mult: float, rng: RandomNumberGenerator) -> int:
	"""Apply multiplier with stochastic rounding to preserve exact expectations"""
	var raw := float(base_hits) * mult
	var whole := int(floor(raw))
	var frac := raw - float(whole)
	if rng.randf() < frac:
		whole += 1
	return whole

func _merge_kill_results(total_kills: Dictionary, new_kills: Dictionary) -> void:
	"""Merge kill results from different attacking unit types"""
	for unit_type in new_kills:
		if total_kills.has(unit_type):
			total_kills[unit_type] += new_kills[unit_type]
		else:
			total_kills[unit_type] = new_kills[unit_type]

func _compute_attack_hits(unit_type: SoldierTypeEnum.Type, unit_count: int, efficiency: int, terrain_type: RegionTypeEnum.Type, castle_type: CastleTypeEnum.Type, rng: RandomNumberGenerator, disable_siege_traits: bool = false) -> Dictionary:
	var efficiency_modifier: float = float(efficiency) / 100.0
	var base_attack_chance: float = float(GameParameters.get_unit_stat(unit_type, "attack")) / 100.0
	var modified_attack_chance: float = base_attack_chance * efficiency_modifier
	modified_attack_chance *= _get_terrain_attack_multiplier(unit_type, terrain_type, castle_type, disable_siege_traits)
	var effective_unit_count: int = unit_count
	if GameParameters.unit_has_trait(unit_type, UnitTraitEnum.Type.UNIT_TRAIT_6):
		effective_unit_count *= 2
	var hits: int = _binomial_sample(rng, effective_unit_count, modified_attack_chance)
	return {
		"hits": hits,
		"effective_unit_count": effective_unit_count,
		"attack_chance": modified_attack_chance
	}

func _log_battle_round_debug(round_number: int, attacker_label: String, defender_label: String, attacker_snapshot: Dictionary, defender_snapshot: Dictionary, attacker_hits: Dictionary, defender_hits: Dictionary, attacker_kills: Dictionary, defender_kills: Dictionary) -> void:
	if not DebugLogger.is_category_enabled("BattleCalculation"):
		return
	DebugLogger.log("BattleCalculation", "--- Round " + str(round_number) + " ---")
	DebugLogger.log("BattleCalculation", "-Hits Phase-")
	_log_battle_phase_section(attacker_label, attacker_snapshot, attacker_hits, "No hits recorded")
	_log_battle_phase_section(defender_label, defender_snapshot, defender_hits, "No hits recorded")
	DebugLogger.log("BattleCalculation", "-Killed Phase-")
	_log_battle_phase_section(attacker_label, attacker_snapshot, defender_kills, "No losses")
	_log_battle_phase_section(defender_label, defender_snapshot, attacker_kills, "No losses")

func _log_round_totals(round_number: int, attacker_label: String, defender_label: String, attacker_hit_totals, defender_hit_totals, attacker_kills: Dictionary, defender_kills: Dictionary, attacker_snapshot: Dictionary, defender_snapshot: Dictionary) -> void:
	if attacker_hit_totals == null or defender_hit_totals == null:
		return
	var attacker_non_ranged_base: int = int(attacker_hit_totals.get("non_ranged_base", 0))
	var attacker_non_ranged_scaled: int = int(attacker_hit_totals.get("non_ranged_scaled", 0))
	var attacker_ranged: int = int(attacker_hit_totals.get("ranged", 0))
	var defender_non_ranged_base: int = int(defender_hit_totals.get("non_ranged_base", 0))
	var defender_non_ranged_scaled: int = int(defender_hit_totals.get("non_ranged_scaled", 0))
	var defender_ranged: int = int(defender_hit_totals.get("ranged", 0))
	var attacker_kill_total := _sum_dict(attacker_kills)
	var defender_kill_total := _sum_dict(defender_kills)
	var attacker_total_hits := attacker_non_ranged_scaled + attacker_ranged
	var defender_total_hits := defender_non_ranged_scaled + defender_ranged
	var attacker_kill_pct := _calc_pct(attacker_kill_total, attacker_total_hits)
	var defender_kill_pct := _calc_pct(defender_kill_total, defender_total_hits)
	DebugLogger.log("BattleCalculation", "Round " + str(round_number))
	DebugLogger.log("BattleCalculation", attacker_label + ": Non-ranged=" + str(attacker_non_ranged_base) + " scaled=" + str(attacker_non_ranged_scaled) + ", Ranged=" + str(attacker_ranged) + ", Kills=" + str(attacker_kill_total) + " (" + str(attacker_kill_pct) + "%)")
	DebugLogger.log("BattleCalculation", defender_label + ": Non-ranged=" + str(defender_non_ranged_base) + " scaled=" + str(defender_non_ranged_scaled) + ", Ranged=" + str(defender_ranged) + ", Kills=" + str(defender_kill_total) + " (" + str(defender_kill_pct) + "%)")

func _sum_dict(dict: Dictionary) -> int:
	var total := 0
	for key in dict:
		total += int(dict[key])
	return total

func _calc_pct(value: int, base: int) -> int:
	if base <= 0:
		return 0
	return int(round((float(value) / float(base)) * 100.0))

func _log_battle_phase_section(sector_label: String, snapshot: Dictionary, values: Dictionary, empty_text: String) -> void:
	DebugLogger.log("BattleCalculation", sector_label)
	var sorted_units := _collect_ordered_units(snapshot, values)
	var total_value := 0
	var printed := false
	for unit_type in sorted_units:
		var entry = values.get(unit_type, 0)
		var amount := 0
		var unit_count := int(snapshot.get(unit_type, 0))
		if entry is Dictionary:
			amount = int(entry.get("hits", 0))
			if entry.has("count"):
				unit_count = int(entry.get("count", unit_count))
		else:
			amount = int(entry)
		var unit_name = SoldierTypeEnum.type_to_string(unit_type)
		DebugLogger.log("BattleCalculation", "%s: %d (%d)" % [unit_name, unit_count, amount], 1)
		total_value += amount
		printed = true
	if not printed:
		DebugLogger.log("BattleCalculation", "  " + empty_text)
	else:
		DebugLogger.log("BattleCalculation", "Total: " + str(total_value))

func _collect_ordered_units(snapshot: Dictionary, values: Dictionary) -> Array:
	var ordered: Array = []
	var seen := {}
	for key in snapshot.keys():
		if int(snapshot[key]) <= 0:
			continue
		ordered.append(key)
		seen[key] = true
	for key in values.keys():
		if seen.has(key):
			continue
		ordered.append(key)
		seen[key] = true
	ordered.sort_custom(func(a, b): return _unit_order_index(a) < _unit_order_index(b))
	return ordered

func _unit_order_index(unit_type: SoldierTypeEnum.Type) -> int:
	var order := SoldierTypeEnum.get_all_types()
	for i in range(order.size()):
		if order[i] == unit_type:
			return i
	return order.size()

func _record_unit_hits(hit_log: Dictionary, unit_type: SoldierTypeEnum.Type, unit_count: int, hits: int) -> void:
	if not hit_log.has(unit_type):
		hit_log[unit_type] = {
			"count": unit_count,
			"hits": hits
		}
	else:
		var entry = hit_log[unit_type]
		if entry is Dictionary:
			entry["hits"] = int(entry.get("hits", 0)) + hits
		else:
			hit_log[unit_type] = {
				"count": unit_count,
				"hits": int(entry) + hits
			}
func _record_unit_stats(stats_accumulator: Dictionary, unit_type: SoldierTypeEnum.Type, attempts: int, hits: int) -> void:
	if not stats_accumulator.has(unit_type):
		stats_accumulator[unit_type] = {
			"attempts": 0,
			"hits": 0
		}
	var entry = stats_accumulator[unit_type]
	entry["attempts"] = int(entry.get("attempts", 0)) + int(attempts)
	entry["hits"] = int(entry.get("hits", 0)) + int(hits)
	stats_accumulator[unit_type] = entry

func _accumulate_hit_totals(hit_totals, is_ranged: bool, base_hits: int, scaled_hits: int) -> void:
	if hit_totals == null:
		return
	if is_ranged:
		hit_totals["ranged"] = int(hit_totals.get("ranged", 0)) + scaled_hits
	else:
		hit_totals["non_ranged_base"] = int(hit_totals.get("non_ranged_base", 0)) + base_hits
		hit_totals["non_ranged_scaled"] = int(hit_totals.get("non_ranged_scaled", 0)) + scaled_hits

func _new_hit_totals() -> Dictionary:
	return {
		"non_ranged_base": 0,
		"non_ranged_scaled": 0,
		"ranged": 0
	}

func _log_effectiveness_stats(header: String, stats: Dictionary) -> void:
	if not DebugLogger.is_category_enabled("BattleCalculation"):
		return
	DebugLogger.log("BattleCalculation", header)
	if stats.is_empty():
		DebugLogger.log("BattleCalculation", "  No attacks recorded")
		return
	var ordered := stats.keys()
	ordered.sort_custom(func(a, b): return _unit_order_index(a) < _unit_order_index(b))
	for unit_type in ordered:
		var entry = stats[unit_type]
		var attempts := float(entry.get("attempts", 0))
		var hits := float(entry.get("hits", 0))
		var effectiveness := 0.0
		if attempts > 0.0:
			effectiveness = (hits / attempts) * 100.0
		var name := SoldierTypeEnum.type_to_string(unit_type)
		DebugLogger.log("BattleCalculation", "%s: %.1f%% (%d/%d)" % [name, snappedf(effectiveness, 0.1), int(hits), int(attempts)], 1)

# Convenience function for applying battle losses to actual Army objects
func apply_battle_losses_to_armies(attacking_armies: Array, defending_armies: Array, report: BattleReport) -> void:
	"""Apply proportional losses to the actual Army objects that participated in battle"""
	
	# Calculate total original sizes
	var total_attacker_size = 0
	var total_defender_size = 0
	
	for army in attacking_armies:
		if army != null:
			total_attacker_size += army.get_composition().get_total_soldiers()
	
	for army in defending_armies:
		if army != null:
			total_defender_size += army.get_composition().get_total_soldiers()
	
	# Apply proportional losses to attacking armies
	for army in attacking_armies:
		if army == null:
			continue
		
		var army_comp = army.get_composition()
		var army_size = army_comp.get_total_soldiers()
		
		if total_attacker_size > 0 and army_size > 0:
			var proportion = float(army_size) / float(total_attacker_size)
			_apply_proportional_losses(army_comp, report.attacker_losses, proportion)
	
	# Apply proportional losses to defending armies
	for army in defending_armies:
		if army == null:
			continue
		
		var army_comp = army.get_composition()
		var army_size = army_comp.get_total_soldiers()
		
		if total_defender_size > 0 and army_size > 0:
			var proportion = float(army_size) / float(total_defender_size)
			_apply_proportional_losses(army_comp, report.defender_losses, proportion)

func _apply_proportional_losses(composition: ArmyComposition, total_losses: Dictionary, proportion: float) -> void:
	"""Apply proportional losses to a specific army composition"""
	for unit_type in total_losses:
		var total_loss = total_losses[unit_type]
		var army_loss = int(round(total_loss * proportion))
		composition.remove_soldiers(unit_type, army_loss)

# Test function for verifying the battle system
static func run_test_battle() -> void:
	"""Run a test battle to verify the system works"""
	DebugLogger.log("BattleCalculation", "=== Battle System Test ===")
	
	var simulator = BattleSimulator.new()
	
	# Create test army compositions
	var attacker_comp = ArmyComposition.new()
	attacker_comp.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, 20)
	attacker_comp.set_soldier_count(SoldierTypeEnum.Type.KNIGHTS, 1)
	
	var defender_comp = ArmyComposition.new()
	defender_comp.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, 15)
	defender_comp.set_soldier_count(SoldierTypeEnum.Type.ARCHERS, 5)
	
	DebugLogger.log("BattleCalculation", "Attacker: " + attacker_comp.get_composition_string())
	DebugLogger.log("BattleCalculation", "Defender: " + defender_comp.get_composition_string())
	
	# Run battle
	var attacking_armies = [attacker_comp]
	var defending_armies = []
	
	var report = simulator.simulate_battle(attacking_armies, defending_armies, defender_comp)
	
	DebugLogger.log("BattleCalculation", "Battle Result: " + report.winner)
	DebugLogger.log("BattleCalculation", "Rounds: " + str(report.rounds))
	DebugLogger.log("BattleCalculation", "Attacker Losses: " + str(report.attacker_losses))
	DebugLogger.log("BattleCalculation", "Defender Losses: " + str(report.defender_losses))
	DebugLogger.log("BattleCalculation", "Final Attacker: " + str(report.final_attacker))
	DebugLogger.log("BattleCalculation", "Final Defender: " + str(report.final_defender))
	DebugLogger.log("BattleCalculation", "=== End Test ===")
	
	return
