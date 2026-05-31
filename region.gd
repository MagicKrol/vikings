extends Node2D
class_name Region

# ============================================================================
# REGION
# ============================================================================
# 
# Purpose: Individual region data container and territory management
# 
# Core Responsibilities:
# - Region properties storage (ID, name, biome, type, level, population)
# - Garrison and resource composition management
# - Movement cost and passability determination based on terrain
# - Population tracking and level-based management
# - Integration with regional systems and map display
# 
# Required Functions:
# - setup_region(): Initialize region from map generator data
# - get/set_region_level(): Administrative level management
# - garrison management: add/remove/get garrison composition
# - resource management: access to region resource composition
# - population management: get/set population values
# 
# Integration Points:
# - RegionManager: Territory ownership and resource generation
# - MapGenerator: Region initialization and positioning data
# - GameParameters: Population and garrison generation rules
# - Enums: Region type, level, and resource type definitions
# ============================================================================

# Region properties - all data here
var region_id: int = -1
var region_name: String = ""
var biome: String = ""
var region_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND
var region_level: RegionLevelEnum.Level = RegionLevelEnum.Level.L1
var is_ocean: bool = false
var center: Vector2 = Vector2.ZERO
var nearby_regions: Array[int] = []
var castle_nearby_entities: Dictionary = {}

# Army composition stationed in this region
var garrison: ArmyComposition

# Wounded pools for garrison and recruits
var wounded_garrison: ArmyComposition
var wounded_recruits: ArmyComposition

# Resource composition available in this region
var resources: ResourceComposition
var base_resources: ResourceComposition

# Population in this region
var population: int = 0

# Available recruits in this region
var available_recruits: int = 0

# Promotion growth bonus tracking
var promotion_growth_bonus_turns_remaining: int = 0

# Castle information
var castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE
var castle_under_construction: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE
var castle_build_turns_remaining: int = 0
var gate_conditions: Array[int] = []
var wall_section_conditions: Array[int] = []
var castle_repair_turns_remaining: int = 0
var castle_repair_in_progress: bool = false
var repair_start_gate_conditions: Array[int] = []
var repair_start_wall_section_conditions: Array[int] = []

# Mining system information
var ore_search_attempts_remaining: int = 0  # Number of ore search attempts left
var discovered_ores: Array[ResourcesEnum.Type] = []  # Which ores have been discovered
var ore_search_used_this_turn: bool = false  # Track if ore search was used this turn
var ore_scenario_rules_enabled: bool = false
var ore_guaranteed_discovery_attempt: int = 0
var ore_guaranteed_discovery_type: ResourcesEnum.Type = ResourcesEnum.Type.IRON
var raise_army_used_this_turn: bool = false  # Track if raise army was used this turn
var promotion_used_this_turn: bool = false  # Track if promotion was used this turn

# Ownership tracking information
var current_owner_id: int = 0  # Current owner player ID (0 = neutral)
var ownership_turns_counter: int = 0  # How many turns region has been owned by current owner
var just_conquered_this_turn: bool = false  # Marks regions conquered this turn for UI restrictions

# AI Scoring data - calculated once, stored permanently until recalculation needed
var ai_cluster_score: float = 0.0              # Final cluster score (0-100)
var ai_individual_score: float = 0.0           # Individual region score (0-100)
var ai_scoring_factors: Dictionary = {}        # Detailed factors (pop_score, resource_score, etc.)
var ai_cluster_data: Dictionary = {}           # Cluster metrics (total_population, resources, etc.)
var ai_scoring_valid: bool = false             # Whether stored scores are still valid

# Strategic points heatmap score (computed pre-castle placement)
var strategic_point_score: float = 0.0
var promotion_cooldown_turns: int = 0

func setup_region(region_data: Dictionary) -> void:
	"""Setup the region with data from the map generator"""
	region_id = int(region_data.get("id", -1))
	biome = String(region_data.get("biome", ""))
	region_type = RegionTypeEnum.string_to_type(biome)
	is_ocean = bool(region_data.get("ocean", false))
	
	# Initialize garrison and resources
	garrison = ArmyComposition.new()
	wounded_garrison = ArmyComposition.new()
	wounded_recruits = ArmyComposition.new()
	nearby_regions.clear()
	castle_nearby_entities = _build_empty_nearby_entities()
	resources = ResourceComposition.new()
	base_resources = ResourceComposition.new()
	castle_repair_turns_remaining = 0
	castle_repair_in_progress = false
	_clear_repair_snapshot()
	_reset_defense_state_to_full()
	
	# Set basic garrison composition and population for non-ocean regions
	if not is_ocean:
		var peasant_count = GameParameters.generate_garrison_size(region_level)
		garrison.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, peasant_count)
		# Generate population based on region level
		population = GameParameters.generate_population_size(region_level)
		# Initialize available recruits based on population
		available_recruits = GameParameters.calculate_max_recruits(population, region_level)
		# Initialize ore search attempts if region can have ores
		if GameParameters.can_search_for_ore_in_region(region_type):
			ore_search_attempts_remaining = GameParameters.ORE_SEARCH_CHANCES_PER_REGION
	
	# Set center position
	var center_data = region_data.get("center", [])
	if center_data.size() == 2:
		center = Vector2(center_data[0], center_data[1])

func set_region_name(new_name: String) -> void:
	"""Set the region name (called by RegionManager)"""
	region_name = new_name
	# Use the actual region name as the node name
	name = new_name

func get_region_name() -> String:
	"""Get the region name"""
	return region_name

func get_region_id() -> int:
	"""Get the region ID"""
	return region_id

func get_biome() -> String:
	"""Get the biome type"""
	return biome

func get_region_type() -> RegionTypeEnum.Type:
	"""Get the region type enum"""
	return region_type

func get_movement_cost() -> int:
	"""Get the movement cost for this region"""
	return RegionTypeEnum.get_movement_cost(region_type)

func is_passable() -> bool:
	"""Check if this region is passable for armies"""
	return RegionTypeEnum.is_passable(region_type)

func is_ocean_region() -> bool:
	"""Check if this is an ocean region"""
	return is_ocean

# Editor helpers for changing region classification
func set_region_type(t: RegionTypeEnum.Type) -> void:
	region_type = t
	biome = RegionTypeEnum.type_to_string(t).to_lower()
	is_ocean = false

func set_ocean(enabled: bool) -> void:
	is_ocean = enabled
	if enabled:
		biome = "ocean"

func set_any_ore_discovered(enabled: bool) -> void:
	"""Editor: toggle generic ore discovered flag (iron default)."""
	if enabled:
		if not ResourcesEnum.Type.IRON in discovered_ores:
			discovered_ores.append(ResourcesEnum.Type.IRON)
	else:
		discovered_ores.clear()

func get_region_level() -> RegionLevelEnum.Level:
	"""Get the region level"""
	return region_level

func set_region_level(level: RegionLevelEnum.Level) -> void:
	"""Set the region level"""
	region_level = level
	_update_resources_from_base()

func promote_region() -> void:
	"""Promote the region to the next level"""
	if (region_level < 5):			
		region_level = region_level + 1
		promotion_growth_bonus_turns_remaining = GameParameters.PROMOTION_GROWTH_BONUS_TURNS
		_update_resources_from_base()

func get_promotion_cooldown() -> int:
	return promotion_cooldown_turns

func set_promotion_cooldown(turns: int) -> void:
	promotion_cooldown_turns = max(0, int(turns))

func decrement_promotion_cooldown() -> void:
	if promotion_cooldown_turns > 0:
		promotion_cooldown_turns -= 1

func get_region_level_string() -> String:
	"""Get the region level as a string"""
	return RegionLevelEnum.level_to_string(region_level)

func get_region_level_number() -> String:
	"""Get the region level as a string"""
	return RegionLevelEnum.level_to_string_number(region_level)

func get_region_type_display_string() -> String:
	"""Get the simplified region type as a display string (grassland, forest, hills, forest hills, mountains)"""
	return RegionTypeEnum.type_to_display_string(region_type)

# Garrison management methods
func get_garrison() -> ArmyComposition:
	"""Get the army composition stationed in this region"""
	return garrison

func kill_wounded_garrison() -> void:
	if wounded_garrison == null:
		return
	for unit_type in SoldierTypeEnum.get_all_types():
		var qty := wounded_garrison.get_soldier_count(unit_type)
		if qty > 0:
			wounded_garrison.remove_soldiers(unit_type, qty)

func add_soldiers_to_garrison(soldier_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Add soldiers to the region's garrison"""
	garrison.add_soldiers(soldier_type, count)

func remove_soldiers_from_garrison(soldier_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Remove soldiers from the region's garrison"""
	garrison.remove_soldiers(soldier_type, count)

func get_garrison_strength() -> int:
	"""Get total combat strength of the garrison"""
	return garrison.get_total_attack()

func has_garrison() -> bool:
	"""Check if region has any garrison soldiers"""
	return garrison.has_soldiers()

func has_defenders() -> bool:
	"""Check if region has any defending forces (garrison, recruits, or armies present)."""
	if has_garrison():
		return true
	if get_base_available_recruits() > 0:
		return true
	for child in get_children():
		if child is Army:
			return true
	return false

func get_garrison_composition_string() -> String:
	"""Get garrison composition as a readable string"""
	return garrison.get_composition_string()

# Resource management methods
func get_resources() -> ResourceComposition:
	"""Get the resource composition in this region"""
	return resources

func get_resource_amount(resource_type: ResourcesEnum.Type) -> int:
	"""Get amount of specific resource type"""
	var base_amount = resources.get_resource_amount(resource_type)
	if base_amount <= 0:
		return 0
	return base_amount

func get_base_resource_amount(resource_type: ResourcesEnum.Type) -> int:
	"""Get base (pre-level-multiplier) amount of specific resource type."""
	var base_amount: int = base_resources.get_resource_amount(resource_type)
	if base_amount <= 0:
		return 0
	return base_amount

func set_base_resource_amount(resource_type: ResourcesEnum.Type, amount: int) -> void:
	"""Set base resource amount and rebuild scaled resources from current region level."""
	base_resources.set_resource_amount(resource_type, amount)
	_update_resources_from_base()

func has_resources() -> bool:
	"""Check if region has any resources"""
	return resources.has_resources()

func get_resource_composition_string() -> String:
	"""Get resource composition as a readable string"""
	return resources.get_composition_string()

func set_base_resources(base_comp: ResourceComposition) -> void:
	base_resources = ResourceComposition.new()
	for rt in ResourcesEnum.get_all_types():
		base_resources.set_resource_amount(rt, base_comp.get_resource_amount(rt))
	_update_resources_from_base()

func set_resources_from_dict(res_dict: Dictionary) -> void:
	var base_comp := ResourceComposition.new()
	for rt in ResourcesEnum.get_all_types():
		var key_string := ResourcesEnum.type_to_string(rt)
		var val = 0
		if res_dict.has(rt):
			val = res_dict.get(rt, 0)
		elif res_dict.has(key_string):
			val = res_dict.get(key_string, 0)
		base_comp.set_resource_amount(rt, int(val))
	set_base_resources(base_comp)

func _update_resources_from_base() -> void:
	var level_bonus := float(RegionLevelEnum.level_to_number(region_level) - 1) * GameParameters.REGION_RESOURCE_LEVEL_MULTIPLIER
	var multiplier := 1.0 + level_bonus
	resources = ResourceComposition.new()
	for rt in ResourcesEnum.get_all_types():
		var base_amt = base_resources.get_resource_amount(rt)
		if base_amt <= 0:
			continue
		var scaled = int(round(float(base_amt) * multiplier))
		resources.set_resource_amount(rt, scaled)

# Population management methods
func get_population() -> int:
	"""Get current population in this region"""
	return population

func set_population(new_population: int) -> void:
	"""Set population for this region"""
	population = max(0, new_population)
	# Recalculate max recruits when population changes
	var max_recruits = GameParameters.calculate_max_recruits(population, region_level)
	# Ensure available recruits don't exceed new maximum
	available_recruits = min(available_recruits, max_recruits)

func apply_population_loss(loss: int, min_population: int = 0) -> int:
	"""Reduce population by loss while clamping to a minimum. Returns actual loss applied."""
	if loss <= 0:
		return 0
	var minimum: int = int(max(0, min_population))
	var target_population: int = int(max(minimum, population - loss))
	var actual_loss: int = population - target_population
	if actual_loss <= 0:
		return 0
	set_population(target_population)
	return actual_loss

# Recruit management methods
func get_available_recruits() -> int:
	"""Get current available recruits in this region with ownership modifier"""
	var base_recruits = available_recruits
	var ownership_modifier = get_ownership_recruitment_modifier()
	return int(base_recruits * ownership_modifier)

func get_base_available_recruits() -> int:
	"""Get base available recruits without ownership modifier (for internal calculations)"""
	return available_recruits

func get_max_recruits() -> int:
	"""Get maximum recruits based on current population and castle type"""
	return GameParameters.calculate_max_recruits(population, region_level)

func hire_recruits(count: int) -> int:
	"""Hire recruits from this region, returns actual hired count"""
	var ownership_modifier: float = get_ownership_recruitment_modifier()
	var modified_available: int = get_available_recruits()
	var actual_hired: int = min(count, modified_available)
	if actual_hired <= 0:
		return 0

	var new_population: int = max(0, population - actual_hired)
	var new_modified_available: int = max(0, modified_available - actual_hired)
	var new_base_available: int = 0

	if ownership_modifier >= 1.0:
		new_base_available = new_modified_available
	elif ownership_modifier > 0.0:
		new_base_available = ceili(float(new_modified_available) / ownership_modifier)

	population = new_population
	var max_recruits: int = GameParameters.calculate_max_recruits(population, region_level)
	available_recruits = min(new_base_available, max_recruits)
	return actual_hired

func reduce_recruits(count: int) -> int:
	"""Reduce available recruits (for battle losses), returns actual reduced count"""
	var base_available = get_base_available_recruits()  # Use base without ownership modifier for losses
	var actual_reduced = min(count, base_available)
	if actual_reduced > 0:
		# Use the centralized function to reduce recruits and population
		_reduce_recruits_and_population(actual_reduced)
	return actual_reduced

func _reduce_recruits_and_population(count: int) -> void:
	"""Internal function to reduce both recruits and population"""
	available_recruits -= count
	# Reduce population by the same amount
	population -= count
	# Recalculate max recruits after population reduction
	var max_recruits = GameParameters.calculate_max_recruits(population, region_level)
	# Ensure available recruits don't exceed new maximum
	available_recruits = min(available_recruits, max_recruits)

func replenish_recruits() -> void:
	"""Replenish recruits based on current population (called each turn)"""
	var replenishment = GameParameters.calculate_recruit_replenishment(population)
	if promotion_growth_bonus_turns_remaining > 0:
		replenishment = replenishment * 2
	var max_recruits = GameParameters.calculate_max_recruits(population, region_level)
	available_recruits = min(available_recruits + replenishment, max_recruits)

func fill_recruits_to_maximum() -> void:
	"""Set available recruits to the current maximum capacity."""
	available_recruits = get_max_recruits()

func get_growth() -> float:
	if is_ocean:
		return 0
	var base_growth_rate = GameParameters.POPULATION_GROWTH_RATE
	var const_growth_rate = GameParameters.POPULATION_CONST_GROWTH_RATE
	var promotion_bonus = get_promotion_bonus()

	var max_recruits = GameParameters.calculate_max_recruits(population, region_level)
	var recruit_ratio = 0.0
	if max_recruits > 0:
		recruit_ratio = min(1.0, float(available_recruits) / float(max_recruits))
	var standard_growth_rate = base_growth_rate * recruit_ratio

	var food_bonus: float = float(resources.get_resource_amount(ResourcesEnum.Type.FOOD)) * 0.001
	var neutral_growth_penalty: float = 0.0
	if current_owner_id == 0:
		neutral_growth_penalty = 0.01

	return standard_growth_rate + promotion_bonus + food_bonus + const_growth_rate - neutral_growth_penalty

func get_population_increase() -> int:
	return int(population * get_growth())

func get_promotion_bonus() -> float:
	if promotion_growth_bonus_turns_remaining > 0:
		var bonus_turn = GameParameters.PROMOTION_GROWTH_BONUS_TURNS - promotion_growth_bonus_turns_remaining + 1
		return GameParameters.PROMOTION_GROWTH_BONUS_BY_TURN.get(bonus_turn, 0.0)
	return 0.0

func grow_population() -> void:
	"""Grow population per turn based on recruitment impact and promotion bonuses (called each turn)"""
	if is_ocean:
		return  # Ocean regions don't have population
	
	var growth = get_growth()
	var population_growth = int(population * growth)

	if promotion_growth_bonus_turns_remaining > 0:
		promotion_growth_bonus_turns_remaining = max(0, promotion_growth_bonus_turns_remaining - 1)
	
	if population_growth > 0:
		var old_population = population
		population += population_growth
		
		var growth_info = " (+" + str(population_growth) + ", rate: " + str(snappedf(growth * 100, 0.1)) + "%"
		var promotion_bonus = get_promotion_bonus()
		if promotion_bonus > 0.0:
			growth_info += ", promotion bonus: +" + str(snappedf(promotion_bonus * 100, 0.1)) + "%"
			growth_info += ", " + str(promotion_growth_bonus_turns_remaining) + " turns remaining"
		growth_info += ")"
		DebugLogger.log("RegionManagement", region_name + " population grew from " + str(old_population) + " to " + str(population) + " " + growth_info)

# Castle management methods
func get_castle_type() -> CastleTypeEnum.Type:
	"""Get the current castle type"""
	return castle_type

func set_castle_type(new_castle_type: CastleTypeEnum.Type) -> void:
	"""Set the castle type (used when construction completes or upgrades)"""
	var old_castle_type = castle_type
	var had_castle: bool = old_castle_type != CastleTypeEnum.Type.NONE
	castle_type = new_castle_type
	var has_castle_now: bool = castle_type != CastleTypeEnum.Type.NONE
	
	# Recalculate recruitment limits when castle type changes
	if old_castle_type != new_castle_type:
		_clear_repair_snapshot()
		_reset_defense_state_to_full()
	if had_castle != has_castle_now:
		var game_manager: GameManager = get_node("/root/Main/GameManager") as GameManager
		var army_manager: ArmyManager = game_manager.get_army_manager()
		army_manager.on_region_castle_presence_changed(self, had_castle, has_castle_now)

func has_castle() -> bool:
	"""Check if region has any castle"""
	return castle_type != CastleTypeEnum.Type.NONE

func has_castle_damage() -> bool:
	return _get_total_defense_damage() > 0

func get_gate_state() -> Dictionary:
	return _build_gate_state()

func get_wall_state() -> Dictionary:
	return _build_wall_state()

func get_wall_section_stats() -> Dictionary:
	var stats := _get_wall_stats()
	return {
		"wall_sections": int(stats.get("sections", 0)),
		"wall_hp": int(stats.get("hp", 0)),
		"trebuchet_damage_to_defense": int(stats.get("trebuchet_damage_to_defense", 0)),
		"gate_count": int(stats.get("gates", 0)),
		"gate_hp": int(stats.get("gate_hp", 0)),
		"wall_section_assault": int(stats.get("wall_section_assault", 0))
	}

func apply_wall_section_damage(damage: int) -> Dictionary:
	var base_hp: int = _get_wall_section_hp()
	if damage <= 0 or base_hp <= 0 or wall_section_conditions.is_empty():
		return _build_wall_state()
	var remaining: int = damage
	for i in range(wall_section_conditions.size()):
		if remaining <= 0:
			break
		var current_hp: int = wall_section_conditions[i]
		if current_hp <= 0:
			continue
		var applied: int = min(current_hp, remaining)
		wall_section_conditions[i] = max(0, current_hp - applied)
		remaining -= applied
	return _build_wall_state()

func apply_siege_damage(siege_counts: Dictionary, ladder_data: Dictionary, ram_data: Dictionary, treb_data: Dictionary, apply_trebuchet_damage: bool = true) -> Dictionary:
	var ladder_count: int = int(siege_counts.get("ladders", 0))
	var ladder_effectiveness_raw: int = ladder_count * int(ladder_data.get("effectiveness", GameParameters.LADDER_EFFECTIVENESS_PER))
	var gate_result := _build_gate_state()
	var wall_result := _build_wall_state()
	return {
		"ladder_effectiveness_raw": ladder_effectiveness_raw,
		"ladder_damage": 0,
		"wall_sections_destroyed": int(wall_result.get("destroyed_sections", 0)),
		"wall_sections_damaged": int(wall_result.get("damaged_sections", 0)),
		"gate_state": gate_result
	}

func _get_wall_stats() -> Dictionary:
	var data = GameParameters.CASTLE_WALLS_GATES.get(castle_type, {})
	return {
		"sections": int(data.get("wall_sections", 0)),
		"hp": int(data.get("wall_hp", 0)),
		"trebuchet_damage_to_defense": int(data.get("trebuchet_damage_to_defense", 0)),
		"gates": int(data.get("gates", 0)),
		"gate_hp": int(data.get("gate_hp", 0))
	}

func _reset_defense_state_to_full() -> void:
	gate_conditions.clear()
	wall_section_conditions.clear()
	var stats := _get_wall_stats()
	var gate_count: int = int(stats.get("gates", 0))
	var gate_hp: int = int(stats.get("gate_hp", 0))
	if gate_count > 0 and gate_hp > 0:
		gate_conditions.resize(gate_count)
		for i in range(gate_count):
			gate_conditions[i] = gate_hp
	var wall_count: int = int(stats.get("sections", 0))
	var wall_hp: int = int(stats.get("hp", 0))
	if wall_count > 0 and wall_hp > 0:
		wall_section_conditions.resize(wall_count)
		for i in range(wall_count):
			wall_section_conditions[i] = wall_hp

func _get_gate_hp() -> int:
	var stats := _get_wall_stats()
	return int(stats.get("gate_hp", 0))

func _get_wall_section_hp() -> int:
	var stats := _get_wall_stats()
	return int(stats.get("hp", 0))

func _apply_gate_damage(damage: int) -> Dictionary:
	var base_hp: int = _get_gate_hp()
	if damage <= 0 or base_hp <= 0 or gate_conditions.is_empty():
		return _build_gate_state()
	var remaining: int = damage
	for i in range(gate_conditions.size()):
		if remaining <= 0:
			break
		var current_hp: int = gate_conditions[i]
		if current_hp <= 0:
			continue
		var applied: int = min(current_hp, remaining)
		gate_conditions[i] = max(0, current_hp - applied)
		remaining -= applied
	return _build_gate_state()

func _build_gate_state() -> Dictionary:
	var base_hp := _get_gate_hp()
	var destroyed := 0
	var damaged := 0
	for hp in gate_conditions:
		if hp <= 0:
			destroyed += 1
		elif hp < base_hp:
			damaged += 1
	return {
		"destroyed_gates": destroyed,
		"damaged_gates": damaged,
		"gate_hp": base_hp,
		"gates": gate_conditions.size(),
		"gate_values": gate_conditions.duplicate()
	}

func _build_wall_state() -> Dictionary:
	var base_hp := _get_wall_section_hp()
	var destroyed := 0
	var damaged := 0
	var section_damage := 0
	for hp in wall_section_conditions:
		if hp <= 0:
			destroyed += 1
		elif hp < base_hp:
			damaged += 1
			if section_damage == 0:
				section_damage = base_hp - hp
	var total_sections := wall_section_conditions.size()
	return {
		"destroyed_sections": destroyed,
		"damaged_sections": damaged,
		"wall_section_hp": base_hp,
		"wall_sections": total_sections,
		"section_damage": section_damage,
		"wall_values": wall_section_conditions.duplicate()
	}

func _get_total_defense_capacity() -> int:
	var base_gate_hp := _get_gate_hp()
	var base_wall_hp := _get_wall_section_hp()
	var gate_cap := gate_conditions.size() * base_gate_hp
	var wall_cap := wall_section_conditions.size() * base_wall_hp
	return gate_cap + wall_cap

func _get_total_defense_damage() -> int:
	var base_gate_hp := _get_gate_hp()
	var base_wall_hp := _get_wall_section_hp()
	var missing := 0
	if base_gate_hp > 0:
		for hp in gate_conditions:
			missing += max(0, base_gate_hp - hp)
	if base_wall_hp > 0:
		for hp in wall_section_conditions:
			missing += max(0, base_wall_hp - hp)
	return missing

func get_defense_damage_fraction() -> float:
	var capacity := _get_total_defense_capacity()
	if capacity <= 0:
		return 0.0
	return clampf(float(_get_total_defense_damage()) / float(capacity), 0.0, 1.0)

func get_castle_type_string() -> String:
	"""Get the castle type as a string"""
	return CastleTypeEnum.type_to_string(castle_type)

func is_castle_under_construction() -> bool:
	"""Check if a castle is currently being built"""
	return castle_under_construction != CastleTypeEnum.Type.NONE

func is_castle_under_repair() -> bool:
	return castle_repair_in_progress

func get_castle_under_construction() -> CastleTypeEnum.Type:
	"""Get the castle type being constructed"""
	return castle_under_construction

func get_castle_build_turns_remaining() -> int:
	"""Get remaining turns for castle construction"""
	return castle_build_turns_remaining

func start_castle_construction(castle_type_to_build: CastleTypeEnum.Type) -> void:
	"""Start construction of a castle type"""
	castle_under_construction = castle_type_to_build
	castle_build_turns_remaining = GameParameters.get_castle_build_time(castle_type_to_build)
	DebugLogger.log("RegionManagement", "Started construction of " + CastleTypeEnum.type_to_string(castle_type_to_build) + " in " + region_name + " (" + str(castle_build_turns_remaining) + " turns remaining)")

func start_castle_repair() -> void:
	castle_repair_in_progress = true
	castle_repair_turns_remaining = 1
	_capture_repair_snapshot()
	DebugLogger.log("RegionManagement", "Started castle repair in " + region_name + " (1 turn remaining)")

func process_castle_repair() -> bool:
	if not castle_repair_in_progress:
		return false
	castle_repair_turns_remaining -= 1
	if castle_repair_turns_remaining <= 0:
		var gate_damage_during_repair: Array[int] = _compute_new_damage_during_repair(gate_conditions, repair_start_gate_conditions)
		var wall_damage_during_repair: Array[int] = _compute_new_damage_during_repair(wall_section_conditions, repair_start_wall_section_conditions)
		_reset_defense_state_to_full()
		_apply_damage_after_repair(gate_damage_during_repair, wall_damage_during_repair)
		_clear_repair_snapshot()
		castle_repair_turns_remaining = 0
		castle_repair_in_progress = false
		_update_castle_visual()
		DebugLogger.log("RegionManagement", "Castle repair completed in " + region_name)
		return true
	return false

func _clear_repair_snapshot() -> void:
	repair_start_gate_conditions.clear()
	repair_start_wall_section_conditions.clear()

func _capture_repair_snapshot() -> void:
	repair_start_gate_conditions = gate_conditions.duplicate()
	repair_start_wall_section_conditions = wall_section_conditions.duplicate()

func _compute_new_damage_during_repair(current_values: Array[int], snapshot_values: Array[int]) -> Array[int]:
	var result: Array[int] = []
	result.resize(current_values.size())
	for i in range(current_values.size()):
		var snapshot_hp: int = current_values[i]
		if i < snapshot_values.size():
			snapshot_hp = snapshot_values[i]
		var current_hp: int = current_values[i]
		result[i] = maxi(0, snapshot_hp - current_hp)
	return result

func _apply_damage_after_repair(gate_damage: Array[int], wall_damage: Array[int]) -> void:
	var base_gate_hp: int = _get_gate_hp()
	for i in range(mini(gate_conditions.size(), gate_damage.size())):
		var damage: int = maxi(0, gate_damage[i])
		gate_conditions[i] = maxi(0, base_gate_hp - damage)
	var base_wall_hp: int = _get_wall_section_hp()
	for i in range(mini(wall_section_conditions.size(), wall_damage.size())):
		var damage: int = maxi(0, wall_damage[i])
		wall_section_conditions[i] = maxi(0, base_wall_hp - damage)

func get_castle_repair_cost() -> Dictionary:
	var castle_type = get_castle_type()
	if castle_type == CastleTypeEnum.Type.NONE:
		return {}
	var capacity := _get_total_defense_capacity()
	if capacity <= 0:
		return {}
	var total_damage = _get_total_defense_damage()
	if total_damage <= 0:
		return {}
	var fraction = float(total_damage) / float(capacity)
	var base_cost = GameParameters.get_castle_building_cost(castle_type)
	var repair_cost: Dictionary = {}
	for res_type in base_cost:
		var val = base_cost[res_type]
		if val > 0:
			repair_cost[res_type] = int(ceil((float(val) / 2.0) * fraction))
	return repair_cost

func process_castle_construction() -> bool:
	"""Process castle construction for one turn. Returns true if construction completed."""
	if not is_castle_under_construction():
		return false
	
	castle_build_turns_remaining -= 1
	DebugLogger.log("RegionManagement", "Castle construction in " + region_name + ": " + str(castle_build_turns_remaining) + " turns remaining")
	
	if castle_build_turns_remaining <= 0:
		# Construction completed
		var completed_castle_type = castle_under_construction
		set_castle_type(completed_castle_type)
		castle_under_construction = CastleTypeEnum.Type.NONE
		castle_build_turns_remaining = 0
		_reset_defense_state_to_full()
		DebugLogger.log("RegionManagement", "Castle construction completed in " + region_name + "! Built: " + CastleTypeEnum.type_to_string(completed_castle_type))
		
		# Trigger visual update by finding and calling the visual manager
		_update_castle_visual()
		
		return true
	
	return false

func _update_castle_visual() -> void:
	"""Update the castle visual when construction completes"""
	# Find the GameManager and get the VisualManager
	var game_manager = get_node("/root/Main/GameManager")
	if game_manager == null:
		DebugLogger.log("RegionManagement", "Warning: Could not find GameManager for visual update")
		return
	
	var visual_manager = game_manager.get_visual_manager()
	if visual_manager == null:
		DebugLogger.log("RegionManagement", "Warning: Could not find VisualManager for visual update")
		return
	
	# Update the castle visual (this will place the correct icon)
	visual_manager.update_castle_visual(self)
	DebugLogger.log("RegionManagement", "Updated castle visual for " + region_name)

func _build_empty_nearby_entities() -> Dictionary:
	return {
		"army_ids": {},
		"castle_ids": {},
		"friendly_army_ids": {},
		"enemy_army_ids": {}
	}

func clear_castle_nearby_entities() -> void:
	castle_nearby_entities = _build_empty_nearby_entities()

func can_build_castle() -> bool:
	"""Check if a castle can be built in this region"""
	# Cannot build if already has castle or construction in progress
	if has_castle() or is_castle_under_construction():
		return false
	
	# Cannot build in ocean regions
	if is_ocean:
		return false
	
	return true

func can_upgrade_castle() -> bool:
	"""Check if the current castle can be upgraded"""
	# Must have a castle and not be under construction
	if not has_castle() or is_castle_under_construction():
		return false
	if is_castle_under_repair():
		return false
	if has_castle_damage():
		return false
	
	# Check if castle can be upgraded to next level
	return CastleTypeEnum.can_upgrade(castle_type)

# Mining system methods
func can_search_for_ore() -> bool:
	"""Check if ore search is possible in this region"""
	# Must be a region that can have ores
	if not GameParameters.can_search_for_ore_in_region(region_type):
		return false
	
	# Stop searching after any ore has been discovered
	if not discovered_ores.is_empty():
		return false
	
	# Must have search attempts remaining
	if ore_search_attempts_remaining <= 0:
		return false
	
	# Cannot search if already used this turn
	if ore_search_used_this_turn:
		return false
	
	# Cannot search in ocean regions
	if is_ocean:
		return false
	
	return true

func get_ore_search_attempts_remaining() -> int:
	"""Get the number of ore search attempts remaining"""
	return ore_search_attempts_remaining

func set_scenario_ore_rules_enabled(enabled: bool) -> void:
	ore_scenario_rules_enabled = enabled

func set_ore_guaranteed_discovery(attempt: int, ore_type: ResourcesEnum.Type) -> void:
	ore_guaranteed_discovery_attempt = maxi(0, attempt)
	ore_guaranteed_discovery_type = ore_type

func get_ore_guaranteed_discovery_attempt() -> int:
	return ore_guaranteed_discovery_attempt

func get_ore_guaranteed_discovery_type() -> ResourcesEnum.Type:
	return ore_guaranteed_discovery_type

func _get_available_ore_types_for_discovery() -> Array[ResourcesEnum.Type]:
	var ore_types: Array[ResourcesEnum.Type] = []
	if get_resource_amount(ResourcesEnum.Type.GOLD) > 0:
		ore_types.append(ResourcesEnum.Type.GOLD)
	if get_resource_amount(ResourcesEnum.Type.IRON) > 0:
		ore_types.append(ResourcesEnum.Type.IRON)
	return ore_types

func _resolve_ore_type_for_discovery(available_ore_types: Array[ResourcesEnum.Type]) -> ResourcesEnum.Type:
	if ore_scenario_rules_enabled:
		if available_ore_types.size() == 1:
			return available_ore_types[0]
	return GameParameters.roll_ore_type()

func search_for_ore() -> Dictionary:
	"""Perform ore search. Returns {success: bool, ore_type: ResourcesEnum.Type, message: String}"""
	if not can_search_for_ore():
		return {"success": false, "ore_type": ResourcesEnum.Type.GOLD, "message": "Cannot search for ore in this region"}
	
	# Use up one attempt
	ore_search_attempts_remaining -= 1
	ore_search_used_this_turn = true

	var discovery_successful: bool = false
	var ore_type: ResourcesEnum.Type = ResourcesEnum.Type.IRON
	var attempts_used: int = GameParameters.ORE_SEARCH_CHANCES_PER_REGION - ore_search_attempts_remaining
	var is_forced_attempt: bool = ore_guaranteed_discovery_attempt > 0 and attempts_used == ore_guaranteed_discovery_attempt
	var available_ore_types: Array[ResourcesEnum.Type] = _get_available_ore_types_for_discovery()

	if ore_scenario_rules_enabled and available_ore_types.is_empty():
		discovery_successful = false
	elif is_forced_attempt:
		if ore_scenario_rules_enabled and not available_ore_types.has(ore_guaranteed_discovery_type):
			discovery_successful = false
		else:
			discovery_successful = true
			ore_type = ore_guaranteed_discovery_type
	else:
		discovery_successful = GameParameters.roll_ore_discovery()
		if discovery_successful:
			ore_type = _resolve_ore_type_for_discovery(available_ore_types)
			if ore_scenario_rules_enabled and not available_ore_types.has(ore_type):
				discovery_successful = false
	
	if discovery_successful:
		
		# Add to discovered ores if not already found
		if ore_type not in discovered_ores:
			discovered_ores.append(ore_type)
			ore_search_attempts_remaining = 0
		
		DebugLogger.log("RegionManagement", "Ore discovered in " + region_name + "! Found: " + ResourcesEnum.type_to_string(ore_type))
		return {"success": true, "ore_type": ore_type, "message": "Discovered " + ResourcesEnum.type_to_string(ore_type) + " ore!"}
	else:
		DebugLogger.log("RegionManagement", "No ore found in " + region_name + " (" + str(ore_search_attempts_remaining) + " attempts remaining)")
		return {"success": false, "ore_type": ResourcesEnum.Type.GOLD, "message": "No ore found "}

func has_discovered_ore(ore_type: ResourcesEnum.Type) -> bool:
	"""Check if a specific ore type has been discovered in this region"""
	return ore_type in discovered_ores

func get_discovered_ores() -> Array[ResourcesEnum.Type]:
	"""Get all discovered ore types"""
	return discovered_ores.duplicate()

func can_collect_resource(resource_type: ResourcesEnum.Type) -> bool:
	"""Check if a resource can be collected (for Gold/Iron, must be discovered first)"""
	# For Gold and Iron, must be discovered first
	if resource_type == ResourcesEnum.Type.GOLD or resource_type == ResourcesEnum.Type.IRON:
		return has_discovered_ore(resource_type)
	
	# Other resources can be collected normally
	return get_resource_amount(resource_type) > 0

func reset_ore_search_turn_usage() -> void:
	"""Reset the ore search usage flag for the new turn"""
	ore_search_used_this_turn = false

func reset_turn_actions_usage() -> void:
	"""Reset per-turn action usage flags"""
	reset_ore_search_turn_usage()
	raise_army_used_this_turn = false
	promotion_used_this_turn = false
	just_conquered_this_turn = false

func has_raised_army_this_turn() -> bool:
	return raise_army_used_this_turn

func mark_raise_army_used() -> void:
	raise_army_used_this_turn = true

func has_promoted_this_turn() -> bool:
	return promotion_used_this_turn

func mark_promoted_this_turn() -> void:
	promotion_used_this_turn = true

func add_call_to_arms_recruits(amount: int) -> void:
	"""Add recruits gathered via call to arms (can exceed current recruit cap)."""
	if amount <= 0:
		return
	population += amount
	available_recruits += amount

func get_ore_search_status_string() -> String:
	"""Get a human-readable string describing ore search status"""
	if not GameParameters.can_search_for_ore_in_region(region_type):
		return tr("No ore")

	if ore_search_attempts_remaining <= 0:
		if discovered_ores.is_empty():
			return tr("No ore")
		var ore_names: Array[String] = []
		for ore in discovered_ores:
			ore_names.append(ResourcesEnum.type_to_display_string(ore))
		return tr("%s Found") % ", ".join(ore_names)

	var search_word: String = tr("search") if ore_search_attempts_remaining == 1 else tr("searches")
	var status = tr("%d %s") % [ore_search_attempts_remaining, search_word]

	if not discovered_ores.is_empty():
		var ore_names: Array[String] = []
		for ore in discovered_ores:
			ore_names.append(ResourcesEnum.type_to_display_string(ore))
		status = tr("%s Found") % ", ".join(ore_names)

	return status

# Ownership tracking methods
func set_region_owner(owner_id: int) -> void:
	"""Set region owner and reset ownership counter (called when ownership changes)"""
	if current_owner_id != owner_id:
		var old_owner = current_owner_id
		current_owner_id = owner_id
		ownership_turns_counter = 0  # Reset counter on ownership change
		DebugLogger.log("RegionManagement", region_name + " ownership changed from Player " + str(old_owner) + " to Player " + str(owner_id) + " (recruitment counter reset)")

func set_initial_region_owner(owner_id: int) -> void:
	"""Set region owner for initial castle placement with full recruitment counter"""
	current_owner_id = owner_id
	ownership_turns_counter = 5  # Full recruitment immediately available

func get_region_owner() -> int:
	"""Get current region owner player ID"""
	return current_owner_id

func get_ownership_turns() -> int:
	"""Get how many turns region has been owned by current owner"""
	return ownership_turns_counter

func increment_ownership_counter() -> void:
	"""Increment ownership counter (called each turn for owned regions)"""
	if current_owner_id > 0:  # Only increment if region is owned
		ownership_turns_counter += 1

func get_ownership_recruitment_modifier() -> float:
	"""Get the recruitment modifier based on ownership duration"""
	if current_owner_id == 0:  # Neutral regions have no recruitment modifier
		return 1.0
	
	if ownership_turns_counter >= 5:  # Full recruitment after 5 turns
		return 1.0
	
	# 0 turns = 0%, 1 turn = 20%, 2 turns = 40%, etc.
	return ownership_turns_counter * 0.2

# AI Scoring management methods
func set_ai_scores(cluster_score: float, individual_score: float, factors: Dictionary, cluster_data: Dictionary) -> void:
	"""Set AI scoring data for this region"""
	ai_cluster_score = cluster_score
	ai_individual_score = individual_score
	ai_scoring_factors = factors
	ai_cluster_data = cluster_data
	ai_scoring_valid = true

func get_ai_cluster_score() -> float:
	"""Get stored cluster score (0-100), returns 0 if invalid"""
	return ai_cluster_score if ai_scoring_valid else 0.0

func get_ai_individual_score() -> float:
	"""Get stored individual score (0-100), returns 0 if invalid"""
	return ai_individual_score if ai_scoring_valid else 0.0

func get_ai_scoring_factors() -> Dictionary:
	"""Get detailed scoring factors, returns empty if invalid"""
	return ai_scoring_factors if ai_scoring_valid else {}

func get_ai_cluster_data() -> Dictionary:
	"""Get cluster metrics data, returns empty if invalid"""
	return ai_cluster_data if ai_scoring_valid else {}

func is_ai_scoring_valid() -> bool:
	"""Check if stored AI scores are still valid"""
	return ai_scoring_valid

func invalidate_ai_scores() -> void:
	"""Mark AI scores as invalid (called when game state changes)"""
	ai_scoring_valid = false
	# Keep the data but mark it invalid - will be recalculated when needed

# Strategic points heatmap API
func set_strategic_point_score(value: float) -> void:
	strategic_point_score = max(0.0, value)

func get_strategic_point_score() -> float:
	return strategic_point_score

func get_wounded_garrison() -> ArmyComposition:
	"""Get the wounded garrison composition"""
	return wounded_garrison

func get_wounded_recruits() -> ArmyComposition:
	"""Get the wounded recruits composition (peasants only)"""
	return wounded_recruits

func get_wounded_recruits_total() -> int:
	"""Get total wounded recruits count (peasants)."""
	return wounded_recruits.get_soldier_count(SoldierTypeEnum.Type.PEASANTS)

func heal_all_wounded() -> void:
	"""Heal all wounded in this region: move wounded garrison back to garrison;
	clear wounded recruits (peasants). Called at the start of the owner's turn."""
	# Heal garrison: transfer all wounded counts back into active garrison
	for unit_type in SoldierTypeEnum.get_all_types():
		var wcount := wounded_garrison.get_soldier_count(unit_type)
		if wcount > 0:
			wounded_garrison.remove_soldiers(unit_type, wcount)
			garrison.add_soldiers(unit_type, wcount)
	# Heal recruits (peasants-only): clear wounded pool
	var wr := wounded_recruits.get_soldier_count(SoldierTypeEnum.Type.PEASANTS)
	if wr > 0:
		wounded_recruits.remove_soldiers(SoldierTypeEnum.Type.PEASANTS, wr)
		var max_recruits := GameParameters.calculate_max_recruits(population, region_level)
		available_recruits = min(available_recruits + wr, max_recruits)

func get_income() -> int:
	"""Get gold income generated by this region's population"""
	if is_ocean:
		return 0  # Ocean regions don't generate income
	
	var level_int = RegionLevelEnum.level_to_number(region_level)
	
	# Formula: floor(Population / (64 - 4 * region_level))
	var divisor = GameParameters.POPULATION_INCOME_BASE_DIVISOR - (GameParameters.POPULATION_INCOME_LEVEL_MULTIPLIER * level_int)
	
	# Prevent division by zero or negative divisors
	if divisor <= 0:
		return 0
	
	var gold_income = 1 + int(population / divisor)
	return max(0, gold_income)
