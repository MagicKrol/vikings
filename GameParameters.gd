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
const BATTLE_ROUND_TIME_NORMAL = 1.5           # Seconds between animated battle rounds (normal)
const BATTLE_ROUND_TIME_FAST = 0.8             # Seconds between rounds when fast battle speed is selected
const BATTLE_ROUND_TIME_VERY_FAST = 0.4        # Seconds between rounds when very fast battle speed is selected
const BATTLE_ROUND_TIME = BATTLE_ROUND_TIME_NORMAL
const BATTLE_ROUND_TIME_QUICK = 0.01          # Seconds between rounds when quick resolve is triggered
const BIOME_ICON_SCALE = 0.2                # Map generation icon scale
const FOREST_ICON_SCALE = 0.2               # Forest icon scale (customizable size)          # Max peasants share during recruitment composition
const RECRUIT_RANGED_MIN_SHARE = 0.25          # legacy (unused)
const RECRUIT_RANGED_MAX_SHARE = 0.35          # legacy (unused)
const RECRUIT_RANGED_SHARE_MIN = 0.20          # Gaussian ranged diversion min
const RECRUIT_RANGED_SHARE_MAX = 0.30          # Gaussian ranged diversion max
const RECRUIT_GAUSS_SIGMA = 1.6
const RECRUIT_GAUSS_AMPLITUDE = 10.0
const RECRUIT_GAUSS_CUTOFF_X = 5.0
const RECRUIT_GAUSS_RATIO_MIN = 0.5
const RECRUIT_GAUSS_RATIO_MAX = 4.0
const RECRUIT_GAUSS_MAX_SHIFT = 4.0
const RECRUIT_SCARCITY_LOW = 0.5               # Gold/recruit lower bound for scarcity bias (legacy)
const RECRUIT_SCARCITY_HIGH = 1.5              # Gold/recruit upper bound for full scarcity bias (legacy)
const RECRUIT_UNIT_BOOSTS: Dictionary = {      # Scarcity bias boosts (higher = more likely when gold/recruit is high)
	SoldierTypeEnum.Type.PEASANTS: -0.9,
	SoldierTypeEnum.Type.SPEARMEN: -0.4,
	SoldierTypeEnum.Type.ARCHERS: 0.5,
	SoldierTypeEnum.Type.SWORDSMEN: 0.7,
	SoldierTypeEnum.Type.CROSSBOWMEN: 0.9,
	SoldierTypeEnum.Type.HORSEMEN: 0.9,
	SoldierTypeEnum.Type.KNIGHTS: 1.2,
	SoldierTypeEnum.Type.MOUNTED_KNIGHTS: 1.4,
	SoldierTypeEnum.Type.ROYAL_GUARD: 1.7
}
const RECRUIT_SPEND_TARGET_PCT = 0.95           # Target budget spend ratio when selecting T
const RECRUIT_DIVERSITY_REQUIREMENTS: Dictionary = {  # Minimal diversity floor (applies when ideal has the unit)
	SoldierTypeEnum.Type.SWORDSMEN: 1,
	SoldierTypeEnum.Type.HORSEMEN: 1,
	SoldierTypeEnum.Type.CROSSBOWMEN: 1
}
const RECRUIT_DIVERSITY_MIN_T = 24             # Apply diversity floor only when T >= this
const POPULATION_GROWTH_RATE = 0.02            # Base population growth rate (%)
const POPULATION_CONST_GROWTH_RATE = 0.00
const WITHDRAWAL_FREE_HIT_ROUNDS = 2           # Number of free hit rounds enemy gets during withdrawal
const PREBATTLE_VOLLEY_ROUNDS = 1              # Number of prebattle ranged volleys (archers/crossbowmen opening shots)
const MOBILITY_EXTRA_WITHDRAWAL_ROUNDS = 2    # Extra rounds mobility units get to attack withdrawing enemies
const ENEMY_ARMY_MEMORY_ROUNDS = 5            # Rounds to retain enemy army power knowledge for AI players
const AI_ENEMY_REGION_SCORE_BONUS = 5          # Bonus added when targeting enemy-owned regions
const AI_WITHDRAW_MAX_POWER_DIFFERENCE = 0.30	# Normal-mode forced withdrawal ratio in open field
const AI_PURSUIT_POWER_RATIO = 1.5			# Ratio above which AI gets a pursuit bonus for targets
const AI_PURSUIT_SCORE_BONUS = 5.0			# Score bonus for high-ratio pursuit targets
const AI_CASTLE_ATTACK_MIN_RATIO = 1.5		# Minimum ratio required to consider attacking castles
const AI_FIELD_ATTACK_MIN_RATIO = 1.0		# Minimum ratio required to consider attacking non-castles
const AI_MOVE_SPEED_NORMAL = 1.0
const AI_MOVE_SPEED_FAST = 2.0
const AI_MOVE_SPEED_VERY_FAST = 6.0
const DEMO_MODE_ENABLED: bool = false
const DEMO_ALLOWED_SCENARIO_FILES: Array[String] = [
	"mission-1.json",
	"mission-2.json",
	"tutorial.json",
	"Vikings Invasion.json"
]
const DEMO_ALLOWED_CUSTOM_MAP_FILES: Array[String] = [
	"Demo Map.json"
]

enum Difficulty {
	EASY = 0,
	NORMAL = 1,
	HARD = 2
}

const GAME_DIFFICULTY_DEFAULT: int = Difficulty.NORMAL
const AI_HUMAN_TARGET_SCORE_BONUS_BY_DIFFICULTY: Dictionary = {
	Difficulty.EASY: -5.0,
	Difficulty.NORMAL: 0.0,
	Difficulty.HARD: 5.0
}
const AI_CASTLE_ATTACK_MIN_RATIO_BY_DIFFICULTY: Dictionary = {
	Difficulty.EASY: 1.25,
	Difficulty.NORMAL: 1.5,
	Difficulty.HARD: 1.75
}
const AI_FIELD_ATTACK_MIN_RATIO_BY_DIFFICULTY: Dictionary = {
	Difficulty.EASY: 0.8,
	Difficulty.NORMAL: 1.0,
	Difficulty.HARD: 1.2
}
const AI_WITHDRAW_POWER_THRESHOLD_BY_DIFFICULTY: Dictionary = {
	Difficulty.EASY: 0.6,
	Difficulty.NORMAL: 0.8,
	Difficulty.HARD: 0.85
}
const AI_WITHDRAW_FORCED_RATIO_BY_DIFFICULTY: Dictionary = {
	Difficulty.EASY: 0.2,
	Difficulty.NORMAL: 0.3,
	Difficulty.HARD: 0.4
}
const AI_SIEGE_WITHDRAW_BAILOUT_RATIO_BY_DIFFICULTY: Dictionary = {
	Difficulty.EASY: 1.25,
	Difficulty.NORMAL: 1.5,
	Difficulty.HARD: 1.75
}
const AI_INCOME_GROWTH_BONUS_BY_DIFFICULTY: Dictionary = {
	Difficulty.EASY: 0.0,
	Difficulty.NORMAL: 0.10,
	Difficulty.HARD: 0.20
}

enum ArmyMoveTrigger {
	LEFT_CLICK = 0,
	RIGHT_CLICK = 1
}

enum KeyboardAction {
	CONTINUE_CLOSE = 0,
	NEXT_ARMY = 1,
	SWITCH_ARMY_REGION = 2,
	RECRUIT = 3,
	CAMP_REST = 4,
	TRANSFER = 5
}

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

const RECRUIT_PERCENTAGE_OF_POPULATION = 0.06  # % of population becomes available recruits
const RECRUIT_REPLENISH_RATE = 0.004            # % of population replenishes per turn
const RECRUIT_PEA_CAP_SHARE = 0.40   
## Region Level Bonuses
const REGION_RESOURCE_LEVEL_MULTIPLIER = 0.375  # Resource bonus per level: +37.5% per level above 1
const PROMOTION_GROWTH_BONUS_TURNS = 5          # Number of turns promotion growth bonus lasts
const PROMOTION_REPLENISH_BONUS_TURNS = 2       # Number of turns promotion replenish bonus lasts
const PROMOTION_REPLENISH_BONUS_MULTIPLIER = 2.0 # Multiplier applied to base replenish rate during promotion bonus
const REGION_LEVEL_REPLENISH_BONUS_RATE = 0.0025 # Added replenish rate per region level above 1

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
	CastleTypeEnum.Type.NONE: 0.04,         # No castle:
	CastleTypeEnum.Type.OUTPOST: 0.045,      # Outpost: 
	CastleTypeEnum.Type.KEEP: 0.055,         # Keep:
	CastleTypeEnum.Type.CASTLE: 0.055,       # Castle:
	CastleTypeEnum.Type.STRONGHOLD: 0.65    # Stronghold:
}

const CASTLE_UPKEEP_COSTS: Dictionary = {
	CastleTypeEnum.Type.NONE: {
		ResourcesEnum.Type.WOOD: 0,
		ResourcesEnum.Type.STONE: 0
	},
	CastleTypeEnum.Type.OUTPOST: {
		ResourcesEnum.Type.WOOD: 2,
		ResourcesEnum.Type.STONE: 0
	},
	CastleTypeEnum.Type.KEEP: {
		ResourcesEnum.Type.WOOD: 2,
		ResourcesEnum.Type.STONE: 2
	},
	CastleTypeEnum.Type.CASTLE: {
		ResourcesEnum.Type.WOOD: 2,
		ResourcesEnum.Type.STONE: 4
	},
	CastleTypeEnum.Type.STRONGHOLD: {
		ResourcesEnum.Type.WOOD: 2,
		ResourcesEnum.Type.STONE: 6
	}
}

const REGION_UPKEEP_COSTS: Dictionary = {
	RegionLevelEnum.Level.L1: {
		ResourcesEnum.Type.FOOD: 0,
		ResourcesEnum.Type.WOOD: 0,
		ResourcesEnum.Type.STONE: 0
	},
	RegionLevelEnum.Level.L2: {
		ResourcesEnum.Type.FOOD: 0,
		ResourcesEnum.Type.WOOD: 0,
		ResourcesEnum.Type.STONE: 0
	},
	RegionLevelEnum.Level.L3: {
		ResourcesEnum.Type.FOOD: 0,
		ResourcesEnum.Type.WOOD: 1,
		ResourcesEnum.Type.STONE: 0
	},
	RegionLevelEnum.Level.L4: {
		ResourcesEnum.Type.FOOD: 0,
		ResourcesEnum.Type.WOOD: 1,
		ResourcesEnum.Type.STONE: 1
	},
	RegionLevelEnum.Level.L5: {
		ResourcesEnum.Type.FOOD: 1,
		ResourcesEnum.Type.WOOD: 1,
		ResourcesEnum.Type.STONE: 1
	}
}

const REGION_RECRUITMENT_PERCENTAGES = {
	RegionLevelEnum.Level.L1: 0.04,         
	RegionLevelEnum.Level.L2: 0.05,      
	RegionLevelEnum.Level.L3: 0.06,        
	RegionLevelEnum.Level.L4: 0.07,       
	RegionLevelEnum.Level.L5: 0.08    
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

static var _ai_move_speed_multiplier: float = AI_MOVE_SPEED_NORMAL
static var _battle_round_time: float = BATTLE_ROUND_TIME_NORMAL
static var _army_move_trigger: int = ArmyMoveTrigger.RIGHT_CLICK
static var _battle_logs_visible: bool = false
static var _continue_close_keycode: int = KEY_SPACE
static var _next_army_keycode: int = KEY_SHIFT
static var _switch_army_region_keycode: int = KEY_TAB
static var _recruit_keycode: int = KEY_R
static var _camp_rest_keycode: int = KEY_C
static var _transfer_keycode: int = KEY_T

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
const AI_NEUTRAL_CORE_DISTANCE_BONUS_MULTIPLIER = 5.0
const AI_NEUTRAL_CORE_DISTANCE_MAX = 3
const AI_NEUTRAL_CORE_OWNED_NEIGHBOR_BONUS = 3.0
const AI_NEUTRAL_CLUSTER_BONUS_PER_EXTRA_REGION = 2.0
const AI_NEUTRAL_CLUSTER_BONUS_MAX = 16.0
const AI_NEUTRAL_CLUSTER_SCAN_MAX = 9
const AI_NEUTRAL_BORDER_BONUS_PER_OWNED_NEIGHBOR = 4.0
const AI_NEUTRAL_BORDER_BONUS_MAX = 12.0

## Mining System Constants
const ORE_SEARCH_COST = 10                      # Gold cost to perform ore search
const ORE_SEARCH_CHANCES_PER_REGION = 3        # Number of ore search attempts per region
const ORE_DISCOVERY_CHANCE = 0.2               # 20% chance to find ore per search
const ORE_TYPE_IRON_CHANCE = 0.6              # 80% chance for iron, 20% for gold

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
const AI_MIN_RECRUITS_FOR_RAISING_BY_DIFFICULTY: Dictionary = {
	Difficulty.EASY: 40,
	Difficulty.NORMAL: 30,
	Difficulty.HARD: 25
}
const AI_RAISE_RESERVE_GOLD_MIN_BY_DIFFICULTY: Dictionary = {
	Difficulty.EASY: 30,
	Difficulty.NORMAL: 20,
	Difficulty.HARD: 0
}
const AI_RAISE_THRESHOLD_NORM_BY_DIFFICULTY: Dictionary = {
	Difficulty.EASY: 0.50,
	Difficulty.NORMAL: 0.45,
	Difficulty.HARD: 0.40
}
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
const AI_RAISE_FRONTIER = 2.5
const AI_MAIN_EXTENDED_TARGET_RANGE_EASY = 2
const AI_MAIN_EXTENDED_TARGET_RANGE_NORMAL = 3
const AI_MAIN_EXTENDED_TARGET_RANGE_HARD = 4

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
	ResourcesEnum.Type.IRON: 15,
	ResourcesEnum.Type.GOLD: 0
}
const AI_NEED_SCORE_MAX = 10.0                # Resource need score cap per resource

## AI Handicap Bonuses
const AI_RESOURCE_GROWTH_BONUS = 0.0          # Multiplier bonus for non-gold resource income (e.g., +25%)


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
const AI_REGION_PROMOTION_MIN_RESOURCE_GROWTH = 5.0

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
const DEFENDER_ATTACK_MULTIPLIER = 2.0          # 100% attack bonus when defending for defender-trait units

# Wounded system
const WOUNDED_CHANCE = 0.30						# Base chance per casualty to become wounded (0..1)
const CAMP_HEAL_CHANCE = 0.50						# Chance to heal one wounded unit on make_camp() (0..1)
const AI_WITHDRAW_POWER_THRESHOLD = 0.80			# AI withdraw triggers when own power <= 80% of enemy power
const AI_CASTLE_ASSAULT_EXPECTED_MULTIPLIER = 0.70	# Expected assault effectiveness vs castles for pre-eval scoring/withdraw checks
const MOVE_ANIMATION_DURATION = 0.5				# Seconds for army move animation

## Camera Centering Timing Constants
const CAMERA_ARMY_START_DELAY = 0.1			# Seconds to pause after centering on army before movement
const CAMERA_BATTLE_RESULT_DELAY = 0.1			# Seconds to pause after battle results (victory/defeat/withdrawal)
const CAMERA_CONQUEST_DELAY = 0.1				# Seconds to pause after region conquest to show ownership change
const CAMERA_FRIENDLY_MOVE_DELAY = 0.1			# Seconds to pause after friendly army moves

## Siege ladders
const LADDER_EFFECTIVENESS_PER = 5				# Raw effectiveness added per ladder for siege assaults
const LADDERS_PER_SECTION = 4					# Max ladders applied per intact wall section
const SIEGE_RAM_HP = 10						# Hit points per siege ram
const SIEGE_RAM_SIZE = 10						# Target weight size for siege ram when absorbing ranged fire (legacy, not used for focus targeting)
const SIEGE_RAM_FOCUS_RANGED = 25				# Number of ranged attackers that prioritize each active ram before shooting units

## Castle Defense Bonuses
const CASTLE_DEFENSE_BONUSES = {
	CastleTypeEnum.Type.NONE: 0,          # No castle
	CastleTypeEnum.Type.OUTPOST: 60,      # Outpost 
	CastleTypeEnum.Type.KEEP: 70,         # Keep
	CastleTypeEnum.Type.CASTLE: 80,       # Castle 
	CastleTypeEnum.Type.STRONGHOLD: 90    # Stronghold 
}

const CASTLE_DEFENSE_BONUSES_MIN = {
	CastleTypeEnum.Type.NONE: 0,          # No castle - 0% hit avoidance
	CastleTypeEnum.Type.OUTPOST: 30,      # Outpost - 20% hit avoidance  
	CastleTypeEnum.Type.KEEP: 45,         # Keep - 40% hit avoidance
	CastleTypeEnum.Type.CASTLE: 50,       # Castle - 60% hit avoidance
	CastleTypeEnum.Type.STRONGHOLD: 60    # Stronghold - 75% hit avoidance
}

const CASTLE_WALLS_GATES = {
	CastleTypeEnum.Type.OUTPOST: {
		"gates": 1,
		"gate_hp": 4,
		"wall_sections": 2,
		"wall_hp": 2,
		"trebuchet_damage_to_defense": 10,
		"wall_section_assault": 20,
		"destroy_chance": 100
	},      # Outpost 
	CastleTypeEnum.Type.KEEP: {
		"gates": 1,
		"gate_hp": 5,
		"wall_sections": 4,
		"wall_hp": 2,
		"trebuchet_damage_to_defense": 9,
		"wall_section_assault": 20,
		"destroy_chance": 95
	},         # Keep
	CastleTypeEnum.Type.CASTLE: {
		"gates": 2,
		"gate_hp": 6,
		"wall_sections": 6,
		"wall_hp": 3,
		"trebuchet_damage_to_defense": 8,
		"wall_section_assault": 20,
		"destroy_chance": 90
	},      # Castle 
	CastleTypeEnum.Type.STRONGHOLD: {
		"gates": 3,
		"gate_hp": 7,
		"wall_sections": 8,
		"wall_hp": 3,
		"trebuchet_damage_to_defense": 7,
		"wall_section_assault": 20,
		"destroy_chance": 85
	}, 
}

const GATE_BREACH_SUCCESS = {
	10: 0.50,
	15: 0.45,
	20: 0.40,
	25: 0.35,
	30: 0.30,
	35: 0.275,
	40: 0.25,
	45: 0.225,
	50: 0.20,
	60: 0.15
};

## Unit Tier System
# Defines which units are available at each region level
const UNIT_TIERS = {
	SoldierTypeEnum.Type.PEASANTS: 1,      # Tier 1 - Available at L1+
	SoldierTypeEnum.Type.SPEARMEN: 2,      # Tier 1 - Available at L1+
	SoldierTypeEnum.Type.SWORDSMEN: 3,     # Tier 2 - Available at L2+
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
		"defense": 8,    # 10% chance to deflect hits
		"cost": 1,        # Free recruitment (food cost 0.1 handled separately)
		"gold_cost": 1,
		"food_cost": 0.1,
		"wood_cost": 0,
		"iron_cost": 0,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_8],  # no_armor,
		"power": 2
	},
	SoldierTypeEnum.Type.SPEARMEN: {
		"attack": 8,     # 10	% hit chance per unit
		"defense": 25,    # 25% chance to deflect hits
		"cost": 2,        # Recruitment cost
		"gold_cost": 2,
		"food_cost": 0.1,
		"wood_cost": 0,
		"iron_cost": 0,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_1, UnitTraitEnum.Type.UNIT_TRAIT_8, UnitTraitEnum.Type.UNIT_TRAIT_10],  # long_spears, light_armor,
		"power": 3
	},
	SoldierTypeEnum.Type.SWORDSMEN: {
		"attack": 14,     # 30% hit chance per unit
		"defense": 35,    # 40% chance to deflect hits
		"cost": 3,        # Recruitment cost
		"gold_cost": 3,
		"food_cost": 0.1,
		"wood_cost": 0,
		"iron_cost": 0,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_8],  # medium_armor,
		"power": 4
	},
	SoldierTypeEnum.Type.ARCHERS: {
		"attack": 20,     # 25% hit chance per unit
		"defense": 15,    # 15% chance to deflect hits
		"cost": 3,        # Recruitment cost
		"gold_cost": 3,
		"food_cost": 0.1,
		"wood_cost": 1,
		"iron_cost": 0,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_2, UnitTraitEnum.Type.UNIT_TRAIT_9],  # ranged, light_armor,
		"power": 4
	},
	SoldierTypeEnum.Type.CROSSBOWMEN: {
		"attack": 16,     # 20% hit chance per unit
		"defense": 20,    # 15% chance to deflect hits
		"cost": 3,        # Recruitment cost
		"gold_cost": 3,
		"food_cost": 0.1,
		"wood_cost": 1,
		"iron_cost": 0,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_2, UnitTraitEnum.Type.UNIT_TRAIT_7, UnitTraitEnum.Type.UNIT_TRAIT_9],  # ranged, armor_piercing, light_armor,
		"power": 4
	},
	SoldierTypeEnum.Type.HORSEMEN: {
		"attack": 15,     # 30% hit chance per unit
		"defense": 25,    # 30% chance to deflect hits
		"cost": 4,        # Recruitment cost
		"gold_cost": 4,
		"food_cost": 0.2,
		"wood_cost": 0,
		"iron_cost": 0,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_3, UnitTraitEnum.Type.UNIT_TRAIT_4, UnitTraitEnum.Type.UNIT_TRAIT_5],  # mobility, flanker, charge, medium_armor,
		"power": 5
	},
	SoldierTypeEnum.Type.KNIGHTS: {
		"attack": 35,     # 60% hit chance per unit
		"defense": 70,    # 60% chance to deflect hits
		"cost": 6,       # Recruitment cost
		"gold_cost": 6,
		"food_cost": 0.1,
		"wood_cost": 0,
		"iron_cost": 1,
		"traits": [],  # heavy_armor,
		"power": 10
	},
	SoldierTypeEnum.Type.MOUNTED_KNIGHTS: {
		"attack": 40,     # 65% hit chance per unit
		"defense": 70,    # 60% chance to deflect hits
		"cost": 8,       # Recruitment cost
		"gold_cost": 8,
		"food_cost": 0.2,
		"wood_cost": 0,
		"iron_cost": 1,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_4, UnitTraitEnum.Type.UNIT_TRAIT_5],  # flanker, charge, heavy_armor,
		"power": 12
	},
	SoldierTypeEnum.Type.ROYAL_GUARD: {
		"attack": 40,     # 80% hit chance per unit
		"defense": 85,    # 80% chance to deflect hits
		"cost": 10,       # Recruitment cost
		"gold_cost": 12,
		"food_cost": 0.1,
		"wood_cost": 0,
		"iron_cost": 2,
		"traits": [UnitTraitEnum.Type.UNIT_TRAIT_6, UnitTraitEnum.Type.UNIT_TRAIT_7],  # multi_attack, heavy_armor,
		"power": 30
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
const BATTLE_ATTACKER_TERRAIN_VIGOR_PENALTY_ENABLED: bool = true
const BATTLE_ATTACKER_TERRAIN_VIGOR_PENALTIES: Dictionary = {
	RegionTypeEnum.Type.HILLS: 20,
	RegionTypeEnum.Type.FOREST_HILLS: 20
}
const BATTLE_RANGED_TERRAIN_PENALTY_ENABLED: bool = true
const BATTLE_RANGED_TERRAIN_PENALTY_PERCENT: int = 30
const BATTLE_RANGED_TERRAIN_TYPES: Array[RegionTypeEnum.Type] = [
	RegionTypeEnum.Type.FOREST,
	RegionTypeEnum.Type.FOREST_HILLS
]
const BATTLE_RANGED_TERRAIN_UNITS: Array[SoldierTypeEnum.Type] = [
	SoldierTypeEnum.Type.ARCHERS,
	SoldierTypeEnum.Type.CROSSBOWMEN
]


## Resource Generation by Region Type
# Format: resource_type -> {min, max} range for randi_range()
const REGION_RESOURCES = {
	RegionTypeEnum.Type.GRASSLAND: {
		ResourcesEnum.Type.FOOD: {"min": 1, "max": 3}
	},
	RegionTypeEnum.Type.FOREST: {
		ResourcesEnum.Type.WOOD: {"min": 1, "max": 3}
	},
	RegionTypeEnum.Type.HILLS: {
		ResourcesEnum.Type.STONE: {"min": 1, "max": 3},
		ResourcesEnum.Type.IRON: {"min": 1, "max": 3},
		ResourcesEnum.Type.GOLD: {"min": 4, "max": 8}
	},
	RegionTypeEnum.Type.FOREST_HILLS: {
		ResourcesEnum.Type.WOOD: {"min": 1, "max": 2},
		ResourcesEnum.Type.STONE: {"min": 0, "max": 2},
		ResourcesEnum.Type.IRON: {"min": 1, "max": 2},
		ResourcesEnum.Type.GOLD: {"min": 2, "max": 6}
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
		"spearmen": 35,
		"archers": 25,
		"swordsmen": 0,
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
		"archers": 30,
		"swordsmen": 0,
		"crossbowmen": 0,
		"horsemen": 0,
		"knights": 0,
		"mounted_knights": 0,
		"royal_guard": 0
	},
	"Keep": {
		"peasants": 35,
		"spearmen": 25,
		"archers": 20,
		"swordsmen": 10,
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
	CastleTypeEnum.Type.KEEP: 5,
	CastleTypeEnum.Type.CASTLE: 6,
	CastleTypeEnum.Type.STRONGHOLD: 6
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
const STARTING_RESOURCES_EASY = {
	ResourcesEnum.Type.GOLD: 130,
	ResourcesEnum.Type.FOOD: 150,
	ResourcesEnum.Type.WOOD: 30,
	ResourcesEnum.Type.IRON: 10,
	ResourcesEnum.Type.STONE: 20
}

const STARTING_RESOURCES_NORMAL = {
	ResourcesEnum.Type.GOLD: 100,
	ResourcesEnum.Type.FOOD: 70,
	ResourcesEnum.Type.WOOD: 20,
	ResourcesEnum.Type.IRON: 0,
	ResourcesEnum.Type.STONE: 10
}

const STARTING_RESOURCES_HARD = {
	ResourcesEnum.Type.GOLD: 50,
	ResourcesEnum.Type.FOOD: 50,
	ResourcesEnum.Type.WOOD: 10,
	ResourcesEnum.Type.IRON: 0,
	ResourcesEnum.Type.STONE: 0
}

const STARTING_RESOURCES = STARTING_RESOURCES_NORMAL

const STARTING_ARMY_COMPOSITION_HUMAN_EASY = {
	SoldierTypeEnum.Type.PEASANTS: 30,
	SoldierTypeEnum.Type.SPEARMEN: 15,
	SoldierTypeEnum.Type.SWORDSMEN: 10,
	SoldierTypeEnum.Type.ARCHERS: 10,
	SoldierTypeEnum.Type.CROSSBOWMEN: 0,
	SoldierTypeEnum.Type.HORSEMEN: 0,
	SoldierTypeEnum.Type.KNIGHTS: 2,
	SoldierTypeEnum.Type.MOUNTED_KNIGHTS: 0,
	SoldierTypeEnum.Type.ROYAL_GUARD: 0
}

const STARTING_ARMY_COMPOSITION_HUMAN_NORMAL = {
	SoldierTypeEnum.Type.PEASANTS: 20,
	SoldierTypeEnum.Type.SPEARMEN: 10,
	SoldierTypeEnum.Type.SWORDSMEN: 5,
	SoldierTypeEnum.Type.ARCHERS: 5,
	SoldierTypeEnum.Type.CROSSBOWMEN: 0,
	SoldierTypeEnum.Type.HORSEMEN: 0,
	SoldierTypeEnum.Type.KNIGHTS: 1,
	SoldierTypeEnum.Type.MOUNTED_KNIGHTS: 0,
	SoldierTypeEnum.Type.ROYAL_GUARD: 0
}

const STARTING_ARMY_COMPOSITION_HUMAN_HARD = {
	SoldierTypeEnum.Type.PEASANTS: 15,
	SoldierTypeEnum.Type.SPEARMEN: 5,
	SoldierTypeEnum.Type.SWORDSMEN: 0,
	SoldierTypeEnum.Type.ARCHERS: 5,
	SoldierTypeEnum.Type.CROSSBOWMEN: 0,
	SoldierTypeEnum.Type.HORSEMEN: 0,
	SoldierTypeEnum.Type.KNIGHTS: 1,
	SoldierTypeEnum.Type.MOUNTED_KNIGHTS: 0,
	SoldierTypeEnum.Type.ROYAL_GUARD: 0
}

const STARTING_ARMY_COMPOSITION_HUMAN = STARTING_ARMY_COMPOSITION_HUMAN_NORMAL

const STARTING_ARMY_COMPOSITION_AI = {
	SoldierTypeEnum.Type.PEASANTS: 20,
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
const AI_TRADE_THRESHOLD_STONE = 100
const AI_TRADE_THRESHOLD_IRON = 50

## Region Garrison Generation by Region Level
const GARRISON_BY_LEVEL = {
	RegionLevelEnum.Level.L1: {"min": 1, "max": 15},
	RegionLevelEnum.Level.L2: {"min": 10, "max": 20},
	RegionLevelEnum.Level.L3: {"min": 15, "max": 30},
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
		ResourcesEnum.Type.GOLD: 0,
		ResourcesEnum.Type.FOOD: 10
	},
	RegionLevelEnum.Level.L3: {  # Cost to promote from L2 to L3
		ResourcesEnum.Type.GOLD: 5,
		ResourcesEnum.Type.FOOD: 15,
		ResourcesEnum.Type.WOOD: 0,
	},
	RegionLevelEnum.Level.L4: {  # Cost to promote from L3 to L4
		ResourcesEnum.Type.GOLD: 10,
		ResourcesEnum.Type.FOOD: 20,
		ResourcesEnum.Type.WOOD: 0,
		ResourcesEnum.Type.STONE: 0,
	},
	RegionLevelEnum.Level.L5: {  # Cost to promote from L4 to L5
		ResourcesEnum.Type.GOLD: 15,
		ResourcesEnum.Type.FOOD: 25,
		ResourcesEnum.Type.WOOD: 0,
		ResourcesEnum.Type.STONE: 0,
		ResourcesEnum.Type.IRON: 0
	}
}

## Castle Building Costs and Build Times
# Costs and construction time for each castle type
const CASTLE_BUILDING_COSTS = {
	CastleTypeEnum.Type.OUTPOST: {
		"cost": {
			ResourcesEnum.Type.GOLD: 30,
			ResourcesEnum.Type.WOOD: 25
		},
		"build_time": 2  # 2 turns to complete
	},
	CastleTypeEnum.Type.KEEP: {
		"cost": {
			ResourcesEnum.Type.GOLD: 50,
			ResourcesEnum.Type.WOOD: 20,
			ResourcesEnum.Type.STONE: 20
		},
		"build_time": 2  # 3 turns to complete
	},
	CastleTypeEnum.Type.CASTLE: {
		"cost": {
			ResourcesEnum.Type.GOLD: 75,
			ResourcesEnum.Type.WOOD: 25,
			ResourcesEnum.Type.STONE: 40,
			ResourcesEnum.Type.IRON: 10
		},
		"build_time": 2  # 4 turns to complete
	},
	CastleTypeEnum.Type.STRONGHOLD: {
		"cost": {
			ResourcesEnum.Type.GOLD: 100,
			ResourcesEnum.Type.WOOD: 20,
			ResourcesEnum.Type.STONE: 60,
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

static func get_battle_attacker_terrain_vigor_penalty(region_type: RegionTypeEnum.Type) -> int:
	if not BATTLE_ATTACKER_TERRAIN_VIGOR_PENALTY_ENABLED:
		return 0
	return int(BATTLE_ATTACKER_TERRAIN_VIGOR_PENALTIES.get(region_type, 0))

static func get_battle_attacker_effective_vigor(base_vigor: int, region_type: RegionTypeEnum.Type) -> int:
	var terrain_penalty: int = get_battle_attacker_terrain_vigor_penalty(region_type)
	return clampi(base_vigor - terrain_penalty, 0, 100)

static func get_battle_ranged_terrain_penalty_for_region(region_type: RegionTypeEnum.Type) -> int:
	if not BATTLE_RANGED_TERRAIN_PENALTY_ENABLED:
		return 0
	if not BATTLE_RANGED_TERRAIN_TYPES.has(region_type):
		return 0
	return BATTLE_RANGED_TERRAIN_PENALTY_PERCENT

static func get_battle_ranged_terrain_penalty_percent(unit_type: SoldierTypeEnum.Type, region_type: RegionTypeEnum.Type) -> int:
	if not BATTLE_RANGED_TERRAIN_UNITS.has(unit_type):
		return 0
	return get_battle_ranged_terrain_penalty_for_region(region_type)

static func set_ai_move_speed_multiplier(multiplier: float) -> void:
	_ai_move_speed_multiplier = max(AI_MOVE_SPEED_NORMAL, multiplier)

static func get_ai_move_speed_multiplier() -> float:
	return _ai_move_speed_multiplier

static func set_battle_round_time(seconds: float) -> void:
	_battle_round_time = clampf(seconds, BATTLE_ROUND_TIME_VERY_FAST, BATTLE_ROUND_TIME_NORMAL)

static func get_battle_round_time() -> float:
	return _battle_round_time

static func set_battle_logs_visible(is_visible: bool) -> void:
	_battle_logs_visible = is_visible

static func get_battle_logs_visible() -> bool:
	return _battle_logs_visible

static func get_prebattle_volley_rounds() -> int:
	return maxi(0, PREBATTLE_VOLLEY_ROUNDS)

static func set_army_move_trigger(trigger: int) -> void:
	if trigger == ArmyMoveTrigger.RIGHT_CLICK:
		_army_move_trigger = ArmyMoveTrigger.RIGHT_CLICK
		return
	_army_move_trigger = ArmyMoveTrigger.LEFT_CLICK

static func get_army_move_trigger() -> int:
	return _army_move_trigger

static func get_default_keyboard_keycode(action: int) -> int:
	match action:
		KeyboardAction.CONTINUE_CLOSE:
			return KEY_SPACE
		KeyboardAction.NEXT_ARMY:
			return KEY_SHIFT
		KeyboardAction.SWITCH_ARMY_REGION:
			return KEY_TAB
		KeyboardAction.RECRUIT:
			return KEY_R
		KeyboardAction.CAMP_REST:
			return KEY_C
		KeyboardAction.TRANSFER:
			return KEY_T
	return KEY_NONE

static func get_keyboard_keycode(action: int) -> int:
	match action:
		KeyboardAction.CONTINUE_CLOSE:
			return _continue_close_keycode
		KeyboardAction.NEXT_ARMY:
			return _next_army_keycode
		KeyboardAction.SWITCH_ARMY_REGION:
			return _switch_army_region_keycode
		KeyboardAction.RECRUIT:
			return _recruit_keycode
		KeyboardAction.CAMP_REST:
			return _camp_rest_keycode
		KeyboardAction.TRANSFER:
			return _transfer_keycode
	return KEY_NONE

static func set_keyboard_keycode(action: int, keycode: int) -> void:
	var normalized_keycode: int = maxi(KEY_NONE, keycode)
	match action:
		KeyboardAction.CONTINUE_CLOSE:
			_continue_close_keycode = normalized_keycode
		KeyboardAction.NEXT_ARMY:
			_next_army_keycode = normalized_keycode
		KeyboardAction.SWITCH_ARMY_REGION:
			_switch_army_region_keycode = normalized_keycode
		KeyboardAction.RECRUIT:
			_recruit_keycode = normalized_keycode
		KeyboardAction.CAMP_REST:
			_camp_rest_keycode = normalized_keycode
		KeyboardAction.TRANSFER:
			_transfer_keycode = normalized_keycode

static func is_keyboard_action_pressed(event: InputEvent, action: int) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	var configured_keycode: int = get_keyboard_keycode(action)
	if configured_keycode == KEY_NONE:
		return false
	return key_event.keycode == configured_keycode

static func is_continue_close_key_pressed(event: InputEvent) -> bool:
	return is_keyboard_action_pressed(event, KeyboardAction.CONTINUE_CLOSE)

static func is_next_army_key_pressed(event: InputEvent) -> bool:
	return is_keyboard_action_pressed(event, KeyboardAction.NEXT_ARMY)

static func is_switch_army_region_key_pressed(event: InputEvent) -> bool:
	return is_keyboard_action_pressed(event, KeyboardAction.SWITCH_ARMY_REGION)

static func is_recruit_key_pressed(event: InputEvent) -> bool:
	return is_keyboard_action_pressed(event, KeyboardAction.RECRUIT)

static func is_camp_rest_key_pressed(event: InputEvent) -> bool:
	return is_keyboard_action_pressed(event, KeyboardAction.CAMP_REST)

static func is_transfer_key_pressed(event: InputEvent) -> bool:
	return is_keyboard_action_pressed(event, KeyboardAction.TRANSFER)

static func get_move_animation_duration(is_ai_player: bool) -> float:
	if is_ai_player:
		return MOVE_ANIMATION_DURATION / max(_ai_move_speed_multiplier, AI_MOVE_SPEED_NORMAL)
	return MOVE_ANIMATION_DURATION

static func get_resource_range(region_type: RegionTypeEnum.Type, resource_type: ResourcesEnum.Type) -> Dictionary:
	"""Get min/max range for resource generation in region type"""
	var region_resources = REGION_RESOURCES.get(region_type, {})
	return region_resources.get(resource_type, {"min": 0, "max": 0})

static func generate_resource_amount(region_type: RegionTypeEnum.Type, resource_type: ResourcesEnum.Type) -> int:
	"""Generate random resource amount for region/resource combination"""
	if region_type == RegionTypeEnum.Type.GRASSLAND and resource_type == ResourcesEnum.Type.FOOD:
		return _roll_weighted_3(45, 35, 1, 2, 3)
	if region_type == RegionTypeEnum.Type.FOREST and resource_type == ResourcesEnum.Type.WOOD:
		return _roll_weighted_3(45, 35, 1, 2, 3)
	if region_type == RegionTypeEnum.Type.HILLS and resource_type == ResourcesEnum.Type.STONE:
		return _roll_weighted_3(50, 35, 1, 2, 3)
	if region_type == RegionTypeEnum.Type.FOREST_HILLS and resource_type == ResourcesEnum.Type.WOOD:
		return _roll_weighted_2(70, 1, 2)
	if region_type == RegionTypeEnum.Type.FOREST_HILLS and resource_type == ResourcesEnum.Type.STONE:
		return _roll_weighted_3(45, 35, 0, 1, 2)

	var range_data = get_resource_range(region_type, resource_type)
	if range_data.min == 0 and range_data.max == 0:
		return 0
	return randi_range(range_data.min, range_data.max)

static func _roll_weighted_2(first_weight: int, first_value: int, second_value: int) -> int:
	var roll: int = randi_range(1, 100)
	if roll <= first_weight:
		return first_value
	return second_value

static func _roll_weighted_3(first_weight: int, second_weight: int, first_value: int, second_value: int, third_value: int) -> int:
	var roll: int = randi_range(1, 100)
	if roll <= first_weight:
		return first_value
	if roll <= first_weight + second_weight:
		return second_value
	return third_value

static func get_starting_resource_amount(resource_type: ResourcesEnum.Type) -> int:
	"""Get starting amount for a resource type"""
	return STARTING_RESOURCES.get(resource_type, 0)

static func get_starting_resource_amount_for_difficulty(resource_type: ResourcesEnum.Type, difficulty: int) -> int:
	var normalized: int = normalize_game_difficulty(difficulty)
	if normalized == Difficulty.EASY:
		return int(STARTING_RESOURCES_EASY.get(resource_type, 0))
	if normalized == Difficulty.HARD:
		return int(STARTING_RESOURCES_HARD.get(resource_type, 0))
	return int(STARTING_RESOURCES_NORMAL.get(resource_type, 0))

static func generate_garrison_size(region_level: RegionLevelEnum.Level) -> int:
	"""Generate random garrison size based on region level"""
	var range_data = GARRISON_BY_LEVEL.get(region_level, {"min": 0, "max": 0})
	return randi_range(range_data.min, range_data.max) + 2

static func generate_population_size(region_level: RegionLevelEnum.Level) -> int:
	"""Generate random population size based on region level"""
	var range_data = POPULATION_BY_LEVEL.get(region_level, {"min": 200, "max": 400})
	return randi_range(range_data.min, range_data.max)

static func calculate_max_recruits(population: int, region_level) -> int:
	"""Calculate maximum recruits available based on population and castle type"""
	var recruitment_percentage = get_region_recruitment_percentage(region_level)
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

static func get_castle_upkeep_cost(castle_type: CastleTypeEnum.Type) -> Dictionary:
	"""Get per-turn upkeep for a castle type."""
	var upkeep_data: Dictionary = CASTLE_UPKEEP_COSTS.get(castle_type, {})
	return {
		ResourcesEnum.Type.WOOD: int(upkeep_data.get(ResourcesEnum.Type.WOOD, 0)),
		ResourcesEnum.Type.STONE: int(upkeep_data.get(ResourcesEnum.Type.STONE, 0))
	}

static func get_region_upkeep_cost(region_level: RegionLevelEnum.Level) -> Dictionary:
	"""Get per-turn upkeep for a region level."""
	var upkeep_data: Dictionary = REGION_UPKEEP_COSTS.get(region_level, {})
	return {
		ResourcesEnum.Type.FOOD: int(upkeep_data.get(ResourcesEnum.Type.FOOD, 0)),
		ResourcesEnum.Type.WOOD: int(upkeep_data.get(ResourcesEnum.Type.WOOD, 0)),
		ResourcesEnum.Type.STONE: int(upkeep_data.get(ResourcesEnum.Type.STONE, 0))
	}

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

static func _copy_starting_composition(source: Dictionary) -> Dictionary:
	var comp: Dictionary = {}
	for key in source.keys():
		comp[key] = int(source[key])
	return comp

static func normalize_game_difficulty(difficulty: int) -> int:
	if difficulty < Difficulty.EASY or difficulty > Difficulty.HARD:
		return GAME_DIFFICULTY_DEFAULT
	return difficulty

static func game_difficulty_from_string(difficulty_name: String) -> int:
	var lowered: String = difficulty_name.to_lower()
	if lowered == "easy":
		return Difficulty.EASY
	if lowered == "hard":
		return Difficulty.HARD
	return Difficulty.NORMAL

static func game_difficulty_to_string(difficulty: int) -> String:
	var normalized: int = normalize_game_difficulty(difficulty)
	if normalized == Difficulty.EASY:
		return "easy"
	if normalized == Difficulty.HARD:
		return "hard"
	return "normal"

static func get_ai_human_target_score_bonus(difficulty: int) -> float:
	var normalized: int = normalize_game_difficulty(difficulty)
	return float(AI_HUMAN_TARGET_SCORE_BONUS_BY_DIFFICULTY.get(normalized, 0.0))

static func get_ai_income_growth_bonus(difficulty: int) -> float:
	var normalized: int = normalize_game_difficulty(difficulty)
	return float(AI_INCOME_GROWTH_BONUS_BY_DIFFICULTY.get(normalized, 0.0))

static func get_ai_min_recruits_for_raising(difficulty: int, severe_castle_threat: bool = false) -> int:
	if severe_castle_threat:
		return AI_MIN_RECRUITS_FOR_RAISING
	var normalized: int = normalize_game_difficulty(difficulty)
	return int(AI_MIN_RECRUITS_FOR_RAISING_BY_DIFFICULTY.get(normalized, AI_MIN_RECRUITS_FOR_RAISING))

static func get_ai_raise_reserve_gold_min(difficulty: int, severe_castle_threat: bool = false) -> int:
	if severe_castle_threat:
		return AI_RESERVE_GOLD_MIN
	var normalized: int = normalize_game_difficulty(difficulty)
	return int(AI_RAISE_RESERVE_GOLD_MIN_BY_DIFFICULTY.get(normalized, AI_RESERVE_GOLD_MIN))

static func get_ai_raise_threshold_norm(difficulty: int, severe_castle_threat: bool = false) -> float:
	if severe_castle_threat:
		return AI_RAISE_THRESHOLD_NORM
	var normalized: int = normalize_game_difficulty(difficulty)
	return float(AI_RAISE_THRESHOLD_NORM_BY_DIFFICULTY.get(normalized, AI_RAISE_THRESHOLD_NORM))

static func _resolve_ai_combat_difficulty(difficulty: int, ai_vs_human: bool) -> int:
	if not ai_vs_human:
		return Difficulty.NORMAL
	return normalize_game_difficulty(difficulty)

static func get_ai_castle_attack_min_ratio(difficulty: int, ai_vs_human: bool) -> float:
	var resolved: int = _resolve_ai_combat_difficulty(difficulty, ai_vs_human)
	return float(AI_CASTLE_ATTACK_MIN_RATIO_BY_DIFFICULTY.get(resolved, AI_CASTLE_ATTACK_MIN_RATIO))

static func get_ai_field_attack_min_ratio(difficulty: int, ai_vs_human: bool) -> float:
	var resolved: int = _resolve_ai_combat_difficulty(difficulty, ai_vs_human)
	return float(AI_FIELD_ATTACK_MIN_RATIO_BY_DIFFICULTY.get(resolved, AI_FIELD_ATTACK_MIN_RATIO))

static func get_ai_withdraw_power_threshold(difficulty: int, ai_vs_human: bool) -> float:
	var resolved: int = _resolve_ai_combat_difficulty(difficulty, ai_vs_human)
	return float(AI_WITHDRAW_POWER_THRESHOLD_BY_DIFFICULTY.get(resolved, AI_WITHDRAW_POWER_THRESHOLD))

static func get_ai_withdraw_forced_ratio(difficulty: int, ai_vs_human: bool) -> float:
	var resolved: int = _resolve_ai_combat_difficulty(difficulty, ai_vs_human)
	return float(AI_WITHDRAW_FORCED_RATIO_BY_DIFFICULTY.get(resolved, AI_WITHDRAW_MAX_POWER_DIFFERENCE))

static func get_ai_siege_withdraw_bailout_ratio(difficulty: int, ai_vs_human: bool) -> float:
	var resolved: int = _resolve_ai_combat_difficulty(difficulty, ai_vs_human)
	return float(AI_SIEGE_WITHDRAW_BAILOUT_RATIO_BY_DIFFICULTY.get(resolved, 1.5))

static func get_ai_withdrawal_rules(difficulty: int, ai_vs_human: bool) -> Dictionary:
	return {
		"withdraw_power_threshold": get_ai_withdraw_power_threshold(difficulty, ai_vs_human),
		"withdraw_forced_threshold": get_ai_withdraw_forced_ratio(difficulty, ai_vs_human),
		"siege_bailout_ratio": get_ai_siege_withdraw_bailout_ratio(difficulty, ai_vs_human)
	}

static func get_starting_army_composition_human_for_difficulty(difficulty: int) -> Dictionary:
	var normalized: int = normalize_game_difficulty(difficulty)
	if normalized == Difficulty.EASY:
		return _copy_starting_composition(STARTING_ARMY_COMPOSITION_HUMAN_EASY)
	if normalized == Difficulty.HARD:
		return _copy_starting_composition(STARTING_ARMY_COMPOSITION_HUMAN_HARD)
	return _copy_starting_composition(STARTING_ARMY_COMPOSITION_HUMAN_NORMAL)

static func get_starting_army_composition_human() -> Dictionary:
	return get_starting_army_composition_human_for_difficulty(GAME_DIFFICULTY_DEFAULT)

static func get_starting_army_composition_ai() -> Dictionary:
	return _copy_starting_composition(STARTING_ARMY_COMPOSITION_AI)

static func get_starting_army_composition_for_player_type_with_difficulty(player_type: PlayerTypeEnum.Type, difficulty: int) -> Dictionary:
	if player_type == PlayerTypeEnum.Type.COMPUTER:
		return get_starting_army_composition_ai()
	return get_starting_army_composition_human_for_difficulty(difficulty)

static func get_starting_army_composition_for_player_type(player_type: PlayerTypeEnum.Type) -> Dictionary:
	return get_starting_army_composition_for_player_type_with_difficulty(player_type, GAME_DIFFICULTY_DEFAULT)

static func get_starting_army_composition() -> Dictionary:
	return get_starting_army_composition_human()

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

static func calculate_siege_points_for_composition(composition: ArmyComposition) -> int:
	"""Siege points come only from units with the siege laborer trait."""
	if composition == null:
		return 0
	var total := 0
	for unit_type in SoldierTypeEnum.get_all_types():
		if unit_has_trait(unit_type, UnitTraitEnum.Type.UNIT_TRAIT_8):
			total += composition.get_soldier_count(unit_type)
	return int(total / 10)

static func calculate_non_ranged_count(composition: ArmyComposition) -> int:
	if composition == null:
		return 0
	var total := 0
	for unit_type in SoldierTypeEnum.get_all_types():
		if not unit_has_trait(unit_type, UnitTraitEnum.Type.UNIT_TRAIT_2):
			total += composition.get_soldier_count(unit_type)
	return total

static func get_castle_defense_bonus(castle_type: CastleTypeEnum.Type) -> int:
	"""Get the defensive hit avoidance percentage for a castle type"""
	return CASTLE_DEFENSE_BONUSES.get(castle_type, 0)

static func get_castle_recruitment_percentage(castle_type: CastleTypeEnum.Type) -> float:
	"""Get the recruitment percentage for a castle type"""
	return CASTLE_RECRUITMENT_PERCENTAGES.get(castle_type, 0.02)

static func get_region_recruitment_percentage(region_level) -> float:
	"""Get the recruitment percentage for a region level"""
	return REGION_RECRUITMENT_PERCENTAGES.get(region_level)

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
