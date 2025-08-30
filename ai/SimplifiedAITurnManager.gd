extends RefCounted
class_name SimplifiedAITurnManager

# ============================================================================
# SIMPLIFIED AI TURN MANAGER
# ============================================================================
# 
# Purpose: Frontier-based AI army movement with per-army scoring
# 
# Core Algorithm:
# 1. Identify frontier targets (enemy/neutral regions adjacent to owned)
# 2. Score targets based on pure value (resources, population, level)
# 3. For each army, adjust scores by subtracting MP distance
# 4. Order moves by highest score (not army strength)
# 5. Execute moves sequentially with battle resolution
# 6. Re-evaluate targets if ownership changes
# ============================================================================

# Manager references
var region_manager: RegionManager
var army_manager: ArmyManager
var player_manager: PlayerManagerNode
var map_generator: MapGenerator

# Scoring system
var frontier_scorer: FrontierTargetScorer

# Pathfinding system (for distance calculation)
var army_pathfinder: ArmyPathfinder

# Turn state tracking
var conquered_this_turn: Dictionary = {}  # region_id -> new_owner
var armies_moved: Dictionary = {}  # army -> true

func _init(region_mgr: RegionManager, army_mgr: ArmyManager, player_mgr: PlayerManagerNode, map_gen: MapGenerator):
	region_manager = region_mgr
	army_manager = army_mgr
	player_manager = player_mgr
	map_generator = map_gen
	
	# Initialize scoring system
	frontier_scorer = FrontierTargetScorer.new(region_mgr, map_gen)
	
	# Initialize pathfinding for distance calculation
	army_pathfinder = ArmyPathfinder.new(region_mgr, army_mgr)

func calculate_next_move(player_id: int) -> Dictionary:
	"""Calculate the next best move for the AI, including all scoring and pathfinding"""
	# Step 1: Start turn - get frontier targets
	var frontier_targets = frontier_scorer.score_frontier_targets(player_id)
	if frontier_targets.is_empty():
		DebugLogger.log("SimplifiedAITurnManager", "No frontier targets available for Player %d" % player_id, 1)
		return {}
	
	DebugLogger.log("SimplifiedAITurnManager", "Found %d frontier targets" % frontier_targets.size(), 1)
	
	# Log frontier regions with their paths (for first army only as an example)
	var available_armies_temp = _get_available_armies(player_id)
	if not available_armies_temp.is_empty():
		var first_army = available_armies_temp[0]
		var army_region = first_army.get_parent()
		if army_region and army_region.has_method("get_region_id"):
			var army_location = army_region.get_region_id()
			var frontier_ids = []
			for target in frontier_targets:
				frontier_ids.append(target.region_id)
			army_pathfinder.log_frontier_regions_summary(frontier_ids, army_location, player_id)
	
	# Step 2: Get all available armies (excluding those that have already moved)
	var available_armies = _get_available_armies(player_id)
	if available_armies.is_empty():
		DebugLogger.log("SimplifiedAITurnManager", "No available armies remaining for Player %d" % player_id, 1)
		return {}
	
	# Step 3-5: Calculate scores for all army-target combinations and find the best
	var best_move = _find_best_army_target_combination(available_armies, frontier_targets, player_id)
	if best_move == null:
		DebugLogger.log("SimplifiedAITurnManager", "No valid army-target combinations found", 1)
		return {}
	
	DebugLogger.log("SimplifiedAITurnManager", "Best move: Army %s -> Region %d (score: %.1f)" % 
		[best_move.army.name, best_move.target_id, best_move.final_score], 1)
	
	return best_move

func process_turn(player_id: int) -> void:
	"""Main AI turn processing with frontier-based movement and ownership change detection"""
	DebugLogger.log("SimplifiedAITurnManager", "========== Processing turn for AI Player %d ==========" % player_id, 1)
	
	# Reset turn state
	conquered_this_turn.clear()
	armies_moved.clear()
	
	# Main AI loop - continue until no more valid moves
	while true:
		# Calculate the best move BEFORE any pause
		var best_move = await calculate_next_move(player_id)
		
		if best_move.is_empty():
			break
			
		# In step-by-step mode, pause before executing the move
		# The calculation and debug display already happened in calculate_next_move()
		
		# Step 6: Move the army that had highest value target
		var ownership_changed = await _execute_army_move(best_move, player_id)
		armies_moved[best_move.army] = true
		
		# Step 7: If region changed owner, repeat from step 1 (recalculate frontier)
		# Step 8: If no ownership change, continue with next army
		if ownership_changed:
			DebugLogger.log("SimplifiedAITurnManager", "Ownership changed - recalculating frontier targets", 1)
			# Continue loop to recalculate frontier
		else:
			DebugLogger.log("SimplifiedAITurnManager", "No ownership change - continuing with remaining armies", 1)
			# Continue with remaining armies
	
	DebugLogger.log("SimplifiedAITurnManager", "========== Completed turn for AI Player %d ==========" % player_id, 1)

func _get_available_armies(player_id: int) -> Array:
	"""Get all armies that haven't moved this turn and have movement points"""
	var available_armies = []
	var player_armies = army_manager.get_player_armies(player_id)
	
	DebugLogger.log("SimplifiedAITurnManager", "Checking %d total armies for Player %d" % [player_armies.size(), player_id], 1)
	
	for army in player_armies:
		if army == null or not is_instance_valid(army):
			DebugLogger.log("SimplifiedAITurnManager", "  Army null/invalid: %s" % str(army), 1)
			continue
		
		# Skip armies that have already moved this turn
		if armies_moved.has(army):
			DebugLogger.log("SimplifiedAITurnManager", "  Army %s already moved this turn" % army.name, 1)
			continue
			
		# Skip armies with no movement points
		if army.get_movement_points() <= 0:
			DebugLogger.log("SimplifiedAITurnManager", "  Army %s has no MP (%d)" % [army.name, army.get_movement_points()], 1)
			continue
			
		DebugLogger.log("SimplifiedAITurnManager", "  Army %s available (MP: %d)" % [army.name, army.get_movement_points()], 1)
		available_armies.append(army)
	
	DebugLogger.log("SimplifiedAITurnManager", "Found %d available armies" % available_armies.size(), 1)
	return available_armies

func _find_best_army_target_combination(armies: Array, frontier_targets: Array, player_id: int) -> Dictionary:
	"""Find the army-target combination with the highest score"""
	var best_move = null
	var highest_score = -999.0
	
	# Loop through all armies
	for army in armies:
		if army == null or not is_instance_valid(army):
			continue
			
		# Get army's current position
		var current_region_container = army.get_parent()
		if current_region_container == null or not current_region_container.has_method("get_region_id"):
			continue
			
		var current_region_id = current_region_container.get_region_id()
		
		# Generate unique random seed based on army name for consistent per-army randomness
		var army_hash = hash(army.name + str(player_id))
		var rng = RandomNumberGenerator.new()
		rng.seed = army_hash
		
		# Calculate base score + random modifier - movement cost for each target
		for target_data in frontier_targets:
			var region_id = target_data.region_id
			
			# Skip if already conquered this turn
			if conquered_this_turn.has(region_id):
				continue
				
			# Calculate base score (already 0-1, multiply by 100)
			var base_score = target_data.base_score * 100.0
			
			# Add per-army random modifier
			var random_modifier = rng.randf() * GameParameters.AI_RANDOM_SCORE_MODIFIER
			
			# Calculate MP cost to target
			var path_data = army_pathfinder.find_path_to_target(current_region_id, region_id, player_id)
			var mp_cost = 0
			if path_data.has("success") and path_data.success:
				mp_cost = path_data.cost
			else:
				continue  # Can't reach target
			
			# Final score: BaseScore + RandomModifier - MovementCost
			var final_score = base_score + random_modifier - mp_cost
			
			# Check if this is the best combination so far
			if final_score > highest_score:
				highest_score = final_score
				best_move = {
					"army": army,
					"target_id": region_id,
					"target_name": target_data.region_name,
					"base_score": base_score,
					"random_modifier": random_modifier,
					"mp_cost": mp_cost,
					"final_score": final_score,
					"path": path_data.path,
					"current_region": current_region_id
				}
	
	return best_move

func _calculate_all_army_moves(armies: Array, targets: Array, player_id: int) -> Array:
	"""Calculate best move for each army with distance-adjusted scoring"""
	var all_moves = []
	
	for army in armies:
		if army == null or not is_instance_valid(army):
			continue
			
		# Skip armies with no movement points
		if army.get_movement_points() <= 0:
			continue
			
		# Get army's current position
		var current_region_container = army.get_parent()
		if current_region_container == null or not current_region_container.has_method("get_region_id"):
			continue
			
		var current_region_id = current_region_container.get_region_id()
		
		# Score each target for this army
		var best_move = _find_best_target_for_army(army, current_region_id, targets, player_id)
		if best_move != null:
			all_moves.append(best_move)
	
	return all_moves

func _find_best_target_for_army(army: Army, current_region_id: int, targets: Array, player_id: int) -> Dictionary:
	"""Find the best target for a specific army considering MP distance"""
	var best_move = null
	var best_score = -999.0
	
	for target_data in targets:
		var target_id = target_data.region_id
		
		# Skip if already conquered this turn
		if conquered_this_turn.has(target_id):
			continue
		
		# Calculate path and MP cost to target
		var path_data = army_pathfinder.find_path_to_target(current_region_id, target_id, player_id)
		if path_data.is_empty() or not path_data.success:
			continue  # Can't reach target
		
		var mp_cost = path_data.cost
		var path = path_data.path
		
		# Adjust score by subtracting MP cost
		# Base score is 0-1, multiply by 100 for better granularity, then subtract MP
		var adjusted_score = (target_data.base_score * 100.0) - mp_cost
		
		if adjusted_score > best_score:
			best_score = adjusted_score
			best_move = {
				"army": army,
				"target_id": target_id,
				"target_name": target_data.region_name,
				"base_score": target_data.base_score,
				"mp_cost": mp_cost,
				"final_score": adjusted_score,
				"path": path,
				"current_region": current_region_id
			}
	
	return best_move

func _execute_army_move(move_data: Dictionary, player_id: int) -> bool:
	"""Execute a single army move with battle resolution. Returns true if ownership changed."""
	var army = move_data.army
	var target_id = move_data.target_id
	var path = move_data.path
	
	DebugLogger.log_separator("SimplifiedAI", "=", 60)
	DebugLogger.log("SimplifiedAI", "Moving Army %s to %s (score: %.1f)" % 
		[army.name, move_data.target_name, move_data.final_score], 1)
	
	# Check if target is still valid (not conquered by another army)
	if conquered_this_turn.has(target_id):
		DebugLogger.log("SimplifiedAI", "Target already conquered this turn, skipping move", 1)
		return false
	
	# Get current region for army selection
	var current_region_container = army.get_parent()
	if current_region_container == null:
		DebugLogger.log("SimplifiedAI", "Error: Army has no valid parent region", 1)
		return false
	
	# Select the army
	army_manager.select_army(army, current_region_container, player_id)
	
	# Trim path to current MP
	var current_mp = army.get_movement_points()
	var trimmed_path = army_pathfinder.trim_path_to_mp_limit(path, player_id, current_mp)
	
	if trimmed_path.size() <= 1:
		DebugLogger.log("SimplifiedAI", "Cannot move - no valid path within MP limit", 1)
		army_manager.deselect_army()
		return false
	
	# Execute movement along path
	var battle_occurred = false
	var ownership_changed = false
	var steps_taken = 0
	var final_position = move_data.current_region
	
	for i in range(1, trimmed_path.size()):
		var next_region_id = trimmed_path[i]
		var next_region = map_generator.get_region_container_by_id(next_region_id)
		
		if next_region == null:
			DebugLogger.log("SimplifiedAI", "Error: Region %d not found" % next_region_id, 1)
			break
		
		# Attempt move
		DebugLogger.log("SimplifiedAI", "Step %d/%d: Moving to region %d" % 
			[i, trimmed_path.size()-1, next_region_id], 1)
		
		var move_successful = army_manager.move_army_to_region(next_region)
		
		if move_successful:
			steps_taken += 1
			final_position = next_region_id
			
			# Check if battle was triggered (army auto-deselected)
			if army_manager.selected_army == null:
				DebugLogger.log("SimplifiedAI", "Battle triggered at region %d" % next_region_id, 1)
				battle_occurred = true
				
				# Wait for battle completion
				await _wait_for_battle_completion()
				
				# Check if we won the battle by checking actual region ownership (BattleManager handles this)
				var current_owner = region_manager.get_region_owner(next_region_id)
				if current_owner == player_id:
					conquered_this_turn[next_region_id] = player_id
					ownership_changed = true
					DebugLogger.log("SimplifiedAI", "Battle won, region %d conquered by Player %d - ownership changed!" % [next_region_id, player_id], 1)
					
					# Trigger debug visualizer recalculation if active
					_notify_ownership_change(player_id)
				else:
					if is_instance_valid(army):
						DebugLogger.log("SimplifiedAI", "Battle result: withdraw or lost, army still alive", 1)
					else:
						DebugLogger.log("SimplifiedAI", "Army defeated in battle", 1)
				break
			
			# Check remaining MP
			if army.get_movement_points() <= 0:
				DebugLogger.log("SimplifiedAI", "Movement points exhausted", 2)
				break
		else:
			DebugLogger.log("SimplifiedAI", "Move failed to region %d" % next_region_id, 1)
			break
	
	# Deselect army if not in battle
	if not battle_occurred and army_manager.selected_army != null:
		army_manager.deselect_army()
	
	DebugLogger.log("SimplifiedAI", "Movement complete: %d steps taken, final position: %d, ownership_changed: %s" % 
		[steps_taken, final_position, str(ownership_changed)], 1)
	DebugLogger.log_separator("SimplifiedAI", "=", 60)
	
	return ownership_changed

func _wait_for_battle_completion() -> void:
	"""Wait for battle to complete before continuing"""
	# Get scene tree through map_generator
	if map_generator == null:
		return
		
	var tree = map_generator.get_tree()
	if tree == null:
		return
	
	# Get battle modal
	var main_node = map_generator.get_parent()
	if main_node == null:
		return
		
	var ui_node = main_node.get_node_or_null("UI")
	if ui_node == null:
		return
		
	var battle_modal = ui_node.get_node_or_null("BattleModal")
	if battle_modal == null:
		return
	
	# Wait for battle to start
	var timeout = 0
	while battle_modal.battle_in_progress == false and timeout < 30:
		await tree.create_timer(0.1).timeout
		timeout += 1
	
	if not battle_modal.battle_in_progress:
		return  # Battle didn't start
	
	# Wait for battle to complete
	timeout = 0
	while battle_modal.battle_in_progress and timeout < 600:
		await tree.create_timer(0.1).timeout
		timeout += 1
	
	DebugLogger.log("SimplifiedAI", "Battle completed", 1)

func _notify_ownership_change(player_id: int):
	"""Notify AI debug visualizer of ownership changes for score recalculation"""
	if map_generator == null:
		return
		
	# Find the AI debug visualizer in the scene
	var map_node = map_generator.get_parent()
	if map_node == null:
		return
		
	var ai_debug_visualizer = map_node.get_node_or_null("AIDebugVisualizer")
	if ai_debug_visualizer != null and ai_debug_visualizer.has_method("recalculate_scores_on_ownership_change"):
		ai_debug_visualizer.recalculate_scores_on_ownership_change(player_id)
