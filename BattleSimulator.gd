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
	
	func _init():
		attacker_losses = {}
		defender_losses = {}
		final_attacker = {}
		final_defender = {}
		attacker_wounded = {}
		defender_wounded = {}
		withdrawing_side = 0

# Main battle function - accepts arrays of compositions for each side
func simulate_battle(attacking_armies: Array, defending_armies: Array, region_garrison: ArmyComposition = null, attacker_efficiency: int = 100, defender_efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE, attacker_label: String = "Attackers", defender_label: String = "Defenders", attacker_can_withdraw: bool = false, defender_can_withdraw: bool = false, castle_defense_bonus_override: int = -1) -> BattleReport:
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
	
	# Store original compositions for loss calculation
	var original_attackers = _copy_composition_dict(merged_attackers)
	var original_defenders = _copy_composition_dict(merged_defenders)
	
	var report = BattleReport.new()
	var rounds = 0
	var max_rounds = 1000
	
	# Ranged opening volley - both sides shoot simultaneously before main battle
	var attacker_ranged_kills = _process_ranged_unit_attacks(merged_attackers, merged_defenders, rng, attacker_efficiency, terrain_type, castle_type, attacker_stats, castle_defense_bonus_override)
	var defender_ranged_kills = {}
	
	# Process garrison ranged attacks at 100% efficiency if garrison exists
	if not current_garrison.is_empty():
		var garrison_ranged_kills = _process_ranged_unit_attacks(current_garrison, merged_attackers, rng, 100, terrain_type, CastleTypeEnum.Type.NONE, defender_stats, -1)
		_merge_kill_results(defender_ranged_kills, garrison_ranged_kills)
	
	# Process defending army ranged attacks at their efficiency if any defending armies exist
	var ranged_armies_only := _compute_army_composition(merged_defenders, current_garrison)
	if not ranged_armies_only.is_empty():
		var army_ranged_kills = _process_ranged_unit_attacks(ranged_armies_only, merged_attackers, rng, defender_efficiency, terrain_type, CastleTypeEnum.Type.NONE, defender_stats, -1)
		_merge_kill_results(defender_ranged_kills, army_ranged_kills)
	
	# Apply ranged volley kills simultaneously
	_apply_kills(merged_defenders, attacker_ranged_kills)
	_apply_kills(merged_attackers, defender_ranged_kills)

	var withdraw_side = _decide_withdrawal(merged_attackers, merged_defenders, current_garrison, attacker_can_withdraw, defender_can_withdraw)
	if withdraw_side != 0:
		var withdraw_rounds := _resolve_withdrawal_phase(merged_attackers, merged_defenders, current_garrison, attacker_efficiency, defender_efficiency, terrain_type, castle_type, rng, attacker_stats, defender_stats, withdraw_side, castle_defense_bonus_override)
		rounds += withdraw_rounds
		return _create_withdrawal_report(original_attackers, original_defenders, merged_attackers, merged_defenders, rounds, withdraw_side)
	
	# Battle loop
	while _army_size(merged_attackers) > 0 and _army_size(merged_defenders) > 0 and rounds < max_rounds:
		rounds += 1
		var attacker_snapshot := _copy_composition_dict(merged_attackers)
		var defender_snapshot := _copy_composition_dict(merged_defenders)
		var attacker_hit_log := {}
		
			# Attack phases - unit-by-unit with trait-based targeting
		var attacker_kills = _process_unit_attacks(merged_attackers, merged_defenders, rng, attacker_efficiency, terrain_type, castle_type, attacker_hit_log, attacker_stats, castle_defense_bonus_override)
		
		# Defense phase - separate garrison and army processing for defenders
		var defender_kills = {}
		var defender_hit_log := {}
		
		# Process garrison attacks at 100% efficiency if garrison exists
		if not current_garrison.is_empty():
			var garrison_kills = _process_unit_attacks(current_garrison, merged_attackers, rng, 100, terrain_type, CastleTypeEnum.Type.NONE, defender_hit_log, defender_stats, -1)
			_merge_kill_results(defender_kills, garrison_kills)
		
		# Process defending army attacks at their efficiency if any defending armies exist
		var defender_armies_only := _compute_army_composition(merged_defenders, current_garrison)
		if not defender_armies_only.is_empty():
			var army_kills = _process_unit_attacks(defender_armies_only, merged_attackers, rng, defender_efficiency, terrain_type, CastleTypeEnum.Type.NONE, defender_hit_log, defender_stats, -1)
			_merge_kill_results(defender_kills, army_kills)
		
		_log_battle_round_debug(rounds, attacker_label, defender_label, attacker_snapshot, defender_snapshot, attacker_hit_log, defender_hit_log, attacker_kills, defender_kills)
		
		# Apply kills simultaneously
		_apply_kills(merged_defenders, attacker_kills)
		_apply_kills(merged_attackers, defender_kills)
		_deduct_garrison_losses_from_snapshot(attacker_kills, defender_snapshot, current_garrison)

		var mid_withdraw_side = _decide_withdrawal(merged_attackers, merged_defenders, current_garrison, attacker_can_withdraw, defender_can_withdraw)
		if mid_withdraw_side != 0:
			var withdraw_extra_rounds := _resolve_withdrawal_phase(merged_attackers, merged_defenders, current_garrison, attacker_efficiency, defender_efficiency, terrain_type, castle_type, rng, attacker_stats, defender_stats, mid_withdraw_side, castle_defense_bonus_override)
			rounds += withdraw_extra_rounds
			return _create_withdrawal_report(original_attackers, original_defenders, merged_attackers, merged_defenders, rounds, mid_withdraw_side)
	
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
	_log_effectiveness_stats(attacker_label + " Stats", attacker_stats)
	_log_effectiveness_stats(defender_label + " Stats", defender_stats)
	
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

func _process_unit_attacks(attacking_army: Dictionary, defending_army: Dictionary, rng: RandomNumberGenerator, efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE, hit_log = null, stats_accumulator = null, castle_defense_bonus_override: int = -1) -> Dictionary:
	"""Process attacks unit-by-unit with trait-based targeting rules"""
	var total_kills = {}
	var efficiency_modifier = efficiency / 100.0
	
	# Process each attacking unit type
	for attacker_unit_type in attacking_army:
		var attacker_count = attacking_army[attacker_unit_type]
		if attacker_count <= 0:
			continue
			
		# Calculate hits for this unit type
		var base_attack_chance = GameParameters.get_unit_stat(attacker_unit_type, "attack") / 100.0
		var modified_attack_chance = base_attack_chance * efficiency_modifier
		
		# Apply terrain bonuses
		modified_attack_chance *= _get_terrain_attack_multiplier(attacker_unit_type, terrain_type, castle_type)
		
		# Apply multi-attack trait (units get 2 attacks instead of 1)
		var effective_unit_count = attacker_count
		if GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_6):  # multi_attack
			effective_unit_count *= 2
		
		var hits = _binomial_sample(rng, effective_unit_count, modified_attack_chance)
		
		if stats_accumulator != null:
			_record_unit_stats(stats_accumulator, attacker_unit_type, effective_unit_count, hits)
		
		if hits <= 0:
			continue
		
		if hit_log != null:
			_record_unit_hits(hit_log, attacker_unit_type, attacker_count, hits)
			
		# Determine valid targets based on traits
		var valid_targets = _get_valid_targets(attacker_unit_type, attacking_army, defending_army)
		
		if valid_targets.is_empty():
			continue
			
		# Distribute hits among valid targets
		var target_assigned = _distribute_hits_to_valid_targets(defending_army, valid_targets, hits, rng)
		
		# Apply long-spears bonus: double hits against cavalry if attacker has long-spears
		if GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_1):  # long_spears
			for defender_unit_type in target_assigned:
				if GameParameters.is_cavalry_unit(defender_unit_type):
					target_assigned[defender_unit_type] = _apply_multiplier_stochastic(target_assigned[defender_unit_type], GameParameters.LONG_SPEARS_CAVALRY_MULTIPLIER, rng)
		
		var target_kills = _defense_resolution_with_attacker_traits(target_assigned, attacker_unit_type, rng, castle_type, castle_defense_bonus_override)
		
		# Merge kills into total
		_merge_kill_results(total_kills, target_kills)
	
	return total_kills

func _process_mobility_attacks(defending_army: Dictionary, attacking_targets: Dictionary, rng: RandomNumberGenerator, efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE, stats_accumulator = null, castle_defense_bonus_override: int = -1) -> Dictionary:
	var mobility_kills := {}
	var efficiency_modifier = efficiency / 100.0
	for defender_unit_type in defending_army.keys():
		var defender_count = defending_army[defender_unit_type]
		if defender_count <= 0:
			continue
		if not GameParameters.unit_has_trait(defender_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_3):
			continue
		var base_attack_chance = GameParameters.get_unit_stat(defender_unit_type, "attack") / 100.0
		var modified_attack_chance = base_attack_chance * efficiency_modifier
		modified_attack_chance *= _get_terrain_attack_multiplier(defender_unit_type, terrain_type, castle_type)
		var effective_unit_count = defender_count
		if GameParameters.unit_has_trait(defender_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_6):
			effective_unit_count *= 2
		var hits = _binomial_sample(rng, effective_unit_count, modified_attack_chance)
		
		if stats_accumulator != null:
			_record_unit_stats(stats_accumulator, defender_unit_type, effective_unit_count, hits)
		if hits <= 0:
			continue
		var valid_targets = _get_valid_targets(defender_unit_type, defending_army, attacking_targets)
		if valid_targets.is_empty():
			continue
		var target_assigned = _distribute_hits_to_valid_targets(attacking_targets, valid_targets, hits, rng)
		if GameParameters.unit_has_trait(defender_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_1):
			for target_unit_type in target_assigned.keys():
				if GameParameters.is_cavalry_unit(target_unit_type):
					target_assigned[target_unit_type] = _apply_multiplier_stochastic(target_assigned[target_unit_type], GameParameters.LONG_SPEARS_CAVALRY_MULTIPLIER, rng)
		var target_kills = _defense_resolution_with_attacker_traits(target_assigned, defender_unit_type, rng, castle_type, castle_defense_bonus_override)
		_merge_kill_results(mobility_kills, target_kills)
	return mobility_kills

func _decide_withdrawal(current_attackers: Dictionary, current_defenders: Dictionary, current_garrison: Dictionary, attacker_can_withdraw: bool, defender_can_withdraw: bool) -> int:
	var atk_power := _compute_dict_power(current_attackers)
	var def_power := _compute_dict_power(current_defenders)
	if atk_power <= 0 or def_power <= 0:
		return 0
	var withdrawing_side := 0 # 1 = attacker, 2 = defender
	var weaker := atk_power
	var stronger := def_power
	if atk_power < def_power:
		withdrawing_side = 1
		weaker = atk_power
		stronger = def_power
	elif def_power < atk_power:
		withdrawing_side = 2
		weaker = def_power
		stronger = atk_power
	else:
		return 0
	if withdrawing_side == 1 and not attacker_can_withdraw:
		return 0
	if withdrawing_side == 2:
		if not defender_can_withdraw:
			return 0
		var armies_only := _get_armies_without_garrison(current_defenders, current_garrison)
		if armies_only.is_empty():
			return 0
	var ratio := float(weaker) / float(stronger)
	if ratio > GameParameters.AI_WITHDRAW_POWER_THRESHOLD:
		return 0
	var forced_ratio := GameParameters.AI_WITHDRAW_POWER_THRESHOLD - GameParameters.AI_WITHDRAW_MAX_POWER_DIFFERENCE
	if ratio <= forced_ratio:
		DebugLogger.log("Withdrawal", "BattleSimulator.decide_withdrawal forced side=" + str(withdrawing_side) + " atk_power=" + str(atk_power) + " def_power=" + str(def_power) + " ratio=" + str(snappedf(ratio, 0.003)))
		DebugLogger.log("BattleCalculation", "Forced withdrawal. side=" + str(withdrawing_side) + " atk_power=" + str(atk_power) + " def_power=" + str(def_power) + " ratio=" + str(snappedf(ratio, 0.003)))
		return withdrawing_side
	var chance: float = clampf(1.0 - ratio, 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll := rng.randf()
	DebugLogger.log("Withdrawal", "BattleSimulator.decide_withdrawal roll side=" + str(withdrawing_side) + " ratio=" + str(snappedf(ratio, 0.003)) + " chance=" + str(snappedf(chance, 0.003)) + " roll=" + str(snappedf(roll, 0.003)))
	DebugLogger.log("BattleCalculation", "Withdrawal check. side=" + str(withdrawing_side) + " atk_power=" + str(atk_power) + " def_power=" + str(def_power) + " ratio=" + str(snappedf(ratio, 0.003)) + " roll=" + str(snappedf(roll, 0.003)) + " chance=" + str(snappedf(chance, 0.003)))
	return withdrawing_side if roll < chance else 0

func _resolve_withdrawal_phase(current_attackers: Dictionary, current_defenders: Dictionary, current_garrison: Dictionary, attacker_efficiency: int, defender_efficiency: int, terrain_type: RegionTypeEnum.Type, castle_type: CastleTypeEnum.Type, rng: RandomNumberGenerator, attacker_stats: Dictionary, defender_stats: Dictionary, withdrawing_side: int, castle_defense_bonus_override: int = -1) -> int:
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
					var garrison_hits = _process_unit_attacks(garrison_dict, current_attackers, rng, 100, terrain_type, CastleTypeEnum.Type.NONE, null, defender_stats, -1)
					_merge_kill_results(kills, garrison_hits)
				if not armies_only.is_empty():
					var army_hits = _process_unit_attacks(armies_only, current_attackers, rng, defender_efficiency, terrain_type, CastleTypeEnum.Type.NONE, null, defender_stats, -1)
					_merge_kill_results(kills, army_hits)
				standard_rounds -= 1
			else:
				if not garrison_dict.is_empty():
					var garrison_mobility_hits = _process_mobility_attacks(garrison_dict, current_attackers, rng, 100, terrain_type, CastleTypeEnum.Type.NONE, defender_stats, -1)
					_merge_kill_results(kills, garrison_mobility_hits)
				if not armies_only.is_empty():
					var army_mobility_hits = _process_mobility_attacks(armies_only, current_attackers, rng, defender_efficiency, terrain_type, CastleTypeEnum.Type.NONE, defender_stats, -1)
					_merge_kill_results(kills, army_mobility_hits)
				mobility_rounds -= 1
			_apply_withdrawal_casualties(current_attackers, kills)
		else:
			var armies_only_def := _get_armies_without_garrison(current_defenders, garrison_dict)
			if armies_only_def.is_empty():
				break
			if standard_rounds > 0:
				kills = _process_unit_attacks(current_attackers, armies_only_def, rng, attacker_efficiency, terrain_type, castle_type, null, attacker_stats, castle_defense_bonus_override)
				standard_rounds -= 1
			else:
				kills = _process_mobility_attacks(current_attackers, armies_only_def, rng, attacker_efficiency, terrain_type, castle_type, attacker_stats, castle_defense_bonus_override)
				mobility_rounds -= 1
			_apply_withdrawal_casualties_to_defenders(current_defenders, garrison_dict, kills)
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

func _apply_withdrawal_casualties_to_defenders(current_defenders: Dictionary, garrison_dict: Dictionary, attacker_kills: Dictionary) -> void:
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

func _compute_dict_power(comp_dict: Dictionary) -> int:
	var total := 0
	for ut in comp_dict.keys():
		var qty: int = int(comp_dict[ut])
		if qty > 0:
			total += GameParameters.get_unit_stat(ut, "power") * qty
	return total

func _create_withdrawal_report(original_attackers: Dictionary, original_defenders: Dictionary, current_attackers: Dictionary, current_defenders: Dictionary, rounds: int, withdrawing_side: int) -> BattleReport:
	var report = BattleReport.new()
	report.winner = "Withdrawal"
	report.rounds = rounds
	report.attacker_losses = _calculate_losses(original_attackers, current_attackers)
	report.defender_losses = _calculate_losses(original_defenders, current_defenders)
	report.final_attacker = current_attackers.duplicate()
	report.final_defender = current_defenders.duplicate()
	report.withdrawing_side = withdrawing_side
	return report

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
			effective_defense_chance *= GameParameters.ARMOR_PIERCING_DEFENSE_REDUCTION
		
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

func _get_valid_targets(attacker_unit_type: SoldierTypeEnum.Type, attacking_army: Dictionary, defending_army: Dictionary) -> Array[SoldierTypeEnum.Type]:
	"""Get valid target unit types based on trait-based combat rules"""
	var valid_targets: Array[SoldierTypeEnum.Type] = []
	var attacker_has_ranged = GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_2)  # ranged
	var attacker_has_flanker = GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_4)  # flanker
	
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

func _get_terrain_attack_multiplier(unit_type: SoldierTypeEnum.Type, terrain_type: RegionTypeEnum.Type, castle_type: CastleTypeEnum.Type) -> float:
	"""Get terrain-based attack multipliers for units with specific traits"""
	var multiplier = 1.0
	
	# Charge bonus: 100% bonus on grassland unless attacking a region with any level of castle
	if GameParameters.unit_has_trait(unit_type, UnitTraitEnum.Type.UNIT_TRAIT_5):  # charge trait
		if terrain_type == RegionTypeEnum.Type.GRASSLAND and castle_type == CastleTypeEnum.Type.NONE:
			multiplier += GameParameters.CHARGE_BONUS_GRASSLAND
	
	return multiplier

func _process_ranged_unit_attacks(attacking_army: Dictionary, defending_army: Dictionary, rng: RandomNumberGenerator, efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE, stats_accumulator = null, castle_defense_bonus_override: int = -1) -> Dictionary:
	"""Process attacks from only ranged trait units during opening volley"""
	var ranged_kills = {}
	var efficiency_modifier = efficiency / 100.0
	
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
		modified_attack_chance *= _get_terrain_attack_multiplier(attacker_unit_type, terrain_type, castle_type)
		
		# Apply multi-attack trait if present
		var effective_unit_count = attacker_count
		if GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_6):  # multi_attack
			effective_unit_count *= 2
		
		var hits = _binomial_sample(rng, effective_unit_count, modified_attack_chance)
		
		if stats_accumulator != null:
			_record_unit_stats(stats_accumulator, attacker_unit_type, effective_unit_count, hits)
		
		if hits <= 0:
			continue
			
		# Determine valid targets based on traits
		var valid_targets = _get_valid_targets(attacker_unit_type, attacking_army, defending_army)
		
		if valid_targets.is_empty():
			continue
			
		# Distribute hits among valid targets
		var target_assigned = _distribute_hits_to_valid_targets(defending_army, valid_targets, hits, rng)
		
		# Apply long-spears bonus: double hits against cavalry if attacker has long-spears
		if GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_1):  # long_spears
			for defender_unit_type in target_assigned:
				if GameParameters.is_cavalry_unit(defender_unit_type):
					target_assigned[defender_unit_type] = _apply_multiplier_stochastic(target_assigned[defender_unit_type], GameParameters.LONG_SPEARS_CAVALRY_MULTIPLIER, rng)
		
		var target_kills = _defense_resolution_with_attacker_traits(target_assigned, attacker_unit_type, rng, castle_type, castle_defense_bonus_override)
		
		# Merge kills into total
		_merge_kill_results(ranged_kills, target_kills)
	
	return ranged_kills

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
