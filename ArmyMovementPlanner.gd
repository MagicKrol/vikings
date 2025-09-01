extends RefCounted
class_name ArmyMovementPlanner

# ============================================================================
# ARMY MOVEMENT PLANNER
# ============================================================================
# 
# Purpose: High-level army movement coordination and strategic planning
# 
# Core Responsibilities:
# - Coordinate pathfinding with target scoring for optimal moves
# - Implement discounted multi-turn strategic evaluation
# - Manage frontier detection and rally point fallback systems
# - Handle multi-army deconfliction through priority ordering
# - Provide comprehensive logging for AI decision debugging
# 
# Key Features:
# - Integration of ArmyPathfinder with ArmyTargetScorer
# - Discounted scoring with gamma_turn for multi-turn evaluation
# - Frontier detection (owned regions adjacent to non-owned)
# - Rally point system using castles as safe fallback destinations
# - Turn-based planning with minWanted threshold for movement decisions
# 
# Integration Points:
# - ArmyPathfinder: Multi-turn pathfinding with MP constraints
# - ArmyTargetScorer: Pure target evaluation (Val function)
# - RegionManager: Territory ownership and castle position tracking
# - GameParameters: Algorithm parameters and strategic constants
# ============================================================================

# Core system references
var region_manager: RegionManager
var army_manager: ArmyManager
var army_pathfinder: ArmyPathfinder
var army_target_scorer: ArmyTargetScorer

# Deconfliction tracking - regions with armies this turn
var occupied_this_turn: Dictionary = {}  # region_id -> true

func _init(region_mgr: RegionManager, army_mgr: ArmyManager, target_scorer: ArmyTargetScorer):
	region_manager = region_mgr
	army_manager = army_mgr
	army_target_scorer = target_scorer
	army_pathfinder = ArmyPathfinder.new(region_mgr, army_mgr)

func reset_turn_tracking() -> void:
	"""Reset deconfliction tracking for new turn"""
	occupied_this_turn.clear()

func mark_region_occupied(region_id: int) -> void:
	"""Mark a region as having an army move there this turn"""
	occupied_this_turn[region_id] = true

func plan_army_movement(army: Army, current_region_id: int) -> Dictionary:
	"""
	Plan optimal movement for an army using canonical scoring from ArmyTargetScorer.
	Returns: {success: bool, target_region_id: int, path: Array[int], score: float, reason: String}
	"""
	if army == null or not is_instance_valid(army):
		return {"success": false, "reason": "Invalid army"}
	
	var player_id = army.get_player_id()
	var current_mp = army.get_movement_points()
	
	DebugLogger.log("AIPlanning", "Planning movement for Army %s (Player %d) from region %d with %d MP" % [army.name, player_id, current_region_id, current_mp])
	
	# Run ONE limited Dijkstra with R*5 horizon (15 MP default)
	var horizon_mp = GameParameters.ARMY_PATHFINDER_HORIZON_MP  # Should be 15
	var reachable = army_pathfinder.find_reachable_regions(current_region_id, player_id, horizon_mp)
	
	if reachable.size() <= 1:  # Only current region
		DebugLogger.log("AIPlanning", "No reachable regions found for Army %s" % army.name)
		return {"success": false, "reason": "No reachable regions"}
	
	DebugLogger.log("AIPlanning", "Found %d reachable regions within %d MP horizon" % [reachable.size(), horizon_mp], 1)
	
	# Build candidate set: non-owned regions only (no deconfliction in planner)
	var candidates = []
	for region_id in reachable:
		if region_id == current_region_id:
			continue
		
		var region_owner = region_manager.get_region_owner(region_id)
		if region_owner != player_id:  # Non-owned (enemy or neutral)
			var region_data = reachable[region_id]
			candidates.append({
				"region_id": region_id,
				"cost": region_data.cost,
				"path": region_data.path
			})
	
	DebugLogger.log("AIPlanning", "Found %d non-owned candidate regions" % candidates.size(), 1)
	
	# Score candidates using canonical scoring
	var best_move = _score_and_select_best_canonical(army, candidates, player_id, current_mp)
	
	if best_move.is_empty() or best_move.score < GameParameters.ARMY_MOVEMENT_MIN_WANTED / 100.0:
		DebugLogger.log("AIPlanning", "No suitable candidate above minWanted threshold (%d%%)" % GameParameters.ARMY_MOVEMENT_MIN_WANTED)
		
		# Fallback: Find nearest frontier or rally point
		var fallback_move = _find_fallback_move(reachable, player_id, current_region_id, current_mp)
		if not fallback_move.is_empty():
			return fallback_move
		
		return {"success": false, "reason": "No valid moves or fallbacks"}
	
	return best_move

func _score_and_select_best_canonical(army: Army, candidates: Array, player_id: int, current_mp: int) -> Dictionary:
	"""
	Score candidates using canonical final scoring from ArmyTargetScorer.
	Apply danger penalty as a separate adjustment after the canonical final score.
	Returns best move or empty dict.
	"""
	if candidates.is_empty():
		return {}
	
	if army == null:
		return {}
	
	DebugLogger.log("AIScoring", "Scoring %d non-owned candidate regions using canonical scoring" % candidates.size())
	
	var best_region_id = -1
	var best_score = -999.0
	var best_path = []
	var best_reason = "normal"
	var best_canonical_final = 0.0
	var best_danger_penalty = 0.0
	
	for candidate in candidates:
		var region_id = candidate.region_id
		var path = candidate.path
		
		# Use canonical raw API to get final army score
		var score_result = army_target_scorer.get_final_army_score_raw(army, region_id)
		
		if not score_result.get("reachable", false):
			continue
		
		# Get the canonical raw final score (base_raw + random - mp)
		var canonical_final_raw = score_result.get("final_raw", 0.0)
		
		# Apply danger penalty as a separate adjustment after canonical scoring
		var danger_penalty = _calculate_danger_penalty(region_id, player_id)
		var decision_score = canonical_final_raw - danger_penalty
		
		DebugLogger.log("AIScoring", "Region %d: base_raw=%.1f random=%.1f mp=%.1f final_raw=%.1f danger=%.1f%% decision=%.1f" % 
			[region_id, score_result.get("base_raw_total", 0.0), score_result.get("random_modifier", 0.0), 
			 score_result.get("mp_cost", 0.0), canonical_final_raw, danger_penalty * 100, decision_score], 1)
		
		if decision_score > best_score:
			best_score = decision_score
			best_region_id = region_id
			best_path = path
			best_canonical_final = canonical_final_raw
			best_danger_penalty = danger_penalty
	
	if best_region_id == -1:
		return {}
	
	# Trim path to current MP
	var trimmed_path = army_pathfinder.trim_path_to_mp_limit(best_path, player_id, current_mp)
	
	# Log chosen destination
	DebugLogger.log("AIMovement", "CHOSEN dest=%d final_raw=%.1f danger=%.1f%% decision=%.1f reason=%s" %
		[best_region_id, best_canonical_final, best_danger_penalty * 100, best_score, best_reason])
	
	return {
		"success": true,
		"desired_destination": best_region_id,
		"end_tile": trimmed_path[-1] if trimmed_path.size() > 0 else best_region_id,
		"target_region_id": trimmed_path[-1] if trimmed_path.size() > 0 else best_region_id,  # Backward compatibility
		"path": trimmed_path,
		"score": best_score,  # This is the decision score (final_raw - danger)
		"reason": best_reason,
		"canonical_final_raw": best_canonical_final,  # Store canonical raw score
		"decision_score": best_score  # Store decision score (final_raw - danger)
	}


# Removed old unused functions - now using _score_and_select_best and _find_fallback_move

func _calculate_danger_penalty(region_id: int, player_id: int) -> float:
	"""
	Calculate danger penalty using power-ratio based approach.
	Penalty = clamp(k * max(0, PR - 1), 0, cap) where PR = enemy_power / my_power
	"""
	var my_power = 0.0
	var enemy_power = 0.0
	
	# Include the target region and all adjacent regions in power calculation
	var regions_to_check = [region_id]
	var neighbors = region_manager.get_neighbor_regions(region_id)
	regions_to_check.append_array(neighbors)
	
	for check_region_id in regions_to_check:
		# Check region garrison
		var region_container = region_manager.map_generator.get_region_container_by_id(check_region_id)
		if region_container == null:
			continue
			
		var region = region_container as Region
		if region != null and region.has_garrison():
			var region_owner = region_manager.get_region_owner(check_region_id)
			var garrison_power = GameParameters.ARMY_DANGER_GARRISON_POWER
			
			if region_owner == player_id:
				my_power += garrison_power
			elif region_owner != -1:  # Enemy owned
				enemy_power += garrison_power
		
		# Check armies in the region
		for child in region_container.get_children():
			if child.has_method("get_player_id") and child.has_method("get_total_soldiers"):  # It's an army
				var army_owner = child.get_player_id()
				var army_power = float(child.get_total_soldiers())
				
				if army_owner == player_id:
					my_power += army_power
				elif army_owner != -1:  # Enemy army
					enemy_power += army_power
	
	# Calculate power ratio and danger penalty
	if my_power <= 0.0:
		# No friendly power - high danger if enemies present
		if enemy_power > 0.0:
			return GameParameters.ARMY_DANGER_MAX_PENALTY
		else:
			return 0.0
	
	var power_ratio = enemy_power / my_power
	var danger_multiplier = GameParameters.ARMY_DANGER_PR_MULTIPLIER
	var max_penalty = GameParameters.ARMY_DANGER_MAX_PENALTY
	var penalty = clamp(danger_multiplier * max(0.0, power_ratio - 1.0), 0.0, max_penalty)
	
	return penalty

func _find_fallback_move(reachable: Dictionary, player_id: int, current_region_id: int, current_mp: int) -> Dictionary:
	"""
	Find fallback movement: nearest frontier or rally point.
	Frontier = owned region adjacent to non-owned.
	Rally = castle position.
	"""
	# First try frontier regions
	var frontier_regions = detect_frontier_regions(player_id)
	var nearest_frontier_id = -1
	var nearest_frontier_cost = 999
	var nearest_frontier_path = []
	
	for frontier_id in frontier_regions:
		if reachable.has(frontier_id) and frontier_id != current_region_id:
			var cost = reachable[frontier_id].cost
			if cost < nearest_frontier_cost:
				nearest_frontier_cost = cost
				nearest_frontier_id = frontier_id
				nearest_frontier_path = reachable[frontier_id].path
	
	if nearest_frontier_id != -1:
		# Move toward frontier
		var trimmed_path = army_pathfinder.trim_path_to_mp_limit(nearest_frontier_path, player_id, current_mp)
		var end_tile = trimmed_path[-1] if trimmed_path.size() > 0 else nearest_frontier_id
		
		DebugLogger.log("AIMovement", "CHOSEN dest=%d (frontier) cost=%d reason=frontier" % [nearest_frontier_id, nearest_frontier_cost])
		
		return {
			"success": true,
			"desired_destination": nearest_frontier_id,
			"end_tile": end_tile,
			"target_region_id": end_tile,  # Backward compatibility
			"path": trimmed_path,
			"score": 0.01,  # Low score for fallback
			"reason": "frontier"
		}
	
	# Try rally point (castle)
	var castle_region_id = region_manager.get_castle_starting_position(player_id)
	if castle_region_id != -1 and castle_region_id != current_region_id:
		if reachable.has(castle_region_id):
			var castle_path = reachable[castle_region_id].path
			var trimmed_path = army_pathfinder.trim_path_to_mp_limit(castle_path, player_id, current_mp)
			var end_tile = trimmed_path[-1] if trimmed_path.size() > 0 else castle_region_id
			
			DebugLogger.log("AIMovement", "CHOSEN dest=%d (rally) cost=%d reason=rally" % [castle_region_id, reachable[castle_region_id].cost])
			
			return {
				"success": true,
				"desired_destination": castle_region_id,
				"end_tile": end_tile,
				"target_region_id": end_tile,  # Backward compatibility
				"path": trimmed_path,
				"score": 0.01,
				"reason": "rally"
			}
	
	DebugLogger.log("AIPlanning", "No fallback move available")
	return {}


func detect_frontier_regions(player_id: int) -> Array[int]:
	"""
	Detect frontier regions: owned regions adjacent to non-owned territories.
	These are strategically important for expansion and defense.
	"""
	var player_regions = region_manager.get_player_regions(player_id)
	var frontier_regions: Array[int] = []
	
	for region_id in player_regions:
		var neighbors = region_manager.get_neighbor_regions(region_id)
		var is_frontier = false
		
		for neighbor_id in neighbors:
			var neighbor_owner = region_manager.get_region_owner(neighbor_id)
			if neighbor_owner != player_id:  # Adjacent to non-owned region
				is_frontier = true
				break
		
		if is_frontier:
			frontier_regions.append(region_id)
	
	return frontier_regions

func prioritize_armies(armies: Array[Army], player_id: int) -> Array[Army]:
	"""
	Prioritize armies for movement to avoid conflicts.
	Simple implementation: prioritize by army strength, then by name.
	"""
	var prioritized = armies.duplicate()
	
	# Sort by total soldiers (descending), then by name for consistency
	prioritized.sort_custom(func(a, b): 
		var strength_a = a.get_total_soldiers()
		var strength_b = b.get_total_soldiers()
		if strength_a != strength_b:
			return strength_a > strength_b  # Higher strength first
		return a.name < b.name  # Alphabetical for consistency
	)
	
	return prioritized