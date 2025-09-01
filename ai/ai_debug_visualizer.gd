extends Node2D
class_name AIDebugVisualizer

# ============================================================================
# AI DEBUG VISUALIZER
# ============================================================================
# 
# Purpose: Visual debugging tools for AI scoring system
# 
# Core Responsibilities:
# - Display numerical scores on regions
# - Toggle debug visualization on/off
# - Render score overlays with readable formatting
# - Color coding based on score ranges
# 
# Visual Elements:
# - Score text labels positioned at region centers
# - Background rectangles for readability
# - Color-coded backgrounds (green=high, yellow=medium, red=low)
# - Toggle visibility with "D" key
# 
# Integration Points:
# - RegionScorer: Get calculated scores for all regions
# - MapGenerator: Access region positions and containers
# - Input system: Toggle debug display
# ============================================================================

# Debug state
var debug_visible: bool = false
var current_player_scores: Dictionary = {}
var detailed_score_cache: Dictionary = {}  # Cache detailed scoring factors
var current_army_perspective: String = ""  # Which army's perspective we're showing

# Visual styling
const SCORE_FONT_SIZE = 20
const LABEL_BACKGROUND_COLOR = Color(0, 0, 0, 0.7)  # Semi-transparent black
const LABEL_PADDING = Vector2(8, 4)
const HIGH_SCORE_COLOR = Color(0.2, 0.8, 0.2, 0.8)  # Green
const MID_SCORE_COLOR = Color(0.8, 0.8, 0.2, 0.8)   # Yellow  
const LOW_SCORE_COLOR = Color(0.8, 0.2, 0.2, 0.8)   # Red

# Score thresholds for color coding
# TODO: Revisit thresholds since raw scale differs from 0..100
const HIGH_SCORE_THRESHOLD = 70.0
const MID_SCORE_THRESHOLD = 30.0

# Component references
var region_scorer: RegionScorer
var castle_placement_scorer: CastlePlacementScorer
var army_target_scorer: ArmyTargetScorer
var frontier_target_scorer: FrontierTargetScorer  # New frontier-based scorer
var map_generator: MapGenerator

# Debug mode state
var debug_mode: String = "castle_placement"  # "castle_placement" or "army_target"
var step_by_step_mode: bool = false

func _init():
	# Layer for debug rendering
	z_index = 1000  # Render on top of everything

func initialize(scorer: RegionScorer, castle_scorer: CastlePlacementScorer, map_gen: MapGenerator, region_mgr: RegionManager = null):
	"""Initialize with required components"""
	region_scorer = scorer
	castle_placement_scorer = castle_scorer
	map_generator = map_gen
	
	# Initialize army target scorer and frontier scorer
	if map_gen != null and region_mgr != null:
		army_target_scorer = ArmyTargetScorer.new(region_mgr, map_gen)
		frontier_target_scorer = FrontierTargetScorer.new(region_mgr, map_gen)
		DebugLogger.log("AIPlanning", "Initialized with all scorers including ArmyTargetScorer and FrontierTargetScorer")
	elif map_gen != null:
		DebugLogger.log("AIPlanning", "Warning: Could not initialize target scorers - RegionManager not provided")
	
	DebugLogger.log("AIPlanning", "Initialized with region scorer, castle placement scorer, and map generator")

func toggle_debug_display(player_id: int):
	"""Toggle debug visualization and update scores with fresh random values"""
	debug_visible = !debug_visible
	
	if debug_visible:
		DebugLogger.log("AIPlanning", "Showing AI debug scores for Player " + str(player_id) + " (mode: " + debug_mode + ")")
		
		# Check if castle placement is over to determine correct mode
		var game_manager = get_node_or_null("/root/Main/GameManager")
		if game_manager != null and not game_manager.is_castle_placing_mode():
			# Castle placement is done, ensure we're in army target mode
			if debug_mode != "army_target":
				debug_mode = "army_target"
				DebugLogger.log("AIPlanning", "Auto-switched to army target mode since castle placement is complete")
		
		_update_scores_for_player(player_id)
	else:
		DebugLogger.log("AIPlanning", "Hiding AI debug scores")
		current_player_scores.clear()
	
	queue_redraw()  # Trigger _draw() call

func switch_to_army_target_mode():
	"""Switch to army target scoring mode after castle placement"""
	debug_mode = "army_target"
	DebugLogger.log("AIPlanning", "Switched to army target scoring mode")
	
	# Always clear old scores when switching modes
	current_player_scores.clear()
	detailed_score_cache.clear()
	
	# If debug is visible, recalculate scores immediately
	if debug_visible:
		var game_manager = get_node_or_null("/root/Main/GameManager")
		if game_manager != null:
			var current_player_id = game_manager.get_current_player_id()
			DebugLogger.log("AIPlanning", "Recalculating army target scores for Player " + str(current_player_id))
			_update_scores_for_player(current_player_id)
		queue_redraw()

func enable_step_by_step_mode(enabled: bool):
	"""Enable/disable step-by-step AI debugging"""
	step_by_step_mode = enabled
	DebugLogger.log("AIPlanning", "Step-by-step mode: " + ("enabled" if enabled else "disabled"))

func is_step_by_step_mode() -> bool:
	"""Check if step-by-step mode is active"""
	return step_by_step_mode

func _update_scores_for_player(player_id: int):
	"""Calculate and store AI scores based on current debug mode"""
	if debug_mode == "castle_placement":
		_update_castle_placement_scores(player_id)
	elif debug_mode == "army_target":
		_update_army_target_scores(player_id)

func _update_castle_placement_scores(player_id: int):
	"""Calculate and store castle placement scores"""
	if castle_placement_scorer == null:
		DebugLogger.log("AIPlanning", "Error: CastlePlacementScorer not initialized")
		return
	
	# Check if we need to recalculate - only if any region has invalid scores
	var need_calculation = false
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node != null:
		for child in regions_node.get_children():
			if child is Region:
				var region = child as Region
				if not region.is_ai_scoring_valid():
					need_calculation = true
					break
	
	if not need_calculation:
		DebugLogger.log("AIPlanning", "Using existing stored castle placement scores")
		_update_display_cache_from_regions()
		return
	
	DebugLogger.log("AIPlanning", "Recalculating castle placement scores for Player " + str(player_id) + "...")
	
	# Get ALL owned regions for distance calculation
	var owned_region_ids = _get_all_owned_regions()
	
	# Calculate castle placement scores for all candidates
	var castle_scores = castle_placement_scorer.score_castle_placement_candidates(owned_region_ids)
	
	# Store scores directly in the Region objects
	for score_data in castle_scores:
		var region_id = score_data.regionId
		var region = map_generator.get_region_container_by_id(region_id) as Region
		if region != null:
			var cluster_score = score_data.OverallScore * 100.0
			var individual_score = castle_placement_scorer.calculate_individual_region_score(region) * 100.0
			
			var factors = {
				"distance": score_data.cluster_data.distance_to_enemy,
				"cluster_size": score_data.cluster_data.owned_count,
				"pop_score": score_data.PopNorm,
				"resource_score": score_data.ResourceScore,
				"safety_score": score_data.SafetyScore,
				"size_score": score_data.SizeScore,
				"level_score": score_data.LevelScore
			}
			
			# Store everything in the region permanently
			region.set_ai_scores(cluster_score, individual_score, factors, score_data.cluster_data)
	
	# Update display cache from stored region data
	_update_display_cache_from_regions()
	
	DebugLogger.log("AIPlanning", "Stored castle placement scores in " + str(castle_scores.size()) + " regions")

func _update_army_target_scores(player_id: int):
	"""Calculate and store army target scores using canonical scoring"""
	# Always use frontier scorer for consistency
	if frontier_target_scorer != null:
		_update_frontier_scores(player_id)
		return

	# This fallback should rarely be used, but if needed, use canonical scoring
	if army_target_scorer == null:
		DebugLogger.log("AIPlanning", "Error: No target scorer available")
		return
	
	DebugLogger.log("AIPlanning", "Fallback: Calculating army target scores for Player " + str(player_id) + "...")
	
	# Get all passable regions as potential targets
	var all_region_ids = _get_all_passable_regions()
	
	if all_region_ids.is_empty():
		DebugLogger.log("AIPlanning", "No passable regions found")
		return
	
	# Find a representative army for scoring
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager == null:
		return
		
	var army_manager = game_manager.get_army_manager()
	if army_manager == null:
		return
		
	var player_armies = army_manager.get_player_armies(player_id)
	if player_armies.is_empty():
		DebugLogger.log("AIPlanning", "No armies found for canonical scoring")
		return
	
	# Use first valid army for canonical scoring
	var army = null
	for test_army in player_armies:
		if test_army != null and is_instance_valid(test_army):
			army = test_army
			break
	
	if army == null:
		return
	
	# Clear existing scores
	current_player_scores.clear()
	detailed_score_cache.clear()
	
	# Score all regions using canonical raw API
	for region_id in all_region_ids:
		var score_result = army_target_scorer.get_final_army_score_raw(army, region_id)
		
		if not score_result.get("reachable", false):
			continue
		
		var final_raw = score_result.get("final_raw", 0.0)
		current_player_scores[region_id] = final_raw
		
		# Store detailed factors using canonical raw data
		var factors = {
			"base_raw_total": score_result.get("base_raw_total", 0.0),
			"random_modifier": score_result.get("random_modifier", 0.0),
			"movement_cost": score_result.get("mp_cost", 0.0),
			"final_raw": final_raw,
			"strategic_0_10": score_result.get("strategic_0_10", 0.0),
			"population_0_10": score_result.get("population_0_10", 0.0),
			"level_0_10": score_result.get("level_0_10", 0.0),
			"resource_0_10": score_result.get("resource_0_10", 0.0),
			"resources_breakdown": score_result.get("resources_breakdown", {})
		}
		detailed_score_cache[region_id] = factors
	
	DebugLogger.log("AIPlanning", "Stored canonical army target scores for " + str(current_player_scores.size()) + " regions")

func _update_display_cache_from_regions():
	"""Update display cache from stored region data with random modifiers"""
	current_player_scores.clear()
	detailed_score_cache.clear()
	
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node != null:
		for child in regions_node.get_children():
			if child is Region:
				var region = child as Region
				if region.is_ai_scoring_valid():
					var region_id = region.get_region_id()
					var base_score = region.get_ai_cluster_score()
					
					# Add random modifier (same logic as in GameManager)
					var random_modifier = randf() * GameParameters.AI_RANDOM_SCORE_MODIFIER
					var final_score = base_score + random_modifier
					
					# Store both for display purposes
					current_player_scores[region_id] = final_score
					# Store the components for the display format
					var score_components = region.get_ai_scoring_factors()
					score_components["base_score"] = base_score
					score_components["random_modifier"] = random_modifier
					score_components["final_score"] = final_score
					detailed_score_cache[region_id] = score_components

func _draw():
	"""Render debug scores on regions"""
	if not debug_visible or current_player_scores.is_empty():
		return
	
	if map_generator == null:
		return
	
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		return
	
	# Draw score for each region
	for child in regions_node.get_children():
		if child is Region:
			var region = child as Region
			var region_id = region.get_region_id()
			
			if region_id in current_player_scores:
				var score = current_player_scores[region_id]
				_draw_region_score(region, score)

func _draw_region_score(region: Region, score: float):
	"""Draw score label at region center"""
	var region_center = region.center
	
	if region_center == Vector2.ZERO:
		return  # Skip regions without valid center
	
	# Convert to local coordinates
	var local_pos = to_local(region_center)
	
	# Format score text as "base+random-movement" (e.g., "72+3-5")
	var region_id = region.get_region_id()
	var score_text = str(int(score))  # Default fallback
	
	# Try to get detailed score info for better formatting
	if region_id in detailed_score_cache:
		var components = detailed_score_cache[region_id]
		if components.has("base_raw_total") and components.has("random_modifier") and components.has("movement_cost"):
			var base_raw = int(components.base_raw_total)
			var random_mod = int(components.random_modifier)
			var movement_cost = int(components.movement_cost)
			score_text = str(base_raw) + "+" + str(random_mod) + "-" + str(movement_cost)
		elif components.has("base_raw_total") and components.has("random_modifier"):
			# Fallback for format without movement cost
			var base_raw = int(components.base_raw_total)
			var random_mod = int(components.random_modifier)
			score_text = str(base_raw) + "+" + str(random_mod)
		elif components.has("base_score") and components.has("random_modifier") and components.has("movement_cost"):
			# Legacy format fallback
			var base_score = int(components.base_score)
			var random_mod = int(components.random_modifier)
			var movement_cost = int(components.movement_cost)
			score_text = str(base_score) + "+" + str(random_mod) + "-" + str(movement_cost)
	
	# Calculate text size for background
	var font = ThemeDB.fallback_font
	var font_size = SCORE_FONT_SIZE
	var text_size = font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	
	# Calculate background rect
	var bg_size = text_size + LABEL_PADDING * 2
	var bg_rect = Rect2(local_pos - bg_size * 0.5, bg_size)
	
	# Choose color based on score
	var bg_color = _get_score_color(score)
	
	# Draw background rectangle
	draw_rect(bg_rect, bg_color)
	draw_rect(bg_rect, Color.BLACK, false, 2.0)  # Border
	
	# Draw score text
	var text_pos = local_pos - text_size * 0.5
	draw_string(font, text_pos, score_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)


func _get_score_color(score: float) -> Color:
	"""Get background color based on score value"""
	if score >= HIGH_SCORE_THRESHOLD:
		return HIGH_SCORE_COLOR
	elif score >= MID_SCORE_THRESHOLD:
		return MID_SCORE_COLOR
	else:
		return LOW_SCORE_COLOR

func is_debug_visible() -> bool:
	"""Check if debug display is currently visible"""
	return debug_visible

func get_region_score(region_id: int) -> float:
	"""Get cached score for a specific region"""
	return current_player_scores.get(region_id, 0.0)

func get_detailed_scores(region_id: int) -> Dictionary:
	"""Get cached detailed scoring factors for a specific region"""
	return detailed_score_cache.get(region_id, {})

func print_top_regions(count: int = 10):
	"""Print top scoring regions to console for debugging"""
	if current_player_scores.is_empty():
		DebugLogger.log("AIPlanning", "No scores available")
		return
	
	var sorted_scores = []
	for region_id in current_player_scores:
		sorted_scores.append({
			"region_id": region_id,
			"score": current_player_scores[region_id]
		})
	
	sorted_scores.sort_custom(func(a, b): return a.score > b.score)
	
	DebugLogger.log("AIPlanning", "Top " + str(count) + " scoring regions:")
	for i in range(min(count, sorted_scores.size())):
		var entry = sorted_scores[i]
		DebugLogger.log("AIPlanning", "  Region " + str(entry.region_id) + ": " + str(entry.score) + " points")

## Utility Methods for External Access

func get_all_scores() -> Dictionary:
	"""Get all current region scores"""
	return current_player_scores.duplicate()

func refresh_scores(player_id: int):
	"""Refresh scores without toggling visibility"""
	if debug_visible:
		_update_scores_for_player(player_id)
		queue_redraw()

func refresh_scores_for_current_player():
	"""Refresh scores for the current player based on game state"""
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager != null and debug_visible:
		# Invalidate all region scores first (this forces recalculation)
		_invalidate_all_region_scores()
		
		var current_player_id = game_manager.get_current_player_id()
		_update_scores_for_player(current_player_id)
		queue_redraw()

func recalculate_scores_on_ownership_change(player_id: int):
	"""Recalculate scores when region ownership changes (affects frontier)"""
	if debug_visible and debug_mode == "army_target":
		DebugLogger.log("AIPlanning", "Recalculating scores due to ownership change for Player " + str(player_id))
		# Clear existing scores to force full recalculation
		current_player_scores.clear()
		detailed_score_cache.clear()
		
		# Recalculate with new frontier
		_update_scores_for_player(player_id)
		queue_redraw()

func _invalidate_all_region_scores():
	"""Invalidate stored AI scores in all regions (call when game state changes)"""
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node != null:
		for child in regions_node.get_children():
			if child is Region:
				var region = child as Region
				region.invalidate_ai_scores()
	DebugLogger.log("AIPlanning", "Invalidated all region AI scores")

func _get_all_owned_regions() -> Array[int]:
	"""Get ALL owned regions on the map (regardless of which player owns them)"""
	var owned_regions: Array[int] = []
	
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node != null:
		for child in regions_node.get_children():
			if child is Region:
				var region = child as Region
				var owner = region.get_region_owner()
				
				# Any region with an owner (> 0) is considered "owned"
				if owner > 0:
					owned_regions.append(region.get_region_id())
	
	return owned_regions

func clear_scores():
	"""Clear all cached scores and hide display"""
	debug_visible = false
	current_player_scores.clear()
	detailed_score_cache.clear()
	queue_redraw()

func _get_all_passable_regions() -> Array[int]:
	"""Get all passable regions on the map"""
	var passable_regions: Array[int] = []
	
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node != null:
		for child in regions_node.get_children():
			if child is Region:
				var region = child as Region
				# Skip mountains and ocean regions
				if (region.get_region_type() != RegionTypeEnum.Type.MOUNTAINS and 
					not region.is_ocean_region()):
					passable_regions.append(region.get_region_id())
	
	return passable_regions

func _find_player_reference_position(player_id: int) -> int:
	"""Find the castle position or any owned region for a player as reference point"""
	# First try to find the castle
	if region_scorer and region_scorer.region_manager:
		var castle_id = region_scorer.region_manager.get_castle_starting_position(player_id)
		if castle_id != -1:
			return castle_id
	
	# Fall back to any owned region
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node != null:
		for child in regions_node.get_children():
			if child is Region:
				var region = child as Region
				if region.get_region_owner() == player_id:
					return region.get_region_id()
	
	return -1  # No reference position found

func _calculate_distances_from_region(start_region_id: int) -> Dictionary:
	"""Calculate BFS distances from a starting region to all reachable regions"""
	var distances = {}
	distances[start_region_id] = 0
	
	var queue = [start_region_id]
	var visited = {start_region_id: true}
	
	while not queue.is_empty():
		var current_id = queue.pop_front()
		var current_distance = distances[current_id]
		
		# Get neighbors
		if region_scorer and region_scorer.region_manager:
			var neighbors = region_scorer.region_manager.get_neighbor_regions(current_id)
			for neighbor_id in neighbors:
				if not visited.has(neighbor_id):
					# Check if neighbor is passable
					var neighbor_region = map_generator.get_region_container_by_id(neighbor_id) as Region
					if neighbor_region and neighbor_region.is_passable():
						visited[neighbor_id] = true
						distances[neighbor_id] = current_distance + 1
						queue.append(neighbor_id)
	
	return distances

func _update_frontier_scores(player_id: int):
	"""Calculate and store frontier-based scores using canonical scoring API"""
	DebugLogger.log("AIPlanning", "Calculating frontier scores with movement costs for Player " + str(player_id) + "...")
	
	# Get all armies for this player
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager == null:
		DebugLogger.log("AIPlanning", "Error: GameManager not found")
		return
		
	var army_manager = game_manager.get_army_manager()
	if army_manager == null:
		DebugLogger.log("AIPlanning", "Error: ArmyManager not found") 
		return
		
	var player_armies = army_manager.get_player_armies(player_id)
	if player_armies.is_empty():
		DebugLogger.log("AIPlanning", "No armies found for Player " + str(player_id))
		return
	
	# Get frontier targets
	var frontier_targets = frontier_target_scorer.get_frontier_targets(player_id)
	if frontier_targets.is_empty():
		DebugLogger.log("AIPlanning", "No frontier targets found for Player " + str(player_id))
		return
	
	# Find the best army perspective using canonical scoring
	var best_army_data = _find_best_army_perspective_canonical(player_armies, frontier_targets, player_id)
	if best_army_data.is_empty():
		DebugLogger.log("AIPlanning", "No valid army perspective found")
		return
	
	current_army_perspective = best_army_data.army_name
	DebugLogger.log("AIPlanning", "Showing scores from perspective of Army: " + current_army_perspective)
	
	# Clear existing scores and show from best army's perspective
	current_player_scores.clear()
	detailed_score_cache.clear()
	
	# Store the scores from this army's perspective
	for target_data in best_army_data.target_scores:
		var region_id = target_data.region_id
		current_player_scores[region_id] = target_data.final_score
		detailed_score_cache[region_id] = target_data.factors
	
	DebugLogger.log("AIPlanning", "Stored frontier scores for " + str(best_army_data.target_scores.size()) + " regions from " + current_army_perspective + "'s perspective")

func _find_best_army_perspective_canonical(armies: Array, frontier_region_ids: Array[int], player_id: int) -> Dictionary:
	"""Find the army with the highest scoring target using canonical scoring API"""
	var best_army_data = {}
	var highest_score = -999.0
	
	for army in armies:
		if army == null or not is_instance_valid(army):
			continue
			
		# Skip armies with no movement points
		if army.get_movement_points() <= 0:
			continue
		
		# Calculate scores for all targets from this army's perspective
		var army_target_scores = []
		var army_highest_score = -999.0
		
		for region_id in frontier_region_ids:
			# Use canonical raw API to get final army score
			var score_result = army_target_scorer.get_final_army_score_raw(army, region_id)
			
			if not score_result.get("reachable", false):
				continue
			
			var final_raw = score_result.get("final_raw", 0.0)
			
			# Track this army's highest score
			if final_raw > army_highest_score:
				army_highest_score = final_raw
			
			# Store target score data with consistent format for display
			var target_score_data = {
				"region_id": region_id,
				"final_score": final_raw,
				"factors": {
					"base_raw_total": score_result.get("base_raw_total", 0.0),
					"random_modifier": score_result.get("random_modifier", 0.0),
					"movement_cost": score_result.get("mp_cost", 0.0),
					"final_raw": final_raw,
					"is_frontier": true,
					"strategic_0_10": score_result.get("strategic_0_10", 0.0),
					"population_0_10": score_result.get("population_0_10", 0.0),
					"level_0_10": score_result.get("level_0_10", 0.0),
					"resource_0_10": score_result.get("resource_0_10", 0.0),
					"resources_breakdown": score_result.get("resources_breakdown", {}),
					"army_name": army.name
				}
			}
			army_target_scores.append(target_score_data)
		
		# Check if this army has the highest scoring target so far
		if army_highest_score > highest_score:
			highest_score = army_highest_score
			best_army_data = {
				"army": army,
				"army_name": army.name,
				"highest_score": army_highest_score,
				"target_scores": army_target_scores
			}
	
	return best_army_data
