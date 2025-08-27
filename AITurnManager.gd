extends RefCounted
class_name AITurnManager

# ============================================================================
# AI TURN MANAGER
# ============================================================================
# 
# Purpose: Coordinate all AI actions during a player's turn
# 
# Core Responsibilities:
# - Aggregate AI decision making for complete turn processing
# - Coordinate army movements, region management, and strategic planning
# - Call specialized AI subsystems in logical order
# - Manage AI turn timing and flow control
# 
# Required Functions:
# - process_turn(): Main AI turn processing entry point
# - move_armies(): Handle all army movements for the player
# - manage_regions(): Process region-based actions (recruitment, building)
# - calculate_scoring(): Update strategic assessments
# 
# Integration Points:
# - RegionManager: Territory and ownership information
# - ArmyManager: Army movement and positioning
# - PlayerManager: Player resources and state
# - MapGenerator: Region data and adjacency information
# ============================================================================

# Manager references
var region_manager: RegionManager
var army_manager: ArmyManager
var player_manager: PlayerManagerNode
var map_generator: MapGenerator

# AI scoring system
var army_target_scorer: ArmyTargetScorer

# AI movement planning system
var army_movement_planner: ArmyMovementPlanner


func _init(region_mgr: RegionManager, army_mgr: ArmyManager, player_mgr: PlayerManagerNode, map_gen: MapGenerator):
	region_manager = region_mgr
	army_manager = army_mgr
	player_manager = player_mgr
	map_generator = map_gen
	
	# Initialize army target scorer
	army_target_scorer = ArmyTargetScorer.new(region_mgr, map_gen)
	
	# Initialize army movement planner
	army_movement_planner = ArmyMovementPlanner.new(region_mgr, army_mgr, army_target_scorer)
	
	DebugLogger.log("AITurnManager", "Initialized with all manager references, ArmyTargetScorer, and ArmyMovementPlanner")

func process_turn(player_id: int) -> void:
	"""Main AI turn processing - coordinates all AI actions for this turn"""
	DebugLogger.log("AITurnManager", "========== Processing turn for AI Player %d ==========" % player_id)
	
	# Phase 1: Calculate strategic scoring (placeholder for future expansion)
	_calculate_scoring(player_id)
	
	# Phase 2: Move armies (with debug support)
	await _move_armies_with_debug(player_id)
	
	# Phase 3: Manage regions (placeholder for future expansion)
	_manage_regions(player_id)
	
	DebugLogger.log("AITurnManager", "========== Completed turn processing for AI Player %d ==========" % player_id)


func _calculate_scoring(player_id: int) -> void:
	"""Calculate strategic scoring for decision making"""
	DebugLogger.log("AITurnManager", "Calculating scoring for Player %d (placeholder)" % player_id, 1)
	# TODO: Implement strategic scoring calculations
	# This will integrate with existing AI scorers for region evaluation

func _move_armies_with_debug(player_id: int) -> void:
	"""Handle all army movements for the AI player"""
	DebugLogger.log("AITurnManager", "Processing army movements for Player %d" % player_id, 1)
	
	# Reset deconfliction tracking for this turn
	army_movement_planner.reset_turn_tracking()
	DebugLogger.log("AITurnManager", "Reset deconfliction tracking for new AI turn", 1)
	
	# Get all armies for this player
	var player_armies = army_manager.get_player_armies(player_id)
	if player_armies.is_empty():
		DebugLogger.log("AITurnManager", "No armies found for Player %d" % player_id)
		return
	
	DebugLogger.log("AITurnManager", "Found %d armies for Player %d" % [player_armies.size(), player_id])
	
	# Prioritize armies for deconfliction (stronger armies move first)
	var prioritized_armies = army_movement_planner.prioritize_armies(player_armies, player_id)
	
	# Process each army movement
	for army in prioritized_armies:
		if army == null or not is_instance_valid(army):
			continue
			
		# Only move armies that have movement points
		if army.get_movement_points() <= 0:
			DebugLogger.log("AIMovement", "Army %s has no movement points, skipping" % army.name, 1)
			continue
			
		await _move_single_army(army, player_id)

func _move_single_army(army: Army, player_id: int) -> void:
	"""Move a single army using sophisticated pathfinding and strategic planning"""
	if army == null or not is_instance_valid(army):
		return
	
	DebugLogger.log_separator("AIMovement", "=", 60)
	DebugLogger.log("AIMovement", "Processing movement for Army %s (Player %d)" % [army.name, player_id])
	
	# Get the current region container for this army
	var current_region_container = army.get_parent()
	if current_region_container == null or not current_region_container.has_method("get_region_id"):
		DebugLogger.log("AIMovement", "Error: Could not find valid region container for Army %s" % army.name)
		return
	
	var current_region_id = current_region_container.get_region_id()
	var current_mp = army.get_movement_points()
	
	DebugLogger.log("AIMovement", "Starting position: Region %d, MP: %d" % [current_region_id, current_mp])
	
	# Skip armies with no movement points
	if current_mp <= 0:
		DebugLogger.log("AIMovement", "Army %s has no movement points remaining" % army.name)
		return
	
	# Use army movement planner to find optimal move
	var movement_plan = army_movement_planner.plan_army_movement(army, current_region_id)
	
	if not movement_plan.success:
		DebugLogger.log("AIMovement", "No suitable movement found - Reason: %s" % movement_plan.reason)
		return
	
	var desired_destination = movement_plan.desired_destination
	var end_tile_planned = movement_plan.end_tile
	var movement_path = movement_plan.path
	var movement_score = movement_plan.score
	var movement_reason = movement_plan.reason
	
	# Handle deconfliction with intelligent fallback
	if army_movement_planner.occupied_this_turn.has(end_tile_planned):
		DebugLogger.log("AIMovement", "End tile %d occupied - attempting fallback" % end_tile_planned)
		
		# Try to back off along the path to nearest unoccupied node within MP
		var fallback_result = _find_fallback_along_path(movement_path, current_mp, player_id)
		
		if fallback_result.success:
			# Use fallback path
			movement_path = fallback_result.path
			end_tile_planned = fallback_result.end_tile
			movement_reason = "conflict_fallback"
			DebugLogger.log("AIMovement", "Using fallback path ending at tile %d" % end_tile_planned)
		else:
			# Try replanning once excluding occupied tiles
			DebugLogger.log("AIMovement", "No fallback along path - attempting replan")
			var replan_result = army_movement_planner.plan_army_movement(army, current_region_id)
			
			if replan_result.success and not army_movement_planner.occupied_this_turn.has(replan_result.end_tile):
				# Use replanned movement
				desired_destination = replan_result.desired_destination
				end_tile_planned = replan_result.end_tile
				movement_path = replan_result.path
				movement_score = replan_result.score
				movement_reason = "replan_deconflict"
				DebugLogger.log("AIMovement", "Replan successful - new end tile %d" % end_tile_planned)
			else:
				# No viable alternatives - skip turn
				DebugLogger.log("AIMovement", "No viable alternatives - skipping movement")
				return
	
	# Apply random modifier to final decision
	var random_modifier = randf() * GameParameters.AI_RANDOM_SCORE_MODIFIER
	var final_score = movement_score + (random_modifier / 100.0)
	
	DebugLogger.log("AIMovement", "Executing planned movement:")
	DebugLogger.log_calculation("AIMovement", "Desired destination", desired_destination)
	DebugLogger.log_calculation("AIMovement", "Path this turn", str(movement_path))
	DebugLogger.log_calculation("AIMovement", "Planned score", movement_score * 100, "%%")
	DebugLogger.log_calculation("AIMovement", "Random modifier", random_modifier, "points")
	DebugLogger.log_calculation("AIMovement", "Final score", final_score * 100, "%%")
	DebugLogger.log_calculation("AIMovement", "Reason", movement_reason)
	
	# Execute movement step-by-step along the path
	var steps_taken = 0
	var stop_reason = "path_executed"  # Default: completed planned path
	var current_container = current_region_container
	var end_tile = current_region_id
	var battle_occurred = false
	
	# Select army once at the start
	army_manager.select_army(army, current_container, player_id)
	
	# Move along the path step by step
	if movement_path.size() > 1:
		for i in range(1, movement_path.size()):
			var next_region_id = movement_path[i]
			var next_region = map_generator.get_region_container_by_id(next_region_id)
			
			if next_region == null:
				DebugLogger.log("AIMovement", "Error: Could not find region %d in path" % next_region_id)
				stop_reason = "invalid_region"
				break
			
			# Check if we can move to this region
			if not army_manager.can_army_move_to_region(army, next_region):
				# Check if it's an enemy region (combat required)
				var next_owner = region_manager.get_region_owner(next_region_id)
				if next_owner != -1 and next_owner != player_id:
					DebugLogger.log("AIMovement", "Step %d/%d: %d→%d BLOCKED - enemy region, combat required" % [i, movement_path.size()-1, end_tile, next_region_id])
					stop_reason = "enemy_blocked"
				else:
					DebugLogger.log("AIMovement", "Step %d/%d: %d→%d BLOCKED - cannot enter" % [i, movement_path.size()-1, end_tile, next_region_id])
					stop_reason = "blocked"
				break
			
			# Attempt the move
			DebugLogger.log("AIMovement", "Step %d/%d: %d→%d" % [i, movement_path.size()-1, end_tile, next_region_id], 1)
			var move_successful = army_manager.move_army_to_region(next_region)
			
			if move_successful:
				steps_taken += 1
				end_tile = next_region_id
				current_container = next_region
				
				# Check if army was auto-deselected (indicates combat engagement)
				if army_manager.selected_army == null:
					DebugLogger.log("AIMovement", "Army auto-deselected - battle triggered", 1)
					battle_occurred = true
					stop_reason = "engaged"
					
					# CRITICAL: Wait for battle to complete before continuing
					DebugLogger.log("AIMovement", "Waiting for battle to complete...", 1)
					await _wait_for_battle_completion()
					DebugLogger.log("AIMovement", "Battle completed, continuing turn processing", 1)
					break
				
				# Check remaining MP
				if army.get_movement_points() <= 0:
					DebugLogger.log("AIMovement", "Movement points exhausted after step %d" % i, 1)
					stop_reason = "mp_exhausted"
					break
			else:
				DebugLogger.log("AIMovement", "Failed to execute step %d: %d→%d" % [i, end_tile, next_region_id])
				stop_reason = "move_failed"
				break
	else:
		DebugLogger.log("AIMovement", "No movement needed - already at destination")
		stop_reason = "at_destination"
	
	# Only deselect if army wasn't auto-deselected by battle
	if not battle_occurred and army_manager.selected_army != null:
		army_manager.deselect_army()
	
	# Update deconfliction tracking with actual end tile
	if end_tile != current_region_id and steps_taken > 0:
		army_movement_planner.mark_region_occupied(end_tile)
	
	# Log execution result with proper status classification
	var remaining_mp = army.get_movement_points()
	var reached_destination = (end_tile == desired_destination)
	var status_desc = ""
	
	if reached_destination:
		status_desc = "at_destination"
	elif steps_taken == 0:
		status_desc = "cannot_progress"  # Couldn't even take first step
	else:
		status_desc = "in_transit"  # Made legitimate progress toward destination
	
	DebugLogger.log("AIMovement", "EXEC path=%s end_tile=%d steps=%d spent=%d MP stop_reason=%s status=%s" % 
		[str(movement_path), end_tile, steps_taken, current_mp - remaining_mp, stop_reason, status_desc])
	
	DebugLogger.log_separator("AIMovement", "=", 60)

func _find_fallback_along_path(path: Array[int], mp_limit: int, player_id: int) -> Dictionary:
	"""
	Find the last unoccupied tile along a path within MP limit.
	Returns: {success: bool, path: Array[int], end_tile: int}
	"""
	if path.size() <= 1:
		return {"success": false}
	
	# Calculate costs along the path
	var cumulative_cost = 0
	var valid_positions = []
	
	for i in range(1, path.size()):
		var region_id = path[i]
		var enter_cost = army_movement_planner.army_pathfinder._calculate_enter_cost(region_id, player_id)
		
		if enter_cost == -1 or cumulative_cost + enter_cost > mp_limit:
			break  # Can't afford this step
		
		cumulative_cost += enter_cost
		valid_positions.append({
			"index": i,
			"region_id": region_id,
			"cost": cumulative_cost
		})
	
	# Go backwards through valid positions to find last unoccupied tile
	for i in range(valid_positions.size() - 1, -1, -1):
		var pos = valid_positions[i]
		if not army_movement_planner.occupied_this_turn.has(pos.region_id):
			# Found unoccupied fallback position
			var fallback_path = path.slice(0, pos.index + 1)
			DebugLogger.log("AIMovement", "Fallback found: tile %d at cost %d (backed off %d steps)" % 
				[pos.region_id, pos.cost, path.size() - 1 - pos.index], 1)
			return {
				"success": true,
				"path": fallback_path,
				"end_tile": pos.region_id
			}
	
	DebugLogger.log("AIMovement", "No unoccupied fallback position found along path", 1)
	return {"success": false}

# Battle detection is now integrated directly into army movement - this function is no longer needed

func _get_battle_modal():
	"""Get BattleModal reference"""
	if map_generator == null:
		return null
	
	# Navigate to Main → UI → BattleModal
	var main_node = map_generator.get_parent()  # Should be Main
	if main_node == null:
		return null
	
	var ui_node = main_node.get_node_or_null("UI")
	if ui_node == null:
		return null
	
	var battle_modal = ui_node.get_node_or_null("BattleModal")
	return battle_modal

func _wait_for_battle_completion() -> void:
	"""Wait for battle to complete before continuing army movement"""
	var battle_modal = _get_battle_modal()
	if battle_modal == null:
		DebugLogger.log("AIMovement", "Warning: Could not find BattleModal - continuing without waiting")
		return
	
	# Get scene tree through map_generator (which is a Node)
	if map_generator == null:
		DebugLogger.log("AIMovement", "Warning: No map_generator reference - cannot wait for battle")
		return
		
	var tree = map_generator.get_tree()
	if tree == null:
		DebugLogger.log("AIMovement", "Warning: Could not get scene tree - cannot wait for battle")
		return
	
	# Wait for battle to start (battle_in_progress becomes true)
	var timeout_counter = 0
	while not battle_modal.battle_in_progress and timeout_counter < 30:  # 3 second timeout
		await tree.create_timer(0.1).timeout
		timeout_counter += 1
	
	if not battle_modal.battle_in_progress:
		DebugLogger.log("AIMovement", "Battle did not start within timeout - continuing")
		return
	
	DebugLogger.log("AIMovement", "Battle confirmed active, waiting for completion...")
	
	# Wait for battle to finish (battle_in_progress becomes false)
	timeout_counter = 0
	while battle_modal.battle_in_progress and timeout_counter < 600:  # 60 second timeout
		await tree.create_timer(0.1).timeout
		timeout_counter += 1
	
	if battle_modal.battle_in_progress:
		DebugLogger.log("AIMovement", "Battle timeout reached - forcing continuation")
		return
	
	DebugLogger.log("AIMovement", "Battle completion confirmed")

func _manage_regions(player_id: int) -> void:
	"""Handle region management (recruitment, building, etc.)"""
	DebugLogger.log("AITurnManager", "Managing regions for Player %d (placeholder)" % player_id, 1)
	# TODO: Implement region management actions
	# This will include:
	# - Recruitment decisions
	# - Building/upgrading castles
	# - Resource management
	# - Region development priorities
