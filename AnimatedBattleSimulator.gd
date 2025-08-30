extends Node
class_name AnimatedBattleSimulator

# Signals for battle events
signal round_completed(round_data: Dictionary)
signal battle_finished(report: BattleSimulator.BattleReport)

# Battle state
var battle_simulator: BattleSimulator
var battle_timer: Timer
var is_battle_running: bool = false
var is_withdrawing: bool = false
var withdrawal_rounds_remaining: int = 0
var mobility_withdrawal_rounds_remaining: int = 0

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

func _ready():
	battle_simulator = BattleSimulator.new()
	
	# Create timer for round delays
	battle_timer = Timer.new()
	battle_timer.wait_time = GameParameters.BATTLE_ROUND_TIME
	battle_timer.timeout.connect(_process_next_round)
	battle_timer.one_shot = true
	add_child(battle_timer)

func start_animated_battle(attacking_armies: Array, defending_armies: Array, region_garrison: ArmyComposition = null, attacker_efficiency: int = 100, defender_efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE) -> void:
	"""Start an animated battle with round-by-round updates"""
	if is_battle_running:
		DebugLogger.log("BattleAnimation", "Battle already running!")
		return
	
	is_battle_running = true
	current_round = 0
	
	# Store efficiency values and garrison reference
	self.attacker_efficiency = attacker_efficiency
	self.defender_efficiency = defender_efficiency
	self.region_garrison = region_garrison
	self.terrain_type = terrain_type
	self.castle_type = castle_type
	
	# Merge all attacking forces
	current_attackers = battle_simulator._merge_compositions(attacking_armies)
	
	# Merge all defending forces (including garrison)
	var all_defenders = defending_armies.duplicate()
	if region_garrison != null and not region_garrison.is_empty():
		all_defenders.append(region_garrison)
	current_defenders = battle_simulator._merge_compositions(all_defenders)
	
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
	
	# Attack phases - unit-by-unit with trait-based targeting
	var attacker_kills = battle_simulator._process_unit_attacks(current_attackers, current_defenders, rng, attacker_efficiency, terrain_type, castle_type)
	
	# Defense phase - separate garrison and army processing for defenders
	var defender_kills = {}
	
	# Process garrison attacks at 100% efficiency if garrison exists
	if region_garrison != null and not region_garrison.is_empty():
		var garrison_dict = battle_simulator._merge_compositions([region_garrison])
		var garrison_kills = battle_simulator._process_unit_attacks(garrison_dict, current_attackers, rng, 100, terrain_type, castle_type)
		battle_simulator._merge_kill_results(defender_kills, garrison_kills)
	
	# Process defending army attacks at their efficiency if any defending armies exist
	var armies_composition = _get_armies_from_defenders()
	if not armies_composition.is_empty():
		var army_kills = battle_simulator._process_unit_attacks(armies_composition, current_attackers, rng, defender_efficiency, terrain_type, castle_type)
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
	report.winner = winner
	report.rounds = current_round
	report.attacker_losses = attacker_losses
	report.defender_losses = defender_losses
	report.final_attacker = current_attackers
	report.final_defender = current_defenders
	
	DebugLogger.log("BattleAnimation", "Battle finished! Winner: " + winner + " in " + str(current_round) + " rounds")
	
	# Emit final results
	battle_finished.emit(report)

func _get_armies_from_defenders() -> Dictionary:
	"""Get the army composition portion of defenders (excluding garrison)"""
	# If there's no garrison, all defenders are armies
	if region_garrison == null or region_garrison.is_empty():
		return current_defenders
	
	# If there is a garrison, we need to subtract garrison composition from current defenders
	# This is an approximation since we merged compositions at start
	var garrison_dict = battle_simulator._merge_compositions([region_garrison])
	var armies_only = {}
	
	# For each unit type in current defenders, subtract garrison amounts
	for unit_type in current_defenders:
		var total_count = current_defenders[unit_type]
		var garrison_count = garrison_dict.get(unit_type, 0)
		var army_count = max(0, total_count - garrison_count)
		
		if army_count > 0:
			armies_only[unit_type] = army_count
	
	return armies_only

func _process_mobility_attacks(defending_army: Dictionary, attacking_targets: Dictionary, rng: RandomNumberGenerator, efficiency: int = 100) -> Dictionary:
	"""Process attacks from only mobility trait units during mobility withdrawal rounds"""
	var mobility_kills = {}
	var efficiency_modifier = efficiency / 100.0
	
	# Only process units with mobility trait
	for defender_unit_type in defending_army:
		var defender_count = defending_army[defender_unit_type]
		if defender_count <= 0:
			continue
			
		# Check if this unit has mobility trait
		if not GameParameters.unit_has_trait(defender_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_3):  # mobility
			continue
			
		# Calculate hits for this mobility unit type
		var base_attack_chance = GameParameters.get_unit_stat(defender_unit_type, "attack") / 100.0
		var modified_attack_chance = base_attack_chance * efficiency_modifier
		
		# Apply terrain bonuses
		modified_attack_chance *= battle_simulator._get_terrain_attack_multiplier(defender_unit_type, terrain_type, castle_type)
		
		# Apply multi-attack trait if present
		var effective_unit_count = defender_count
		if GameParameters.unit_has_trait(defender_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_6):  # multi_attack
			effective_unit_count *= 2
		
		var hits = battle_simulator._binomial_sample(rng, effective_unit_count, modified_attack_chance)
		
		if hits <= 0:
			continue
			
		# Determine valid targets based on traits
		var valid_targets = battle_simulator._get_valid_targets(defender_unit_type, defending_army, attacking_targets)
		
		if valid_targets.is_empty():
			continue
			
		# Distribute hits among valid targets
		var target_assigned = battle_simulator._distribute_hits_to_valid_targets(attacking_targets, valid_targets, hits, rng)
		
		# Apply long-spears bonus from the ACTING ATTACKER (defender_unit_type is the attacker in this context)
		if GameParameters.unit_has_trait(defender_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_1):  # long_spears
			for target_unit_type in target_assigned:
				if GameParameters.is_cavalry_unit(target_unit_type):
					target_assigned[target_unit_type] = battle_simulator._apply_multiplier_stochastic(
						target_assigned[target_unit_type],
						GameParameters.LONG_SPEARS_CAVALRY_MULTIPLIER,
						rng
					)
		
		var target_kills = battle_simulator._defense_resolution_with_attacker_traits(target_assigned, defender_unit_type, rng, CastleTypeEnum.Type.NONE)
		
		# Merge kills into total
		battle_simulator._merge_kill_results(mobility_kills, target_kills)
	
	return mobility_kills

func _process_ranged_attacks(attacking_army: Dictionary, defending_targets: Dictionary, rng: RandomNumberGenerator, efficiency: int = 100) -> Dictionary:
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
		modified_attack_chance *= battle_simulator._get_terrain_attack_multiplier(attacker_unit_type, terrain_type, castle_type)
		
		# Apply multi-attack trait if present
		var effective_unit_count = attacker_count
		if GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_6):  # multi_attack
			effective_unit_count *= 2
		
		var hits = battle_simulator._binomial_sample(rng, effective_unit_count, modified_attack_chance)
		
		if hits <= 0:
			continue
			
		# Determine valid targets based on traits
		var valid_targets = battle_simulator._get_valid_targets(attacker_unit_type, attacking_army, defending_targets)
		
		if valid_targets.is_empty():
			continue
			
		# Distribute hits among valid targets
		var target_assigned = battle_simulator._distribute_hits_to_valid_targets(defending_targets, valid_targets, hits, rng)
		
		# Apply long-spears bonus: double hits against cavalry if attacker has long-spears
		if GameParameters.unit_has_trait(attacker_unit_type, UnitTraitEnum.Type.UNIT_TRAIT_1):  # long_spears
			for target_unit_type in target_assigned:
				if GameParameters.is_cavalry_unit(target_unit_type):
					target_assigned[target_unit_type] = battle_simulator._apply_multiplier_stochastic(
						target_assigned[target_unit_type],
						GameParameters.LONG_SPEARS_CAVALRY_MULTIPLIER,
						rng
					)
		
		var target_kills = battle_simulator._defense_resolution_with_attacker_traits(target_assigned, attacker_unit_type, rng, CastleTypeEnum.Type.NONE)
		
		# Merge kills into total
		battle_simulator._merge_kill_results(ranged_kills, target_kills)
	
	return ranged_kills

func _process_ranged_opening_volley() -> void:
	"""Process the ranged opening volley before standard battle rounds"""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Process attacker ranged attacks
	var attacker_ranged_kills = _process_ranged_attacks(current_attackers, current_defenders, rng, attacker_efficiency)
	
	# Process defender ranged attacks
	var defender_ranged_kills = {}
	
	# Process garrison ranged attacks at 100% efficiency if garrison exists
	if region_garrison != null and not region_garrison.is_empty():
		var garrison_dict = battle_simulator._merge_compositions([region_garrison])
		var garrison_ranged_kills = _process_ranged_attacks(garrison_dict, current_attackers, rng, 100)
		battle_simulator._merge_kill_results(defender_ranged_kills, garrison_ranged_kills)
	
	# Process defending army ranged attacks at their efficiency if any defending armies exist
	var armies_composition = _get_armies_from_defenders()
	if not armies_composition.is_empty():
		var army_ranged_kills = _process_ranged_attacks(armies_composition, current_attackers, rng, defender_efficiency)
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
		battle_timer.stop()
		DebugLogger.log("BattleAnimation", "Battle stopped")

func is_running() -> bool:
	"""Check if a battle is currently running"""
	return is_battle_running

func start_withdrawal_round() -> void:
	"""Start withdrawal rounds where only defenders can attack"""
	if not is_battle_running or is_withdrawing:
		return
	
	is_withdrawing = true
	withdrawal_rounds_remaining = GameParameters.WITHDRAWAL_FREE_HIT_ROUNDS
	mobility_withdrawal_rounds_remaining = GameParameters.MOBILITY_EXTRA_WITHDRAWAL_ROUNDS
	DebugLogger.log("BattleAnimation", "Starting withdrawal with " + str(withdrawal_rounds_remaining) + " free hit rounds and " + str(mobility_withdrawal_rounds_remaining) + " mobility rounds...")

func _process_withdrawal_round(rng: RandomNumberGenerator) -> void:
	"""Process a withdrawal round where only defenders attack"""
	var is_mobility_round = withdrawal_rounds_remaining <= 0 and mobility_withdrawal_rounds_remaining > 0
	var round_type = "mobility" if is_mobility_round else "standard"
	DebugLogger.log("BattleAnimation", "Processing " + round_type + " withdrawal round " + str(current_round) + " (" + str(withdrawal_rounds_remaining) + " standard, " + str(mobility_withdrawal_rounds_remaining) + " mobility remaining)")
	
	# During withdrawal, attackers cannot attack (they get 0 hits)
	var attacker_hits = 0
	var attacker_kills = {}
	
	# Defenders get their normal attack using trait-based system
	var defender_kills = {}
	
	if is_mobility_round:
		# Only units with mobility trait can attack during these extra rounds
		if region_garrison != null and not region_garrison.is_empty():
			var garrison_dict = battle_simulator._merge_compositions([region_garrison])
			var mobility_garrison_kills = _process_mobility_attacks(garrison_dict, current_attackers, rng, 100)
			battle_simulator._merge_kill_results(defender_kills, mobility_garrison_kills)
		
		var armies_composition = _get_armies_from_defenders()
		if not armies_composition.is_empty():
			var mobility_army_kills = _process_mobility_attacks(armies_composition, current_attackers, rng, defender_efficiency)
			battle_simulator._merge_kill_results(defender_kills, mobility_army_kills)
	else:
		# Standard withdrawal rounds - all defender units can attack
		if region_garrison != null and not region_garrison.is_empty():
			var garrison_dict = battle_simulator._merge_compositions([region_garrison])
			var garrison_kills = battle_simulator._process_unit_attacks(garrison_dict, current_attackers, rng, 100, terrain_type, castle_type)
			battle_simulator._merge_kill_results(defender_kills, garrison_kills)
		
		var armies_composition = _get_armies_from_defenders()
		if not armies_composition.is_empty():
			var army_kills = battle_simulator._process_unit_attacks(armies_composition, current_attackers, rng, defender_efficiency, terrain_type, castle_type)
			battle_simulator._merge_kill_results(defender_kills, army_kills)
	
	# Apply only defender kills (attackers don't get to attack during withdrawal)
	var attacker_casualties = {}
	var defender_casualties = {}  # No defender casualties during withdrawal
	
	for unit_type in defender_kills:
		var kills = defender_kills[unit_type]
		var available = current_attackers.get(unit_type, 0)
		var actual_kills = min(kills, available)
		current_attackers[unit_type] = available - actual_kills
		if current_attackers[unit_type] <= 0:
			current_attackers.erase(unit_type)
		if actual_kills > 0:
			attacker_casualties[unit_type] = actual_kills
	
	# Decrement appropriate withdrawal rounds counter
	if is_mobility_round:
		mobility_withdrawal_rounds_remaining -= 1
	else:
		withdrawal_rounds_remaining -= 1
	
	# Calculate total defender hits for display
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
		"defender_size": battle_simulator._army_size(current_defenders),
		"is_withdrawal": true,
		"withdrawal_rounds_remaining": withdrawal_rounds_remaining,
		"mobility_withdrawal_rounds_remaining": mobility_withdrawal_rounds_remaining,
		"is_mobility_round": is_mobility_round
	}
	
	# Emit round completion signal
	round_completed.emit(round_data)
	
	DebugLogger.log("BattleAnimation", "Withdrawal round completed - Defenders get free hits: " + str(defender_hits))
	
	# Check if withdrawal is complete
	if (withdrawal_rounds_remaining <= 0 and mobility_withdrawal_rounds_remaining <= 0) or battle_simulator._army_size(current_attackers) <= 0:
		# End battle after all withdrawal rounds (winner is always "Withdrawal")
		_finish_withdrawal()
	else:
		# Schedule next withdrawal round
		battle_timer.start()

func _finish_withdrawal() -> void:
	"""Complete a withdrawal and emit final results"""
	is_battle_running = false
	is_withdrawing = false
	
	# Calculate total losses during the battle (including withdrawal round)
	var attacker_losses = battle_simulator._calculate_losses(original_attackers, current_attackers)
	var defender_losses = battle_simulator._calculate_losses(original_defenders, current_defenders)
	
	# Create final report with withdrawal outcome
	var report = BattleSimulator.BattleReport.new()
	report.winner = "Withdrawal"  # Special case for withdrawal
	report.rounds = current_round
	report.attacker_losses = attacker_losses
	report.defender_losses = defender_losses
	report.final_attacker = current_attackers
	report.final_defender = current_defenders
	
	DebugLogger.log("BattleAnimation", "Withdrawal completed! Attackers withdrawn after " + str(current_round) + " rounds")
	
	# Emit final results
	battle_finished.emit(report)
