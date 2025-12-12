extends RefCounted
class_name GameParameters

# ============================================================================
# GAME PARAMETERS
# ============================================================================
# 
# Purpose: Centralized configuration and parameter management for game mechanics
# 
# Core Responsibilities:
# - Unit combat statistics and recruitment costs
# - Movement costs by terrain type and army limitations
# - Resource generation ranges by region and biome type
# - Battle system configuration and timing parameters
# - Population and garrison generation by region level
# 
# Required Functions:
# - get_unit_stat(): Access unit combat and cost data
# - generate_resource_amount(): Region-based resource generation
# - generate_population_size(): Level-based population creation
# - get_movement_cost(): Terrain movement cost lookups
# - Static helper functions for game balance access
# 
# Integration Points:
# - All game systems: Centralized parameter access
# - Region generation: Resource and population rules
# - Combat system: Unit statistics and battle timing
# - Army movement: Terrain costs and movement points
# ============================================================================

## Single-line Configuration Constants
const MOVEMENT_POINTS_PER_TURN = 5          # Army movement points per turn
const BATTLE_ROUND_TIME = 0.55               # Seconds between animated battle rounds
const BIOME_ICON_SCALE = 0.2                # Map generation icon scale
const FOREST_ICON_SCALE = 0.2               # Forest icon scale (customizable size)
const RECRUIT_PERCENTAGE_OF_POPULATION = 0.08  # % of population becomes available recruits
const RECRUIT_REPLENISH_RATE = 0.01            # % of population replenishes per turn
const POPULATION_GROWTH_RATE = 0.02            # Base population growth rate (%)
const POPULATION_CONST_GROWTH_RATE = 0.01
const WITHDRAWAL_FREE_HIT_ROUNDS = 3           # Number of free hit rounds enemy gets during withdrawal
const MOBILITY_EXTRA_WITHDRAWAL_ROUNDS = 3    # Extra rounds mobility units get to attack withdrawing enemies
const ENEMY_ARMY_MEMORY_ROUNDS = 5            # Rounds to retain enemy army power knowledge for AI players
const AI_ENEMY_REGION_SCORE_BONUS = 5          # Bonus added when targeting enemy-owned regions
const AI_WITHDRAW_MAX_POWER_DIFFERENCE = 0.20	# Power gap (20%) that forces withdrawal once reached

## Border Enhancement Constants
const BORDER_SATURATION_BOOST = 0.1           # Increase saturation by 20% for colored borders
const BORDER_VALUE_REDUCTION = 0.15           # Darken borders by 15% 
const BORDER_OPACITY = 0.9                    # Border opacity (90%)
const BORDER_MIN_VALUE = 0.2                  # Minimum darkness to prevent too-dark borders

## UI Colors (shared)
const UI_COLOR_DEAD = Color.RED                # Used for dead counts in summaries
const UI_COLOR_WOUNDED = Color.YELLOW          # Used for wounded counts in summaries

const SCOUT_ARMY_SIZE_THRESHOLDS: Array = [
	{"min": 0, "max": 10, "description": "Your scouts believe the area is barely defended, with only isolated enemies present."},
	{"min": 10, "max": 30, "description": "Your scouts observed a small enemy detachment guarding the area."},
	{"min": 30, "max": 60, "description": "Your scouts report a sizable enemy force defending the region."},
	{"min": 60, "max": 100, "description": "Your scouts observed a strong enemy contingent holding the position."},
	{"min": 100, "max": 150, "description": "Your scouts detected a large concentration of enemy troops in the area."},
	{"min": 150, "max": 250, "description": "Your scouts observed a major assembly of troops preparing for battle."},
	{"min": 250, "max": 400, "description": "Your scouts detected a massive concentration of enemy troops across the battlefield."},
	{"min": 400, "max": 800, "description": "Your scouts warn that an enormous host of soldiers holds this territory."},
	{"min": 800, "max": -1, "description": "Your scouts report enemy numbers beyond reliable counting—an entire army stands before you."}
]

## Region Highlight Transparency
const REGION_ANIM_OWNED_ALPHA_FROM = 0.5
const REGION_ANIM_OWNED_ALPHA_TO = 0.75
const REGION_ANIM_NEUTRAL_ALPHA_FROM = 0.35
const REGION_ANIM_NEUTRAL_ALPHA_TO = 0.55
const REGION_MOVE_HOVER_OWNED_ALPHA = 0.85
const REGION_MOVE_HOVER_NEUTRAL_ALPHA = 0.55
const REGION_MAP_HOVER_OWNED_BASE_ALPHA = 0.6
const REGION_MAP_HOVER_OWNED_HOVER_ALPHA = 0.7
const REGION_MAP_HOVER_NEUTRAL_BASE_ALPHA = 0.2
const REGION_MAP_HOVER_NEUTRAL_HOVER_ALPHA = 0.3

## Region Level Bonuses
const REGION_RESOURCE_LEVEL_MULTIPLIER = 0.25   # Resource bonus per level: +25% per level above 1
const PROMOTION_GROWTH_BONUS_TURNS = 5          # Number of turns promotion growth bonus lasts

## Promotion Growth Bonus by Turn (added to base growth rate)
const PROMOTION_GROWTH_BONUS_BY_TURN = {
	1: 0.04,  # 1st turn: 
	2: 0.035,  # 2nd turn: 
	3: 0.03,  # 3rd turn: 
	4: 0.025,  # 4th turn: 
	5: 0.02   # 5th turn: 
}

## Castle Recruitment Bonuses (percentage of population becomes recruits)
const CASTLE_RECRUITMENT_PERCENTAGES = {
	CastleTypeEnum.Type.NONE: 0.05,         # No castle:
	CastleTypeEnum.Type.OUTPOST: 0.05,      # Outpost: 
	CastleTypeEnum.Type.KEEP: 0.06,         # Keep:
	CastleTypeEnum.Type.CASTLE: 0.06,       # Castle:
	CastleTypeEnum.Type.STRONGHOLD: 0.7    # Stronghold:
}

## AI Region Scoring Weights (0-100 scale normalization factors)
# Population scoring
const AI_POPULATION_WEIGHT = 0.05              # Population contribution to score (5% per 100 population)
const AI_POPULATION_MAX_EXPECTED = 1000        # Expected max population for normalization

# Random score modifier for castle placement
const AI_RANDOM_SCORE_MODIFIER = 5             # Random value (0 to this value) added to each player's castle placement scores

# Resource scoring weights
const AI_GOLD_RESOURCE_WEIGHT = 0.5            # Gold resources are highly valued
const AI_FOOD_RESOURCE_WEIGHT = 1.25            # Food important for army maintenance  
const AI_WOOD_RESOURCE_WEIGHT = 1.0            # Wood for building
const AI_STONE_RESOURCE_WEIGHT = 1.0           # Stone for building
const AI_IRON_RESOURCE_WEIGHT = 1.25            # Iron for advanced units
const AI_MAX_EXPECTED_RESOURCE = 50             # Expected max resource amount for normalization

# Strategic value weights
const AI_REGION_LEVEL_WEIGHT = 8.0             # Region level very important (8 points per level)
const AI_CASTLE_LEVEL_WEIGHT = 10.0            # Castle level highly important (10 points per level)

# Neighbor analysis weights  
const AI_OWNED_NEIGHBOR_WEIGHT = 2.0           # Own neighbors provide defensive value
const AI_NEUTRAL_NEIGHBOR_WEIGHT = 3.0         # Neutral neighbors are expansion opportunities
const AI_ENEMY_NEIGHBOR_WEIGHT = -1.0          # Enemy neighbors are threats
const AI_TOTAL_NEIGHBOR_WEIGHT = 1.0           # More neighbors = more strategic position

# Distance and position weights
const AI_ENEMY_DISTANCE_WEIGHT = 5.0           # Closer to enemies = more strategic value
const AI_MAX_EXPECTED_DISTANCE = 10            # Expected max distance for normalization

## Mining System Constants
const ORE_SEARCH_COST = 10                      # Gold cost to perform ore search
const ORE_SEARCH_CHANCES_PER_REGION = 3        # Number of ore search attempts per region
const ORE_DISCOVERY_CHANCE = 0.25               # 20% chance to find ore per search
const ORE_TYPE_IRON_CHANCE = 0.80              # 80% chance for iron, 20% for gold

## Army Management Constants
const RAISE_ARMY_COST = 20                     # Gold cost to raise a new army

## Population Income Formula Constants
const POPULATION_INCOME_BASE_DIVISOR = 165      # Base divisor for population gold income formula
const POPULATION_INCOME_LEVEL_MULTIPLIER = 15   # Level multiplier for population gold income formula

## AI Raise Army Decision Parameters
# Cost/Reserves
const AI_RESERVE_GOLD_MIN = 30                 # Minimum gold to keep after raising army
# Eligibility
const AI_MIN_RECRUITS_FOR_RAISING = 40         # Minimum recruits at castle+neighbors to consider raising
# Global Guards
const AI_MAX_UNDERPOWERED_RATIO = 0.5          # Max fraction of armies below target power
const AI_MIN_RECRUITS_PER_ARMY_AFTER_RAISE = 25  # Support load target after raising
# Scoring Weights for global decision
const AI_RAISE_W_FRONTIER = 20.0               # Weight for frontier pressure
const AI_RAISE_W_SPACING = 10.0                # Weight for castle spacing              # Weight for bank ratio
const AI_RAISE_W_POWER_GAP = 25.0              # Weight for power gap (negative contribution)
# Candidate scoring weights
const AI_CAND_W_RECRUITS = 40.0                # Weight for recruit availability
const AI_CAND_W_FRONTIER_NEAR = 30.0           # Weight for frontier proximity
const AI_CAND_W_TRAVEL = 20.0                  # Weight for travel hint
# Decision Threshold
const AI_RAISE_THRESHOLD = 35.0                # Global decision cutoff score
# Target army power for raise army decisions
const AI_TARGET_ARMY_POWER = 100               # Target power threshold for underpowered armies
const MAX_ARMIES_PER_REGION = 5                # Maximum armies allowed in a single region

# New raise-army decision tuning (normalized model)
const AI_RAISE_R2A_BAND_MIN = 3.0
const AI_RAISE_R2A_BAND_MAX = 5.0
const AI_RAISE_DIST_MIN = 2.0
const AI_RAISE_DIST_MAX = 10.0
const AI_RAISE_RECRUITS_MIN = AI_MIN_RECRUITS_FOR_RAISING
const AI_RAISE_RECRUITS_MAX = 200
const AI_RAISE_BANK_RESERVE = AI_RESERVE_GOLD_MIN
const AI_RAISE_BANK_MAX = AI_RESERVE_GOLD_MIN + 170
const AI_RAISE_SUPPORT_MIN = 0.25
const AI_RAISE_W_R2A = 0.50
const AI_RAISE_W_DIST = 0.20
const AI_RAISE_W_RECRUITS = 0.20
const AI_RAISE_W_BANK = 0.10
const AI_RAISE_THRESHOLD_NORM = 0.50

## Dynamic Resource Need Scoring (ArmyTargetScorer)
# Need multipliers
const AI_NEED_NEG_GROWTH_MULT = 3.0           # Multiplier when net change per turn is negative
const AI_NEED_COVERAGE_TARGET = 2.0           # Target coverage in turns (stock / net)
const AI_NEED_COVERAGE_MULT = 2.0             # Multiplier when coverage < target
const AI_NEED_LOW_STOCK_MULT = 2.0            # Multiplier for very low absolute stock
# Minimum stock thresholds per resource
const AI_NEED_MIN_STOCK = {
	ResourcesEnum.Type.FOOD: 50,
	ResourcesEnum.Type.WOOD: 30,
	ResourcesEnum.Type.STONE: 30,
	ResourcesEnum.Type.IRON: 20,
	ResourcesEnum.Type.GOLD: 0
}
const AI_NEED_SCORE_MAX = 10.0                # Resource need score cap per resource


## AI Peasants-Only Recruitment Parameters
# Minimum peasant share threshold
enum WealthLevel {
	POOR,
	NORMAL,
	RICH
}

const AI_PEA_MIN_PROP_BASE = 0.20               # Minimum acceptable peasant share trigger (20%)
# Army power thresholds for target peasant share
const AI_PEA_POWER_LOW_MAX = 150                # Upper bound for "low power" armies
const AI_PEA_POWER_HIGH_MIN = 300               # Lower bound for "high power" armies
# Target peasant shares by army power
const AI_PEA_TARGET_PROP_LOW = 0.40             # Target share for low power armies (40%)
const AI_PEA_TARGET_PROP_MID = 0.30             # Target share for mid power armies (30%)
const AI_PEA_TARGET_PROP_HIGH = 0.20            # Target share for high power armies (20%)
const AI_MIN_FOOD_AFTER_UPGRADE = 50            # Minimum net food after region upgrade safeguard

## Army Pathfinder Algorithm Constants
const ARMY_PATHFINDER_HORIZON_MP = 15          # Maximum MP horizon for pathfinding (3 turns * 5 MP)
const ARMY_MOVEMENT_GAMMA_TURN = 0.9           # Discount factor for future turn scoring
const ARMY_MOVEMENT_MIN_WANTED = 5             # Minimum desired score (0-100) to trigger movement

## Power-Ratio Based Danger System
const ARMY_DANGER_PR_MULTIPLIER = 0.15         # Multiplier for power ratio penalty (k in formula)
const ARMY_DANGER_MAX_PENALTY = 0.4           # Maximum danger penalty (25% cap)
const ARMY_DANGER_GARRISON_POWER = 50          # Power value assigned to garrison units

## Terrain Combat Bonuses
const CHARGE_BONUS_GRASSLAND = 1.0              # 100% attack bonus for charge units on grassland

## Armor Piercing Bonuses
const ARMOR_PIERCING_DEFENSE_REDUCTION = 0.5    # Halves enemy defense (50% reduction)

## Long-Spears Bonuses
const LONG_SPEARS_CAVALRY_MULTIPLIER = 2.0      # Doubles hits against cavalry units

# Wounded system
const WOUNDED_CHANCE = 0.30						# Base chance per casualty to become wounded (0..1)
const CAMP_HEAL_CHANCE = 0.50						# Chance to heal one wounded unit on make_camp() (0..1)
const AI_WITHDRAW_POWER_THRESHOLD = 0.80			# AI withdraw triggers when own power <= 80% of enemy power
const MOVE_ANIMATION_DURATION = 0.5				# Seconds for army move animation

## Camera Centering Timing Constants
const CAMERA_ARMY_START_DELAY = 0.1			# Seconds to pause after centering on army before movement
const CAMERA_BATTLE_RESULT_DELAY = 0.1			# Seconds to pause after battle results (victory/defeat/withdrawal)
const CAMERA_CONQUEST_DELAY = 0.1				# Seconds to pause after region conquest to show ownership change
const CAMERA_FRIENDLY_MOVE_DELAY = 0.1			# Seconds to pause after friendly army moves

## Castle Defense Bonuses
const CASTLE_DEFENSE_BONUSES = {
	CastleTypeEnum.Type.NONE: 0,          # No castle
	CastleTypeEnum.Type.OUTPOST: 40,      # Outpost 
	CastleTypeEnum.Type.KEEP: 55,         # Keep
	CastleTypeEnum.Type.CASTLE: 70,       # Castle 
	CastleTypeEnum.Type.STRONGHOLD: 85    # Stronghold 
}

const CASTLE_DEFENSE_BONUSES_MIN = {
	CastleTypeEnum.Type.NONE: 0,          # No castle - 0% hit avoidance
	CastleTypeEnum.Type.OUTPOST: 10,      # Outpost - 20% hit avoidance  
	CastleTypeEnum.Type.KEEP: 25,         # Keep - 40% hit avoidance
	CastleTypeEnum.Type.CASTLE: 30,       # Castle - 60% hit avoidance
	CastleTypeEnum.Type.STRONGHOLD: 40    # Stronghold - 75% hit avoidance
}

## Unit Tier System
# Defines which units are available at each region level
const UNIT_TIERS = {
	SoldierTypeEnum.Type.PEASANTS: 1,      # Tier 1 - Available at L1+
	SoldierTypeEnum.Type.SPEARMEN: 2,      # Tier 1 - Available at L1+
	SoldierTypeEnum.Type.SWORDSMEN: 2,     # Tier 2 - Available at L2+
	SoldierTypeEnum.Type.ARCHERS: 2,       # Tier 2 - Available at L2+
	SoldierTypeEnum.Type.CROSSBOWMEN: 3,   # Tier 3 - Available at L3+
	SoldierTypeEnum.Type.HORSEMEN: 3,      # Tier 3 - Available at L3+
	SoldierTypeEnum.Type.KNIGHTS: 4,       # Tier 4 - Available at L4+
	SoldierTypeEnum.Type.MOUNTED_KNIGHTS: 4, # Tier 4 - Available at L4+
	SoldierTypeEnum.Type.ROYAL_GUARD: 5    # Tier 5 - Available at L5+
}

## Castle Type to Tier Mapping
# Maps castle types to maximum recruitment tier
const CASTLE_RECRUITMENT_TIERS = {
	CastleTypeEnum.Type.NONE: 1,      # No castle - Basic units only
	CastleTypeEnum.Type.OUTPOST: 2,   # Outpost - Basic + advanced units
	CastleTypeEnum.Type.KEEP: 3,      # Keep - Basic + advanced + mounted units
	CastleTypeEnum.Type.CASTLE: 4,    # Castle - Basic + advanced + mounted + elite units
	CastleTypeEnum.Type.STRONGHOLD: 5 # Stronghold - All units available
}

## Unit Combat Statistics
# Stats migrated from battle_sim.py for consistency
const UNIT_STATS = {
	SoldierTypeEnum.Type.PEASANTS: {
		"attack": 5,      # 5% hit chance per unit
		"defense": 10,    # 10% chance to deflect hits
		"cost": 0,        # Free recruitment (food cost 0.1 handled separately)
		"gold_cost": 0,
		"food_cost": 0.1,
		"wood_cost": 0,
		"iron_cost": 0,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_8],  # no_armor,
		"power": 2
	},
	SoldierTypeEnum.Type.SPEARMEN: {
		"attack": 8,     # 10% hit chance per unit
		"defense": 20,    # 25% chance to deflect hits
		"cost": 1,        # Recruitment cost
		"gold_cost": 1,
		"food_cost": 0.1,
		"wood_cost": 0,
		"iron_cost": 0,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_1, UnitTraitEnum.Type.UNIT_TRAIT_9],  # long_spears, light_armor,
		"power": 3
	},
	SoldierTypeEnum.Type.SWORDSMEN: {
		"attack": 12,     # 30% hit chance per unit
		"defense": 30,    # 40% chance to deflect hits
		"cost": 2,        # Recruitment cost
		"gold_cost": 3,
		"food_cost": 0.1,
		"wood_cost": 0,
		"iron_cost": 0,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_10],  # medium_armor,
		"power": 4
	},
	SoldierTypeEnum.Type.ARCHERS: {
		"attack": 10,     # 25% hit chance per unit
		"defense": 15,    # 15% chance to deflect hits
		"cost": 3,        # Recruitment cost
		"gold_cost": 4,
		"food_cost": 0.1,
		"wood_cost": 1,
		"iron_cost": 0,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_2, UnitTraitEnum.Type.UNIT_TRAIT_9],  # ranged, light_armor,
		"power": 3
	},
	SoldierTypeEnum.Type.CROSSBOWMEN: {
		"attack": 8,     # 20% hit chance per unit
		"defense": 15,    # 15% chance to deflect hits
		"cost": 2,        # Recruitment cost
		"gold_cost": 4,
		"food_cost": 0.1,
		"wood_cost": 1,
		"iron_cost": 0,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_2, UnitTraitEnum.Type.UNIT_TRAIT_7, UnitTraitEnum.Type.UNIT_TRAIT_9],  # ranged, armor_piercing, light_armor,
		"power": 4
	},
	SoldierTypeEnum.Type.HORSEMEN: {
		"attack": 12,     # 30% hit chance per unit
		"defense": 25,    # 30% chance to deflect hits
		"cost": 4,        # Recruitment cost
		"gold_cost": 5,
		"food_cost": 0.2,
		"wood_cost": 0,
		"iron_cost": 0,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_3, UnitTraitEnum.Type.UNIT_TRAIT_4, UnitTraitEnum.Type.UNIT_TRAIT_5, UnitTraitEnum.Type.UNIT_TRAIT_10],  # mobility, flanker, charge, medium_armor,
		"power": 5
	},
	SoldierTypeEnum.Type.KNIGHTS: {
		"attack": 25,     # 60% hit chance per unit
		"defense": 70,    # 60% chance to deflect hits
		"cost": 10,       # Recruitment cost
		"gold_cost": 10,
		"food_cost": 0.2,
		"wood_cost": 0,
		"iron_cost": 1,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_11],  # heavy_armor,
		"power": 10
	},
	SoldierTypeEnum.Type.MOUNTED_KNIGHTS: {
		"attack": 30,     # 65% hit chance per unit
		"defense": 70,    # 60% chance to deflect hits
		"cost": 15,       # Recruitment cost
		"gold_cost": 15,
		"food_cost": 0.4,
		"wood_cost": 0,
		"iron_cost": 1,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_4, UnitTraitEnum.Type.UNIT_TRAIT_5, UnitTraitEnum.Type.UNIT_TRAIT_11],  # flanker, charge, heavy_armor,
		"power": 13
	},
	SoldierTypeEnum.Type.ROYAL_GUARD: {
		"attack": 40,     # 80% hit chance per unit
		"defense": 90,    # 80% chance to deflect hits
		"cost": 20,       # Recruitment cost
		"gold_cost": 20,
		"food_cost": 0.3,
		"wood_cost": 0,
		"iron_cost": 1,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_6, UnitTraitEnum.Type.UNIT_TRAIT_11],  # multi_attack, heavy_armor,
		"power": 15
	}
}

## Movement Costs by Terrain Type
const MOVEMENT_COSTS = {
	RegionTypeEnum.Type.GRASSLAND: 2,     # Easy terrain
	RegionTypeEnum.Type.HILLS: 3,         # Difficult terrain
	RegionTypeEnum.Type.FOREST: 3,        # Difficult terrain
	RegionTypeEnum.Type.FOREST_HILLS: 4,  # Difficult terrain
	RegionTypeEnum.Type.MOUNTAINS: -1     # Impassable terrain
}


## Resource Generation by Region Type
# Format: resource_type -> {min, max} range for randi_range()
const REGION_RESOURCES = {
	RegionTypeEnum.Type.GRASSLAND: {
		ResourcesEnum.Type.FOOD: {"min": 1, "max": 4}
	},
	RegionTypeEnum.Type.FOREST: {
		ResourcesEnum.Type.WOOD: {"min": 1, "max": 3}
	},
	RegionTypeEnum.Type.HILLS: {
		ResourcesEnum.Type.STONE: {"min": 1, "max": 3},
		ResourcesEnum.Type.IRON: {"min": 2, "max": 5},
		ResourcesEnum.Type.GOLD: {"min": 5, "max": 15}
	},
	RegionTypeEnum.Type.FOREST_HILLS: {
		ResourcesEnum.Type.WOOD: {"min": 1, "max": 2},
		ResourcesEnum.Type.STONE: {"min": 0, "max": 2},
		ResourcesEnum.Type.IRON: {"min": 1, "max": 3},
		ResourcesEnum.Type.GOLD: {"min": 3, "max": 9}
	},
	RegionTypeEnum.Type.MOUNTAINS: {
		# No resources - impassable terrain
	}
}

## Ideal Army Compositions for Different Scenarios
const IDEAL_ARMY_COMPOSITIONS = {
	"None": {
		"peasants": 100,
		"spearmen": 0,
		"archers": 0,
		"swordsmen": 0,
		"crossbowmen": 0,
		"horsemen": 0,
		"knights": 0,
		"mounted_knights": 0,
		"royal_guard": 0
	},
	"Outpost": {
		"peasants": 40,
		"spearmen": 30,
		"archers": 20,
		"swordsmen": 10,
		"crossbowmen": 0,
		"horsemen": 0,
		"knights": 0,
		"mounted_knights": 0,
		"royal_guard": 0
	},
	"Keep": {
		"peasants": 35,
		"spearmen": 25,
		"archers": 15,
		"swordsmen": 15,
		"crossbowmen": 5,
		"horsemen": 5,
		"knights": 0,
		"mounted_knights": 0,
		"royal_guard": 0
	},
	"Castle": {
		"peasants": 24,
		"spearmen": 22,
		"archers": 15,
		"swordsmen": 16,
		"crossbowmen": 8,
		"horsemen": 7,
		"knights": 5,
		"mounted_knights": 3,
		"royal_guard": 0
	},
	"Stronghold": {
		"peasants": 20,
		"spearmen": 20,
		"archers": 13,
		"swordsmen": 16,
		"crossbowmen": 12,
		"horsemen": 7,
		"knights": 7,
		"mounted_knights": 4,
		"royal_guard": 1
	}
}

const IDEAL_CASTLE_GARRISON_COMPOSITIONS = {
	"None": {
		"peasants": 100,
		"spearmen": 0,
		"archers": 0,
		"swordsmen": 0,
		"crossbowmen": 0,
		"horsemen": 0,
		"knights": 0,
		"mounted_knights": 0,
		"royal_guard": 0
	},
	"Outpost": {
		"peasants": 40,
		"spearmen": 30,
		"archers": 20,
		"swordsmen": 10,
		"crossbowmen": 0,
		"horsemen": 0,
		"knights": 0,
		"mounted_knights": 0,
		"royal_guard": 0
	},
	"Keep": {
		"peasants": 35,
		"spearmen": 25,
		"archers": 15,
		"swordsmen": 15,
		"crossbowmen": 10,
		"horsemen": 0,
		"knights": 0,
		"mounted_knights": 0,
		"royal_guard": 0
	},
	"Castle": {
		"peasants": 24,
		"spearmen": 22,
		"archers": 20,
		"swordsmen": 16,
		"crossbowmen": 10,
		"horsemen": 0,
		"knights": 8,
		"mounted_knights": 0,
		"royal_guard": 0
	},
	"Stronghold": {
		"peasants": 20,
		"spearmen": 20,
		"archers": 19,
		"swordsmen": 16,
		"crossbowmen": 12,
		"horsemen": 0,
		"knights": 10,
		"mounted_knights": 0,
		"royal_guard": 3
	}
}

const GARRISON_TRICKLE_PER_CASTLE = {
	CastleTypeEnum.Type.OUTPOST: 4,
	CastleTypeEnum.Type.KEEP: 6,
	CastleTypeEnum.Type.CASTLE: 8,
	CastleTypeEnum.Type.STRONGHOLD: 10
}

const SAFE_GARRISON_POWER_PER_LEVEL = {
	CastleTypeEnum.Type.OUTPOST: 30,
	CastleTypeEnum.Type.KEEP: 60,
	CastleTypeEnum.Type.CASTLE: 100,
	CastleTypeEnum.Type.STRONGHOLD: 150
}

## Player Colors for Multi-Player Support
const PLAYER_COLORS = {
	1: Color('#ab3c16'), # Dark red
	2: Color('#6c817f'), # Custom blue-gray
	3: Color('#40481a'), # Dark green
	4: Color('#ff8000'), # Orange	
	5: Color('#e8e8d4'), # White
	6: Color('#604250')  # Dark purple
}

const WEALTH_NORMAL_THRESHOLD_GOLD = 200
const WEALTH_RICH_THRESHOLD_GOLD = 400

## Initial Player Resources
const STARTING_RESOURCES = {
	ResourcesEnum.Type.GOLD: 100,
	ResourcesEnum.Type.FOOD: 50,
	ResourcesEnum.Type.WOOD: 20,
	ResourcesEnum.Type.IRON: 10,
	ResourcesEnum.Type.STONE: 10
}

const STARTING_ARMY_COMPOSITION = {
	SoldierTypeEnum.Type.PEASANTS: 15,
	SoldierTypeEnum.Type.SPEARMEN: 10,
	SoldierTypeEnum.Type.SWORDSMEN: 5,
	SoldierTypeEnum.Type.ARCHERS: 5,
	SoldierTypeEnum.Type.CROSSBOWMEN: 0,
	SoldierTypeEnum.Type.HORSEMEN: 0,
	SoldierTypeEnum.Type.KNIGHTS: 1
}

const TRADE_PRICES = {
	ResourcesEnum.Type.WOOD: {"sell": 1, "buy": 2},
	ResourcesEnum.Type.FOOD: {"sell": 1, "buy": 2},
	ResourcesEnum.Type.STONE: {"sell": 2, "buy": 4},
	ResourcesEnum.Type.IRON: {"sell": 3, "buy": 6}
}

const TRADE_MARKET_MIN_PRICE = 0.4
const TRADE_MARKET_K = 0.01
const TRADE_RESET_RATE = 0.2
const AI_TRADE_THRESHOLD_FOOD = 100
const AI_TRADE_THRESHOLD_WOOD = 100
const AI_TRADE_THRESHOLD_STONE = 50
const AI_TRADE_THRESHOLD_IRON = 50

## Region Garrison Generation by Region Level
const GARRISON_BY_LEVEL = {
	RegionLevelEnum.Level.L1: {"min": 1, "max": 8},
	RegionLevelEnum.Level.L2: {"min": 1, "max": 15},
	RegionLevelEnum.Level.L3: {"min": 1, "max": 20},
	RegionLevelEnum.Level.L4: {"min": 1, "max": 0},
	RegionLevelEnum.Level.L5: {"min": 1, "max": 0}
}

## Population Generation by Region Level
const POPULATION_BY_LEVEL = {
	RegionLevelEnum.Level.L1: {"min": 50, "max": 300},
	RegionLevelEnum.Level.L2: {"min": 250, "max": 400},
	RegionLevelEnum.Level.L3: {"min": 400, "max": 600},
	RegionLevelEnum.Level.L4: {"min": 600, "max": 800},
	RegionLevelEnum.Level.L5: {"min": 800, "max": 1000}
}

## Region Promotion Costs by Target Level
# Costs required to promote a region to the specified level
const REGION_PROMOTION_COSTS = {
	RegionLevelEnum.Level.L2: {  # Cost to promote from L1 to L2
		ResourcesEnum.Type.GOLD: 10,
		ResourcesEnum.Type.FOOD: 20
	},
	RegionLevelEnum.Level.L3: {  # Cost to promote from L2 to L3
		ResourcesEnum.Type.GOLD: 15,
		ResourcesEnum.Type.FOOD: 30,
		ResourcesEnum.Type.WOOD: 10,
	},
	RegionLevelEnum.Level.L4: {  # Cost to promote from L3 to L4
		ResourcesEnum.Type.GOLD: 20,
		ResourcesEnum.Type.FOOD: 40,
		ResourcesEnum.Type.WOOD: 20,
		ResourcesEnum.Type.STONE: 0,
	},
	RegionLevelEnum.Level.L5: {  # Cost to promote from L4 to L5
		ResourcesEnum.Type.GOLD: 25,
		ResourcesEnum.Type.FOOD: 50,
		ResourcesEnum.Type.WOOD: 25,
		ResourcesEnum.Type.STONE: 5,
		ResourcesEnum.Type.IRON: 0
	}
}

## Castle Building Costs and Build Times
# Costs and construction time for each castle type
const CASTLE_BUILDING_COSTS = {
	CastleTypeEnum.Type.OUTPOST: {
		"cost": {
			ResourcesEnum.Type.GOLD: 30,
			ResourcesEnum.Type.WOOD: 30
		},
		"build_time": 2  # 2 turns to complete
	},
	CastleTypeEnum.Type.KEEP: {
		"cost": {
			ResourcesEnum.Type.GOLD: 50,
			ResourcesEnum.Type.WOOD: 20,
			ResourcesEnum.Type.STONE: 15
		},
		"build_time": 2  # 3 turns to complete
	},
	CastleTypeEnum.Type.CASTLE: {
		"cost": {
			ResourcesEnum.Type.GOLD: 75,
			ResourcesEnum.Type.WOOD: 25,
			ResourcesEnum.Type.STONE: 30,
			ResourcesEnum.Type.IRON: 10
		},
		"build_time": 2  # 4 turns to complete
	},
	CastleTypeEnum.Type.STRONGHOLD: {
		"cost": {
			ResourcesEnum.Type.GOLD: 100,
			ResourcesEnum.Type.WOOD: 30,
			ResourcesEnum.Type.STONE: 50,
			ResourcesEnum.Type.IRON: 20
		},
		"build_time": 2  # 6 turns to complete
	}
}


## Static Helper Functions

static func get_scout_threshold_entry(total: int) -> Dictionary:
	for entry in SCOUT_ARMY_SIZE_THRESHOLDS:
		var min_val: int = entry["min"]
		var max_val: int = entry["max"]
		if max_val == -1:
			if total >= min_val:
				return entry
		elif total >= min_val and total < max_val:
			return entry
	return SCOUT_ARMY_SIZE_THRESHOLDS.back()

static func get_unit_stat(unit_type: SoldierTypeEnum.Type, stat_name: String):
	"""Get a specific stat for a unit type"""
	return UNIT_STATS.get(unit_type, {}).get(stat_name, 0)

static func get_unit_gold_cost(unit_type: SoldierTypeEnum.Type) -> int:
	"""Get gold cost for recruiting a unit type"""
	return get_unit_stat(unit_type, "gold_cost")

static func get_unit_food_cost(unit_type: SoldierTypeEnum.Type) -> float:
	"""Get food cost for recruiting a unit type"""
	return get_unit_stat(unit_type, "food_cost")

static func get_unit_wood_cost(unit_type: SoldierTypeEnum.Type) -> int:
	"""Get wood cost for recruiting a unit type"""
	return get_unit_stat(unit_type, "wood_cost")

static func get_unit_iron_cost(unit_type: SoldierTypeEnum.Type) -> int:
	"""Get iron cost for recruiting a unit type"""
	return get_unit_stat(unit_type, "iron_cost")

static func get_unit_total_recruitment_cost(unit_type: SoldierTypeEnum.Type) -> Dictionary:
	"""Get complete recruitment cost breakdown for a unit type"""
	return {
		"gold": get_unit_gold_cost(unit_type),
		"food": get_unit_food_cost(unit_type),
		"wood": get_unit_wood_cost(unit_type),
		"iron": get_unit_iron_cost(unit_type)
	}

static func get_safe_garrison_power(castle_type: CastleTypeEnum.Type) -> int:
	"""Minimum desirable garrison strength per castle tier"""
	return SAFE_GARRISON_POWER_PER_LEVEL.get(castle_type, 0)

static func get_ideal_castle_garrison(castle_type: CastleTypeEnum.Type) -> Dictionary:
	"""Ideal garrison composition for a castle tier"""
	var key = CastleTypeEnum.type_to_string(castle_type)
	return IDEAL_CASTLE_GARRISON_COMPOSITIONS.get(key, {})

static func get_garrison_trickle_units(castle_type: CastleTypeEnum.Type) -> int:
	return GARRISON_TRICKLE_PER_CASTLE.get(castle_type, 0)

static func get_movement_cost(region_type: RegionTypeEnum.Type) -> int:
	"""Get movement cost for terrain type"""
	return MOVEMENT_COSTS.get(region_type, 1)

static func is_passable(region_type: RegionTypeEnum.Type) -> bool:
	"""Check if terrain is passable (movement cost != -1)"""
	return get_movement_cost(region_type) != -1

static func get_resource_range(region_type: RegionTypeEnum.Type, resource_type: ResourcesEnum.Type) -> Dictionary:
	"""Get min/max range for resource generation in region type"""
	var region_resources = REGION_RESOURCES.get(region_type, {})
	return region_resources.get(resource_type, {"min": 0, "max": 0})

static func generate_resource_amount(region_type: RegionTypeEnum.Type, resource_type: ResourcesEnum.Type) -> int:
	"""Generate random resource amount for region/resource combination"""
	var range_data = get_resource_range(region_type, resource_type)
	if range_data.min == 0 and range_data.max == 0:
		return 0
	return randi_range(range_data.min, range_data.max)

static func get_starting_resource_amount(resource_type: ResourcesEnum.Type) -> int:
	"""Get starting amount for a resource type"""
	return STARTING_RESOURCES.get(resource_type, 0)

static func generate_garrison_size(region_level: RegionLevelEnum.Level) -> int:
	"""Generate random garrison size based on region level"""
	var range_data = GARRISON_BY_LEVEL.get(region_level, {"min": 0, "max": 0})
	return randi_range(range_data.min, range_data.max)

static func generate_population_size(region_level: RegionLevelEnum.Level) -> int:
	"""Generate random population size based on region level"""
	var range_data = POPULATION_BY_LEVEL.get(region_level, {"min": 200, "max": 400})
	return randi_range(range_data.min, range_data.max)

static func calculate_max_recruits(population: int, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE) -> int:
	"""Calculate maximum recruits available based on population and castle type"""
	var recruitment_percentage = get_castle_recruitment_percentage(castle_type)
	return int(population * recruitment_percentage)

static func calculate_recruit_replenishment(population: int) -> int:
	"""Calculate recruit replenishment per turn based on population (1%)"""
	return int(population * RECRUIT_REPLENISH_RATE)

static func get_unit_tier(unit_type: SoldierTypeEnum.Type) -> int:
	"""Get the tier level for a unit type"""
	return UNIT_TIERS.get(unit_type, 1)

static func get_castle_max_tier(castle_type: CastleTypeEnum.Type) -> int:
	"""Get the maximum recruitment tier for a castle type"""
	return CASTLE_RECRUITMENT_TIERS.get(castle_type, 1)

static func can_recruit_unit_with_castle(unit_type: SoldierTypeEnum.Type, castle_type: CastleTypeEnum.Type) -> bool:
	"""Check if a unit type can be recruited with the given castle type"""
	var unit_tier = get_unit_tier(unit_type)
	var castle_max_tier = get_castle_max_tier(castle_type)
	return unit_tier <= castle_max_tier

static func get_promotion_cost(target_level: RegionLevelEnum.Level) -> Dictionary:
	"""Get the resource cost to promote a region to the target level"""
	return REGION_PROMOTION_COSTS.get(target_level, {})

static func can_afford_promotion(target_level: RegionLevelEnum.Level, player_resources: Dictionary) -> bool:
	"""Check if player can afford to promote region to target level"""
	var cost = get_promotion_cost(target_level)
	
	for resource_type in cost:
		var required_amount = cost[resource_type]
		var available_amount = player_resources.get(resource_type, 0)
		if available_amount < required_amount:
			return false
	
	return true

static func get_castle_building_cost(castle_type: CastleTypeEnum.Type) -> Dictionary:
	"""Get the resource cost to build a castle type"""
	var castle_data = CASTLE_BUILDING_COSTS.get(castle_type, {})
	return castle_data.get("cost", {})

static func get_castle_build_time(castle_type: CastleTypeEnum.Type) -> int:
	"""Get the build time in turns for a castle type"""
	var castle_data = CASTLE_BUILDING_COSTS.get(castle_type, {})
	return castle_data.get("build_time", 1)

static func can_afford_castle(castle_type: CastleTypeEnum.Type, player_resources: Dictionary) -> bool:
	"""Check if player can afford to build a castle type"""
	var cost = get_castle_building_cost(castle_type)
	
	for resource_type in cost:
		var required_amount = cost[resource_type]
		var available_amount = player_resources.get(resource_type, 0)
		if available_amount < required_amount:
			return false
	
	return true

static func can_search_for_ore_in_region(region_type: RegionTypeEnum.Type) -> bool:
	"""Check if ore search is possible in this region type"""
	# Only regions with Gold or Iron in their resource definitions can be searched
	var region_resources = REGION_RESOURCES.get(region_type, {})
	return region_resources.has(ResourcesEnum.Type.GOLD) or region_resources.has(ResourcesEnum.Type.IRON)

static func get_ore_search_cost() -> int:
	"""Get the gold cost for ore search"""
	return ORE_SEARCH_COST

static func get_ore_discovery_chance() -> float:
	"""Get the chance to discover ore per search"""
	return ORE_DISCOVERY_CHANCE

static func roll_ore_discovery() -> bool:
	"""Roll for ore discovery based on configured chance"""
	return randf() < ORE_DISCOVERY_CHANCE

static func roll_ore_type() -> ResourcesEnum.Type:
	"""Roll for ore type (Iron or Gold) based on configured chances"""
	if randf() < ORE_TYPE_IRON_CHANCE:
		return ResourcesEnum.Type.IRON
	else:
		return ResourcesEnum.Type.GOLD

static func get_starting_army_composition() -> Dictionary:
	var comp: Dictionary = {}
	for key in STARTING_ARMY_COMPOSITION.keys():
		comp[key] = int(STARTING_ARMY_COMPOSITION[key])
	return comp

static func get_ai_trade_threshold(resource_type: ResourcesEnum.Type) -> int:
	match resource_type:
		ResourcesEnum.Type.FOOD:
			return AI_TRADE_THRESHOLD_FOOD
		ResourcesEnum.Type.WOOD:
			return AI_TRADE_THRESHOLD_WOOD
		ResourcesEnum.Type.STONE:
			return AI_TRADE_THRESHOLD_STONE
		ResourcesEnum.Type.IRON:
			return AI_TRADE_THRESHOLD_IRON
		_:
			return 0

static func get_raise_army_cost() -> int:
	"""Get the gold cost for raising a new army"""
	return RAISE_ARMY_COST

static func get_unit_traits(unit_type: SoldierTypeEnum.Type) -> Array:
	"""Get all traits for a unit type"""
	return UNIT_STATS.get(unit_type, {}).get("traits", [])

static func unit_has_trait(unit_type: SoldierTypeEnum.Type, trait_type) -> bool:
	"""Check if a unit type has a specific trait"""
	var unit_traits = get_unit_traits(unit_type)
	return unit_traits.has(trait_type)

static func get_units_with_trait(trait_type) -> Array[SoldierTypeEnum.Type]:
	"""Get all unit types that have a specific trait"""
	var units_with_trait: Array[SoldierTypeEnum.Type] = []
	
	for unit_type in SoldierTypeEnum.get_all_types():
		if unit_has_trait(unit_type, trait_type):
			units_with_trait.append(unit_type)
	
	return units_with_trait

static func is_cavalry_unit(unit_type: SoldierTypeEnum.Type) -> bool:
	"""Check if a unit type is cavalry (has mobility or charge traits)"""
	return unit_has_trait(unit_type, UnitTraitEnum.Type.UNIT_TRAIT_3) or unit_has_trait(unit_type, UnitTraitEnum.Type.UNIT_TRAIT_5)  # mobility or charge

static func get_castle_defense_bonus(castle_type: CastleTypeEnum.Type) -> int:
	"""Get the defensive hit avoidance percentage for a castle type"""
	return CASTLE_DEFENSE_BONUSES.get(castle_type, 0)

static func get_castle_recruitment_percentage(castle_type: CastleTypeEnum.Type) -> float:
	"""Get the recruitment percentage for a castle type"""
	return CASTLE_RECRUITMENT_PERCENTAGES.get(castle_type, 0.02)

static func get_player_color(player_id: int) -> Color:
	"""Get the color for a specific player"""
	return PLAYER_COLORS.get(player_id, Color.WHITE)

static func get_ideal_composition(need_key: String) -> Dictionary:
	"""Get ideal army composition for a specific scenario"""
	if not IDEAL_ARMY_COMPOSITIONS.has(need_key):
		# Return empty dictionary for invalid keys - caller should handle this
		return {}
	return IDEAL_ARMY_COMPOSITIONS.get(need_key, {})

static func get_ideal_composition_for_wealth(need_key: String, wealth_level: int) -> Dictionary:
	"""Return an ideal composition adjusted for the player's wealth tier."""
	var base = get_ideal_composition(need_key)
	return _adjust_peasant_share_for_wealth(base, wealth_level)

static func get_ideal_castle_garrison_for_wealth(castle_type: CastleTypeEnum.Type, wealth_level: int) -> Dictionary:
	var base = get_ideal_castle_garrison(castle_type)
	return _adjust_peasant_share_for_wealth(base, wealth_level)

static func get_unit_power(unit_type: SoldierTypeEnum.Type) -> int:
	"""Get power value for a unit type"""
	return get_unit_stat(unit_type, "power")

static func get_unit_recruit_cost(unit_type: SoldierTypeEnum.Type) -> int:
	"""Get recruitment cost for a unit type (alias for gold cost)"""
	return get_unit_gold_cost(unit_type)

static func get_wealth_level_for_gold(gold: int) -> int:
	if gold >= WEALTH_RICH_THRESHOLD_GOLD:
		return WealthLevel.RICH
	if gold >= WEALTH_NORMAL_THRESHOLD_GOLD:
		return WealthLevel.NORMAL
	return WealthLevel.POOR

static func get_peasant_ratio_multiplier_for_wealth(wealth_level: int) -> float:
	if wealth_level == WealthLevel.NORMAL:
		return 0.5
	if wealth_level == WealthLevel.RICH:
		return 0.0
	return 1.0

static func adjust_peasant_prop_for_wealth(base_prop: float, wealth_level: int) -> float:
	return base_prop * get_peasant_ratio_multiplier_for_wealth(wealth_level)

static func get_ai_peasant_min_prop_for_wealth(wealth_level: int) -> float:
	return adjust_peasant_prop_for_wealth(AI_PEA_MIN_PROP_BASE, wealth_level)

static func get_ai_peasant_target_prop_low_for_wealth(wealth_level: int) -> float:
	return adjust_peasant_prop_for_wealth(AI_PEA_TARGET_PROP_LOW, wealth_level)

static func get_ai_peasant_target_prop_mid_for_wealth(wealth_level: int) -> float:
	return adjust_peasant_prop_for_wealth(AI_PEA_TARGET_PROP_MID, wealth_level)

static func get_ai_peasant_target_prop_high_for_wealth(wealth_level: int) -> float:
	return adjust_peasant_prop_for_wealth(AI_PEA_TARGET_PROP_HIGH, wealth_level)

static func _adjust_peasant_share_for_wealth(base: Dictionary, wealth_level: int) -> Dictionary:
	var adjusted = base.duplicate()
	if adjusted.is_empty():
		return adjusted
	var multiplier = get_peasant_ratio_multiplier_for_wealth(wealth_level)
	if multiplier >= 1.0:
		return adjusted
	var peasants_key = "peasants"
	var peasants_value: float = float(adjusted.get(peasants_key, 0.0))
	if peasants_value <= 0.0:
		return adjusted
	var non_peasant_total = 0.0
	for key in adjusted.keys():
		if key == peasants_key:
			continue
		non_peasant_total += float(adjusted[key])
	if non_peasant_total <= 0.0:
		adjusted[peasants_key] = peasants_value * multiplier
		return adjusted
	var new_peasants = peasants_value * multiplier
	var freed_share = peasants_value - new_peasants
	adjusted[peasants_key] = new_peasants
	var scale = (non_peasant_total + freed_share) / non_peasant_total
	for key in adjusted.keys():
		if key == peasants_key:
			continue
		adjusted[key] = float(adjusted[key]) * scale
	return adjusted
