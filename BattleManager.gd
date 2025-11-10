extends RefCounted
class_name BattleManager

# ============================================================================
# BATTLE MANAGER
# ============================================================================
# 
# Purpose: Signal-based battle system with minimal state mutation
# 
# Core Responsibilities:
# - Battle UI coordination and state management
# - Signal-based battle flow communication
# - Battle result processing and cleanup
# - Army defeat handling and removal
# 
# Required Functions:
# - start_battle(): Initiate battle UI and set up context
# - handle_battle_modal_closed(): Process battle completion
# - apply_battle_losses(): Update armies and regions after battle
# - emit battle_finished(result): Signal completion to TurnController
# 
# Integration Points:
# - BattleModal: Battle UI and user interaction
# - RegionManager: Territory ownership (read-only)
# - ArmyManager: Army removal and tracking updates
# - TurnController: Battle completion signaling
# ============================================================================

# Battle completion signal
signal battle_started(attacker: Army, target_region_id: int)
signal battle_finished(result: String)
signal battle_finalization_complete

# Conquest tracking
var pending_conquest_army: Army = null
var pending_conquest_region: Region = null

# Pending participants for loss distribution
var _pending_attackers: Array[Army] = []
var _pending_defenders: Array[Army] = []
var _pending_garrison: ArmyComposition = null
var _pending_recruits_count: int = 0
var _pending_recruits_region: Region = null

# Manager references
var _region_manager: RegionManager
var _army_manager: ArmyManager
var _battle_modal: BattleModal
var _sound_manager: SoundManager
var _game_manager

# Track battle finalization queue so callers can await camera/tween completion
var _finalization_queue: Array = []
var _finalization_in_progress: bool = false

# Unified battle report storage (works for modal and background)
var _last_battle_report: BattleSimulator.BattleReport = null

# Store the fighting army for re-selection after battle (human players only)
var _fighting_army_for_reselection: Army = null

func _init(region_manager: RegionManager, army_manager: ArmyManager, battle_modal: BattleModal, sound_manager: SoundManager):
	_region_manager = region_manager
	_army_manager = army_manager
	_battle_modal = battle_modal
	_sound_manager = sound_manager

func set_game_manager(game_manager) -> void:
	"""Set GameManager reference for AI turn resumption"""
	_game_manager = game_manager

func start_battle(attacker: Army, target_region_id: int) -> void:
	"""Start a battle between attacker and target region"""
	var target_region = _region_manager.map_generator.get_region_container_by_id(target_region_id) as Region

	# Store the fighting army for potential re-selection after battle (only for human players)
	if _game_manager and _game_manager.is_player_human(attacker.get_player_id()):
		_fighting_army_for_reselection = attacker
		DebugLogger.log("BattleSystem", "[BattleManager] Stored army " + attacker.name + " for re-selection after battle. Current stored army: " + str(_fighting_army_for_reselection))
	else:
		DebugLogger.log("BattleSystem", "[BattleManager] Clearing stored army (AI player or no GameManager). Previous: " + str(_fighting_army_for_reselection))
		_fighting_army_for_reselection = null
		DebugLogger.log("BattleSystem", "[BattleManager] Not storing army for re-selection (AI player or no GameManager)")

	# Set up battle context
	set_pending_conquest(attacker, target_region)

	# Collect all battle participants (owner-based defenders under invariant)
	var owner_id := _region_manager.get_region_owner(target_region_id)
	var defender_armies: Array[Army] = []
	for child in target_region.get_children():
		if child is Army and child.get_player_id() == owner_id and child != attacker:
			defender_armies.append(child)
	var garrison := target_region.get_garrison()

	# AI defender pre-battle withdrawal check (retreat armies to owned neighbor; garrison stays)
	# Rules:
	# - Only when defender owner is AI
	# - Only if region has no military building (castle/outpost/etc.)
	# - Only if there exists at least one owned neighboring region
	# - Chance uses the same model as attacker withdrawal (power ratio based)
	if owner_id != -1 and _game_manager.is_player_computer(owner_id) and defender_armies.size() > 0:
		if target_region.get_castle_type() == CastleTypeEnum.Type.NONE:
			var owned_neighbors: Array = []
			for nid in _region_manager.get_neighbor_regions(target_region_id):
				if _region_manager.get_region_owner(nid) == owner_id:
					owned_neighbors.append(nid)
			if owned_neighbors.size() > 0:
				if _evaluate_ai_defender_withdrawal(attacker, defender_armies, garrison, target_region):
					var pick_id: int = owned_neighbors[randi() % owned_neighbors.size()]
					var dest_region := _region_manager.map_generator.get_region_container_by_id(pick_id) as Region
					# Move all defending armies to the chosen owned neighbor
					for d in defender_armies:
						if is_instance_valid(d):
							var start_global := d.global_position
							target_region.remove_child(d)
							dest_region.add_child(d)
							# Recompute stacked position and animate
							var target_local := _army_manager._compute_army_target_position(dest_region, d)
							_army_manager._apply_army_offsets_for_region(dest_region, d)
							var target_global: Vector2 = dest_region.to_global(target_local)
							d.global_position = start_global
							var tw := d.animate_move_to(target_global, GameParameters.MOVE_ANIMATION_DURATION, true)
							await tw.finished
					# Clear defender_armies for this battle context (they retreated)
					defender_armies.clear()
					DebugLogger.log("BattleAI", "Defender AI retreated armies from region " + str(target_region_id) + " before battle")
	
	# Persist the pending contributors so we can apply proportional losses later
	_pending_attackers = [attacker]
	_pending_defenders = defender_armies
	_pending_garrison = garrison
	_pending_recruits_count = target_region.get_base_available_recruits()
	_pending_recruits_region = target_region
	
	# Emit battle started signal
	emit_signal("battle_started", attacker, target_region_id)
	
	# AI background path: no modal, instant simulation when flag is on
	# Exception: if the defender is human (region owner or defending army), always show modal
	var attacker_is_ai: bool = _game_manager.is_player_computer(attacker.get_player_id())
	var defender_owner_id := _region_manager.get_region_owner(target_region_id)
	var defender_is_human: bool = false
	if defender_owner_id != -1 and _game_manager.is_player_human(defender_owner_id):
		defender_is_human = true
	else:
		for d in defender_armies:
			if _game_manager.is_player_human(d.get_player_id()):
				defender_is_human = true
				break
	var withdrawal_context := get_attacker_withdrawal_context()
	if _game_manager.debug_disable_battle_modal and attacker_is_ai and not defender_is_human:
		var atk_comps = _compositions_from_armies([attacker])
		var def_comps = _compositions_from_armies(defender_armies)
		# Include recruits in defenders for background simulation (parity with animated/human path)
		if _pending_recruits_count > 0:
			var recruits_comp = ArmyComposition.new()
			recruits_comp.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, _pending_recruits_count)
			def_comps.append(recruits_comp)
		var attacker_eff = attacker.get_efficiency()
		var defender_eff = 100
		var terrain_type = target_region.get_region_type()
		var castle_type = target_region.get_castle_type()
		var sim = BattleSimulator.new()
		var report = sim.simulate_battle(atk_comps, def_comps, garrison, attacker_eff, defender_eff, terrain_type, castle_type, withdrawal_context)
		# Compute wounded for background path so summary data is present
		report.attacker_wounded = Utils.compute_wounded(report.attacker_losses)
		report.defender_wounded = Utils.compute_wounded(report.defender_losses)
		_last_battle_report = report
		var winner = report.winner
		var result = "victory" if winner == "Attackers" else "withdrawal" if winner == "Withdrawal" else "defeat"
		# Finalize through GameManager and signal completion
		var result_data = {
			"result": result,
			"army": attacker,
			"target_region_id": target_region_id,
			"battle_report": report,
			"attacking_armies": _pending_attackers,
			"defending_armies": _pending_defenders,
			"defending_garrison": _pending_garrison,
			"defending_recruits_region": _pending_recruits_region,
			"defending_recruits_count": _pending_recruits_count
		}
		_queue_battle_finalization(result_data)
		_clear_pending_conquest_state()
		# Re-select fighting army for human players after instant battle
		call_deferred("_reselect_fighting_army_after_battle")
		call_deferred("_emit_battle_finished", result)
		DebugLogger.log("BattleSystem", "[BattleManager] Background battle done: " + result)
		return

	# Default: show interactive modal
	if _battle_modal:
		_battle_modal.show_battle(attacker, target_region)

	DebugLogger.log("BattleSystem", "[BattleManager] Battle started: " + str(attacker.name) + " vs " + str(target_region.get_region_name()))

func set_pending_conquest(army: Army, region: Region) -> void:
	"""Set or extend the pending conquest context for battle resolution (multi-army join)."""
	if pending_conquest_region != null and pending_conquest_region == region:
		var exists := false
		for a in _pending_attackers:
			if a == army:
				exists = true
				break
		if not exists:
			_pending_attackers.append(army)
	else:
		pending_conquest_region = region
		pending_conquest_army = army
		_pending_attackers = [army]
		_pending_defenders = []
		_pending_garrison = null
		_pending_recruits_count = 0
		_pending_recruits_region = null
		DebugLogger.log("BattleSystem", "[BattleManager] Set pending conquest: Army " + str(army.name) + " vs Region " + str(region.get_region_name()))

func _clear_pending_conquest_state() -> void:
	pending_conquest_army = null
	pending_conquest_region = null

func prepare_human_battle(attacker: Army, region: Region) -> void:
	"""Prepare defender participants for a human-initiated battle while keeping pending conquest logic."""
	# Ensure attacker is part of the pending attacker list (multi-army join)
	set_pending_conquest(attacker, region)
	# Collect defending armies based on region ownership (neutral has no armies per invariant)
	var owner_id := _region_manager.get_region_owner(region.get_region_id())
	var defenders: Array[Army] = []
	for child in region.get_children():
		if child is Army and child.get_player_id() == owner_id:
			defenders.append(child)
	_pending_defenders = defenders
	_pending_garrison = region.get_garrison()
	_pending_recruits_count = region.get_base_available_recruits()
	_pending_recruits_region = region


func handle_battle_modal_closed() -> void:
	"""Handle battle modal closure and complete conquest if needed"""
	DebugLogger.log("BattleSystem", "[BattleManager] Battle modal closed, checking for pending conquest...")
	
	if pending_conquest_army != null and pending_conquest_region != null:
		DebugLogger.log("BattleSystem", "[BattleManager] Found pending conquest, delegating to GameManager finalization...")
		
		# Get battle result
		var battle_result = _get_battle_result()
		
		# Prepare result data for GameManager finalization
		_last_battle_report = _battle_modal.battle_report
		var result_data = {
			"result": battle_result,
			"army": pending_conquest_army,
			"target_region_id": pending_conquest_region.get_region_id(),
			"battle_report": _last_battle_report,
			"attacking_armies": _pending_attackers,
			"defending_armies": _pending_defenders,
			"defending_garrison": _pending_garrison,
			"defending_recruits_region": _pending_recruits_region,
			"defending_recruits_count": _pending_recruits_count
		}
		
		# Use GameManager's unified finalization
		if _game_manager:
			_queue_battle_finalization(result_data)
		
		# Clear pending conquest
		_clear_pending_conquest_state()
	else:
		DebugLogger.log("BattleSystem", "[BattleManager] No pending conquest found")
	
	var result = _get_battle_result()

	# Re-select fighting army for human players after battle (delayed to ensure modal is fully closed)
	if result != "withdrawal":
		DebugLogger.log("BattleSystem", "[BattleManager] About to call deferred re-selection. Current stored army: " + str(_fighting_army_for_reselection))
		call_deferred("_reselect_fighting_army_after_battle")
	else:
		DebugLogger.log("BattleSystem", "[BattleManager] Skipping re-selection after withdrawal")
		_fighting_army_for_reselection = null

	# Emit battle finished signal
	emit_signal("battle_finished", result)
	DebugLogger.log("BattleSystem", "[BattleManager] Battle finished with result: " + str(result))

func _apply_battle_losses() -> void:
	"""Apply battle losses from the latest battle report to armies and region"""
	var report := _last_battle_report
	if report == null and _battle_modal != null:
		report = _battle_modal.battle_report
	if report == null:
		DebugLogger.log("BattleSystem", "[BattleManager] No battle report available")
		return
	
	# New rule:
	# - Losing side takes 100% losses (destroyed) → no need to calculate for losing side
	# - Apply calculated losses only to winning side, or to both sides when withdrawal
	if report.winner == "Attackers":
		# Destroy defenders entirely (armies + garrison + recruits)
		_destroy_defender_side()
		# Apply attackers' calculated losses
		_apply_losses_proportionally(report.attacker_losses, _pending_attackers, null)
	elif report.winner == "Withdrawal":
		# Apply both sides' calculated losses
		_apply_losses_proportionally(report.attacker_losses, _pending_attackers, null)
		_apply_losses_proportionally_with_recruits(report.defender_losses, _pending_defenders, _pending_garrison, _pending_recruits_region, _pending_recruits_count)
	else:
		# Defenders win: destroy attackers entirely; apply defender losses
		_destroy_attacker_side()
		_apply_losses_proportionally_with_recruits(report.defender_losses, _pending_defenders, _pending_garrison, _pending_recruits_region, _pending_recruits_count)

	_update_enemy_power_tracking()


	# Cleanup defeated armies ONLY among battle participants
	for a in _pending_attackers:
		if a.get_total_soldiers() <= 0:
			_handle_battle_defeat(a)
	for d in _pending_defenders:
		if d.get_total_soldiers() <= 0:
			_handle_battle_defeat(d)
	
	_last_battle_report = null

func _destroy_defender_side() -> void:
	# Zero-out all defender armies
	for d in _pending_defenders:
		if is_instance_valid(d):
			for unit_type in SoldierTypeEnum.get_all_types():
				var cnt := d.get_soldier_count(unit_type)
				if cnt > 0:
					d.remove_soldiers(unit_type, cnt)
	# Zero-out garrison
	if _pending_garrison != null:
		for unit_type in SoldierTypeEnum.get_all_types():
			var gc := _pending_garrison.get_soldier_count(unit_type)
			if gc > 0:
				_pending_garrison.remove_soldiers(unit_type, gc)
	# Zero-out recruits (using reduce_recruits for battle losses)
	if _pending_recruits_region != null:
		var base_avail: int = _pending_recruits_region.get_base_available_recruits()
		if base_avail > 0:
			_pending_recruits_region.reduce_recruits(base_avail)

func _destroy_attacker_side() -> void:
	# Zero-out all attacking armies
	for a in _pending_attackers:
		if is_instance_valid(a):
			for unit_type in SoldierTypeEnum.get_all_types():
				var cnt := a.get_soldier_count(unit_type)
				if cnt > 0:
					a.remove_soldiers(unit_type, cnt)

func _get_battle_result() -> String:
	"""Get the battle result: 'victory', 'withdrawal', or 'defeat'"""
	if _battle_modal == null or _battle_modal.battle_report == null:
		return "defeat"
	
	var battle_report = _battle_modal.battle_report
	if battle_report.winner == "Attackers":
		return "victory"
	elif battle_report.winner == "Withdrawal":
		return "withdrawal"
	else:
		return "defeat"

func _handle_army_withdrawal(withdrawing_army: Army) -> void:
	"""Handle when an army withdraws from battle"""
	if withdrawing_army == null or not is_instance_valid(withdrawing_army):
		return
	
	DebugLogger.log("BattleSystem", "[BattleManager] Army " + str(withdrawing_army.name) + " withdrew from battle")
	
	# Reduce efficiency by 5 for withdrawal (in addition to movement penalty already applied)
	withdrawing_army.reduce_efficiency(5)
	DebugLogger.log("BattleSystem", "[BattleManager] Reduced " + str(withdrawing_army.name) + " efficiency to " + str(withdrawing_army.get_efficiency()) + "% after withdrawal")
	
	# Move army back to previous region using ArmyManager
	if _army_manager != null:
		_army_manager.retreat_army_to_previous_region(withdrawing_army)
	else:
		DebugLogger.log("BattleSystem", "[BattleManager] Warning: ArmyManager not available for army retreat")

func _handle_battle_defeat(defeated_army: Army) -> void:
	"""Handle when an army is defeated in battle"""
	if defeated_army == null or not is_instance_valid(defeated_army):
		return
	
	DebugLogger.log("BattleSystem", "[BattleManager] Army " + str(defeated_army.name) + " was defeated in battle")
	
	# Get the army's parent (region container)
	var parent_region = defeated_army.get_parent() as Region
	if parent_region == null:
		DebugLogger.log("BattleSystem", "[BattleManager] Warning: Defeated army has no parent region")
		return
	
	# Check if army still has soldiers
	if defeated_army.get_total_soldiers() > 0:
		DebugLogger.log("BattleSystem", "[BattleManager] Army " + str(defeated_army.name) + " survived with " + str(defeated_army.get_total_soldiers()) + " soldiers")
		
		# Find a random owned neighboring region to retreat to
		var army_owner = defeated_army.get_player_id()
		var current_region_id = parent_region.get_region_id()
		var neighbors = _region_manager.get_neighbor_regions(current_region_id)
		
		# Filter for owned neighbors
		var owned_neighbors: Array = []
		for neighbor_id in neighbors:
			if _region_manager.get_region_owner(neighbor_id) == army_owner:
				owned_neighbors.append(neighbor_id)
		
		if owned_neighbors.size() > 0:
			# Pick a random owned neighbor for retreat
			var retreat_region_id = owned_neighbors[randi() % owned_neighbors.size()]
			var retreat_region = _region_manager.map_generator.get_region_container_by_id(retreat_region_id) as Region
			
			if retreat_region != null:
				DebugLogger.log("BattleSystem", "[BattleManager] Army " + str(defeated_army.name) + " retreating to " + str(retreat_region.get_region_name()))
				
				# Move army to retreat region
				parent_region.remove_child(defeated_army)
				retreat_region.add_child(defeated_army)
				
				# Update army position to retreat region center
				var polygon = retreat_region.get_node_or_null("Polygon") as Polygon2D
				if polygon != null:
					var center_meta = polygon.get_meta("center")
					if center_meta != null:
						var center = center_meta as Vector2
						# Calculate appropriate offset based on region contents
						var offset = Vector2.ZERO
						if _army_manager != null:
							offset = _army_manager._get_army_position_offset(retreat_region)
						defeated_army.position = center + offset
				
				DebugLogger.log("BattleSystem", "[BattleManager] Army successfully retreated to " + str(retreat_region.get_region_name()))
				return
			else:
				DebugLogger.log("BattleSystem", "[BattleManager] Warning: Could not find retreat region container")
		else:
			DebugLogger.log("BattleSystem", "[BattleManager] No owned neighboring regions available for retreat")
	else:
		DebugLogger.log("BattleSystem", "[BattleManager] Army " + str(defeated_army.name) + " has no soldiers left after healing")
	
	# If we reach here, army either has no soldiers or couldn't retreat - remove it
	DebugLogger.log("BattleSystem", "[BattleManager] Removing army " + str(defeated_army.name) + " from the map")
	
	# Remove the army from the scene
	if parent_region != null:
		parent_region.remove_child(defeated_army)
	
	# Remove the army from army manager tracking
	if _army_manager != null:
		_army_manager.remove_army_from_tracking(defeated_army)
	
	# Free the army node
	defeated_army.queue_free()
	
	DebugLogger.log("BattleSystem", "[BattleManager] Defeated army removed from map")

func _check_ai_turn_resumption(army_player_id: int) -> void:
	"""Check if an AI player needs to resume their turn after battle completion"""
	# NOTE: This function is no longer needed since AI turns now properly wait for battles
	# to complete using async/await in _execute_army_move(). The battle completion is 
	# handled automatically within the AI turn processing flow.
	DebugLogger.log("BattleSystem", "[BattleManager] Battle completed for Player %d - AI turn will continue automatically" % army_player_id)

# --- Collect all defending armies owned by the region owner in the region (excluding the attacker if already reparented) ---
func _collect_defender_armies(region: Region, attacker: Army) -> Array[Army]:
	"""Collect all armies in the region that belong to enemy players (not the attacker's owner)."""
	var list: Array[Army] = []
	var attacker_owner := attacker.get_player_id()
	for child in region.get_children():
		if child is Army and child != attacker and child.get_player_id() != attacker_owner:
			list.append(child)
	return list

# --- Convert contributors into ArmyComposition array for the simulator ---
func _compositions_from_armies(armies: Array[Army]) -> Array:
	var comps: Array = []
	for a in armies:
		comps.append(a.get_composition())
	return comps

func _update_enemy_power_tracking() -> void:
	if _game_manager == null:
		return
	for attacker in _pending_attackers:
		if attacker != null and is_instance_valid(attacker):
			var observer_id := attacker.get_player_id()
			_record_enemy_observations(observer_id, _pending_defenders)
	for defender in _pending_defenders:
		if defender != null and is_instance_valid(defender):
			var observer_id := defender.get_player_id()
			_record_enemy_observations(observer_id, _pending_attackers)
	if _pending_garrison != null and _pending_recruits_region != null:
		var garrison_power := _calculate_composition_power(_pending_garrison)
		var region_id := _pending_recruits_region.get_region_id()
		for attacker in _pending_attackers:
			if attacker != null and is_instance_valid(attacker):
				_game_manager.record_enemy_garrison(attacker.get_player_id(), region_id, garrison_power)

func _record_enemy_observations(observer_id: int, enemies: Array) -> void:
	if enemies.is_empty():
		return
	for enemy in enemies:
		if enemy == null:
			continue
		var army_enemy := enemy as Army
		if army_enemy == null:
			continue
		if not is_instance_valid(army_enemy):
			continue
		_game_manager.record_enemy_army_power(observer_id, army_enemy)

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

# --- Expose compositions for battle modal ---
func get_pending_attacking_compositions() -> Array:
	return _compositions_from_armies(_pending_attackers)

func get_pending_defending_compositions() -> Array:
	return _compositions_from_armies(_pending_defenders)

func get_pending_garrison() -> ArmyComposition:
	return _pending_garrison

func get_last_battle_report() -> BattleSimulator.BattleReport:
	return _last_battle_report
	
func await_finalize_complete() -> void:
	if not _finalization_in_progress:
		return
	await battle_finalization_complete

func _queue_battle_finalization(result_data: Dictionary) -> void:
	_finalization_queue.append(result_data)
	if _finalization_in_progress:
		return
	_process_finalization_queue()

func _process_finalization_queue() -> void:
	if _finalization_queue.is_empty():
		if _finalization_in_progress:
			_finalization_in_progress = false
			emit_signal("battle_finalization_complete")
		return
	_finalization_in_progress = true
	var next_data: Dictionary = _finalization_queue.pop_front()
	call_deferred("_run_battle_finalization_async", next_data)

func _run_battle_finalization_async(result_data: Dictionary) -> void:
	if _game_manager == null:
		_process_finalization_queue()
		return
	await _game_manager.finalize_battle_result(result_data)
	_process_finalization_queue()

func _emit_battle_finished(result: String) -> void:
	emit_signal("battle_finished", result)

func _reselect_fighting_army_after_battle() -> void:
	"""Re-select the fighting army and show movement arrows after battle completion (human players only)"""
	DebugLogger.log("BattleSystem", "[BattleManager] _reselect_fighting_army_after_battle called")
	
	# Wait a frame to ensure the modal is fully closed and UI state is updated
	await Engine.get_main_loop().process_frame
	
	if _fighting_army_for_reselection == null:
		DebugLogger.log("BattleSystem", "[BattleManager] No army stored for re-selection")
		return
	
	DebugLogger.log("BattleSystem", "[BattleManager] Found stored army: " + _fighting_army_for_reselection.name)
	
	# Check if army is still valid and alive after battle
	if not is_instance_valid(_fighting_army_for_reselection):
		DebugLogger.log("BattleSystem", "[BattleManager] Stored army is no longer valid")
		_fighting_army_for_reselection = null
		return
	
	if _fighting_army_for_reselection.get_total_soldiers() <= 0:
		DebugLogger.log("BattleSystem", "[BattleManager] Stored army has no soldiers left")
		_fighting_army_for_reselection = null
		return
	
	# Only re-select for human players
	if _game_manager and not _game_manager.is_player_human(_fighting_army_for_reselection.get_player_id()):
		DebugLogger.log("BattleSystem", "[BattleManager] Army belongs to AI player, not re-selecting")
		_fighting_army_for_reselection = null
		return
	
	# Get the current region container where the army is located
	var current_region_container = _fighting_army_for_reselection.get_parent()
	if current_region_container == null:
		DebugLogger.log("BattleSystem", "[BattleManager] Army has no parent region container")
		_fighting_army_for_reselection = null
		return
	
	DebugLogger.log("BattleSystem", "[BattleManager] Army is in region: " + current_region_container.name)
	
	# Re-select the army and show arrows and modals (same as clicking "move army")
	if _army_manager != null:
		DebugLogger.log("BattleSystem", "[BattleManager] Re-selecting army with full functionality for continued movement")
		# Use proper select_army method to trigger the same action as clicking "move army"
		var current_player_id = _game_manager.get_current_player_id() if _game_manager else -1
		_army_manager.select_army(_fighting_army_for_reselection, current_region_container, current_player_id)
		var ui_manager: UIManager = _battle_modal.get_parent().get_node("UIManager") as UIManager
		ui_manager.set_modal_active(false)
		
		DebugLogger.log("BattleSystem", "[BattleManager] Re-selected army " + _fighting_army_for_reselection.name + " after battle completion (with modals)")
	else:
		DebugLogger.log("BattleSystem", "[BattleManager] ArmyManager is null, cannot re-select army")
	
	# Clear the stored army reference
	_fighting_army_for_reselection = null

func get_attacker_withdrawal_context() -> Dictionary:
	"""Expose attacker withdrawal evaluation context for simulators/UI."""
	return {
		"check_callable": Callable(self, "evaluate_ai_attacker_withdrawal"),
		"recruits_peasants": _pending_recruits_count
	}

# --- AI withdrawal evaluation (attacker-side only) ---
func evaluate_ai_attacker_withdrawal(current_atk: Dictionary = {}, current_def: Dictionary = {}, garrison: ArmyComposition = null, recruits_peasants: int = 0) -> bool:
	"""Check if the attacking AI should withdraw based on power ratio.
	Uses dynamic round compositions when provided; otherwise falls back to army nodes.
	Defender power subtracts garrison and recruit peasants."""
	if _pending_attackers.is_empty():
		return false
	if _game_manager == null:
		return false
	# Only attackers can withdraw with current simulator
	var attacker_owner := _pending_attackers[0].get_player_id()
	if not _game_manager.is_player_computer(attacker_owner):
		return false
	var atk_power := 0
	var def_power := 0
	if current_atk.is_empty() or current_def.is_empty():
		for a in _pending_attackers:
			if is_instance_valid(a):
				atk_power += a.get_army_power()
		for d in _pending_defenders:
			if is_instance_valid(d):
				def_power += d.get_army_power()
	else:
		# Compute from compositions
		for ut in current_atk.keys():
			var qty: int = int(current_atk[ut])
			if qty > 0:
				atk_power += GameParameters.get_unit_stat(ut, "power") * qty
		# Start with total defenders
		var def_dict := current_def.duplicate()
		# Subtract garrison
		if garrison != null:
			for ut in SoldierTypeEnum.get_all_types():
				var g := garrison.get_soldier_count(ut)
				if g > 0:
					var cur := int(def_dict.get(ut, 0))
					def_dict[ut] = max(0, cur - g)
		# Subtract recruits (peasants only)
		if recruits_peasants > 0:
			var curp := int(def_dict.get(SoldierTypeEnum.Type.PEASANTS, 0))
			var remove: int = min(curp, recruits_peasants)
			def_dict[SoldierTypeEnum.Type.PEASANTS] = max(0, curp - remove)
		for ut in def_dict.keys():
			var qtyd: int = int(def_dict[ut])
			if qtyd > 0:
				def_power += GameParameters.get_unit_stat(ut, "power") * qtyd
	if def_power <= 0:
		return false
	# Check threshold
	var ratio := float(atk_power) / float(def_power)
	if ratio > GameParameters.AI_WITHDRAW_POWER_THRESHOLD:
		DebugLogger.log("BattleAI", "AI withdraw check (attacker): atk=" + str(atk_power) + ", def=" + str(def_power) + ", ratio=" + str(snappedf(ratio, 0.001)) + ", threshold=" + str(GameParameters.AI_WITHDRAW_POWER_THRESHOLD) + " -> no attempt")
		return false
	# Chance = (def - atk)/def = 1 - ratio
	var chance: float = clampf(1.0 - ratio, 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll := rng.randf()
	var will_withdraw := roll < chance
	DebugLogger.log("BattleAI", "AI withdraw attempt (attacker): atk=" + str(atk_power) + ", def=" + str(def_power) + ", ratio=" + str(snappedf(ratio, 0.001)) + ", chance=" + str(snappedf(chance, 0.001)) + ", roll=" + str(snappedf(roll, 0.001)) + ", result=" + ("WITHDRAW" if will_withdraw else "CONTINUE"))
	return will_withdraw

# --- AI withdrawal evaluation (defender-side, pre-battle) ---
func _evaluate_ai_defender_withdrawal(attacker: Army, defender_armies: Array[Army], garrison: ArmyComposition, region: Region) -> bool:
	"""Check if the defending AI should retreat armies before the battle starts.
	Uses attacker vs defending armies power (excludes garrison)."""
	var atk_power := 0
	var def_power := 0
	# Attacker power
	if is_instance_valid(attacker):
		atk_power = attacker.get_army_power()
	# Defending armies power (exclude garrison)
	for d in defender_armies:
		if is_instance_valid(d):
			def_power += d.get_army_power()
	if def_power <= 0:
		return false
	var ratio := float(def_power) / float(atk_power if atk_power > 0 else 1)
	# Mirror attacker logic: retreat attempt when outpowered (own/enemy <= threshold) → here (def/atk <= threshold)
	if ratio > GameParameters.AI_WITHDRAW_POWER_THRESHOLD:
		DebugLogger.log("BattleAI", "AI withdraw check (defender): def=" + str(def_power) + ", atk=" + str(atk_power) + ", ratio=" + str(snappedf(ratio, 0.001)) + ", threshold=" + str(GameParameters.AI_WITHDRAW_POWER_THRESHOLD) + " -> no attempt")
		return false
	# Chance = (atk - def)/atk = 1 - (def/atk) with atk>0
	var chance: float = 1.0 - min(1.0, float(def_power) / float(atk_power if atk_power > 0 else 1))
	chance = clampf(chance, 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll := rng.randf()
	var will_withdraw := roll < chance
	DebugLogger.log("BattleAI", "AI withdraw attempt (defender): def=" + str(def_power) + ", atk=" + str(atk_power) + ", ratio=" + str(snappedf(ratio, 0.001)) + ", chance=" + str(snappedf(chance, 0.001)) + ", roll=" + str(snappedf(roll, 0.001)) + ", result=" + ("RETREAT" if will_withdraw else "HOLD"))
	return will_withdraw

# --- Proportional loss distribution across an array of Army nodes (and optional garrison) ---
func _apply_losses_proportionally(losses: Dictionary, armies: Array[Army], garrison: ArmyComposition) -> void:
	for unit_type in losses.keys():
		var total_loss: int = int(losses[unit_type])
		if total_loss <= 0:
			continue
		
		# 1) Measure available per contributor
		var avail: Array = []  # [{army: Army, count: int}]  (or {garrison: true, comp: ArmyComposition, count:int})
		var total_available := 0
		
		for a in armies:
			if a == null or not is_instance_valid(a):
				continue
			var cnt := a.get_composition().get_soldier_count(unit_type)
			if cnt > 0:
				avail.append({"army": a, "count": cnt})
				total_available += cnt
		
		var garrison_entry := {}
		if garrison != null:
			var g_cnt := garrison.get_soldier_count(unit_type)
			if g_cnt > 0:
				garrison_entry = {"garrison": true, "comp": garrison, "count": g_cnt}
				avail.append(garrison_entry)
				total_available += g_cnt
		
		if total_available <= 0:
			continue  # nothing to remove
		
		# 2) Proportional shares (floor) + largest remainder
		var allocations: Array = [] # [{ref: Army|ArmyComposition, take: int, frac: float, cap:int}]
		var taken_sum := 0
		
		for entry in avail:
			var share := float(total_loss) * float(entry["count"]) / float(total_available)
			var take := int(floor(share))
			var frac := share - float(take)
			allocations.append({
				"entry": entry,
				"take": take,
				"frac": frac
			})
			taken_sum += take
		
		# Distribute remaining by largest remainder, respecting caps
		var remainder := total_loss - taken_sum
		allocations.sort_custom(func(a, b): return a["frac"] > b["frac"])
		var i := 0
		while remainder > 0 and i < allocations.size():
			var entry: Dictionary = allocations[i]["entry"]
			var cap: int = entry["count"] - allocations[i]["take"]
			if cap > 0:
				allocations[i]["take"] += 1
				remainder -= 1
			i += 1
			if i >= allocations.size() and remainder > 0:
				# one more pass if still remainder (rare when caps bind)
				i = 0
		
		# 3) Apply (never exceed actual counts)
		for alloc in allocations:
			var entry: Dictionary = alloc["entry"]
			var take: int = min(alloc["take"], entry["count"])
			if take <= 0: 
				continue
			if entry.has("garrison"):
				entry["comp"].remove_soldiers(unit_type, take)
			else:
				var army := entry["army"] as Army
				army.remove_soldiers(unit_type, take)

func _apply_losses_proportionally_with_recruits(losses: Dictionary, armies: Array[Army], garrison: ArmyComposition, recruits_region: Region, recruits_count: int) -> void:
	for unit_type in losses.keys():
		var total_loss: int = int(losses[unit_type])
		if total_loss <= 0:
			continue
		var avail: Array = []
		var total_available := 0
		for a in armies:
			if not is_instance_valid(a):
				continue
			var c := a.get_composition().get_soldier_count(unit_type)
			if c > 0:
				avail.append({"army": a, "count": c})
				total_available += c
		if garrison != null:
			var gc := garrison.get_soldier_count(unit_type)
			if gc > 0:
				avail.append({"garrison": true, "comp": garrison, "count": gc})
				total_available += gc
		if unit_type == SoldierTypeEnum.Type.PEASANTS and recruits_count > 0 and recruits_region != null:
			avail.append({"recruits": true, "region": recruits_region, "count": recruits_count})
			total_available += recruits_count
		if total_available <= 0:
			continue
		var allocations: Array = []
		var taken_sum := 0
		for entry in avail:
			var share := float(total_loss) * float(entry["count"]) / float(total_available)
			var take := int(floor(share))
			var frac := share - float(take)
			allocations.append({"entry": entry, "take": take, "frac": frac})
			taken_sum += take
		var remainder := total_loss - taken_sum
		allocations.sort_custom(func(a, b): return a["frac"] > b["frac"])
		var i := 0
		while remainder > 0 and i < allocations.size():
			var entry: Dictionary = allocations[i]["entry"]
			var cap: int = entry["count"] - allocations[i]["take"]
			if cap > 0:
				allocations[i]["take"] += 1
				remainder -= 1
			i += 1
			if i >= allocations.size() and remainder > 0:
				i = 0
		for alloc in allocations:
			var entry: Dictionary = alloc["entry"]
			var take: int = min(alloc["take"], entry["count"])
			if take <= 0:
				continue
			if entry.has("garrison"):
				entry["comp"].remove_soldiers(unit_type, take)
			elif entry.has("recruits"):
				# Use reduce_recruits for battle losses (not hire_recruits)
				entry["region"].reduce_recruits(take)
			else:
				var army := entry["army"] as Army
				army.remove_soldiers(unit_type, take)
