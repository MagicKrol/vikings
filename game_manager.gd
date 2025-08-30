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
	PlayerTypeEnum.Type.OFF,   # Player 3 - Computer
	PlayerTypeEnum.Type.OFF,   # Player 4 - Computer
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
var _battle_manager: BattleManager
var _visual_manager: VisualManager
var _ui_manager: UIManager

# AI system references
var _ai_region_scorer: RegionScorer
var _ai_castle_placement_scorer: CastlePlacementScorer
var _ai_debug_visualizer: AIDebugVisualizer

# New unified turn system
var _turn_controller: TurnController

# AI debugging state is now handled by TurnController

# Modal references  
var _battle_modal: BattleModal
var _next_player_modal: NextPlayerModal
var _sound_manager: SoundManager

# References to other managers
var click_manager: Node = null

func _ready():
	# Initialize all game systems
	initialize_managers()
	
	# Start the game audio sequence after a brief delay to ensure sound manager is ready
	await get_tree().process_frame
	if _sound_manager:
		print("[GameManager] Starting game audio sequence...")
		_sound_manager.play_game_start_sequence()
	else:
		print("[GameManager] Error: Sound manager not found!")

func initialize_managers():
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
	if _army_manager:
		_army_manager.set_army_modal(army_modal)
		_army_manager.set_battle_modal(_battle_modal)
	
	_sound_manager = get_node("../SoundManager") as SoundManager
	
	# Connect sound manager to ArmyManager
	if _army_manager:
		_army_manager.set_sound_manager(_sound_manager)
	
	# Initialize specialized managers
	_battle_manager = BattleManager.new(_region_manager, _army_manager, _battle_modal, _sound_manager)
	_battle_manager.set_game_manager(self)
	_visual_manager = VisualManager.new(map_generator, _region_manager, _army_manager)
	
	# Get the PlayerManager node FIRST before initializing other systems that depend on it
	print("[GameManager] Looking for PlayerManager node at path: ../PlayerManager")
	var player_manager_node = get_node("../PlayerManager")
	print("[GameManager] Found node: ", player_manager_node, " (", type_string(typeof(player_manager_node)), ")")
	
	player_manager = player_manager_node as PlayerManagerNode
	if player_manager:
		print("[GameManager] Successfully cast to PlayerManagerNode: ", player_manager)
		player_manager.initialize_with_managers(_region_manager, map_generator)
		player_manager.set_army_manager(_army_manager)
		
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
	
	# Add AI debug visualizer to the scene tree
	var map_node = get_node("../Map")
	map_node.add_child(_ai_debug_visualizer)
	
	# Enable debug mode and step-by-step mode by default
	_ai_debug_visualizer.enable_step_by_step_mode(true)
	print("[GameManager] AI system initialized with debug and step-by-step mode enabled")
	
	# Print initial player resources and types
	print("[GameManager] Game initialized with ", total_players, " players")
	print("[GameManager] Player types:")
	for i in range(1, total_players + 1):
		print("  Player ", i, ": ", PlayerTypeEnum.type_to_string(get_player_type(i)))
	player_manager.print_all_resources()
	
	# Initialize castle placement with proper player type handling
	_initialize_castle_placement_sequence()

func _unhandled_input(event: InputEvent) -> void:
	# Handle keyboard shortcuts
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER:
			next_turn()
		elif event.keycode == KEY_0:
			# Toggle AI debug visualization
			if _ai_debug_visualizer:
				_ai_debug_visualizer.toggle_debug_display(current_player)
				print("[GameManager] AI debug toggle for Player ", current_player)
		elif event.keycode == KEY_9:
			# Toggle step-by-step AI debug mode (only during actual turns, not castle placement)
			if _ai_debug_visualizer and not castle_placing_mode:
				var current_mode = _ai_debug_visualizer.is_step_by_step_mode()
				_ai_debug_visualizer.enable_step_by_step_mode(not current_mode)
				print("[GameManager] Step-by-step AI debug mode: ", "enabled" if not current_mode else "disabled")
			elif castle_placing_mode:
				print("[GameManager] Step-by-step mode not available during castle placement")
		# SPACE key handling is now managed by TurnController's DebugStepGate

func next_turn():
	"""Advance to the next player's turn and perform turn-based actions"""
	
	# Get next active player in sequence (skips OFF players)
	var next_player_id = _get_next_active_player()
	var is_new_round = (next_player_id == players_per_round[0])
	
	if is_new_round:
		# Starting a new round - increment turn counter
		current_turn += 1
		print("[GameManager] === Starting Round ", current_turn, " ===")
		
		# Process global turn-based actions only at start of new round
		_process_round_start_actions()
	
	# Set current player
	current_player = next_player_id
	player_manager.set_current_player(current_player)
	
	# Process player-specific turn start actions (only for active players)
	if is_player_active(current_player):
		_process_player_turn_start(current_player)
	
	# Check if current player is AI and handle AI turn processing
	print("[GameManager] Checking AI turn: castle_placing_mode=", castle_placing_mode, ", current_player=", current_player, ", is_computer=", is_player_computer(current_player))
	if not castle_placing_mode and is_player_computer(current_player):
		print("[GameManager] AI Player ", current_player, " starting turn processing with TurnController...")
		await _turn_controller.start_turn(current_player)
		next_turn()  # Advance to next player after turn completes
		return  # Exit early since AI turn handling includes next_turn() call
	else:
		print("[GameManager] Skipping AI turn processing")
	
	# Note: next player modal and player status display are now handled by _on_current_player_changed signal handler

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
	print("[GameManager] Castle placement starting with Player ", current_player, " (", PlayerTypeEnum.type_to_string(get_player_type(current_player)), ")")
	
	# If the first player is AI, trigger AI placement immediately
	if is_player_computer(current_player):
		print("[GameManager] First player is AI - starting automatic placement...")
		# Use a small delay to ensure all systems are ready
		await get_tree().create_timer(1.0).timeout
		_handle_ai_castle_placement(current_player)

func _process_round_start_actions():
	"""Process actions that happen once per round (when Player 1 starts)"""
	print("[GameManager] Processing round start actions...")
	
	# Increment ownership counters for all owned regions
	print("[GameManager] Incrementing ownership counters...")
	if _region_manager:
		_region_manager.increment_all_ownership_counters()
	
	# Grow population for all regions (before recruit replenishment)
	print("[GameManager] Growing regional populations...")
	if _region_manager:
		_region_manager.grow_all_populations()
	
	# Replenish recruits for all regions (after population growth)
	print("[GameManager] Replenishing recruits...")
	if _region_manager:
		_region_manager.replenish_all_recruits()
	
	# Process castle construction for all regions
	print("[GameManager] Processing castle construction...")
	if _region_manager:
		_region_manager.process_all_castle_construction()
	
	# Reset ore search turn usage for all regions
	print("[GameManager] Resetting ore search turn usage...")
	if _region_manager:
		_region_manager.reset_all_ore_search_turn_usage()
	
	# Reset movement points for all armies
	reset_movement_points()

func _process_player_turn_start(player_id: int):
	"""Process actions that happen at the start of each player's turn"""
	print("[GameManager] Processing turn start for Player ", player_id, "...")
	
	# Process resource income for current player
	print("[GameManager] Processing resource income for Player ", player_id, "...")
	player_manager.process_resource_income_for_player(player_id)
	
	# Deduct food costs for current player's armies and garrisons
	print("[GameManager] Deducting army food costs for Player ", player_id, "...")
	_process_army_food_costs_for_player(player_id)
	


func reset_movement_points():
	"""Reset movement points for all armies on the map"""

	if click_manager != null:
		var army_manager = click_manager.get_army_manager()
		if army_manager != null:

			army_manager.reset_all_army_movement_points()
		else:
			print("[GameManager] Warning: Cannot reset army moves - ArmyManager not found")
	else:
		print("[GameManager] Warning: Cannot reset army moves - ClickManager not found")

func _process_army_food_costs_for_player(player_id: int) -> void:
	"""Process food costs for armies and garrisons for a specific player"""
	var player = player_manager.get_player(player_id)
	if player == null:
		print("[GameManager] Warning: Player ", player_id, " not found for food cost processing")
		return
	
	# Calculate total food cost for all armies and garrisons
	var total_food_cost = player_manager.calculate_total_army_food_cost(player_id)
	
	if total_food_cost > 0:
		# Convert float cost to integer (round up)
		var food_cost_int = int(ceil(total_food_cost))
		
		print("[GameManager] Total army food cost for Player ", player_id, ": ", total_food_cost, " (rounded: ", food_cost_int, ")")
		
		# Check if player has enough food
		var current_food = player.get_resource_amount(ResourcesEnum.Type.FOOD)
		if current_food >= food_cost_int:
			# Deduct the food cost
			player.remove_resources(ResourcesEnum.Type.FOOD, food_cost_int)
			print("[GameManager] Deducted ", food_cost_int, " food from Player ", player_id, " (", current_food - food_cost_int, " remaining)")
		else:
			# Player doesn't have enough food - this could lead to penalties
			print("[GameManager] WARNING: Player ", player_id, " doesn't have enough food! Required: ", food_cost_int, ", Available: ", current_food)
			# For now, just deduct all available food
			if current_food > 0:
				player.remove_resources(ResourcesEnum.Type.FOOD, current_food)
				print("[GameManager] Deducted all available food (", current_food, ") from Player ", player_id)
	else:
		print("[GameManager] No army food costs for Player ", player_id)

func _update_player_status_display() -> void:
	"""Update the player status display when resources or player changes"""
	print("[GameManager] Updating player status display...")
	
	var ui_node = get_node("../UI")
	var player_status_modal = ui_node.get_node("PlayerStatusModal") as PlayerStatusModal
	
	print("[GameManager] Calling PlayerStatusModal.refresh_from_game_state()")
	player_status_modal.refresh_from_game_state()

func _on_current_player_changed(player_id: int) -> void:
	"""Handle player change signal by refreshing UI and showing next player modal"""
	print("[GameManager] Player changed to ", player_id, " - refreshing UI and showing next player modal")
	
	# Update player status display
	_update_player_status_display()
	
	# Show next player modal only for active players
	if _next_player_modal and is_player_active(player_id):
		_next_player_modal.show_next_player(player_id, castle_placing_mode)
	
	print("[GameManager] Round ", current_turn, " - Player ", player_id, "'s turn")

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
		print("[GameManager] Player ", player_id, " set to ", PlayerTypeEnum.type_to_string(type))

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
		print("[GameManager] Error: AI castle placement scorer not available")
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
		print("[GameManager] No valid castle placement candidates for AI Player ", player_id)
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
	
	print("[GameManager] AI Player ", player_id, " selecting region ", best_region_id, " with final score ", snappedf(best_score * 100, 0.1), " (includes random modifier)")
	
	# Find the region and place castle
	if regions_node:
		for child in regions_node.get_children():
			if child is Region and child.get_region_id() == best_region_id:
				handle_castle_placement(child)
				break

# Player resource management
func get_player_manager() -> PlayerManagerNode:
	"""Get the player manager instance"""
	return player_manager

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

func get_current_player_id() -> int:
	"""Get the current active player ID"""
	return current_player

func set_armies_per_castle(count: int):
	"""Set the number of armies to create per castle (for scenario/difficulty configuration)"""
	armies_per_castle = max(1, count)  # Ensure at least 1 army
	print("[GameManager] Set armies per castle to ", armies_per_castle)

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
		print("[GameManager] Castle placement failed - region already owned by another player")
		return
		
	var region_id = region.get_region_id()
	
	# Set castle starting position (this will also claim neighboring regions)
	var placement_successful = false
	if _region_manager:
		placement_successful = _region_manager.set_castle_starting_position(region_id, current_player)
	
	if not placement_successful:
		print("[GameManager] Castle placement failed - unexpected error")
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
				child.set_castle_type(CastleTypeEnum.Type.OUTPOST)
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
				print("[GameManager] Placed ", armies_per_castle, " armies for Player ", current_player, " in region ", region_id)
				break
	
	# Track castle placement order and advance to next player
	castle_placement_order.append(current_player)
	castles_placed += 1
	print("[GameManager] Player ", current_player, " placed castle (", castles_placed, "/", total_players, ")")
	
	# Check if all active players have placed castles
	var active_players_count = 0
	for i in range(1, total_players + 1):
		if is_player_active(i):
			active_players_count += 1
	
	if castles_placed >= active_players_count:
		# All active players placed castles - end castle placing mode and start normal gameplay
		castle_placing_mode = false
		print("[GameManager] All active players have placed castles. Game begins!")
		
		# Switch AI debug visualizer to army target mode
		if _ai_debug_visualizer:
			_ai_debug_visualizer.switch_to_army_target_mode()
			print("[GameManager] Switched AI debug visualizer to army target scoring mode")
		
		# Set current player to Player 1 to start normal gameplay
		current_player = 1
		player_manager.set_current_player(current_player)
		
		# Start the first turn of normal gameplay
		print("[GameManager] Starting first turn of normal gameplay...")
		await get_tree().create_timer(0.5).timeout  # Brief delay for UI updates
		_start_first_turn()
	else:
		# Move to next active player for castle placement
		current_player = _get_next_active_player()
		player_manager.set_current_player(current_player)
		print("[GameManager] Next player to place castle: Player ", current_player, " (", PlayerTypeEnum.type_to_string(get_player_type(current_player)), ")")
		
		# Handle different player types
		if is_player_human(current_player):
			# Show next player modal for human player
			if _next_player_modal:
				_next_player_modal.show_next_player(current_player, true)
		elif is_player_computer(current_player):
			# AI player - automatically place castle using AI system
			print("[GameManager] AI Player ", current_player, " placing castle automatically...")
			# Use a short delay to allow visuals to update
			await get_tree().create_timer(0.5).timeout
			_handle_ai_castle_placement(current_player)
		# OFF players are skipped by _get_next_active_player()
	
	# Show player status modal with current state
	var ui_node = get_node("../UI")
	var player_status_modal = ui_node.get_node("PlayerStatusModal") as PlayerStatusModal
	if player_status_modal:
		player_status_modal.show_and_update()
	
	# Update AI debug scores if debug mode is active (for next player's perspective)
	if _ai_debug_visualizer and _ai_debug_visualizer.is_debug_visible():
		# Get the next player who will be placing a castle
		var next_player_for_scoring = current_player
		if castles_placed < total_players:
			next_player_for_scoring = _get_next_player()
		
		print("[GameManager] Recalculating AI debug scores for Player ", next_player_for_scoring, " after castle placement")
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
	print("[GameManager] perform_region_entry: ", army.name, " -> region ", target_region_id, " (source: ", source, ")")
	
	# Resolve target region Node using RegionManager lookup
	var target_region = _region_manager.map_generator.get_region_container_by_id(target_region_id) as Region
	if target_region == null:
		print("[GameManager] Error: Target region not found")
		return "blocked"
	
	# Call ArmyManager.move_army
	var move_success = _army_manager.move_army(army, target_region)
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
				return "battle_defeat" 
			else:
				return "battle_defeat"
	
	return "moved"

# Battle coordination - unified system for both Human and AI players
func handle_army_battle(army: Army, target_region_id: int) -> String:
	"""
	Unified battle handling for both Human and AI players
	Returns: 'victory', 'defeat', or 'withdrawal'
	"""
	print("[GameManager] Starting unified battle for ", army.name, " vs region ", target_region_id)
	
	# Start the battle using BattleManager
	_battle_manager.start_battle(army, target_region_id)
	
	# Wait for battle to complete
	var result: String = await _battle_manager.battle_finished
	print("[GameManager] Battle completed with result: ", result)
	
	# For AI battles, finalize immediately since there's no modal interaction
	if is_player_computer(army.get_player_id()):
		var result_data = {
			"result": result,
			"army": army,
			"target_region_id": target_region_id,
			"battle_report": _battle_manager._battle_modal.battle_report if _battle_manager._battle_modal else null,
			"attacking_armies": _battle_manager._pending_attackers if _battle_manager else [],
			"defending_armies": _battle_manager._pending_defenders if _battle_manager else [],
			"defending_garrison": _battle_manager._pending_garrison if _battle_manager else null
		}
		finalize_battle_result(result_data)
	
	return result

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
	
	var army_name = "unknown army"
	if army != null:
		army_name = army.name
	print("[GameManager] Finalizing battle result: ", result, " for ", army_name)
	
	# Apply battle losses using existing BattleManager logic
	if battle_report and _battle_manager:
		_battle_manager._apply_losses_proportionally(battle_report.attacker_losses, attacking_armies, null)
		_battle_manager._apply_losses_proportionally(battle_report.defender_losses, defending_armies, defending_garrison)
		
		# Cleanup destroyed armies
		if _army_manager:
			_army_manager.remove_destroyed_armies()
	
	# Handle battle outcome
	if result == "victory":
		# Attackers won - handle conquest
		if army and is_instance_valid(army) and target_region_id != -1:
			var player_id = army.get_player_id()
			_region_manager.set_region_ownership(target_region_id, player_id)
			refresh_ai_debug_scores()
			print("[GameManager] Player ", player_id, " conquered region ", target_region_id, " via unified finalization")
			
			# Reduce efficiency for conquest
			army.reduce_efficiency(5)
			print("[GameManager] Reduced ", army.name, " efficiency to ", army.get_efficiency(), "% after conquest")
	elif result == "withdrawal":
		# Army withdrew - handle retreat and efficiency reduction
		if army and is_instance_valid(army) and _battle_manager:
			_battle_manager._handle_army_withdrawal(army)
	else:
		# Attackers lost - remove the army
		if army and is_instance_valid(army) and _battle_manager:
			_battle_manager._handle_battle_defeat(army)

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
		print("[GameManager] Manually refreshing AI debug scores for Player ", current_player)
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
	Returns: "arrived", "blocked", "battle_victory", "battle_defeat"
	"""
	if army == null or not is_instance_valid(army):
		print("[GameManager] ai_travel_to: Invalid army")
		return "blocked"
	
	var current_region = army.get_parent() as Region
	if current_region == null:
		print("[GameManager] ai_travel_to: Army not in valid region")
		return "blocked"
	
	var current_region_id = current_region.get_region_id()
	var player_id = army.get_player_id()
	
	print("[GameManager] ai_travel_to: Army %s traveling from region %d to region %d" % [army.name, current_region_id, final_region_id])
	
	# Get pathfinder from TurnController (reuse existing scorer pathfinder)
	if _turn_controller == null:
		print("[GameManager] ai_travel_to: TurnController not available")
		return "blocked"
	
	var pathfinder = _turn_controller.pathfinder
	if pathfinder == null:
		print("[GameManager] ai_travel_to: Pathfinder not available") 
		return "blocked"
	
	# Get path using existing pathfinder with same filters (friendly-only, passable)
	var path_result = pathfinder.find_path_to_target(current_region_id, final_region_id, player_id)
	if not path_result["success"]:
		print("[GameManager] ai_travel_to: No valid path found")
		return "blocked"
	
	var full_path = path_result["path"] as Array[int]
	if full_path.size() <= 1:
		print("[GameManager] ai_travel_to: Already at destination or invalid path")
		return "arrived"
	
	print("[GameManager] ai_travel_to: Path found with %d steps" % full_path.size())
	
	# Iterate adjacent steps starting from index 1 (skip current position)
	for i in range(1, full_path.size()):
		var next_region_id = full_path[i]
		
		# Check if army still has movement points
		if army.get_movement_points() <= 0:
			print("[GameManager] ai_travel_to: Army %s out of movement points, stopping at region %d" % [army.name, army.get_parent().get_region_id()])
			return "blocked"
		
		# Get next region for battle check
		var next_region_container = _region_manager.map_generator.get_region_container_by_id(next_region_id)
		if next_region_container == null:
			print("[GameManager] ai_travel_to: Invalid region %d in path" % next_region_id)
			return "blocked"
		
		var next_region = next_region_container as Region
		if next_region == null:
			print("[GameManager] ai_travel_to: Region %d is not valid" % next_region_id)
			return "blocked"
		
		# Debug step pausing using DebugStepGate
		if _turn_controller.debug_step_gate:
			print("[GameManager] ai_travel_to: Debug step - Army %s moving to region %d (step %d/%d)" % [army.name, next_region_id, i, full_path.size()-1])
			await _turn_controller.debug_step_gate.step()
		
		# Check if this step should trigger battle
		if _should_trigger_battle(army, next_region):
			print("[GameManager] ai_travel_to: Contested step - using perform_region_entry")
			var battle_result = await perform_region_entry(army, next_region_id, "ai")
			
			# Log step result
			print("[GameManager] ai_travel_to: Battle result for step %d: %s" % [i, battle_result])
			
			match battle_result:
				"battle_victory":
					# Continue to next step after victory
					continue
				"battle_defeat":
					print("[GameManager] ai_travel_to: Army defeated in battle")
					return "battle_defeat"
				"blocked":
					print("[GameManager] ai_travel_to: Movement blocked")
					return "blocked"
				_:
					print("[GameManager] ai_travel_to: Unexpected battle result: %s" % battle_result)
					return "blocked"
		else:
			# Friendly step - use ArmyManager.move_army()
			print("[GameManager] ai_travel_to: Friendly step - using ArmyManager.move_army")
			var move_success = _army_manager.move_army(army, next_region)
			
			# Log step result  
			if move_success:
				print("[GameManager] ai_travel_to: Friendly move successful for step %d" % i)
			else:
				print("[GameManager] ai_travel_to: Friendly move failed for step %d" % i)
				return "blocked"
	
	# Check if we reached the final destination
	var final_position = army.get_parent() as Region
	if final_position and final_position.get_region_id() == final_region_id:
		print("[GameManager] ai_travel_to: Army %s successfully arrived at region %d" % [army.name, final_region_id])
		return "arrived"
	else:
		var current_pos = final_position.get_region_id() if final_position else -1
		print("[GameManager] ai_travel_to: Army %s stopped at region %d (target was %d)" % [army.name, current_pos, final_region_id])
		return "blocked"

func _start_first_turn() -> void:
	"""Start the first turn after castle placement completes"""
	print("[GameManager] _start_first_turn called for Player ", current_player)
	
	# Process player-specific turn start actions
	_process_player_turn_start(current_player)
	
	# Check if current player is AI and handle AI turn processing
	print("[GameManager] Checking AI turn: castle_placing_mode=", castle_placing_mode, ", current_player=", current_player, ", is_computer=", is_player_computer(current_player))
	if not castle_placing_mode and is_player_computer(current_player):
		print("[GameManager] AI Player ", current_player, " starting first turn with TurnController...")
		
		# Enable debug display for AI turns
		if _ai_debug_visualizer:
			_ai_debug_visualizer.toggle_debug_display(current_player)
			print("[GameManager] Enabled AI debug display for Player ", current_player)
		
		await _turn_controller.start_turn(current_player)
		next_turn()  # Advance to next player after turn completes
		return  # Exit early since AI turn handling includes next_turn() call
	else:
		print("[GameManager] Skipping AI turn processing")
	
	# Note: next player modal and player status display are now handled by _on_current_player_changed signal handler
