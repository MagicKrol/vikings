# Vikings Strategy Game - Project Map

## Overview
Turn-based strategy game in Godot 4.3 with procedural map, resources, recruitment, movement, and battles for up to 6 players. Architecture emphasizes separation of concerns and SRP.

## Scenes

### main_menu.tscn
- Entry UI. Starts a new game or continues; loads `main.tscn`.
- Map preview panel (`MapPreview/InnerPanel/MapScreenshot`) handles campaign/scenario hovers; a separate CustomMap preview lives in `CustomMap/Panel2/TextureRect` and scales previews to a 450x450 frame (keep-aspect-covered, fit width).
- Custom Map & Scenario submenus share `CustomMap`:
  - Panel (players/difficulty/victory + Select Map) shows for custom maps; Scenario panel shows for scenario list; both Back buttons return to New Game.
  - Player toggles are static scene nodes with defaults: P1 Human, P2-4 Computer, P5-6 Off; difficulty defaults to Normal; victory defaults to Conquer; selection uses default button styling (no font color override).
  - Map/Scenario list (Panel3) uses a scrollable template row (`Map1`) sorted by size (S/M/L) then name; size filter buttons (All/S/M/L) rebuild the list and clear selection.
  - Selecting a row colors it header-gold, updates Panel2 labels (MapName = display name, MapSize = Small/Medium/Large), enables the Select button (text switches to "Start Game"), and loads the preview if available under `previews/<map_or_scenario>.png`.
  - Campaign button now opens the Scenario panel with "Campaign" header, hides Panel3 and shows Panel4 (mission list without size filters), and lists only scenarios named `mission*`; custom map list skips mapdata files starting with `mission`.
  - Scenario/Campaign difficulty buttons are mutually exclusive via a shared ButtonGroup (Normal preselected).
- Menu UX: No click sounds on button presses in main menu.
- Demo Menu: Default visible menu with Tutorial button (loads tutorial.json scenario), Demo Map button (loads demo-999-medium.json custom game with Player 1 human, Players 2-5 computer, Player 6 off), Options and Exit buttons.

Start Flow
- Main menu sets `SceneTree` meta `start_payload` and loads `main.tscn`:
  - Scenario: `{ type: "scenario", scenario_path: res://scenarios/<name>.json }`
- Custom map: `{ type: "map", map_file: res://mapdata/<file>.json, map_size: <small|medium|large|huge>, player_settings: [...] }` (size inferred from filename suffix; new names map internally to legacy values)
- `GameManager._ready()` reads `start_payload`:
  - Scenario: sets `game_mode = "scenario"`, assigns `scenario_path` (pre-load applies scenario map file).
  - Custom map: sets `game_mode = "custom"`, assigns `MapGenerator.data_file_path` and map size via `_map_set_size_from_string`, applies player_settings if present, then `generate_map()`.
  - Payload is cleared after consumption.
- Custom map start shows `MessageModal` prompt "Click a region to choose your starting location" during castle placement.

### main.tscn (Primary)
Main (Node2D) [place_armies.gd]
├ Map (Node2D) [map_generator.gd]
│	├ Regions (Node2D) – dynamic `Region` nodes [region.gd] named `<region_name>#<region_id>` (land polygons tile `background4grass.png` and still rebuild from the stored noisy border points; ocean polygons remain hidden by default)
│	│	└ Borders: `BorderManager` instantiates named Line2D nodes (`OceanBorder@id`, `OwnershipBorder@id`, `InternalBorder@id`) and only adjusts width/color/offset when ownership changes so counts always match adjacency.
│	├ Ocean (Node2D) – metadata-only ocean polygons (hidden visuals)
│	├ Frame (Node2D)
│	├ BorderManager (Node) [border_manager.gd] – centralizes noisy border creation, caches per-edge geometries, preserves ocean strokes (5.2px black) and exposes refresh helpers consumed by MapGenerator/RegionManager; MapEditor now reruns `BorderManager.setup()` (plus the noisy polygon rebuild/overlay sync) whenever a region toggles between land and ocean so the new coastline/borders appear immediately.
│	└ TutorialWorldArrow (Sprite2D) – single world-space tutorial arrow used for region-anchored hints
├ Background (Sprite2D)
├ Camera2D [camera_controller.gd] – handles pan/zoom; shift+left-drag or right-drag pans; wheel zoom; Q/E zoom; R reset; emits camera_moved_by_player and camera_zoomed_by_player during tutorial
├ ClickManager (Node) [click_manager.gd]
├ GameManager (Node) [game_manager.gd]
├ SoundManager (Node) [sound_manager.gd]
├ PlayerManager (Node) [PlayerManagerNode.gd]
├ MapEditor (Node) [map_editor.gd]
├ UI (CanvasLayer)
│	├ UIManager (Control) [ui_manager.gd] – tracks modal visibility list to drive `is_modal_active`, hiding IconsModal/TurnModal whenever any tracked modal is up or a move selection is active; owns tooltip coordination; ClickManager/UIManager now block map clicks from dismissing Prebattle/Battle/BattleSummary modals (buttons only)
│	├ ArmyModal [scenes/army_modal.tscn] [army_modal.gd]
│	├ SelectModal [scenes/select_modal.tscn] [select_modal.gd]
│	├ GeneralSelectModal [scenes/general_select_modal.tscn] [general_select_modal.gd] – fixed-size menu with textured backdrop, themed header, region + army buttons; picking an army now immediately selects it for movement (InfoModal + move arrows/MoveModal)
│	├ ArmySelectModal [scenes/army_select_modal.tscn] [army_select_modal.gd] – same textured layout as region modal; header label with 40px white action buttons (move/camp/transfer/recruit/back); opened from MoveModal's ArmyActions when you cancel a move but still want actions
│	├ GameMenuModal [scenes/game_menu_modal.tscn] [game_menu_modal.gd] – pause overlay using select-modal styling; 60px tall buttons matching other select modals; Continue resumes, Main Menu loads main_menu.tscn, Exit quits, Options disabled placeholder
│	├ InfoModal [scenes/info_modal.tscn] [info_modal.gd]
│	│	└ Uses `themes/standard_text_modal_theme.tres` for body text (#f1d891) and `themes/header_modal_theme.tres` for headers
│	├ RegionSelectModal [scenes/region_select_modal.tscn] [region_select_modal.gd] – fixed-size layout; actions may hide this modal to show MessageModal, then restore on Continue; promotion button enforces the `AI_MIN_FOOD_AFTER_UPGRADE` buffer before enabling and both promotion/raise actions disable once used for that region with the castle-style disabled visuals; Raise Army also locks when the region already hosts `GameParameters.MAX_ARMIES_PER_REGION` armies and the tooltip surfaces the per-turn lock; castle action button only appears when build/upgrade/repair is possible and under-construction text reflects the active build target (fixes Stronghold crash)
│	├ RegionTooltip [scenes/region_tooltip.tscn] [region_tooltip.gd]
│	├ RegionTooltip2 [scenes/region_tooltip2.tscn] [region_tooltip_2.gd] – compact hover panel that now shows a combined Gold/Iron icon with `?` whenever the region can still discover ore (ore attempts left, eligible biome, nothing discovered yet)
│	├ MoveTooltip [scenes/move_tooltip.tscn] [move_tooltip.gd] – hover cost badge shown only during army move target previews (MP text with 20px cursor offset)
│	├ PrebattleModal [scenes/prebattle_modal.tscn] [prebattle_modal.gd] – human-only step after moving into enemy territory; supports siege equipment buying (spends wood + siege points from defender count), shows a Bombard step when trebuchets are purchased (4x50% shots per treb), posts the breach result in the message row, and combines ladder, wall-breach, and gate damage into an assault effectiveness sent to BattleManager; Withdraw refunds purchases and retreats via BattleManager; siege equipment rows use the Info hover panel like Recruitment (Ladders/Rams/Trebuchet); Siege panel shows per-section wall status and per-gate HP bars (ram targeting controls hidden by default); non-castle fights display 100% assault; ladders/rams no longer reduce castle defense pre-battle
│	├ BattleModal [scenes/battle_modal.tscn] [battle_modal.gd] – shares InfoModal standard/header themes for text styling; shows castle defense bonus and colors attacker label with the player color/name; Quick Resolve button drops battle round time to the quick parameter for immediate simulation; non-castle fights always show 100% assault; siege view updates gates/ram assignment each round with dynamic gate assault bonus and per-gate breach rolls (rams/ranged split, scheduled gate/ram damage over the breach duration); siege panel hidden automatically for non-castle battles
│	├ SiegePanel [scenes/siege.tscn] [siege_panel.gd] – shared siege status view used by Prebattle and Battle modals to show wall/gate damage and ram placement from the current siege payload (one active ram per gate; global reserve pool fills empty, intact gates)
│	├ BattleSummaryModal [scenes/battle_summary_modal.tscn] [battle_summary_modal.gd] – uses same InfoModal body/header themes
│	├ TutorialModal [tutorial_modal.tscn] [tutorial_modal.gd] – UI-layer arrows for screen-anchored tutorial hints (Arrow1/Arrow2 placed manually in scene)
│	├ PlayerStatusModal [scenes/player_status_modal.tscn] [player_status_modal.gd]
│	├ PlayerStatusModal2 [scenes/player_status_modal2.tscn] [player_status_modal2.gd] – resource HUD; hides RegionTooltip2 on mouse enter; shows projected next-turn income/pop growth from live state and refreshes via the `player_status_refresh_requested` signal (emitted by GameManager and actions like recruitment, ore search, promotions, castle construction, call to arms, battles, and raise-army); visible at all times in `debug_mode`, otherwise only during human turns outside castle placement
│	├ TurnModal [scenes/turn_modal.tscn] [turn_modal.gd] – turn display; mouse enter hides RegionTooltip2; player label clamps HSV value to 60% with 2px outline
│	├ RecruitmentModal [scenes/recruitment_modal.tscn] [recruitment_modal.gd] – info-modal fonts with +/-10/1 number buttons per unit; sliders removed; unit hover shows stat/trait panel populated from GameParameters/UnitTraitEnum
│	├ CallToArmsModal [scenes/call_to_arms_modal.tscn] [call_to_arms_modal.gd] – transfer-modal layout; region rows use +/-10/1 buttons to shift recruits into target; buttons styled via themes/number_buttons_theme.tres and total row tracks remaining recruits; moved recruits now increase target population so later recruitment doesn’t overdraw population
│	├ TransferSoldiersModal [scenes/transfer_soldiers_modal.tscn] [transfer_soldiers_modal.gd] – transfer buttons move units between army/garrison while keeping each army at ≥1 soldier; labels use standard modal text theme with white value columns like recruitment
│	├ TransferSelectModal [scenes/transfer_select_modal.tscn] [transfer_select_modal.gd] – mirrors select modal layout; header + 40px white buttons for garrison/army targets
│	├ SelectTooltipModal [scenes/select_tooltip_modal.tscn] [select_tooltip_modal.gd]
│	├ SelectTooltipModalNoRes [scenes/select_tooltip_modal_nores.tscn] [select_tooltip_modal_nores.gd] – message-only tooltip
│	├ MessageModal [scenes/intromessage_modal.tscn] [intro_message_modal.gd] – intro/custom-map message overlay; inherits MessageModal behavior (displayMessage/show_tutorial_message, continue_clicked signal)
│	├ NextPlayerModal [scenes/next_player_modal.tscn] [next_player_modal.gd] – shows turn/castle prompt; castle-placement prompt only appears for human players
│	├ MoveModal [scenes/move_modal.tscn] [move_modal.gd] – cancel move UI; hides region tooltip on hover; make-camp button refreshes InfoModal when open and is disabled (ignored) when the army has 0 MP; ArmyActions button cancels move and reopens ArmySelectModal for the selected army; NextArmy button and Tab (while MoveModal is visible) cycle to the player's next army, repainting modals and centering the camera
│	├ IconsModal [scenes/icons_modal.tscn] [icons_modal.gd] – swaps map/scale icon textures on hover; trade icon opens TradeModal
│	├ SpeedModal [scenes/speed_modal.tscn] [scenes/speed_modal.gd] – AI/battle speed selector (normal/fast/very fast); adjusts AI move speed multiplier during map play and battle round timing during sieges; selected option stays visibly pressed via grouped toggle buttons; also shown during battles
│	├ TradeModal [scenes/trade_modal.tscn] [trade_modal.gd] – opens from trade icon; prices start at Food/Wood 2/1, Stone 4/2, Iron 6/3 then adjust by market curve (min 0.4, k=0.01); per-player trade history decays each turn (trade_reset_rate=0.2); buttons adjust buy/sell amounts, update totals/gold delta, and continue applies trades via PlayerManager with status refresh
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
- EditorStart payloads now tag the session as `game_mode="custom"` for raw map editing (clearing any previous scenario names) or `game_mode="scenario"` for scenario editing, so screenshots/previews automatically save under the selected map data or scenario name.

scenes/voronoi_map_generator.tscn (VoronoiMapGenerator)
- Editor tool scene that previews a random Voronoi layout without running the game. Exported slider params: `seed`, `random_seed`, `size`, `noise_frequency`, `noise_octaves`, `noise_gain`, `water_level`, `edge_clear_level`, `elevation_profile`, `hill_split`, and `save_map` (trigger save); changing any triggers auto-regeneration. Save writes `res://mapdata/mapdata-<seed>-medium.json` compatible with `map_generator.gd`.
- Builds color-coded terrain (green flats, brown hills, gray mountains, blue water) inside a 1024x1024 bounds with red site markers; per-site noise tags regions as water vs land, elevation slider shifts mountain heights, hill split controls grass vs hill coverage, and optional edge clearing forces edge-touching regions to water.

## Core Managers & Flow

### game_manager.gd (GameManager)
- Purpose: High-level orchestration (castle placement, turns, resource ticks, AI start, battle finalization).
- Key: `initialize_managers()`, `next_turn()`, `_process_round_start_actions()`, `_process_player_turn_start()`, `handle_castle_placement()`, `finalize_battle_result(...)`.
- Integrates: RegionManager, ArmyManager, BattleManager, VisualManager, UIManager, PlayerManagerNode, TurnController, AIDebugVisualizer, CastlePlacementScorer.
- Debug: `debug_disable_battle_modal` — when true, AI battles run instantly in background (no modal, no delays).
- `debug_mode`: when false, AI turns hide the PlayerStatus panel, IconsModal (trade/map icons), and TurnModal end-turn button (keeps AI HUD minimal).
- Camera: Sets initial zoom by map size at startup (Small=1.0, Medium=1.5, Large=2.0) and clamps zoom-out to 0.5.
- AI memory: Records observed enemy army power for computer players after each battle (5-round decay window via `GameParameters.ENEMY_ARMY_MEMORY_ROUNDS`).
- AI memory: Records observed enemy garrison power when computer armies attack a region (shared 5-round decay window).
- Enemy intel snapshots: `_record_both_sides_power_snapshot()` captures defender forces for the attacker and attacker forces for the defender on early withdrawals; `_record_battle_power_after_resolution()` refreshes both sides' sightings after losses/retreats so AI knowledge stays current.
- Siege sims: `simulate_siege_battle(attacker, region)` runs AI-style siege prep on cloned wall/gate states (no resource spend/state changes) and feeds `BattleSimulator` so AI can judge castle fights during planning; it now uses only known defender intel (tracked armies/garrison); unknown forces are excluded from the sim.
- AI: Uses `TurnController.start_turn()` for computer players; castle placement uses `CastlePlacementScorer` with randomness.
- AI Step Gate: `ai_step_requires_shift` forwards to `DebugStepGate` — when true, AI waits for Shift to advance; false lets AI run automatically.
- AI Logging: Owns `AILogManager`; `ensure_ai_log_started()` names the log `<scenario>_<timestamp>.txt` the first time any AI player takes a turn so all later TurnController events can append to the same file inside the root `logs/` directory.
- Round start caches the average power of all armies each round so AI economy can compare castle garrisons against the global baseline.
- AI Siege: `_execute_ai_siege_preparation()` rolls trebuchets between `(castle_level - 1 - destroyed_walls)` and intact wall sections, reduces by attacker/defender power advantage above 3:1 (defender power = garrison + recruits + owned armies), then clamps by siege points/wood/caps; rams spend random remaining points up to intact gates (respecting caps/wood), ladders take the leftover points. AI fires trebs once before battle (`trebuchet_bombard` payload, no double wall damage) and ships `siege_view_state` with ram HP.
- Castle assault gating: AI castle attacks now run a no-side-effect siege simulation before spending resources; only predicted victories proceed. Simulation logs include siege purchases, assault/defense values, and pre/post compositions.
- Battle Log Queue: `finalize_battle_result()` snapshots attacker/defender forces before and after `_battle_manager._apply_battle_losses()`, converts the result into readable lines (`Battle started`, attacker/defender power/composition, `Battle Result`, post-battle status) and queues them per attacking army via `consume_ai_battle_log_for_army()` so TurnController can append them immediately after its movement logs.
- Initial castle placement (human or AI) now spawns a Keep immediately rather than an Outpost, so every starting stronghold begins at level 2 with the associated recruitment caps and visuals.
- Debug overlay: `show_region_center_markers` draws a small red square at each land region center by calling `MapGenerator.set_center_markers_enabled()` after startup and whenever the map regenerates.
- AI pre-battle withdrawal: before siege prep, AI attackers back out if attacker power ≤ defender power after defense bonus; after siege prep (or for open-field fights) AI withdraws immediately when the standard withdrawal power threshold is met (no roll, no casualties).
- Target scoring: known enemy power (tracked armies + tracked garrison) is checked against the same withdrawal thresholds; regions with stronger known enemies are skipped during frontier target selection.
- Target scoring: known enemy power is adjusted by castle defense and a conservative assault multiplier; castles require a projected ratio > 1.5 to be considered, while open-field targets require > 1.0; pursuit bonuses apply the same castle adjustments.
- Map Editor: `enable_map_editor` flag — when true, skips castle placement/turns, initializes MapEditor, shows empty editor panel (25% left).
 - Modes:
   - Custom: current behavior (castle placement → gameplay).
 - Scenario: set `game_mode="scenario"` and `scenario_path` before start; map is regenerated from scenario `map_file`, managers init, then `ScenarioManager.apply_to_runtime` is called. Skips castle placement and starts the first turn immediately.
 - Scenario resources: `ScenarioManager.apply_to_runtime()` pushes `player_resources` into `PlayerManagerNode.set_player_resources()` before the first turn.
- First turn: `_process_player_turn_start()` skips economy/food for each player the first time it runs so HUD deltas stay `+0`; actual income/upkeep begins when that player starts turn two.
- Famine: `_process_army_food_costs_for_player()` triggers `famine_regions()` when food falls short (1 food deficit = 10 population loss). Starvation reduces region population (floor 30), wipes garrisons at the minimum, and then removes army soldiers proportionally. UI growth indicators read from `Region.get_growth()`.

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
- Movement: Each AI army picks the best single frontier target to attack; if no valid target exists or merge policy halts on a stronger/unknown enemy, it logs defense and spends the turn camping.
- Frontier fallback: when no targets are reachable this turn, the AI now picks the closest distant frontier target (mp_cost) with score as tie-breaker.
- Enemy intel logging: Target lines mark enemies as “known” only when tracked power exists (tracked armies or garrison memory); first-turn unseen enemies remain unknown.
- Recruitment: When no recruit castle is available (or unreachable via friendly-only paths), the army logs the miss and spends the turn camping/defending; recruitment moves route strictly through owned regions (no hostile hops) when heading to a castle or peasant pickup.
- Economy logging: AI log now records castle build/upgrade candidates with scores plus resource gaps and top-up attempts when builds/upgrades are skipped.
- Signals: `turn_started`, `move_prepared`, `move_started`, `battle_started`, `battle_finished`, `region_conquered`, `turn_finished`.
- Uses: `ArmyPathfinder`, `ArmyTargetScorer`, `BudgetManager` (allocate budgets at turn start), `RecruitmentManager` (hire at castles when requested; AI allows instant hire for `just_raised`), `DebugStepGate`.
- AI castle upkeep: `plan_turn()` handles both emergency garrison hires and the final “additional recruitment” pass (threat-weighted) before army movement, so TurnController no longer runs ore searches or garrison spending after movement.
- Wealth tracking: caches start-of-turn resources for AI log headers, writes the final totals after movement, and calls `PlayerManagerNode.update_player_wealth_status()` so every player ends their turn tagged as poor/normal/rich (thresholds in `GameParameters`).
- Battle Logs: After `_log_army_move_result()` records `"Fight at ..."` lines, `_log_recent_battle_details()` pulls the queued summary from `GameManager.consume_ai_battle_log_for_army()` so AI logs show `Battle started`, attacker/defender stats, the result string (`Won/Defeated/Withdrew`), and the post-battle status lines right after the arrival entry; battle log tokens are captured before travel so freed armies can still retrieve their queued entries, and the header uses the actual contested region returned by `ai_travel_to`.
- Recruitment Loop: When an army needs troops, it always finds the best owned castle (logs every candidate with distance/recruits/score), travels there (including current region), and if no budget is available it camps and skips frontier actions until a budgeted hire succeeds.
- Withdrawal Logging: `battle_withdrawal` results note which side withdrew; defender withdrawals are treated as holding the target (no extra movement log), while attacker withdrawals log the retreat destination.
- Post-withdrawal reposition: when an AI army withdraws or loses and still has movement points, it moves to the strongest reachable friendly region within range.
- Calls back into `GameManager.ai_travel_to()` for step-wise movement and battle triggers.
- Reinforcement routing: Armies that need recruitment but have no assigned budget now queue a `goal: reinforce` move toward the best owned castle before chasing frontier targets, so low-power stacks travel home for resupply.
- Castle targeting: When enemy strength is known and the target has a castle, `_build_enemy_info()` triggers `GameManager.simulate_siege_battle()` and `_evaluate_merge_policy()` halts attacks predicted to lose (or withdraw) and proceeds when the sim reports victory.
- Army loop (AI only): per-turn armies are shuffled, then each army loops until MPs are gone — recruitment (must move to best castle; if blocked, camp), then peasant recruitment, then frontier target selection; target choice logs with known/unknown enemy tags, merges local armies when enemy is stronger/unknown, rests vigor to 100% if below 90% before moving, and attacks; if no valid move, the army spends all MPs camping. Enemy unknown → always merge and attack; stronger enemy without enough local power leaves a TODO defense stop.
- Resting Logic (AI): armies rest to 100% vigor before any move if efficiency < 90% (camp until full or MPs run out), and any time no move is possible they burn remaining MPs camping; end-of-turn pass still exhausts leftover MPs with `make_camp()`.
- Peasants-Only Recruitment:
  - Runs only when standard recruitment is not needed, the player has positive net food growth, and the army is below its wealth-adjusted peasant floor (Poor uses the base 20% minimum, Normal halves to 10%, Rich players skip peasants entirely).
  - Targets peasant share based on army power thresholds, scaled by wealth (Poor uses 40%/30%/20%, Normal halves those shares, Rich uses 0%).
  - Filters candidate regions to those with enough recruits to meet the calculated need, then picks the best recruits-per-(distance+1) ratio so nearby pools are favored.
  - If no region can meet the minimum, the army flags for normal castle recruitment; otherwise it moves/hire peasants for free using standard pathfinding within current MPs.
- AI Logging: During AI turns `TurnController` calls `AILogManager` to write the requested log format — each turn header includes resources, signals, decision, and owned regions, while every army action logs as `Recruits`, `Goes to Castle`, or `Moves` with its target plus recruitment/economy success or failure reasons.
- AI log entries now show efficiency inline (`Power: 67, E: 95 - P:...`) so it’s easy to see when armies act below full effectiveness.
- Frontier targeting now logs the top 3 scored candidates (name/id, score, resources/pop/level/castle/pursue/strategy components) before selecting the best attack target.

### BattleManager.gd (BattleManager)
- Purpose: Battle UI coordination and post-battle processing via signals.
- Key: `start_battle()`, `handle_battle_modal_closed()`, emits `battle_finished`; tracks pending conquest; proportional loss application; removes only battle-participant armies reduced to zero (no global scan).
- Integrates: BattleModal UI, RegionManager (read), ArmyManager (remove/retreat), GameManager (finalization).
- Behavior: If `GameManager.debug_disable_battle_modal` is enabled for AI, `start_battle()` simulates instantly via `BattleSimulator` and emits `battle_finished` without showing a modal. AI withdrawal checks include all defenders (armies + garrison + recruits), scale chance from `AI_WITHDRAW_POWER_THRESHOLD` down to forced retreats at `AI_WITHDRAW_MAX_POWER_DIFFERENCE`, and defender armies can retreat pre-battle (each picks a random owned neighbor) which ends the battle immediately.
 - Withdrawal: `BattleSimulator`/`AnimatedBattleSimulator` carry `withdrawing_side` in the BattleReport; `GameManager.finalize_battle_result()` applies retreats based on that. If missing, it falls back to attacker withdrawal.
- Withdrawal destinations ignore owned neighbors already holding five armies.
- Post-battle reselection now mirrors `ArmySelectModal -> Move Army` by clearing `UIManager` modal state so the next region click moves immediately.
- `BattleSimulator.gd` and `AnimatedBattleSimulator.gd`: battle logic now lives entirely in `BattleSimulator` (both background and step-wise sessions); `AnimatedBattleSimulator` drives the UI by consuming session steps and emitting `round_completed`/`battle_finished`/`ai_withdrawal_started`.
- Siege resolution now builds a per-gate plan from a single breach roll (`q` progress) that schedules gate damage over the rolled turns and applies a weighted ram damage queue (failures always chew through assigned rams), logging plan/tick details under the `siege` debug tag. Gate assault ratio now uses destroyed-gate count (live gate HP) instead of the old raw counter, so only fully destroyed gates boost assault effectiveness. Ram damage application treats near-zero HP as destroyed to avoid lingering 1 HP rams from float rounding.
- Breach chance now scales linearly up when assigned archers are below the minimum bucket, instead of clamping down: e.g., with a bucket of 10 and chance 0.50, 2 archers now use chance 0.90 (interpolated toward 1.0 at zero archers as requested).
- Gate assault ratio again uses the legacy raw accumulation: destroyed gates add 5 raw per turn; the gate contribution is raw/non-ranged (no 10% cap) summed with wall/ladder. Per-round ladder/wall/gate totals and gate raw accumulation (`[GateRaw] destroyed=.. added=.. raw_before=.. raw_after=..`) are logged under `siege`. Destroyed gate detection tolerates HP ≤ 0.01.
- Battle/UI: Siege panels now read gate HP as floats (no truncation), so gate progress shows finer-grained percentages instead of 20% steps.
- ArmyTracker logging traces garrison power/army tracking during battle setup and observation updates; conquered regions now clear all tracked garrison intel via `PlayerManagerNode.clear_enemy_garrison_memory()`.

### Region systems
- region_manager.gd (RegionManager): ownership map, castle start, neighbor graph, resource generation, level upgrades, turn ticks (population growth, recruit replenish, castle builds, ore search reset), frontier discovery, recruit source aggregation, castle level lookup. Registers `VisualManager` via `set_visual_manager()` so ownership changes can clear any temporary hover highlights before recoloring overlays. `find_best_recruitment_castle()` returns both the best region id and the scored candidate list, using `(total available recruits from the castle + owned neighbors) / distance * (1 + 0.2 × castle level)`, divides the recruit pool evenly across all armies requesting recruitment at that castle (including the requester) for scoring, and rejects any castle not connected via wholly owned regions when selecting the best target.
- region.gd (Region): data container with population, resources, recruits, ownership counter, garrison, castle type/upgrade, ore search, movement/passability helpers.
	- `apply_population_loss(loss, min_population)` clamps population and recalculates recruits.
	- `heal_all_wounded()` now restores wounded recruits straight into the base recruit pool (pre-ownership modifier) so they heal at turn start without touching population.
	- `fill_recruits_to_maximum()` resets the recruit pool to the region's current cap (used during scenario setup).
	- `apply_siege_damage()` uses `GameParameters.CASTLE_WALLS_GATES` to drive wall/gate counts and per-section HP; gates and walls store individual HP arrays that repairs reset to full; `apply_wall_section_damage()` reduces wall-section HP and reports destroyed/damaged sections without altering the castle defense bonus (single defense value now).
	- Ore search offers three attempts but halts permanently after the first discovery (UI and AI use `can_search_for_ore()` for gating).
	- Tracks per-turn action usage (ore search/raise army/promotion) cleared by `RegionManager.reset_all_ore_search_turn_usage()` at round start.
- Info modal theme uses a `FontVariation` and theme shadow settings for Labels so region stats stay legible over busy backgrounds without outlines.
	- `get_wounded_recruits_total()` exposes the wounded-peasant count for UI consistency.

### RecruitmentManager.gd (RecruitmentManager)
	- Purpose: Builds recruitment plans from ideal compositions, budgets, and recruit caps for armies/garrisons using the same pipeline for simulation and execution.
	- Sandbox helper: `recruitment.py` is now a standalone Gaussian visualizer (Tkinter) that computes weights with sigma=1.6, amplitude=10 (cutting to zero at x≥7) for peasants→royal_guard; mu shifts linearly by gold/recruits (≤0.5 -> 0, ≥5 -> 6), diverts 20-30% of base mass into ranged (archers from x 0-2 mass, crossbowmen from x 3-5 mass), applies a user-selected tier cap (1..5) to zero higher tiers, renders the curve instead of boosts, lists the Y(x) values, and allocates recruits under gold/wood/iron budgets using those weights.
	- RecruitmentManager.gd now mirrors the Gaussian sandbox: no ideals/upgrades/diversity; weights shift by gold/recruits, ranged diversion 20-30%, tier-capped, garrisons block cavalry, and purchases scale weights by gold cost until budgets or recruits exhaust, using GameParameters unit costs/tiers; logs continue via AILogManager.
- Hard caps: Starts from `T` peasants, only converts/upgrades within budget left after that base cost, so total recruited never exceeds the chosen `T`; spending reports use `spent = start - left` for gold/wood/iron.
- Castle tier gating: Ideal mapping and upgrade/burn steps drop unit types above `GameParameters.CASTLE_RECRUITMENT_TIERS` for the current castle, so keeps cannot hire Royal Guards or other over-tier units.
- T chooser tweak: When gold-per-recruit is low, the T picker now gives a small bonus to larger T (quantity) before evaluating diversity/ideal distance; when the ratio rises toward/above 1.0, the bonus fades out so quality spending dominates again.
- Burn-budget guard: Upgrade burn now preserves at least the ideal (rounded) counts for each donor type and skips converting peasants/spearmen when gold-per-recruit is low, keeping cheaper bodies in low-budget situations.
- Scarcity bias window tightened: `RECRUIT_SCARCITY_LOW/HIGH` now 0.5/1.5 gold-per-recruit, so quality bias ramps up as soon as gold/recruits is decent and reaches max when ratio ≥1.5.

### Army systems
- army_manager.gd (ArmyManager): create/select/move/deselect armies, movement points reset, battle hooks, tracking and cleanup.
- army.gd (Army): movement points, ownership, efficiency (reduce/restore, affects combat), recruitment request/assigned budget, simple power checks. Emits `movement_points_changed(army, new_points)` whenever points reset/spent/camped so ArmyManager can refresh highlights. Includes `just_raised` flag (AI-only instant recruitment bypass on first turn; cleared after use) and `get_display_name()` to standardize log/UI labels (falls back to the roman number when the node keeps a default Sprite2D name).
- ArmyManager exposes `transfer_all_soldiers(donor, receiver)` for bulk transfers, and armies keep `spawn_minimal_peasant_token()` so TurnController can leave placeholder peasants after merging stacks.
- ArmyPathfinder.gd: pathfinding within MP horizon, multi-turn pathfinding with MP constraints.
- **ArmyTargetScorer.gd**: **Single source of truth for army region scoring**. Provides canonical raw scoring APIs:
  - `get_base_region_score_raw(region, player_id)`: Returns raw base sum and components (strategic + population + level + resource, no normalization)
  - `get_resource_component_breakdown_out_of_10(region, player_id)`: Per-resource contributions that sum to resource component  
  - `get_final_army_score_raw(army, region_id)`: Returns final_raw = base_raw + random - mp_cost with full breakdown
- ArmyMovementPlanner.gd: High-level army movement coordination using canonical raw final scoring from ArmyTargetScorer. Applies danger penalty as separate adjustment after raw final score.

### VisualManager.gd (VisualManager)
- Purpose: Place/update/remove castle visuals; create army visuals via ArmyManager; trigger region visual updates. Region highlights reuse `animate_region_highlight_on(region_id, params)` / `animate_region_highlight_off(region_id)` for move targets and global hover; movement uses `GameParameters.REGION_ANIM_*` alpha pairs (owned 0.5↔0.75, neutral 0.35↔0.55) with hover alphas (owned 0.85, neutral 0.55). Passing `animated=false` applies map-hover values from `GameParameters.REGION_MAP_HOVER_*` (owned base 0.6→0.7 hover, neutral base 0.2→0.3 hover). `set_map_hover_region()` uses those toned-down values on non-ocean, non-mountain land; movement highlighting remains animated while `_ready_highlight_regions` restores turn-start highlights after hover/move overrides, all animated overlays share a synced tween cycle so new ready regions match existing pulses, and ready-army highlights suspend whenever move-target overlays are shown so only legal destinations animate.
- `clear_interaction_highlights()` drops both move-target pulses and map-hover overlays when UI modals take over (ArmyManager/GameManager/ClickManager call it so contested neutral regions don't keep pulsing after retreats/withdrawals).

### map_editor.gd (MapEditor)
- Purpose: Map editor mode controller for toggling editor UI.
- Key: `initialize()` — shows MapEditorPanel, hides player/turn UI.
- Region edits: `region_type_changed` updates both the in-memory `Region` node and `MapGenerator`'s region dictionaries, then calls `refresh_region_visual()` and reruns `BorderManager.setup()` + the noisy polygon/overlay rebuild helpers so switching between grassland/ocean/forest immediately rebuilds coastlines and removes stale borders without touching `map_generator.gd`.

### map_editor_panel.gd (MapEditorPanel)
- Purpose: Left-hand editor UI for per-region edits, player settings, and persistence.
- Key: `Save Map Data` now resolves the active `MapGenerator.data_file_path` through `_resolve_mapdata_path()` before reading/writing so edits always update `res://mapdata/<file>.json` (modification timestamps change as soon as the button is pressed).

### PlayerManagerNode.gd (PlayerManagerNode)
- Purpose: Player storage and per-player economy as a scene node.
- Key: initialize players; `current_player_changed` signal; add/remove/afford/pay; per-player income `process_resource_income_for_player()` (AI income/resources boosted by `GameParameters.AI_RESOURCE_GROWTH_BONUS` and `AI_INCOME_GROWTH_BONUS`); total army+garrison food cost; `set_player_resources()` for scenario starts; save/load.
- Exposes `get_player_food_growth()` and `meets_food_upgrade_safeguard()` so UI/AI can gate promotions on the required post-upgrade food buffer from `GameParameters.AI_MIN_FOOD_AFTER_UPGRADE`.
- Wealth helpers: `get_player_wealth_level()` / `update_player_wealth_status()` wrap the new gold thresholds so other systems can react to poor/normal/rich states without reimplementing the math.
- Used by GameManager and TurnController.

### Economy & Recruitment
- BudgetManager.gd: Split player resources among armies at castles that need reinforcement; sets `army.assigned_budget` with `BudgetComposition`.
- BudgetComposition.gd: Simple value holder for gold/wood/iron/available_recruits; afford/check helpers.
- RecruitmentManager.gd: Python-inspired recruitment (feasibility-picked T with spend target, ranged/peasants bounds, diversity floor, scarcity bias/boosts, low-gpr quantity bonus) using `GameParameters` exports (`RECRUIT_*`, unit boosts) and per-castle/garrison ideals; simulation and final hire share the same builder so hired counts match the decided `T`, budgets cannot go negative, and spent resources are `start - remaining`.
- PlayerManagerNode.gd: `get_player_economy_snapshot()` aggregates balances, projected income (with food upkeep), and population totals; `get_projected_economy_for_player()` wraps it for compatibility and UI (PlayerStatusModal2) consumption.

### EconomyAIManager.gd
- Purpose: Central, deterministic planner for AI economy decisions each turn.
- Current Scope: Recruitment budgeting and raise army decisions (integrated with existing flow).
- Future Hooks: region_upgrade, castle_upgrade (stubs in place).
- Key Functions:
  - `plan_turn(player_id, turn_number)`: Computes signals, allocates recruitment budgets (and immediately hires armies/garrison defenders), then runs the sequential economy pass (raise → build → upgrade → ore → extra castle recruitment)
  - `perform_garrison_trickle(player_id)`: Adds free garrison units each turn per castle tier (4/6/8/10) weighted by ideal compositions; archers/crossbowmen require positive wood growth, knights/royal guard require positive iron growth, and the free pool is full/half/blocked when the castle garrison is below / up to 125% / above the global average army power cached on round start.
  - `decide_and_raise_army(player_id, turn_number)`: Orchestrates the raise army decision and execution
  - `pick_best_raise_region(player_id)`: Selects optimal castle for new army based on recruits and frontier proximity
  - `should_raise_army(candidate, player)`: Global decision logic with guards and scoring, returns a `score_text` string for AI log output
  - `execute_raise_army(player_id, region_id)`: Creates army and deducts cost
  - `ore_checks(player_id)`: Walks all owned regions once per AI turn and spends gold on `Region.search_for_ore()` whenever the region still has attempts and the player can afford the flat ore search cost
  - `execute_garrison_recruitment(player_id)` / `perform_garrison_trickle(player_id)`: Reuse `RecruitmentManager` so danger-listed castles (step 1) and the final “additional castle recruitment” pass both hire with the same composition logic as armies, feeding `IDEAL_CASTLE_GARRISON_COMPOSITIONS` and respecting leftover gold (only when net food growth is positive)
- Signals computed: frontier_pressure, underpowered_ratio, castle_spacing, bank_ratio, power_gap_norm
- Integration: `TurnController.start_turn()` constructs `EconomyAIManager` and runs `plan_turn()` once per AI turn. The plan now executes a fixed sequence: (1) split all available gold/wood/iron across armies (plus danger castles) for recruitment, (2) attempt to raise armies, (3) build castles, (4) upgrade castles, (5) upgrade regions, (6) perform ore searches, and (7) spend any leftover resources on additional castle recruitment. After this economy pass completes, TurnController proceeds directly to army movement (no separate post-movement budget phase).
- Castle garrison protection: During budget allocation, castles that fall below `SAFE_GARRISON_POWER_PER_LEVEL` and have enemy armies within two hops receive the same BudgetComposition treatment as armies, then pass those budgets to `RecruitmentManager.hire_garrison()` so regions fill toward their `IDEAL_CASTLE_GARRISON_COMPOSITIONS`.
- Garrison upkeep: After AI movement resolves, any surplus gold is split among all owned castles with weights tied to castle tier (outpost..stronghold). Each castle spends its share through the same recruiter as long as the player's projected food change stays positive.

- Priority Flow:
  - If any armies at castles need recruitment this turn → allocate recruitment budgets and skip raising/building.
  - Else try to raise an army; if raised → allocate recruitment for the new army and skip region spending.
  - Else defer region economy to post-movement phase.
- Castle building (post-move): checks Outpost affordability, scans owned regions without castles, scores each as `strategic_heatmap*10 + neighbor_support` (friendly neighbors +15, neutral +5, enemy -10). Candidates below 100 points are rejected. A candidate must also be closer to at least one enemy castle than any current friendly castle (BFS distances cached per map). Winning region starts an Outpost build immediately and the action is reported back for AI logging.
- Castle upgrades: evaluates every owned castle not already upgrading. Score = normalized recruit availability (total recruits from the castle plus neighbors) + normalized proximity to enemy castles. The closest/highest-recruit castle gets 100 per axis; others scale proportionally. The best affordable candidate upgrades to the next tier (Keep → Castle, etc.) while logging the full evaluation list.
- Region upgrades: continuously promotes the best non-max-level regions while the player can afford the promotion cost. Score = (castle level ×2) + population/100 + neighboring friendly castle levels + recruit status bonus (empty +2, partial +1, full −2) − current region level. Every successful promotion logs `"Upgrading <region> to <level> (score: X)"`.
- Region upgrades call `PlayerManagerNode.meets_food_upgrade_safeguard()` so the AI skips promotions that would drop projected food (stock − food cost + growth) below `AI_MIN_FOOD_AFTER_UPGRADE`.

#### Raise Army AI (implemented)
- Goal: Prefer fewer, stronger armies over many weak ones; raise only when we have support and coverage gaps.
- Decision flow:
  1. `pick_best_raise_region()`: Find best castle with enough recruits (≥ AI_MIN_RECRUITS_FOR_RAISING)
  2. `should_raise_army()`: Normalized model over 4 factors via `ai/RaiseArmyDecision.gd`, returns decision + formatted score text for logging
  3. `execute_raise_army()`: Create army and deduct cost
- Gates:
  - Recruits: `recruits_total >= AI_MIN_RECRUITS_FOR_RAISING`
  - Gold reserve: `player.gold - RAISE_ARMY_COST >= AI_RESERVE_GOLD_MIN`
  - Capacity: ignores castles already hosting `GameParameters.MAX_ARMIES_PER_REGION` armies; execution aborts (with gold restored) if a cap race happens mid-action.
- Scoring factors (normalized 0..1):
  - Region/Army ratio within band `[AI_RAISE_R2A_BAND_MIN..MAX]`
  - Average MP distance of armies to candidate castle `[AI_RAISE_DIST_MIN..MAX]`
  - Recruits and Gold (bank) above minimums
  - Weights:`AI_RAISE_W_R2A`, `AI_RAISE_W_DIST`, `AI_RAISE_W_RECRUITS`, `AI_RAISE_W_BANK`
  - Threshold: `AI_RAISE_THRESHOLD_NORM`
- Execution: One raise per turn max, deterministic tie-break by region_id
- Tuning: GameParameters (`AI_RAISE_*` normalized constants) and `ai/RaiseArmyDecision.gd`

## Logging
### AILogManager.gd (AILogManager)
- Purpose: Writes AI-only log files under `logs/<scenario>_<timestamp>.txt` in the project root so each game session has its own text file distinct from standard debug logs.
- API: `start_new_game_log(label)`, `log_turn_intro(turn, player_label, player_id, resources, signals, decision, region_names)`, `log_army_action(name, power, action, target)`, plus helpers for recruitment/economy notes.
- Siege logging: records AI siege equipment purchases with SP available, ladders/rams/trebuchets, and breached/damaged wall sections.
- Format: Turn headers (dashes + `[Turn X]` + ASCII digits) are emitted once per turn, then `[Player Y]` with matching ASCII art, full resource list, `Signals:` (frontier_pressure, underpowered_ratio, castle_spacing, bank_ratio, power_gap_norm), `Decision: ...`, `Regions: ...`, followed by `Army N [Power: Z]: Recruits|Goes to Castle|Moves` with `Target: ...` and recruitment/economy rationales.
- Integration: GameManager creates the logger once per session and exposes it; TurnController logs each AI turn header, army action, recruitment success/failure, peasant hires, and the post-movement economy summary through this manager.

- PlayerManagerNode.set_player_resources(): applies scenario `player_resources` dictionaries to player resource amounts (keys must match ResourcesEnum.type_to_string, e.g., "Food", "Gold").

## AI & Scoring
- ai/region_scorer.gd: Per-region score (population/resources/level/castle/neighbors/distance). Used for castle placement scoring.
- ai/castle_placement_scorer.gd: Candidate scoring for initial castles with random perturbation; weights favor resources/size over safety (safety saturates beyond ~7 tiles).
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
- BattleSimulator.gd: When the `BattleCalculation` debug tag is enabled, each auto-resolved round logs hits and losses per unit type with running totals for both sides.
- BattleSimulator.gd: Finalizes each battle with attacker/defender effectiveness stats (hit % per unit type) whenever `BattleCalculation` logging is enabled.
- AnimatedBattleSimulator.gd: Round-based animated presentation and reporting for the BattleModal.
- BattleModal.gd: Action button switches Withdraw/Continue automatically; message label surfaces withdraw/start/end notices.
- BattleManager.gd: Re-selects victorious human armies automatically, but skips re-selection after withdrawal outcomes.
- BattleManager.gd: Castle defense override now drops per breached wall section (full `trebuchet_damage_to_defense`, half when only damaged) and clamps to the castle’s minimum defense bonus.
- PrebattleModal.gd: Displays castle defense with wall damage applied immediately after trebuchet bombardment (full per destroyed section, half per damaged).
- Siege rams: each has 10 HP and size 10 for ranged targeting; defender ranged fire can hit the active rams (one per gate), destroying them and reassigning reserve rams from a global pool to intact gates; rams return to the reserve when their gate falls.
- SiegePanel: shows active ram HP per gate (progress/percent) using `ram_hp` from siege state; reserves still listed separately.
- AI siege prep: buys siege equipment (trebs/rams/ladders) from siege points/wood, and now fires trebuchet bombard (same shot count/chance as player) before battle when trebs are bought, updating wall damage and assault ratios in the siege payload.
- BattleSummaryModal.gd: Remaining-unit colors only show red when forces started with troops; zero-initial rows use grey.
- Siege trait rules: long spears (1), mobility (3), flanker (4), and charge (5) are ignored whenever a castle is present so siege battles use baseline stats.
- Siege prep: siege points now come only from siege-laborer (trait 8) units; ladders no longer lower castle defense and instead add raw attacker effectiveness (5 each) that scales non-ranged attacker hits during sieges (effectiveness is fixed at battle start based on the attacker’s initial non-ranged count and shown in the prebattle/battle assault labels).
- Armor piercing: subtracts `GameParameters.ARMOR_PIERCING_DEFENSE_REDUCTION` from defender defense chance (floored at 0) before the penetration roll; castle avoidance is applied first.
- Assault effectiveness scales the total pool of non-ranged hits once per assaulting side before distributing targets (no per-unit scaling logs).
- Round totals log kill percentages relative to that side's hits (scaled non-ranged + ranged) for the round.
- ArmyTargetScorer.gd: Applies enemy memory adjustments (nullifies targets when tracked enemy armies are ≥25% stronger, adds ±1 per 5% difference up to ±10).
- ArmyTargetScorer.gd: Combines stored army and garrison intel; requires known power for every defending army before applying bonuses.
- ArmyTargetScorer.gd: Adds configurable +5 bonus for enemy-owned regions (`GameParameters.AI_ENEMY_REGION_SCORE_BONUS`).
 - Withdrawal Rules:
   - Background/instant sims use `BattleSimulator._decide_withdrawal`: per-round checks, attacker power scaled by assault ratio (+0.2 per active ram), defender power scaled by castle defense; forced/roll thresholds use `AI_WITHDRAW_POWER_THRESHOLD` / `AI_WITHDRAW_MAX_POWER_DIFFERENCE`.
   - Animated battles use `AnimatedBattleSimulator._try_start_withdrawal`: non-siege keeps legacy ratio/roll; siege uses trend logic (if attacker ratio ≤ 1.5 withdraws; after round 7, if ratio worsens 3 rounds in a row, attacker withdraws). Checks run each round.
   - Eligibility: attacker auto-withdraw is AI-only; defender auto-withdraw is AI-only, castle must be `NONE`, and at least one defending army with an owned neighboring region (garrison/recruits never withdraw). Human attacker can still click Withdraw; defenders have no button.
   - Resolution: free-hit rounds run in-battle (AnimatedBattleSimulator/BattleSimulator). If attackers withdraw, defenders (armies + garrison) hit them; if defenders withdraw, attackers hit only defender armies (garrison stays). Outcome is `Withdrawal` even if garrison/recruits remain.
   - Manual attacker withdrawal still locks defender auto-withdraw and forces the outcome to attacker withdrawal so retreat happens after free-hit rounds.
- `BattleManager.await_finalize_complete()` lets GameManager pause turn processing until asynchronous battle finalization (camera focus, withdrawals, conquer delays) finishes, so the camera never jumps to the next action mid-animation.
- Withdrawal camera pacing: `GameManager.finalize_battle_result()` now waits for `BattleManager._handle_army_withdrawal()`/`ArmyManager.retreat_army_to_previous_region()` to finish, then the AI camera tracks the retreating army itself instead of the destination region, preventing the extra camera hop reported in logs.
- Debugging: enable `Withdrawal` category in `DebugLogger` to trace human withdraw clicks, simulator decisions, and BattleManager finalization fields.
- Additional withdrawal tracing: AnimatedBattleSimulator logs withdrawal start/rounds/finish; BattleManager logs retreat handling; GameManager logs withdrawal finalization/retreat completion.

## Input & UI
- ESC Key: Opens/closes game menu modal (pauses game) when pressed during gameplay. Not available in map editor mode.
- click_manager.gd (ClickManager): Mouse input → region hit tests → delegates to GameManager (castle placement, movement via `perform_region_entry`), Select/Region modals, human battle start; ESC deselects army. In editor mode, also hit-tests `Map/Ocean` polygons to select ocean regions. If an army is already selected, clicks prioritize movement to the clicked region (ignored when that army has 0 MP) even when friendly armies are present there. Mouse motion feeds `VisualManager` both move-target hover and neutral land hover via the new `set_map_hover_region()`.
- Movement animation: Army moves animate smoothly using tweens (`Army.animate_move_to`). `ArmyManager.move_army_to_region()` preserves global position across reparenting, computes the stacked target, animates to global target, awaits tween completion, then proceeds (ownership, battle checks, UI). All callers (`GameManager.perform_region_entry`, `ai_travel_to`) await move completion, so no new actions start until the animation ends. Retreat/reposition animations now respect the AI Speed modal multiplier (faster when Fast/Very Fast).
- ui_manager.gd (UIManager): Central UI state; tooltip coordination; modal visibility control; polls tracked modals (select/info/move/prebattle/battle/message/trade/recruit/transfer/call-to-arms/next-player/battle summary/game menu) every frame to update `is_modal_active` and hide IconsModal/TurnModal whenever any are visible; remembers the last opened select modal (region vs army) via region_id/army_number so Recruitment / Transfer / Call-To-Arms modals can jump back with `restore_select_context()`. ESC closes any active non-blocking modal; blocking modals (Prebattle/Battle/BattleSummary) remain until their buttons close them. Treats mountain regions like oceans for tooltip suppression. Turn modal visibility is now suppressed while an army is selected for movement (managed via ArmyManager).
- region_tooltip.gd: Shows region information on hover. In debug mode with army target scoring active, displays same scores as overlay using ai_debug_visualizer.get_detailed_scores(). Shows canonical scoring breakdown (base+random-mp) matching overlay display.
- select_tooltip_modal.gd: Tooltip text provider for action buttons. Uses `SelectTooltipModal` when resource costs are shown and `SelectTooltipModalNoRes` for message-only tips.
- Scenes in `scenes/` folder (each with paired script): `army_modal`, `select_modal`, `army_select_modal`, `info_modal`, `region_select_modal`, `region_tooltip`, `battle_modal`, `player_status_modal`, `recruitment_modal`, `call_to_arms_modal`, `transfer_soldiers_modal`, `transfer_select_modal`, `select_tooltip_modal`, `message_modal`, `next_player_modal`, `game_menu_modal`. Recruitment / TransferSoldiers / CallToArms Continue buttons now close themselves, drop modal mode, then ask UIManager to reopen the stored select modal context automatically.
		- game_menu_modal.gd: In-game menu accessed via ESC key; pauses game. Main menu provides Continue (resume), Options, Main Menu (return to main menu), and Exit Game (quit). Options submenu has Back and Audio buttons. Audio submenu has Back button and audio panel with Music/Sound toggles (CheckButton) and volume sliders (HSlider 0-100) that sync with SoundManager state.
		- trade_modal.gd: UI-only; delegates pricing/affordability to TradeManager and applies trades through it.
		- TradeManager.gd: Centralizes trade math (dynamic pricing, affordability, batch apply) with simple `buy`/`sell` helpers; updates player resources, gold, traded volumes, and emits player status refresh.
		- call_to_arms_modal.gd: Uses `Region.add_call_to_arms_recruits()` so gathered recruits add to population and can exceed the previous recruit cap in the target region.
		- general_select_modal.gd: Region button is disabled on the conquest turn (ownership counter 0) with tooltip “Conquered region cannot be managed the same turn.”
		- click_manager.gd: Clicking an owned region with ownership counter 0 (and no armies) shows a message modal instead of RegionSelectModal.
		- tutorial_manager.gd / tutorial_modal.gd: Data-driven tutorial steps (welcome message → click castle with world-anchored arrow under `Map/TutorialWorldArrow` → choose army with screen-anchored Arrow2 under `UI/TutorialModal`); arrows are pre-placed and toggled per step while clicks/UI actions are gated to the expected target; BattleModal now pings TutorialManager on battle completion so a step can advance when fights end; tutorial completion restores modal-active state so open modals can be dismissed normally.
		- ui_manager.gd: Central UI state with modal tracking and tooltip routing.

- F8 Screenshot: `GameManager._unhandled_input(KEY_F8)` calls `Utils.take_screenshot()`. Names file by mode: `res://screenshots/screenshot_<scenario>.png` in scenario mode (from `GameManager.scenario_path`) or `res://screenshots/screenshot_<mapdata>.png` in custom mode (from `MapGenerator.data_file_path`). Camera centers/zooms out, UI hides for capture, then both restore.

- F8 Screenshot: `GameManager._unhandled_input(KEY_F8)` calls `Utils.take_screenshot()`. It centers and zooms out the camera, hides `UI`, captures the viewport, restores `UI` and camera, and saves to `res://screenshots/screenshot.png`.

- Camera Centering: Auto-centers on armies/assets. `CameraController.await_target_reached()` replaces arbitrary delays; `GameManager.ai_travel_to()` awaits camera arrival instead of timers. For human players: `GameManager._on_current_player_changed()` centers on first army or castle, but skips recentering while any battle is active to prevent mid-battle camera jumps.

## Data & Parameters
- Player.gd: resources, name/color/id, afford/pay helpers, serialization, plus a per-player `wealth_level` flag (poor/normal/rich) that TurnController updates at the end of each turn so recruitment logic can read each player's current tier.
- ResourceComposition.gd / ArmyComposition.gd: storage and math helpers; food cost, power.
- GameParameters.gd: unit stats and costs, recruitment caps and growth, movement costs, mining/search, castle defense, AI weights, pathfinder/AI constants, icons/scales, peasants-only recruitment parameters (AI_PEA_*), camera timing constants (CAMERA_*), and the new wealth thresholds + composition tables used to pick poor/normal/rich army and garrison mixes.
- Enums (Enums/*.gd): Regions, Levels, Soldiers, Players, Resources, Unit traits, Castle types.
- Wealth scaling: GameParameters’ peasant ratios shrink by wealth tier (Normal halves, Rich zeroes) across army/garrison ideal compositions and the AI peasants-only min/target proportions so richer players favor pricier units automatically.

## Static vs Dynamic
- Static nodes: `Map/Regions`, `Map/Ocean`, `Map/Frame`, all UI nodes under `UI`, and `Players/Player1..6` containers.
- Dynamic nodes: `Region` instances under `Map/Regions` (land + ocean; ocean `Polygon` hidden, visuals from `Map/Ocean`), `Army` nodes parented to regions, `Castle` sprites under regions, border/overlay visuals.
- Border widths: In `MapGenerator`, all Line2D borders scale by map size using `Utils.get_map_size_icon_scale()`.
- Icon scaling: Map-size scale uses SMALL as baseline (1.0) to match tuned icon sizes. Mountains ignore map-size scale, match the closest aspect-ratio variant, and fit their dominant dimension to the region bounds while clamping to the smaller dimension.
- RegionIconManager.gd: MapGenerator delegates all biome icon placement here; it randomizes hill/forest/hill_forest variants (`<biome>_1..3.png`), offsets standard icons, and picks the mountain sprite with the nearest proportions before fitting it inside the region; internal-mountain detection from `MapGenerator` is kept for potential scaling adjustments but currently applies a neutral 1.0 multiplier.
- Starting armies use `GameParameters.STARTING_ARMY_COMPOSITION_HUMAN`/`_AI` selected through `GameManager.get_starting_army_composition_for_player()` and passed into `Army.setup_army()`.
 - Border widths and offsets: In `MapGenerator`, both Line2D widths and offset distances scale by map size (TINY baseline). This keeps double borders (ocean/owned and enemy borders) aligned across sizes.
 - XTINY scale: Uses 2.0 as the current visual scale factor for icons/borders (subject to tuning).
- Center markers: `MapGenerator.set_center_markers_enabled(true)` adds a `CenterMarkers` Node2D full of small red Polygon2D squares at each non-ocean region center (used by the GameManager debug toggle).
- Polygon centroids: Every time MapGenerator loads JSON or BorderManager rebuilds noisy polygons it recomputes the centroid for each region polygon (shoelace method with degenerate average fallback), stores it back into `region_by_id`, pushes it into `Region.center`, and writes it to each Polygon2D’s `center` metadata so castles/armies/icons/debug dots always anchor to the real geometric center instead of stale JSON values.
- Mountain adjacency: BorderManager skips drawing internal borders when both touching regions are mountains so mountain ranges remain uninterrupted visual blobs.
- Mountain icon layering: After every icon pass MapGenerator reorders all mountain sprites (marked via `mountain_icon` metadata) by their region center Y and assigns strictly increasing z-indexes so upper mountains render behind lower ones.

## Notable Relationships
- GameManager wires all managers, creates `TurnController`, and hands references around; UI/battle events flow back through `BattleManager` → `GameManager.finalize_battle_result`.
- Sound: `SoundManager` respects `music_enabled`; `GameManager` does not force-enable music and calls `play_game_start_sequence()` which no-ops when disabled. Retreat horn (`sounds/retreat_horn.mp3`) plays via `SoundManager.play_retreat_horn()` whenever BattleModal shows a withdrawal message. Battle sound (`sounds/battle.wav`) plays at 50% volume through `SoundManager.play_battle_sound()` when BattleModal opens.
- Sound players run with `PROCESS_MODE_ALWAYS` so opening the in-game menu (tree pause) does not stop music/SFX.
- Music playlists: `SoundManager` hosts `Playlist` (tracks + shuffle + repeat) and predefined `PLAYLIST_DEFS` with a tutorial playlist (`track2.mp3`, then `track1.mp3`, no shuffle, repeats) and a custom-map playlist (`track1.mp3`–`track7.mp3`, shuffle on, repeat). `GameManager` activates the tutorial playlist when tutorial mode is enabled and the custom-map playlist whenever game mode is custom; the music player advances through the playlist on the `AudioStreamPlayer.finished` signal, looping from the start.
- Wounded: Simple wounded system added. `GameParameters.WOUNDED_CHANCE` base chance; per casualty wounded chance is `base * (1 + defense%)`. `Utils.compute_wounded()` calculates wounded per unit type from loss dicts. Wounded are computed exactly once when a battle finishes (modal path computes on finish; background path sets it before finalization). `GameManager.finalize_battle_result()` never computes wounded; it assumes they exist on the report, allocates them proportionally (attackers: attacker army; defenders: across defending armies, garrison, and recruits), then applies losses. `Army` tracks a separate `wounded_composition` excluded from battles but included in food upkeep via `PlayerManagerNode.calculate_total_army_food_cost()`.
  - Storage: `Army.wounded_composition`, `Region.wounded_garrison`, `Region.wounded_recruits` (peasants only).
  - Allocation: Wounded distributed proportionally by availability before losses are applied. Defenders include armies, garrison, and recruits in the proportional distribution.
  - Summary: Battle summary displays total wounded from all sources; loss application removes from active comps/recruits.
- Healing: `GameParameters.CAMP_HEAL_CHANCE` controls healing probability. `Army.make_camp()` calls `heal_army(false)` to attempt healing across all wounded (per-unit chance). `Army.heal_army(force_at_least_one=false)` heals each wounded unit independently by chance; if `force_at_least_one` it guarantees at least one heal when wounded remain. There is no free post-battle heal on defeat or withdrawal; healing occurs only when making camp.
 - Healing: `GameParameters.CAMP_HEAL_CHANCE` controls army healing when camping. There is no free post-battle heal on defeat/withdrawal. At the start of a player's turn, all owned regions fully heal their regional wounded pools: `RegionManager.heal_wounded_for_player(player_id)` moves `Region.wounded_garrison` back into `garrison` and clears `Region.wounded_recruits` (peasants). This is invoked in `GameManager._process_player_turn_start()` before income.
- Ownership Overlays: Creation/update centralized in `MapGenerator`. Every non-ocean region always carries an `OwnershipOverlay`; neutral ownership keeps it fully transparent rather than removing it so highlight/tween logic can reuse it (existing tinted overlays are preserved).
  - `create_ownership_overlay(region_id, player_id)`: Ensures the overlay exists, syncs the noisy polygon, and applies the player tint (alpha 0.4).
  - `update_ownership_overlay(region_id, player_id)`: Recolors existing `OwnershipOverlay` without changing alpha; used when conquering non‑neutral regions.
  - `remove_ownership_overlay(region_id)`: Resets overlay color to transparent neutral black (keeps node alive for reuse).
  - `RegionManager.set_region_ownership` still calls create for previous owner = -1, update otherwise; neutralizing a region routes through `remove_ownership_overlay`.
 - InfoModal: Region view shows local garrison total in `Garison -> Value` (sum of region garrison composition; excludes available recruits).
- TurnController owns pathfinder/scorer; calls `GameManager.ai_travel_to` for movement and battle stepping; uses `BudgetManager` and `RecruitmentManager` when armies request reinforcement.
- PlayerManagerNode is the authoritative per-player economy and emits player-change signals used by UI.
 - AI camera pacing: `GameManager` routes AI actions (castle placement, move steps, battle resolution) through `AICameraDirector` to enforce pre-action and post-action waits; camera snaps instantly to targets and all AI camera delays scale down with the AI Speed modal when set above Normal.

### army_manager.gd (ArmyManager)
- Purpose: Army creation, selection, and adjacent-region movement.
- Key: `create_army()`, `move_army()`, `move_army_to_region()`, `reset_all_army_movement_points()`.
- Capacity: `GameParameters.MAX_ARMIES_PER_REGION = 5` enforced on creation/movement helpers (`is_region_at_army_cap`, `get_armies_in_region`, `get_army_count_in_region`) so UI/AI respect the stack limit.
- Stacking: `_apply_army_offsets_for_region(region)` repositions all armies in a region to avoid overlap using fixed extra offsets. Applied on create, move (both source and target), and retreat. Pattern: 1st = base; 2nd = x-15/y-10/z-1; 3rd = x-30/y-20/z-2; 4th = x+15/y-10/z-3; 5th = x+30/y-20/z-4; 6th+ same as 1st.
- Ready highlight: Caches `_ready_highlight_player_id`, listens to `Army.movement_points_changed`, and refreshes `VisualManager.update_ready_army_highlights()` on turn start, move/camp MP spend, resets, and army removal.
- Retreat Support: `get_previous_region_for_army()` exposes the last region so cameras can focus on withdrawal destinations.
- Raised armies now spawn with 1 peasant token (set in `Army.setup_raised_army`) to avoid empty stacks on creation.

### ai_camera_director.gd (AICameraDirector)
- Purpose: Coordinates AI camera focus and timing around the shared `CameraController`.
- Key: `await_focus_on_army()`, `await_focus_on_region()`, `await_delay()`.
- `GameManager` uses it to wrap AI castle placement, movement steps, and battle resolution with the configured pre/post waits.

## Missing/Added Since Last Map
- Extracted UI modals into separate `.tscn` scenes and instanced in `main.tscn` (previously described as inline).
- New/now-central: `TurnController.gd`, `BattleManager.gd`, `VisualManager.gd`, `BudgetManager.gd`, `BudgetComposition.gd`, `RecruitmentManager.gd`, `PlayerManagerNode.gd`.
