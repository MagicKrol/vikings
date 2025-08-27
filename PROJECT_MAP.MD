# Vikings Strategy Game - Project Map

## Overview
Turn-based strategy game built in Godot 4.3 featuring procedural map generation, resource management, tactical combat, and territory conquest. Supports up to 6 human players with sequential turn-based gameplay. Refactored architecture with proper separation of concerns and single responsibility principle.

## Game Node Structure

### main_menu.tscn - Main Menu Scene
**Primary Scene**: Game entry point with menu navigation and viking-themed styling

```
MainMenu (Control) [main_menu.gd]
├── Background (TextureRect) - Full-screen main_menu.png background
└── MenuContainer (VBoxContainer) - Centered menu layout with 50px spacing
    ├── ContinueButton (Button) - Load existing game (opens main.tscn)
    ├── Spacer1 (Control) - 50px vertical spacing
    ├── NewGameButton (Button) - Start new game (opens main.tscn)
    ├── Spacer2 (Control) - 50px vertical spacing  
    ├── LoadGameButton (Button) - Load saved game (placeholder)
    ├── Spacer3 (Control) - 50px vertical spacing
    ├── OptionsButton (Button) - Game settings (placeholder)
    ├── Spacer4 (Control) - 50px vertical spacing
    └── ExitButton (Button) - Quit application
```

**Theme**: main_menu_theme.tres with viking.ttf font (50px), colors #eee9db (normal) / #1d1706 (hover)

### main.tscn - Game Node Hierarchy
**Primary Scene**: Vikings Strategy Game with organized node architecture

```
Main (Node2D) [place_armies.gd]
├── Map (Node2D) [map_generator.gd]
│   ├── Regions/ (static container)
│   │   ├── RegionName (Region) [region.gd] - Dynamically created regions
│   │   │   ├── Polygon (Polygon2D) - Region boundaries
│   │   │   ├── Borders/ (static container) - Region-specific borders
│   │   │   │   └── Border Line2D objects - Dynamic ownership borders
│   │   │   ├── Castle (Sprite2D) - Castle visual (if present)
│   │   │   └── Army nodes (Army) [Army.gd] - Armies in region
│   │   └── ... (multiple regions)
│   ├── Ocean/ (static container)
│   │   └── Ocean Polygon2D objects - Dynamic ocean regions
│   └── Frame/ (static container)
│       └── Ocean frame Polygon2D objects - Dynamic map frame
│
├── Background (Sprite2D) - World map background
├── Camera2D [camera_controller.gd] - Map navigation
├── ClickManager (Node) [click_manager.gd] - Input handling
├── GameManager (Node) [game_manager.gd] - Game coordination  
├── SoundManager (Node) [sound_manager.gd] - Audio system
├── PlayerManager (Node) [PlayerManagerNode.gd] - Player and resource management
│
├── Players (Node2D) - Player organization container 
│   ├── Player1 (Node2D) - Player 1 metadata (future: stats, UI elements)
│   ├── Player2 (Node2D) - Player 2 metadata (future: stats, UI elements) 
│   ├── Player3 (Node2D) - Player 3 metadata (future: stats, UI elements)
│   ├── Player4 (Node2D) - Player 4 metadata (future: stats, UI elements)
│   ├── Player5 (Node2D) - Player 5 metadata (future: stats, UI elements)
│   └── Player6 (Node2D) - Player 6 metadata (future: stats, UI elements)
│
└── UI (CanvasLayer) - Complete interface system
    ├── UIManager (Control) [ui_manager.gd] - Modal coordination
    ├── ArmyModal (Control) [ui_modal.gd] - Army information display
    │   ├── OuterFrame (ColorRect) - Modal background styling
    │   ├── ContentContainer (VBoxContainer) - Army data layout
    │   │   ├── ArmyHeader (Label) - "ARMY" title with header theme
    │   │   ├── MovementLabel (Label) - Movement points display
    │   │   ├── MoraleLabel (Label) - Morale percentage
    │   │   └── CompositionContainer (VBoxContainer) - Unit composition
    │   └── CloseButton (Button) - Modal closure
    ├── RegionModal (Control) [region_modal.gd] - Region details
    │   ├── OuterFrame (ColorRect) - Modal background styling
    │   ├── HeaderLabel (Label) - Region name with header theme
    │   ├── TypeLabel (Label) - Region type (grassland, hills, etc.)
    │   ├── LevelLabel (Label) - Administrative level
    │   ├── ResourcesLabel (Label) - Resource composition
    │   └── CloseButton (Button) - Modal closure
    ├── SelectModal (Control) [select_modal.gd] - General selection
    │   ├── OuterFrame (ColorRect) - Modal background styling
    │   └── ButtonContainer (VBoxContainer) - Dynamic button layout
    ├── ArmySelectModal (Control) [army_select_modal.gd] - Army actions
    │   ├── OuterFrame (ColorRect) - Modal background styling
    │   └── ButtonContainer (VBoxContainer) - Army action buttons
    ├── InfoModal (Control) [info_modal.gd] - Army and region details
    │   ├── OuterFrame (ColorRect) - Modal background styling
    │   ├── ContentContainer (VBoxContainer) - Army/region information layout (shows Efficiency instead of Morale for armies)
    │   └── CloseButton (Button) - Modal closure
    ├── RegionSelectModal (Control) [region_select_modal.gd] - Region actions
    │   ├── OuterFrame (ColorRect) - Modal background styling
    │   └── ButtonContainer (VBoxContainer) - Region action buttons
    ├── RegionTooltip (Control) [region_tooltip.gd] - Hover information with debug support
    │   ├── Background (ColorRect) - Tooltip background
    │   └── Label (Label) - Region information text with tooltip theme
    │       └── Debug mode: Shows P:population, W/F/S/I/G:resources, RL:region_level when AI debug is active
    ├── BattleModal (Control) [battle_modal.gd] - Combat interface (Static UI)
    │   ├── OuterFrame (ColorRect) - Modal background styling
    │   └── BorderMargin (MarginContainer) - Battle content layout
    │       └── MainContainer (VBoxContainer) - Battle organization
    │           ├── TitleContainer (Control) - "Battle for Region" header
    │           │   └── BattleTitleLabel (Label) - Dynamic battle title
    │           ├── MainContent (HBoxContainer) - Two-column battle display
    │           │   ├── AttackerColumnMargin (MarginContainer) - Attacker layout
    │           │   │   └── AttackerColumn (VBoxContainer) - Attacker units
    │           │   │       ├── AttackerHeader (Label) - "Attacker" subheader
    │           │   │       ├── AttackerEffectiveness (Label) - Combat effectiveness
    │           │   │       └── AttackerUnitsContainer (VBoxContainer) - Unit display
    │           │   ├── MarginContainer (Control) - Column separator
    │           │   └── DefenderColumnMargin (MarginContainer) - Defender layout
    │           │       └── DefenderColumn (VBoxContainer) - Defender units
    │           │           ├── DefenderHeader (Label) - "Defender" subheader
    │           │           ├── DefenderEffectiveness (Label) - Combat effectiveness
    │           │           └── DefenderUnitsContainer (VBoxContainer) - Unit display
    │           └── ButtonContainer (Control) - Battle controls
    │               └── ContinueButton (Button) - Battle progression
    ├── PlayerStatusModal (Control) [player_status_modal.gd] - Resource display and turn management
    │   ├── OuterFrame (ColorRect) - Modal background styling
    │   └── ResourceContainer (HBoxContainer) - Resource and turn control layout
    │       ├── PopulationLabel (Label) - Total population and growth
    │       ├── PopSeparator (Control) - Visual separator
    │       ├── GoldLabel (Label) - Gold amount and income
    │       ├── Separator1 (Control) - Visual separator
    │       ├── FoodLabel (Label) - Food amount and net income (production - army costs)
    │       ├── Separator2 (Control) - Visual separator
    │       ├── WoodLabel (Label) - Wood amount and income
    │       ├── Separator3 (Control) - Visual separator
    │       ├── StoneLabel (Label) - Stone amount and income
    │       ├── Separator4 (Control) - Visual separator
    │       ├── IronLabel (Label) - Iron amount and income
    │       ├── Separator5 (Control) - Visual separator
    │       ├── PlayerTurnLabel (RichTextLabel) - Current player and turn indicator with color coding
    │       ├── Separator6 (Control) - Visual separator
    │       └── EndTurnButton (Button) - End current player's turn
    ├── RecruitmentModal (Control) [recruitment_modal.gd] - Military recruitment interface
    │   ├── OuterFrame (ColorRect) - Modal background styling
    │   └── BorderMargin (MarginContainer) - Recruitment content layout
    │       └── MainContainer (VBoxContainer) - Recruitment organization
    │           ├── TitleContainer (Control) - "Recruitment in Region" header
    │           │   └── RecruitmentTitleLabel (Label) - Dynamic recruitment title
    │           ├── HeaderContainer (Control) - Column headers
    │           │   └── HeaderRow (HBoxContainer) - "Army", "Recruit", "Cost" headers
    │           ├── MainContent (MarginContainer) - Recruitment controls
    │           │   └── ArmyUnitsContainer (VBoxContainer) - Unit recruitment rows
    │           ├── TotalRow (Control) - Recruitment totals
    │           │   └── TotalRowContainer (HBoxContainer) - Total counts display
    │           └── ButtonContainer (Control) - Recruitment controls
    │               └── ContinueButton (Button) - Apply recruitment
    └── CallToArmsModal (Control) [call_to_arms_modal.gd] - Recruit consolidation interface
        ├── OuterFrame (ColorRect) - Modal background styling
        └── BorderMargin (MarginContainer) - Call to Arms content layout
            └── MainContainer (VBoxContainer) - Call to Arms organization
                ├── TitleContainer (Control) - "Call to Arms" header
                │   └── CallToArmsTitleLabel (Label) - Modal title
                ├── HeaderContainer (Control) - Column headers
                │   └── HeaderRow (HBoxContainer) - "Regions", "Called Recruits", "Available Recruits" headers
                ├── MainContent (MarginContainer) - Region controls
                │   └── RegionsContainer (VBoxContainer) - Neighboring region rows
                └── ButtonContainer (Control) - Action controls
                    └── ContinueButton (Button) - Execute call to arms
    └── NextPlayerModal (Control) [next_player_modal.gd] - Turn transition notification
        └── ContentContainer (VBoxContainer) - Turn transition layout
            ├── HeaderLabel (Label) - "Next Turn" or "Castle Placement" header
            ├── Spacer1 (Control) - Visual spacing
            └── PlayerLabel (RichTextLabel) - Color-coded current player indication
```

### UI Modal Architecture
**Current Implementation**: All modals are defined inline within main.tscn for simplicity and direct access

**Recommended Scene Extraction** (for better modularity):
- **BattleModal.tscn**: Complex static UI structure ideal for separate scene
- **PlayerStatusModal.tscn**: Resource display with multiple labels and separators
- **RegionModal.tscn**: Region information display with standardized layout
- **ArmyModal.tscn**: Army composition and status display

**Benefits of Scene Extraction**:
- Improved modularity and reusability
- Easier UI maintenance and iteration
- Reduced main.tscn complexity
- Better separation of concerns

### Static vs Dynamic Node Architecture
**Static Container Nodes** (defined in main.tscn):
- **Map/Regions/**: Static container for all region nodes
- **Map/Ocean/**: Static container for ocean polygon objects
- **Map/Frame/**: Static container for map frame polygon objects
- **Region/Borders/**: Static container within each region for border lines

**Runtime Generated Nodes**:
- **Region containers**: Individual regions created by MapGenerator from JSON data
  - Each region is a Node2D with Region script attached
  - Contains Polygon2D for boundaries and collision detection
- **Region/Castle**: Castle sprites created by VisualManager on castle placement  
- **Region/Army_PlayerX_Roman**: Army nodes created by ArmyManager and placed in regions
  - Army nodes contain player_id for ownership tracking
  - Positioned in regions for spatial logic and map interactions
  - Named format: "Army_Player1_I", "Army_Player2_III", etc.
- **Border Line2D objects**: Dynamic ownership-based borders within Region/Borders/
- **Ocean/Frame Polygon2D objects**: Dynamic map elements based on JSON data

### Army Organization Philosophy
**Region-Centric Army Placement**:
- ✅ **Armies live in regions** for positioning, movement, and combat logic
- ✅ **Player ownership** tracked via Army.player_id property  
- ✅ **ArmyManager** handles creation, tracking, and player-based queries
- ✅ **No separate player army containers** - spatial organization takes priority
- ✅ **Clean node hierarchy** - removed redundant empty army containers

### Player Container Purpose
**Players/PlayerX nodes are reserved for**:
- Future player-specific UI elements (flags, banners, player info displays)
- Player statistics tracking and visualization
- Player-specific visual effects or indicators
- Turn-based player state management (if needed)

## Core Management Systems

### game_manager.gd
**Class**: GameManager
**Purpose**: Central game state coordination and multi-player turn-based game flow management with player type system and AI turn processing
**Key Functions**:
- `initialize_managers()`: Dependency injection and system initialization
- `handle_castle_placement()`: Coordinate sequential castle placement for all 6 players with player type handling
- `next_turn()`: Process turn advancement with player rotation, resource management, and AI turn processing
- `_get_next_player()` / `_get_next_active_player()`: Player turn sequence management (1→2→3→4→5→6→1) with OFF player skipping
- `_process_round_start_actions()`: Global actions at start of each round
- `_process_player_turn_start()`: Per-player turn initialization
- `_process_ai_turn()`: Delegate AI turn processing to AITurnManager
- `is_castle_placing_mode()` / `get_current_player_id()`: Game state access
- `_handle_ai_castle_placement()`: AI automated castle selection using highest scored region
- `_initialize_castle_placement_sequence()`: Handle initial game setup with player type awareness
- Manager accessor methods for system coordination
**Player Type System**:
- `player_types: Array[PlayerTypeEnum.Type]`: Array of 6 player types (Human/Computer/Off)
- `get_player_type()` / `set_player_type()`: Player type management functions
- `is_player_active()` / `is_player_human()` / `is_player_computer()`: Player type checking
- Player 1: Human (default), Player 2-4: Computer, Player 5-6: Off
**Multi-Player Features**:
- 6-player sequential turn management with round progression and player type support
- Castle placement phase where each player places one castle based on their type:
  - **Human**: Manual castle placement via mouse clicks
  - **Computer**: Automatic AI castle selection using CastlePlacementScorer for highest scored region
  - **Off**: Skipped entirely in turn sequence
- Per-player resource income processing and army food cost deduction
- Turn indicators and player-specific UI updates with type-aware handling
- **AI Turn Processing**: Automatic AI actions during computer player turns via AITurnManager
**Integrates With**: All managers via dependency injection, PlayerManager, UI systems, CastlePlacementScorer, PlayerTypeEnum, AITurnManager

### PlayerManager.gd  
**Class**: PlayerManager
**Purpose**: Multi-player system with resource management and army food cost tracking for 6 players
**Key Functions**:
- `_calculate_player_income()`: Region-based resource calculation for individual players
- `process_resource_income()`: Apply income to all players (legacy compatibility)
- `process_resource_income_for_player()`: Apply income to specific player for turn-based gameplay
- `get_player_regions()`: Territory ownership tracking per player
- `calculate_total_army_food_cost()`: Calculate food costs for all player armies (garrisons + standalone armies)
- Resource transaction handling (add/remove/afford/pay) for individual players
**Multi-Player Features**:
- Manages 6 players with individual resource pools and army tracking
- Per-player income processing during turn-based gameplay
- Individual player resource transaction validation
- Player-specific army food cost calculations
**Army Food Cost System**:
- Tracks food costs for both garrison armies and standalone armies
- Integrates with ArmyManager to get all player armies
- Used by GameManager for per-player turn-based food cost deduction
**Integrates With**: RegionManager, Player, GameManager, ArmyManager

### region_manager.gd
**Class**: RegionManager
**Purpose**: Territory ownership management and region-based operations
**Key Functions**:
- `set_region_ownership()`: Manage territory ownership changes
- `set_castle_starting_position()`: Handle castle placement and claims
- `upgrade_castle_regions()`: Level up castle and neighbor regions
- `generate_region_resources()`: Create region-specific resources
- `get_neighbor_regions()`: Region adjacency lookups
**Resource Generation**:
- Grassland: Food (10-20)
- Forest: Food (5-10) + Wood (10-20)
- Hills: Food (2-5) + Stone (5-10) + Iron (5-20) + Gold (5-20)
- Forest Hills: Food (2-5) + Wood (5-20) + Stone (5-20)
- Mountains: No resources (impassable)

**Population Generation**:
- All region levels: Population (200-400) based on region level
- Ocean regions: No population (uninhabitable)

**Recruits System**:
- **Available Recruits**: 10% of region population (configurable in GameParameters)
- **Recruitment Impact**: Hiring reduces population and recalculates max recruits
- **Replenishment**: 1% of current population per turn (rounded down)
- **Turn Integration**: Automatic replenishment during turn processing
- **Example**: 313 population → 31 max recruits → hire 13 → 300 population → 30 max, 18 available → +3 per turn

### army_manager.gd
**Class**: ArmyManager
**Purpose**: Army creation, movement, selection, and lifecycle management
**Key Functions**:
- `create_army()`: Create and place armies on regions
- `move_army_to_region()`: Handle army movement with validation
- `reset_all_army_movement_points()`: Turn-based movement reset
- `remove_destroyed_armies()`: Clean up defeated armies
- `select/deselect_army()`: Army selection state management
- `get_terrain_cost()`: Calculate movement costs with ownership bonuses
- `get_player_armies()`: Get all armies for a specific player for AI coordination
**Movement System**: 
- 5 movement points per turn with terrain-based costs
- **Ownership Bonus**: Movement cost reduced by 1 for owned territories (minimum cost of 1)
- Strategic advantage for moving through controlled territory

### click_manager.gd
**Class**: ClickManager
**Purpose**: Focused input handling and click event coordination with player type awareness
**Key Functions**:
- `_unhandled_input()`: Process mouse and keyboard input events
- `_on_left_click()`: Coordinate conversion and region detection
- `_handle_region_click()`: Delegate clicks to GameManager or other systems with player type validation
- `_point_in_polygon()`: Geometric intersection testing
**Player Type Integration**:
- Castle placement clicks only allowed for human-controlled players
- Computer and OFF players have click input ignored during castle placement
- Seamless integration with GameManager player type system
**Integration**: Delegates to GameManager and other specialized systems

### BattleManager.gd
**Class**: BattleManager *(New)*
**Purpose**: Centralized battle and conquest system management
**Key Functions**:
- `complete_conquest()`: Apply conquest results to game state
- `handle_battle_modal_closed()`: Process battle completion
- `apply_battle_losses()`: Update armies and regions after battle
- `handle_army_defeat()`: Remove defeated armies from game
**Integration**: BattleModal, RegionManager, ArmyManager, SoundManager

### VisualManager.gd
**Class**: VisualManager *(New)*
**Purpose**: Centralized visual creation and update system
**Key Functions**:
- `place_castle_visual()`: Create castle sprites on regions
- `place_army_visual()`: Create army visuals via ArmyManager
- `update_region_visuals()`: Coordinate map visual updates
**Integration**: MapGenerator, RegionManager, ArmyManager

## Battle System

### BattleSimulator.gd
**Class**: BattleSimulator (Static)
**Purpose**: Statistical combat resolution engine with efficiency modifiers
**Key Functions**:
- `simulate_battle()`: Statistical combat with binomial sampling and efficiency modifiers
- `_attacks_to_hits()`: Attack calculation with efficiency-modified hit chances
- `_calculate_losses()`: Proportional casualty distribution
- Multiple army support with comprehensive reporting
**Efficiency System Integration**:
- Hit chances modified by army efficiency: base_hit_chance × (efficiency / 100)
- **Garrison Rule**: Region garrison compositions always fight at 100% efficiency
- **Army vs Army**: Both attacking and defending armies use their actual efficiency values
- **Mixed Defending Forces**: Garrison units fight at 100%, defending armies use their efficiency
- Attacking army efficiency passed from Army.get_efficiency()
- Separate efficiency calculations for garrison and army components

### AnimatedBattleSimulator.gd
**Class**: AnimatedBattleSimulator
**Purpose**: Real-time animated battle display with efficiency support
**Key Functions**:
- `start_animated_battle()`: Begin animated combat sequence with efficiency parameters
- Round-by-round progression with configurable timing
- Signal-based UI updates for battle modals
- Battle report generation with detailed casualties
**Efficiency Integration**:
- Accepts attacker_efficiency and defender_efficiency parameters
- Calculates separate hit chances for garrison (100%) and army (variable) components
- `_get_armies_from_defenders()`: Separates army units from garrison units for efficiency calculations
- Mixed defending forces handled correctly with proper efficiency values

## Data Classes and Enums

### Player.gd
**Class**: Player
**Purpose**: Individual player data management
**Key Functions**:
- Resource storage and transaction handling
- Player identification (ID, name, color)
- Save/load functionality with dictionary serialization
**Starting Resources**: 1 of each type (Gold, Food, Wood, Iron, Stone)

### Region.gd
**Class**: Region
**Purpose**: Territory data container with recruit management and population growth
**Key Functions**:
- Region properties (ID, name, biome, type, level, population)
- Garrison and resource composition management
- Movement cost and passability determination
- Population tracking and management
- **Recruit Management**: `hire_recruits()`, `replenish_recruits()`, `get_available_recruits()`
- **Population Impact**: Hiring recruits reduces population and recalculates limits
- **Population Growth**: `grow_population()` - Turn-based population growth with recruit availability modifier and promotion bonuses
- **Ownership Tracking**: `set_region_owner()`, `increment_ownership_counter()`, `get_ownership_recruitment_modifier()`
**Population Growth System**:
- Base growth rate from GameParameters.POPULATION_GROWTH_RATE (3%)
- Growth modified by recruit availability ratio (available/max recruits)
- Recruit ratio capped at 1.0 to prevent Call to Arms from boosting growth above 3%
- Growth calculated as: base_rate * min(1.0, available_recruits/max_recruits)

**Castle-Based Recruitment System**:
- Recruitment percentage based on castle level: No castle (6%), Outpost (7%), Keep (8%), Castle (9%), Stronghold (10%)
- Maximum recruits calculated as: population × castle_recruitment_percentage
- Recruitment limits automatically recalculate when castles are built or upgraded
- Higher castle levels enable larger standing armies and faster military expansion

**Ownership-Based Recruitment Modifier**:
- Newly conquered regions have reduced recruitment efficiency based on ownership duration
- Turn 0 (just conquered): 0% recruitment available
- Turn 1: 20% of normal recruitment pool
- Turn 2: 40% of normal recruitment pool
- Turn 3: 60% of normal recruitment pool
- Turn 4: 80% of normal recruitment pool
- Turn 5+: 100% recruitment (full efficiency)
- Formula: available_recruits × (ownership_turns × 0.2), capped at 1.0
- **Special Case**: Initial castle placement regions start with full recruitment (counter = 5)
- **Castle Placement Protection**: Cannot place castles on regions owned by other players
- Encourages strategic consolidation and makes rapid expansion less immediately powerful
**Integrates With**: RegionManager, ResourceComposition, ArmyComposition, GameParameters

### Army.gd
**Class**: Army
**Purpose**: Individual army management with efficiency tracking
**Key Functions**:
- Movement point tracking (5 per turn)
- Army composition integration
- Player ownership and positioning
- **Efficiency Management**: `get_efficiency()`, `set_efficiency()`, `reduce_efficiency()`, `restore_efficiency()`
- **Make Camp**: Restores 10 efficiency points (costs 1 movement point)
**Efficiency System**:
- Starting efficiency: 100% for all armies
- Movement reduces efficiency by 5% per move
- Battle participation reduces efficiency by 5%
- Efficiency affects hit chances in combat (base hit chance × efficiency%)
- Efficiency minimum: 10%, maximum: 100%
- Making camp restores 10 efficiency points
**Battle Efficiency Rules**:
- **Army vs Army**: Both sides use their actual efficiency values
- **Army vs Garrison**: Attacking army uses efficiency, garrison always 100%
- **Army vs Mixed**: Garrison units 100%, defending armies use their efficiency
**Types**: Regular armies and raised armies (from regions)

### ResourceComposition.gd
**Class**: ResourceComposition
**Purpose**: Resource storage and manipulation
**Key Functions**:
- Resource amount tracking by type
- Mathematical operations (add, subtract, multiply)
- Serialization and string formatting

### ArmyComposition.gd
**Class**: ArmyComposition  
**Purpose**: Military unit management
**Key Functions**:
- Soldier count tracking by type (Peasants, Archers, Knights)
- Combat strength calculations
- Recruitment cost and time calculations

## Enumeration System

### ResourcesEnum.gd
**Types**: GOLD, FOOD, WOOD, IRON, STONE
**Features**: Starting amounts, string conversion, icon paths, formatting

### RegionTypeEnum.gd
**Types**: GRASSLAND, HILLS, FOREST, FOREST_HILLS, MOUNTAINS
**Features**: Movement costs, passability, display strings, biome conversion

### RegionLevelEnum.gd
**Levels**: MARCH, PROVINCE, SHIRE, COUNTY, DUCHY
**Features**: Administrative hierarchy with descriptions

### SoldierTypeEnum.gd
**Types**: PEASANTS, ARCHERS, KNIGHTS
**Features**: Combat stats, recruitment costs, training times

### PlayerTypeEnum.gd
**Types**: HUMAN, COMPUTER, OFF
**Purpose**: Define player control types for castle placement and gameplay
**Features**: 
- String conversion utilities (`type_to_string()`, `from_string()`)
- GameManager integration for player type management
- Castle placement behavior control (manual/automatic/skip)

### GameParameters.gd
**Class**: GameParameters (Static)
**Purpose**: Centralized configuration and parameter management for multi-player gameplay
**Key Constants**:
- **Single-Line Constants**: `MOVEMENT_POINTS_PER_TURN` (5), `BATTLE_ROUND_TIME` (0.8s), `BIOME_ICON_SCALE` (0.15), `FOREST_ICON_SCALE` (0.20)
- **Border Enhancement**: `BORDER_SATURATION_BOOST` (0.2), `BORDER_VALUE_REDUCTION` (0.15), `BORDER_OPACITY` (0.9), `BORDER_MIN_VALUE` (0.2)
- **Region Level Bonuses**: `REGION_RESOURCE_LEVEL_MULTIPLIER` (0.25), `PROMOTION_GROWTH_BONUS_TURNS` (5), `PROMOTION_GROWTH_BONUS_BY_TURN` table
- **Castle Recruitment**: `CASTLE_RECRUITMENT_PERCENTAGES` - Recruitment rates by castle type (2% to 10%)
- **Multi-Player System**: `PLAYER_COLORS` - Color definitions for all 6 players (RED, BLUE-GRAY, GREEN, YELLOW, MAGENTA, CYAN)
- **Population System**: `RECRUIT_PERCENTAGE_OF_POPULATION` (8%), `RECRUIT_REPLENISH_RATE` (1%), `POPULATION_GROWTH_RATE` (3%)
- **Unit Combat Statistics**: Attack/defense values, recruitment costs with food costs per unit type
- **Recruitment System**: Castle-based unit availability with tier mappings (CASTLE_RECRUITMENT_TIERS)
- **Movement Costs**: Terrain-based movement point consumption
- **Resource Generation**: Min/max ranges by region type
- **Starting Resources**: Player initial resource amounts
**Key Functions**:
- `calculate_max_recruits()`: Calculate castle-based percentage of population for recruit limit
- `calculate_recruit_replenishment()`: Calculate 1% population replenishment
- `generate_population_size()`: Level-based population generation
- `can_recruit_unit_with_castle()`: Check unit availability based on castle type
- `get_castle_max_tier()`: Get maximum recruitment tier for castle types
- Unit cost helper functions: `get_unit_gold_cost()`, `get_unit_food_cost()`, `get_unit_total_recruitment_cost()`
- Resource and movement cost helper functions
- `get_player_color()`: Get color for specific player ID (multi-player support)

## UI System

### player_status_modal.gd
**Class**: PlayerStatusModal
**Purpose**: Real-time resource display, income tracking, and turn management UI
**Key Functions**:
- `refresh_from_game_state()`: Update from current game state
- `_calculate_region_income()`: Show actual region-based income for current player
- `_on_end_turn_button_pressed()`: Handle end turn button for multi-player turn cycling
- Always-visible top-right display with income indicators, player turn status, and end turn controls
**Multi-Player Features**:
- Player turn indicator with color-coded player identification
- Dynamic display showing current player and round number
- End Turn button for advancing to next player's turn
- Castle placement mode indicator during initial setup phase

### battle_modal.gd
**Class**: BattleModal
**Purpose**: Combat interface and resolution display
**Key Functions**:
- Two-column battle display (Attacker vs Defender)
- Real-time unit count updates during animated battles
- Battle report with casualty breakdown

### region_modal.gd
**Class**: RegionModal
**Purpose**: Territory information display
**Key Functions**:
- Region details (name, type, level, population, resources)
- Garrison composition display
- Integration with region type system

### next_player_modal.gd
**Class**: NextPlayerModal
**Purpose**: Turn transition notification with automatic hide after 2 seconds
**Key Functions**:
- `show_next_player()`: Display player turn notification with color-coded player identification
- `hide_modal()`: Manually hide modal or auto-hide via timer
- `_on_timer_timeout()`: Automatic modal dismissal after 2-second display
**Multi-Player Features**:
- Color-coded player names using GameParameters.get_player_color()
- Dynamic header text for castle placement vs. normal gameplay phases
- Auto-dismissal timer for seamless turn transitions
- Non-blocking modal that allows UI interaction during display
**Integration**: GameManager for turn transitions, UIManager for modal state management

### ui_manager.gd
**Class**: UIManager
**Purpose**: Centralized UI state management and modal coordination
**Key Functions**:
- `set_modal_active()`: Control modal state and tooltip interactions
- `close_all_active_modals()`: Centralized modal closure
- `handle_mouse_motion()`: Region tooltip display management
- `is_any_modal_visible()`: Modal conflict resolution
**Integration**: All modal components, RegionTooltip, MapGenerator, Input system

## AI System

### RegionScorer (ai/region_scorer.gd)
**Class**: RegionScorer
**Purpose**: Strategic region evaluation and scoring for AI decision making
**Key Functions**:
- `calculate_region_score()`: Comprehensive 0-100 region scoring
- `score_all_regions_for_player()`: Calculate scores for all regions from player perspective
- `get_top_scored_regions()`: Get highest value targets
- Pathfinding utilities: `_find_distance_to_nearest_enemy()`, `calculate_movement_path_cost()`
**Scoring Factors**:
- Population value and recruitment potential (weighted)
- Resource availability (gold, food, wood, stone, iron with individual weights)
- Strategic infrastructure (region level, castle level)
- Neighbor analysis (owned, neutral, enemy territory counts)
- Distance to nearest enemy positions using BFS pathfinding
**Integration**: GameParameters (weights), RegionManager (ownership), Region (data)

### CastlePlacementScorer (ai/castle_placement_scorer.gd)
**Class**: CastlePlacementScorer
**Purpose**: Advanced castle placement evaluation using cluster-based scoring algorithm
**Key Functions**:
- `score_castle_placement_candidates()`: Comprehensive cluster-based evaluation of all regions
- `_calculate_cluster_metrics()`: Aggregate population, resources, level across region + neighbors
- `_calculate_distance_to_nearest_enemy()`: Multi-source BFS pathfinding to enemies
- `_calculate_normalization_parameters()`: Percentile-based normalization (5th/95th percentiles)
- `_calculate_resource_score()`: Shannon entropy diversity + diminishing returns soft caps
- `_calculate_safety_score()`: Exponential decay distance scoring
**Algorithm Features**:
- Cluster evaluation: region + all passable neighbors (excludes mountains)
- Resource balance: 60% quantity + 30% diversity + 10% gold bonus
- Safety scoring: 1 - exp(-max(distance-1, 0)/4) with λ=4, safe_floor=1
- Weighted combination: Population(30%) + Resources(35%) + Safety(20%) + Size(10%) + Level(5%)
- Robust normalization: percentiles for pop/size, medians for resource soft caps
**Integration**: RegionManager, MapGenerator, AIDebugVisualizer

### AIDebugVisualizer (ai/ai_debug_visualizer.gd)
**Class**: AIDebugVisualizer (extends Node2D)
**Purpose**: Visual debugging tools for castle placement scoring system
**Key Functions**:
- `toggle_debug_display()`: Show/hide castle placement scores with "0" key
- `_draw_region_score()`: Render cluster-based castle placement scores at region centers
- Color-coded backgrounds (green=high, yellow=medium, red=low scores)
- `print_top_regions()`: Console debugging output
- `is_debug_visible()`: Check if debug mode is active
- `get_region_score()`: Get cached castle placement score for specific region
**Visual Elements**:
- Castle placement scores (0-100) with readable backgrounds
- Color coding based on score thresholds (70+, 30-70, <30)
- Layer rendering on top of map (z_index = 1000)
- Each score represents how good the region is for castle placement (includes neighbor cluster)
**Integration**: CastlePlacementScorer (data), RegionScorer (legacy), MapGenerator (positions), GameManager (input), RegionTooltip (debug state)

### ArmyTargetScorer (ai/army_target_scorer.gd)
**Class**: ArmyTargetScorer
**Purpose**: Pure target evaluation system for army movement decisions
**Key Functions**:
- `score_target_regions()`: Evaluate and rank target regions for army movement
- `get_best_target()`: Return highest scored target from candidates
- `_calculate_individual_score()`: Score single region based on strategic value
**Scoring Factors**:
- Population value for recruitment potential
- Resource availability with weighted importance
- Strategic position and expansion opportunities
- Region level and infrastructure value
**Design Philosophy**:
- Pure scoring function without movement costs or time factors
- Context-free evaluation (no discounting or multi-turn planning)
- Used by ArmyMovementPlanner for target evaluation
**Integration**: RegionManager, MapGenerator, GameParameters

### ArmyPathfinder (ArmyPathfinder.gd)
**Class**: ArmyPathfinder
**Purpose**: Limited Dijkstra pathfinding for army movement with MP constraints
**Key Functions**:
- `find_reachable_regions()`: Find all regions reachable within MP limit using Dijkstra
- `get_valid_moves_for_army()`: Get valid moves for specific army with current MP
- `trim_path_to_mp_limit()`: Trim path to fit within movement point constraints
- `calculate_path_cost()`: Calculate total MP cost for a movement path
- `_calculate_enter_cost()`: Uniform cost calculation with ownership bonuses
- `_reconstruct_path()`: Build path from start to target using parent tracking
**Algorithm Features**:
- **Limited Dijkstra**: Search horizon limited by MP (default 15 = 3 turns)
- **Ownership Bonus**: Movement cost reduced by 1 for owned territories (min 1)
- **Priority Queue**: Efficient frontier expansion for optimal pathfinding
- **Path Reconstruction**: Full path tracking from start to destination
**Integration**: RegionManager, ArmyManager, GameParameters

### ArmyMovementPlanner (ArmyMovementPlanner.gd)
**Class**: ArmyMovementPlanner
**Purpose**: High-level army movement coordination with strategic planning
**Key Functions**:
- `plan_army_movement()`: Plan optimal movement using pathfinding and scoring
- `detect_frontier_regions()`: Find owned regions adjacent to non-owned
- `prioritize_armies()`: Order armies by strength for deconfliction
- `_score_all_moves()`: Combine pathfinding with target scoring
- `_select_best_move()`: Choose move with discounted future scoring
- `_calculate_discounted_future_score()`: Evaluate future opportunities
- `_calculate_danger_penalty()`: Assess risk from enemy proximity
- `_find_rally_point_move()`: Fallback movement toward castles
**Strategic Features**:
- **Multi-Turn Planning**: Evaluates current + discounted future scores
- **Discounting**: Future opportunities weighted by gamma_turn=0.9
- **MinWanted Threshold**: Only move if score exceeds 5% threshold
- **Danger Assessment**: Penalty for enemy-adjacent regions
- **Rally Points**: Castle-based fallback when no good targets
- **Frontier Detection**: Identifies expansion/defense boundaries
**Integration**: ArmyPathfinder, ArmyTargetScorer, RegionManager, GameParameters

### AITurnManager.gd
**Class**: AITurnManager
**Purpose**: Coordinate all AI actions during a player's turn with integrated battle resolution
**Key Functions**:
- `process_turn()`: Main AI turn processing entry point - coordinates all AI actions for complete turn
- `_move_armies_with_debug()`: Handle all army movements with sequential processing and battle waiting
- `_move_single_army()`: Move individual army with integrated battle resolution using sophisticated pathfinding
- `_wait_for_battle_completion()`: Wait for battle completion before continuing turn processing
- `_calculate_scoring()` / `_manage_regions()`: Placeholder functions for future strategic AI expansion
**Battle Integration Features**:
- **Integrated Battle Resolution**: Battles resolved as part of army movement sequence, not externally
- **Sequential Army Processing**: Each army fully completes its movement (including battles) before next army
- **Battle Detection**: Automatic detection when army movement triggers combat via army auto-deselection
- **Battle Waiting**: Uses `await` to wait for battle completion before continuing turn processing
- **Turn Completion**: Turn only ends after ALL armies have completed their movements AND battles
- **Clear Sequence**: Plan move → execute move → resolve battle (if any) → move to next army
**AI Army Movement Algorithm**:
- Uses **ArmyMovementPlanner** for strategic multi-turn pathfinding with limited Dijkstra algorithm
- **Pathfinding Horizon**: 3 turns (15 MP) for strategic planning beyond immediate neighbors
- **Target Evaluation**: Integrates ArmyPathfinder with ArmyTargetScorer for optimal move selection
- **Discounted Scoring**: Future opportunities discounted by gamma_turn=0.9 factor
- **Movement Decisions**: Only move if total score exceeds minWanted threshold (5% = 0.05)
- **Danger Assessment**: Penalty for moving into enemy zones of control
- **Rally Points**: Fallback movement toward castle positions when no good targets available
- **Comprehensive Logging**: Detailed decision tracking for debugging and analysis
**Integration Structure**:
- **ArmyMovementPlanner**: High-level movement coordination and strategic planning
- **ArmyPathfinder**: Limited Dijkstra pathfinding with MP constraints and ownership bonuses
- **ArmyTargetScorer**: Pure target evaluation (Val function) unchanged from previous system
- **RegionManager**: Territory ownership and castle position tracking for rally points
- **ArmyManager**: Army execution, selection, movement validation, and terrain cost calculation
- **BattleModal**: Battle state tracking for completion detection and waiting
- **GameParameters**: Algorithm parameters (R=3, gamma_turn=0.9, minWanted=5, danger_penalty=10)
**Algorithm Features**:
- **Multi-turn Planning**: Considers reachable regions within 3-turn horizon (15 MP)
- **Ownership Bonus**: Movement cost reduced by 1 for owned territories (minimum 1 MP)
- **Smart Pathfinding**: Finds optimal paths beyond immediate neighbors using graph search
- **Future Scoring**: Evaluates long-term positioning and strategic opportunities
- **Fallback System**: Rally point movement toward castles when no suitable targets found

## Support Systems

### map_generator.gd
**Class**: MapGenerator
**Purpose**: Procedural map creation and region management
**Key Functions**:
- JSON-based map data loading
- Dynamic region polygon creation within static containers
- Border generation with ownership-based coloring
- Ocean and mountain region handling
- Customizable forest icon sizing with dedicated FOREST_ICON_SCALE parameter
- Static container node management (Regions, Ocean, Frame)
**Architecture**: Uses static container nodes for predictable structure, dynamic content creation

### camera_controller.gd
**Class**: CameraController
**Purpose**: Map navigation and viewport management
**Key Functions**:
- Pan and zoom controls
- Viewport boundaries and limits
- Smooth camera movement

### sound_manager.gd
**Class**: SoundManager
**Purpose**: Audio feedback system
**Key Functions**:
- UI interaction sounds
- Battle and movement audio
- Volume and audio configuration management

## Data Files

### regions.json
**Purpose**: Region naming data for procedural assignment
