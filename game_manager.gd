extends Node
class_name GameManager

signal player_status_refresh_requested
signal spawn_event_target_selected(region_id: int)

# ============================================================================
# GAME MANAGER
# ============================================================================
# 
# Purpose: Central game state coordination and high-level game flow management
# 
# Core Responsibilities:
# - Game state management (turns, players, game modes)
# - Manager initialization and dependency injection
# - High-level game flow coordination (castle placement, conquest)
# - Turn management and resource processing
# 
# Required Functions:
# - next_turn(): Process turn advancement and updates
# - initialize_managers(): Set up all game systems
# - handle_castle_placement(): Coordinate castle placement flow
# - get/set game state: Access to current turn, player, mode
# 
# Integration Points:
# - PlayerManager: Resource and player state management
# - All other managers: Initialization and coordination
# - UI systems: Game state updates and notifications
# ============================================================================

# Game state
var current_turn: int = 1
var current_player: int = 1
var total_players: int = 6

# Player type management (up to 6 players)
var player_types: Array[PlayerTypeEnum.Type] = [
	PlayerTypeEnum.Type.HUMAN,   # Player 1 - Computer (temporarily for testing)
	PlayerTypeEnum.Type.COMPUTER,   # Player 2 - Computer
	PlayerTypeEnum.Type.COMPUTER,   # Player 3 - Computer
	PlayerTypeEnum.Type.COMPUTER,   # Player 4 - Computer
	PlayerTypeEnum.Type.OFF,   # Player 5 - Computer
	PlayerTypeEnum.Type.OFF    # Player 6 - Computer
]


# Turn management
var players_per_round: Array[int] = [1, 2, 3, 4, 5, 6]  # Sequence: Player 1, 2, 3, 4, 5, 6

# Game mode state
var castle_placing_mode: bool = true
var castle_placement_order: Array[int] = []  # Track castle placement order
var castles_placed: int = 0

# Army placement settings
var armies_per_castle: int = 3  # Configurable - can be adjusted for difficulty/scenario

# Player management
var player_manager: PlayerManagerNode

# Manager references
var _region_manager: RegionManager
var _army_manager: ArmyManager
var _active_battles: int = 0
var _battle_manager: BattleManager
var _visual_manager: VisualManager
var _border_manager: BorderManager
var _ui_manager: UIManager
var _trade_manager: TradeManager
var _tutorial_manager: TutorialManager
var _ai_camera_director: AICameraDirector
var _message_modal: MessageModal
var _event_message_modal: EventMessageModal
var _intro_message_modal: IntroMessageModal
var ai_step_requires_shift: bool = false

# AI system references
var _ai_region_scorer: RegionScorer
var _ai_castle_placement_scorer: CastlePlacementScorer
var _ai_debug_visualizer: AIDebugVisualizer

# New unified turn system
var _turn_controller: TurnController

# AI debugging state is now handled by TurnController

# Modal references  
var _battle_modal: BattleModal
var _prebattle_modal: PrebattleModal

# Debug: disable AI battle modal and run instant background battles
var debug_disable_battle_modal: bool = true
var debug_heatmap: bool = false
@export var debug_mode: bool = true
@export var show_region_center_markers: bool = false
var _next_player_modal: NextPlayerModal
var _game_menu_modal: Control
var _save_game_modal: SaveGameModal
var _sound_manager: SoundManager
var tutorial_enabled: bool = false
# Map editor mode state
var enable_map_editor: bool = false  # Configurable flag to enable map editor mode


# References to other managers
var click_manager: Node = null

const FAMINE_POINTS_PER_FOOD: float = 10.0
const FAMINE_POINTS_LOOKUP_BY_ROLL: Array[int] = [5, 7, 9, 13, 16, 16, 13, 9, 7, 5]
const DOMINATE_DEFAULT_THRESHOLD: float = 0.75
const DEBUG_LANGUAGE_CYCLE: Array[String] = ["en", "de", "pl", "br"]
const MAIN_MENU_TARGET_META_KEY: String = "main_menu_target"
const MAIN_MENU_TARGET_CAMPAIGN_LIST: String = "campaign_list"
const CAMPAIGN_OUTRO_KEY_TEMPLATE: String = "mission-%d_outro"

var _player_initial_turn_completed: Dictionary = {}
var _latest_famine_result_by_player: Dictionary = {}

# Scenario mode
var game_mode: String = "scenario"  # "custom" | "scenario"
var scenario_path: String = ""
# var scenario_path: String = "battle_test.json"
var loaded_scenario_name: String = ""  # Track the loaded scenario name for the editor
var _loaded_from_save: bool = false
var _pending_loaded_save_data: Dictionary = {}
var _ai_log_manager: AILogManager = AILogManager.new()
var _turn_advance_in_progress: bool = false
var _ai_log_started: bool = false
var _ai_battle_log_queue: Dictionary = {}
var average_army_power: float = 0.0
var victory_conditions: Array[Dictionary] = []
var victory_declared: bool = false
var winning_player_id: int = -1
var _scenario_events_runtime: Array[Dictionary] = []
var scenario_trade_disabled: bool = false
var _player_hired_units: Dictionary = {}
var game_difficulty: int = GameParameters.GAME_DIFFICULTY_DEFAULT
var _spawn_event_placement_active: bool = false
var _spawn_event_placement_army: Army = null
var _spawn_event_allowed_target_ids: Array[int] = []
var _spawn_event_source_region_by_target: Dictionary = {}
var _spawn_event_pending_event_index: int = -1

func _ready():
	# If EditorStart provided a payload, force-enable editor mode
	if get_tree().has_meta("editor_start_payload") and get_tree().get_meta("editor_start_payload") != null:
		enable_map_editor = true
	_set_victory_conditions_from_raw([])
	_scenario_events_runtime.clear()
	scenario_trade_disabled = false
	_reset_player_hired_units_tracking()
	_spawn_event_placement_active = false
	_spawn_event_placement_army = null
	_spawn_event_allowed_target_ids.clear()
	_spawn_event_source_region_by_target.clear()
	_spawn_event_pending_event_index = -1

	# Early init gate: check if map editor is enabled BEFORE normal init
	if enable_map_editor:
		DebugLogger.log("GameInit", "Map editor mode enabled")
		# If no editor start payload, jump to EditorStart scene first
		if not get_tree().has_meta("editor_start_payload") or get_tree().get_meta("editor_start_payload") == null:
			DebugLogger.log("GameInit", "Opening EditorStart scene for selection")
			# Defer scene change to avoid remove_child during initialization
			get_tree().call_deferred("change_scene_to_file", "res://scenes/editor_start.tscn")
			return
		# Otherwise, proceed to initialize editor inside main scene
		_initialize_map_editor()
		return

	# Main menu start payload (scenario/custom)
	if get_tree().has_meta("start_payload") and get_tree().get_meta("start_payload") != null:
		var payload = get_tree().get_meta("start_payload")
		var kind := String(payload.get("type", ""))
		var map_generator: MapGenerator = get_node("../Map") as MapGenerator
		if kind == "scenario":
			game_mode = "scenario"
			scenario_path = String(payload.get("scenario_path", ""))
			game_difficulty = GameParameters.game_difficulty_from_string(String(payload.get("difficulty", "normal")))
		elif kind == "map":
			game_mode = "custom"
			scenario_path = ""
			game_difficulty = GameParameters.game_difficulty_from_string(String(payload.get("difficulty", "normal")))
			var map_path := String(payload.get("map_file", ""))
			var size_str := String(payload.get("map_size", "small"))
			map_generator.data_file_path = map_path.get_file()
			_map_set_size_from_string(map_generator, size_str)
			
			# Apply player settings from CustomMap
			if payload.has("player_settings"):
				_apply_custom_map_player_settings(payload.get("player_settings"))
			_initialize_victory_conditions_from_custom_payload(payload)
			
			map_generator.generate_map()
		elif kind == "save":
			var save_path: String = String(payload.get("save_path", SaveGameManager.SAVE_FILE_PATH))
			var save_data: Dictionary = SaveGameManager.load_game_from_path(save_path)
			if not save_data.is_empty():
				_loaded_from_save = true
				_pending_loaded_save_data = save_data
				_prepare_loaded_game_source(save_data, map_generator)
		# Clear payload to avoid reuse
		get_tree().set_meta("start_payload", null)

	# Scenario pre-load: if scenario mode, set map file upfront and regenerate map
	if not _loaded_from_save and game_mode == "scenario" and scenario_path != "":
		var map_generator: MapGenerator = get_node("../Map") as MapGenerator
		# Normalize scenario path to res://scenarios/<file>
		var scen_file := String(scenario_path).get_file()
		var scen_full := "res://scenarios/" + scen_file
		var scen := ScenarioManager.new().load_scenario(scen_full)
		_initialize_victory_conditions_from_scenario_data(scen)
		if scen.has("map_file"):
			# Expect bare filename; normalize to file name
			var map_file_only := String(scen.get("map_file")).get_file()
			map_generator.data_file_path = map_file_only
			# Infer map size from filename suffix and apply before generating
			var base := map_file_only.get_basename()
			var parts := base.split("-")
			if parts.size() >= 3:
				var size_str := parts[parts.size() - 1]
				_map_set_size_from_string(map_generator, size_str)
			map_generator.generate_map()

	# Initialize all game systems
	initialize_managers(game_mode == "scenario" and not _loaded_from_save, _loaded_from_save)
	if _loaded_from_save:
		SaveGameManager.apply_save_data(self, _pending_loaded_save_data)
		_pending_loaded_save_data = {}
	_apply_initial_camera_zoom()
	_apply_center_marker_setting()
	_show_custom_start_prompt()

	if tutorial_enabled:
		_sound_manager.set_active_playlist("tutorial")
	
	# Intro horn is handled on IntroMessageModal Continue click.

func initialize_managers(is_scenario: bool = false, skip_initial_flow: bool = false):
	"""Initialize all game managers and establish dependencies"""
	# Get core components - these are required
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	if not map_generator.map_generated.is_connected(_on_map_generated):
		map_generator.map_generated.connect(_on_map_generated)
	_border_manager = map_generator.border_manager
	_border_manager.refresh_all_borders()
	
	# Initialize core managers directly
	_region_manager = RegionManager.new(map_generator)
	if _region_manager == null:
		push_error("[GameManager] CRITICAL: Failed to create RegionManager")
		return
		
	_army_manager = ArmyManager.new(map_generator, _region_manager)
	if _army_manager == null:
		push_error("[GameManager] CRITICAL: Failed to create ArmyManager")
		return
	_region_manager.set_army_manager(_army_manager)
	
	# Find the click manager and provide it with manager references
	click_manager = get_node("../ClickManager")
	# Provide managers to ClickManager for backward compatibility
	if click_manager.has_method("set_managers"):
		click_manager.set_managers(_region_manager, _army_manager)
	
	# Get UI components
	var ui_node = get_node("../UI")
	_battle_modal = ui_node.get_node("BattleModal") as BattleModal
	_prebattle_modal = ui_node.get_node("PrebattleModal") as PrebattleModal
	_next_player_modal = ui_node.get_node("NextPlayerModal") as NextPlayerModal
	if not _next_player_modal.continue_acknowledged.is_connected(_on_next_player_modal_continue_acknowledged):
		_next_player_modal.continue_acknowledged.connect(_on_next_player_modal_continue_acknowledged)
	_game_menu_modal = ui_node.get_node("GameMenuModal") as Control
	_save_game_modal = ui_node.get_node("SaveGameModal") as SaveGameModal
	_message_modal = ui_node.get_node("MessageModal") as MessageModal
	_event_message_modal = ui_node.get_node("EventMessageModal") as EventMessageModal
	_intro_message_modal = ui_node.get_node("IntroMessageModal") as IntroMessageModal
	if _game_menu_modal:
		_game_menu_modal.connect("main_menu_pressed", _on_game_menu_main_menu_pressed)
		_game_menu_modal.connect("exit_pressed", _on_game_menu_exit_pressed)
		_game_menu_modal.connect("load_game_pressed", _on_game_menu_load_game_pressed)
		_game_menu_modal.connect("save_game_pressed", _on_game_menu_save_game_pressed)
	_save_game_modal.back_requested.connect(_on_save_game_modal_back_requested)
	_save_game_modal.action_requested.connect(_on_save_game_modal_action_requested)
	_ui_manager = ui_node.get_node("UIManager") as UIManager
	var tutorial_modal = get_node("../UI/TutorialModal") as TutorialModal
	var tutorial_world_arrow = get_node("../Map/TutorialWorldArrow") as Sprite2D
	var tutorial_camera = get_node("../Camera2D") as Camera2D
	if tutorial_modal:
		tutorial_modal.set_camera(tutorial_camera)
		tutorial_modal.set_world_arrow(tutorial_world_arrow)
	
	# Connect UI components to ArmyManager
	var army_modal = ui_node.get_node("InfoModal") as InfoModal
	var move_modal = ui_node.get_node("MoveModal") as MoveModal
	if _army_manager:
		_army_manager.set_army_modal(army_modal)
		_army_manager.set_battle_modal(_battle_modal)
		_army_manager.set_move_modal(move_modal)
		_army_manager.set_ui_manager(_ui_manager)
	
	_sound_manager = get_node("../SoundManager") as SoundManager
	SaveGameManager.load_settings(_sound_manager)
	var runtime_clouds: Clouds = get_node("../Map/Clouds") as Clouds
	runtime_clouds.set_clouds_enabled(Clouds.is_global_clouds_enabled())
	
	# Connect sound manager to ArmyManager
	if _army_manager:
		_army_manager.set_sound_manager(_sound_manager)
	
	# Initialize specialized managers
	_battle_manager = BattleManager.new(_region_manager, _army_manager, _battle_modal, _sound_manager)
	_battle_manager.set_game_manager(self)
	_battle_manager.battle_started.connect(_on_battle_started)
	_battle_manager.battle_finished.connect(_on_battle_finished)
	_visual_manager = VisualManager.new(map_generator, _region_manager, _army_manager)
	_region_manager.set_visual_manager(_visual_manager)
	_army_manager.set_visual_manager(_visual_manager)
	
	# Get the PlayerManager node FIRST before initializing other systems that depend on it
	DebugLogger.log("GameInit", "Looking for PlayerManager node at path: ../PlayerManager")
	var player_manager_node = get_node("../PlayerManager")
	DebugLogger.log("GameInit", "Found node: " + str(player_manager_node) + " (" + type_string(typeof(player_manager_node)) + ")")
	
	player_manager = player_manager_node as PlayerManagerNode
	if player_manager:
		DebugLogger.log("GameInit", "Successfully cast to PlayerManagerNode: " + str(player_manager))
		player_manager.initialize_with_managers(_region_manager, map_generator)
		player_manager.set_army_manager(_army_manager)
		# Ensure players are initialized before any UI or scenario logic uses them
		player_manager._initialize_players(player_types)
		_apply_starting_resources_for_difficulty()
		_trade_manager = TradeManager.new(player_manager)
		
		# Connect to player change signal to refresh UI
		player_manager.current_player_changed.connect(_on_current_player_changed)
	else:
		push_error("[GameManager] CRITICAL: Failed to cast PlayerManager node to PlayerManagerNode! Node type: " + str(type_string(typeof(player_manager_node))))
		return
	
	# Initialize AI camera director early so tutorial can use it even in scenario/custom flows
	_ai_camera_director = AICameraDirector.new()
	_ai_camera_director.name = "AICameraDirector"
	add_child(_ai_camera_director)
	var camera_controller: CameraController = get_node("../Camera2D")
	_ai_camera_director.initialize(camera_controller)
	if _tutorial_manager:
		_tutorial_manager.set_ai_camera_director(_ai_camera_director)
		DebugLogger.log("Tutorial", "TutorialManager camera director set during AI director init")
	
	# Handle tutorial flag from scenario name (only for non-editor)
	tutorial_enabled = _should_enable_tutorial() and not enable_map_editor
	if tutorial_enabled:
		_tutorial_manager = TutorialManager.new(_region_manager, tutorial_modal, _message_modal, tutorial_camera, _ai_camera_director)
		if click_manager and click_manager.has_method("set_tutorial_manager"):
			click_manager.set_tutorial_manager(_tutorial_manager)
	elif not enable_map_editor and _sound_manager:
		_sound_manager.set_active_playlist("custom_map")
	
	# Early flows: heatmap/scenario/editor
	if debug_heatmap:
		var heat := StrategicPointsHeatmap.new()
		heat.name = "StrategicPointsHeatmap"
		add_child(heat)
		heat.initialize(_region_manager, map_generator)
		heat.enable_key_toggle = true
		heat.compute_and_show()
		DebugLogger.log("GameInit", "Debug heatmap enabled: displaying strategic points heatmap. Castle placement and turns are disabled.")
		return
	if is_scenario and scenario_path != "":
		_start_scenario()
		return
	if enable_map_editor:
		DebugLogger.log("GameInit", "Map editor enabled: skipping heatmap and castle placement initialization")
		return
	if not skip_initial_flow:
		var heat_calc := StrategicPointsHeatmap.new()
		heat_calc.initialize(_region_manager, map_generator)
		heat_calc.enable_key_toggle = false
		heat_calc.compute_and_store()
		_initialize_castle_placement_sequence()
	
	# Initialize AI system (now with proper PlayerManagerNode reference)
	_ai_region_scorer = RegionScorer.new(_region_manager, map_generator)
	_ai_castle_placement_scorer = CastlePlacementScorer.new(_region_manager, map_generator)
	_ai_debug_visualizer = AIDebugVisualizer.new()
	_ai_debug_visualizer.initialize(_ai_region_scorer, _ai_castle_placement_scorer, map_generator, _region_manager)
	
	# Initialize new unified turn controller (DebugStepGate should be in scene)
	_turn_controller = TurnController.new()
	_turn_controller.name = "TurnController"
	# Note: debug_step_gate_path should be set via inspector to static scene node
	add_child(_turn_controller)
	_turn_controller.initialize(_region_manager, _army_manager, player_manager, _battle_manager)
	if _turn_controller.debug_step_gate:
		_turn_controller.debug_step_gate.set_debug_enabled(ai_step_requires_shift)
	
	# Add AI debug visualizer to the scene tree
	var map_node = get_node("../Map")
	map_node.add_child(_ai_debug_visualizer)
	
	# Enable debug mode and step-by-step mode by default
	_ai_debug_visualizer.enable_step_by_step_mode(true)
	DebugLogger.log("GameInit", "AI system initialized with debug and step-by-step mode enabled")
	
	# Print initial player resources and types
	DebugLogger.log("GameInit", "Game initialized with " + str(total_players) + " players")
	DebugLogger.log("GameInit", "Player types:")
	for i in range(1, total_players + 1):
		DebugLogger.log("GameInit", "  Player " + str(i) + ": " + PlayerTypeEnum.type_to_string(get_player_type(i)))
	player_manager.print_all_resources()

	var icons_modal = ui_node.get_node("IconsModal") as Control
	icons_modal.visible = false

func _should_enable_tutorial() -> bool:
	return game_mode == "scenario" and scenario_path != "" and scenario_path.to_lower().find("tutorial") != -1

func _start_scenario() -> void:
	"""Apply scenario to runtime and start gameplay (no castle placement)."""
	DebugLogger.log("GameInit", "Starting scenario mode from: " + scenario_path)
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	var scen_mgr := ScenarioManager.new()
	var scen := scen_mgr.load_scenario(scenario_path)
	_initialize_victory_conditions_from_scenario_data(scen)
	_initialize_trade_rules_from_scenario_data(scen)
	_apply_scenario_player_settings_from_data(scen)
	# Apply to runtime
	scen_mgr.apply_to_runtime(
		map_generator,
		_region_manager,
		_army_manager,
		_visual_manager,
		scen,
		player_manager,
		GameParameters.game_difficulty_to_string(game_difficulty)
	)
	var heat_calc := StrategicPointsHeatmap.new()
	heat_calc.initialize(_region_manager, map_generator)
	heat_calc.enable_key_toggle = false
	heat_calc.compute_and_store()
	_initialize_scenario_events_from_data(scen, GameParameters.game_difficulty_to_string(game_difficulty))

	# Initialize AI system (now with proper PlayerManagerNode reference)
	_ai_region_scorer = RegionScorer.new(_region_manager, map_generator)
	_ai_castle_placement_scorer = CastlePlacementScorer.new(_region_manager, map_generator)
	_ai_debug_visualizer = AIDebugVisualizer.new()
	_ai_debug_visualizer.initialize(_ai_region_scorer, _ai_castle_placement_scorer, map_generator, _region_manager)

	# Initialize new unified turn controller (DebugStepGate should be in scene)
	_turn_controller = TurnController.new()
	_turn_controller.name = "TurnController"
	add_child(_turn_controller)
	_turn_controller.initialize(_region_manager, _army_manager, player_manager, _battle_manager)
	if _turn_controller.debug_step_gate:
		_turn_controller.debug_step_gate.set_debug_enabled(ai_step_requires_shift)

	# Add AI debug visualizer to the scene tree
	var map_node = get_node("../Map")
	map_node.add_child(_ai_debug_visualizer)

	# Enable debug mode and step-by-step mode by default
	_ai_debug_visualizer.enable_step_by_step_mode(true)
	DebugLogger.log("GameInit", "AI system initialized with debug and step-by-step mode enabled")

	# Set game state for immediate play
	castle_placing_mode = false
	current_player = _get_first_active_player()
	player_manager.set_current_player(current_player)
	# Allow a frame for UI to be ready, then show status modals
	await get_tree().process_frame
	var ui_node = get_node("../UI")
	var player_status_modal2 = ui_node.get_node("PlayerStatusModal2") as PlayerStatusModal2
	var turn_modal = ui_node.get_node("TurnModal") as TurnModal
	var icons_modal = ui_node.get_node("IconsModal") as Control
	player_status_modal2.show_and_update()
	turn_modal.show_and_update()
	if icons_modal:
		icons_modal.visible = true
	# Start first turn after optional scenario intro message
	if _show_scenario_intro_message_if_any(scen):
		return
	_start_first_turn()

func _apply_scenario_player_settings_from_data(scenario_data: Dictionary) -> void:
	if not scenario_data.has("player_settings"):
		return
	var raw_settings: Variant = scenario_data.get("player_settings", [])
	if not (raw_settings is Array):
		return
	var settings: Array = raw_settings
	if settings.is_empty():
		return
	_apply_custom_map_player_settings(settings)
	player_manager._initialize_players(player_types)
	_apply_starting_resources_for_difficulty()

func _show_scenario_intro_message_if_any(scenario_data: Dictionary) -> bool:
	var skip_intro: bool = bool(scenario_data.get("skip_intro", false))
	if skip_intro:
		return false
	var intro_text: String = _build_scenario_intro_modal_text(scenario_data)
	if intro_text == "":
		return false
	_disconnect_intro_message_modal_handlers()
	_intro_message_modal.continue_clicked.connect(_on_scenario_intro_continue)
	_intro_message_modal.display_intro_text(intro_text)
	return true

func _on_scenario_intro_continue() -> void:
	_disconnect_intro_message_modal_handlers()
	_start_first_turn()

func show_intro_message_modal_again() -> void:
	_disconnect_intro_message_modal_handlers()
	if scenario_path != "":
		var scen_mgr := ScenarioManager.new()
		var scenario_data: Dictionary = scen_mgr.load_scenario(scenario_path)
		var intro_text: String = _build_scenario_intro_modal_text(scenario_data)
		if intro_text != "":
			_intro_message_modal.display_intro_text(intro_text)
			return
	_intro_message_modal.display_default_intro_text_with_continue()

func _build_scenario_intro_modal_text(scenario_data: Dictionary) -> String:
	var intro_key: String = String(scenario_data.get("intro_message", "")).strip_edges()
	var objectives_key: String = String(scenario_data.get("objectives", "")).strip_edges()
	var intro_text: String = ""
	var objectives_text: String = ""
	if intro_key != "":
		intro_text = tr(intro_key)
	if objectives_key != "":
		objectives_text = tr(objectives_key)
	if intro_text != "" and objectives_text != "":
		return intro_text + "\n\n" + objectives_text
	if intro_text != "":
		return intro_text
	return objectives_text

func _disconnect_intro_message_modal_handlers() -> void:
	if _intro_message_modal.continue_clicked.is_connected(_on_scenario_intro_continue):
		_intro_message_modal.continue_clicked.disconnect(_on_scenario_intro_continue)
	if _intro_message_modal.continue_clicked.is_connected(_on_campaign_outro_end_mission):
		_intro_message_modal.continue_clicked.disconnect(_on_campaign_outro_end_mission)

func _on_campaign_outro_end_mission() -> void:
	_disconnect_intro_message_modal_handlers()
	get_tree().paused = false
	get_tree().set_meta(MAIN_MENU_TARGET_META_KEY, MAIN_MENU_TARGET_CAMPAIGN_LIST)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	# Handle keyboard shortcuts
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if tutorial_enabled and not enable_map_editor and _game_menu_modal:
				if _game_menu_modal.visible:
					_game_menu_modal.hide_modal()
				else:
					_game_menu_modal.show_modal()
				get_viewport().set_input_as_handled()
				return
			if _ui_manager.handle_escape_action():
				return
			if _game_menu_modal and not enable_map_editor:
				if _game_menu_modal.visible:
					_game_menu_modal.hide_modal()
				else:
					_game_menu_modal.show_modal()
		elif event.keycode == KEY_0:
			# Toggle AI debug visualization
			if _ai_debug_visualizer:
				_ai_debug_visualizer.toggle_debug_display(current_player)
				DebugLogger.log("TurnProcessing", "AI debug toggle for Player " + str(current_player))
		elif event.keycode == KEY_9:
			# Toggle step-by-step AI debug mode (only during actual turns, not castle placement)
			if _ai_debug_visualizer and not castle_placing_mode:
				var current_mode = _ai_debug_visualizer.is_step_by_step_mode()
				_ai_debug_visualizer.enable_step_by_step_mode(not current_mode)
				DebugLogger.log("TurnProcessing", "Step-by-step AI debug mode: " + ("enabled" if not current_mode else "disabled"))
			elif castle_placing_mode:
				DebugLogger.log("TurnProcessing", "Step-by-step mode not available during castle placement")
		elif event.keycode == KEY_Z:
			if debug_mode:
				_cycle_debug_language()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F8:
			# Take screenshot with proper setup
			_take_game_screenshot()
		# SPACE key handling is now managed by TurnController's DebugStepGate

func _cycle_debug_language() -> void:
	var current_locale: String = TranslationServer.get_locale().to_lower()
	var current_index: int = _debug_language_index_from_locale(current_locale)
	var next_index: int = (current_index + 1) % DEBUG_LANGUAGE_CYCLE.size()
	var next_locale: String = DEBUG_LANGUAGE_CYCLE[next_index]
	TranslationServer.set_locale(next_locale)
	var turn_modal: TurnModal = _ui_manager.get_turn_modal()
	turn_modal.update_turn_display()
	SaveGameManager.save_settings(_sound_manager)
	DebugLogger.log("UISystem", "Debug language switched to: " + next_locale)

func _debug_language_index_from_locale(locale: String) -> int:
	if locale.begins_with("de"):
		return 1
	if locale.begins_with("pl"):
		return 2
	if locale.begins_with("br") or locale.begins_with("pt"):
		return 3
	return 0

func next_turn():
	"""Advance to the next player's turn and perform turn-based actions"""
	if _turn_advance_in_progress:
		DebugLogger.log("TurnProcessing", "next_turn ignored: turn advance already in progress")
		return
	_turn_advance_in_progress = true
	await _next_turn_internal()
	_turn_advance_in_progress = false

func _next_turn_internal() -> void:
	if victory_declared:
		DebugLogger.log("Victory", "next_turn ignored after victory")
		return
	if debug_heatmap:
		DebugLogger.log("TurnProcessing", "Debug heatmap mode active - next_turn ignored")
		return
	if _army_manager:
		_army_manager.set_ready_highlight_player(-1)
	
	# Get next active player in sequence (skips OFF players)
	var next_player_id: int = _get_next_active_player()
	var round_start_player_id: int = _get_first_active_player()
	var is_new_round: bool = next_player_id == round_start_player_id
	
	if is_new_round:
		# Starting a new round - increment turn counter
		current_turn += 1
		DebugLogger.log("TurnProcessing", "=== Starting Round " + str(current_turn) + " ===")
		
		# Process global turn-based actions only at start of new round
		_process_round_start_actions()
	
	# Set current player
	current_player = next_player_id
	player_manager.set_current_player(current_player)
	
	# Process player-specific turn start actions (only for active players)
	if is_player_active(current_player):
		await _process_scenario_events_for_turn_start(current_player)
		if victory_declared:
			return
		await _process_player_turn_start(current_player)
		if check_victory_conditions_for_player(current_player):
			return
		_process_turn_start_autosave(current_player)
	
	# Check if current player is AI and handle AI turn processing
	DebugLogger.log("TurnProcessing", "Checking AI turn: castle_placing_mode=" + str(castle_placing_mode) + ", current_player=" + str(current_player) + ", is_computer=" + str(is_player_computer(current_player)))
	if not castle_placing_mode and is_player_computer(current_player):
		DebugLogger.log("TurnProcessing", "AI Player " + str(current_player) + " starting turn processing with TurnController...")
		await _turn_controller.start_turn(current_player)
		await _await_pending_battles()
		call_deferred("next_turn")  # Advance to next player after turn completes
		return  # Exit early since AI turn handling includes next_turn() call
	else:
		DebugLogger.log("TurnProcessing", "Skipping AI turn processing")
	
	# Note: next player modal and player status display are now handled by _on_current_player_changed signal handler

func _initialize_map_editor() -> void:
	"""Initialize map editor mode instead of normal game flow"""
	# Initialize MapEditor controller
	var map_editor = get_node("../MapEditor")
	map_editor.initialize()
	DebugLogger.log("GameInit", "MapEditor initialized successfully")

	# Map reference
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator

	# Handle editor start payload (from EditorStart scene)
	if get_tree().has_meta("editor_start_payload"):
		var payload = get_tree().get_meta("editor_start_payload")
		var kind := String(payload.get("type", ""))
		if kind == "map":
			game_mode = "custom"
			scenario_path = ""
			loaded_scenario_name = ""
			# Expect bare filename; normalize if path included
			map_generator.data_file_path = String(payload.get("map_file")).get_file()
			_map_set_size_from_string(map_generator, String(payload.get("map_size", "small")))
			map_generator.generate_map()
		elif kind == "scenario":
			game_mode = "scenario"
			var scen_path := String(payload.get("scenario_path"))
			scenario_path = scen_path
			var scen_mgr := ScenarioManager.new()
			# Normalize scenario path to res://scenarios/<file>
			var scen_full := "res://scenarios/" + scen_path.get_file()
			var scen := scen_mgr.load_scenario(scen_full)
			# Track the loaded scenario name
			loaded_scenario_name = scen_path.get_file().get_basename()
			if scen.has("map_file"):
				map_generator.data_file_path = String(scen.get("map_file")).get_file()
				_map_set_size_from_string(map_generator, String(payload.get("map_size", "small")))
				map_generator.generate_map()
			# After managers are created (below), apply scenario deltas
			get_tree().set_meta("__scenario_to_apply__", scen)
		# Clear payload
		get_tree().set_meta("editor_start_payload", null)

	# Minimal managers for editor actions (ownership/army toggles) — create AFTER map generation
	_region_manager = RegionManager.new(map_generator)
	_army_manager = ArmyManager.new(map_generator, _region_manager)
	_region_manager.set_army_manager(_army_manager)
	# Provide to ClickManager so editor code can use them
	click_manager = get_node("../ClickManager")
	if click_manager.has_method("set_managers"):
		click_manager.set_managers(_region_manager, _army_manager)

	# If a scenario was queued, apply its deltas now
	if get_tree().has_meta("__scenario_to_apply__") and get_tree().get_meta("__scenario_to_apply__") != null:
		var scen: Dictionary = get_tree().get_meta("__scenario_to_apply__") as Dictionary
		get_tree().set_meta("__scenario_to_apply__", null)
		var player_manager_node = get_node("../PlayerManager") as PlayerManagerNode
		ScenarioManager.new().apply_to_runtime(map_generator, _region_manager, _army_manager, null, scen, player_manager_node, "all")

	# Hide player/turn UI modals that are not needed in editor mode
	var ui_node = get_node("../UI")
	_ui_manager = ui_node.get_node("UIManager") as UIManager
	var player_status_modal2 = ui_node.get_node("PlayerStatusModal2")
	var turn_modal = ui_node.get_node("TurnModal") 
	var next_player_modal = ui_node.get_node("NextPlayerModal")
	
	player_status_modal2.hide()
	turn_modal.hide()
	next_player_modal.hide()
	
	# Show map editor panel
	var map_editor_panel = ui_node.get_node("MapEditorPanel")
	map_editor_panel.show()
	DebugLogger.log("GameInit", "Map editor panel shown")
	
	DebugLogger.log("GameInit", "Map editor initialization complete")

func _apply_custom_map_player_settings(settings: Array) -> void:
	"""Apply player settings from CustomMap to game state"""
	DebugLogger.log("GameInit", "Applying custom map player settings...")
	
	# Reset player types array to defaults
	for i in range(player_types.size()):
		player_types[i] = PlayerTypeEnum.Type.OFF
	
	var active_players = 0
	
	# Apply each player's setting
	for setting in settings:
		if not setting is Dictionary:
			continue
			
		var player_id = int(setting.get("player_id", 0))
		var control_type = String(setting.get("control_type", "Off"))
		
		if player_id >= 1 and player_id <= 6:
			var player_type: PlayerTypeEnum.Type
			match control_type:
				"Player":
					player_type = PlayerTypeEnum.Type.HUMAN
					active_players += 1
				"Computer":
					player_type = PlayerTypeEnum.Type.COMPUTER
					active_players += 1
				"Off":
					player_type = PlayerTypeEnum.Type.OFF
				_:
					player_type = PlayerTypeEnum.Type.OFF
			
			player_types[player_id - 1] = player_type
			DebugLogger.log("GameInit", "Player " + str(player_id) + " set to " + PlayerTypeEnum.type_to_string(player_type))
	
	# Update total_players to reflect active players (keep at 6 for array consistency)
	total_players = 6
	
	DebugLogger.log("GameInit", "Custom map player settings applied - " + str(active_players) + " active players")

func _apply_initial_camera_zoom() -> void:
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	var camera_controller: CameraController = get_node("../Camera2D") as CameraController
	var zoom_value := _get_initial_zoom_value(map_generator)
	camera_controller.set_zoom_immediate(zoom_value)

func _get_initial_zoom_value(map_generator: MapGenerator) -> float:
	return map_generator.get_map_initial_zoom()

func _map_set_size_from_string(mg: MapGenerator, size_str: String) -> void:
	var token: String = Utils.extract_map_size_token(size_str)
	if token == "":
		token = size_str.to_lower()
	var canonical_token: String = Utils.canonical_label_from_token(token)
	if canonical_token == "" and token.is_valid_int():
		canonical_token = Utils.get_nearest_anchor_label_from_region_count(int(token))
	if canonical_token == "":
		canonical_token = "small"
	match canonical_token:
		"tiny":
			mg.map_size = MapGenerator.MapSize.TINY
		"small":
			mg.map_size = MapGenerator.MapSize.SMALL
		"medium":
			mg.map_size = MapGenerator.MapSize.MEDIUM
		"large":
			mg.map_size = MapGenerator.MapSize.LARGE
		"huge":
			mg.map_size = MapGenerator.MapSize.HUGE
		_:
			mg.map_size = MapGenerator.MapSize.SMALL

func _on_map_generated() -> void:
	_apply_center_marker_setting()

func _apply_center_marker_setting() -> void:
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	map_generator.set_center_markers_enabled(show_region_center_markers)

func _show_custom_start_prompt() -> void:
	if game_mode != "custom":
		return
	if _loaded_from_save:
		return
	if enable_map_editor:
		return
	var modal_to_use: MessageModal = _message_modal
	if not tutorial_enabled and _intro_message_modal != null:
		modal_to_use = _intro_message_modal
	if modal_to_use == null:
		return
	modal_to_use.call_deferred("display_message", "Click a region to choose your starting location")

func _prepare_loaded_game_source(save_data: Dictionary, map_generator: MapGenerator) -> void:
	var source: Dictionary = save_data.get("source", {})
	game_mode = "custom"
	scenario_path = ""
	loaded_scenario_name = ""
	scenario_trade_disabled = false
	var map_file: String = String(source.get("map_file", map_generator.data_file_path))
	var map_size: String = String(source.get("map_size", "small"))
	map_generator.data_file_path = map_file.get_file()
	_map_set_size_from_string(map_generator, map_size)
	if source.has("player_settings"):
		_apply_custom_map_player_settings(source.get("player_settings"))
	load_victory_conditions_from_source(source)
	map_generator.generate_map()

func _initialize_victory_conditions_from_custom_payload(payload: Dictionary) -> void:
	var selected_condition: String = String(payload.get("victory_condition", "")).to_lower()
	_set_victory_conditions_from_raw([selected_condition])

func _initialize_victory_conditions_from_scenario_data(scenario_data: Dictionary) -> void:
	if scenario_data.has("victory_conditions"):
		var raw_conditions: Array = scenario_data.get("victory_conditions", [])
		_set_victory_conditions_from_raw(raw_conditions)
		return
	_set_victory_conditions_from_raw([])

func _initialize_trade_rules_from_scenario_data(scenario_data: Dictionary) -> void:
	if game_mode != "scenario":
		scenario_trade_disabled = false
		return
	scenario_trade_disabled = bool(scenario_data.get("trade_disabled", false))

func load_victory_conditions_from_source(source: Dictionary) -> void:
	if source.has("victory_conditions"):
		var raw_conditions: Array = source.get("victory_conditions", [])
		_set_victory_conditions_from_raw(raw_conditions)
		return
	_set_victory_conditions_from_raw([])

func get_victory_conditions_for_save() -> Array:
	var serialized: Array = []
	for condition: Dictionary in victory_conditions:
		serialized.append(condition.duplicate(true))
	return serialized

func has_victory_been_declared() -> bool:
	return victory_declared

func check_victory_conditions_for_player(player_id: int) -> bool:
	if victory_declared:
		return true
	if not is_player_active(player_id):
		return false
	for condition: Dictionary in victory_conditions:
		if not _victory_condition_applies_to_player(condition, player_id):
			continue
		if _is_victory_condition_met(player_id, condition):
			_declare_victory(player_id, condition)
			return true
	return false

func _set_victory_conditions_from_raw(raw_conditions: Array) -> void:
	var normalized_conditions: Array[Dictionary] = []
	for raw_condition in raw_conditions:
		var normalized: Dictionary = _normalize_victory_condition(raw_condition)
		if normalized.is_empty():
			continue
		normalized_conditions.append(normalized)
	victory_conditions.clear()
	for condition: Dictionary in normalized_conditions:
		victory_conditions.append(condition.duplicate(true))
	victory_declared = false
	winning_player_id = -1

func _normalize_victory_condition(raw_condition: Variant) -> Dictionary:
	if raw_condition is String:
		var condition_type_from_string: String = String(raw_condition).to_lower()
		match condition_type_from_string:
			"conquer":
				return {"type": "conquer"}
			"conquer_after_events":
				return {"type": "conquer_after_events"}
			"dominate":
				return {
					"type": "dominate",
					"required_ratio": DOMINATE_DEFAULT_THRESHOLD
				}
			_:
				return {}
	if not (raw_condition is Dictionary):
		return {}
	var source_condition: Dictionary = raw_condition
	var condition_type: String = String(source_condition.get("type", "")).to_lower()
	var target_player_id: int = int(source_condition.get("player_id", 0))
	match condition_type:
		"conquer":
			return {
				"type": "conquer",
				"player_id": target_player_id
			}
		"conquer_after_events", "conquer_events", "event_conquer":
			return {
				"type": "conquer_after_events",
				"player_id": target_player_id
			}
		"dominate":
			var threshold: float = float(source_condition.get("required_ratio", source_condition.get("threshold", DOMINATE_DEFAULT_THRESHOLD)))
			return {
				"type": "dominate",
				"player_id": target_player_id,
				"required_ratio": threshold
			}
		"own_region":
			var required_region_id: int = int(source_condition.get("region_id", -1))
			if required_region_id < 0:
				return {}
			return {
				"type": "own_region",
				"player_id": target_player_id,
				"region_id": required_region_id
			}
		"survive", "survive_turns":
			var required_turns: int = int(source_condition.get("turns", source_condition.get("required_turns", 0)))
			if required_turns <= 0:
				return {}
			return {
				"type": "survive_turns",
				"player_id": target_player_id,
				"turns": required_turns
			}
		"economy":
			var required_region_id: int = int(source_condition.get("region_id", -1))
			if required_region_id < 0:
				return {}
			var required_units_hired: int = int(source_condition.get("units_hired", source_condition.get("required_units_hired", source_condition.get("unit_count", 0))))
			if required_units_hired <= 0:
				return {}
			var required_region_level: RegionLevelEnum.Level = RegionLevelEnum.string_to_level(String(source_condition.get("required_region_level", source_condition.get("region_level", "shire"))))
			var required_castle_level: CastleTypeEnum.Type = CastleTypeEnum.string_to_type(String(source_condition.get("required_castle_level", source_condition.get("castle_level", "none"))))
			var required_unit_type: SoldierTypeEnum.Type = SoldierTypeEnum.string_to_type(String(source_condition.get("unit_type", source_condition.get("required_unit_type", "peasants"))))
			return {
				"type": "economy",
				"player_id": target_player_id,
				"region_id": required_region_id,
				"required_region_level": RegionLevelEnum.level_to_string(required_region_level),
				"required_castle_level": CastleTypeEnum.type_to_string(required_castle_level),
				"unit_type": SoldierTypeEnum.type_to_string(required_unit_type),
				"units_hired": required_units_hired
			}
		_:
			return {}

func _victory_condition_applies_to_player(condition: Dictionary, player_id: int) -> bool:
	var target_player_id: int = int(condition.get("player_id", 0))
	if target_player_id <= 0:
		return true
	return target_player_id == player_id

func _is_victory_condition_met(player_id: int, condition: Dictionary) -> bool:
	var condition_type: String = String(condition.get("type", ""))
	match condition_type:
		"conquer":
			return _is_conquer_victory_met(player_id)
		"conquer_after_events":
			return _is_conquer_after_events_victory_met(player_id)
		"dominate":
			return _is_dominate_victory_met(player_id, condition)
		"own_region":
			return _is_own_region_victory_met(player_id, condition)
		"survive_turns":
			return _is_survive_turns_victory_met(player_id, condition)
		"economy":
			return _is_economy_victory_met(player_id, condition)
		_:
			return false

func _is_conquer_victory_met(player_id: int) -> bool:
	for other_player_id in range(1, total_players + 1):
		if other_player_id == player_id:
			continue
		if not is_player_active(other_player_id):
			continue
		if _player_has_any_castle(other_player_id):
			return false
		if _player_has_any_army(other_player_id):
			return false
	return true

func _is_conquer_after_events_victory_met(player_id: int) -> bool:
	if not _are_all_scenario_events_triggered():
		return false
	return _is_conquer_victory_met(player_id)

func _are_all_scenario_events_triggered() -> bool:
	for event_data in _scenario_events_runtime:
		if not bool(event_data.get("triggered", false)):
			return false
	return true

func _is_dominate_victory_met(player_id: int, condition: Dictionary) -> bool:
	var required_ratio: float = float(condition.get("required_ratio", DOMINATE_DEFAULT_THRESHOLD))
	if required_ratio <= 0.0:
		required_ratio = DOMINATE_DEFAULT_THRESHOLD
	var total_conquerable_regions: int = _count_all_conquerable_regions()
	if total_conquerable_regions <= 0:
		return false
	var owned_conquerable_regions: int = _count_player_conquerable_regions(player_id)
	var controlled_ratio: float = float(owned_conquerable_regions) / float(total_conquerable_regions)
	return controlled_ratio >= required_ratio

func _is_own_region_victory_met(player_id: int, condition: Dictionary) -> bool:
	var required_region_id: int = int(condition.get("region_id", -1))
	if required_region_id < 0:
		return false
	var owner_id: int = _region_manager.get_region_owner(required_region_id)
	return owner_id == player_id

func _is_survive_turns_victory_met(_player_id: int, condition: Dictionary) -> bool:
	var required_turns: int = int(condition.get("turns", 0))
	if required_turns <= 0:
		return false
	return current_turn >= required_turns

func _is_economy_victory_met(player_id: int, condition: Dictionary) -> bool:
	var required_region_id: int = int(condition.get("region_id", -1))
	if required_region_id < 0:
		return false
	if _region_manager.get_region_owner(required_region_id) != player_id:
		return false
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	var region: Region = map_generator.get_region_container_by_id(required_region_id) as Region
	var required_region_level: RegionLevelEnum.Level = RegionLevelEnum.string_to_level(String(condition.get("required_region_level", "shire")))
	var required_castle_level: CastleTypeEnum.Type = CastleTypeEnum.string_to_type(String(condition.get("required_castle_level", "none")))
	if int(region.get_region_level()) < int(required_region_level):
		return false
	if int(region.get_castle_type()) < int(required_castle_level):
		return false
	var required_units_hired: int = int(condition.get("units_hired", 0))
	if required_units_hired <= 0:
		return false
	var unit_type_name: String = SoldierTypeEnum.type_to_string(SoldierTypeEnum.string_to_type(String(condition.get("unit_type", "peasants"))))
	var hired_units: int = _get_player_hired_unit_count(player_id, unit_type_name)
	return hired_units >= required_units_hired

func _create_empty_hired_units_entry() -> Dictionary:
	var entry: Dictionary = {}
	for unit_type in SoldierTypeEnum.get_all_types():
		var unit_name: String = SoldierTypeEnum.type_to_string(unit_type)
		entry[unit_name] = 0
	return entry

func _reset_player_hired_units_tracking() -> void:
	_player_hired_units.clear()
	for player_id in range(1, 7):
		_player_hired_units[player_id] = _create_empty_hired_units_entry()

func record_hired_units(player_id: int, hired_counts: Dictionary) -> void:
	if not _player_hired_units.has(player_id):
		_player_hired_units[player_id] = _create_empty_hired_units_entry()
	var player_data: Dictionary = _player_hired_units[player_id]
	for key in hired_counts.keys():
		var amount: int = maxi(0, int(hired_counts[key]))
		if amount <= 0:
			continue
		var unit_type_name: String
		if key is int:
			unit_type_name = SoldierTypeEnum.type_to_string(key)
		else:
			unit_type_name = SoldierTypeEnum.type_to_string(SoldierTypeEnum.string_to_type(String(key)))
		player_data[unit_type_name] = int(player_data.get(unit_type_name, 0)) + amount
	_player_hired_units[player_id] = player_data

func _get_player_hired_unit_count(player_id: int, unit_type_name: String) -> int:
	if not _player_hired_units.has(player_id):
		return 0
	var player_data: Dictionary = _player_hired_units[player_id]
	return int(player_data.get(unit_type_name, 0))

func get_player_hired_units_for_save() -> Dictionary:
	var serialized: Dictionary = {}
	for player_id in _player_hired_units.keys():
		serialized[str(player_id)] = (_player_hired_units[player_id] as Dictionary).duplicate(true)
	return serialized

func set_player_hired_units_from_save(raw_data: Dictionary) -> void:
	_reset_player_hired_units_tracking()
	for key in raw_data.keys():
		var player_id: int = int(key)
		var source_entry: Dictionary = raw_data.get(key, {})
		var normalized_entry: Dictionary = _create_empty_hired_units_entry()
		for unit_type in SoldierTypeEnum.get_all_types():
			var unit_name: String = SoldierTypeEnum.type_to_string(unit_type)
			normalized_entry[unit_name] = maxi(0, int(source_entry.get(unit_name, 0)))
		_player_hired_units[player_id] = normalized_entry

func _player_has_any_castle(player_id: int) -> bool:
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	var owned_region_ids: Array[int] = _region_manager.get_player_regions(player_id)
	for region_id: int in owned_region_ids:
		var region: Region = map_generator.get_region_container_by_id(region_id) as Region
		if region.has_castle():
			return true
	return false

func _player_has_any_army(player_id: int) -> bool:
	var armies: Array[Army] = _army_manager.get_player_armies(player_id)
	for army: Army in armies:
		if is_instance_valid(army):
			return true
	return false

func _count_all_conquerable_regions() -> int:
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	var regions_node: Node = map_generator.get_node("Regions")
	var count: int = 0
	for child in regions_node.get_children():
		if not (child is Region):
			continue
		var region: Region = child as Region
		if _is_region_conquerable(region):
			count += 1
	return count

func _count_player_conquerable_regions(player_id: int) -> int:
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	var regions_node: Node = map_generator.get_node("Regions")
	var count: int = 0
	for child in regions_node.get_children():
		if not (child is Region):
			continue
		var region: Region = child as Region
		if not _is_region_conquerable(region):
			continue
		var owner_id: int = _region_manager.get_region_owner(region.get_region_id())
		if owner_id == player_id:
			count += 1
	return count

func _is_region_conquerable(region: Region) -> bool:
	if region.is_ocean_region():
		return false
	if region.get_region_type() == RegionTypeEnum.Type.MOUNTAINS:
		return false
	return true

func _declare_victory(player_id: int, condition: Dictionary) -> void:
	if victory_declared:
		return
	victory_declared = true
	winning_player_id = player_id
	var condition_type: String = String(condition.get("type", ""))
	DebugLogger.log("Victory", "Player " + str(player_id) + " won with condition: " + condition_type)
	if _should_show_campaign_outro(player_id):
		_disconnect_intro_message_modal_handlers()
		_intro_message_modal.continue_clicked.connect(_on_campaign_outro_end_mission)
		_intro_message_modal.display_outro_text(_resolve_campaign_outro_text())
		return
	_message_modal.display_message(tr("Player %d Won") % player_id)

func _should_show_campaign_outro(player_id: int) -> bool:
	if player_id != 1:
		return false
	if game_mode != "scenario":
		return false
	if scenario_path == "":
		return false
	var scenario_data: Dictionary = ScenarioManager.new().load_scenario(scenario_path)
	var scenario_type: String = String(scenario_data.get("scenario_type", "scenario")).to_lower()
	return scenario_type == "campaign"

func _resolve_campaign_outro_text() -> String:
	var scenario_data: Dictionary = ScenarioManager.new().load_scenario(scenario_path)
	var mission_number: int = int(scenario_data.get("mission_number", 0))
	return CAMPAIGN_OUTRO_KEY_TEMPLATE % mission_number

func _initialize_scenario_events_from_data(scenario_data: Dictionary, difficulty_token: String = "all") -> void:
	_scenario_events_runtime.clear()
	if game_mode != "scenario":
		return
	if not scenario_data.has("events"):
		return
	var source_events: Array = scenario_data.get("events", [])
	var normalized_difficulty: String = _normalize_scenario_difficulty_token(difficulty_token)
	var event_composition_overrides: Dictionary = _resolve_event_composition_overrides_for_difficulty(scenario_data, normalized_difficulty)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for event_index in range(source_events.size()):
		var raw_event: Variant = source_events[event_index]
		if not (raw_event is Dictionary):
			continue
		var event_definition: Dictionary = _normalize_scenario_event_definition(raw_event)
		if event_composition_overrides.has(event_index):
			var raw_override: Variant = event_composition_overrides.get(event_index, {})
			if raw_override is Dictionary:
				event_definition["composition"] = _normalize_event_composition(raw_override)
		var turn_start: int = int(event_definition.get("turn_start", 1))
		var turn_end: int = int(event_definition.get("turn_end", turn_start))
		var selected_turn: int = rng.randi_range(turn_start, turn_end)
		var region_pool: Array[int] = _normalize_event_regions(event_definition.get("regions", []))
		region_pool.shuffle()
		var selected_region_id: int = -1
		if not region_pool.is_empty():
			selected_region_id = region_pool[0]
		var runtime_event: Dictionary = {
			"name": String(event_definition.get("name", "Event")),
			"player_id": int(event_definition.get("player_id", 1)),
			"turn": selected_turn,
			"turn_start": turn_start,
			"turn_end": turn_end,
			"regions": _normalize_event_regions(event_definition.get("regions", [])),
			"region_pool": region_pool,
			"selected_region_id": selected_region_id,
			"composition": _normalize_event_composition(event_definition.get("composition", {})),
			"message": String(event_definition.get("message", "")),
			"triggered": false
		}
		_scenario_events_runtime.append(runtime_event)

func _normalize_scenario_difficulty_token(raw_token: String) -> String:
	var normalized: String = raw_token.to_lower().strip_edges()
	match normalized:
		"easy", "normal", "hard":
			return normalized
		_:
			return "all"

func _resolve_event_composition_overrides_for_difficulty(scenario_data: Dictionary, difficulty_token: String) -> Dictionary:
	if difficulty_token == "all":
		return {}
	var raw_overrides: Variant = scenario_data.get("difficulty_overrides", {})
	if not (raw_overrides is Dictionary):
		return {}
	var overrides: Dictionary = raw_overrides as Dictionary
	var raw_difficulty_block: Variant = overrides.get(difficulty_token, {})
	if not (raw_difficulty_block is Dictionary):
		return {}
	var difficulty_block: Dictionary = raw_difficulty_block as Dictionary
	var raw_event_entries: Variant = difficulty_block.get("event_compositions", [])
	if not (raw_event_entries is Array):
		return {}
	var result: Dictionary = {}
	var event_entries: Array = raw_event_entries as Array
	for raw_entry in event_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var event_index: int = int(entry.get("event_index", -1))
		if event_index < 0:
			continue
		var raw_composition: Variant = entry.get("composition", {})
		if not (raw_composition is Dictionary):
			continue
		result[event_index] = _normalize_event_composition(raw_composition)
	return result

func _normalize_scenario_event_definition(raw_event: Dictionary) -> Dictionary:
	var event_name: String = String(raw_event.get("name", "Event")).strip_edges()
	if event_name == "":
		event_name = "Event"
	var turn_start: int = maxi(1, int(raw_event.get("turn_start", 1)))
	var turn_end: int = maxi(1, int(raw_event.get("turn_end", turn_start)))
	if turn_end < turn_start:
		var tmp_turn: int = turn_start
		turn_start = turn_end
		turn_end = tmp_turn
	return {
		"name": event_name,
		"regions": _normalize_event_regions(raw_event.get("regions", [])),
		"turn_start": turn_start,
		"turn_end": turn_end,
		"player_id": maxi(1, mini(6, int(raw_event.get("player_id", 1)))),
		"composition": _normalize_event_composition(raw_event.get("composition", {})),
		"message": String(raw_event.get("message", ""))
	}

func _normalize_event_regions(raw_regions: Variant) -> Array[int]:
	var result: Array[int] = []
	if not (raw_regions is Array):
		return result
	var regions_array: Array = raw_regions
	for raw_region in regions_array:
		var region_id: int = int(raw_region)
		if region_id < 0:
			continue
		if result.has(region_id):
			continue
		result.append(region_id)
	return result

func _normalize_event_composition(raw_composition: Variant) -> Dictionary:
	var result: Dictionary = {}
	var source: Dictionary = {}
	if raw_composition is Dictionary:
		source = raw_composition
	for unit_type in SoldierTypeEnum.get_all_types():
		var unit_name: String = SoldierTypeEnum.type_to_string(unit_type)
		result[unit_name] = maxi(0, int(source.get(unit_name, 0)))
	return result

func _process_scenario_events_for_turn_start(player_id: int) -> void:
	if game_mode != "scenario":
		return
	for i in range(_scenario_events_runtime.size()):
		var event_data: Dictionary = _scenario_events_runtime[i]
		if bool(event_data.get("triggered", false)):
			continue
		if int(event_data.get("player_id", 0)) != player_id:
			continue
		if int(event_data.get("turn", -1)) != current_turn:
			continue
		await _execute_scenario_event(i)
		if victory_declared:
			return

func _execute_scenario_event(event_index: int) -> void:
	if event_index < 0 or event_index >= _scenario_events_runtime.size():
		return
	var event_data: Dictionary = _scenario_events_runtime[event_index]
	var event_message: String = String(event_data.get("message", "")).strip_edges()
	if event_message != "":
		_event_message_modal.display_message(tr(event_message))
		await _event_message_modal.continue_clicked
	var player_id: int = int(event_data.get("player_id", 1))
	if is_player_human(player_id):
		event_data = await _execute_human_spawn_event_with_manual_placement(event_index, event_data)
	else:
		event_data = await _execute_scenario_event_auto_spawn(event_data)
	_scenario_events_runtime[event_index] = event_data

func _resolve_scenario_event_spawn_region(event_data: Dictionary) -> Dictionary:
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	var region_pool: Array[int] = _normalize_event_regions(event_data.get("region_pool", []))
	if region_pool.is_empty():
		region_pool = _normalize_event_regions(event_data.get("regions", []))
		region_pool.shuffle()
	while not region_pool.is_empty():
		var region_id: int = int(region_pool.pop_front())
		if not map_generator.region_container_by_id.has(region_id):
			continue
		var region: Region = map_generator.region_container_by_id[region_id] as Region
		if _army_manager.is_region_at_army_cap(region):
			continue
		event_data["region_pool"] = region_pool
		event_data["selected_region_id"] = region_id
		return {
			"spawnable": true,
			"region": region,
			"region_id": region_id,
			"event": event_data
		}
	event_data["region_pool"] = region_pool
	event_data["selected_region_id"] = -1
	return {
		"spawnable": false,
		"region_id": -1,
		"event": event_data
	}

func _spawn_scenario_event_army_in_region(region: Region, player_id: int, composition: Dictionary, set_zero_movement: bool = true) -> Army:
	var spawned_army: Army = _army_manager.create_army(region, player_id)
	if spawned_army == null:
		return null
	_apply_scenario_event_army_composition(spawned_army, composition)
	if set_zero_movement:
		spawned_army.movement_points = 0
	spawned_army.just_raised = false
	return spawned_army

func _execute_scenario_event_auto_spawn(event_data: Dictionary) -> Dictionary:
	var updated_event: Dictionary = event_data
	var spawn_plan: Dictionary = _resolve_scenario_event_spawn_region(updated_event)
	updated_event = spawn_plan.get("event", updated_event)
	if bool(spawn_plan.get("spawnable", false)):
		var region_id: int = int(spawn_plan.get("region_id", -1))
		var region: Region = spawn_plan.get("region") as Region
		await _ai_camera_director.await_focus_on_region(region)
		var composition: Dictionary = _normalize_event_composition(updated_event.get("composition", {}))
		var player_id: int = int(updated_event.get("player_id", 1))
		var spawned_army: Army = _spawn_scenario_event_army_in_region(region, player_id, composition, true)
		if spawned_army != null:
			var army_player_id: int = spawned_army.get_player_id()
			var battle_needed: bool = _should_trigger_battle(spawned_army, region)
			if battle_needed:
				await handle_army_battle(spawned_army, region_id)
				await _await_pending_battles()
				check_victory_conditions_for_player(army_player_id)
	updated_event["triggered"] = true
	return updated_event

func _execute_human_spawn_event_with_manual_placement(event_index: int, event_data: Dictionary) -> Dictionary:
	var updated_event: Dictionary = event_data
	var placement_context: Dictionary = _build_human_spawn_event_placement_context(updated_event)
	var target_ids: Array[int] = placement_context.get("target_ids", [])
	var staging_region: Region = placement_context.get("staging_region") as Region
	if target_ids.is_empty() or staging_region == null:
		DebugLogger.log("TurnProcessing", "Human event spawn placement fallback: no valid placement context for event index " + str(event_index))
		return await _execute_scenario_event_auto_spawn(updated_event)
	var composition: Dictionary = _normalize_event_composition(updated_event.get("composition", {}))
	var player_id: int = int(updated_event.get("player_id", 1))
	var spawned_army: Army = _spawn_scenario_event_army_in_region(staging_region, player_id, composition, false)
	if spawned_army == null:
		DebugLogger.log("TurnProcessing", "Human event spawn placement fallback: failed to create staging army for event index " + str(event_index))
		return await _execute_scenario_event_auto_spawn(updated_event)
	spawned_army.visible = false
	_activate_spawn_event_placement_mode(
		event_index,
		spawned_army,
		target_ids,
		placement_context.get("source_region_by_target", {})
	)
	var selected_variant: Variant = await spawn_event_target_selected
	var selected_region_id: int = int(selected_variant)
	_deactivate_spawn_event_placement_mode()
	if not target_ids.has(selected_region_id):
		selected_region_id = int(target_ids[0])
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	var target_region: Region = map_generator.get_region_container_by_id(selected_region_id) as Region
	await _ai_camera_director.await_focus_on_region(target_region)
	_relocate_spawn_event_army_to_region(spawned_army, target_region)
	var battle_needed: bool = _should_trigger_battle(spawned_army, target_region)
	if battle_needed:
		await handle_army_battle(spawned_army, selected_region_id)
		await _await_pending_battles()
		check_victory_conditions_for_player(player_id)
	if spawned_army != null and is_instance_valid(spawned_army):
		spawned_army.movement_points = 0
	updated_event["selected_region_id"] = selected_region_id
	updated_event["triggered"] = true
	return updated_event

func _build_human_spawn_event_placement_context(event_data: Dictionary) -> Dictionary:
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	var target_ids: Array[int] = []
	var source_region_by_target: Dictionary = {}
	var candidate_ocean_sources: Array[int] = []
	var region_ids: Array[int] = _normalize_event_regions(event_data.get("regions", []))
	for region_id in region_ids:
		if not map_generator.region_container_by_id.has(region_id):
			continue
		var target_region: Region = map_generator.region_container_by_id[region_id] as Region
		if target_region.is_ocean_region():
			continue
		if _army_manager.is_region_at_army_cap(target_region):
			continue
		target_ids.append(region_id)
		var ocean_source_id: int = _find_first_adjacent_ocean_region_id(region_id)
		if ocean_source_id != -1:
			source_region_by_target[region_id] = ocean_source_id
			if not candidate_ocean_sources.has(ocean_source_id):
				candidate_ocean_sources.append(ocean_source_id)
	var fallback_source_id: int = -1
	if not candidate_ocean_sources.is_empty():
		fallback_source_id = int(candidate_ocean_sources[0])
	for target_id in target_ids:
		if source_region_by_target.has(target_id):
			continue
		var resolved_source_id: int = _find_nearest_ocean_region_id(target_id)
		if resolved_source_id != -1:
			source_region_by_target[target_id] = resolved_source_id
			if not candidate_ocean_sources.has(resolved_source_id):
				candidate_ocean_sources.append(resolved_source_id)
			if fallback_source_id == -1:
				fallback_source_id = resolved_source_id
			continue
		if fallback_source_id != -1:
			source_region_by_target[target_id] = fallback_source_id
			continue
		source_region_by_target[target_id] = target_id
	var staging_region: Region = _resolve_spawn_event_staging_region(candidate_ocean_sources, target_ids)
	return {
		"target_ids": target_ids,
		"source_region_by_target": source_region_by_target,
		"staging_region": staging_region
	}

func _resolve_spawn_event_staging_region(candidate_ocean_sources: Array[int], target_ids: Array[int]) -> Region:
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	for source_id in candidate_ocean_sources:
		if not map_generator.region_container_by_id.has(source_id):
			continue
		var source_region: Region = map_generator.region_container_by_id[source_id] as Region
		if source_region == null:
			continue
		if _army_manager.is_region_at_army_cap(source_region):
			continue
		return source_region
	for target_id in target_ids:
		if not map_generator.region_container_by_id.has(target_id):
			continue
		var target_region: Region = map_generator.region_container_by_id[target_id] as Region
		if target_region == null:
			continue
		if _army_manager.is_region_at_army_cap(target_region):
			continue
		return target_region
	return null

func _find_first_adjacent_ocean_region_id(target_region_id: int) -> int:
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	for raw_edge in map_generator.edges:
		if not (raw_edge is Dictionary):
			continue
		var edge: Dictionary = raw_edge as Dictionary
		var region1: int = int(edge.get("region1", -1))
		var region2: int = int(edge.get("region2", -1))
		if region1 != target_region_id and region2 != target_region_id:
			continue
		var neighbor_id: int = region1 if region2 == target_region_id else region2
		if not map_generator.region_by_id.has(neighbor_id):
			continue
		var neighbor_data: Dictionary = map_generator.region_by_id[neighbor_id] as Dictionary
		if bool(neighbor_data.get("ocean", false)):
			return neighbor_id
	return -1

func _find_nearest_ocean_region_id(target_region_id: int) -> int:
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	var target_region: Region = map_generator.get_region_container_by_id(target_region_id) as Region
	var target_center: Vector2 = target_region.center
	var nearest_id: int = -1
	var nearest_distance_sq: float = INF
	for raw_region_id in map_generator.region_by_id.keys():
		var ocean_region_id: int = int(raw_region_id)
		var region_data: Dictionary = map_generator.region_by_id[ocean_region_id] as Dictionary
		if not bool(region_data.get("ocean", false)):
			continue
		var ocean_region: Region = map_generator.get_region_container_by_id(ocean_region_id) as Region
		var distance_sq: float = target_center.distance_squared_to(ocean_region.center)
		if distance_sq >= nearest_distance_sq:
			continue
		nearest_distance_sq = distance_sq
		nearest_id = ocean_region_id
	return nearest_id

func _activate_spawn_event_placement_mode(event_index: int, spawned_army: Army, target_ids: Array[int], source_region_by_target: Dictionary) -> void:
	_spawn_event_pending_event_index = event_index
	_spawn_event_placement_army = spawned_army
	_spawn_event_allowed_target_ids = target_ids.duplicate()
	_spawn_event_source_region_by_target = source_region_by_target.duplicate(true)
	_spawn_event_placement_active = true
	var ui_node: Node = get_node("../UI")
	var info_modal: InfoModal = ui_node.get_node("InfoModal") as InfoModal
	var move_modal: MoveModal = ui_node.get_node("MoveModal") as MoveModal
	info_modal.set_spawn_event_armies_only_mode(true)
	info_modal.show_army_info(spawned_army)
	_army_manager.select_army(spawned_army, spawned_army.get_parent() as Region, current_player)
	move_modal.hide_move_modal()
	if _next_player_modal and _next_player_modal.visible:
		_next_player_modal.hide_modal()
	_army_manager.show_custom_target_arrows(_spawn_event_allowed_target_ids, _spawn_event_source_region_by_target)

func _deactivate_spawn_event_placement_mode() -> void:
	_spawn_event_placement_active = false
	_army_manager.clear_custom_target_arrows()
	var ui_node: Node = get_node("../UI")
	var info_modal: InfoModal = ui_node.get_node("InfoModal") as InfoModal
	info_modal.set_spawn_event_armies_only_mode(false)
	if _spawn_event_placement_army != null and is_instance_valid(_spawn_event_placement_army):
		if _army_manager.selected_army == _spawn_event_placement_army:
			_army_manager.deselect_army()
	_spawn_event_placement_army = null
	_spawn_event_allowed_target_ids.clear()
	_spawn_event_source_region_by_target.clear()
	_spawn_event_pending_event_index = -1

func _relocate_spawn_event_army_to_region(army: Army, target_region: Region) -> void:
	if army == null or not is_instance_valid(army):
		return
	var source_region: Region = army.get_parent() as Region
	if source_region == null:
		return
	if source_region == target_region:
		army.visible = true
		_army_manager._apply_army_offsets_for_region(target_region)
		return
	var start_global: Vector2 = army.global_position
	source_region.remove_child(army)
	target_region.add_child(army)
	army.global_position = start_global
	army.visible = true
	_army_manager.on_army_moved(army, source_region, target_region)
	_army_manager._apply_army_offsets_for_region(source_region)
	_army_manager._apply_army_offsets_for_region(target_region)

func is_spawn_event_placement_active() -> bool:
	return _spawn_event_placement_active

func try_handle_spawn_event_region_click(region: Region, button_index: int) -> bool:
	if not _spawn_event_placement_active:
		return false
	if region == null:
		return true
	if button_index != MOUSE_BUTTON_RIGHT:
		return true
	if region.is_ocean_region():
		return true
	var region_id: int = region.get_region_id()
	if not _spawn_event_allowed_target_ids.has(region_id):
		return true
	if _army_manager.is_region_at_army_cap(region):
		return true
	_spawn_event_placement_active = false
	emit_signal("spawn_event_target_selected", region_id)
	return true

func _apply_scenario_event_army_composition(army: Army, composition: Dictionary) -> void:
	for unit_type in SoldierTypeEnum.get_all_types():
		var unit_name: String = SoldierTypeEnum.type_to_string(unit_type)
		var amount: int = maxi(0, int(composition.get(unit_name, 0)))
		army.get_composition().set_soldier_count(unit_type, amount)
		army.get_wounded_composition().set_soldier_count(unit_type, 0)

func get_scenario_events_runtime_for_save() -> Array:
	var copied: Array = []
	for event_data in _scenario_events_runtime:
		copied.append((event_data as Dictionary).duplicate(true))
	return copied

func set_scenario_events_runtime_from_save(raw_events: Array) -> void:
	_scenario_events_runtime.clear()
	for raw_event in raw_events:
		if not (raw_event is Dictionary):
			continue
		var event_data: Dictionary = raw_event.duplicate(true)
		var normalized_regions: Array[int] = _normalize_event_regions(event_data.get("regions", []))
		var normalized_region_pool: Array[int] = _normalize_event_regions(event_data.get("region_pool", normalized_regions))
		event_data["name"] = String(event_data.get("name", "Event"))
		event_data["player_id"] = maxi(1, mini(6, int(event_data.get("player_id", 1))))
		event_data["turn"] = maxi(1, int(event_data.get("turn", 1)))
		event_data["turn_start"] = maxi(1, int(event_data.get("turn_start", event_data.get("turn", 1))))
		event_data["turn_end"] = maxi(1, int(event_data.get("turn_end", event_data.get("turn", 1))))
		event_data["regions"] = normalized_regions
		event_data["region_pool"] = normalized_region_pool
		event_data["selected_region_id"] = int(event_data.get("selected_region_id", -1))
		event_data["composition"] = _normalize_event_composition(event_data.get("composition", {}))
		event_data["message"] = String(event_data.get("message", ""))
		event_data["triggered"] = bool(event_data.get("triggered", false))
		_scenario_events_runtime.append(event_data)

func set_region_center_markers_enabled(value: bool) -> void:
	if show_region_center_markers == value:
		return
	show_region_center_markers = value
	_apply_center_marker_setting()

func _get_next_player() -> int:
	"""Get the next player in the turn sequence"""
	var current_index = players_per_round.find(current_player)
	if current_index == -1:
		# Current player not found, start with first player
		return players_per_round[0]
	
	var next_index = (current_index + 1) % players_per_round.size()
	return players_per_round[next_index]

func _get_next_active_player() -> int:
	"""Get the next active player (skipping OFF players)"""
	var starting_player = current_player
	var next_player = _get_next_player()
	
	# Keep searching until we find an active player or loop back
	while not is_player_active(next_player) and next_player != starting_player:
		var temp_current = current_player
		current_player = next_player  # Temporarily set to get the next player
		next_player = _get_next_player()
		current_player = temp_current  # Restore current player
		
		# If we've checked all players and none are active, return starting player
		if next_player == starting_player:
			break
	
	return next_player if is_player_active(next_player) else starting_player

func _get_first_active_player() -> int:
	"""Get the first active player in configured turn order."""
	for player_id: int in players_per_round:
		if is_player_active(player_id):
			return player_id
	return players_per_round[0]


func _initialize_castle_placement_sequence() -> void:
	"""Initialize castle placement sequence, starting with first active player"""
	current_player = _get_first_active_player()
	
	player_manager.set_current_player(current_player)
	DebugLogger.log("GameInit", "Castle placement starting with Player " + str(current_player) + " (" + PlayerTypeEnum.type_to_string(get_player_type(current_player)) + ")")
	
	# If the first player is AI, trigger AI placement immediately
	if is_player_computer(current_player):
		DebugLogger.log("GameInit", "First player is AI - starting automatic placement...")
		# Use a small delay to ensure all systems are ready
		await get_tree().create_timer(1.0).timeout
		await _handle_ai_castle_placement(current_player)

func _process_round_start_actions():
	"""Process actions that happen once per round (when first active player starts)."""
	DebugLogger.log("TurnProcessing", "Processing round start actions...")
	_update_average_army_power()
	
	# Increment ownership counters for all owned regions
	DebugLogger.log("TurnProcessing", "Incrementing ownership counters...")
	if _region_manager:
		_region_manager.increment_all_ownership_counters()
	
	# Grow population for all regions (before recruit replenishment)
	DebugLogger.log("TurnProcessing", "Growing regional populations...")
	if _region_manager:
		_region_manager.grow_all_populations()
	
	# Replenish recruits for all regions (after population growth)
	DebugLogger.log("TurnProcessing", "Replenishing recruits...")
	if _region_manager:
		_region_manager.replenish_all_recruits()
	
	# Reset per-turn region action usage for all regions
	DebugLogger.log("TurnProcessing", "Resetting region turn usage flags...")
	if _region_manager:
		_region_manager.reset_all_ore_search_turn_usage()
	
	# Reset movement points for all armies
	reset_movement_points()

func _update_average_army_power() -> void:
	var armies: Array[Army] = _army_manager.get_all_armies()
	if armies.is_empty():
		average_army_power = 0.0
		return
	var total_power: int = 0
	for army in armies:
		total_power += army.get_army_power()
	average_army_power = float(total_power) / float(armies.size())

func get_average_army_power() -> float:
	return average_army_power

func _process_player_turn_start(player_id: int):
	"""Process actions that happen at the start of each player's turn"""
	DebugLogger.log("TurnProcessing", "Processing turn start for Player " + str(player_id) + "...")
	if player_manager:
		player_manager.decay_enemy_memory_for_player(player_id)
		player_manager.decay_traded_resources_for_player(player_id, GameParameters.TRADE_RESET_RATE)
	if _region_manager:
		_region_manager.process_castle_progress_for_player(player_id)
		_region_manager.heal_wounded_for_player(player_id)
		_region_manager.decrement_promotion_cooldowns_for_player(player_id)
	if _army_manager:
		_army_manager.set_ready_highlight_player(player_id)
	var initial_turn := not _player_initial_turn_completed.has(player_id)
	if initial_turn:
		_player_initial_turn_completed[player_id] = false
		DebugLogger.log("TurnProcessing", "Skipping economy for Player " + str(player_id) + " (initial turn)")
		_update_player_status_display()
		return
	DebugLogger.log("TurnProcessing", "Processing resource income for Player " + str(player_id) + "...")
	player_manager.process_resource_income_for_player(player_id)
	DebugLogger.log("TurnProcessing", "Deducting army food costs for Player " + str(player_id) + "...")
	_process_army_food_costs_for_player(player_id)
	var famine_result: Dictionary = consume_latest_famine_result_for_player(player_id)
	_player_initial_turn_completed[player_id] = true
	_update_player_status_display()
	await _show_turn_start_famine_message_if_needed(player_id, famine_result)
 
func _process_turn_start_autosave(player_id: int) -> void:
	if castle_placing_mode:
		return
	if not is_player_human(player_id):
		return
	var autosave_ok: bool = SaveGameManager.save_auto_save(self)
	if autosave_ok:
		DebugLogger.log("SaveGame", "Autosave updated: " + ProjectSettings.globalize_path(SaveGameManager.AUTOSAVE_FILE_PATH))
	else:
		DebugLogger.log("SaveGame", "ERROR: Failed to update autosave")


func reset_movement_points():
	"""Reset movement points for all armies on the map"""

	if click_manager != null:
		var army_manager = click_manager.get_army_manager()
		if army_manager != null:

			army_manager.reset_all_army_movement_points()
		else:
			DebugLogger.log("TurnProcessing", "Warning: Cannot reset army moves - ArmyManager not found")
	else:
		DebugLogger.log("TurnProcessing", "Warning: Cannot reset army moves - ClickManager not found")

func _process_army_food_costs_for_player(player_id: int) -> void:
	"""Process food costs for armies and garrisons for a specific player"""
	var player: Player = player_manager.get_player(player_id)
	if player == null:
		DebugLogger.log("TurnProcessing", "Warning: Player " + str(player_id) + " not found for food cost processing")
		return
	
	# Calculate total food cost for all armies and garrisons
	var total_food_cost: float = player_manager.calculate_total_army_food_cost(player_id)
	
	if total_food_cost > 0:
		# Convert float cost to integer (round up)
		var food_cost_int: int = int(ceil(total_food_cost))
		
		DebugLogger.log("TurnProcessing", "Total army food cost for Player " + str(player_id) + ": " + str(total_food_cost) + " (rounded: " + str(food_cost_int) + ")")
		
		# Check if player has enough food
		var current_food: int = player.get_resource_amount(ResourcesEnum.Type.FOOD)
		var net_food_after: int = current_food - food_cost_int
		if net_food_after >= 0:
			player.set_resource_amount(ResourcesEnum.Type.FOOD, net_food_after)
			DebugLogger.log("TurnProcessing", "Deducted " + str(food_cost_int) + " food from Player " + str(player_id) + " (" + str(net_food_after) + " remaining)")
			_latest_famine_result_by_player.erase(player_id)
		else:
			DebugLogger.log("TurnProcessing", "WARNING: Player " + str(player_id) + " doesn't have enough food! Required: " + str(food_cost_int) + ", Available: " + str(current_food))
			var shortage: float = max(0.0, total_food_cost - float(current_food))
			player.set_resource_amount(ResourcesEnum.Type.FOOD, 0)
			if shortage > 0.0:
				DebugLogger.log("TurnProcessing", "Triggering famine for Player " + str(player_id) + " (food deficit: " + str(snappedf(shortage, 0.01)) + ")")
				var famine_result: Dictionary = famine_regions(player_id, shortage)
				_latest_famine_result_by_player[player_id] = famine_result
	else:
		DebugLogger.log("TurnProcessing", "No army food costs for Player " + str(player_id))
		_latest_famine_result_by_player.erase(player_id)

func famine_regions(player_id: int, missing_food: float) -> Dictionary:
	var clamped_missing_food: float = max(0.0, missing_food)
	var result: Dictionary = {
		"triggered": clamped_missing_food > 0.0,
		"player_id": player_id,
		"food_deficit": snappedf(clamped_missing_food, 0.01),
		"target_points": 0,
		"actual_points_removed": 0,
		"soldiers_lost": 0,
		"by_force": [],
		"by_unit_type": {}
	}
	if clamped_missing_food <= 0.0:
		return result
	
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var target_points: int = _roll_famine_points(clamped_missing_food, rng)
	result["target_points"] = target_points
	if target_points <= 0:
		return result
	
	var force_entries: Array[Dictionary] = _build_famine_force_entries(player_id)
	if force_entries.is_empty():
		DebugLogger.log("TurnProcessing", "Famine skipped for Player " + str(player_id) + " - no eligible army or garrison units")
		return result
	
	var total_force_points: int = 0
	for force_entry in force_entries:
		total_force_points += int(force_entry.get("upkeep_points", 0))
	if total_force_points <= 0:
		return result
	
	var points_to_apply: int = min(target_points, total_force_points)
	_allocate_points_proportionally(force_entries, points_to_apply, "upkeep_points", "allocated_points", rng)
	
	var by_force: Array = []
	var by_unit_type: Dictionary = {}
	var actual_points_removed: int = 0
	var soldiers_lost: int = 0
	for idx in range(force_entries.size()):
		var force_entry: Dictionary = force_entries[idx]
		var force_result: Dictionary = _apply_famine_points_to_force(force_entry, rng)
		var removed_points: int = int(force_result.get("removed_points", 0))
		var force_soldiers_lost: int = int(force_result.get("soldiers_lost", 0))
		var removed_units: Dictionary = force_result.get("removed_units", {})
		force_entry["removed_points"] = removed_points
		force_entry["soldiers_lost"] = force_soldiers_lost
		force_entry["removed_units"] = removed_units
		force_entries[idx] = force_entry
		actual_points_removed += removed_points
		soldiers_lost += force_soldiers_lost
		for unit_name in removed_units.keys():
			by_unit_type[unit_name] = int(by_unit_type.get(unit_name, 0)) + int(removed_units[unit_name])
		by_force.append({
			"force_id": String(force_entry.get("force_id", "")),
			"force_type": String(force_entry.get("force_type", "")),
			"force_name": String(force_entry.get("force_name", "")),
			"region_id": int(force_entry.get("region_id", -1)),
			"region_name": String(force_entry.get("region_name", "")),
			"allocated_points": int(force_entry.get("allocated_points", 0)),
			"removed_points": removed_points,
			"soldiers_lost": force_soldiers_lost,
			"units": removed_units
		})
	
	_army_manager.remove_destroyed_armies()
	result["actual_points_removed"] = actual_points_removed
	result["soldiers_lost"] = soldiers_lost
	result["by_force"] = by_force
	result["by_unit_type"] = by_unit_type
	DebugLogger.log("TurnProcessing", "Famine resolved for Player " + str(player_id) + ": " + str(soldiers_lost) + " soldiers died")
	return result

func get_latest_famine_result_for_player(player_id: int) -> Dictionary:
	var stored_result: Dictionary = _latest_famine_result_by_player.get(player_id, {})
	return stored_result.duplicate(true)

func consume_latest_famine_result_for_player(player_id: int) -> Dictionary:
	var stored_result: Dictionary = _latest_famine_result_by_player.get(player_id, {})
	var result: Dictionary = stored_result.duplicate(true)
	_latest_famine_result_by_player.erase(player_id)
	return result

func _show_turn_start_famine_message_if_needed(player_id: int, famine_result: Dictionary) -> void:
	if famine_result.is_empty():
		return
	if not bool(famine_result.get("triggered", false)):
		return
	if not is_player_human(player_id):
		return
	var soldiers_lost: int = int(famine_result.get("soldiers_lost", 0))
	var header_text: String = tr("Famine strikes your armies.")
	var body_text: String = tr("%d soldiers died from starvation.") % soldiers_lost
	_message_modal.display_message(header_text, body_text)
	await _message_modal.continue_clicked

func _build_famine_force_entries(player_id: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	var owned_region_ids: Array[int] = _region_manager.get_player_regions(player_id)
	for region_id in owned_region_ids:
		var region: Region = map_generator.get_region_container_by_id(region_id) as Region
		var garrison: ArmyComposition = region.get_garrison()
		var garrison_points: int = _get_composition_famine_points(garrison)
		if garrison_points <= 0:
			continue
		entries.append({
			"force_id": "garrison_%d" % region_id,
			"force_type": "garrison",
			"force_name": "Garrison " + region.get_region_name(),
			"region_id": region_id,
			"region_name": region.get_region_name(),
			"composition": garrison,
			"upkeep_points": garrison_points,
			"allocated_points": 0,
			"removed_points": 0,
			"soldiers_lost": 0,
			"removed_units": {}
		})
	
	var player_armies: Array[Army] = _army_manager.get_player_armies(player_id)
	for army in player_armies:
		var region: Region = army.get_parent() as Region
		var composition: ArmyComposition = army.get_composition()
		var army_points: int = _get_composition_famine_points(composition)
		if army_points <= 0:
			continue
		entries.append({
			"force_id": "army_%d" % army.get_instance_id(),
			"force_type": "army",
			"force_name": army.get_display_name(),
			"region_id": region.get_region_id(),
			"region_name": region.get_region_name(),
			"composition": composition,
			"upkeep_points": army_points,
			"allocated_points": 0,
			"removed_points": 0,
			"soldiers_lost": 0,
			"removed_units": {}
		})
	
	return entries

func _get_composition_famine_points(composition: ArmyComposition) -> int:
	var total_points: int = 0
	for unit_type in SoldierTypeEnum.get_all_types():
		var count: int = composition.get_soldier_count(unit_type)
		if count <= 0:
			continue
		var unit_points: int = _get_unit_famine_points(unit_type)
		if unit_points <= 0:
			continue
		total_points += count * unit_points
	return total_points

func _get_unit_famine_points(unit_type: SoldierTypeEnum.Type) -> int:
	var food_cost: float = float(GameParameters.get_unit_food_cost(unit_type))
	return max(0, int(round(food_cost * FAMINE_POINTS_PER_FOOD)))

func _roll_famine_points(missing_food: float, rng: RandomNumberGenerator) -> int:
	var clamped_missing_food: float = max(0.0, missing_food)
	if clamped_missing_food <= 0.0:
		return 0
	var lookup_points: int = _roll_famine_lookup_points(rng)
	var target_points: int = int(floor(clamped_missing_food * float(lookup_points)))
	return max(0, target_points)

func _roll_famine_lookup_points(rng: RandomNumberGenerator) -> int:
	var roll: int = rng.randi_range(1, FAMINE_POINTS_LOOKUP_BY_ROLL.size())
	return int(FAMINE_POINTS_LOOKUP_BY_ROLL[roll - 1])

func _allocate_points_proportionally(entries: Array[Dictionary], points_to_allocate: int, capacity_key: String, allocation_key: String, rng: RandomNumberGenerator) -> int:
	if points_to_allocate <= 0 or entries.is_empty():
		return 0
	
	var total_capacity: int = 0
	for idx in range(entries.size()):
		var entry: Dictionary = entries[idx]
		var capacity: int = max(0, int(entry.get(capacity_key, 0)))
		entry[allocation_key] = 0
		entry["_fraction"] = 0.0
		entries[idx] = entry
		total_capacity += capacity
	if total_capacity <= 0:
		return 0
	
	var target: int = min(points_to_allocate, total_capacity)
	var floor_sum: int = 0
	for idx in range(entries.size()):
		var entry: Dictionary = entries[idx]
		var capacity: int = max(0, int(entry.get(capacity_key, 0)))
		if capacity <= 0:
			continue
		var share_float: float = float(target) * float(capacity) / float(total_capacity)
		var floor_alloc: int = min(capacity, int(floor(share_float)))
		entry[allocation_key] = floor_alloc
		entry["_fraction"] = share_float - float(floor_alloc)
		entries[idx] = entry
		floor_sum += floor_alloc
	
	var remainder: int = max(0, target - floor_sum)
	while remainder > 0:
		var candidate_indexes: Array[int] = []
		var candidate_weights: Array[float] = []
		var has_fraction_weight: bool = false
		for idx in range(entries.size()):
			var entry: Dictionary = entries[idx]
			var capacity: int = max(0, int(entry.get(capacity_key, 0)))
			var allocated: int = max(0, int(entry.get(allocation_key, 0)))
			if allocated >= capacity:
				continue
			candidate_indexes.append(idx)
			var weight: float = max(0.0, float(entry.get("_fraction", 0.0)))
			if weight > 0.0:
				has_fraction_weight = true
			candidate_weights.append(weight)
		if candidate_indexes.is_empty():
			break
		if not has_fraction_weight:
			candidate_weights.clear()
			for candidate_idx in candidate_indexes:
				var fallback_entry: Dictionary = entries[candidate_idx]
				var fallback_capacity: int = max(0, int(fallback_entry.get(capacity_key, 0)))
				var fallback_allocated: int = max(0, int(fallback_entry.get(allocation_key, 0)))
				candidate_weights.append(float(max(1, fallback_capacity - fallback_allocated)))
		var picked_local_idx: int = _pick_weighted_index(candidate_weights, rng)
		var picked_entry_idx: int = candidate_indexes[picked_local_idx]
		var picked_entry: Dictionary = entries[picked_entry_idx]
		picked_entry[allocation_key] = int(picked_entry.get(allocation_key, 0)) + 1
		entries[picked_entry_idx] = picked_entry
		remainder -= 1
	
	for idx in range(entries.size()):
		var clean_entry: Dictionary = entries[idx]
		clean_entry.erase("_fraction")
		entries[idx] = clean_entry
	return target - remainder

func _pick_weighted_index(weights: Array[float], rng: RandomNumberGenerator) -> int:
	if weights.is_empty():
		return 0
	var total_weight: float = 0.0
	for weight in weights:
		total_weight += max(0.0, float(weight))
	if total_weight <= 0.0:
		return rng.randi_range(0, weights.size() - 1)
	var roll: float = rng.randf() * total_weight
	var cumulative: float = 0.0
	for idx in range(weights.size()):
		cumulative += max(0.0, float(weights[idx]))
		if roll <= cumulative:
			return idx
	return weights.size() - 1

func _apply_famine_points_to_force(force_entry: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var allocated_points: int = max(0, int(force_entry.get("allocated_points", 0)))
	if allocated_points <= 0:
		return {"removed_points": 0, "soldiers_lost": 0, "removed_units": {}}
	
	var composition: ArmyComposition = force_entry.get("composition") as ArmyComposition
	var unit_entries: Array[Dictionary] = []
	var total_unit_points: int = 0
	for unit_type in SoldierTypeEnum.get_all_types():
		var count: int = composition.get_soldier_count(unit_type)
		if count <= 0:
			continue
		var point_cost: int = _get_unit_famine_points(unit_type)
		if point_cost <= 0:
			continue
		var max_points: int = count * point_cost
		unit_entries.append({
			"unit_type": unit_type,
			"count": count,
			"point_cost": point_cost,
			"max_points": max_points,
			"allocated_points": 0,
			"remove_units": 0,
			"residue_weight": 0.0
		})
		total_unit_points += max_points
	if total_unit_points <= 0:
		return {"removed_points": 0, "soldiers_lost": 0, "removed_units": {}}
	
	var points_to_apply: int = min(allocated_points, total_unit_points)
	_allocate_points_proportionally(unit_entries, points_to_apply, "max_points", "allocated_points", rng)
	
	var removed_points: int = 0
	for idx in range(unit_entries.size()):
		var unit_entry: Dictionary = unit_entries[idx]
		var point_cost: int = int(unit_entry.get("point_cost", 0))
		var count: int = int(unit_entry.get("count", 0))
		var allocated_unit_points: int = int(unit_entry.get("allocated_points", 0))
		var base_remove: int = min(count, allocated_unit_points / point_cost)
		unit_entry["remove_units"] = base_remove
		unit_entry["residue_weight"] = float(allocated_unit_points - (base_remove * point_cost))
		unit_entries[idx] = unit_entry
		removed_points += base_remove * point_cost
	
	var remaining_points: int = max(0, points_to_apply - removed_points)
	while remaining_points > 0:
		var candidate_indexes: Array[int] = []
		var candidate_weights: Array[float] = []
		for idx in range(unit_entries.size()):
			var unit_entry: Dictionary = unit_entries[idx]
			var point_cost: int = int(unit_entry.get("point_cost", 0))
			var count: int = int(unit_entry.get("count", 0))
			var removed_units: int = int(unit_entry.get("remove_units", 0))
			if removed_units >= count:
				continue
			if point_cost > remaining_points:
				continue
			candidate_indexes.append(idx)
			candidate_weights.append(max(0.1, 0.1 + float(unit_entry.get("residue_weight", 0.0))))
		if candidate_indexes.is_empty():
			break
		var picked_local_idx: int = _pick_weighted_index(candidate_weights, rng)
		var picked_entry_idx: int = candidate_indexes[picked_local_idx]
		var picked_entry: Dictionary = unit_entries[picked_entry_idx]
		var picked_cost: int = int(picked_entry.get("point_cost", 0))
		picked_entry["remove_units"] = int(picked_entry.get("remove_units", 0)) + 1
		unit_entries[picked_entry_idx] = picked_entry
		removed_points += picked_cost
		remaining_points -= picked_cost
	
	var soldiers_lost: int = 0
	var removed_units_summary: Dictionary = {}
	for unit_entry in unit_entries:
		var remove_units: int = int(unit_entry.get("remove_units", 0))
		if remove_units <= 0:
			continue
		var unit_type: SoldierTypeEnum.Type = int(unit_entry.get("unit_type", SoldierTypeEnum.Type.PEASANTS))
		composition.remove_soldiers(unit_type, remove_units)
		soldiers_lost += remove_units
		var unit_name: String = SoldierTypeEnum.type_to_string(unit_type)
		removed_units_summary[unit_name] = int(removed_units_summary.get(unit_name, 0)) + remove_units
	
	return {
		"removed_points": removed_points,
		"soldiers_lost": soldiers_lost,
		"removed_units": removed_units_summary
	}

func has_completed_initial_turn(player_id: int) -> bool:
	return _player_initial_turn_completed.get(player_id, false)

func _update_player_status_display() -> void:
	"""Update the player status display when resources or player changes"""
	DebugLogger.log("TurnProcessing", "Updating player status display...")

	_emit_player_status_refresh()
	var ui_node = get_node("../UI")
	var turn_modal = ui_node.get_node("TurnModal") as TurnModal

	DebugLogger.log("TurnProcessing", "Calling turn modal update")
	if turn_modal:
		turn_modal.refresh_from_game_state()

func request_player_status_refresh() -> void:
	_emit_player_status_refresh()

func _emit_player_status_refresh() -> void:
	GlobalSignals.emit_signal("player_status_refresh_requested")

func _should_show_player_status_panel(player_id: int) -> bool:
	return debug_mode or (not castle_placing_mode and not is_player_computer(player_id))

func _set_player_status_panel_visibility(player_id: int, ui_node: Node) -> void:
	var player_status_modal2 = ui_node.get_node("PlayerStatusModal2") as PlayerStatusModal2
	player_status_modal2.set_panel_visible(_should_show_player_status_panel(player_id))

func _apply_debug_ui_visibility_for_player(player_id: int) -> void:
	var hide_ai_ui = (not debug_mode) and is_player_computer(player_id)
	var ui_node = get_node("../UI")
	_set_player_status_panel_visibility(player_id, ui_node)
	var icons_modal = ui_node.get_node("IconsModal") as Control
	var turn_modal = ui_node.get_node("TurnModal") as TurnModal
	var speed_modal = ui_node.get_node("SpeedModal") as Control
	if turn_modal:
		turn_modal.set_end_turn_button_visible(not hide_ai_ui)
	if icons_modal:
		icons_modal.visible = not hide_ai_ui
	if speed_modal:
		speed_modal.visible = is_player_computer(player_id) and not castle_placing_mode

func _on_current_player_changed(player_id: int) -> void:
	"""Handle player change signal by refreshing UI and showing next player modal"""
	DebugLogger.log("TurnProcessing", "Player changed to " + str(player_id) + " - refreshing UI and showing next player modal")
	_apply_debug_ui_visibility_for_player(player_id)
	
	# Update player status display
	_update_player_status_display()
	
	# Center camera on player's first army or castle (only for human players),
	# but never recenter while a battle is active
	if is_player_human(player_id) and not castle_placing_mode and _active_battles == 0:
		_center_camera_on_player_assets(player_id)
	
	# Show next player modal only for human turns when 2+ humans are active.
	if _next_player_modal and not castle_placing_mode and is_player_active(player_id) and is_player_human(player_id) and _should_show_next_player_modal():
		var require_ack: bool = _should_require_next_player_modal_ack(player_id)
		if require_ack:
			var ui_node = get_node("../UI")
			var player_status_modal2 = ui_node.get_node("PlayerStatusModal2") as PlayerStatusModal2
			player_status_modal2.set_panel_visible(false)
		_next_player_modal.show_next_player(player_id, current_turn, require_ack)
	
	DebugLogger.log("TurnProcessing", "Round " + str(current_turn) + " - Player " + str(player_id) + "'s turn")

func _on_next_player_modal_continue_acknowledged(player_id: int) -> void:
	var ui_node = get_node("../UI")
	_set_player_status_panel_visibility(player_id, ui_node)

func get_current_turn() -> int:
	"""Get the current turn number"""
	return current_turn

func get_current_player() -> int:
	"""Get the current player number"""
	return current_player

func get_total_players() -> int:
	"""Get the total number of players"""
	return total_players

# Player type management
func get_player_type(player_id: int) -> PlayerTypeEnum.Type:
	"""Get the type of a specific player"""
	if player_id >= 1 and player_id <= player_types.size():
		return player_types[player_id - 1]  # Convert 1-based to 0-based index
	return PlayerTypeEnum.Type.OFF

func get_starting_army_composition_for_player(player_id: int) -> Dictionary:
	"""Get starting army composition for the given player's control type"""
	return GameParameters.get_starting_army_composition_for_player_type_with_difficulty(get_player_type(player_id), game_difficulty)

func get_game_difficulty() -> int:
	return game_difficulty

func _apply_starting_resources_for_difficulty() -> void:
	for i in range(player_types.size()):
		var player_type: PlayerTypeEnum.Type = player_types[i]
		if player_type == PlayerTypeEnum.Type.OFF:
			continue
		var player_id: int = i + 1
		var resources_data: Dictionary = {}
		for resource_type in ResourcesEnum.get_all_types():
			var resource_key: String = ResourcesEnum.type_to_string(resource_type)
			var amount: int = GameParameters.get_starting_resource_amount_for_difficulty(resource_type, game_difficulty)
			resources_data[resource_key] = amount
		player_manager.set_player_resources(player_id, resources_data)

func is_player_active(player_id: int) -> bool:
	"""Check if a player is active (not OFF)"""
	return get_player_type(player_id) != PlayerTypeEnum.Type.OFF

func is_player_human(player_id: int) -> bool:
	"""Check if a player is human controlled"""
	return get_player_type(player_id) == PlayerTypeEnum.Type.HUMAN

func is_player_computer(player_id: int) -> bool:
	"""Check if a player is AI controlled"""
	return get_player_type(player_id) == PlayerTypeEnum.Type.COMPUTER

func _get_human_player_count() -> int:
	var human_players: int = 0
	for player_id in range(1, total_players + 1):
		if is_player_human(player_id):
			human_players += 1
	return human_players

func _should_show_next_player_modal() -> bool:
	return true

func _should_require_next_player_modal_ack(player_id: int) -> bool:
	return is_player_human(player_id) and _get_human_player_count() > 1

func is_player_ai(player_id: int) -> bool:
	"""Check if a player is AI controlled (alias for is_player_computer)"""
	return is_player_computer(player_id)

# Battle resolution is now handled directly within AI army movement - these functions are no longer needed


func _handle_ai_castle_placement(player_id: int) -> void:
	"""Handle AI castle placement by selecting highest scored region with randomness"""
	if not _ai_castle_placement_scorer:
		DebugLogger.log("GameInit", "Error: AI castle placement scorer not available")
		return
	
	# Get all owned regions to calculate enemy distances
	var owned_regions: Array[int] = []
	var regions_node = get_node("../Map/Regions")
	if regions_node:
		for child in regions_node.get_children():
			if child is Region:
				var region = child as Region
				var owner = region.get_region_owner()
				if owner > 0:  # Any owned region
					owned_regions.append(region.get_region_id())
	
	# Score all castle placement candidates
	var scored_candidates = _ai_castle_placement_scorer.score_castle_placement_candidates(owned_regions)
	
	if scored_candidates.is_empty():
		DebugLogger.log("GameInit", "No valid castle placement candidates for AI Player " + str(player_id))
		return
	
	# Apply random modifier to each region's score (fresh random value for each region)
	for candidate in scored_candidates:
		var random_modifier = randf() * GameParameters.AI_RANDOM_SCORE_MODIFIER
		candidate.OverallScore += random_modifier / 100.0  # Convert to 0-1 scale to match OverallScore
	
	# Sort again after applying random modifiers
	scored_candidates.sort_custom(func(a, b): return a.OverallScore > b.OverallScore)
	
	# Select the highest scored region (now with randomness applied)
	var best_candidate = scored_candidates[0]
	var best_region_id = best_candidate.regionId
	var best_score = best_candidate.OverallScore
	
	DebugLogger.log("GameInit", "AI Player " + str(player_id) + " selecting region " + str(best_region_id) + " with final score " + str(snappedf(best_score * 100, 0.1)) + " (includes random modifier)")
	
	# Find the region and place castle
	if regions_node:
		for child in regions_node.get_children():
			if child is Region and child.get_region_id() == best_region_id:
				await _ai_camera_director.await_focus_on_region(child)
				await _ai_camera_director.await_delay(GameParameters.CAMERA_ARMY_START_DELAY)
				await handle_castle_placement(child)
				break

# Player resource management
func get_player_manager() -> PlayerManagerNode:
	"""Get the player manager instance"""
	return player_manager

func record_enemy_army_power(observer_id: int, enemy_army: Army) -> void:
	if player_manager == null:
		return
	player_manager.record_enemy_army_power(observer_id, enemy_army)

func record_enemy_garrison(observer_id: int, region_id: int, power: int) -> void:
	if player_manager == null:
		return
	player_manager.record_enemy_garrison(observer_id, region_id, power)

func get_current_player_data() -> Player:
	"""Get the current player's data"""
	if player_manager == null:
		return null
	return player_manager.get_current_player()

func get_player_resources(player_id: int) -> Dictionary:
	"""Get all resources for a specific player"""
	if player_manager == null:
		return {}
	var player = player_manager.get_player(player_id)
	if player == null:
		return {}
	return player.get_all_resources()

func add_player_resources(player_id: int, resource_type: ResourcesEnum.Type, amount: int) -> bool:
	"""Add resources to a player"""
	if player_manager == null:
		return false
	return player_manager.add_resources_to_player(player_id, resource_type, amount)

func can_player_afford(player_id: int, cost: Dictionary) -> bool:
	"""Check if a player can afford a cost"""
	if player_manager == null:
		return false
	return player_manager.can_player_afford_cost(player_id, cost)

func charge_player(player_id: int, cost: Dictionary) -> bool:
	"""Charge a player for a cost"""
	if player_manager == null:
		return false
	return player_manager.charge_player(player_id, cost)

# Game state accessors
func is_castle_placing_mode() -> bool:
	"""Check if the game is in castle placing mode"""
	return castle_placing_mode

func set_castle_placing_mode(enabled: bool) -> void:
	"""Set castle placing mode"""
	castle_placing_mode = enabled

func set_ai_step_requires_shift(enabled: bool) -> void:
	"""Enable or disable manual shift gating for AI steps"""
	ai_step_requires_shift = enabled
	if _turn_controller != null and _turn_controller.debug_step_gate:
		_turn_controller.debug_step_gate.set_debug_enabled(enabled)

func get_current_player_id() -> int:
	"""Get the current active player ID"""
	return current_player

func set_armies_per_castle(count: int):
	"""Set the number of armies to create per castle (for scenario/difficulty configuration)"""
	armies_per_castle = max(1, count)  # Ensure at least 1 army
	DebugLogger.log("GameInit", "Set armies per castle to " + str(armies_per_castle))

func get_armies_per_castle() -> int:
	"""Get the number of armies created per castle"""
	return armies_per_castle

# Game flow coordination
func can_place_castle_in_region(region: Region) -> bool:
	"""Check if a castle can be placed in the given region"""
	if not castle_placing_mode:
		return false
	
	if region == null:
		return false
	
	var region_id = region.get_region_id()
	
	# Check if region is already owned by another player
	if _region_manager:
		var current_owner = _region_manager.get_region_owner(region_id)
		if current_owner != -1 and current_owner != current_player:
			return false
	
	return true

func handle_castle_placement(region: Region) -> void:
	"""Coordinate the complete castle placement flow"""
	if not castle_placing_mode:
		return
	
	# Validate placement first
	if not can_place_castle_in_region(region):
		DebugLogger.log("GameInit", "Castle placement failed - region already owned by another player")
		return
		
	var region_id = region.get_region_id()
	
	# Set castle starting position (this will also claim neighboring regions)
	var placement_successful = false
	if _region_manager:
		placement_successful = _region_manager.set_castle_starting_position(region_id, current_player)
	
	if not placement_successful:
		DebugLogger.log("GameInit", "Castle placement failed - unexpected error")
		return

	if _sound_manager:
		_sound_manager.click_sound()
	
	# Upgrade castle region and neighboring regions
	if _region_manager:
		_region_manager.upgrade_castle_regions(region)
	
	# Update region visuals to show ownership
	if _visual_manager:
		_visual_manager.update_region_visuals()
	
	# Build initial castle (Outpost) using new castle system
	if _region_manager:
		var regions_node = get_node("../Map/Regions")
		for child in regions_node.get_children():
			if child is Region and child.get_region_id() == region_id:
				# Set castle type directly for initial placement
				child.set_castle_type(CastleTypeEnum.Type.KEEP)
				# Place visual using new system
				if _visual_manager:
					_visual_manager.place_castle_visual(child)
				break
	
	# Place multiple armies in the same region
	if _visual_manager:
		var regions_node = get_node("../Map/Regions")
		for child in regions_node.get_children():
			if child is Region and child.get_region_id() == region_id:
				# Place the configured number of armies
				for i in range(armies_per_castle):
					_visual_manager.place_army_visual(child, current_player)
				DebugLogger.log("GameInit", "Placed " + str(armies_per_castle) + " armies for Player " + str(current_player) + " in region " + str(region_id))
				break
	
	if is_player_computer(current_player) and _ai_camera_director:
		await _ai_camera_director.await_delay(GameParameters.CAMERA_CONQUEST_DELAY)
		await _ai_camera_director.await_delay(GameParameters.CAMERA_FRIENDLY_MOVE_DELAY)

	# Track castle placement order and advance to next player
	castle_placement_order.append(current_player)
	castles_placed += 1
	DebugLogger.log("GameInit", "Player " + str(current_player) + " placed castle (" + str(castles_placed) + "/" + str(total_players) + ")")
	
	# Check if all active players have placed castles
	var active_players_count = 0
	for i in range(1, total_players + 1):
		if is_player_active(i):
			active_players_count += 1
	
	if castles_placed >= active_players_count:
		# All active players placed castles - end castle placing mode and start normal gameplay
		castle_placing_mode = false
		DebugLogger.log("GameInit", "All active players have placed castles. Game begins!")

		# Show PlayerStatusModal2 and IconsModal now that castle placement is done
		var ui_node = get_node("../UI")
		var icons_modal = ui_node.get_node("IconsModal") as Control
		if icons_modal:
			icons_modal.visible = true

		# Switch AI debug visualizer to army target mode
		if _ai_debug_visualizer:
			_ai_debug_visualizer.switch_to_army_target_mode()
		DebugLogger.log("GameInit", "Switched AI debug visualizer to army target scoring mode")

		# Set current player to first active player to start normal gameplay
		current_player = _get_first_active_player()
		player_manager.set_current_player(current_player)
		_set_player_status_panel_visibility(current_player, ui_node)
		
		# Start the first turn of normal gameplay
		DebugLogger.log("GameInit", "Starting first turn of normal gameplay...")
		await get_tree().create_timer(0.5).timeout  # Brief delay for UI updates
		_start_first_turn()
		return
	
	await _advance_castle_placement_turn()

func _advance_castle_placement_turn() -> void:
	# Move to next active player for castle placement
	current_player = _get_next_active_player()
	player_manager.set_current_player(current_player)
	DebugLogger.log("GameInit", "Next player to place castle: Player " + str(current_player) + " (" + PlayerTypeEnum.type_to_string(get_player_type(current_player)) + ")")
	
	# Handle different player types
	if is_player_computer(current_player):
		# AI player - automatically place castle using AI system
		DebugLogger.log("GameInit", "AI Player " + str(current_player) + " placing castle automatically...")
		# Use a short delay to allow visuals to update
		await get_tree().create_timer(0.5).timeout
		await _handle_ai_castle_placement(current_player)
	# OFF players are skipped by _get_next_active_player()
	
	# Show turn modal but hide PlayerStatusModal2 and IconsModal during castle placement
	var ui_node = get_node("../UI")
	var turn_modal = ui_node.get_node("TurnModal") as TurnModal
	var icons_modal = ui_node.get_node("IconsModal") as Control
	_set_player_status_panel_visibility(current_player, ui_node)
	if turn_modal:
		turn_modal.show_and_update()
	
	# Update AI debug scores if debug mode is active (for next player's perspective)
	if _ai_debug_visualizer and _ai_debug_visualizer.is_debug_visible():
		# Get the next player who will be placing a castle
		var next_player_for_scoring = current_player
		if castles_placed < total_players:
			next_player_for_scoring = _get_next_player()
		
		DebugLogger.log("GameInit", "Recalculating AI debug scores for Player " + str(next_player_for_scoring) + " after castle placement")
		_ai_debug_visualizer._update_scores_for_player(next_player_for_scoring)
		_ai_debug_visualizer.queue_redraw()
	
func _should_trigger_battle(army: Army, target_region: Region) -> bool:
	"""
	Centralized pure helper to determine if a battle is required.
	Returns true if entering the region should trigger a battle.
	No side effects - pure logic only.
	"""
	if army == null or target_region == null:
		return false
	
	var region_owner = _region_manager.get_region_owner(target_region.get_region_id())
	var army_player_id = army.get_player_id()
	
	# Battle if region is owned by different player
	if region_owner != -1 and region_owner != army_player_id:
		return true
	
	# Battle if neutral region has a garrison
	if region_owner == -1 and target_region.has_defenders():
		return true
	
	return false

func should_show_prebattle_for_army(army: Army) -> bool:
	return is_player_human(army.get_player_id())

func show_prebattle_modal(army: Army, target_region: Region) -> void:
	if _prebattle_modal.is_showing_for(army, target_region):
		return
	_prebattle_modal.show_prebattle(army, target_region)

func handle_prebattle_attack(army: Army, target_region: Region, siege_payload: Dictionary = {}) -> void:
	var attacker_effectiveness_ratio: float = _compute_attacker_effectiveness_ratio(army, siege_payload, target_region)
	_battle_manager.start_battle(army, target_region.get_region_id(), attacker_effectiveness_ratio, siege_payload)

func handle_prebattle_withdraw(army: Army) -> void:
	await _battle_manager.withdraw_attacking_army(army)

func perform_region_entry(army: Army, target_region_id: int, source: String) -> String:
	"""
	Shared orchestration function for Human and AI region entry flow.
	Returns: "blocked" | "moved" | "battle_started"
	"""
	DebugLogger.log("TurnProcessing", "perform_region_entry: " + army.get_display_name() + " -> region " + str(target_region_id) + " (source: " + source + ")")
	
	# Resolve target region Node using RegionManager lookup
	var target_region = _region_manager.map_generator.get_region_container_by_id(target_region_id) as Region
	if target_region == null:
		DebugLogger.log("TurnProcessing", "Error: Target region not found")
		return "blocked"
	
	# Call ArmyManager.move_army
	var move_success = await _army_manager.move_army(army, target_region)
	if not move_success:
		return "blocked"
	
	# Use centralized helper to decide if battle is required
	var battle_needed = _should_trigger_battle(army, target_region)
	
	if battle_needed:
		if source == "human":
			if should_show_prebattle_for_army(army):
				show_prebattle_modal(army, target_region)
				return "battle_started"
		elif source == "ai":
			# For AI: use non-UI resolution (direct battle handling)
			var result: String = await handle_army_battle(army, target_region.get_region_id())
			if result == "victory":
				check_victory_conditions_for_player(army.get_player_id())
				return "battle_victory"
			elif result == "withdrawal":
				return "battle_withdrawal"
			else:
				return "battle_defeat"

	check_victory_conditions_for_player(army.get_player_id())
	return "moved"

# Battle coordination - unified system for both Human and AI players
func handle_army_battle(army: Army, target_region_id: int) -> String:
	"""
	Unified battle handling for both Human and AI players
	Returns: 'victory', 'defeat', or 'withdrawal'
	"""
	var attacker_owner_id := army.get_player_id()
	var target_region := _region_manager.map_generator.get_region_container_by_id(target_region_id) as Region
	DebugLogger.log("TurnProcessing", "Starting unified battle for " + army.get_display_name() + " vs region " + str(target_region_id))
	var siege_payload := {}
	var use_uncapped_siege: bool = false
	var target_has_castle := target_region.get_castle_type() != CastleTypeEnum.Type.NONE
	if is_player_computer(attacker_owner_id) and target_has_castle:
		var sim_results := _run_ai_battle_simulation(army, target_region)
		var sim_attempts: Array = sim_results.get("attempts", [])
		var final_sim: Dictionary = sim_results.get("final", {})
		use_uncapped_siege = bool(final_sim.get("uncapped_wood", false))
		var sim_outcome: String = final_sim.get("result", "defeat")
		_log_ai_battle_simulation(army, target_region, sim_attempts)
		if sim_outcome != "victory":
			_log_ai_prebattle_withdraw(army, target_region, "siege_simulation_failure")
			DebugLogger.log("Withdrawal", "[Pre-Battle] AI attacker withdrawing after failed siege simulation.")
			await _battle_manager.withdraw_attacking_army(army)
			return "withdrawal"
	if is_player_computer(attacker_owner_id):
		if not target_has_castle and _should_ai_withdraw_pre_siege(army, target_region):
			_log_ai_prebattle_withdraw(army, target_region, "pre_siege_power_check")
			DebugLogger.log("Withdrawal", "[Pre-Battle] AI attacker withdrawing before battle due to unfavorable power vs defense.")
			await _battle_manager.withdraw_attacking_army(army)
			return "withdrawal"
		siege_payload = _execute_ai_siege_preparation(army, target_region, use_uncapped_siege)
		if not target_has_castle and _should_ai_withdraw_post_siege(army, target_region, siege_payload):
			_log_ai_prebattle_withdraw(army, target_region, "post_siege_power_check")
			DebugLogger.log("Withdrawal", "[Pre-Battle] AI attacker withdrawing after battle prep due to unfavorable power ratio.")
			_record_enemy_presence_for_attacker(attacker_owner_id, target_region)
			var defender_owner := _region_manager.get_region_owner(target_region_id)
			if defender_owner > 0:
				_record_attacker_for_defender(defender_owner, [army])
			await _battle_manager.withdraw_attacking_army(army)
			return "withdrawal"
	var attacker_effectiveness_ratio := _compute_attacker_effectiveness_ratio(army, siege_payload, target_region)

	# Start the battle using BattleManager (will bypass modal if debug_disable_battle_modal && AI)
	_battle_manager.start_battle(army, target_region_id, attacker_effectiveness_ratio, siege_payload)

	# Always wait for battle_finished signal - it contains the correct result
	# The signal is emitted by BattleManager with the proper victory/defeat/withdrawal value
	var result: String = await _battle_manager.battle_finished
	DebugLogger.log("TurnProcessing", "Battle completed with result: " + result)
	await _battle_manager.await_finalize_complete()
	return result

func _execute_ai_siege_preparation(attacker: Army, target_region: Region, use_full_wood: bool = false) -> Dictionary:
	var castle_defense := GameParameters.get_castle_defense_bonus(target_region.get_castle_type())
	if castle_defense <= 0:
		return {}
	var siege_points_total: int = GameParameters.calculate_siege_points_for_composition(attacker.get_composition())
	var player_id := attacker.get_player_id()
	var player := player_manager.get_player(player_id)
	var available_wood: int = player.get_resource_amount(ResourcesEnum.Type.WOOD)
	var wood_growth: int = int(floor(player_manager.get_player_resource_growth(player_id, ResourcesEnum.Type.WOOD)))
	var wood_budget: int = _calculate_siege_wood_budget(available_wood, wood_growth)
	if use_full_wood:
		wood_budget = available_wood
	var wall_state: Dictionary = target_region.get_wall_state()
	var gate_state: Dictionary = target_region.get_gate_state()
	var wall_sections: int = int(wall_state.get("wall_sections", 0))
	var destroyed_sections: int = int(wall_state.get("destroyed_sections", 0))
	var intact_walls: int = max(0, wall_sections - destroyed_sections)
	var total_gates: int = int(gate_state.get("gates", gate_state.get("gate_values", []).size()))
	var destroyed_gates: int = int(gate_state.get("destroyed_gates", 0))
	var intact_gates: int = max(0, total_gates - destroyed_gates)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var siege_counts: Dictionary = _battle_manager.plan_siege_purchase(siege_points_total, intact_walls, intact_gates, wood_budget, rng)
	var wood_spent: int = 0
	wood_spent = siege_counts["ladders"] * int(PrebattleModal.LADDER_DATA["wood"])
	wood_spent += siege_counts["rams"] * int(PrebattleModal.RAM_DATA["wood"])
	wood_spent += siege_counts["trebuchets"] * int(PrebattleModal.TREB_DATA["wood"])
	if wood_spent > 0:
		player.remove_resources(ResourcesEnum.Type.WOOD, wood_spent)
	var bombard_damage: int = 0
	var bombard_state: Dictionary = {}
	var apply_trebuchet_damage := true
	if siege_counts["trebuchets"] > 0:
		bombard_damage = _roll_ai_trebuchet_bombard_damage(int(siege_counts["trebuchets"]))
		if bombard_damage > 0:
			bombard_state = target_region.apply_wall_section_damage(bombard_damage)
		else:
			bombard_state = target_region.get_wall_state()
		apply_trebuchet_damage = false
	var payload := target_region.apply_siege_damage(siege_counts, PrebattleModal.LADDER_DATA, PrebattleModal.RAM_DATA, PrebattleModal.TREB_DATA, apply_trebuchet_damage)
	var wall_raw: float = _battle_manager.compute_wall_assault_raw(target_region)
	var wall_ratio_calc: float = _battle_manager.compute_wall_assault_ratio(target_region, attacker.get_composition())
	var gate_ratio: float = _battle_manager.compute_gate_assault_ratio(target_region)
	var raw := int(payload.get("ladder_effectiveness_raw", 0))
	var non_ranged := GameParameters.calculate_non_ranged_count(attacker.get_composition())
	var ladder_ratio := 0.0
	if non_ranged > 0:
		ladder_ratio = clampf(float(raw) / float(non_ranged), 0.0, 1.0)
	if DebugLogger.is_category_enabled("BattleCalculation") or DebugLogger.is_category_enabled("BattleSystem"):
		DebugLogger.log("BattleCalculation", "AI siege prep: points=" + str(siege_points_total) + ", ladders=" + str(siege_counts.get("ladders", 0)) + ", rams=" + str(siege_counts.get("rams", 0)) + ", trebs=" + str(siege_counts.get("trebuchets", 0)) + ", raw_effectiveness=" + str(raw) + ", non_ranged=" + str(non_ranged) + ", ratio=" + str(snappedf(ladder_ratio * 100.0, 0.1)) + "%")
	payload["ladder_effectiveness_ratio"] = ladder_ratio
	payload["wall_effectiveness_ratio"] = wall_ratio_calc
	payload["wall_effectiveness_raw"] = wall_raw
	payload["gate_effectiveness_ratio"] = gate_ratio
	payload["assault_ratio"] = clampf(ladder_ratio + wall_ratio_calc + gate_ratio, 0.0, 1.0)
	payload["siege_counts"] = siege_counts.duplicate()
	if siege_counts["trebuchets"] > 0:
		payload["trebuchet_bombard"] = _build_ai_bombard_payload(target_region, bombard_damage, bombard_state, wall_ratio_calc, gate_ratio, ladder_ratio)
	var ai_gate_state: Dictionary = payload.get("gate_state", target_region.get_gate_state())
	payload["siege_view_state"] = SiegePanel.build_state(target_region, ai_gate_state, int(siege_counts.get("rams", 0)))
	var limit_label := "no limit" if available_wood > 50 else "growth limit"
	var wall_state_log: Dictionary = bombard_state
	if wall_state_log.is_empty():
		wall_state_log = target_region.get_wall_state()
	var breached_log: int = int(wall_state_log.get("destroyed_sections", 0))
	var damaged_log: int = int(wall_state_log.get("damaged_sections", 0))
	_log_ai_siege_preparation(siege_points_total, available_wood, limit_label, siege_counts, breached_log, damaged_log)
	return payload

func _compute_attacker_effectiveness_ratio(attacker: Army, siege_payload: Dictionary, target_region: Region) -> float:
	if target_region.get_castle_type() == CastleTypeEnum.Type.NONE:
		return 1.0
	var preset_total := float(siege_payload.get("assault_ratio", -1.0))
	if preset_total >= 0.0:
		return clampf(preset_total, 0.0, 1.0)
	var ladder_ratio := float(siege_payload.get("ladder_effectiveness_ratio", -1.0))
	var wall_ratio := float(siege_payload.get("wall_effectiveness_ratio", -1.0))
	var gate_ratio := float(siege_payload.get("gate_effectiveness_ratio", -1.0))
	var combined := 0.0
	var any_component := false
	if ladder_ratio >= 0.0:
		combined += ladder_ratio
		any_component = true
	if wall_ratio >= 0.0:
		combined += wall_ratio
		any_component = true
	if gate_ratio >= 0.0:
		combined += gate_ratio
		any_component = true
	if any_component:
		return clampf(combined, 0.0, 1.0)
	var raw: int = int(siege_payload.get("ladder_effectiveness_raw", 0))
	if raw <= 0:
		return 0.0
	var non_ranged := GameParameters.calculate_non_ranged_count(attacker.get_composition())
	if non_ranged <= 0:
		return 0.0
	return clampf(float(raw) / float(non_ranged), 0.0, 1.0)

func _compute_attacker_effectiveness_ratio_from_composition(attacker_comp: ArmyComposition, siege_payload: Dictionary, target_region: Region) -> float:
	if target_region.get_castle_type() == CastleTypeEnum.Type.NONE:
		return 1.0
	var preset_total := float(siege_payload.get("assault_ratio", -1.0))
	if preset_total >= 0.0:
		return clampf(preset_total, 0.0, 1.0)
	var ladder_ratio := float(siege_payload.get("ladder_effectiveness_ratio", -1.0))
	var wall_ratio := float(siege_payload.get("wall_effectiveness_ratio", -1.0))
	var gate_ratio := float(siege_payload.get("gate_effectiveness_ratio", -1.0))
	var combined := 0.0
	var any_component := false
	if ladder_ratio >= 0.0:
		combined += ladder_ratio
		any_component = true
	if wall_ratio >= 0.0:
		combined += wall_ratio
		any_component = true
	if gate_ratio >= 0.0:
		combined += gate_ratio
		any_component = true
	if any_component:
		return clampf(combined, 0.0, 1.0)
	var raw: int = int(siege_payload.get("ladder_effectiveness_raw", 0))
	if raw <= 0:
		return 0.0
	var non_ranged := GameParameters.calculate_non_ranged_count(attacker_comp)
	if non_ranged <= 0:
		return 0.0
	return clampf(float(raw) / float(non_ranged), 0.0, 1.0)

func _roll_ai_trebuchet_bombard_damage(treb_count: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var total: int = 0
	for i in range(treb_count):
		for shot in range(PrebattleModal.TREBUCHET_SHOTS):
			if rng.randf() <= PrebattleModal.TREBUCHET_HIT_CHANCE:
				total += 1
	return total

func _build_ai_bombard_payload(region: Region, bombard_damage: int, wall_state: Dictionary, wall_ratio: float, gate_ratio: float, ladder_ratio: float) -> Dictionary:
	var effective_wall_state: Dictionary = wall_state
	if effective_wall_state.is_empty():
		effective_wall_state = region.get_wall_state()
	var wall_effectiveness_raw: float = _battle_manager.compute_wall_assault_raw(region)
	var assault_ratio := clampf(ladder_ratio + wall_ratio + gate_ratio, 0.0, 1.0)
	return {
		"total_damage": bombard_damage,
		"destroyed_sections": int(effective_wall_state.get("destroyed_sections", 0)),
		"damaged_sections": int(effective_wall_state.get("damaged_sections", 0)),
		"section_damage": int(effective_wall_state.get("section_damage", 0)),
		"wall_section_hp": int(effective_wall_state.get("wall_section_hp", 0)),
		"wall_sections": int(effective_wall_state.get("wall_sections", 0)),
		"wall_effectiveness_raw": wall_effectiveness_raw,
		"wall_effectiveness_ratio": wall_ratio,
		"gate_effectiveness_ratio": gate_ratio,
		"assault_ratio": assault_ratio
	}

func _compute_region_total_defender_power(region: Region) -> int:
	var owner_id := region.get_region_owner()
	var total: int = 0
	var garrison_comp: ArmyComposition = region.get_garrison()
	if garrison_comp != null:
		total += _calculate_composition_power(garrison_comp)
	var recruits: int = region.get_base_available_recruits()
	if recruits > 0:
		total += recruits * int(GameParameters.get_unit_stat(SoldierTypeEnum.Type.PEASANTS, "power"))
	for child in region.get_children():
		if child is Army and child.get_player_id() == owner_id:
			total += child.get_army_power()
	return total

func _log_ai_siege_preparation(points: int, wood_available: int, wood_limit_label: String, siege_counts: Dictionary, breached_sections: int, damaged_sections: int) -> void:
	ensure_ai_log_started()
	_ai_log_manager.log_siege_preparation(points, wood_available, wood_limit_label, siege_counts, breached_sections, damaged_sections)

func _calculate_siege_wood_budget(available_wood: int, wood_growth: int) -> int:
	var growth_cap: int = max(0, wood_growth)
	if available_wood <= 30:
		return min(available_wood, growth_cap)
	var spendable: int = max(0, available_wood - 30) + growth_cap
	return min(available_wood, spendable)

func _record_enemy_presence(observer_id: int, target_region: Region) -> void:
	if target_region == null:
		return
	var target_owner := _region_manager.get_region_owner(target_region.get_region_id())
	if target_owner == observer_id:
		return
	var garrison_comp: ArmyComposition = target_region.get_garrison()
	var recruits: int = target_region.get_base_available_recruits()
	var garrison_power: int = 0
	if garrison_comp != null:
		garrison_power += _calculate_composition_power(garrison_comp)
	if recruits > 0:
		garrison_power += recruits * int(GameParameters.get_unit_stat(SoldierTypeEnum.Type.PEASANTS, "power"))
	player_manager.record_enemy_garrison(observer_id, target_region.get_region_id(), garrison_power)
	for child in target_region.get_children():
		if not (child is Army):
			continue
		var enemy_army: Army = child
		if enemy_army.get_player_id() == observer_id:
			continue
		player_manager.record_enemy_army_power(observer_id, enemy_army)

func should_ai_withdraw_by_power(attacker_power: float, defender_power: float, assault_multiplier: float, defense_bonus: int, threshold: float) -> bool:
	if attacker_power <= 0.0 or defender_power <= 0.0:
		return false
	var effective_atk: float = attacker_power * assault_multiplier
	var defense_multiplier: float = 1.0 + float(defense_bonus) / 100.0
	var effective_def: float = defender_power * defense_multiplier
	if effective_atk <= 0.0 or effective_def <= 0.0:
		return false
	var ratio: float = effective_atk / max(1.0, effective_def)
	return ratio <= threshold

func _should_ai_withdraw_pre_siege(attacker: Army, target_region: Region) -> bool:
	if target_region.get_castle_type() == CastleTypeEnum.Type.NONE:
		return false
	var defense_bonus: int = _battle_manager.get_effective_defense_for_region(target_region)
	if defense_bonus <= 0:
		return false
	var attacker_power: int = attacker.get_army_power()
	var defender_power: int = _calculate_region_defender_power(target_region)
	if defender_power <= 0:
		return false
	var target_ratio: float = 1.0
	var should_withdraw: bool = should_ai_withdraw_by_power(float(attacker_power), float(defender_power), 1.0, defense_bonus, target_ratio)
	var ratio: float = float(attacker_power) / max(1.0, float(defender_power) * (1.0 + float(defense_bonus) / 100.0))
	DebugLogger.log("Withdrawal", "[Pre-Siege Check] atk_power=" + str(attacker_power) + " def_power=" + str(defender_power) + " def_bonus=" + str(defense_bonus) + " ratio=" + str(snappedf(ratio, 0.003)))
	return should_withdraw

func _should_ai_withdraw_post_siege(attacker: Army, target_region: Region, siege_payload: Dictionary) -> bool:
	var attacker_power: int = attacker.get_army_power()
	var defender_power: int = _calculate_region_defender_power(target_region)
	if attacker_power <= 0 or defender_power <= 0:
		return false
	var assault_multiplier: float = 1.0
	var defense_bonus: int = 0
	var defender_owner_id: int = target_region.get_region_owner()
	var ai_vs_human: bool = is_player_computer(attacker.get_player_id()) and is_player_human(defender_owner_id)
	var withdraw_threshold: float = GameParameters.get_ai_withdraw_power_threshold(get_game_difficulty(), ai_vs_human)
	if target_region.get_castle_type() != CastleTypeEnum.Type.NONE:
		assault_multiplier = max(0.0, _compute_attacker_effectiveness_ratio(attacker, siege_payload, target_region))
		var siege_counts: Dictionary = siege_payload.get("siege_counts", {})
		var rams: int = int(siege_counts.get("rams", 0))
		if rams > 0:
			assault_multiplier += float(rams) * 0.2
		defense_bonus = _battle_manager.get_effective_defense_for_region(target_region)
		withdraw_threshold = 0.5
	var split := _split_power_by_ranged_composition(attacker.get_composition())
	var ranged_power: float = split.get("ranged", 0.0)
	var non_ranged_power: float = split.get("non_ranged", 0.0)
	var defense_multiplier: float = 1.0 + float(defense_bonus) / 100.0
	var effective_atk: float = ranged_power + non_ranged_power * assault_multiplier
	var effective_def: float = float(defender_power) * defense_multiplier
	var ratio: float = effective_atk / max(1.0, effective_def)
	var should_withdraw: bool = ratio <= withdraw_threshold
	DebugLogger.log("Withdrawal", "[Pre-Battle Check] atk_power=" + str(attacker_power) + " def_power=" + str(defender_power) + " assault_mult=" + str(snappedf(assault_multiplier, 0.003)) + " defense_mult=" + str(snappedf(defense_multiplier, 0.003)) + " ratio=" + str(snappedf(ratio, 0.003)) + " thr=" + str(withdraw_threshold))
	return should_withdraw

func _calculate_region_defender_power(region: Region) -> int:
	var owner_id: int = region.get_region_owner()
	var total: int = 0
	var garrison_comp: ArmyComposition = region.get_garrison()
	if garrison_comp != null:
		total += _calculate_composition_power(garrison_comp)
	for child in region.get_children():
		if child is Army and child.get_player_id() == owner_id:
			total += (child as Army).get_army_power()
	return total

func _split_power_by_ranged_composition(comp: ArmyComposition) -> Dictionary:
	if comp == null:
		return {"ranged": 0.0, "non_ranged": 0.0}
	var ranged: float = 0.0
	var non_ranged: float = 0.0
	for ut in SoldierTypeEnum.get_all_types():
		var qty := comp.get_soldier_count(ut)
		if qty <= 0:
			continue
		var power: int = GameParameters.get_unit_stat(ut, "power") * qty
		if GameParameters.unit_has_trait(ut, UnitTraitEnum.Type.UNIT_TRAIT_2):
			ranged += float(power)
		else:
			non_ranged += float(power)
	return {"ranged": ranged, "non_ranged": non_ranged}

func _log_ai_prebattle_withdraw(attacker: Army, target_region: Region, reason: String) -> void:
	var observer_id := attacker.get_player_id()
	var defenders := _collect_defender_log_entries(_army_manager.get_armies_in_region(target_region), target_region.get_garrison(), target_region, target_region.get_base_available_recruits(), observer_id, attacker, attacker.get_player_id())
	var lines := _build_battle_pre_log_lines(attacker, defenders)
	lines.append("Battle Result: withdrawal (pre-battle)")
	lines.append("Reason: " + reason)
	lines.append("")
	_enqueue_ai_battle_log(attacker, lines)

func _record_enemy_presence_for_attacker(observer_id: int, target_region: Region) -> void:
	if target_region == null:
		return
	var target_owner := _region_manager.get_region_owner(target_region.get_region_id())
	if target_owner == observer_id:
		return
	var garrison_power: int = _compute_region_total_defender_power(target_region)
	record_enemy_garrison(observer_id, target_region.get_region_id(), garrison_power)
	for child in target_region.get_children():
		if not (child is Army):
			continue
		var enemy_army: Army = child
		if enemy_army.get_player_id() == observer_id:
			continue
		record_enemy_army_power(observer_id, enemy_army)

func simulate_siege_battle(attacker: Army, target_region: Region, use_full_wood: bool = false) -> Dictionary:
	var observer_id := attacker.get_player_id()
	var defenders := _build_simulated_defenders(target_region, observer_id)
	var siege_sim := _simulate_ai_siege_preparation(attacker, target_region, use_full_wood)
	var siege_payload: Dictionary = siege_sim.get("siege_payload", {})
	var attacker_effectiveness_ratio: float = float(siege_sim.get("attacker_effectiveness_ratio", 1.0))
	var defense_bonus: int = int(siege_sim.get("defense_bonus", _battle_manager.get_effective_defense_for_region(target_region)))
	var simulator := BattleSimulator.new()
	var attacker_comp: ArmyComposition = attacker.get_composition().duplicate()
	var defender_armies: Array[ArmyComposition] = defenders.get("armies", [])
	var garrison_comp: ArmyComposition = defenders.get("garrison", null)
	var sim_label: String = "Sim vs " + str(target_region.get_region_name())
	if use_full_wood:
		sim_label += " (no cap)"
	var report := simulator.simulate_battle(
		[attacker_comp],
		defender_armies,
		garrison_comp,
		attacker.get_efficiency(),
		100,
		target_region.get_region_type(),
		target_region.get_castle_type(),
		"Attackers",
		"Defenders",
		false,
		false,
		defense_bonus,
		attacker_effectiveness_ratio,
		siege_payload,
		_ai_log_manager,
		sim_label
	)
	return {
		"report": report,
		"result": _derive_battle_result_from_report(report),
		"attacker_effectiveness_ratio": attacker_effectiveness_ratio,
		"defense_bonus": defense_bonus,
		"attacker_survivors": _sum_composition(report.final_attacker),
		"defender_survivors": _sum_composition(report.final_defender),
		"siege_payload": siege_payload,
		"uncapped_wood": use_full_wood
	}

func simulate_castle_threat_battle(attacking_armies: Array[Army], target_region: Region, use_full_wood: bool = false, include_defender_armies: bool = true) -> Dictionary:
	var merged_attacker: ArmyComposition = _merge_attacker_army_composition(attacking_armies)
	var reference_attacker: Army = attacking_armies[0]
	var defenders := _build_simulated_defenders(target_region, -1, include_defender_armies)
	var siege_sim: Dictionary = _simulate_ai_siege_preparation_for_composition(merged_attacker, reference_attacker.get_player_id(), target_region, use_full_wood)
	var siege_payload: Dictionary = siege_sim.get("siege_payload", {})
	var attacker_effectiveness_ratio: float = float(siege_sim.get("attacker_effectiveness_ratio", 1.0))
	var defense_bonus: int = int(siege_sim.get("defense_bonus", _battle_manager.get_effective_defense_for_region(target_region)))
	var simulator := BattleSimulator.new()
	var defender_armies: Array[ArmyComposition] = defenders.get("armies", [])
	var garrison_comp: ArmyComposition = defenders.get("garrison", null)
	var sim_label: String = "Threat Sim vs " + str(target_region.get_region_name())
	if use_full_wood:
		sim_label += " (no cap)"
	var report := simulator.simulate_battle(
		[merged_attacker],
		defender_armies,
		garrison_comp,
		_get_average_efficiency_for_armies(attacking_armies),
		100,
		target_region.get_region_type(),
		target_region.get_castle_type(),
		"Attackers",
		"Defenders",
		false,
		false,
		defense_bonus,
		attacker_effectiveness_ratio,
		siege_payload,
		_ai_log_manager,
		sim_label
	)
	return {
		"report": report,
		"result": _derive_battle_result_from_report(report),
		"attacker_effectiveness_ratio": attacker_effectiveness_ratio,
		"defense_bonus": defense_bonus,
		"attacker_survivors": _sum_composition(report.final_attacker),
		"defender_survivors": _sum_composition(report.final_defender),
		"siege_payload": siege_payload,
		"uncapped_wood": use_full_wood
	}

func _merge_attacker_army_composition(attacking_armies: Array[Army]) -> ArmyComposition:
	var merged: ArmyComposition = ArmyComposition.new()
	for army in attacking_armies:
		var source: ArmyComposition = army.get_composition()
		for unit_type in SoldierTypeEnum.get_all_types():
			var quantity: int = source.get_soldier_count(unit_type)
			if quantity > 0:
				merged.add_soldiers(unit_type, quantity)
	return merged

func _get_average_efficiency_for_armies(attacking_armies: Array[Army]) -> int:
	var total_efficiency: int = 0
	for army in attacking_armies:
		total_efficiency += army.get_efficiency()
	return int(round(float(total_efficiency) / float(max(1, attacking_armies.size()))))

func _build_simulated_defenders(target_region: Region, observer_id: int = -1, include_defender_armies: bool = true) -> Dictionary:
	var owner_id: int = _region_manager.get_region_owner(target_region.get_region_id())
	var defender_armies: Array[ArmyComposition] = []
	if include_defender_armies:
		for child in target_region.get_children():
			if child is Army and child.get_player_id() == owner_id:
				var army_node := child as Army
				if observer_id != -1:
					var tracker_key := Player.get_enemy_tracker_key(army_node)
					var tracked_power := player_manager.get_tracked_enemy_power(observer_id, tracker_key)
					if tracked_power < 0:
						continue
				defender_armies.append(army_node.get_composition().duplicate())
	var garrison_source: ArmyComposition = target_region.get_garrison()
	var garrison_copy: ArmyComposition = ArmyComposition.new()
	var tracked_garrison := -1
	if observer_id != -1:
		tracked_garrison = player_manager.get_tracked_enemy_garrison_power(observer_id, target_region.get_region_id())
	if garrison_source != null and (tracked_garrison >= 0 or observer_id == -1):
		garrison_copy.copy_from(garrison_source)
	if tracked_garrison >= 0 or observer_id == -1:
		var recruits: int = target_region.get_base_available_recruits()
		if recruits > 0:
			garrison_copy.add_soldiers(SoldierTypeEnum.Type.PEASANTS, recruits)
	return {
		"armies": defender_armies,
		"garrison": garrison_copy
	}

func _simulate_ai_siege_preparation(attacker: Army, target_region: Region, use_full_wood: bool = false) -> Dictionary:
	var castle_type := target_region.get_castle_type()
	var default_defense: int = _battle_manager.get_effective_defense_for_region(target_region)
	if castle_type == CastleTypeEnum.Type.NONE:
		return {
			"siege_payload": {},
			"attacker_effectiveness_ratio": 1.0,
			"defense_bonus": default_defense
		}
	var defense_state := _capture_defense_state(target_region)
	var siege_counts := _simulate_siege_purchase(attacker, target_region, defense_state, use_full_wood)
	var bombard_damage: int = 0
	var apply_trebuchet_damage := true
	if int(siege_counts.get("trebuchets", 0)) > 0:
		bombard_damage = _roll_ai_trebuchet_bombard_damage(int(siege_counts["trebuchets"]))
		if bombard_damage > 0:
			_apply_wall_damage_to_state(defense_state, bombard_damage)
		apply_trebuchet_damage = false
	var siege_payload := _apply_siege_damage_to_state(defense_state, siege_counts, apply_trebuchet_damage)
	var wall_state := _build_wall_state_from_sim(defense_state)
	var gate_state := _build_gate_state_from_sim(defense_state)
	var wall_raw := _compute_wall_assault_raw_from_state(castle_type, wall_state)
	var wall_ratio := _compute_wall_assault_ratio_from_raw(wall_raw, attacker.get_composition())
	var gate_ratio := _compute_gate_assault_ratio_from_state(gate_state, attacker.get_composition())
	var ladder_ratio := _compute_ladder_ratio_from_raw(int(siege_payload.get("ladder_effectiveness_raw", 0)), attacker.get_composition())
	if int(siege_counts.get("trebuchets", 0)) > 0:
		siege_payload["trebuchet_bombard"] = _build_simulated_bombard_payload(wall_state, bombard_damage, wall_ratio, gate_ratio, ladder_ratio, castle_type)
	siege_payload["siege_counts"] = siege_counts.duplicate()
	siege_payload["gate_state"] = gate_state
	siege_payload["ladder_effectiveness_ratio"] = ladder_ratio
	siege_payload["wall_effectiveness_raw"] = wall_raw
	siege_payload["wall_effectiveness_ratio"] = wall_ratio
	siege_payload["gate_effectiveness_ratio"] = gate_ratio
	siege_payload["assault_ratio"] = clampf(ladder_ratio + wall_ratio + gate_ratio, 0.0, 1.0)
	var attacker_effectiveness_ratio: float = _compute_attacker_effectiveness_ratio(attacker, siege_payload, target_region)
	var defense_bonus := _compute_defense_bonus_from_state(castle_type, wall_state)
	return {
		"siege_payload": siege_payload,
		"attacker_effectiveness_ratio": attacker_effectiveness_ratio,
		"defense_bonus": defense_bonus,
		"wall_state": wall_state,
		"gate_state": gate_state
	}

func _simulate_ai_siege_preparation_for_composition(attacker_comp: ArmyComposition, attacker_player_id: int, target_region: Region, use_full_wood: bool = false) -> Dictionary:
	var castle_type := target_region.get_castle_type()
	var default_defense: int = _battle_manager.get_effective_defense_for_region(target_region)
	if castle_type == CastleTypeEnum.Type.NONE:
		return {
			"siege_payload": {},
			"attacker_effectiveness_ratio": 1.0,
			"defense_bonus": default_defense
		}
	var defense_state := _capture_defense_state(target_region)
	var siege_counts: Dictionary = _simulate_siege_purchase_for_composition(attacker_comp, attacker_player_id, defense_state, use_full_wood)
	var bombard_damage: int = 0
	var apply_trebuchet_damage := true
	if int(siege_counts.get("trebuchets", 0)) > 0:
		bombard_damage = _roll_ai_trebuchet_bombard_damage(int(siege_counts["trebuchets"]))
		if bombard_damage > 0:
			_apply_wall_damage_to_state(defense_state, bombard_damage)
		apply_trebuchet_damage = false
	var siege_payload := _apply_siege_damage_to_state(defense_state, siege_counts, apply_trebuchet_damage)
	var wall_state := _build_wall_state_from_sim(defense_state)
	var gate_state := _build_gate_state_from_sim(defense_state)
	var wall_raw := _compute_wall_assault_raw_from_state(castle_type, wall_state)
	var wall_ratio := _compute_wall_assault_ratio_from_raw(wall_raw, attacker_comp)
	var gate_ratio := _compute_gate_assault_ratio_from_state(gate_state, attacker_comp)
	var ladder_ratio := _compute_ladder_ratio_from_raw(int(siege_payload.get("ladder_effectiveness_raw", 0)), attacker_comp)
	if int(siege_counts.get("trebuchets", 0)) > 0:
		siege_payload["trebuchet_bombard"] = _build_simulated_bombard_payload(wall_state, bombard_damage, wall_ratio, gate_ratio, ladder_ratio, castle_type)
	siege_payload["siege_counts"] = siege_counts.duplicate()
	siege_payload["gate_state"] = gate_state
	siege_payload["ladder_effectiveness_ratio"] = ladder_ratio
	siege_payload["wall_effectiveness_raw"] = wall_raw
	siege_payload["wall_effectiveness_ratio"] = wall_ratio
	siege_payload["gate_effectiveness_ratio"] = gate_ratio
	siege_payload["assault_ratio"] = clampf(ladder_ratio + wall_ratio + gate_ratio, 0.0, 1.0)
	var attacker_effectiveness_ratio: float = _compute_attacker_effectiveness_ratio_from_composition(attacker_comp, siege_payload, target_region)
	var defense_bonus := _compute_defense_bonus_from_state(castle_type, wall_state)
	return {
		"siege_payload": siege_payload,
		"attacker_effectiveness_ratio": attacker_effectiveness_ratio,
		"defense_bonus": defense_bonus,
		"wall_state": wall_state,
		"gate_state": gate_state
	}

func _capture_defense_state(target_region: Region) -> Dictionary:
	var gate_state: Dictionary = target_region.get_gate_state()
	var wall_state: Dictionary = target_region.get_wall_state()
	return {
		"gate_hp": int(gate_state.get("gate_hp", 0)),
		"gate_values": (gate_state.get("gate_values", []) as Array).duplicate(),
		"wall_section_hp": int(wall_state.get("wall_section_hp", 0)),
		"wall_values": (wall_state.get("wall_values", []) as Array).duplicate()
	}

func _simulate_siege_purchase(attacker: Army, target_region: Region, defense_state: Dictionary, use_full_wood: bool) -> Dictionary:
	var siege_points_total: int = GameParameters.calculate_siege_points_for_composition(attacker.get_composition())
	var player_id := attacker.get_player_id()
	var player := player_manager.get_player(player_id)
	var available_wood: int = player.get_resource_amount(ResourcesEnum.Type.WOOD)
	var wood_growth: int = int(floor(player_manager.get_player_resource_growth(player_id, ResourcesEnum.Type.WOOD)))
	var wood_budget: int = _calculate_siege_wood_budget(available_wood, wood_growth)
	if use_full_wood:
		wood_budget = available_wood
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var wall_state := _build_wall_state_from_sim(defense_state)
	var gate_state := _build_gate_state_from_sim(defense_state)
	var intact_walls: int = 0
	for hp in wall_state.get("wall_values", []):
		if int(hp) > 0:
			intact_walls += 1
	var intact_gates: int = 0
	for hp in gate_state.get("gate_values", []):
		if int(hp) > 0:
			intact_gates += 1
	return _battle_manager.plan_siege_purchase(siege_points_total, intact_walls, intact_gates, wood_budget, rng)

func _simulate_siege_purchase_for_composition(attacker_comp: ArmyComposition, attacker_player_id: int, defense_state: Dictionary, use_full_wood: bool) -> Dictionary:
	var siege_points_total: int = GameParameters.calculate_siege_points_for_composition(attacker_comp)
	var player := player_manager.get_player(attacker_player_id)
	var available_wood: int = player.get_resource_amount(ResourcesEnum.Type.WOOD)
	var wood_growth: int = int(floor(player_manager.get_player_resource_growth(attacker_player_id, ResourcesEnum.Type.WOOD)))
	var wood_budget: int = _calculate_siege_wood_budget(available_wood, wood_growth)
	if use_full_wood:
		wood_budget = available_wood
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var wall_state := _build_wall_state_from_sim(defense_state)
	var gate_state := _build_gate_state_from_sim(defense_state)
	var intact_walls: int = 0
	for hp in wall_state.get("wall_values", []):
		if int(hp) > 0:
			intact_walls += 1
	var intact_gates: int = 0
	for hp in gate_state.get("gate_values", []):
		if int(hp) > 0:
			intact_gates += 1
	return _battle_manager.plan_siege_purchase(siege_points_total, intact_walls, intact_gates, wood_budget, rng)

func _apply_siege_damage_to_state(defense_state: Dictionary, siege_counts: Dictionary, apply_trebuchet_damage: bool) -> Dictionary:
	var ladder_count: int = int(siege_counts.get("ladders", 0))
	var ladder_effectiveness_raw: int = ladder_count * int(PrebattleModal.LADDER_DATA.get("effectiveness", GameParameters.LADDER_EFFECTIVENESS_PER))
	var wall_state := _build_wall_state_from_sim(defense_state)
	var gate_state := _build_gate_state_from_sim(defense_state)
	return {
		"ladder_effectiveness_raw": ladder_effectiveness_raw,
		"ladder_damage": 0,
		"wall_sections_destroyed": int(wall_state.get("destroyed_sections", 0)),
		"wall_sections_damaged": int(wall_state.get("damaged_sections", 0)),
		"gate_state": gate_state
	}

func _apply_gate_damage_to_state(defense_state: Dictionary, damage: int) -> void:
	var gate_values: Array = defense_state.get("gate_values", [])
	var remaining: int = damage
	for i in range(gate_values.size()):
		if remaining <= 0:
			break
		var current: int = int(gate_values[i])
		if current <= 0:
			continue
		var applied: int = min(current, remaining)
		gate_values[i] = max(0, current - applied)
		remaining -= applied
	defense_state["gate_values"] = gate_values

func _apply_wall_damage_to_state(defense_state: Dictionary, damage: int) -> Dictionary:
	var wall_values: Array = defense_state.get("wall_values", [])
	var remaining: int = damage
	for i in range(wall_values.size()):
		if remaining <= 0:
			break
		var current: int = int(wall_values[i])
		if current <= 0:
			continue
		var applied: int = min(current, remaining)
		wall_values[i] = max(0, current - applied)
		remaining -= applied
	defense_state["wall_values"] = wall_values
	return _build_wall_state_from_sim(defense_state)

func _build_gate_state_from_sim(defense_state: Dictionary) -> Dictionary:
	var gate_values: Array = defense_state.get("gate_values", [])
	var gate_hp: int = int(defense_state.get("gate_hp", 0))
	var destroyed := 0
	var damaged := 0
	for hp in gate_values:
		var gate_hp_value: int = int(hp)
		if gate_hp_value <= 0:
			destroyed += 1
		elif gate_hp_value < gate_hp:
			damaged += 1
	return {
		"destroyed_gates": destroyed,
		"damaged_gates": damaged,
		"gate_hp": gate_hp,
		"gates": gate_values.size(),
		"gate_values": gate_values.duplicate()
	}

func _build_wall_state_from_sim(defense_state: Dictionary) -> Dictionary:
	var wall_values: Array = defense_state.get("wall_values", [])
	var wall_hp: int = int(defense_state.get("wall_section_hp", 0))
	var destroyed := 0
	var damaged := 0
	var section_damage: int = 0
	for hp in wall_values:
		var wall_hp_value: int = int(hp)
		if wall_hp_value <= 0:
			destroyed += 1
		elif wall_hp_value < wall_hp:
			damaged += 1
			if section_damage == 0:
				section_damage = wall_hp - wall_hp_value
	return {
		"destroyed_sections": destroyed,
		"damaged_sections": damaged,
		"wall_section_hp": wall_hp,
		"wall_sections": wall_values.size(),
		"section_damage": section_damage,
		"wall_values": wall_values.duplicate()
	}

func _compute_wall_assault_raw_from_state(castle_type: CastleTypeEnum.Type, wall_state: Dictionary) -> float:
	var data: Dictionary = GameParameters.CASTLE_WALLS_GATES.get(castle_type, {})
	var assault_per_section: int = int(data.get("wall_section_assault", 0))
	if assault_per_section <= 0:
		return 0.0
	var destroyed: int = int(wall_state.get("destroyed_sections", 0))
	return float(destroyed * assault_per_section)

func _compute_wall_assault_ratio_from_raw(raw: float, attacker_comp: ArmyComposition) -> float:
	if raw <= 0.0:
		return 0.0
	var non_ranged := GameParameters.calculate_non_ranged_count(attacker_comp)
	if non_ranged <= 0:
		return 0.0
	return clampf(raw / float(non_ranged), 0.0, 1.0)

func _compute_gate_assault_ratio_from_state(gate_state: Dictionary, attacker_comp: ArmyComposition) -> float:
	var gate_hp: int = int(gate_state.get("gate_hp", 0))
	var gate_values: Array = gate_state.get("gate_values", [])
	var gates: int = int(gate_state.get("gates", gate_values.size()))
	if gate_hp <= 0 or gates <= 0:
		return 0.0
	var capacity: int = max(1, gates * gate_hp)
	var missing: int = 0
	for hp in gate_values:
		missing += max(0, gate_hp - int(hp))
	return clampf(float(missing) / float(capacity), 0.0, 1.0)

func _compute_ladder_ratio_from_raw(raw: int, attacker_comp: ArmyComposition) -> float:
	if raw <= 0:
		return 0.0
	var non_ranged := GameParameters.calculate_non_ranged_count(attacker_comp)
	if non_ranged <= 0:
		return 0.0
	return clampf(float(raw) / float(non_ranged), 0.0, 1.0)

func _compute_defense_bonus_from_state(castle_type: CastleTypeEnum.Type, wall_state: Dictionary) -> int:
	var base_def: int = GameParameters.get_castle_defense_bonus(castle_type)
	var data: Dictionary = GameParameters.CASTLE_WALLS_GATES.get(castle_type, {})
	var per_section: int = int(data.get("trebuchet_damage_to_defense", 0))
	var destroyed: int = int(wall_state.get("destroyed_sections", 0))
	var damaged: int = int(wall_state.get("damaged_sections", 0))
	var damaged_penalty_per_section: int = int(round(float(per_section) * 0.5))
	var penalty: int = destroyed * per_section + damaged * damaged_penalty_per_section
	var min_def: int = GameParameters.CASTLE_DEFENSE_BONUSES_MIN.get(castle_type, 0)
	return max(min_def, base_def - penalty)

func _build_simulated_bombard_payload(wall_state: Dictionary, bombard_damage: int, wall_ratio: float, gate_ratio: float, ladder_ratio: float, castle_type: CastleTypeEnum.Type) -> Dictionary:
	var wall_raw := _compute_wall_assault_raw_from_state(castle_type, wall_state)
	var assault_ratio := clampf(ladder_ratio + wall_ratio + gate_ratio, 0.0, 1.0)
	return {
		"total_damage": bombard_damage,
		"destroyed_sections": int(wall_state.get("destroyed_sections", 0)),
		"damaged_sections": int(wall_state.get("damaged_sections", 0)),
		"section_damage": int(wall_state.get("section_damage", 0)),
		"wall_section_hp": int(wall_state.get("wall_section_hp", 0)),
		"wall_sections": int(wall_state.get("wall_sections", 0)),
		"wall_effectiveness_raw": wall_raw,
		"wall_effectiveness_ratio": wall_ratio,
		"gate_effectiveness_ratio": gate_ratio,
		"assault_ratio": assault_ratio
	}

func _sum_composition(comp: Dictionary) -> int:
	if comp == null:
		return 0
	var total := 0
	for key in comp.keys():
		total += int(comp[key])
	return total

func _run_ai_battle_simulation(attacker: Army, target_region: Region) -> Dictionary:
	var attempts: Array = []
	var primary: Dictionary = simulate_siege_battle(attacker, target_region, false)
	attempts.append({
		"label": "budgeted",
		"result": primary
	})
	if String(primary.get("result", "defeat")) != "victory":
		var fallback: Dictionary = simulate_siege_battle(attacker, target_region, true)
		attempts.append({
			"label": "no cap",
			"result": fallback
		})
	var final_result: Dictionary = attempts[attempts.size() - 1]["result"]
	return {
		"attempts": attempts,
		"final": final_result
	}

func _log_ai_battle_simulation(attacker: Army, target_region: Region, attempts: Array) -> void:
	if attacker == null or target_region == null:
		return
	ensure_ai_log_started()
	if attempts.is_empty():
		return
	var defender_entries := _collect_defender_log_entries(_army_manager.get_armies_in_region(target_region), target_region.get_garrison(), target_region, target_region.get_base_available_recruits(), attacker.get_player_id())
	for attempt in attempts:
		var sim_result: Dictionary = attempt.get("result", {})
		var siege_payload: Dictionary = sim_result.get("siege_payload", {})
		var siege_counts: Dictionary = siege_payload.get("siege_counts", {})
		var trebs: int = int(siege_counts.get("trebuchets", 0))
		var rams: int = int(siege_counts.get("rams", 0))
		var ladders: int = int(siege_counts.get("ladders", 0))
		var assault_ratio: float = float(siege_payload.get("assault_ratio", sim_result.get("attacker_effectiveness_ratio", 0.0)))
		var defense_bonus: int = int(sim_result.get("defense_bonus", 0))
		var uncapped: bool = bool(sim_result.get("uncapped_wood", false))
		var label: String = String(attempt.get("label", ""))
		var lines: Array[String] = []
		var gate_log: Array[String] = []
		var sim_report: BattleSimulator.BattleReport = sim_result.get("report", null)
		if sim_report != null and not sim_report.gate_plan_log.is_empty():
			gate_log = sim_report.gate_plan_log
		if not gate_log.is_empty():
			lines.append_array(gate_log)
		var header := "[Simulation"
		if label != "":
			header += " - " + label
		header += "]"
		lines.append(header)
		var wood_label := "Budgeted"
		if uncapped:
			wood_label = "None"
		lines.append("Wood Cap: " + wood_label)
		lines.append("Bought: %d Trebuchets, %d Battling Rams, %d Ladders" % [trebs, rams, ladders])
		lines.append("Assault: %d%%" % int(round(assault_ratio * 100.0)))
		lines.append("Defense: %d%%" % defense_bonus)
		lines.append("Simulation started")
		lines.append(_format_attacker_line("Attacker", attacker, attacker.name))
		for entry in defender_entries:
			lines.append(_format_defender_pre_line(entry))
		var sim_outcome: String = _format_battle_result_label(sim_result.get("result", "defeat"))
		lines.append("Battle Result: %s" % sim_outcome)
		var final_attacker_comp: ArmyComposition = _comp_from_dict(sim_report.final_attacker) if sim_report != null else null
		lines.append(_format_comp_line("Attacker After", attacker.get_display_name(), final_attacker_comp))
		var defender_sources := _build_simulation_defender_sources(target_region)
		var final_defender_dict: Dictionary = sim_report.final_defender if sim_report != null else {}
		var defender_survivors := _allocate_simulation_survivors(defender_sources, final_defender_dict)
		for survivor_entry in defender_survivors:
			lines.append(_format_comp_line(survivor_entry.get("label", "Defender After"), survivor_entry.get("label", "Defender After"), survivor_entry.get("comp", null)))
		lines.append("")
		for line in lines:
			_ai_log_manager.log_army_detail(line)

func _comp_from_dict(data: Dictionary) -> ArmyComposition:
	var comp := ArmyComposition.new()
	for ut in data.keys():
		comp.set_soldier_count(ut, int(data[ut]))
	return comp

func _build_simulation_defender_sources(target_region: Region) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	var owner_id: int = _region_manager.get_region_owner(target_region.get_region_id())
	for child in target_region.get_children():
		if child is Army and child.get_player_id() == owner_id:
			var army: Army = child
			var comp := army.get_composition().duplicate()
			sources.append({"label": army.get_display_name(), "comp": comp})
	var garrison_copy: ArmyComposition = ArmyComposition.new()
	var garrison_source: ArmyComposition = target_region.get_garrison()
	if garrison_source != null:
		garrison_copy.copy_from(garrison_source)
	if not garrison_copy.is_empty():
		sources.append({"label": "Garrison", "comp": garrison_copy})
	var recruits: int = target_region.get_base_available_recruits()
	if recruits > 0:
		var recruits_comp := ArmyComposition.new()
		recruits_comp.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, recruits)
		var region_label := target_region.get_region_name()
		sources.append({"label": "Recruits (" + region_label + ")", "comp": recruits_comp})
	return sources

func _allocate_simulation_survivors(sources: Array[Dictionary], final_total: Dictionary) -> Array[Dictionary]:
	var survivors: Array[Dictionary] = []
	for src in sources:
		var copy_comp := ArmyComposition.new()
		var comp: ArmyComposition = src.get("comp", null)
		if comp != null:
			copy_comp.copy_from(comp)
		survivors.append({"label": src.get("label", "Defender After"), "comp": copy_comp})
	for unit_type in SoldierTypeEnum.get_all_types():
		var initial_total: int = 0
		for src in sources:
			var comp: ArmyComposition = src.get("comp", null)
			if comp != null:
				initial_total += comp.get_soldier_count(unit_type)
		var final_count: int = int(final_total.get(unit_type, 0))
		var loss: int = max(0, initial_total - final_count)
		if loss <= 0 or initial_total <= 0:
			continue
		var allocations: Array[Dictionary] = []
		var taken: int = 0
		for src in sources:
			var comp: ArmyComposition = src.get("comp", null)
			if comp == null:
				continue
			var count: int = comp.get_soldier_count(unit_type)
			if count <= 0:
				continue
			var share: float = float(loss) * float(count) / float(initial_total)
			var take: int = int(floor(share))
			var frac: float = share - float(take)
			allocations.append({"label": src.get("label", ""), "take": take, "frac": frac})
			taken += take
		var remainder: int = loss - taken
		allocations.sort_custom(func(a, b): return a["frac"] > b["frac"])
		var idx: int = 0
		while remainder > 0 and not allocations.is_empty():
			if idx >= allocations.size():
				idx = 0
			allocations[idx]["take"] = int(allocations[idx]["take"]) + 1
			remainder -= 1
			idx += 1
		for alloc in allocations:
			var label := String(alloc.get("label", ""))
			var take: int = int(alloc.get("take", 0))
			if take <= 0:
				continue
			for survivor in survivors:
				if survivor.get("label", "") == label:
					var comp: ArmyComposition = survivor.get("comp", null)
					if comp != null:
						var current := comp.get_soldier_count(unit_type)
						comp.set_soldier_count(unit_type, max(0, current - take))
					break
	return survivors

func _format_comp_line(prefix: String, name: String, comp: ArmyComposition) -> String:
	if comp == null:
		return "%s: %s [Power: 0 - none]" % [prefix, name]
	var power: int = _calculate_composition_power(comp)
	return "%s: %s [Power: %d - %s]" % [prefix, name, power, _format_composition_suffix(comp)]

func _record_attacker_for_defender(defender_player_id: int, attacking_armies: Array[Army]) -> void:
	if not is_player_computer(defender_player_id):
		return
	for atk in attacking_armies:
		if atk == null or not is_instance_valid(atk):
			continue
		record_enemy_army_power(defender_player_id, atk)

func _record_both_sides_power_snapshot(attacker: Army, defender_region: Region, defender_armies: Array[Army], defender_garrison: ArmyComposition, defender_recruits: int) -> void:
	if attacker != null and is_instance_valid(attacker):
		_record_enemy_presence_for_attacker(attacker.get_player_id(), defender_region)
	var defender_owner_id: int = defender_region.get_region_owner()
	if defender_owner_id > 0:
		var attacking_armies: Array[Army] = []
		if attacker != null and is_instance_valid(attacker):
			attacking_armies.append(attacker)
		_record_attacker_for_defender(defender_owner_id, attacking_armies)

func _record_battle_power_after_resolution(attacking_armies: Array[Army], defending_armies: Array[Army], defending_region: Region, defending_recruits_count: int, attacker_player_id: int, defender_owner_id: int) -> void:
	var defender_region: Region = defending_region
	if defending_region == null and not defending_armies.is_empty():
		defender_region = defending_armies[0].get_parent() as Region
	if defender_region != null and attacker_player_id > 0:
		_record_enemy_presence_for_attacker(attacker_player_id, defender_region)
	if defender_owner_id > 0:
		_record_attacker_for_defender(defender_owner_id, attacking_armies)

func _derive_battle_result_from_report(report: BattleSimulator.BattleReport) -> String:
	if report == null:
		return "defeat"
	match report.winner:
		"Attackers":
			return "victory"
		"Withdrawal":
			return "withdrawal"
		_:
			return "defeat"

func _on_battle_started(attacker: Army, target_region_id: int) -> void:
	_active_battles += 1
	DebugLogger.log("TurnProcessing", "Battle started. Active battles: " + str(_active_battles))

func _on_battle_finished(result: String) -> void:
	_active_battles = max(0, _active_battles - 1)
	DebugLogger.log("TurnProcessing", "Battle finished (" + result + "). Active battles: " + str(_active_battles))

func _await_pending_battles() -> void:
	"""Await until there are no active battles remaining."""
	while _active_battles > 0:
		await _battle_manager.battle_finished
	await _battle_manager.await_finalize_complete()

func finalize_battle_result(result_data: Dictionary) -> void:
	"""
	Single finalization function for all battle outcomes (Human and AI)
	Handles losses, retreat, conquest, and cleanup consistently
	"""
	var result: String = result_data.get("result", "defeat")
	var army: Army = result_data.get("army")
	var target_region_id: int = result_data.get("target_region_id", -1)
	var battle_report: BattleSimulator.BattleReport = result_data.get("battle_report")
	var attacking_armies_untyped: Array = result_data.get("attacking_armies", [])
	var attacking_armies: Array[Army] = attacking_armies_untyped
	var defending_armies_untyped: Array = result_data.get("defending_armies", [])
	var defending_armies: Array[Army] = defending_armies_untyped
	var defending_garrison: ArmyComposition = result_data.get("defending_garrison")
	var defending_recruits_region: Region = result_data.get("defending_recruits_region")
	var defending_recruits_count: int = result_data.get("defending_recruits_count", 0)
	var attacker_player_id: int = army.get_player_id() if army != null else -1
	var garrison_recorded: bool = bool(result_data.get("garrison_recorded", false))
	if attacker_player_id == -1 and not attacking_armies.is_empty():
		var first_attacker: Army = attacking_armies[0]
		if first_attacker != null and is_instance_valid(first_attacker):
			attacker_player_id = first_attacker.get_player_id()
	var defender_owner_id: int = -1
	if target_region_id != -1:
		defender_owner_id = _region_manager.get_region_owner(target_region_id)
	elif defending_recruits_region != null:
		defender_owner_id = defending_recruits_region.get_region_owner()
	if defender_owner_id == -1 and not defending_armies.is_empty():
		var first_defender: Army = defending_armies[0]
		if first_defender != null and is_instance_valid(first_defender):
			defender_owner_id = first_defender.get_player_id()
	var normalized_result := result
	if battle_report != null and battle_report.winner != null:
		match battle_report.winner:
			"Attackers":
				if result != "victory":
					DebugLogger.log("TurnProcessing", "Result mismatch (reported " + result + ", report Attackers). Normalizing to victory.")
				normalized_result = "victory"
			"Withdrawal":
				if result != "withdrawal":
					DebugLogger.log("TurnProcessing", "Result mismatch (reported " + result + ", report Withdrawal). Normalizing to withdrawal.")
				normalized_result = "withdrawal"
			_:
				if result != "defeat":
					DebugLogger.log("TurnProcessing", "Result mismatch (reported " + result + ", report " + battle_report.winner + "). Normalizing to defeat.")
				normalized_result = "defeat"
	
	var army_name = "unknown army"
	if army != null:
		army_name = army.get_display_name()
	DebugLogger.log("TurnProcessing", "Finalizing battle result: " + normalized_result + " for " + army_name)
	var withdrawing_side := int(result_data.get("withdrawing_side", 0))
	if withdrawing_side == 0 and battle_report != null:
		withdrawing_side = int(battle_report.withdrawing_side)
	var should_queue_battle_log := army != null and is_player_computer(army.get_player_id()) and battle_report != null
	var battle_log_lines: Array[String] = []
	var defender_entries: Array = []
	if should_queue_battle_log:
		defender_entries = _collect_defender_log_entries(defending_armies, defending_garrison, defending_recruits_region, defending_recruits_count, attacker_player_id)
		if not battle_report.gate_plan_log.is_empty():
			battle_log_lines.append_array(battle_report.gate_plan_log)
		battle_log_lines.append_array(_build_battle_pre_log_lines(army, defender_entries))
	
	# Wounded must be precomputed by the battle flow (modal/background) before finalization
	# GameManager does not compute wounded.
	# Allocate wounded to armies (attackers: single army; defenders: proportionally across armies, garrison, and recruits)
	# Attackers (apply to initiating army)
	if not attacking_armies.is_empty():
		var atk_army: Army = attacking_armies[0]
		for ut in battle_report.attacker_wounded.keys():
			atk_army.get_wounded_composition().add_soldiers(ut, int(battle_report.attacker_wounded[ut]))
	# Defenders - distribute among armies, garrison, and recruits proportionally (independent of attackers list)
	for ut in battle_report.defender_wounded.keys():
			var wounded_total: int = int(battle_report.defender_wounded[ut])
			if wounded_total <= 0:
				continue
			# Measure availability among all defender sources pre-application
			var avail: Array = [] # [{type: "army"/"garrison"/"recruits", ref: Army/Region, count:int}]
			var total_available: int = 0
			# Add armies
			for d in defending_armies:
				var cnt: int = d.get_composition().get_soldier_count(ut)
				if cnt > 0:
					avail.append({"type": "army", "ref": d, "count": cnt})
					total_available += cnt
			# Add garrison
			if defending_garrison != null:
				var g_cnt: int = defending_garrison.get_soldier_count(ut)
				if g_cnt > 0:
					avail.append({"type": "garrison", "ref": defending_recruits_region, "count": g_cnt})
					total_available += g_cnt
			# Add recruits (only for PEASANTS)
			if ut == SoldierTypeEnum.Type.PEASANTS and defending_recruits_count > 0 and defending_recruits_region != null:
				avail.append({"type": "recruits", "ref": defending_recruits_region, "count": defending_recruits_count})
				total_available += defending_recruits_count
			if total_available <= 0:
				continue
			# Proportional allocation by largest remainder
			var allocations: Array = [] # [{entry:dict, take:int, frac:float}]
			var taken_sum: int = 0
			for entry in avail:
				var share: float = float(wounded_total) * float(entry["count"]) / float(total_available)
				var take: int = int(floor(share))
				var frac: float = share - float(take)
				allocations.append({"entry": entry, "take": take, "frac": frac})
				taken_sum += take
			var remainder: int = wounded_total - taken_sum
			allocations.sort_custom(func(a, b): return a["frac"] > b["frac"])
			var i: int = 0
			while remainder > 0 and i < allocations.size():
				var entry = allocations[i]["entry"]
				var cap: int = entry["count"] - allocations[i]["take"]
				if cap > 0:
					allocations[i]["take"] += 1
					remainder -= 1
				i += 1
				if i >= allocations.size() and remainder > 0:
					i = 0
			# Apply wounded allocations to appropriate wounded pools
			for alloc in allocations:
				var entry = alloc["entry"]
				var take := int(alloc["take"])
				if take <= 0:
					continue
				match entry["type"]:
					"army":
						var army_d := entry["ref"] as Army
						army_d.get_wounded_composition().add_soldiers(ut, take)
					"garrison":
						var region := entry["ref"] as Region
						region.get_wounded_garrison().add_soldiers(ut, take)
					"recruits":
						var region := entry["ref"] as Region
						region.get_wounded_recruits().add_soldiers(ut, take)

	# Apply battle losses using BattleManager rule (removes both dead and wounded from active comps)
	if battle_report and _battle_manager:
		_battle_manager._apply_battle_losses()
		if should_queue_battle_log:
			var post_lines := _build_battle_post_log_lines(army, defender_entries, normalized_result, withdrawing_side)
			var combined := battle_log_lines.duplicate()
			combined.append_array(post_lines)
			combined.append("")
			_enqueue_ai_battle_log(army, combined)
		var attacker_id_snapshot: int = attacker_player_id
		if attacker_id_snapshot == -1 and army != null:
			attacker_id_snapshot = army.get_player_id()
		var defender_id_snapshot: int = defender_owner_id
		if battle_report.rounds > 0:
			_record_battle_power_after_resolution(attacking_armies, defending_armies, defending_recruits_region, defending_recruits_count, attacker_id_snapshot, defender_id_snapshot)
	
	# Handle battle outcome
	if normalized_result == "victory":
		if withdrawing_side == 2 and _battle_manager:
			await _battle_manager.retreat_defender_armies(defending_armies, defending_recruits_region)
		if _battle_manager:
			for defender in defending_armies:
				if defender != null and is_instance_valid(defender):
					var parent_region := defender.get_parent() as Region
					if parent_region != null:
						_battle_manager._apply_army_offsets_for_region(parent_region)
		var attacked_enemy_army := not defending_armies.is_empty()
		if army and is_instance_valid(army) and _army_manager and attacked_enemy_army:
			await _army_manager.reposition_army_in_region_with_animation(army)
		# Attackers won - handle conquest
		if army and is_instance_valid(army) and target_region_id != -1:
			army.play_victory()
			var player_id = army.get_player_id()
			_region_manager.set_region_ownership(target_region_id, player_id)
			var conquered_region = _region_manager.map_generator.get_region_container_by_id(target_region_id) as Region
			if conquered_region != null:
				conquered_region.kill_wounded_garrison()
			refresh_ai_debug_scores()
			player_manager.clear_enemy_garrison_memory(target_region_id)
			if garrison_recorded:
				DebugLogger.log("ArmyTracker", "Cleared tracked garrison for region " + str(target_region_id) + " after conquest by player " + str(player_id))
			DebugLogger.log("TurnProcessing", "Player " + str(player_id) + " conquered region " + str(target_region_id) + " via unified finalization")
			
			if is_player_computer(player_id) and _ai_camera_director:
				var conquest_delay = max(GameParameters.CAMERA_CONQUEST_DELAY, GameParameters.CAMERA_BATTLE_RESULT_DELAY)
				await _ai_camera_director.await_delay(conquest_delay)
			
			# Reduce efficiency for conquest
			army.reduce_efficiency(5)
			DebugLogger.log("TurnProcessing", "Reduced " + army.get_display_name() + " efficiency to " + str(army.get_efficiency()) + "% after conquest")
	elif normalized_result == "withdrawal":
		# Army withdrew - handle retreat and efficiency reduction
		if withdrawing_side == 0:
			withdrawing_side = int(result_data.get("withdrawing_side", 0))
		var attacker_can_withdraw_flag := bool(result_data.get("attacker_can_withdraw", false))
		var defender_can_withdraw_flag := bool(result_data.get("defender_can_withdraw", false))
		DebugLogger.log("BattleSystem", "Withdrawal finalization: side=" + str(withdrawing_side) + ", attacker_can=" + str(attacker_can_withdraw_flag) + ", defender_can=" + str(defender_can_withdraw_flag))
		DebugLogger.log("Withdrawal", "GameManager.finalize_battle_result start withdrawal side=" + str(withdrawing_side) + " attacker_can=" + str(attacker_can_withdraw_flag) + " defender_can=" + str(defender_can_withdraw_flag))
		if withdrawing_side == 0 and battle_report != null:
			withdrawing_side = int(battle_report.withdrawing_side)
			if withdrawing_side == 0:
				if defender_can_withdraw_flag and not attacker_can_withdraw_flag:
					withdrawing_side = 2
				elif attacker_can_withdraw_flag and not defender_can_withdraw_flag:
					withdrawing_side = 1
		DebugLogger.log("BattleSystem", "Resolved withdrawing_side=" + str(withdrawing_side))
		if withdrawing_side == 1:
			if army and is_instance_valid(army) and _battle_manager:
				var is_ai_withdraw := is_player_computer(army.get_player_id())
				DebugLogger.log("BattleSystem", "Applying attacker withdrawal for army " + army.get_display_name())
				await _battle_manager._handle_army_withdrawal(army)
				DebugLogger.log("Withdrawal", "GameManager.finalize_battle_result attacker retreat complete for " + army.get_display_name())
				if is_ai_withdraw and _ai_camera_director:
					await _ai_camera_director.await_focus_on_army(army)
					await _ai_camera_director.await_delay(GameParameters.CAMERA_BATTLE_RESULT_DELAY)
		elif withdrawing_side == 2:
			if _battle_manager:
				DebugLogger.log("BattleSystem", "Applying defender withdrawal retreat for defenders: " + str(defending_armies.size()))
				await _battle_manager.retreat_defender_armies(defending_armies, defending_recruits_region)
				DebugLogger.log("Withdrawal", "GameManager.finalize_battle_result defender retreat complete")
			if army and is_instance_valid(army) and target_region_id != -1:
				DebugLogger.log("BattleSystem", "Setting ownership after defender withdrawal to player " + str(army.get_player_id()) + " for region " + str(target_region_id))
				_region_manager.set_region_ownership(target_region_id, army.get_player_id())
				var conquered_region2 = _region_manager.map_generator.get_region_container_by_id(target_region_id) as Region
				if conquered_region2 != null:
					conquered_region2.kill_wounded_garrison()
				player_manager.clear_enemy_garrison_memory(target_region_id)
				if garrison_recorded:
					DebugLogger.log("ArmyTracker", "Cleared tracked garrison for region " + str(target_region_id) + " after withdrawal conquest by player " + str(army.get_player_id()))
				refresh_ai_debug_scores()
				if _army_manager:
					await _army_manager.reposition_army_in_region_with_animation(army)
		# No post-battle healing here; healing only occurs during make_camp()
	else:
		# Attackers lost - remove the army
		if army and is_instance_valid(army) and _battle_manager:
			_battle_manager._handle_battle_defeat(army)
			if is_player_computer(army.get_player_id()):
				if target_region_id != -1:
					var defeated_region = _region_manager.map_generator.get_region_container_by_id(target_region_id) as Region
					if defeated_region != null:
						await _ai_camera_director.await_focus_on_region(defeated_region)
					await _ai_camera_director.await_delay(GameParameters.CAMERA_BATTLE_RESULT_DELAY)

	_update_player_status_display()
	if attacker_player_id != -1:
		check_victory_conditions_for_player(attacker_player_id)

	if _visual_manager:
		_visual_manager.clear_interaction_highlights()
		if target_region_id != -1:
			_visual_manager.clear_region_highlight_state(target_region_id)

# Manager accessors for external systems
func get_battle_manager() -> BattleManager:
	"""Get the BattleManager instance"""
	return _battle_manager

func get_visual_manager() -> VisualManager:
	"""Get the VisualManager instance"""
	return _visual_manager

func get_tutorial_manager() -> TutorialManager:
	return _tutorial_manager

func get_trade_manager() -> TradeManager:
	return _trade_manager

func is_trade_disabled_for_current_game() -> bool:
	return game_mode == "scenario" and scenario_trade_disabled

func get_region_manager() -> RegionManager:
	"""Get the RegionManager instance"""
	return _region_manager

func get_army_manager() -> ArmyManager:
	"""Get the ArmyManager instance"""
	return _army_manager

func claim_peaceful_region(region_id: int, player_id: int) -> void:
	"""
	Claim a neutral region without battle (single authority for ownership changes).
	This is the proper way to claim regions through RegionManager.
	"""
	_region_manager.set_region_ownership(region_id, player_id)

func refresh_ai_debug_scores():
	"""Refresh AI debug scores for the current player (callable from external systems)"""
	if _ai_debug_visualizer and _ai_debug_visualizer.is_debug_visible():
		DebugLogger.log("TurnProcessing", "Manually refreshing AI debug scores for Player " + str(current_player))
		# Use the new recalculation method that handles ownership changes
		if _ai_debug_visualizer.has_method("recalculate_scores_on_ownership_change"):
			_ai_debug_visualizer.recalculate_scores_on_ownership_change(current_player)
		else:
			# Fallback to old method
			_ai_debug_visualizer._update_scores_for_player(current_player)
			_ai_debug_visualizer._update_display_cache_from_regions()
			_ai_debug_visualizer.queue_redraw()

# All AI turn processing is now handled by TurnController
# Legacy AI processing methods removed since TurnController handles all turn logic

func ai_travel_to(army: Army, final_region_id: int) -> Dictionary:
	"""
	AI travel wrapper for step-by-step movement with debug pausing.
	Gets the path using existing pathfinder, then iterates adjacent steps.
	For contested steps: use perform_region_entry(army, next_id, "ai")
	For friendly steps: use ArmyManager.move_army(army, next_region)
	Returns Dictionary: {"result": String, "battle_region_id": int}
	"""
	if army == null or not is_instance_valid(army):
		DebugLogger.log("AIPathfinding", "ai_travel_to: Invalid army")
		return {"result": "blocked", "battle_region_id": -1}
	
	var current_region = army.get_parent() as Region
	if current_region == null:
		DebugLogger.log("AIPathfinding", "ai_travel_to: Army not in valid region")
		return {"result": "blocked", "battle_region_id": -1}
	
	await _ai_camera_director.await_focus_on_army(army)
	await _ai_camera_director.await_delay(GameParameters.CAMERA_ARMY_START_DELAY)
	
	var current_region_id = current_region.get_region_id()
	var player_id = army.get_player_id()
	
	DebugLogger.log("AIPathfinding", "ai_travel_to: Army %s traveling from region %d to region %d" % [army.get_display_name(), current_region_id, final_region_id])
	
	var pathfinder = _turn_controller.pathfinder
	
	# Get path using existing pathfinder with same filters (friendly-only, passable)
	var path_result = pathfinder.find_path_to_target(current_region_id, final_region_id, player_id, true, true)
	if not path_result["success"]:
		DebugLogger.log("AIPathfinding", "ai_travel_to: No valid path found")
		return {"result": "blocked", "battle_region_id": current_region_id}
	
	var full_path = path_result["path"] as Array[int]
	if full_path.size() <= 1:
		DebugLogger.log("AIPathfinding", "ai_travel_to: Already at destination or invalid path")
		return {"result": "arrived", "battle_region_id": final_region_id}
	
	DebugLogger.log("AIPathfinding", "ai_travel_to: Path found with %d steps" % full_path.size())
	
	# Iterate adjacent steps starting from index 1 (skip current position)
	var last_battle_outcome := ""
	var last_battle_region_id: int = -1
	for i in range(1, full_path.size()):
		var next_region_id = full_path[i]

		# Check if army still has movement points
		if army.get_movement_points() <= 0:
			DebugLogger.log("AIMovement", "ai_travel_to: Army %s out of movement points, stopping at region %d" % [army.get_display_name(), army.get_parent().get_region_id()])
			return {"result": "out_of_movement_points", "battle_region_id": army.get_parent().get_region_id()}

		# Get next region for battle check
		var next_region_container = _region_manager.map_generator.get_region_container_by_id(next_region_id)
		if next_region_container == null:
			DebugLogger.log("AIMovement", "ai_travel_to: Invalid region %d in path" % next_region_id)
			return {"result": "blocked", "battle_region_id": next_region_id}
		
		var next_region = next_region_container as Region
		if next_region == null:
			DebugLogger.log("AIMovement", "ai_travel_to: Region %d is not valid" % next_region_id)
			return {"result": "blocked", "battle_region_id": next_region_id}
		# Debug step pausing using DebugStepGate
		if _turn_controller.debug_step_gate:
			DebugLogger.log("AIMovement", "ai_travel_to: Debug step - Army %s moving to region %d (step %d/%d)" % [army.get_display_name(), next_region_id, i, full_path.size()-1])
			await _turn_controller.debug_step_gate.step()
		
		# Check if this step should trigger battle
		if _should_trigger_battle(army, next_region):
			DebugLogger.log("AIMovement", "ai_travel_to: Contested step - using perform_region_entry")
			var battle_result = await perform_region_entry(army, next_region_id, "ai")
			
			# Log step result
			DebugLogger.log("AIMovement", "ai_travel_to: Battle result for step %d: %s" % [i, battle_result])
			
			match battle_result:
				"battle_victory":
					DebugLogger.log("AIMovement", "ai_travel_to: Army victorious, continuing movement")
					await _ai_camera_director.await_delay(GameParameters.CAMERA_BATTLE_RESULT_DELAY)
					last_battle_outcome = "battle_victory"
					last_battle_region_id = next_region_id
					continue
				"battle_withdrawal":
					DebugLogger.log("AIMovement", "ai_travel_to: Army withdrew from battle")
					await _ai_camera_director.await_delay(GameParameters.CAMERA_BATTLE_RESULT_DELAY)
					return {"result": "battle_withdrawal", "battle_region_id": next_region_id}
				"battle_defeat":
					DebugLogger.log("AIMovement", "ai_travel_to: Army defeated in battle")
					await _ai_camera_director.await_delay(GameParameters.CAMERA_BATTLE_RESULT_DELAY)
					return {"result": "battle_defeat", "battle_region_id": next_region_id}
				"blocked":
					DebugLogger.log("AIMovement", "ai_travel_to: Movement blocked")
					await _ai_camera_director.await_delay(GameParameters.CAMERA_BATTLE_RESULT_DELAY)
					return {"result": "blocked", "battle_region_id": next_region_id}
				_:
					DebugLogger.log("AIMovement", "ai_travel_to: Unexpected battle result: %s" % battle_result)
					await _ai_camera_director.await_delay(GameParameters.CAMERA_BATTLE_RESULT_DELAY)
					return {"result": "blocked", "battle_region_id": next_region_id}
		else:
			# Friendly step - use ArmyManager.move_army()
			DebugLogger.log("AIMovement", "ai_travel_to: Friendly step - using ArmyManager.move_army")
			var move_success = await _army_manager.move_army(army, next_region)
			if move_success:
				_handle_recruitment_merge_on_friendly_step(army, next_region)
			await _ai_camera_director.await_delay(GameParameters.CAMERA_FRIENDLY_MOVE_DELAY)
			
			# Log step result  
			if move_success:
				DebugLogger.log("AIMovement", "ai_travel_to: Friendly move successful for step %d" % i)
			else:
				DebugLogger.log("AIMovement", "ai_travel_to: Friendly move failed for step %d" % i)
				return {"result": "blocked", "battle_region_id": next_region_id}
	
	# Check if we reached the final destination
	var final_position = army.get_parent() as Region
	if final_position and final_position.get_region_id() == final_region_id:
		DebugLogger.log("AIMovement", "ai_travel_to: Army %s successfully arrived at region %d" % [army.get_display_name(), final_region_id])
		if last_battle_outcome != "":
			return {"result": last_battle_outcome, "battle_region_id": last_battle_region_id}
		return {"result": "arrived", "battle_region_id": final_region_id}
	else:
		var current_pos = final_position.get_region_id() if final_position else -1
		DebugLogger.log("AIMovement", "ai_travel_to: Army %s stopped at region %d (target was %d)" % [army.get_display_name(), current_pos, final_region_id])
		return {"result": "blocked", "battle_region_id": current_pos}

func _handle_recruitment_merge_on_friendly_step(moving_army: Army, region: Region) -> void:
	if not moving_army.is_recruitment_requested():
		return
	var friendly_armies: Array[Army] = []
	for region_army in _army_manager.get_armies_in_region(region):
		if not is_instance_valid(region_army):
			continue
		if region_army.get_player_id() != moving_army.get_player_id():
			continue
		friendly_armies.append(region_army)
	if friendly_armies.size() < 2:
		return
	friendly_armies.sort_custom(func(a: Army, b: Army) -> bool:
		var a_power: int = a.get_army_power()
		var b_power: int = b.get_army_power()
		if a_power != b_power:
			return a_power > b_power
		return a.get_instance_id() < b.get_instance_id()
	)
	var receiver: Army = friendly_armies[0]
	if receiver == moving_army:
		return
	var transferred: bool = _army_manager.transfer_all_soldiers(moving_army, receiver)
	if not transferred:
		return
	moving_army.spawn_minimal_peasant_token()
	_recheck_recruitment_need_after_transfer(receiver)

func _recheck_recruitment_need_after_transfer(army: Army) -> void:
	if not army.is_recruitment_requested():
		return
	var turn_number: int = get_current_turn()
	if army.needs_recruitment(turn_number, false, true, false):
		return
	army.clear_recruitment_request()
	army.set_recruitment_move_state(Army.RecruitmentMoveState.NORMAL)

# ============================================================================
# AI Battle Log Helpers
# ============================================================================

func _enqueue_ai_battle_log(army: Army, lines: Array[String]) -> void:
	if army == null or lines.is_empty():
		return
	var key := _get_ai_battle_log_key(army)
	var queue: Array = _ai_battle_log_queue.get(key, [])
	queue.append(lines)
	_ai_battle_log_queue[key] = queue

func _get_ai_battle_log_key(army: Army) -> String:
	return str(army.get_instance_id())

func _collect_defender_log_entries(defending_armies: Array, defending_garrison: ArmyComposition, defending_recruits_region: Region, defending_recruits_count: int, observer_id: int = -1, exclude_army: Army = null, exclude_player_id: int = -1) -> Array:
	var entries: Array = []
	var region_owner_id: int = -1
	if defending_recruits_region != null and _region_manager != null:
		region_owner_id = _region_manager.get_region_owner(defending_recruits_region.get_region_id())
	for defender in defending_armies:
		if defender == null:
			continue
		if exclude_army != null and defender == exclude_army:
			continue
		if exclude_player_id != -1 and defender.get_player_id() == exclude_player_id:
			continue
		if region_owner_id != -1 and defender.get_player_id() != region_owner_id:
			continue
		var known := false
		if observer_id > 0 and player_manager != null:
			var key := Player.get_enemy_tracker_key(defender)
			if key != "":
				known = player_manager.get_tracked_enemy_power(observer_id, key) >= 0
		entries.append({
			"type": "army",
			"ref": defender,
			"name": defender.name,
			"known": known
		})
	if defending_garrison != null:
		var g_known := false
		if observer_id > 0 and player_manager != null and defending_recruits_region != null:
			var rid := defending_recruits_region.get_region_id()
			g_known = player_manager.get_tracked_enemy_garrison_power(observer_id, rid) >= 0
		entries.append({
			"type": "garrison",
			"ref": defending_garrison,
			"name": "Garrison",
			"known": g_known
		})
	if defending_recruits_region != null:
		entries.append({
			"type": "recruits",
			"region": defending_recruits_region,
			"initial_count": max(0, defending_recruits_count),
			"known": false
		})
	return entries

func _build_battle_pre_log_lines(attacker: Army, defender_entries: Array) -> Array[String]:
	var lines: Array[String] = []
	lines.append("Battle started")
	lines.append(_format_attacker_line("Attacker", attacker, attacker.name if attacker else "Unknown Army"))
	if defender_entries.is_empty():
		lines.append("Defender: None")
	else:
		for entry in defender_entries:
			lines.append(_format_defender_pre_line(entry))
	return lines

func _build_battle_post_log_lines(attacker: Army, defender_entries: Array, result: String, withdrawing_side: int) -> Array[String]:
	var lines: Array[String] = []
	lines.append("Battle Result: %s" % _format_battle_result_label(result))
	if result == "withdrawal":
		var label := "Withdrawal: Unknown"
		if withdrawing_side == 1:
			label = "Withdrawal: Attacker"
		elif withdrawing_side == 2:
			label = "Withdrawal: Defender"
		lines.append(label)
	lines.append(_format_attacker_after_line("Attacker After", attacker, attacker.name if attacker else "Unknown Army"))
	if defender_entries.is_empty():
		lines.append("Defender After: None")
	else:
		for entry in defender_entries:
			lines.append(_format_defender_after_line(entry))
	return lines

func _format_attacker_line(prefix: String, army: Army, fallback_name: String) -> String:
	if army != null and is_instance_valid(army):
		return "%s: %s [Power: %d - %s]" % [prefix, army.get_display_name(), army.get_army_power(), _format_composition_suffix(army.get_composition())]
	return "%s: %s [Power: 0 - none]" % [prefix, fallback_name]

func _format_attacker_after_line(prefix: String, army: Army, fallback_name: String) -> String:
	if army != null and is_instance_valid(army):
		return "%s: %s [Power: %d - %s]" % [prefix, army.get_display_name(), army.get_army_power(), _format_composition_suffix(army.get_composition())]
	return "%s: %s destroyed" % [prefix, fallback_name]

func _format_defender_pre_line(entry: Dictionary) -> String:
	var status := "unknown" if not entry.get("known", false) else "known"
	if entry.get("type", "") == "garrison":
		var garrison_comp: ArmyComposition = entry.get("ref")
		return "Defender Garrison (%s) [Power: %d - %s]" % [
			status,
			_calculate_composition_power(garrison_comp),
			_format_composition_suffix(garrison_comp)
		]
	if entry.get("type", "") == "recruits":
		var region: Region = entry.get("region")
		var initial_count := int(entry.get("initial_count", 0))
		var label := "Defender Recruits"
		if region != null:
			label += " (%s)" % region.get_region_name()
		var comp := _build_peasant_composition(initial_count)
		return "%s (%s) [Power: %d - %s]" % [
			label,
			status,
			_calculate_composition_power(comp),
			_format_composition_suffix(comp)
		]
	var defender: Army = entry.get("ref")
	var label := "Defender %s" % entry.get("name", "Army")
	if defender != null and is_instance_valid(defender):
		return "%s (%s) [Power: %d - %s]" % [label, status, defender.get_army_power(), _format_composition_suffix(defender.get_composition())]
	return "%s (%s) [Power: 0 - none]" % [label, status]

func _format_defender_after_line(entry: Dictionary) -> String:
	var status := "unknown" if not entry.get("known", false) else "known"
	if entry.get("type", "") == "garrison":
		var garrison_comp: ArmyComposition = entry.get("ref")
		return "Defender After (Garrison): %s (%s) [Power: %d - %s]" % [
			entry.get("name", "Garrison"),
			status,
			_calculate_composition_power(garrison_comp),
			_format_composition_suffix(garrison_comp)
		]
	if entry.get("type", "") == "recruits":
		var region: Region = entry.get("region")
		var label := "Defender After (Recruits)"
		var remaining := 0
		if region != null:
			label += ": %s" % region.get_region_name()
			remaining = max(0, region.get_base_available_recruits())
		var comp := _build_peasant_composition(remaining)
		return "%s (%s) [Power: %d - %s]" % [
			label,
			status,
			_calculate_composition_power(comp),
			_format_composition_suffix(comp)
		]
	var defender: Army = entry.get("ref")
	var label := "Defender After: %s" % entry.get("name", "Army")
	if defender != null and is_instance_valid(defender):
		return "%s (%s) [Power: %d - %s]" % [label, status, defender.get_army_power(), _format_composition_suffix(defender.get_composition())]
	return "%s destroyed" % label

func _format_battle_result_label(result: String) -> String:
	match result:
		"victory":
			return "Won"
		"defeat":
			return "Defeated"
		"withdrawal":
			return "Withdrew"
		_:
			return result.capitalize()

func _format_composition_suffix(comp: ArmyComposition) -> String:
	if comp == null:
		return "none"
	var mapping = [
		{"type": SoldierTypeEnum.Type.PEASANTS, "label": "P"},
		{"type": SoldierTypeEnum.Type.SPEARMEN, "label": "S"},
		{"type": SoldierTypeEnum.Type.ARCHERS, "label": "A"},
		{"type": SoldierTypeEnum.Type.SWORDSMEN, "label": "SW"},
		{"type": SoldierTypeEnum.Type.CROSSBOWMEN, "label": "C"},
		{"type": SoldierTypeEnum.Type.HORSEMEN, "label": "H"},
		{"type": SoldierTypeEnum.Type.KNIGHTS, "label": "K"},
		{"type": SoldierTypeEnum.Type.MOUNTED_KNIGHTS, "label": "M"},
		{"type": SoldierTypeEnum.Type.ROYAL_GUARD, "label": "R"}
	]
	var parts: Array[String] = []
	for entry in mapping:
		var unit_type: SoldierTypeEnum.Type = entry["type"]
		var count := comp.get_soldier_count(unit_type)
		if count > 0:
			parts.append("%s:%d" % [entry["label"], count])
	if parts.is_empty():
		return "none"
	return ", ".join(parts)

func _calculate_composition_power(comp: ArmyComposition) -> int:
	if comp == null:
		return 0
	var total := 0
	for unit_type in SoldierTypeEnum.get_all_types():
		var qty := comp.get_soldier_count(unit_type)
		if qty <= 0:
			continue
		var unit_power: int = int(GameParameters.get_unit_stat(unit_type, "power"))
		total += unit_power * qty
	return total

func _build_peasant_composition(count: int) -> ArmyComposition:
	var comp := ArmyComposition.new()
	if count > 0:
		comp.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, count)
	return comp

func get_loaded_scenario_name() -> String:
	"""Get the name of the loaded scenario (for map editor)"""
	return loaded_scenario_name

func ensure_ai_log_started() -> void:
	if _ai_log_started:
		return
	var label = _derive_ai_log_label()
	_ai_log_manager.start_new_game_log(label)
	_ai_log_started = true

func _derive_ai_log_label() -> String:
	if loaded_scenario_name != "":
		return loaded_scenario_name
	if scenario_path != "":
		return scenario_path.get_file().get_basename()
	if game_mode == "custom":
		return "custom_game"
	return "free_play"

func get_ai_log_manager() -> AILogManager:
	return _ai_log_manager

func get_ai_battle_log_token(army: Army) -> String:
	if army == null:
		return ""
	return _get_ai_battle_log_key(army)

func consume_ai_battle_log_for_army(army: Army) -> Array[String]:
	if army == null:
		return []
	var key := _get_ai_battle_log_key(army)
	if not _ai_battle_log_queue.has(key):
		return []
	var queue: Array = _ai_battle_log_queue.get(key, [])
	if queue.is_empty():
		_ai_battle_log_queue.erase(key)
		return []
	var lines: Array[String] = queue[0]
	queue.remove_at(0)
	if queue.is_empty():
		_ai_battle_log_queue.erase(key)
	else:
		_ai_battle_log_queue[key] = queue
	return lines

func consume_ai_battle_log_for_token(token: String) -> Array[String]:
	if token == "":
		return []
	if not _ai_battle_log_queue.has(token):
		return []
	var queue: Array = _ai_battle_log_queue.get(token, [])
	if queue.is_empty():
		_ai_battle_log_queue.erase(token)
		return []
	var lines: Array[String] = queue[0]
	queue.remove_at(0)
	if queue.is_empty():
		_ai_battle_log_queue.erase(token)
	else:
		_ai_battle_log_queue[token] = queue
	return lines

func _start_first_turn() -> void:
	"""Start the first turn after castle placement completes"""
	DebugLogger.log("TurnProcessing", "_start_first_turn called for Player " + str(current_player))
	DebugLogger.log("TurnProcessing", "Player " + str(current_player) + " is human: " + str(is_player_human(current_player)))
	DebugLogger.log("TurnProcessing", "Player type: " + PlayerTypeEnum.type_to_string(get_player_type(current_player)))

	# Ensure PlayerStatusModal2 and IconsModal are visible for human players
	if is_player_human(current_player):
		DebugLogger.log("TurnProcessing", "Showing PlayerStatusModal2 and IconsModal for human player")
		var ui_node = get_node("../UI")
		var player_status_modal2 = ui_node.get_node("PlayerStatusModal2") as PlayerStatusModal2
		var icons_modal = ui_node.get_node("IconsModal") as Control
		DebugLogger.log("TurnProcessing", "PlayerStatusModal2 found: " + str(player_status_modal2 != null))
		DebugLogger.log("TurnProcessing", "IconsModal found: " + str(icons_modal != null))
		if player_status_modal2:
			_set_player_status_panel_visibility(current_player, ui_node)
			var panel = player_status_modal2.get_node("Panel")
			DebugLogger.log("TurnProcessing", "Called set_panel_visible(true), Panel exists: " + str(panel != null) + ", Panel.visible: " + str(panel.visible if panel else "null"))
		if icons_modal:
			icons_modal.visible = true
			DebugLogger.log("TurnProcessing", "Set IconsModal.visible = true")

	# Process player-specific turn start actions
	await _process_scenario_events_for_turn_start(current_player)
	if victory_declared:
		return
	await _process_player_turn_start(current_player)
	if check_victory_conditions_for_player(current_player):
		return
	_process_turn_start_autosave(current_player)
	
	if _tutorial_manager and not is_player_computer(current_player) and not _tutorial_manager.is_active():
		_tutorial_manager.start_tutorial(current_player)
	
	# Check if current player is AI and handle AI turn processing
	DebugLogger.log("TurnProcessing", "Checking AI turn: castle_placing_mode=" + str(castle_placing_mode) + ", current_player=" + str(current_player) + ", is_computer=" + str(is_player_computer(current_player)))
	if not castle_placing_mode and is_player_computer(current_player):
		DebugLogger.log("TurnProcessing", "AI Player " + str(current_player) + " starting first turn with TurnController...")
		
		# Enable debug display for AI turns
		if _ai_debug_visualizer:
			_ai_debug_visualizer.toggle_debug_display(current_player)
			DebugLogger.log("TurnProcessing", "Enabled AI debug display for Player " + str(current_player))
		
		await _turn_controller.start_turn(current_player)
		await _await_pending_battles()
		call_deferred("next_turn")  # Advance to next player after turn completes
		return  # Exit early since AI turn handling includes next_turn() call
	else:
		DebugLogger.log("TurnProcessing", "Skipping AI turn processing")
	
	# Note: next player modal and player status display are now handled by _on_current_player_changed signal handler
func _center_camera_on_player_assets(player_id: int) -> void:
	"""Center camera on player's first army, or if no armies, their castle"""
	var camera_controller = get_node("../Camera2D") as CameraController
	if camera_controller == null:
		DebugLogger.log("TurnProcessing", "Camera controller not found for player centering!")
		return
	
	DebugLogger.log("TurnProcessing", "Attempting to center camera for Player " + str(player_id))
	
	# First try to find the player's armies
	if _army_manager != null:
		var player_armies = _army_manager.get_player_armies(player_id)
		if not player_armies.is_empty():
			var first_army = player_armies[0]
			camera_controller.center_on_army(first_army)
			DebugLogger.log("TurnProcessing", "Centered camera on Player " + str(player_id) + "'s first army: " + first_army.get_display_name())
			return
	
	# If no armies, try to find their castle
	if _region_manager != null:
		var owned_regions = _region_manager.get_player_regions(player_id)
		var map_generator: MapGenerator = get_node("../Map") as MapGenerator
		if map_generator != null:
			var regions_node = map_generator.get_node_or_null("Regions")
			if regions_node != null:
				for region_id in owned_regions:
					var region_container = map_generator.get_region_container_by_id(region_id)
					if region_container != null:
						var castle = region_container.get_node_or_null("Castle")
						if castle != null:
							var castle_global_pos = castle.global_position
							camera_controller.center_on_position(castle_global_pos)
							DebugLogger.log("TurnProcessing", "Centered camera on Player " + str(player_id) + "'s castle in region " + str(region_id))
							return
	
	DebugLogger.log("TurnProcessing", "No assets found to center camera on for Player " + str(player_id))

func _take_game_screenshot() -> void:
	"""Take a screenshot using Utils function"""
	Utils.take_screenshot()

func _on_game_menu_main_menu_pressed() -> void:
	"""Handle Main Menu button from game menu"""
	DebugLogger.log("UISystem", "Returning to main menu")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_game_menu_save_game_pressed() -> void:
	var save_entries: Array[Dictionary] = SaveGameManager.get_save_entries()
	_save_game_modal.configure(SaveGameModal.Mode.SAVE, save_entries, SaveGameModal.Context.GAME_MENU)
	_save_game_modal.visible = true
	_save_game_modal.move_to_front()
	_ui_manager.set_modal_active(true)

func _on_game_menu_load_game_pressed() -> void:
	var save_entries: Array[Dictionary] = SaveGameManager.get_save_entries()
	_save_game_modal.configure(SaveGameModal.Mode.LOAD, save_entries, SaveGameModal.Context.GAME_MENU)
	_save_game_modal.visible = true
	_save_game_modal.move_to_front()
	_ui_manager.set_modal_active(true)

func _on_save_game_modal_back_requested(_context: int) -> void:
	_save_game_modal.visible = false
	_ui_manager.set_modal_active(true)

func _on_save_game_modal_action_requested(mode: int, selected_file_name: String, entered_file_name: String) -> void:
	var save_ok: bool = false
	if mode == SaveGameModal.Mode.SAVE:
		var target_file_name: String = entered_file_name if entered_file_name != "" else selected_file_name
		save_ok = SaveGameManager.save_game_named(self, target_file_name)
		var save_entries: Array[Dictionary] = SaveGameManager.get_save_entries()
		_save_game_modal.configure(SaveGameModal.Mode.SAVE, save_entries, SaveGameModal.Context.GAME_MENU)
	elif mode == SaveGameModal.Mode.LOAD:
		if selected_file_name == "":
			DebugLogger.log("SaveGame", "ERROR: No save file selected")
			return
		var save_path: String = SaveGameManager.build_save_path_from_file_name(selected_file_name)
		get_tree().paused = false
		get_tree().set_meta("start_payload", {
			"type": "save",
			"save_path": save_path
		})
		get_tree().change_scene_to_file("res://main.tscn")
		return
	if save_ok:
		DebugLogger.log("SaveGame", "Game saved")
	else:
		DebugLogger.log("SaveGame", "ERROR: Failed to save game")

func _on_game_menu_exit_pressed() -> void:
	"""Handle Exit Game button from game menu"""
	_on_game_menu_main_menu_pressed()

func handle_human_end_turn() -> void:
	_auto_camp_armies_for_player(current_player)
	next_turn()

func _auto_camp_armies_for_player(player_id: int) -> void:
	var armies: Array[Army] = _army_manager.get_player_armies(player_id)
	for army in armies:
		while army.get_movement_points() > 0:
			army.make_camp()
