extends Node
class_name GameManager

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
var _ui_manager: UIManager
var _ai_camera_director: AICameraDirector
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

# Debug: disable AI battle modal and run instant background battles
var debug_disable_battle_modal: bool = true
var debug_heatmap: bool = false
var _next_player_modal: NextPlayerModal
var _sound_manager: SoundManager
# Map editor mode state
var enable_map_editor: bool = false  # Configurable flag to enable map editor mode


# References to other managers
var click_manager: Node = null

const FAMINE_MIN_POPULATION: int = 30
const FAMINE_POP_PER_FOOD: float = 0.1

var _player_initial_turn_completed: Dictionary = {}

# Scenario mode
var game_mode: String = "scenario"  # "custom" | "scenario"
var scenario_path: String = "mission1.json"
# var scenario_path: String = "battle_test.json"
var loaded_scenario_name: String = ""  # Track the loaded scenario name for the editor
var _ai_log_manager: AILogManager = AILogManager.new()
var _ai_log_started: bool = false
var _ai_battle_log_queue: Dictionary = {}

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
	_next_player_modal = ui_node.get_node("NextPlayerModal") as NextPlayerModal
	_ui_manager = ui_node.get_node("UIManager") as UIManager
	
	# Connect UI components to ArmyManager
	var army_modal = ui_node.get_node("InfoModal") as InfoModal
	var move_modal = ui_node.get_node("MoveModal") as MoveModal
	if _army_manager:
		_army_manager.set_army_modal(army_modal)
		_army_manager.set_battle_modal(_battle_modal)
		_army_manager.set_move_modal(move_modal)
	
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
		player_manager._initialize_players()
		
		# Connect to player change signal to refresh UI
		player_manager.current_player_changed.connect(_on_current_player_changed)
	else:
		push_error("[GameManager] CRITICAL: Failed to cast PlayerManager node to PlayerManagerNode! Node type: " + str(type_string(typeof(player_manager_node))))
		return
	
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
	_ai_camera_director = AICameraDirector.new()
	_ai_camera_director.name = "AICameraDirector"
	add_child(_ai_camera_director)
	var camera_controller: CameraController = get_node("../Camera2D")
	_ai_camera_director.initialize(camera_controller)
	
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
	
	# Initialize castle placement with proper player type handling
	# Always compute strategic points heatmap scores before castle placement
	if debug_heatmap:
		# Create and show heatmap; block normal game flow (no castle placement/turns)
		var heat := StrategicPointsHeatmap.new()
		heat.name = "StrategicPointsHeatmap"
		add_child(heat)
		heat.initialize(_region_manager, map_generator)
		heat.enable_key_toggle = true
		heat.compute_and_show()
		DebugLogger.log("GameInit", "Debug heatmap enabled: displaying strategic points heatmap. Castle placement and turns are disabled.")
	else:
		# Scenario mode: apply scenario and start game immediately
		if is_scenario and scenario_path != "":
			_start_scenario()
			return
		# In map editor mode, skip heatmap/castle placement/turn flow entirely
		if enable_map_editor:
			DebugLogger.log("GameInit", "Map editor enabled: skipping heatmap and castle placement initialization")
			return
		var heat_calc := StrategicPointsHeatmap.new()
		heat_calc.initialize(_region_manager, map_generator)
		heat_calc.enable_key_toggle = false
		heat_calc.compute_and_store()
		_initialize_castle_placement_sequence()

func _start_scenario() -> void:
	"""Apply scenario to runtime and start gameplay (no castle placement)."""
	DebugLogger.log("GameInit", "Starting scenario mode from: " + scenario_path)
	var map_generator: MapGenerator = get_node("../Map") as MapGenerator
	var scen_mgr := ScenarioManager.new()
	var scen := scen_mgr.load_scenario(scenario_path)
	# Apply to runtime
	scen_mgr.apply_to_runtime(map_generator, _region_manager, _army_manager, _visual_manager, scen, player_manager)
	# Set game state for immediate play
	castle_placing_mode = false
	current_player = 1
	player_manager.set_current_player(current_player)
	# Allow a frame for UI to be ready, then show status modals
	await get_tree().process_frame
	var ui_node = get_node("../UI")
	var player_status_modal2 = ui_node.get_node("PlayerStatusModal2") as PlayerStatusModal2
	var turn_modal = ui_node.get_node("TurnModal") as TurnModal
	player_status_modal2.show_and_update()
	turn_modal.show_and_update()
	# Start first turn immediately
	_start_first_turn()

func _unhandled_input(event: InputEvent) -> void:
	# Handle keyboard shortcuts
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER:
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
			# Expect bare filename; normalize if path included
			map_generator.data_file_path = String(payload.get("map_file")).get_file()
			_map_set_size_from_string(map_generator, String(payload.get("map_size", "small")))
			map_generator.generate_map()
		elif kind == "scenario":
			var scen_path := String(payload.get("scenario_path"))
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
	
	# Process castle construction for all regions
	DebugLogger.log("TurnProcessing", "Processing castle construction...")
	if _region_manager:
		_region_manager.process_all_castle_construction()
	
	# Reset ore search turn usage for all regions
	DebugLogger.log("TurnProcessing", "Resetting ore search turn usage...")
	if _region_manager:
		_region_manager.reset_all_ore_search_turn_usage()
	
	# Reset movement points for all armies
	reset_movement_points()

func _process_player_turn_start(player_id: int):
	"""Process actions that happen at the start of each player's turn"""
	DebugLogger.log("TurnProcessing", "Processing turn start for Player " + str(player_id) + "...")
	if player_manager:
		player_manager.decay_enemy_memory_for_player(player_id)
	if _region_manager:
		_region_manager.heal_wounded_for_player(player_id)
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
		if actual_loss <= 0 and pop_loss_target > 0 and region.last_population_growth >= 0:
			region.last_population_growth = -pop_loss_target
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
	
	var ui_node = get_node("../UI")
	var player_status_modal2 = ui_node.get_node("PlayerStatusModal2") as PlayerStatusModal2
	var turn_modal = ui_node.get_node("TurnModal") as TurnModal
	
	DebugLogger.log("TurnProcessing", "Calling resource and turn modal updates")
	if player_status_modal2:
		player_status_modal2.refresh_from_game_state()
	if turn_modal:
		turn_modal.refresh_from_game_state()

func _on_current_player_changed(player_id: int) -> void:
	"""Handle player change signal by refreshing UI and showing next player modal"""
	DebugLogger.log("TurnProcessing", "Player changed to " + str(player_id) + " - refreshing UI and showing next player modal")
	
	# Update player status display
	_update_player_status_display()
	
	# Center camera on player's first army or castle (only for human players),
	# but never recenter while a battle is active
	if is_player_human(player_id) and not castle_placing_mode and _active_battles == 0:
		_center_camera_on_player_assets(player_id)
	
	# Show next player modal only for active players
	if _next_player_modal and is_player_active(player_id):
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

func set_player_type(player_id: int, type: PlayerTypeEnum.Type) -> void:
	"""Set the type of a specific player"""
	if player_id >= 1 and player_id <= player_types.size():
		player_types[player_id - 1] = type  # Convert 1-based to 0-based index
		DebugLogger.log("GameInit", "Player " + str(player_id) + " set to " + PlayerTypeEnum.type_to_string(type))

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
		
		# Switch AI debug visualizer to army target mode
		if _ai_debug_visualizer:
			_ai_debug_visualizer.switch_to_army_target_mode()
		DebugLogger.log("GameInit", "Switched AI debug visualizer to army target scoring mode")
		
		# Set current player to Player 1 to start normal gameplay
		current_player = 1
		player_manager.set_current_player(current_player)
		
		# Start the first turn of normal gameplay
		DebugLogger.log("GameInit", "Starting first turn of normal gameplay...")
		await get_tree().create_timer(0.5).timeout  # Brief delay for UI updates
		_start_first_turn()
	else:
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
	
	# Show player status modals with current state
	var ui_node = get_node("../UI")
	var player_status_modal2 = ui_node.get_node("PlayerStatusModal2") as PlayerStatusModal2
	var turn_modal = ui_node.get_node("TurnModal") as TurnModal
	if player_status_modal2:
		player_status_modal2.show_and_update()
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
	
	# Play sound
	if _sound_manager:
		_sound_manager.click_sound()

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
	if region_owner == -1 and target_region.has_garrison():
		return true
	
	return false

func perform_region_entry(army: Army, target_region_id: int, source: String) -> String:
	"""
	Shared orchestration function for Human and AI region entry flow.
	Returns: "blocked" | "moved" | "battle_started"
	"""
	DebugLogger.log("TurnProcessing", "perform_region_entry: " + army.name + " -> region " + str(target_region_id) + " (source: " + source + ")")
	
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
			# For Human: call existing battle UI path (pending conquest + modal)
			var battle_manager = get_battle_manager()
			if battle_manager:
				battle_manager.set_pending_conquest(army, target_region)
				
				# Show battle modal for human interaction
				var ui_node = get_node("../UI")
				var battle_modal = ui_node.get_node("BattleModal") as BattleModal
				battle_modal.show_battle(army, target_region)
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
	DebugLogger.log("TurnProcessing", "Starting unified battle for " + army.name + " vs region " + str(target_region_id))

	# Start the battle using BattleManager (will bypass modal if debug_disable_battle_modal && AI)
	_battle_manager.start_battle(army, target_region_id)

	# If background mode is enabled for AI AND defender is not human,
	# the result is ready immediately and signal will be emitted deferred
	var defender_owner_id := _region_manager.get_region_owner(target_region_id)
	var defender_is_human := (defender_owner_id != -1 and is_player_human(defender_owner_id))
	if debug_disable_battle_modal and is_player_computer(army.get_player_id()) and not defender_is_human:
		var report = _battle_manager.get_last_battle_report()
		var res = "victory" if report and report.winner == "Attackers" else "defeat"
		return res

	# Otherwise wait for the modal-driven signal
	var result: String = await _battle_manager.battle_finished
	DebugLogger.log("TurnProcessing", "Battle completed with result: " + result)
	
	# For AI battles (modal path), finalize immediately using last battle report after signal
	if is_player_computer(army.get_player_id()) and not debug_disable_battle_modal:
		var result_data = {
			"result": result,
			"army": army,
			"target_region_id": target_region_id,
			"battle_report": _battle_manager.get_last_battle_report(),
			"attacking_armies": _battle_manager._pending_attackers,
			"defending_armies": _battle_manager._pending_defenders,
			"defending_garrison": _battle_manager._pending_garrison,
			"defending_recruits_region": _battle_manager._pending_recruits_region,
			"defending_recruits_count": _battle_manager._pending_recruits_count
		}
		finalize_battle_result(result_data)
	
	return result

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
	var battle_report = result_data.get("battle_report")
	var attacking_armies: Array = result_data.get("attacking_armies", [])
	var defending_armies: Array = result_data.get("defending_armies", [])
	var defending_garrison = result_data.get("defending_garrison")
	var defending_recruits_region: Region = result_data.get("defending_recruits_region")
	var defending_recruits_count: int = result_data.get("defending_recruits_count", 0)
	
	var army_name = "unknown army"
	if army != null:
		army_name = army.name
	DebugLogger.log("TurnProcessing", "Finalizing battle result: " + result + " for " + army_name)
	var should_queue_battle_log := army != null and is_player_computer(army.get_player_id()) and battle_report != null
	var battle_log_lines: Array[String] = []
	var defender_entries: Array = []
	if should_queue_battle_log:
		defender_entries = _collect_defender_log_entries(defending_armies, defending_garrison)
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
			var post_lines := _build_battle_post_log_lines(army, defender_entries, result)
			var combined := battle_log_lines.duplicate()
			combined.append_array(post_lines)
			combined.append("")
			_enqueue_ai_battle_log(army, combined)
	
	# Handle battle outcome
	if result == "victory":
		# Attackers won - handle conquest
		if army and is_instance_valid(army) and target_region_id != -1:
			var player_id = army.get_player_id()
			_region_manager.set_region_ownership(target_region_id, player_id)
			var conquered_region = _region_manager.map_generator.get_region_container_by_id(target_region_id) as Region
			if conquered_region != null:
				conquered_region.kill_wounded_garrison()
			refresh_ai_debug_scores()
			DebugLogger.log("TurnProcessing", "Player " + str(player_id) + " conquered region " + str(target_region_id) + " via unified finalization")
			
			if is_player_computer(player_id) and _ai_camera_director:
				var conquest_delay = max(GameParameters.CAMERA_CONQUEST_DELAY, GameParameters.CAMERA_BATTLE_RESULT_DELAY)
				await _ai_camera_director.await_delay(conquest_delay)
			
			# Reduce efficiency for conquest
			army.reduce_efficiency(5)
			DebugLogger.log("TurnProcessing", "Reduced " + army.name + " efficiency to " + str(army.get_efficiency()) + "% after conquest")
	elif result == "withdrawal":
		# Army withdrew - handle retreat and efficiency reduction
		if army and is_instance_valid(army) and _battle_manager:
			var is_ai_withdraw := is_player_computer(army.get_player_id())
			var focused_before_retreat := false
			if is_ai_withdraw and _ai_camera_director and _army_manager:
				var retreat_region := _army_manager.get_previous_region_for_army(army)
				if retreat_region != null:
					await _ai_camera_director.await_focus_on_region(retreat_region)
					focused_before_retreat = true
			await _battle_manager._handle_army_withdrawal(army)
			if is_ai_withdraw and _ai_camera_director:
				if not focused_before_retreat:
					await _ai_camera_director.await_focus_on_army(army)
				await _ai_camera_director.await_delay(GameParameters.CAMERA_BATTLE_RESULT_DELAY)
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

# Manager accessors for external systems
func get_battle_manager() -> BattleManager:
	"""Get the BattleManager instance"""
	return _battle_manager

func get_visual_manager() -> VisualManager:
	"""Get the VisualManager instance"""
	return _visual_manager

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

func ai_travel_to(army: Army, final_region_id: int) -> String:
	"""
	AI travel wrapper for step-by-step movement with debug pausing.
	Gets the path using existing pathfinder, then iterates adjacent steps.
	For contested steps: use perform_region_entry(army, next_id, "ai")
	For friendly steps: use ArmyManager.move_army(army, next_region)
	Returns: "arrived", "blocked", "battle_victory", "battle_defeat", "battle_withdrawal"
	"""
	if army == null or not is_instance_valid(army):
		DebugLogger.log("AIPathfinding", "ai_travel_to: Invalid army")
		return "blocked"
	
	var current_region = army.get_parent() as Region
	if current_region == null:
		DebugLogger.log("AIPathfinding", "ai_travel_to: Army not in valid region")
		return "blocked"
	
	await _ai_camera_director.await_focus_on_army(army)
	await _ai_camera_director.await_delay(GameParameters.CAMERA_ARMY_START_DELAY)
	
	var current_region_id = current_region.get_region_id()
	var player_id = army.get_player_id()
	
	DebugLogger.log("AIPathfinding", "ai_travel_to: Army %s traveling from region %d to region %d" % [army.name, current_region_id, final_region_id])
	
	var pathfinder = _turn_controller.pathfinder
	
	# Get path using existing pathfinder with same filters (friendly-only, passable)
	var path_result = pathfinder.find_path_to_target(current_region_id, final_region_id, player_id)
	if not path_result["success"]:
		DebugLogger.log("AIPathfinding", "ai_travel_to: No valid path found")
		return "blocked"
	
	var full_path = path_result["path"] as Array[int]
	if full_path.size() <= 1:
		DebugLogger.log("AIPathfinding", "ai_travel_to: Already at destination or invalid path")
		return "arrived"
	
	DebugLogger.log("AIPathfinding", "ai_travel_to: Path found with %d steps" % full_path.size())
	
	# Iterate adjacent steps starting from index 1 (skip current position)
	var last_battle_outcome := ""
	for i in range(1, full_path.size()):
		var next_region_id = full_path[i]
		
		# Check if army still has movement points
		if army.get_movement_points() <= 0:
			DebugLogger.log("AIMovement", "ai_travel_to: Army %s out of movement points, stopping at region %d" % [army.name, army.get_parent().get_region_id()])
			return "out_of_movement_points"
		
		# Get next region for battle check
		var next_region_container = _region_manager.map_generator.get_region_container_by_id(next_region_id)
		if next_region_container == null:
			DebugLogger.log("AIMovement", "ai_travel_to: Invalid region %d in path" % next_region_id)
			return "blocked"
		
		var next_region = next_region_container as Region
		if next_region == null:
			DebugLogger.log("AIMovement", "ai_travel_to: Region %d is not valid" % next_region_id)
			return "blocked"
		# Debug step pausing using DebugStepGate
		if _turn_controller.debug_step_gate:
			DebugLogger.log("AIMovement", "ai_travel_to: Debug step - Army %s moving to region %d (step %d/%d)" % [army.name, next_region_id, i, full_path.size()-1])
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
					continue
				"battle_withdrawal":
					DebugLogger.log("AIMovement", "ai_travel_to: Army withdrew from battle")
					await _ai_camera_director.await_delay(GameParameters.CAMERA_BATTLE_RESULT_DELAY)
					return "battle_withdrawal"
				"battle_defeat":
					DebugLogger.log("AIMovement", "ai_travel_to: Army defeated in battle")
					await _ai_camera_director.await_delay(GameParameters.CAMERA_BATTLE_RESULT_DELAY)
					return "battle_defeat"
				"blocked":
					DebugLogger.log("AIMovement", "ai_travel_to: Movement blocked")
					await _ai_camera_director.await_delay(GameParameters.CAMERA_BATTLE_RESULT_DELAY)
					return "blocked"
				_:
					DebugLogger.log("AIMovement", "ai_travel_to: Unexpected battle result: %s" % battle_result)
					await _ai_camera_director.await_delay(GameParameters.CAMERA_BATTLE_RESULT_DELAY)
					return "blocked"
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
				return "blocked"
	
	# Check if we reached the final destination
	var final_position = army.get_parent() as Region
	if final_position and final_position.get_region_id() == final_region_id:
		DebugLogger.log("AIMovement", "ai_travel_to: Army %s successfully arrived at region %d" % [army.name, final_region_id])
		if last_battle_outcome != "":
			return last_battle_outcome
		return "arrived"
	else:
		var current_pos = final_position.get_region_id() if final_position else -1
		DebugLogger.log("AIMovement", "ai_travel_to: Army %s stopped at region %d (target was %d)" % [army.name, current_pos, final_region_id])
		return "blocked"

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

func _collect_defender_log_entries(defending_armies: Array, defending_garrison: ArmyComposition) -> Array:
	var entries: Array = []
	for defender in defending_armies:
		if defender == null:
			continue
		entries.append({
			"type": "army",
			"ref": defender,
			"name": defender.name
		})
	if defending_garrison != null:
		entries.append({
			"type": "garrison",
			"ref": defending_garrison,
			"name": "Garrison"
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

func _build_battle_post_log_lines(attacker: Army, defender_entries: Array, result: String) -> Array[String]:
	var lines: Array[String] = []
	lines.append("Battle Result: %s" % _format_battle_result_label(result))
	lines.append(_format_attacker_after_line("Attacker After", attacker, attacker.name if attacker else "Unknown Army"))
	if defender_entries.is_empty():
		lines.append("Defender After: None")
	else:
		for entry in defender_entries:
			lines.append(_format_defender_after_line(entry))
	return lines

func _format_attacker_line(prefix: String, army: Army, fallback_name: String) -> String:
	if army != null and is_instance_valid(army):
		return "%s: %s [Power: %d - %s]" % [prefix, army.name, army.get_army_power(), _format_composition_suffix(army.get_composition())]
	return "%s: %s [Power: 0 - none]" % [prefix, fallback_name]

func _format_attacker_after_line(prefix: String, army: Army, fallback_name: String) -> String:
	if army != null and is_instance_valid(army):
		return "%s: %s [Power: %d - %s]" % [prefix, army.name, army.get_army_power(), _format_composition_suffix(army.get_composition())]
	return "%s: %s destroyed" % [prefix, fallback_name]

func _format_defender_pre_line(entry: Dictionary) -> String:
	if entry.get("type", "") == "garrison":
		var garrison_comp: ArmyComposition = entry.get("ref")
		return "Defender Garrison [Power: %d - %s]" % [
			_calculate_composition_power(garrison_comp),
			_format_composition_suffix(garrison_comp)
		]
	var defender: Army = entry.get("ref")
	var label := "Defender %s" % entry.get("name", "Army")
	if defender != null and is_instance_valid(defender):
		return "%s [Power: %d - %s]" % [label, defender.get_army_power(), _format_composition_suffix(defender.get_composition())]
	return "%s [Power: 0 - none]" % label

func _format_defender_after_line(entry: Dictionary) -> String:
	if entry.get("type", "") == "garrison":
		var garrison_comp: ArmyComposition = entry.get("ref")
		return "Defender After (Garrison): %s [Power: %d - %s]" % [
			entry.get("name", "Garrison"),
			_calculate_composition_power(garrison_comp),
			_format_composition_suffix(garrison_comp)
		]
	var defender: Army = entry.get("ref")
	var label := "Defender After: %s" % entry.get("name", "Army")
	if defender != null and is_instance_valid(defender):
		return "%s [Power: %d - %s]" % [label, defender.get_army_power(), _format_composition_suffix(defender.get_composition())]
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
	
	# Process player-specific turn start actions
	_process_player_turn_start(current_player)
	
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
			DebugLogger.log("TurnProcessing", "Centered camera on Player " + str(player_id) + "'s first army: " + first_army.name)
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
