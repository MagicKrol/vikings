# Vikings Strategy Game - Project Map

## Overview
Turn-based strategy game in Godot 4.3 with procedural map, resources, recruitment, movement, and battles for up to 6 players. Architecture emphasizes separation of concerns and SRP.

## Scenes

### main_menu.tscn
- Entry UI. Starts a new game or continues; loads `main.tscn`.

### main.tscn (Primary)
Main (Node2D) [place_armies.gd]
├ Map (Node2D) [map_generator.gd]
│	├ Regions (Node2D) – dynamic `Region` nodes [region.gd]
│	├ Ocean (Node2D)
│	└ Frame (Node2D)
├ Background (Sprite2D)
├ Camera2D [camera_controller.gd]
├ ClickManager (Node) [click_manager.gd]
├ GameManager (Node) [game_manager.gd]
├ SoundManager (Node) [sound_manager.gd]
├ PlayerManager (Node) [PlayerManagerNode.gd]
├ UI (CanvasLayer)
│	├ UIManager (Control) [ui_manager.gd]
│	├ ArmyModal [scenes/army_modal.tscn] [army_modal.gd]
│	├ RegionModal [scenes/region_modal.tscn] [region_modal.gd]
│	├ SelectModal [scenes/select_modal.tscn] [select_modal.gd]
│	├ ArmySelectModal [scenes/army_select_modal.tscn] [army_select_modal.gd]
│	├ InfoModal [scenes/info_modal.tscn] [info_modal.gd]
│	├ RegionSelectModal [scenes/region_select_modal.tscn] [region_select_modal.gd]
│	├ RegionTooltip [scenes/region_tooltip.tscn] [region_tooltip.gd]
│	├ BattleModal [scenes/battle_modal.tscn] [battle_modal.gd]
│	├ PlayerStatusModal [scenes/player_status_modal.tscn] [player_status_modal.gd]
│	├ RecruitmentModal [scenes/recruitment_modal.tscn] [recruitment_modal.gd]
│	├ CallToArmsModal [scenes/call_to_arms_modal.tscn] [call_to_arms_modal.gd]
│	├ TransferSoldiersModal [scenes/transfer_soldiers_modal.tscn] [transfer_soldiers_modal.gd]
│	├ TransferSelectModal [scenes/transfer_select_modal.tscn] [transfer_select_modal.gd]
│	├ SelectTooltipModal [scenes/select_tooltip_modal.tscn] [select_tooltip_modal.gd]
│	├ MessageModal [scenes/message_modal.tscn] [message_modal.gd]
│	└ NextPlayerModal [scenes/next_player_modal.tscn] [next_player_modal.gd]
└ Players (Node2D)
	├ Player1..Player6 (Node2D) – reserved containers

Notes
- UI modals are extracted into separate `.tscn` scenes and instanced under `UI` (no longer inline).
- Regions, armies, castles are created at runtime under `Map/Regions`.

## Core Managers & Flow

### game_manager.gd (GameManager)
- Purpose: High-level orchestration (castle placement, turns, resource ticks, AI start, battle finalization).
- Key: `initialize_managers()`, `next_turn()`, `_process_round_start_actions()`, `_process_player_turn_start()`, `handle_castle_placement()`, `finalize_battle_result(...)`.
- Integrates: RegionManager, ArmyManager, BattleManager, VisualManager, UIManager, PlayerManagerNode, TurnController, AIDebugVisualizer, CastlePlacementScorer.
- AI: Uses `TurnController.start_turn()` for computer players; castle placement uses `CastlePlacementScorer` with randomness.

### TurnController.gd (TurnController)
- Purpose: Unified turn pipeline for AI (and fits human pipeline shape).
- Flow: frontier discovery → target scoring → build candidates → execute with step-gate → handle battle → continue/recalc.
- Signals: `turn_started`, `move_prepared`, `move_started`, `battle_started`, `battle_finished`, `region_conquered`, `turn_finished`.
- Uses: `ArmyPathfinder`, `ArmyTargetScorer`, `BudgetManager` (allocate budgets at turn start), `RecruitmentManager` (hire at castles when requested), `DebugStepGate`.
- Calls back into `GameManager.ai_travel_to()` for step-wise movement and battle triggers.

### BattleManager.gd (BattleManager)
- Purpose: Battle UI coordination and post-battle processing via signals.
- Key: `start_battle()`, `handle_battle_modal_closed()`, emits `battle_finished`; tracks pending conquest; proportional loss application; army defeat/removal.
- Integrates: BattleModal UI, RegionManager (read), ArmyManager (remove/retreat), GameManager (finalization).

### Region systems
- region_manager.gd (RegionManager): ownership map, castle start, neighbor graph, resource generation, level upgrades, turn ticks (population growth, recruit replenish, castle builds, ore search reset), frontier discovery, nearest owned castle search, recruit source aggregation, castle level lookup.
- region.gd (Region): data container with population, resources, recruits, ownership counter, garrison, castle type/upgrade, ore search, movement/passability helpers.

### Army systems
- army_manager.gd (ArmyManager): create/select/move/deselect armies, movement points reset, battle hooks, tracking and cleanup.
- army.gd (Army): movement points, ownership, efficiency (reduce/restore, affects combat), recruitment request/assigned budget, simple power checks.
- ArmyPathfinder.gd / ArmyTargetScorer.gd / ArmyMovementPlanner.gd: pathfinding within MP horizon, target value scoring, multi-turn planning and deconfliction utilities.

### VisualManager.gd (VisualManager)
- Purpose: Place/update/remove castle visuals; create army visuals via ArmyManager; trigger region visual updates.

### PlayerManagerNode.gd (PlayerManagerNode)
- Purpose: Player storage and per-player economy as a scene node.
- Key: initialize players; `current_player_changed` signal; add/remove/afford/pay; per-player income `process_resource_income_for_player()`; total army+garrison food cost; save/load.
- Used by GameManager and TurnController.

### Economy & Recruitment
- BudgetManager.gd: Split player resources among armies at castles that need reinforcement; sets `army.assigned_budget` with `BudgetComposition`.
- BudgetComposition.gd: Simple value holder for gold/wood/iron/available_recruits; afford/check helpers.
- RecruitmentManager.gd: Hire units for an army using ideal-composition logic and neighbor recruit sources; deducts recruits proportionally.

### EconomyAIManager.gd (new)
- Purpose: Central, deterministic planner for AI economy decisions each turn.
- Current Scope: Recruitment budgeting only (compatible with existing flow).
- Future Hooks: raise_army, region_upgrade, castle_upgrade (stubs in place).
- Key: `plan_turn(player_id, turn_number)` computes simple signals, scores categories, picks active ones (recruit), and delegates to `BudgetManager.allocate_recruitment_budgets`.
- Integration: `TurnController.start_turn()` constructs `EconomyAIManager` and calls `plan_turn()` at turn start.

## AI & Scoring
- ai/region_scorer.gd: Per-region score (population/resources/level/castle/neighbors/distance).
- ai/castle_placement_scorer.gd: Candidate scoring for initial castles with random perturbation.
- ai/ai_debug_visualizer.gd: On-map overlays and step-by-step debug toggles.
- AITurnManager.gd, ai/SimplifiedAITurnManager.gd: Legacy/alternative turn processors; not used in main flow since TurnController manages AI.

## Battle Simulation
- BattleSimulator.gd: Statistical resolution with efficiency and proportional loss distribution.
- AnimatedBattleSimulator.gd: Round-based animated presentation and reporting for the BattleModal.

## Input & UI
- click_manager.gd (ClickManager): Mouse input → region hit tests → delegates to GameManager (castle placement, movement via `perform_region_entry`), Select/Region modals, human battle start; ESC deselects army.
- ui_manager.gd (UIManager): Central UI state; tooltip coordination; modal visibility control; provides PlayerStatusModal.
- Scenes in `scenes/` folder (each with paired script): `army_modal`, `region_modal`, `select_modal`, `army_select_modal`, `info_modal`, `region_select_modal`, `region_tooltip`, `battle_modal`, `player_status_modal`, `recruitment_modal`, `call_to_arms_modal`, `transfer_soldiers_modal`, `transfer_select_modal`, `select_tooltip_modal`, `message_modal`, `next_player_modal`.

## Data & Parameters
- Player.gd: resources, name/color/id, afford/pay helpers, serialization.
- ResourceComposition.gd / ArmyComposition.gd: storage and math helpers; food cost, power.
- GameParameters.gd: unit stats and costs, recruitment caps and growth, movement costs, mining/search, castle defense, AI weights, pathfinder/AI constants, icons/scales.
- Enums (Enums/*.gd): Regions, Levels, Soldiers, Players, Resources, Unit traits, Castle types.

## Static vs Dynamic
- Static nodes: `Map/Regions`, `Map/Ocean`, `Map/Frame`, all UI nodes under `UI`, and `Players/Player1..6` containers.
- Dynamic nodes: `Region` instances under `Map/Regions`, `Army` nodes parented to regions, `Castle` sprites under regions, border/overlay visuals.

## Notable Relationships
- GameManager wires all managers, creates `TurnController`, and hands references around; UI/battle events flow back through `BattleManager` → `GameManager.finalize_battle_result`.
- TurnController owns pathfinder/scorer; calls `GameManager.ai_travel_to` for movement and battle stepping; uses `BudgetManager` and `RecruitmentManager` when armies request reinforcement.
- PlayerManagerNode is the authoritative per-player economy and emits player-change signals used by UI.

## Missing/Added Since Last Map
- Extracted UI modals into separate `.tscn` scenes and instanced in `main.tscn` (previously described as inline).
- New/now-central: `TurnController.gd`, `BattleManager.gd`, `VisualManager.gd`, `BudgetManager.gd`, `BudgetComposition.gd`, `RecruitmentManager.gd`, `PlayerManagerNode.gd`.
- Legacy/auxiliary present but not on the main turn path: `AITurnManager.gd`, `ai/SimplifiedAITurnManager.gd`.
