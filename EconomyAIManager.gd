extends RefCounted
class_name EconomyAIManager

# Foundation for AI economy planning. KISS: keep recruitment wired, stub others.

var region_manager: RegionManager
var army_manager: ArmyManager
var player_manager: PlayerManagerNode
var budget_manager: BudgetManager
var signals: Dictionary

func _init(_region_manager: RegionManager, _army_manager: ArmyManager, _player_manager: PlayerManagerNode) -> void:
	region_manager = _region_manager
	army_manager = _army_manager
	player_manager = _player_manager
	budget_manager = BudgetManager.new()

# Public entry: plan and allocate budgets for this player's turn.
# Currently only recruitment is executed; other categories are stubs.
func plan_turn(player_id: int, turn_number: int) -> Dictionary:
	print("\n=== AI ECONOMY TURN PLANNING (Player %d, Turn %d) ===" % [player_id, turn_number])
	
	# Snapshot signals once
	signals = _compute_signals(player_id, turn_number)

	# 1) If any armies at castles need recruitment → allocate budgets and stop (skip raise/builds)
	var armies_need = _find_recruitment_armies_at_castles(player_id, turn_number)
	if armies_need.size() > 0:
		print(">> PRIORITY: RECRUITMENT — ", armies_need.size(), " army(ies) at castles need units")
		var assigned1 = _allocate_recruitment(player_id, turn_number)
		print(">> RECRUITMENT: Assigned budgets to ", assigned1, " armies; skipping raise/builds this turn")
		print("=== END AI ECONOMY TURN PLANNING ===\n")
		return {"decision": "recruit_only", "recruit_assigned": assigned1, "signals": signals}

	# 2) Otherwise try to raise an army; if raised → allocate recruitment for it and stop
	print(">> PRIORITY: RAISE ARMY — no armies need recruitment")
	var raise_res = decide_and_raise_army(player_id, turn_number)
	if raise_res.get("raised", false):
		var assigned2 = _allocate_recruitment(player_id, turn_number)
		print(">> RAISE ARMY: Raised at region ", raise_res.get("region_id", -1), "; post-raise recruitment assigned to ", assigned2, " armies")
		print("=== END AI ECONOMY TURN PLANNING ===\n")
		return {"decision": "raised_then_recruit", "raise": raise_res, "recruit_assigned": assigned2, "signals": signals}
	else:
		print(">> RAISE ARMY: Skipped — ", raise_res.get("reason", "unknown"))

# 3) No recruitment needs and no raise → defer region economy to post-movement phase
	print(">> PRIORITY: NONE — deferring region economy to post-movement phase")
	print("=== END AI ECONOMY TURN PLANNING ===\n")
	return {"decision": "defer_region_economy", "signals": signals}

# Signals summarize state. Extended for raise army decisions.
func _compute_signals(player_id: int, turn_number: int) -> Dictionary:
	var owned_regions = region_manager.get_player_regions(player_id)
	var frontier_regions = region_manager.get_frontier_regions(player_id)
	var armies = army_manager.get_player_armies(player_id)
	var player = player_manager.get_player(player_id)
	
	# Calculate frontier pressure
	var frontier_pressure = 0.0
	if owned_regions.size() > 0:
		frontier_pressure = float(frontier_regions.size()) / float(owned_regions.size())
	
	# Calculate underpowered ratio
	var underpowered_count = 0
	var target_power = GameParameters.AI_TARGET_ARMY_POWER
	for army in armies:
		if army.get_army_power() < target_power:
			underpowered_count += 1
	var underpowered_ratio = 0.0
	if armies.size() > 0:
		underpowered_ratio = float(underpowered_count) / float(armies.size())
	
	# Calculate castle spacing (average distance between castles)
	var castle_regions = []
	for region_id in owned_regions:
		if region_manager.get_castle_level(region_id) >= 1:
			castle_regions.append(region_id)
	var castle_spacing = 0.0
	if castle_regions.size() > 1:
		# Simple proxy: use count ratio
		castle_spacing = float(owned_regions.size()) / float(castle_regions.size())
	
	# Calculate bank ratio (current gold vs a target reserve)
	var bank_ratio = 0.0
	var target_bank = 50  # Target gold reserve
	bank_ratio = min(1.0, float(player.get_resource_amount(ResourcesEnum.Type.GOLD)) / float(target_bank))
	
	# Calculate normalized power gap (simplified)
	var power_gap_norm = 0.0
	if armies.size() > 0:
		var avg_power = 0
		for army in armies:
			avg_power += army.get_army_power()
		avg_power = avg_power / armies.size()
		power_gap_norm = max(0.0, (target_power - avg_power) / target_power)
	
	print("Signals: ", {
		"frontier_pressure": frontier_pressure,
		"underpowered_ratio": underpowered_ratio,
		"castle_spacing": castle_spacing,
		"bank_ratio": bank_ratio,
		"power_gap_norm": power_gap_norm,
		"army_power_gap": 0.0,
		"resource_scarcity": {},
		"recruit_abundance": 0.0,
		"turn_index": float(turn_number)
	})	

	return {
		"frontier_pressure": frontier_pressure,
		"underpowered_ratio": underpowered_ratio,
		"castle_spacing": castle_spacing,
		"bank_ratio": bank_ratio,
		"power_gap_norm": power_gap_norm,
		"army_power_gap": 0.0,
		"resource_scarcity": {},
		"recruit_abundance": 0.0,
		"turn_index": float(turn_number)
	}

# Turn signals to weights per category. Stub: recruit always enabled.
func _score_categories(signals: Dictionary) -> Dictionary:
	# Kept for potential future bucket weighting; not used in priority flow
	return {"recruit": 1.0}

# Pick active categories (weight > 0). Deterministic order.
func _pick_categories(weights: Dictionary) -> Array:
	# Deprecated for current flow; present for API stability
	return ["recruit"]

# Delegate to existing BudgetManager to keep compatibility with recruitment flow.
func _allocate_recruitment(player_id: int, turn_number: int) -> int:
	var player = player_manager.get_player(player_id)
	var armies: Array[Army] = army_manager.get_player_armies(player_id)
	return budget_manager.allocate_recruitment_budgets(armies, player, region_manager, turn_number)

func _find_recruitment_armies_at_castles(player_id: int, turn_number: int) -> Array[Army]:
	var out: Array[Army] = []
	var armies = army_manager.get_player_armies(player_id)
	for a in armies:
		if a.needs_recruitment(turn_number):
			var r: Region = a.get_parent()
			var rid = r.get_region_id()
			if region_manager.get_castle_level(rid) >= 1:
				out.append(a)
	return out

# Main orchestrator for raise army decision
func decide_and_raise_army(player_id: int, turn_number: int) -> Dictionary:
	print("   Evaluating raise army decision...")
	var candidate = pick_best_raise_region(player_id)
	var player = player_manager.get_player(player_id)
	
	if candidate.is_empty():
		print("   Decision: NO - No valid castle regions with sufficient recruits")
		return {"raised": false, "reason": "no_candidate"}
	
	print("   Best candidate: Region %d (recruits: %d, score: %.1f)" % [candidate["region_id"], candidate["recruits_total"], candidate["score"]])
	
	var should_raise = should_raise_army(candidate, player)
	if should_raise:
		print("   Decision: YES - All constraints satisfied")
		var success = execute_raise_army(player_id, candidate["region_id"])
		if success:
			print("   Execution: SUCCESS - Army raised at region %d" % candidate["region_id"])
			return {"raised": true, "region_id": candidate["region_id"]}
		else:
			print("   Execution: FAILED - Could not deduct gold cost")
			return {"raised": false, "reason": "execution_failed"}
	else:
		return {"raised": false, "reason": "guards_failed"}

# Pick the best castle region to raise an army at
func pick_best_raise_region(player_id: int) -> Dictionary:
	print("   Searching for castle regions with sufficient recruits...")
	var owned_regions = region_manager.get_player_regions(player_id)
	var candidates = []
	var max_recruits_seen = 1
	var castles_checked = 0
	
	# Gather candidates
	for region_id in owned_regions:
		if region_manager.get_castle_level(region_id) < 1:
			continue
		castles_checked += 1
		
		# Calculate total recruits from region and neighbors
		var recruit_sources = region_manager.get_available_recruits_from_region_and_neighbors(region_id, player_id)
		var recruits_total = 0
		for source in recruit_sources:
			recruits_total += int(source.amount)
		
		print("   Castle %d: %d recruits (min: %d)" % [region_id, recruits_total, GameParameters.AI_MIN_RECRUITS_FOR_RAISING])
		
		if recruits_total < GameParameters.AI_MIN_RECRUITS_FOR_RAISING:
			continue
		
		max_recruits_seen = max(max_recruits_seen, recruits_total)
		
		# Check if this region is on the frontier
		var neighbors = region_manager.get_neighbor_regions(region_id)
		var frontier_near = 0
		var travel_hint = 0
		
		for neighbor_id in neighbors:
			var neighbor_owner = region_manager.get_region_owner(neighbor_id)
			if neighbor_owner != player_id:
				frontier_near = 1
				travel_hint = 1
				break
		
		# If not directly on frontier, check if any frontier exists (for travel hint)
		if travel_hint == 0:
			var frontier_regions = region_manager.get_frontier_regions(player_id)
			if frontier_regions.size() > 0:
				travel_hint = 1
		
		candidates.append({
			"region_id": region_id,
			"recruits_total": recruits_total,
			"frontier_near": frontier_near,
			"travel_hint": travel_hint
		})
	
	print("   Checked %d castles, found %d valid candidates" % [castles_checked, candidates.size()])
	
	if candidates.is_empty():
		return {}
	
	# Score candidates
	for candidate in candidates:
		var recruits_norm = float(candidate["recruits_total"]) / float(max_recruits_seen)
		var score = GameParameters.AI_CAND_W_RECRUITS * recruits_norm
		score += GameParameters.AI_CAND_W_FRONTIER_NEAR * candidate["frontier_near"]
		score += GameParameters.AI_CAND_W_TRAVEL * candidate["travel_hint"]
		candidate["score"] = score
		print("   Candidate %d: score %.1f (recruits: %.2f*%.1f, frontier: %d*%.1f, travel: %d*%.1f)" % [
			candidate["region_id"], score,
			recruits_norm, GameParameters.AI_CAND_W_RECRUITS,
			candidate["frontier_near"], GameParameters.AI_CAND_W_FRONTIER_NEAR,
			candidate["travel_hint"], GameParameters.AI_CAND_W_TRAVEL
		])
	
	# Pick highest score with deterministic tie-break
	candidates.sort_custom(func(a, b): 
		if abs(a["score"] - b["score"]) < 0.001:
			return a["region_id"] < b["region_id"]  # Tie-break by region_id
		return a["score"] > b["score"]
	)

	print("   Winner: Region %d (score: %.1f)" % [candidates[0]["region_id"], candidates[0]["score"]])
	
	return candidates[0]

# Decide whether to raise an army this turn
func should_raise_army(candidate: Dictionary, player: Player) -> bool:
	# Check if we have a valid candidate
	if candidate.is_empty():
		print("   Constraint: NO_CANDIDATE")
		return false
	
	# Check gold reserve constraint
	var current_gold = player.get_resource_amount(ResourcesEnum.Type.GOLD)
	var gold_after = current_gold - GameParameters.RAISE_ARMY_COST
	if gold_after < GameParameters.AI_RESERVE_GOLD_MIN:
		print("   Constraint: GOLD_RESERVE (current: %d, after: %d, min: %d)" % [current_gold, gold_after, GameParameters.AI_RESERVE_GOLD_MIN])
		return false
	
	# Check underpowered ratio constraint
	if signals["underpowered_ratio"] > GameParameters.AI_MAX_UNDERPOWERED_RATIO:
		print("   Constraint: UNDERPOWERED_RATIO (%.2f > %.2f)" % [signals["underpowered_ratio"], GameParameters.AI_MAX_UNDERPOWERED_RATIO])
		return false
	
	# Check if there's any frontier pressure
	if signals["frontier_pressure"] <= 0:
		print("   Constraint: NO_FRONTIER_PRESSURE (%.2f)" % signals["frontier_pressure"])
		return false
	
	# Estimate support load after raising
	var region_id = candidate["region_id"]
	var armies_at_castle = 0
	var armies = army_manager.get_player_armies(player.get_player_id())
	for army in armies:
		var army_region = army.get_parent()
		if army_region and army_region.get_region_id() == region_id:
			armies_at_castle += 1
	
	var recruits_per_army_after = float(candidate["recruits_total"]) / float(armies_at_castle + 1)
	if recruits_per_army_after < GameParameters.AI_MIN_RECRUITS_PER_ARMY_AFTER_RAISE:
		print("   Constraint: SUPPORT_LOAD (%.1f recruits/army < %d min)" % [recruits_per_army_after, GameParameters.AI_MIN_RECRUITS_PER_ARMY_AFTER_RAISE])
		return false
	
	# Calculate global score
	var g_score = GameParameters.AI_RAISE_W_FRONTIER * signals["frontier_pressure"]
	g_score += GameParameters.AI_RAISE_W_SPACING * signals["castle_spacing"]
	g_score += GameParameters.AI_RAISE_W_BANK * signals["bank_ratio"]
	g_score -= GameParameters.AI_RAISE_W_POWER_GAP * signals["power_gap_norm"]
	
	print("   Global score: %.1f (frontier: %.1f, spacing: %.1f, bank: %.1f, power_gap: -%.1f)" % [
		g_score, 
		GameParameters.AI_RAISE_W_FRONTIER * signals["frontier_pressure"],
		GameParameters.AI_RAISE_W_SPACING * signals["castle_spacing"],
		GameParameters.AI_RAISE_W_BANK * signals["bank_ratio"],
		GameParameters.AI_RAISE_W_POWER_GAP * signals["power_gap_norm"]
	])
	print("   Threshold: %.1f" % GameParameters.AI_RAISE_THRESHOLD)
	
	var decision = g_score >= GameParameters.AI_RAISE_THRESHOLD
	print("   Decision: %s" % ("RAISE" if decision else "DECLINE"))
	return decision

# Execute the army raising at the specified region
func execute_raise_army(player_id: int, region_id: int) -> bool:
	var player = player_manager.get_player(player_id)
	
	# Check and deduct cost
	if not player.remove_resources(ResourcesEnum.Type.GOLD, GameParameters.RAISE_ARMY_COST):
		return false
	
	# Get the region container
	var region_container = region_manager.map_generator.get_region_container_by_id(region_id)
	
	# Create the army
	army_manager.create_army(region_container, player_id, true)
	return true

# Post-movement economy pass: spend leftovers on region economy only
func plan_post_movement(player_id: int, turn_number: int) -> Dictionary:
	print("\n=== AI ECONOMY POST-MOVEMENT (Player %d, Turn %d) ===" % [player_id, turn_number])
	# Recompute snapshot (cheap) to base any simple heuristics on fresh state
	signals = _compute_signals(player_id, turn_number)
	var reg_actions = _process_region_economy(player_id, turn_number)
	print(">> REGION ECONOMY (post-move): ", reg_actions)
	print("=== END AI ECONOMY POST-MOVEMENT ===\n")
	return {"decision": "region_economy_post", "region_actions": reg_actions, "signals": signals}

func _process_region_economy(player_id: int, turn_number: int) -> Dictionary:
	# Placeholder: try build castle, then upgrade castle, then upgrade region (all no-ops for now)
	if _evaluate_build_castle(player_id, turn_number):
		return {"executed": [{"action": "build_castle"}]}
	if _evaluate_upgrade_castle(player_id, turn_number):
		return {"executed": [{"action": "upgrade_castle"}]}
	if _evaluate_upgrade_region(player_id, turn_number):
		return {"executed": [{"action": "upgrade_region"}]}
	return {"executed": [], "reason": "no_region_actions"}

func _evaluate_build_castle(player_id: int, turn_number: int) -> bool:
	# TODO: implement scoring; disabled for now
	return false

func _evaluate_upgrade_castle(player_id: int, turn_number: int) -> bool:
	# TODO: implement scoring; disabled for now
	return false

func _evaluate_upgrade_region(player_id: int, turn_number: int) -> bool:
	# TODO: implement scoring; disabled for now
	return false
