extends Node
class_name GameManager

signal player_status_refresh_requested

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
@export var debug_mode: bool = false
@export var show_region_center_markers: bool = false
var _next_player_modal: NextPlayerModal
var _game_menu_modal: Control
var _sound_manager: SoundManager
var tutorial_enabled: bool = false
# Map editor mode state
var enable_map_editor: bool = false  # Configurable flag to enable map editor mode


# References to other managers
var click_manager: Node = null

const FAMINE_MIN_POPULATION: int = 30
const FAMINE_POP_PER_FOOD: float = 0.1

var _player_initial_turn_completed: Dictionary = {}

# Scenario mode
var game_mode: String = "scenario"  # "custom" | "scenario"
var scenario_path: String = ""
# var scenario_path: String = "battle_test.json"
var loaded_scenario_name: String = ""  # Track the loaded scenario name for the editor
var _ai_log_manager: AILogManager = AILogManager.new()
var _ai_log_started: bool = false
var _ai_battle_log_queue: Dictionary = {}
var average_army_power: float = 0.0

func _ready():
	# If EditorStart provided a payload, force-enable editor mode
	if get_tree().has_meta("editor_start_payload") and get_tree().get_meta("editor_start_payload") != null:
		enable_map_editor = true

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
		elif kind == "map":
			game_mode = "custom"
			scenario_path = ""
			var map_path := String(payload.get("map_file", ""))
			var size_str := String(payload.get("map_size", "small"))
			map_generator.data_file_path = map_path.get_file()
			_map_set_size_from_string(map_generator, size_str)
			
			# Apply player settings from CustomMap
			if payload.has("player_settings"):
				_apply_custom_map_player_settings(payload.get("player_settings"))
			
			map_generator.generate_map()
		# Clear payload to avoid reuse
		get_tree().set_meta("start_payload", null)

	# Scenario pre-load: if scenario mode, set map file upfront and regenerate map
	if game_mode == "scenario" and scenario_path != "":
		var map_generator: MapGenerator = get_node("../Map") as MapGenerator
		# Normalize scenario path to res://scenarios/<file>
		var scen_file := String(scenario_path).get_file()
		var scen_full := "res://scenarios/" + scen_file
		var scen := ScenarioManager.new().load_scenario(scen_full)
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
	initialize_managers(game_mode == "scenario")
	_apply_initial_camera_zoom()
	_apply_center_marker_setting()
	_show_custom_start_prompt()

	if tutorial_enabled:
		_sound_manager.set_active_playlist("tutorial")
	
	# Start the game audio sequence after a brief delay to ensure sound manager is ready
	await get_tree().process_frame
	if _sound_manager:
		DebugLogger.log("GameInit", "Starting game audio sequence...")
		# Respect user's music setting; do not force-enable
		_sound_manager.play_game_start_sequence()
	else:
		DebugLogger.log("GameInit", "Error: Sound manager not found!")

func initialize_managers(is_scenario: bool = false):
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
	_game_menu_modal = ui_node.get_node("GameMenuModal") as Control
	_message_modal = ui_node.get_node("MessageModal") as MessageModal
	if _game_menu_modal:
		_game_menu_modal.connect("main_menu_pressed", _on_game_menu_main_menu_pressed)
		_game_menu_modal.connect("exit_pressed", _on_game_menu_exit_pressed)
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
	# Apply to runtime
	scen_mgr.apply_to_runtime(map_generator, _region_manager, _army_manager, _visual_manager, scen, player_manager)

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
	current_player = 1
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
	# Start first turn immediately
	_start_first_turn()

func _unhandled_input(event: InputEvent) -> void:
	# Handle keyboard shortcuts
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _game_menu_modal and not enable_map_editor:
				if _game_menu_modal.visible:
					_game_menu_modal.hide_modal()
				else:
					_game_menu_modal.show_modal()
		elif event.keycode == KEY_ENTER:
			next_turn()
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
		elif event.keycode == KEY_F8:
			# Take screenshot with proper setup
			_take_game_screenshot()
		# SPACE key handling is now managed by TurnController's DebugStepGate

func next_turn():
	"""Advance to the next player's turn and perform turn-based actions"""
	if debug_heatmap:
		DebugLogger.log("TurnProcessing", "Debug heatmap mode active - next_turn ignored")
		return
	if _army_manager:
		_army_manager.set_ready_highlight_player(-1)
	
	# Get next active player in sequence (skips OFF players)
	var next_player_id = _get_next_active_player()
	var is_new_round = (next_player_id == players_per_round[0])
	
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
		_process_player_turn_start(current_player)
	
	# Check if current player is AI and handle AI turn processing
	DebugLogger.log("TurnProcessing", "Checking AI turn: castle_placing_mode=" + str(castle_placing_mode) + ", current_player=" + str(current_player) + ", is_computer=" + str(is_player_computer(current_player)))
	if not castle_placing_mode and is_player_computer(current_player):
		DebugLogger.log("TurnProcessing", "AI Player " + str(current_player) + " starting turn processing with TurnController...")
		await _turn_controller.start_turn(current_player)
		await _await_pending_battles()
		next_turn()  # Advance to next player after turn completes
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
	# Provide to ClickManager so editor code can use them
	click_manager = get_node("../ClickManager")
	if click_manager.has_method("set_managers"):
		click_manager.set_managers(_region_manager, _army_manager)

	# If a scenario was queued, apply its deltas now
	if get_tree().has_meta("__scenario_to_apply__") and get_tree().get_meta("__scenario_to_apply__") != null:
		var scen: Dictionary = get_tree().get_meta("__scenario_to_apply__") as Dictionary
		get_tree().set_meta("__scenario_to_apply__", null)
		var player_manager_node = get_node("../PlayerManager") as PlayerManagerNode
		ScenarioManager.new().apply_to_runtime(map_generator, _region_manager, _army_manager, null, scen, player_manager_node)

	# Hide player/turn UI modals that are not needed in editor mode
	var ui_node = get_node("../UI")
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
	var zoom_value := _get_initial_zoom_value(map_generator.map_size)
	camera_controller.set_zoom_immediate(zoom_value)

func _get_initial_zoom_value(map_size: MapGenerator.MapSize) -> float:
	match map_size:
		MapGenerator.MapSize.MEDIUM:
			return 1.5
		MapGenerator.MapSize.LARGE:
			return 2.0
		_:
			return 1.0

func _map_set_size_from_string(mg: MapGenerator, size_str: String) -> void:
	# First check if it's a new size name that needs conversion
	var old_size_names = ["xtiny", "tiny", "small", "medium", "large", "huge"]
	var input_lower = size_str.to_lower()
	
	# If it's not an old size name, try to convert from new naming
	var actual_size = size_str
	if not input_lower in old_size_names:
		actual_size = _convert_new_size_to_old(size_str)
	
	var s := actual_size.to_lower()
	match s:
		"xtiny":
			mg.map_size = MapGenerator.MapSize.XTINY
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

func _convert_new_size_to_old(new_size: String) -> String:
	"""Convert new size names back to old internal names for MapGenerator"""
	var size_lower = new_size.to_lower()
	match size_lower:
		"small":
			return "xtiny"  # New Small maps to old XTiny
		"medium":
			return "tiny"   # New Medium maps to old Tiny  
		"large":
			return "small"  # New Large maps to old Small
		"huge":
			return "medium" # New Huge maps to old Medium
		_:
			return new_size  # Return as-is for old names or unknown

func _on_map_generated() -> void:
	_apply_center_marker_setting()

func _apply_center_marker_setting() -> void:
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	map_generator.set_center_markers_enabled(show_region_center_markers)

func _show_custom_start_prompt() -> void:
	if game_mode != "custom":
		return
	if enable_map_editor:
		return
	if _message_modal == null:
		return
	_message_modal.call_deferred("display_message", "Click a region to choose your starting location")

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


func _initialize_castle_placement_sequence() -> void:
	"""Initialize castle placement sequence, starting with first active player"""
	# Find the first active player to start castle placement
	current_player = 1
	if not is_player_active(current_player):
		current_player = _get_next_active_player()
	
	player_manager.set_current_player(current_player)
	DebugLogger.log("GameInit", "Castle placement starting with Player " + str(current_player) + " (" + PlayerTypeEnum.type_to_string(get_player_type(current_player)) + ")")
	
	# If the first player is AI, trigger AI placement immediately
	if is_player_computer(current_player):
		DebugLogger.log("GameInit", "First player is AI - starting automatic placement...")
		# Use a small delay to ensure all systems are ready
		await get_tree().create_timer(1.0).timeout
		await _handle_ai_castle_placement(current_player)

func _process_round_start_actions():
	"""Process actions that happen once per round (when Player 1 starts)"""
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
	_player_initial_turn_completed[player_id] = true
	_update_player_status_display()
	


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
	var player = player_manager.get_player(player_id)
	if player == null:
		DebugLogger.log("TurnProcessing", "Warning: Player " + str(player_id) + " not found for food cost processing")
		return
	
	# Calculate total food cost for all armies and garrisons
	var total_food_cost = player_manager.calculate_total_army_food_cost(player_id)
	
	if total_food_cost > 0:
		# Convert float cost to integer (round up)
		var food_cost_int = int(ceil(total_food_cost))
		
		DebugLogger.log("TurnProcessing", "Total army food cost for Player " + str(player_id) + ": " + str(total_food_cost) + " (rounded: " + str(food_cost_int) + ")")
		
		# Check if player has enough food
		var current_food = player.get_resource_amount(ResourcesEnum.Type.FOOD)
		var net_food_after = current_food - food_cost_int
		if net_food_after >= 0:
			player.set_resource_amount(ResourcesEnum.Type.FOOD, net_food_after)
			DebugLogger.log("TurnProcessing", "Deducted " + str(food_cost_int) + " food from Player " + str(player_id) + " (" + str(net_food_after) + " remaining)")
		else:
			DebugLogger.log("TurnProcessing", "WARNING: Player " + str(player_id) + " doesn't have enough food! Required: " + str(food_cost_int) + ", Available: " + str(current_food))
			var shortage: float = max(0.0, total_food_cost - float(current_food))
			player.set_resource_amount(ResourcesEnum.Type.FOOD, 0)
			if shortage > 0.0:
				DebugLogger.log("TurnProcessing", "Triggering famine for Player " + str(player_id) + " (food deficit: " + str(snappedf(shortage, 0.01)) + ")")
				famine_regions(player_id, shortage)
	else:
		DebugLogger.log("TurnProcessing", "No army food costs for Player " + str(player_id))

func famine_regions(player_id: int, missing_food: float) -> void:
	missing_food = max(0.0, missing_food)
	if missing_food <= 0.0:
		return
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	if map_generator == null or _region_manager == null or _army_manager == null:
		DebugLogger.log("TurnProcessing", "Cannot process famine - missing managers")
		return
	var entry_map: Dictionary = {}
	var total_men := 0
	var owned_region_ids = _region_manager.get_player_regions(player_id)
	for region_id in owned_region_ids:
		var region = map_generator.get_region_container_by_id(region_id) as Region
		if region == null:
			continue
		var entry = _get_or_create_famine_entry(entry_map, region)
		entry.owns_region = true
		var garrison_comp: ArmyComposition = region.get_garrison()
		var garrison_total := 0
		if garrison_comp != null:
			garrison_total = garrison_comp.get_total_soldiers()
		entry.garrison = garrison_comp
		entry.total_men += garrison_total
		entry_map[region] = entry
		total_men += garrison_total
	var player_armies = _army_manager.get_player_armies(player_id)
	for army in player_armies:
		if army == null or not is_instance_valid(army):
			continue
		var region_node = army.get_parent()
		if region_node == null or not (region_node is Region):
			continue
		var region = region_node as Region
		var entry = _get_or_create_famine_entry(entry_map, region)
		var soldier_count = army.get_total_soldiers()
		entry.armies.append(army)
		entry.total_men += soldier_count
		entry_map[region] = entry
		total_men += soldier_count
	if total_men <= 0:
		DebugLogger.log("TurnProcessing", "Famine skipped for Player " + str(player_id) + " - no stationed troops")
		return
	var total_population_loss_target = int(floor(missing_food / FAMINE_POP_PER_FOOD))
	if total_population_loss_target <= 0:
		return
	var entries_with_men: Array = []
	var entries_all: Array = []
	var floor_sum := 0
	for region in entry_map.keys():
		var entry = entry_map[region]
		if entry.total_men > 0:
			var share_food := missing_food * float(entry.total_men) / float(total_men)
			var pop_loss_float := share_food / FAMINE_POP_PER_FOOD
			entry.loss_target_float = pop_loss_float
			entry.loss_int = int(floor(pop_loss_float))
			entry.fraction = pop_loss_float - float(entry.loss_int)
			floor_sum += entry.loss_int
			entries_with_men.append(entry)
		else:
			entry.loss_target_float = 0.0
			entry.loss_int = 0
			entry.fraction = 0.0
		entries_all.append(entry)
	var remainder: int = int(max(0, total_population_loss_target - floor_sum))
	if remainder > 0 and entries_with_men.size() > 0:
		entries_with_men.sort_custom(Callable(self, "_sort_famine_fraction_desc"))
		var idx := 0
		while remainder > 0 and entries_with_men.size() > 0:
			entries_with_men[idx].loss_int += 1
			remainder -= 1
			idx = (idx + 1) % entries_with_men.size()
	for entry in entries_all:
		var pop_loss_target: int = entry.loss_int
		if pop_loss_target <= 0:
			continue
		var region: Region = entry.region
		var actual_loss = region.apply_population_loss(pop_loss_target, FAMINE_MIN_POPULATION)
		var leftover = pop_loss_target - actual_loss
		var reached_minimum := region.get_population() <= FAMINE_MIN_POPULATION
		if entry.owns_region and reached_minimum:
			var garrison_comp: ArmyComposition = entry.garrison
			if garrison_comp != null and garrison_comp.get_total_soldiers() > 0:
				var removed = _remove_casualties_from_composition(garrison_comp, garrison_comp.get_total_soldiers())
				leftover = max(0, leftover - removed)
				DebugLogger.log("TurnProcessing", "Famine wiped garrison in " + region.get_region_name())
		if leftover > 0:
			leftover = _apply_army_starvation(entry.armies, leftover)
			if leftover > 0:
				DebugLogger.log("TurnProcessing", "Famine leftover " + str(leftover) + " not absorbed in region " + region.get_region_name())
	_army_manager.remove_destroyed_armies()

func has_completed_initial_turn(player_id: int) -> bool:
	return _player_initial_turn_completed.get(player_id, false)

func _get_or_create_famine_entry(entry_map: Dictionary, region: Region) -> Dictionary:
	if entry_map.has(region):
		return entry_map[region]
	var data = {
		"region": region,
		"garrison": region.get_garrison(),
		"armies": [],
		"total_men": 0,
		"owns_region": false,
		"loss_target_float": 0.0,
		"loss_int": 0,
		"fraction": 0.0
	}
	entry_map[region] = data
	return data

func _sort_famine_fraction_desc(a: Dictionary, b: Dictionary) -> bool:
	return a.fraction > b.fraction

func _remove_casualties_from_composition(composition: ArmyComposition, casualties: int) -> int:
	if composition == null or casualties <= 0:
		return 0
	var remaining := casualties
	for unit_type in SoldierTypeEnum.get_all_types():
		if remaining <= 0:
			break
		var available = composition.get_soldier_count(unit_type)
		if available <= 0:
			continue
		var to_remove = min(available, remaining)
		composition.remove_soldiers(unit_type, to_remove)
		remaining -= to_remove
	return casualties - remaining

func _apply_army_starvation(armies: Array, casualties: int) -> int:
	if casualties <= 0 or armies.is_empty():
		return casualties
	var army_data: Array = []
	var total_soldiers := 0
	for army in armies:
		if army == null or not is_instance_valid(army):
			continue
		var soldiers = army.get_total_soldiers()
		if soldiers <= 0:
			continue
		var data = {
			"army": army,
			"soldiers": soldiers,
			"loss": 0,
			"fraction": 0.0
		}
		army_data.append(data)
		total_soldiers += soldiers
	if total_soldiers <= 0:
		return casualties
	var total_target = min(casualties, total_soldiers)
	var floor_sum := 0
	for data in army_data:
		var share_float := float(data.soldiers) / float(total_soldiers) * float(total_target)
		var loss_int := int(floor(share_float))
		data.loss = loss_int
		data.fraction = share_float - float(loss_int)
		floor_sum += loss_int
	var remainder: int = int(max(0, total_target - floor_sum))
	if remainder > 0:
		army_data.sort_custom(Callable(self, "_sort_famine_fraction_desc"))
		var idx := 0
		while remainder > 0 and army_data.size() > 0:
			army_data[idx].loss += 1
			remainder -= 1
			idx = (idx + 1) % army_data.size()
	for data in army_data:
		var loss_count: int = data.loss
		if loss_count <= 0:
			continue
		var army: Army = data.army
		_remove_casualties_from_composition(army.get_composition(), loss_count)
	return casualties - total_target

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
	
	# Show next player modal only for active players
	if _next_player_modal and is_player_active(player_id):
		var allow_castle_modal := not castle_placing_mode or is_player_human(player_id)
		if allow_castle_modal:
			_next_player_modal.show_next_player(player_id, castle_placing_mode)
	
	DebugLogger.log("TurnProcessing", "Round " + str(current_turn) + " - Player " + str(player_id) + "'s turn")

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
	return GameParameters.get_starting_army_composition_for_player_type(get_player_type(player_id))

func is_player_active(player_id: int) -> bool:
	"""Check if a player is active (not OFF)"""
	return get_player_type(player_id) != PlayerTypeEnum.Type.OFF

func is_player_human(player_id: int) -> bool:
	"""Check if a player is human controlled"""
	return get_player_type(player_id) == PlayerTypeEnum.Type.HUMAN

func is_player_computer(player_id: int) -> bool:
	"""Check if a player is AI controlled"""
	return get_player_type(player_id) == PlayerTypeEnum.Type.COMPUTER

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
	if not is_player_computer(observer_id):
		return
	player_manager.record_enemy_army_power(observer_id, enemy_army)

func record_enemy_garrison(observer_id: int, region_id: int, power: int) -> void:
	if player_manager == null:
		return
	if not is_player_computer(observer_id):
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

		# Set current player to Player 1 to start normal gameplay
		current_player = 1
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
	if is_player_human(current_player):
		# Show next player modal for human player
		if _next_player_modal:
			_next_player_modal.show_next_player(current_player, true)
	elif is_player_computer(current_player):
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
				return "battle_victory"
			elif result == "withdrawal":
				return "battle_withdrawal"
			else:
				return "battle_defeat"

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
	_record_enemy_presence_for_attacker(attacker_owner_id, target_region)
	var siege_payload := {}
	if is_player_computer(attacker_owner_id):
		if _should_ai_withdraw_pre_siege(army, target_region):
			_log_ai_prebattle_withdraw(army, target_region, "pre_siege_power_check")
			_record_both_sides_power_snapshot(army, target_region, [], target_region.get_garrison(), target_region.get_base_available_recruits())
			DebugLogger.log("Withdrawal", "[Pre-Battle] AI attacker withdrawing before siege prep due to unfavorable power vs defense.")
			await _battle_manager.withdraw_attacking_army(army)
			return "withdrawal"
	if is_player_computer(attacker_owner_id):
		siege_payload = _execute_ai_siege_preparation(army, target_region)
		if _should_ai_withdraw_post_siege(army, target_region, siege_payload):
			_log_ai_prebattle_withdraw(army, target_region, "post_siege_power_check")
			_record_both_sides_power_snapshot(army, target_region, [], target_region.get_garrison(), target_region.get_base_available_recruits())
			DebugLogger.log("Withdrawal", "[Pre-Battle] AI attacker withdrawing after siege prep due to unfavorable power ratio.")
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

func _execute_ai_siege_preparation(attacker: Army, target_region: Region) -> Dictionary:
	var castle_defense := GameParameters.get_castle_defense_bonus(target_region.get_castle_type())
	if castle_defense <= 0:
		return {}
	var siege_points_total: int = GameParameters.calculate_siege_points_for_composition(attacker.get_composition())
	var player_id := attacker.get_player_id()
	var player := player_manager.get_player(player_id)
	var available_wood: int = player.get_resource_amount(ResourcesEnum.Type.WOOD)
	var wood_growth: int = int(floor(player_manager.get_player_resource_growth(player_id, ResourcesEnum.Type.WOOD)))
	var wood_budget: int = _calculate_siege_wood_budget(available_wood, wood_growth)
	var remaining_points: int = siege_points_total
	var remaining_wood: int = wood_budget
	var siege_counts: Dictionary = {"trebuchets": 0, "rams": 0, "ladders": 0}
	var siege_data: Dictionary = {
		"trebuchets": PrebattleModal.TREB_DATA,
		"rams": PrebattleModal.RAM_DATA,
		"ladders": PrebattleModal.LADDER_DATA
	}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# --- Trebuchets ---
	var wall_state: Dictionary = target_region.get_wall_state()
	var wall_sections: int = int(wall_state.get("wall_sections", 0))
	var destroyed_sections: int = int(wall_state.get("destroyed_sections", 0))
	var treb_data: Dictionary = siege_data["trebuchets"]
	var treb_points_cost: int = int(treb_data.get("points", 0))
	var treb_wood_cost: int = int(treb_data.get("wood", 0))
	var treb_max_allowed: int = int(treb_data.get("max", 0))
	var castle_level: int = int(target_region.get_castle_type())
	var treb_min_raw: int = castle_level - 1 - destroyed_sections
	var treb_min: int = max(0, treb_min_raw)
	var treb_max: int = max(treb_min, wall_sections - destroyed_sections)
	var trebuchets_target: int = 0
	if treb_points_cost > 0 and treb_max > 0 and siege_points_total > 6:
		trebuchets_target = rng.randi_range(treb_min, treb_max)
		var attacker_power: int = attacker.get_army_power()
		var defender_power: int = _compute_region_total_defender_power(target_region)
		var ratio_denominator: int = defender_power if defender_power > 0 else 1
		var ratio_value: float = float(attacker_power) / float(ratio_denominator)
		var reduce_by: int = max(0, int(floor(ratio_value)) - 3)
		trebuchets_target = max(treb_min, trebuchets_target - reduce_by)
		var max_by_points: int = int(remaining_points / treb_points_cost)
		var max_by_wood: int = int(remaining_wood / treb_wood_cost) if treb_wood_cost > 0 else max_by_points
		var max_cap: int = treb_max if treb_max_allowed <= 0 else min(treb_max, treb_max_allowed)
		trebuchets_target = clampi(trebuchets_target, treb_min, max_cap)
		trebuchets_target = min(trebuchets_target, max_by_points, max_by_wood)
		if trebuchets_target > 0:
			siege_counts["trebuchets"] = trebuchets_target
			remaining_points -= trebuchets_target * treb_points_cost
			if treb_wood_cost > 0:
				remaining_wood -= trebuchets_target * treb_wood_cost
	# --- Rams ---
	var ram_data: Dictionary = siege_data["rams"]
	var ram_points: int = int(ram_data.get("points", 0))
	var ram_wood: int = int(ram_data.get("wood", 0))
	var ram_max: int = int(ram_data.get("max", 0))
	var gate_state: Dictionary = target_region.get_gate_state()
	var total_gates: int = int(gate_state.get("gates", 0))
	var destroyed_gates: int = int(gate_state.get("destroyed_gates", 0))
	var intact_gates: int = max(0, total_gates - destroyed_gates)
	if ram_points > 0 and remaining_points > 0 and intact_gates > 0:
		var ram_points_spend: int = rng.randi_range(0, remaining_points)
		var max_by_points_ram: int = int(ram_points_spend / ram_points)
		var max_by_wood_ram: int = int(remaining_wood / ram_wood) if ram_wood > 0 else max_by_points_ram
		var ram_cap: int = intact_gates
		if ram_max > 0:
			ram_cap = min(ram_cap, ram_max)
		var ram_count: int = min(max_by_points_ram, max_by_wood_ram, ram_cap)
		if ram_count > 0:
			siege_counts["rams"] = ram_count
			remaining_points -= ram_count * ram_points
			if ram_wood > 0:
				remaining_wood -= ram_count * ram_wood
	# --- Ladders ---
	var ladder_data: Dictionary = siege_data["ladders"]
	var ladder_points: int = int(ladder_data.get("points", 0))
	var ladder_max: int = int(ladder_data.get("max", 0))
	if ladder_points > 0 and remaining_points > 0:
		var ladder_capacity: int = _battle_manager.compute_ladder_capacity(target_region)
		var max_by_points_ladder: int = int(remaining_points / ladder_points)
		var ladder_cap: int = ladder_capacity
		if ladder_max > 0:
			ladder_cap = min(ladder_cap, ladder_max)
		var ladder_count: int = min(max_by_points_ladder, ladder_cap)
		if ladder_count > 0:
			siege_counts["ladders"] = ladder_count
			remaining_points -= ladder_count * ladder_points
	var wood_spent := 0
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
	var wall_raw := _battle_manager.compute_wall_assault_raw(target_region)
	var wall_ratio_calc := _battle_manager.compute_wall_assault_ratio(target_region, attacker.get_composition())
	var gate_ratio := _battle_manager.compute_gate_assault_ratio(target_region)
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
	_log_ai_siege_preparation(siege_points_total, available_wood, limit_label, siege_counts)
	var wall_state_log: Dictionary = bombard_state
	if wall_state_log.is_empty():
		wall_state_log = target_region.get_wall_state()
	var breached_log: int = int(wall_state_log.get("destroyed_sections", 0))
	var damaged_log: int = int(wall_state_log.get("damaged_sections", 0))
	_log_ai_siege_purchase_summary(siege_points_total, siege_counts, breached_log, damaged_log)
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
	var wall_effectiveness_raw := _battle_manager.compute_wall_assault_raw(region)
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

func _log_ai_siege_preparation(points: int, wood_available: int, wood_limit_label: String, siege_counts: Dictionary) -> void:
	ensure_ai_log_started()
	_ai_log_manager.log_siege_preparation(points, wood_available, wood_limit_label, siege_counts)

func _log_ai_siege_purchase_summary(points: int, siege_counts: Dictionary, breached_sections: int, damaged_sections: int) -> void:
	var ladders: int = int(siege_counts.get("ladders", 0))
	var rams: int = int(siege_counts.get("rams", 0))
	var trebs: int = int(siege_counts.get("trebuchets", 0))
	var msg := "[AI Siege] SP available: " + str(points) + ", Ladders: " + str(ladders) + ", Siege Rams: " + str(rams) + ", Trebuchets: " + str(trebs) + ", Breached: " + str(breached_sections) + ", Damaged: " + str(damaged_sections)
	DebugLogger.log("BattleCalculation", msg)
	ensure_ai_log_started()
	_ai_log_manager.log_siege_purchase_summary(points, siege_counts, breached_sections, damaged_sections)

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
	if target_owner == observer_id or target_owner == -1:
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
	var target_ratio: float = 1.5
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
	var withdraw_threshold: float = GameParameters.AI_WITHDRAW_POWER_THRESHOLD
	if target_region.get_castle_type() != CastleTypeEnum.Type.NONE:
		assault_multiplier = max(0.0, _compute_attacker_effectiveness_ratio(attacker, siege_payload, target_region))
		var siege_counts: Dictionary = siege_payload.get("siege_counts", {})
		var rams: int = int(siege_counts.get("rams", 0))
		if rams > 0:
			assault_multiplier += float(rams) * 0.2
		defense_bonus = _battle_manager.get_effective_defense_for_region(target_region)
		withdraw_threshold = 1.0
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
	if target_owner == observer_id or target_owner == -1:
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
		battle_log_lines = _build_battle_pre_log_lines(army, defender_entries)
	
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
	for defender in defending_armies:
		if defender == null:
			continue
		if exclude_army != null and defender == exclude_army:
			continue
		if exclude_player_id != -1 and defender.get_player_id() == exclude_player_id:
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
	_process_player_turn_start(current_player)
	
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
		next_turn()  # Advance to next player after turn completes
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

func _on_game_menu_exit_pressed() -> void:
	"""Handle Exit Game button from game menu"""
	DebugLogger.log("UISystem", "Exiting game")
	get_tree().quit()
