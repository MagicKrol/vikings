# Vikings Strategy Game - Project Map

## Overview
Turn-based strategy game in Godot 4.3 with procedural map, resources, recruitment, movement, and battles for up to 6 players. Architecture emphasizes separation of concerns and SRP.

## Scenes

### main_menu.tscn
- Entry UI. Starts a new game or continues; loads `main.tscn`.
- MapPreview: Visible only in Campaign/Scenario menus. `InnerPanel` background stays visible while menu is open; `MapScreenshot` toggled on hover. Fits height (keeps aspect), width is clipped.
- Menu UX: No click sounds on button presses in main menu.

Start Flow
- Main menu sets `SceneTree` meta `start_payload` and loads `main.tscn`:
  - Scenario: `{ type: "scenario", scenario_path: res://scenarios/<name>.json }`
- Custom map: `{ type: "map", map_file: res://mapdata/<file>.json, map_size: <small|medium|large|huge> }` (size inferred from filename suffix; new names map internally to legacy values)
- `GameManager._ready()` reads `start_payload`:
  - Scenario: sets `game_mode = "scenario"`, assigns `scenario_path` (pre-load applies scenario map file).
  - Custom map: sets `game_mode = "custom"`, assigns `MapGenerator.data_file_path` and map size via `_map_set_size_from_string`, then `generate_map()`.
  - Payload is cleared after consumption.

### main.tscn (Primary)
Main (Node2D) [place_armies.gd]
├ Map (Node2D) [map_generator.gd]
│	├ Regions (Node2D) – dynamic `Region` nodes [region.gd] (land polygons tile `background4.png` and sync shape from noisy borders; mountain clusters use hidden noisy lines; ocean polygons hidden by default)
│	├ Ocean (Node2D) – metadata-only ocean polygons (hidden visuals)
│	└ Frame (Node2D)
├ Background (Sprite2D)
├ Camera2D [camera_controller.gd]
├ ClickManager (Node) [click_manager.gd]
├ GameManager (Node) [game_manager.gd]
├ SoundManager (Node) [sound_manager.gd]
├ PlayerManager (Node) [PlayerManagerNode.gd]
├ MapEditor (Node) [map_editor.gd]
├ UI (CanvasLayer)
│	├ UIManager (Control) [ui_manager.gd]
│	├ ArmyModal [scenes/army_modal.tscn] [army_modal.gd]
│	├ SelectModal [scenes/select_modal.tscn] [select_modal.gd]
│	├ ArmySelectModal [scenes/army_select_modal.tscn] [army_select_modal.gd]
│	├ InfoModal [scenes/info_modal.tscn] [info_modal.gd]
│	│	└ Uses `themes/standard_text_modal_theme.tres` for body text (#f1d891) and `themes/header_modal_theme.tres` for headers
│	├ RegionSelectModal [scenes/region_select_modal.tscn] [region_select_modal.gd]
│	├ RegionTooltip [scenes/region_tooltip.tscn] [region_tooltip.gd]
│	├ BattleModal [scenes/battle_modal.tscn] [battle_modal.gd] – shares InfoModal standard/header themes for text styling
│	├ BattleSummaryModal [scenes/battle_summary_modal.tscn] [battle_summary_modal.gd] – uses same InfoModal body/header themes
│	├ PlayerStatusModal [scenes/player_status_modal.tscn] [player_status_modal.gd]
│	├ PlayerStatusModal2 [scenes/player_status_modal2.tscn] [player_status_modal2.gd] – resource HUD; hides RegionTooltip2 on mouse enter
│	├ TurnModal [scenes/turn_modal.tscn] [turn_modal.gd] – turn display; mouse enter hides RegionTooltip2; player label clamps HSV value to 60% with 2px outline
│	├ RecruitmentModal [scenes/recruitment_modal.tscn] [recruitment_modal.gd]
│	├ CallToArmsModal [scenes/call_to_arms_modal.tscn] [call_to_arms_modal.gd]
│	├ TransferSoldiersModal [scenes/transfer_soldiers_modal.tscn] [transfer_soldiers_modal.gd]
│	├ TransferSelectModal [scenes/transfer_select_modal.tscn] [transfer_select_modal.gd]
│	├ SelectTooltipModal [scenes/select_tooltip_modal.tscn] [select_tooltip_modal.gd]
│	├ SelectTooltipModalNoRes [scenes/select_tooltip_modal_nores.tscn] [select_tooltip_modal_nores.gd] – message-only tooltip
│	├ MessageModal [scenes/message_modal.tscn] [message_modal.gd]
│	├ NextPlayerModal [scenes/next_player_modal.tscn] [next_player_modal.gd]
│	├ MoveModal [scenes/move_modal.tscn] [move_modal.gd] – cancel move UI; hides region tooltip on hover
│	└ MapEditorPanel [scenes/map_editor_panel.tscn] [map_editor_panel.gd]
└ Players (Node2D)
	├ Player1..Player6 (Node2D) – reserved containers

Notes
- UI modals are extracted into separate `.tscn` scenes and instanced under `UI` (no longer inline).
- Regions, armies, castles are created at runtime under `Map/Regions`.
- Map background tiles `sea_new.png` (Sprite2D region repeat) without stretching; ocean visuals rely on base layer only; land polygons rebuild from border noise to stay aligned (mountain clusters rely on hidden noisy borders for seamless joins).
- Ownership borders render as solid Line2D strokes.

Map Editor Panel (editor mode)
- Uses TabContainer with 4 tabs: Main, Scenario, Region, Army
- Main Tab: Save/Load scenario functionality
  - Save Scenario: Input + button. Writes JSON to `res://scenarios/<scenario_name>.json` (or `last_saved_scenario.json` if empty) with:
    - `map_file` (source mapdata JSON path)
    - `regions`: list with id, name, biome/ocean/type_display, level, castle_type, population, owner, resources, discovered_ores
    - `armies`: list with region_id, player_id, name, composition (per unit type)
    - `player_settings`: six entries (player_id + control_type: Player/Computer/Off)
    - `player_resources`: six entries (player_id + resource dictionary for Gold/Wood/Food/Stone/Iron). Applied to `PlayerManagerNode` by `ScenarioManager.apply_to_runtime()` when the scenario starts.
  - Load Scenario: Lists all `res://scenarios/*.json` in a select box with "Load" button (no-op for now)
  - Save Map: Persists edited base map biomes and ocean flags back to the selected `res://mapdata/<file>.json`.
- Scenario Tab: Player control toggles plus starting resource editor (dropdown for Player 1–6, rows for Gold/Wood/Food/Stone/Iron with editable amounts saved to `player_resources`).
- Region Tab: ID, Name, Type, Level, Population, Castle, Resources, Ore, Ownership
  - Ownership: OptionButton with Neutral (0) and Players 1–6. Emits `region_type_changed` with `OWNER:<id>`
- Army Tab: Army management with two states
  - Default state: Army toggle button (Add Army/Remove Army when owner > 0; hidden for Neutral), Edit Army button
  - Edit state: Shows Region ID/Name, Army Name, and per-unit counts (editable). "Close" saves changes and returns to default
- MapEditor handles signals by delegating to `RegionManager.set_region_ownership` (creates/removes overlays, regenerates borders) and `ArmyManager.create_raised_army` / removal. Region resources are generated by `RegionManager` after the map is generated in editor mode.
 - Quick ownership mode: Press number keys `1..6` in editor to enable ownership mode for that player; next region click assigns ownership. Press `ESC` to exit ownership mode.
- When editing army, Army tab stays active with edit panel visible until closed
 - Save Map: persists per-region `biome` and `ocean` flags to the source `mapdata-*.json` so ocean/land edits load correctly.

editor_start.tscn (Editor Start)
- Start UI when `enable_map_editor = true`.
- Map Data: lists `mapdata-*.json` under `res://mapdata/`; “Edit Map or New Scenario” passes `res://mapdata/<filename>` to `MapGenerator.data_file_path`, then loads `main.tscn` and applies map size inferred from filename.
- Map Data: lists `mapdata-*.json` under `res://mapdata/`; code always reads map files from this folder. `MapGenerator.data_file_path` expects a bare filename (no `res://` or folder). Supported sizes: xtiny, tiny, small, medium, large, huge.
- Scenario: lists `res://scenarios/*.json`; loader always resolves scenarios from `res://scenarios/` and accepts bare filenames or full paths. Scenario `map_file` field should be a bare filename; loader resolves from `res://mapdata/`.
- Scenario: during load, GameManager infers `map_size` from the scenario `map_file` suffix (e.g., `mapdata-208-medium.json` → `medium`) and applies `_map_set_size_from_string()` before generating the map.
 - Launch: EditorStart sets `SceneTree` meta `editor_start_payload` and switches to `main.tscn`. `GameManager._ready()` force-enables editor mode when this payload is present and calls `_initialize_map_editor()` to show `MapEditorPanel`.

## Core Managers & Flow

### game_manager.gd (GameManager)
- Purpose: High-level orchestration (castle placement, turns, resource ticks, AI start, battle finalization).
- Key: `initialize_managers()`, `next_turn()`, `_process_round_start_actions()`, `_process_player_turn_start()`, `handle_castle_placement()`, `finalize_battle_result(...)`.
- Integrates: RegionManager, ArmyManager, BattleManager, VisualManager, UIManager, PlayerManagerNode, TurnController, AIDebugVisualizer, CastlePlacementScorer.
- Debug: `debug_disable_battle_modal` — when true, AI battles run instantly in background (no modal, no delays).
- Camera: Sets initial zoom by map size at startup (Small=1.0, Medium=1.5, Large=2.0) and clamps zoom-out to 0.5.
- AI memory: Records observed enemy army power for computer players after each battle (5-round decay window via `GameParameters.ENEMY_ARMY_MEMORY_ROUNDS`).
- AI memory: Records observed enemy garrison power when computer armies attack a region (shared 5-round decay window).
- AI: Uses `TurnController.start_turn()` for computer players; castle placement uses `CastlePlacementScorer` with randomness.
- Map Editor: `enable_map_editor` flag — when true, skips castle placement/turns, initializes MapEditor, shows empty editor panel (25% left).
 - Modes:
   - Custom: current behavior (castle placement → gameplay).
 - Scenario: set `game_mode="scenario"` and `scenario_path` before start; map is regenerated from scenario `map_file`, managers init, then `ScenarioManager.apply_to_runtime` is called. Skips castle placement and starts the first turn immediately.
 - Scenario resources: `ScenarioManager.apply_to_runtime()` pushes `player_resources` into `PlayerManagerNode.set_player_resources()` before the first turn.
- First turn: `_process_player_turn_start()` skips economy/food for each player the first time it runs so HUD deltas stay `+0`; actual income/upkeep begins when that player starts turn two.
- Famine: `_process_army_food_costs_for_player()` triggers `famine_regions()` when food falls short (1 food deficit = 10 population loss). Starvation reduces region population (floor 30), wipes garrisons at the minimum, and then removes army soldiers proportionally. UI growth indicators flip to red using the region's `last_population_growth`.

### scenario_manager.gd (ScenarioManager)
- Purpose: Data-driven loader for premade scenarios (map + region overrides + ownership + castles + armies).
- API: `load_scenario(path) -> Dictionary`, `apply_to_runtime(map_generator, region_manager, army_manager, visual_manager, scenario, player_manager)`.
- Order of application: regions (type/ocean, level, population, resources, ores, name) → ownership (via RegionManager) → castles (via VisualManager) → armies (via ArmyManager).
- Ownership setup treats scenario-owned regions as fully established: `set_initial_region_ownership()` is used for player IDs > 0 so they start turn one with full recruit availability.
- Region setup now refills recruit pools to the current max after applying population and castle overrides so scenario starts never begin partially depleted.
- Keeps base map geometry in the referenced `map_file`; scenario stores only deltas.

### TurnController.gd (TurnController)
- Purpose: Unified turn pipeline for AI (and fits human pipeline shape).
- Flow: frontier discovery → target scoring → build candidates → execute with step-gate → handle battle → continue/recalc.
- Signals: `turn_started`, `move_prepared`, `move_started`, `battle_started`, `battle_finished`, `region_conquered`, `turn_finished`.
- Uses: `ArmyPathfinder`, `ArmyTargetScorer`, `BudgetManager` (allocate budgets at turn start), `RecruitmentManager` (hire at castles when requested; AI allows instant hire for `just_raised`), `DebugStepGate`.
- Calls back into `GameManager.ai_travel_to()` for step-wise movement and battle triggers.
- Resting Logic (AI):
  - Start-of-evaluation: if an army's efficiency < 75%, it spends all remaining MPs on `make_camp()` and skips movement that loop.
  - Pre-attack: if an army can reach a target now and a battle is expected, and efficiency < 90%, it calls `make_camp()` up to 2 times (bounded by MPs) before moving.
  - End-of-turn: after post-movement economy, any army with leftover MPs spends all on `make_camp()`.
- Peasants-Only Recruitment:
  - Runs only when standard recruitment is not needed and peasant ratio < AI_PEA_MIN_PROP_BASE
  - Targets peasant share based on army power thresholds (low/mid/high power → 40%/30%/20% peasants)
  - Moves to best reachable owned region with highest available recruits to hire peasants (free cost)
  - Uses pathfinding to find optimal region within current movement points

### BattleManager.gd (BattleManager)
- Purpose: Battle UI coordination and post-battle processing via signals.
- Key: `start_battle()`, `handle_battle_modal_closed()`, emits `battle_finished`; tracks pending conquest; proportional loss application; removes only battle-participant armies reduced to zero (no global scan).
- Integrates: BattleModal UI, RegionManager (read), ArmyManager (remove/retreat), GameManager (finalization).
- Behavior: If `GameManager.debug_disable_battle_modal` is enabled for AI, `start_battle()` simulates instantly via `BattleSimulator` and emits `battle_finished` without showing a modal.
- Post-battle reselection now mirrors `ArmySelectModal -> Move Army` by clearing `UIManager` modal state so the next region click moves immediately.

### Region systems
- region_manager.gd (RegionManager): ownership map, castle start, neighbor graph, resource generation, level upgrades, turn ticks (population growth, recruit replenish, castle builds, ore search reset), frontier discovery, nearest owned castle search, recruit source aggregation, castle level lookup.
- region.gd (Region): data container with population, resources, recruits, ownership counter, garrison, castle type/upgrade, ore search, movement/passability helpers.
  - `apply_population_loss(loss, min_population)` clamps population, recalculates recruits, and forces `last_population_growth` negative for famine turns.
  - `heal_all_wounded()` now restores wounded recruits straight into the base recruit pool (pre-ownership modifier) so they heal at turn start without touching population.
  - `fill_recruits_to_maximum()` resets the recruit pool to the region's current cap (used during scenario setup).
- Info modal theme uses a `FontVariation` and theme shadow settings for Labels so region stats stay legible over busy backgrounds without outlines.
  - `get_wounded_recruits_total()` exposes the wounded-peasant count for UI consistency.

### Army systems
- army_manager.gd (ArmyManager): create/select/move/deselect armies, movement points reset, battle hooks, tracking and cleanup.
- army.gd (Army): movement points, ownership, efficiency (reduce/restore, affects combat), recruitment request/assigned budget, simple power checks. Includes `just_raised` flag (AI-only instant recruitment bypass on first turn; cleared after use).
- ArmyPathfinder.gd: pathfinding within MP horizon, multi-turn pathfinding with MP constraints.
- **ArmyTargetScorer.gd**: **Single source of truth for army region scoring**. Provides canonical raw scoring APIs:
  - `get_base_region_score_raw(region, player_id)`: Returns raw base sum and components (strategic + population + level + resource, no normalization)
  - `get_resource_component_breakdown_out_of_10(region, player_id)`: Per-resource contributions that sum to resource component  
  - `get_final_army_score_raw(army, region_id)`: Returns final_raw = base_raw + random - mp_cost with full breakdown
- ArmyMovementPlanner.gd: High-level army movement coordination using canonical raw final scoring from ArmyTargetScorer. Applies danger penalty as separate adjustment after raw final score.

### VisualManager.gd (VisualManager)
- Purpose: Place/update/remove castle visuals; create army visuals via ArmyManager; trigger region visual updates. Move highlight uses looping alpha tween (0.5↔0.75); hover shows a cloned overlay at 0.85 while the base tween keeps running and hides the region tooltip during move highlighting.

### map_editor.gd (MapEditor)
- Purpose: Map editor mode controller for toggling editor UI.
- Key: `initialize()` — shows MapEditorPanel, hides player/turn UI.
- Note: Empty panel for now, based on info_modal.tscn (25% width left side).

### PlayerManagerNode.gd (PlayerManagerNode)
- Purpose: Player storage and per-player economy as a scene node.
- Key: initialize players; `current_player_changed` signal; add/remove/afford/pay; per-player income `process_resource_income_for_player()`; total army+garrison food cost; `set_player_resources()` for scenario starts; save/load.
- Used by GameManager and TurnController.

### Economy & Recruitment
- BudgetManager.gd: Split player resources among armies at castles that need reinforcement; sets `army.assigned_budget` with `BudgetComposition`.
- BudgetComposition.gd: Simple value holder for gold/wood/iron/available_recruits; afford/check helpers.
- RecruitmentManager.gd: Hire units for an army using ideal-composition logic and neighbor recruit sources; deducts recruits proportionally.

### EconomyAIManager.gd
- Purpose: Central, deterministic planner for AI economy decisions each turn.
- Current Scope: Recruitment budgeting and raise army decisions (integrated with existing flow).
- Future Hooks: region_upgrade, castle_upgrade (stubs in place).
- Key Functions:
  - `plan_turn(player_id, turn_number)`: Computes signals, allocates recruitment budgets, decides on raising armies
  - `decide_and_raise_army(player_id, turn_number)`: Orchestrates the raise army decision and execution
  - `pick_best_raise_region(player_id)`: Selects optimal castle for new army based on recruits and frontier proximity
  - `should_raise_army(candidate, player)`: Global decision logic with guards and scoring
  - `execute_raise_army(player_id, region_id)`: Creates army and deducts cost
- Signals computed: frontier_pressure, underpowered_ratio, castle_spacing, bank_ratio, power_gap_norm
- Integration: `TurnController.start_turn()` constructs `EconomyAIManager` and calls `plan_turn()` at turn start. After movement, `TurnController` calls `plan_post_movement()` to spend any leftover budget on region economy.

- Priority Flow:
  - If any armies at castles need recruitment this turn → allocate recruitment budgets and skip raising/building.
  - Else try to raise an army; if raised → allocate recruitment for the new army and skip region spending.
  - Else defer region economy to post-movement phase.

#### Raise Army AI (implemented)
- Goal: Prefer fewer, stronger armies over many weak ones; raise only when we have support and coverage gaps.
- Decision flow:
  1. `pick_best_raise_region()`: Find best castle with enough recruits (≥ AI_MIN_RECRUITS_FOR_RAISING)
  2. `should_raise_army()`: Normalized model over 4 factors via `ai/RaiseArmyDecision.gd`
  3. `execute_raise_army()`: Create army and deduct cost
- Gates:
  - Recruits: `recruits_total >= AI_MIN_RECRUITS_FOR_RAISING`
  - Gold reserve: `player.gold - RAISE_ARMY_COST >= AI_RESERVE_GOLD_MIN`
- Scoring factors (normalized 0..1):
  - Region/Army ratio within band `[AI_RAISE_R2A_BAND_MIN..MAX]`
  - Average MP distance of armies to candidate castle `[AI_RAISE_DIST_MIN..MAX]`
  - Recruits and Gold (bank) above minimums
  - Weights:`AI_RAISE_W_R2A`, `AI_RAISE_W_DIST`, `AI_RAISE_W_RECRUITS`, `AI_RAISE_W_BANK`
  - Threshold: `AI_RAISE_THRESHOLD_NORM`
- Execution: One raise per turn max, deterministic tie-break by region_id
- Tuning: GameParameters (`AI_RAISE_*` normalized constants) and `ai/RaiseArmyDecision.gd`

## AI & Scoring
- ai/region_scorer.gd: Per-region score (population/resources/level/castle/neighbors/distance). Used for castle placement scoring.
- ai/castle_placement_scorer.gd: Candidate scoring for initial castles with random perturbation.
- **ArmyTargetScorer.gd**: **Single source of truth for army region scoring**. Provides canonical raw scoring APIs:
  - `get_base_region_score_raw(region, player_id)`: Returns raw base sum and components (strategic + population + level + resource, no normalization)
  - `get_resource_component_breakdown_out_of_10(region, player_id)`: Per-resource contributions using simple weighted sum with modifiers (low income × 3, high stockpile × 0.5 for non-gold)
  - `get_final_army_score_raw(army, region_id)`: Returns final_raw = base_raw + random - mp_cost with full breakdown
  - Resource scoring: contrib_r = qty_r × weight_r × modifier_r. FOOD uses net change (income - upkeep), others use income. Both overlay and tooltip use identical breakdown.
- ai/FrontierTargetScorer.gd: **Finder only**. Identifies frontier regions and uses ArmyTargetScorer raw base API for scoring. No longer maintains separate scoring logic.
- ai/ai_debug_visualizer.gd: On-map overlays using raw final scores. Army mode displays raw scores from best army perspective. Uses canonical raw APIs and caches resource breakdown. Shows "base_raw+random-movement" format.
- region_tooltip.gd: Displays same raw final scores and component breakdown as overlay. Shows per-resource breakdown using cached factors or fallback to raw APIs.
- ai/StrategicPointsHeatmap.gd: Computes strategic point centrality (ocean-border shortest-path centrality) before castle placement and can toggle a heatmap overlay with key `8` in debug mode. Stores normalized `strategic_point_score` on every Region in [0..10], where the highest-traffic region gets 10.0. Initializes with `initialize(region_manager, map_generator)`.

## Battle Simulation
- BattleSimulator.gd: Statistical resolution with efficiency and proportional loss distribution.
- AnimatedBattleSimulator.gd: Round-based animated presentation and reporting for the BattleModal.
- BattleModal.gd: Action button switches Withdraw/Continue automatically; message label surfaces withdraw/start/end notices.
- BattleManager.gd: Re-selects victorious human armies automatically, but skips re-selection after withdrawal outcomes.
- BattleSummaryModal.gd: Remaining-unit colors only show red when forces started with troops; zero-initial rows use grey.
- ArmyTargetScorer.gd: Applies enemy memory adjustments (nullifies targets when tracked enemy armies are ≥25% stronger, adds ±1 per 5% difference up to ±10).
- ArmyTargetScorer.gd: Combines stored army and garrison intel; requires known power for every defending army before applying bonuses.
- ArmyTargetScorer.gd: Adds configurable +5 bonus for enemy-owned regions (`GameParameters.AI_ENEMY_REGION_SCORE_BONUS`).
- Withdrawal Rules:
- Attacker (human/AI): May withdraw during battle; human path uses animated withdrawal rounds then returns to the previous region (ArmyManager.retreat_army_to_previous_region). AI attacker uses power-ratio chance (threshold `AI_WITHDRAW_POWER_THRESHOLD`).
- Defender (AI): Before battle starts, performs a power-ratio withdrawal chance check. If successful AND the region has no military building (castle/outpost/keep/stronghold) AND there is at least one owned neighboring region, all defending armies retreat to a random owned neighbor. Garrison stays; battle proceeds versus garrison.
- Defender (human): Withdraw button is disabled when the region has a military building or there are no owned neighboring regions. Current UX retreats defending armies to a random owned neighbor; arrow-based region selection can be added later.

## Input & UI
- click_manager.gd (ClickManager): Mouse input → region hit tests → delegates to GameManager (castle placement, movement via `perform_region_entry`), Select/Region modals, human battle start; ESC deselects army. In editor mode, also hit-tests `Map/Ocean` polygons to select ocean regions. If an army is already selected, clicks prioritize movement to the clicked region, even when friendly armies are present there.
- Movement animation: Army moves animate smoothly using tweens (`Army.animate_move_to`). `ArmyManager.move_army_to_region()` preserves global position across reparenting, computes the stacked target, animates to global target, awaits tween completion, then proceeds (ownership, battle checks, UI). All callers (`GameManager.perform_region_entry`, `ai_travel_to`) await move completion, so no new actions start until the animation ends.
- ui_manager.gd (UIManager): Central UI state; tooltip coordination; modal visibility control; provides PlayerStatusModal. ESC closes any active modal via `close_all_active_modals()`. Treats mountain regions like oceans for tooltip suppression.
- region_tooltip.gd: Shows region information on hover. In debug mode with army target scoring active, displays same scores as overlay using ai_debug_visualizer.get_detailed_scores(). Shows canonical scoring breakdown (base+random-mp) matching overlay display.
- select_tooltip_modal.gd: Tooltip text provider for action buttons. Uses `SelectTooltipModal` when resource costs are shown and `SelectTooltipModalNoRes` for message-only tips.
- Scenes in `scenes/` folder (each with paired script): `army_modal`, `select_modal`, `army_select_modal`, `info_modal`, `region_select_modal`, `region_tooltip`, `battle_modal`, `player_status_modal`, `recruitment_modal`, `call_to_arms_modal`, `transfer_soldiers_modal`, `transfer_select_modal`, `select_tooltip_modal`, `message_modal`, `next_player_modal`.

- F8 Screenshot: `GameManager._unhandled_input(KEY_F8)` calls `Utils.take_screenshot()`. Names file by mode: `res://screenshots/screenshot_<scenario>.png` in scenario mode (from `GameManager.scenario_path`) or `res://screenshots/screenshot_<mapdata>.png` in custom mode (from `MapGenerator.data_file_path`). Camera centers/zooms out, UI hides for capture, then both restore.

- F8 Screenshot: `GameManager._unhandled_input(KEY_F8)` calls `Utils.take_screenshot()`. It centers and zooms out the camera, hides `UI`, captures the viewport, restores `UI` and camera, and saves to `res://screenshots/screenshot.png`.

- Camera Centering: Auto-centers on armies/assets. `CameraController.await_target_reached()` replaces arbitrary delays; `GameManager.ai_travel_to()` awaits camera arrival instead of timers. For human players: `GameManager._on_current_player_changed()` centers on first army or castle, but skips recentering while any battle is active to prevent mid-battle camera jumps.

## Data & Parameters
- Player.gd: resources, name/color/id, afford/pay helpers, serialization.
- ResourceComposition.gd / ArmyComposition.gd: storage and math helpers; food cost, power.
- GameParameters.gd: unit stats and costs, recruitment caps and growth, movement costs, mining/search, castle defense, AI weights, pathfinder/AI constants, icons/scales, peasants-only recruitment parameters (AI_PEA_*), camera timing constants (CAMERA_*).
- Enums (Enums/*.gd): Regions, Levels, Soldiers, Players, Resources, Unit traits, Castle types.

## Static vs Dynamic
- Static nodes: `Map/Regions`, `Map/Ocean`, `Map/Frame`, all UI nodes under `UI`, and `Players/Player1..6` containers.
- Dynamic nodes: `Region` instances under `Map/Regions` (land + ocean; ocean `Polygon` hidden, visuals from `Map/Ocean`), `Army` nodes parented to regions, `Castle` sprites under regions, border/overlay visuals.
- Border widths: In `MapGenerator`, all Line2D borders scale by map size using `Utils.get_map_size_icon_scale()`.
- Icon scaling: Map-size scale uses SMALL as baseline (1.0) to match tuned icon sizes. Mountains intentionally ignore map-size scale and use polygon scale only.
 - Border widths and offsets: In `MapGenerator`, both Line2D widths and offset distances scale by map size (TINY baseline). This keeps double borders (ocean/owned and enemy borders) aligned across sizes.
 - XTINY scale: Uses 2.0 as the current visual scale factor for icons/borders (subject to tuning).

## Notable Relationships
- GameManager wires all managers, creates `TurnController`, and hands references around; UI/battle events flow back through `BattleManager` → `GameManager.finalize_battle_result`.
- Sound: `SoundManager` respects `music_enabled`; `GameManager` does not force-enable music and calls `play_game_start_sequence()` which no-ops when disabled.
- Wounded: Simple wounded system added. `GameParameters.WOUNDED_CHANCE` base chance; per casualty wounded chance is `base * (1 + defense%)`. `Utils.compute_wounded()` calculates wounded per unit type from loss dicts. Wounded are computed exactly once when a battle finishes (modal path computes on finish; background path sets it before finalization). `GameManager.finalize_battle_result()` never computes wounded; it assumes they exist on the report, allocates them proportionally (attackers: attacker army; defenders: across defending armies, garrison, and recruits), then applies losses. `Army` tracks a separate `wounded_composition` excluded from battles but included in food upkeep via `PlayerManagerNode.calculate_total_army_food_cost()`.
  - Storage: `Army.wounded_composition`, `Region.wounded_garrison`, `Region.wounded_recruits` (peasants only).
  - Allocation: Wounded distributed proportionally by availability before losses are applied. Defenders include armies, garrison, and recruits in the proportional distribution.
  - Summary: Battle summary displays total wounded from all sources; loss application removes from active comps/recruits.
- Healing: `GameParameters.CAMP_HEAL_CHANCE` controls healing probability. `Army.make_camp()` calls `heal_army(false)` to attempt healing across all wounded (per-unit chance). `Army.heal_army(force_at_least_one=false)` heals each wounded unit independently by chance; if `force_at_least_one` it guarantees at least one heal when wounded remain. There is no free post-battle heal on defeat or withdrawal; healing occurs only when making camp.
 - Healing: `GameParameters.CAMP_HEAL_CHANCE` controls army healing when camping. There is no free post-battle heal on defeat/withdrawal. At the start of a player's turn, all owned regions fully heal their regional wounded pools: `RegionManager.heal_wounded_for_player(player_id)` moves `Region.wounded_garrison` back into `garrison` and clears `Region.wounded_recruits` (peasants). This is invoked in `GameManager._process_player_turn_start()` before income.
- Ownership Overlays: Creation/update centralized in `MapGenerator`.
  - `create_ownership_overlay(region_id, player_id)`: Creates a new `Polygon2D` named `OwnershipOverlay` with standard alpha; used for scenario setup and neutral conquests.
  - `update_ownership_overlay(region_id, player_id)`: Recolors existing `OwnershipOverlay` without changing alpha; used when conquering non‑neutral regions.
  - `RegionManager.set_region_ownership` calls create for previous owner = -1, update otherwise. Prevents duplicate overlays.
 - InfoModal: Region view shows local garrison total in `Garison -> Value` (sum of region garrison composition; excludes available recruits).
- TurnController owns pathfinder/scorer; calls `GameManager.ai_travel_to` for movement and battle stepping; uses `BudgetManager` and `RecruitmentManager` when armies request reinforcement.
- PlayerManagerNode is the authoritative per-player economy and emits player-change signals used by UI.

### army_manager.gd (ArmyManager)
- Purpose: Army creation, selection, and adjacent-region movement.
- Key: `create_army()`, `move_army()`, `move_army_to_region()`, `reset_all_army_movement_points()`.
- Stacking: `_apply_army_offsets_for_region(region)` repositions all armies in a region to avoid overlap using fixed extra offsets. Applied on create, move (both source and target), and retreat. Pattern: 1st = base; 2nd = x-15/y-10/z-1; 3rd = x-30/y-20/z-2; 4th = x+15/y-10/z-3; 5th = x+30/y-20/z-4; 6th+ same as 1st.
- Logging: After each move, logs `Moved to region <id>, Cost: <mp>, MP left: <left>/<per_turn>`.

## Missing/Added Since Last Map
- Extracted UI modals into separate `.tscn` scenes and instanced in `main.tscn` (previously described as inline).
- New/now-central: `TurnController.gd`, `BattleManager.gd`, `VisualManager.gd`, `BudgetManager.gd`, `BudgetComposition.gd`, `RecruitmentManager.gd`, `PlayerManagerNode.gd`.
