extends Node
class_name AnimatedBattleSimulator

# Signals for battle events
signal round_completed(round_data: Dictionary)
signal battle_finished(report: BattleSimulator.BattleReport)
signal ai_withdrawal_started

# Battle state
var battle_simulator: BattleSimulator
var battle_timer: Timer
var is_battle_running: bool = false
var is_withdrawing: bool = false
var withdrawal_rounds_remaining: int = 0
var mobility_withdrawal_rounds_remaining: int = 0
var attacker_can_withdraw: bool = false
var defender_can_withdraw: bool = false
var withdrawing_side: int = 0 # 0 none, 1 attacker, 2 defender

# Current battle data
var current_attackers: Dictionary
var current_defenders: Dictionary
var original_attackers: Dictionary
var original_defenders: Dictionary
var current_round: int = 0
var max_rounds: int = 1000
var attacker_efficiency: int = 100
var defender_efficiency: int = 100
var region_garrison: ArmyComposition = null
var terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND
var castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE
var castle_defense_override: int = -1
var current_garrison_composition: Dictionary = {}
var is_siege_battle: bool = false
var attacker_effectiveness_ratio: float = 0.0

func _ready():
	battle_simulator = BattleSimulator.new()
	
	# Create timer for round delays
	battle_timer = Timer.new()
	battle_timer.wait_time = GameParameters.BATTLE_ROUND_TIME
	battle_timer.timeout.connect(_process_next_round)
	battle_timer.one_shot = true
	add_child(battle_timer)

func set_round_time(seconds: float) -> void:
	battle_timer.wait_time = seconds
	if is_battle_running:
		battle_timer.start()

func start_animated_battle(attacking_armies: Array, defending_armies: Array, region_garrison: ArmyComposition = null, attacker_efficiency: int = 100, defender_efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE, attacker_can_withdraw: bool = false, defender_can_withdraw: bool = false, castle_defense_bonus_override: int = -1, attacker_effectiveness_ratio: float = 0.0) -> void:
	"""Start an animated battle with round-by-round updates"""
	if is_battle_running:
		DebugLogger.log("BattleAnimation", "Battle already running!")
		return
	
	is_battle_running = true
	current_round = 0
	is_withdrawing = false
	withdrawal_rounds_remaining = 0
	mobility_withdrawal_rounds_remaining = 0
	withdrawing_side = 0
	self.attacker_can_withdraw = attacker_can_withdraw
	self.defender_can_withdraw = defender_can_withdraw
	
	# Store efficiency values and garrison reference
	self.attacker_efficiency = attacker_efficiency
	self.defender_efficiency = defender_efficiency
	self.region_garrison = region_garrison
	self.terrain_type = terrain_type
	self.castle_type = castle_type
	self.attacker_can_withdraw = attacker_can_withdraw
	self.defender_can_withdraw = defender_can_withdraw
	self.castle_defense_override = castle_defense_bonus_override
	self.attacker_effectiveness_ratio = clampf(attacker_effectiveness_ratio, 0.0, 1.0)
	is_siege_battle = castle_type != CastleTypeEnum.Type.NONE
	DebugLogger.log("BattleAnimation", "Battle start flags: attacker_can_withdraw=" + str(attacker_can_withdraw) + ", defender_can_withdraw=" + str(defender_can_withdraw))
	
	# Merge all attacking forces
	current_attackers = battle_simulator._merge_compositions(attacking_armies)
	
	# Merge all defending forces (including garrison)
	var all_defenders = defending_armies.duplicate()
	if region_garrison != null and not region_garrison.is_empty():
		all_defenders.append(region_garrison)
	current_defenders = battle_simulator._merge_compositions(all_defenders)
	current_garrison_composition = battle_simulator._create_garrison_composition(region_garrison)
	
	# Store original compositions for loss calculation
	original_attackers = battle_simulator._copy_composition_dict(current_attackers)
	original_defenders = battle_simulator._copy_composition_dict(current_defenders)
	
	DebugLogger.log("BattleAnimation", "Starting animated battle...")
	DebugLogger.log("BattleAnimation", "Attackers: " + str(current_attackers))
	DebugLogger.log("BattleAnimation", "Defenders: " + str(current_defenders))
	
	# Process ranged opening volley before standard rounds
	_process_ranged_opening_volley()
	
	# Start the first round after a brief delay
	battle_timer.start()

func _process_next_round() -> void:
	"""Process one round of combat and emit updates"""
	if not is_battle_running:
		return
	
	current_round += 1
	
	# Check if battle should end
	var attacker_size = battle_simulator._army_size(current_attackers)
	var defender_size = battle_simulator._army_size(current_defenders)
	
	if attacker_size <= 0 or defender_size <= 0 or current_round >= max_rounds:
		_finish_battle()
		return
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Handle withdrawal round differently
	if is_withdrawing:
		_process_withdrawal_round(rng)
		return
	
	if _try_start_withdrawal(rng):
		return
	
	var attacker_snapshot = current_attackers.duplicate()
	var defender_snapshot = current_defenders.duplicate()
	
	# Attack phases - unit-by-unit with trait-based targeting
	var attacker_effectiveness_value = attacker_effectiveness_ratio if is_siege_battle else 0.0
	var attacker_hit_totals = null
	var defender_hit_totals = null
	if DebugLogger.is_category_enabled("BattleCalculation"):
		attacker_hit_totals = battle_simulator._new_hit_totals()
		defender_hit_totals = battle_simulator._new_hit_totals()
	var attacker_kills = battle_simulator._process_unit_attacks(current_attackers, current_defenders, rng, attacker_efficiency, terrain_type, castle_type, null, null, castle_defense_override, attacker_effectiveness_value, is_siege_battle, attacker_hit_totals)
	
	# Defense phase - separate garrison and army processing for defenders
	var defender_kills = {}
	
	# Process garrison attacks at 100% efficiency if garrison exists
	if not current_garrison_composition.is_empty():
		var garrison_kills = battle_simulator._process_unit_attacks(current_garrison_composition, current_attackers, rng, 100, terrain_type, CastleTypeEnum.Type.NONE, null, null, -1, -1, is_siege_battle, defender_hit_totals)
		battle_simulator._merge_kill_results(defender_kills, garrison_kills)
	
	# Process defending army attacks at their efficiency if any defending armies exist
	var armies_composition = _get_armies_from_defenders()
	if not armies_composition.is_empty():
		var army_kills = battle_simulator._process_unit_attacks(armies_composition, current_attackers, rng, defender_efficiency, terrain_type, CastleTypeEnum.Type.NONE, null, null, -1, -1, is_siege_battle, defender_hit_totals)
		battle_simulator._merge_kill_results(defender_kills, army_kills)
	
	# Apply kills simultaneously
	var attacker_casualties = {}
	var defender_casualties = {}
	
	for unit_type in attacker_kills:
		var kills = attacker_kills[unit_type]
		var available = current_defenders.get(unit_type, 0)
		var actual_kills = min(kills, available)
		current_defenders[unit_type] = available - actual_kills
		if current_defenders[unit_type] <= 0:
			current_defenders.erase(unit_type)
		if actual_kills > 0:
			defender_casualties[unit_type] = actual_kills
	
	for unit_type in defender_kills:
		var kills = defender_kills[unit_type]
		var available = current_attackers.get(unit_type, 0)
		var actual_kills = min(kills, available)
		current_attackers[unit_type] = available - actual_kills
		if current_attackers[unit_type] <= 0:
			current_attackers.erase(unit_type)
		if actual_kills > 0:
			attacker_casualties[unit_type] = actual_kills
	
	_deduct_garrison_losses_from_snapshot(attacker_kills, defender_snapshot)
	
	# Calculate total hits for display (sum of all kills)
	var attacker_hits = 0
	for unit_type in attacker_kills:
		attacker_hits += attacker_kills[unit_type]
	var defender_hits = 0
	for unit_type in defender_kills:
		defender_hits += defender_kills[unit_type]
	
	# Create round data for UI updates
	var round_data = {
		"round": current_round,
		"attacker_hits": attacker_hits,
		"defender_hits": defender_hits,
		"attacker_casualties": attacker_casualties,
		"defender_casualties": defender_casualties,
		"current_attackers": current_attackers.duplicate(),
		"current_defenders": current_defenders.duplicate(),
		"attacker_size": battle_simulator._army_size(current_attackers),
		"defender_size": battle_simulator._army_size(current_defenders)
	}
	
	# Emit round completion signal
	round_completed.emit(round_data)
	
	DebugLogger.log("BattleAnimation", "Round " + str(current_round) + " - Attacker hits: " + str(attacker_hits) + ", Defender hits: " + str(defender_hits))
	if DebugLogger.is_category_enabled("BattleCalculation"):
		battle_simulator._log_round_totals(current_round, "Attackers", "Defenders", attacker_hit_totals, defender_hit_totals, attacker_kills, defender_kills, attacker_snapshot, defender_snapshot)
	
	# Schedule next round
	battle_timer.start()

func _finish_battle() -> void:
	"""Complete the battle and emit final results"""
	is_battle_running = false
	
	# Determine winner
	var attacker_size = battle_simulator._army_size(current_attackers)
	var defender_size = battle_simulator._army_size(current_defenders)
	
	var winner: String
	if attacker_size > 0 and defender_size == 0:
		winner = "Attackers"
	elif defender_size > 0 and attacker_size == 0:
		winner = "Defenders"
	else:
		winner = "Draw"
	
	# Calculate total losses
	var attacker_losses = battle_simulator._calculate_losses(original_attackers, current_attackers)
	var defender_losses = battle_simulator._calculate_losses(original_defenders, current_defenders)
	
	# Create final report
	var report = BattleSimulator.BattleReport.new()
	if withdrawing_side == 1:
		report.winner = "Withdrawal"
	elif withdrawing_side == 2:
		report.winner = "Attackers"
	else:
		report.winner = winner
	report.rounds = current_round
	report.attacker_losses = attacker_losses
	report.defender_losses = defender_losses
	report.final_attacker = current_attackers
	report.final_defender = current_defenders
	report.withdrawing_side = withdrawing_side
	
	DebugLogger.log("BattleAnimation", "Battle finished! Winner: " + winner + " in " + str(current_round) + " rounds")
	
	# Emit final results
	battle_finished.emit(report)

func _get_armies_from_defenders() -> Dictionary:
	"""Get the army composition portion of defenders (excluding garrison)"""
	if current_garrison_composition.is_empty():
		return current_defenders.duplicate()
	var armies_only := {}
	for unit_type in current_defenders:
		var total_count = int(current_defenders[unit_type])
		var garrison_count = int(current_garrison_composition.get(unit_type, 0))
		var army_count = total_count - garrison_count
		if army_count > 0:
			armies_only[unit_type] = army_count
	return armies_only

func _deduct_garrison_losses_from_snapshot(attacker_kills: Dictionary, defender_snapshot: Dictionary) -> void:
	if current_garrison_composition.is_empty():
		return
	for unit_type in attacker_kills:
		var kills = int(attacker_kills[unit_type])
		if kills <= 0:
			continue
		var garrison_before = int(current_garrison_composition.get(unit_type, 0))
		if garrison_before <= 0:
			continue
		var total_before = int(defender_snapshot.get(unit_type, 0))
		if total_before <= 0:
			continue
		var garrison_loss = int(round(float(kills) * float(garrison_before) / float(total_before)))
		garrison_loss = clampi(garrison_loss, 0, garrison_before)
		var remaining = garrison_before - garrison_loss
		if remaining > 0:
			current_garrison_composition[unit_type] = remaining
		else:
			current_garrison_composition.erase(unit_type)

func _compute_power(comp_dict: Dictionary) -> int:
	var total := 0
	for ut in comp_dict.keys():
		var qty: int = int(comp_dict[ut])
		if qty > 0:
			total += GameParameters.get_unit_stat(ut, "power") * qty
	return total

func _apply_withdrawal_casualties_to_defenders(kills: Dictionary, defender_casualties: Dictionary) -> void:
	for unit_type in kills:
		var kill_count = int(kills[unit_type])
		if kill_count <= 0:
			continue
		var total_def = int(current_defenders.get(unit_type, 0))
		var garrison_count = int(current_garrison_composition.get(unit_type, 0))
		var army_available = max(0, total_def - garrison_count)
		if army_available <= 0:
			continue
		var actual_kills = min(kill_count, army_available)
		current_defenders[unit_type] = total_def - actual_kills
		if current_defenders[unit_type] <= 0:
			current_defenders.erase(unit_type)
		if actual_kills > 0:
			defender_casualties[unit_type] = actual_kills

func _try_start_withdrawal(rng: RandomNumberGenerator) -> bool:
	if is_withdrawing:
		return false
	var atk_power: int = _compute_power(current_attackers)
	var def_power: int = _compute_power(current_defenders)
	if atk_power <= 0 or def_power <= 0:
		return false
	var withdrawing: int = 0
	var weaker: int = atk_power
	var stronger: int = def_power
	if atk_power < def_power:
		withdrawing = 1
		weaker = atk_power
		stronger = def_power
	elif def_power < atk_power:
		withdrawing = 2
		weaker = def_power
		stronger = atk_power
	else:
		return false
	if withdrawing == 1 and not attacker_can_withdraw:
		return false
	if withdrawing == 2:
		if not defender_can_withdraw:
			return false
		if _get_armies_from_defenders().is_empty():
			return false
	var ratio := float(weaker) / float(stronger)
	if ratio > GameParameters.AI_WITHDRAW_POWER_THRESHOLD:
		return false

	if ratio <= GameParameters.AI_WITHDRAW_MAX_POWER_DIFFERENCE:
		DebugLogger.log("BattleAnimation", "Forced withdrawal triggered. side=" + str(withdrawing) + " atk_power=" + str(atk_power) + " def_power=" + str(def_power) + " ratio=" + str(snappedf(ratio, 0.003)))
		ai_withdrawal_started.emit()
		start_withdrawal_round(withdrawing)
		return true
	var gap := 1.0 - ratio
	var chance: float = clampf(gap, 0.0, 1.0)
	var roll := rng.randf()
	if roll < chance:
		DebugLogger.log("BattleAnimation", "Withdrawal roll passed. side=" + str(withdrawing) + " atk_power=" + str(atk_power) + " def_power=" + str(def_power) + " ratio=" + str(snappedf(ratio, 0.003)) + " roll=" + str(snappedf(roll, 0.003)) + " chance=" + str(snappedf(chance, 0.003)))
		ai_withdrawal_started.emit()
		start_withdrawal_round(withdrawing)
		return true
	return false

func _process_mobility_attacks(defending_army: Dictionary, attacking_targets: Dictionary, rng: RandomNumberGenerator, efficiency: int = 100, apply_castle_defense: bool = true, attack_effectiveness_ratio: float = 0.0) -> Dictionary:
	"""Process attacks from only mobility trait units during mobility withdrawal rounds"""
	var mobility_kills = {}
	var efficiency_modifier = efficiency / 100.0
	var defense_castle := castle_type if apply_castle_defense else CastleTypeEnum.Type.NONE
	var defense_override := castle_defense_override if apply_castle_defense else -1
	var clamped_effectiveness := attack_effectiveness_ratio if is_siege_battle else 1.0
	clamped_effectiveness = clampf(clamped_effectiveness, 0.0, 1.0)
	var hit_records := []
	var total_non_ranged_hits := 0
	
	# Only process units with mobility trait
	for defender_unit_type in defending_army:
		var defender_count = defending_army[defender_unit_type]
		if defender_count <= 0:
			continue
			
		# Check if this unit has mobility trait
		if is_siege_battle or not GameParameters.unit_has_trait(defender_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_3):  # mobility
			continue
			
		# Calculate hits for this mobility unit type
		var base_attack_chance = GameParameters.get_unit_stat(defender_unit_type, "attack") / 100.0
		var modified_attack_chance = base_attack_chance * efficiency_modifier
		
		# Apply terrain bonuses
		modified_attack_chance *= battle_simulator._get_terrain_attack_multiplier(defender_unit_type, terrain_type, castle_type, is_siege_battle)
		
		# Apply multi-attack trait if present
		var effective_unit_count = defender_count
		if GameParameters.unit_has_trait(defender_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_6):  # multi_attack
			effective_unit_count *= 2
		
		var hits: int = battle_simulator._binomial_sample(rng, effective_unit_count, modified_attack_chance)
		var is_ranged_unit := GameParameters.unit_has_trait(defender_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_2)
		if not is_ranged_unit and clamped_effectiveness < 1.0:
			total_non_ranged_hits += hits
		hit_records.append({
			"unit_type": defender_unit_type,
			"hits": hits,
			"original_hits": hits,
			"is_ranged": is_ranged_unit,
			"effective_unit_count": effective_unit_count
		})
	
	if clamped_effectiveness < 1.0 and total_non_ranged_hits > 0:
		var scaled_hits := battle_simulator._apply_multiplier_stochastic(total_non_ranged_hits, clamped_effectiveness, rng)
		battle_simulator._scale_non_ranged_hit_records(hit_records, scaled_hits, rng)
	
	for record in hit_records:
		var defender_unit_type = record["unit_type"]
		var hits: int = int(record["hits"])
		if hits <= 0:
			continue
		
		# Determine valid targets based on traits
		var valid_targets = battle_simulator._get_valid_targets(defender_unit_type, defending_army, attacking_targets, is_siege_battle)
		
		if valid_targets.is_empty():
			continue
			
		# Distribute hits among valid targets
		var target_assigned = battle_simulator._distribute_hits_to_valid_targets(attacking_targets, valid_targets, hits, rng)
		
		# Apply long-spears bonus from the ACTING ATTACKER (defender_unit_type is the attacker in this context)
		if not is_siege_battle and GameParameters.unit_has_trait(defender_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_1):  # long_spears
			for target_unit_type in target_assigned:
				if GameParameters.is_cavalry_unit(target_unit_type):
					target_assigned[target_unit_type] = battle_simulator._apply_multiplier_stochastic(
						target_assigned[target_unit_type],
						GameParameters.LONG_SPEARS_CAVALRY_MULTIPLIER,
						rng
					)
		
		var target_kills = battle_simulator._defense_resolution_with_attacker_traits(target_assigned, defender_unit_type, rng, defense_castle, defense_override)
		
		# Merge kills into total
		battle_simulator._merge_kill_results(mobility_kills, target_kills)
	
	return mobility_kills

func _process_ranged_attacks(attacking_army: Dictionary, defending_targets: Dictionary, rng: RandomNumberGenerator, efficiency: int = 100, apply_castle_defense: bool = true) -> Dictionary:
	"""Process attacks from only ranged trait units during opening volley"""
	var ranged_kills = {}
	var efficiency_modifier = efficiency / 100.0
	var defense_castle := castle_type if apply_castle_defense else CastleTypeEnum.Type.NONE
	var defense_override := castle_defense_override if apply_castle_defense else -1
	
	# Only process units with ranged trait
	for attacker_unit_type in attacking_army:
		var attacker_count = attacking_army[attacker_unit_type]
		if attacker_count <= 0:
			continue
			
		# Check if this unit has ranged trait
		if not GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_2):  # ranged
			continue
			
		# Calculate hits for this ranged unit type
		var base_attack_chance = GameParameters.get_unit_stat(attacker_unit_type, "attack") / 100.0
		var modified_attack_chance = base_attack_chance * efficiency_modifier
		
		# Apply terrain bonuses
		modified_attack_chance *= battle_simulator._get_terrain_attack_multiplier(attacker_unit_type, terrain_type, castle_type, is_siege_battle)
		
		# Apply multi-attack trait if present
		var effective_unit_count = attacker_count
		if GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_6):  # multi_attack
			effective_unit_count *= 2
		
		var hits = battle_simulator._binomial_sample(rng, effective_unit_count, modified_attack_chance)
		
		if hits <= 0:
			continue
		
		# Determine valid targets based on traits
		var valid_targets = battle_simulator._get_valid_targets(attacker_unit_type, attacking_army, defending_targets, is_siege_battle)
		
		if valid_targets.is_empty():
			continue
			
		# Distribute hits among valid targets
		var target_assigned = battle_simulator._distribute_hits_to_valid_targets(defending_targets, valid_targets, hits, rng)
		
		# Apply long-spears bonus: double hits against cavalry if attacker has long-spears
		if not is_siege_battle and GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_1):  # long_spears
			for target_unit_type in target_assigned:
				if GameParameters.is_cavalry_unit(target_unit_type):
					target_assigned[target_unit_type] = battle_simulator._apply_multiplier_stochastic(
						target_assigned[target_unit_type],
						GameParameters.LONG_SPEARS_CAVALRY_MULTIPLIER,
						rng
					)
		
		var target_kills = battle_simulator._defense_resolution_with_attacker_traits(target_assigned, attacker_unit_type, rng, defense_castle, defense_override)
		
		# Merge kills into total
		battle_simulator._merge_kill_results(ranged_kills, target_kills)
	
	return ranged_kills

func _process_ranged_opening_volley() -> void:
	"""Process the ranged opening volley before standard battle rounds"""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Process attacker ranged attacks
	var attacker_ranged_kills = _process_ranged_attacks(current_attackers, current_defenders, rng, attacker_efficiency, true)
	
	# Process defender ranged attacks
	var defender_ranged_kills = {}
	
	# Process garrison ranged attacks at 100% efficiency if garrison exists
	if region_garrison != null and not region_garrison.is_empty():
		var garrison_dict = battle_simulator._merge_compositions([region_garrison])
		var garrison_ranged_kills = _process_ranged_attacks(garrison_dict, current_attackers, rng, 100, false)
		battle_simulator._merge_kill_results(defender_ranged_kills, garrison_ranged_kills)
	
	# Process defending army ranged attacks at their efficiency if any defending armies exist
	var armies_composition = _get_armies_from_defenders()
	if not armies_composition.is_empty():
		var army_ranged_kills = _process_ranged_attacks(armies_composition, current_attackers, rng, defender_efficiency, false)
		battle_simulator._merge_kill_results(defender_ranged_kills, army_ranged_kills)
	
	# Apply ranged volley kills simultaneously
	var attacker_casualties = {}
	var defender_casualties = {}
	
	# Apply attacker ranged kills to defenders
	for unit_type in attacker_ranged_kills:
		var kills = attacker_ranged_kills[unit_type]
		var available = current_defenders.get(unit_type, 0)
		var actual_kills = min(kills, available)
		current_defenders[unit_type] = available - actual_kills
		if current_defenders[unit_type] <= 0:
			current_defenders.erase(unit_type)
		if actual_kills > 0:
			defender_casualties[unit_type] = actual_kills
	
	# Apply defender ranged kills to attackers
	for unit_type in defender_ranged_kills:
		var kills = defender_ranged_kills[unit_type]
		var available = current_attackers.get(unit_type, 0)
		var actual_kills = min(kills, available)
		current_attackers[unit_type] = available - actual_kills
		if current_attackers[unit_type] <= 0:
			current_attackers.erase(unit_type)
		if actual_kills > 0:
			attacker_casualties[unit_type] = actual_kills
	
	# Calculate total hits for display
	var attacker_hits = 0
	for unit_type in attacker_ranged_kills:
		attacker_hits += attacker_ranged_kills[unit_type]
	var defender_hits = 0
	for unit_type in defender_ranged_kills:
		defender_hits += defender_ranged_kills[unit_type]
	
	# Emit ranged volley data if there were any ranged units
	if attacker_hits > 0 or defender_hits > 0:
		var volley_data = {
			"round": 0,  # Round 0 = ranged volley
			"attacker_hits": attacker_hits,
			"defender_hits": defender_hits,
			"attacker_casualties": attacker_casualties,
			"defender_casualties": defender_casualties,
			"current_attackers": current_attackers.duplicate(),
			"current_defenders": current_defenders.duplicate(),
			"attacker_size": battle_simulator._army_size(current_attackers),
			"defender_size": battle_simulator._army_size(current_defenders),
			"is_ranged_volley": true
		}
		
		round_completed.emit(volley_data)
		DebugLogger.log("BattleAnimation", "Ranged volley completed - Attacker ranged hits: " + str(attacker_hits) + ", Defender ranged hits: " + str(defender_hits))

func stop_battle() -> void:
	"""Force stop the current battle"""
	if is_battle_running:
		is_battle_running = false
		is_withdrawing = false
		withdrawal_rounds_remaining = 0
		mobility_withdrawal_rounds_remaining = 0
		withdrawing_side = 0
		battle_timer.stop()
		DebugLogger.log("BattleAnimation", "Battle stopped")

func is_running() -> bool:
	"""Check if a battle is currently running"""
	return is_battle_running

func start_withdrawal_round(side: int) -> void:
	"""Start withdrawal rounds where the opposing side gets free hits"""
	if not is_battle_running or is_withdrawing or side == 0:
		return
	
	is_withdrawing = true
	withdrawing_side = side
	withdrawal_rounds_remaining = GameParameters.WITHDRAWAL_FREE_HIT_ROUNDS
	mobility_withdrawal_rounds_remaining = GameParameters.MOBILITY_EXTRA_WITHDRAWAL_ROUNDS
	DebugLogger.log("BattleAnimation", "Starting withdrawal with " + str(withdrawal_rounds_remaining) + " free hit rounds and " + str(mobility_withdrawal_rounds_remaining) + " mobility rounds...")
	DebugLogger.log("Withdrawal", "AnimatedBattleSimulator.start_withdrawal_round side=" + str(side) + " standard=" + str(withdrawal_rounds_remaining) + " mobility=" + str(mobility_withdrawal_rounds_remaining) + " atk_size=" + str(battle_simulator._army_size(current_attackers)) + " def_size=" + str(battle_simulator._army_size(current_defenders)))
	battle_timer.start()

func _process_withdrawal_round(rng: RandomNumberGenerator) -> void:
	"""Process a withdrawal round where only the non-withdrawing side attacks"""
	var is_mobility_round = withdrawal_rounds_remaining <= 0 and mobility_withdrawal_rounds_remaining > 0
	var round_type = "mobility" if is_mobility_round else "standard"
	var attacker_effectiveness_value = attacker_effectiveness_ratio if is_siege_battle else 0.0
	var attacker_hit_totals = null
	var defender_hit_totals = null
	if DebugLogger.is_category_enabled("BattleCalculation"):
		attacker_hit_totals = battle_simulator._new_hit_totals()
		defender_hit_totals = battle_simulator._new_hit_totals()
	DebugLogger.log("BattleAnimation", "Processing " + round_type + " withdrawal round " + str(current_round) + " (" + str(withdrawal_rounds_remaining) + " standard, " + str(mobility_withdrawal_rounds_remaining) + " mobility remaining)")
	
	var attacker_hits = 0
	var defender_hits = 0
	var attacker_kills = {}
	var defender_kills = {}
	
	if withdrawing_side == 1:
		if is_mobility_round:
			if not current_garrison_composition.is_empty():
				var mobility_garrison_kills = _process_mobility_attacks(current_garrison_composition, current_attackers, rng, 100, false, -1.0)
				battle_simulator._merge_kill_results(defender_kills, mobility_garrison_kills)
			var armies_comp = _get_armies_from_defenders()
			if not armies_comp.is_empty():
				var mobility_army_kills = _process_mobility_attacks(armies_comp, current_attackers, rng, defender_efficiency, false, -1.0)
				battle_simulator._merge_kill_results(defender_kills, mobility_army_kills)
		else:
			if not current_garrison_composition.is_empty():
				var garrison_kills = battle_simulator._process_unit_attacks(current_garrison_composition, current_attackers, rng, 100, terrain_type, CastleTypeEnum.Type.NONE, null, null, -1, -1.0, is_siege_battle, defender_hit_totals)
				battle_simulator._merge_kill_results(defender_kills, garrison_kills)
			var armies_standard = _get_armies_from_defenders()
			if not armies_standard.is_empty():
				var army_kills = battle_simulator._process_unit_attacks(armies_standard, current_attackers, rng, defender_efficiency, terrain_type, CastleTypeEnum.Type.NONE, null, null, -1, -1.0, is_siege_battle, defender_hit_totals)
				battle_simulator._merge_kill_results(defender_kills, army_kills)
	else:
		var armies_only = _get_armies_from_defenders()
		if not armies_only.is_empty():
			if is_mobility_round:
				attacker_kills = _process_mobility_attacks(current_attackers, armies_only, rng, attacker_efficiency, true, attacker_effectiveness_value)
			else:
				attacker_kills = battle_simulator._process_unit_attacks(current_attackers, armies_only, rng, attacker_efficiency, terrain_type, castle_type, null, null, castle_defense_override, attacker_effectiveness_value, is_siege_battle, attacker_hit_totals)
	
	var attacker_casualties = {}
	var defender_casualties = {}
	if withdrawing_side == 1:
		for unit_type in defender_kills:
			var kills = defender_kills[unit_type]
			var available = current_attackers.get(unit_type, 0)
			var actual_kills = min(kills, available)
			current_attackers[unit_type] = available - actual_kills
			if current_attackers[unit_type] <= 0:
				current_attackers.erase(unit_type)
			if actual_kills > 0:
				attacker_casualties[unit_type] = actual_kills
			attacker_hits += actual_kills
	else:
		_apply_withdrawal_casualties_to_defenders(attacker_kills, defender_casualties)
		for unit_type in attacker_kills:
			defender_hits += attacker_kills[unit_type]

	if is_mobility_round:
		mobility_withdrawal_rounds_remaining -= 1
	else:
		withdrawal_rounds_remaining -= 1
	
	var round_data = {
		"round": current_round,
		"attacker_hits": attacker_hits,
		"defender_hits": defender_hits,
		"attacker_casualties": attacker_casualties,
		"defender_casualties": defender_casualties,
		"current_attackers": current_attackers.duplicate(),
		"current_defenders": current_defenders.duplicate(),
		"attacker_size": battle_simulator._army_size(current_attackers),
		"defender_size": battle_simulator._army_size(current_defenders),
		"is_withdrawal": true,
		"withdrawal_rounds_remaining": withdrawal_rounds_remaining,
		"mobility_withdrawal_rounds_remaining": mobility_withdrawal_rounds_remaining,
		"is_ranged_volley": false
	}
	
	round_completed.emit(round_data)
	
	var defenders_armies_size = battle_simulator._army_size(_get_armies_from_defenders())
	DebugLogger.log("Withdrawal", "AnimatedBattleSimulator._process_withdrawal_round side=" + str(withdrawing_side) + " round=" + str(current_round) + " type=" + round_type + " atk_size=" + str(battle_simulator._army_size(current_attackers)) + " def_size=" + str(battle_simulator._army_size(current_defenders)) + " def_army_size=" + str(defenders_armies_size) + " std_left=" + str(withdrawal_rounds_remaining) + " mob_left=" + str(mobility_withdrawal_rounds_remaining))
	if (withdrawal_rounds_remaining <= 0 and mobility_withdrawal_rounds_remaining <= 0) or battle_simulator._army_size(current_attackers) <= 0 or defenders_armies_size <= 0:
		_finish_withdrawal()
		return
	
	battle_timer.start()

func _finish_withdrawal() -> void:
	"""Complete a withdrawal and emit final results"""
	var side := withdrawing_side
	is_battle_running = false
	is_withdrawing = false
	withdrawing_side = 0
	
	# Calculate total losses during the battle (including withdrawal round)
	var attacker_losses = battle_simulator._calculate_losses(original_attackers, current_attackers)
	var defender_losses = battle_simulator._calculate_losses(original_defenders, current_defenders)
	
	# Create final report with withdrawal outcome
	var report = BattleSimulator.BattleReport.new()
	report.winner = "Withdrawal"
	report.rounds = current_round
	report.attacker_losses = attacker_losses
	report.defender_losses = defender_losses
	report.final_attacker = current_attackers
	report.final_defender = current_defenders
	report.withdrawing_side = side
	
	DebugLogger.log("BattleAnimation", "Withdrawal completed! Side=" + str(side) + " after " + str(current_round) + " rounds")
	DebugLogger.log("Withdrawal", "AnimatedBattleSimulator._finish_withdrawal side=" + str(side) + " atk_size=" + str(battle_simulator._army_size(current_attackers)) + " def_size=" + str(battle_simulator._army_size(current_defenders)) + " atk_losses=" + str(attacker_losses) + " def_losses=" + str(defender_losses))
	
	# Emit final results
	battle_finished.emit(report)
