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
	
	func _init():
		attacker_losses = {}
		defender_losses = {}
		final_attacker = {}
		final_defender = {}

# Main battle function - accepts arrays of compositions for each side
func simulate_battle(attacking_armies: Array, defending_armies: Array, region_garrison: ArmyComposition = null, attacker_efficiency: int = 100, defender_efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE) -> BattleReport:
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
	
	# Store original compositions for loss calculation
	var original_attackers = _copy_composition_dict(merged_attackers)
	var original_defenders = _copy_composition_dict(merged_defenders)
	
	var report = BattleReport.new()
	var rounds = 0
	var max_rounds = 1000
	
	# Ranged opening volley - both sides shoot simultaneously before main battle
	var attacker_ranged_kills = _process_ranged_unit_attacks(merged_attackers, merged_defenders, rng, attacker_efficiency, terrain_type, castle_type)
	var defender_ranged_kills = {}
	
	# Process garrison ranged attacks at 100% efficiency if garrison exists
	if region_garrison != null and not region_garrison.is_empty():
		var garrison_dict = _merge_compositions([region_garrison])
		var garrison_ranged_kills = _process_ranged_unit_attacks(garrison_dict, merged_attackers, rng, 100, terrain_type, castle_type)
		_merge_kill_results(defender_ranged_kills, garrison_ranged_kills)
	
	# Process defending army ranged attacks at their efficiency if any defending armies exist
	if not defending_armies.is_empty():
		var armies_dict = _merge_compositions(defending_armies)
		var army_ranged_kills = _process_ranged_unit_attacks(armies_dict, merged_attackers, rng, defender_efficiency, terrain_type, castle_type)
		_merge_kill_results(defender_ranged_kills, army_ranged_kills)
	
	# Apply ranged volley kills simultaneously
	_apply_kills(merged_defenders, attacker_ranged_kills)
	_apply_kills(merged_attackers, defender_ranged_kills)
	
	# Battle loop
	while _army_size(merged_attackers) > 0 and _army_size(merged_defenders) > 0 and rounds < max_rounds:
		rounds += 1
		
		# Attack phases - unit-by-unit with trait-based targeting
		var attacker_kills = _process_unit_attacks(merged_attackers, merged_defenders, rng, attacker_efficiency, terrain_type, castle_type)
		
		# Defense phase - separate garrison and army processing for defenders
		var defender_kills = {}
		
		# Process garrison attacks at 100% efficiency if garrison exists
		if region_garrison != null and not region_garrison.is_empty():
			var garrison_dict = _merge_compositions([region_garrison])
			var garrison_kills = _process_unit_attacks(garrison_dict, merged_attackers, rng, 100, terrain_type, castle_type)
			_merge_kill_results(defender_kills, garrison_kills)
		
		# Process defending army attacks at their efficiency if any defending armies exist
		if not defending_armies.is_empty():
			var armies_dict = _merge_compositions(defending_armies)
			var army_kills = _process_unit_attacks(armies_dict, merged_attackers, rng, defender_efficiency, terrain_type, castle_type)
			_merge_kill_results(defender_kills, army_kills)
		
		# Apply kills simultaneously
		_apply_kills(merged_defenders, attacker_kills)
		_apply_kills(merged_attackers, defender_kills)
	
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

func _army_size(army: Dictionary) -> int:
	"""Calculate total size of an army"""
	var total = 0
	for unit_type in army:
		total += army[unit_type]
	return total

func _process_unit_attacks(attacking_army: Dictionary, defending_army: Dictionary, rng: RandomNumberGenerator, efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE) -> Dictionary:
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
		
		var target_kills = _defense_resolution_with_attacker_traits(target_assigned, attacker_unit_type, rng, castle_type)
		
		# Merge kills into total
		_merge_kill_results(total_kills, target_kills)
	
	return total_kills

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

func _defense_resolution_with_attacker_traits(assigned_hits: Dictionary, attacker_unit_type: SoldierTypeEnum.Type, rng: RandomNumberGenerator, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE) -> Dictionary:
	"""Apply defense chances with consideration for attacker traits like armor piercing and castle defenses"""
	var kills = {}
	
	# Check if attacker has armor piercing trait
	var has_armor_piercing = GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_7)  # armor_piercing
	
	# Get castle defense bonus (hit avoidance percentage)
	var castle_defense_bonus = GameParameters.get_castle_defense_bonus(castle_type) / 100.0
	
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

func _process_ranged_unit_attacks(attacking_army: Dictionary, defending_army: Dictionary, rng: RandomNumberGenerator, efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE) -> Dictionary:
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
		
		var target_kills = _defense_resolution_with_attacker_traits(target_assigned, attacker_unit_type, rng, castle_type)
		
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
