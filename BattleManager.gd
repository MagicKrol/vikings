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

# Conquest tracking
var pending_conquest_army: Army = null
var pending_conquest_region: Region = null

# Pending participants for loss distribution
var _pending_attackers: Array[Army] = []
var _pending_defenders: Array[Army] = []
var _pending_garrison: ArmyComposition = null

# Manager references
var _region_manager: RegionManager
var _army_manager: ArmyManager
var _battle_modal: BattleModal
var _sound_manager: SoundManager
var _game_manager: GameManager

func _init(region_manager: RegionManager, army_manager: ArmyManager, battle_modal: BattleModal, sound_manager: SoundManager):
	_region_manager = region_manager
	_army_manager = army_manager
	_battle_modal = battle_modal
	_sound_manager = sound_manager

func set_game_manager(game_manager: GameManager) -> void:
	"""Set GameManager reference for AI turn resumption"""
	_game_manager = game_manager

func start_battle(attacker: Army, target_region_id: int) -> void:
	"""Start a battle between attacker and target region"""
	var target_region = _region_manager.map_generator.get_region_container_by_id(target_region_id) as Region
	if not target_region:
		print("[BattleManager] Error: Target region not found")
		return
	
	# Set up battle context
	set_pending_conquest(attacker, target_region)
	
	# Collect all battle participants
	var owner_id := _region_manager.get_region_owner(target_region_id)
	var defender_armies := _collect_defender_armies(target_region, owner_id, attacker)
	var garrison := target_region.get_garrison()
	
	# Persist the pending contributors so we can apply proportional losses later
	_pending_attackers = [attacker]
	_pending_defenders = defender_armies
	_pending_garrison = garrison
	
	# Emit battle started signal
	emit_signal("battle_started", attacker, target_region_id)
	
	# Show battle modal
	if _battle_modal:
		_battle_modal.show_battle(attacker, target_region)
	
	print("[BattleManager] Battle started: ", attacker.name, " vs ", target_region.get_region_name())

func set_pending_conquest(army: Army, region: Region) -> void:
	"""Set the pending conquest context for battle resolution"""
	pending_conquest_army = army
	pending_conquest_region = region
	print("[BattleManager] Set pending conquest: Army ", army.name, " vs Region ", region.get_region_name())


func handle_battle_modal_closed() -> void:
	"""Handle battle modal closure and complete conquest if needed"""
	print("[BattleManager] Battle modal closed, checking for pending conquest...")
	
	# Store the army player ID to check if AI needs to resume
	var army_player_id = -1
	if pending_conquest_army != null and is_instance_valid(pending_conquest_army):
		army_player_id = pending_conquest_army.get_player_id()
	
	if pending_conquest_army != null and pending_conquest_region != null:
		print("[BattleManager] Found pending conquest, applying battle losses and completing...")
		
		# Apply battle losses from the battle modal
		_apply_battle_losses()
		
		# Handle battle outcome
		var battle_result = _get_battle_result()
		
		if battle_result == "victory":
			# Attackers won - only reduce efficiency, TurnController handles conquest
			if pending_conquest_army != null and is_instance_valid(pending_conquest_army):
				pending_conquest_army.reduce_efficiency(5)
				print("[BattleManager] Reduced ", pending_conquest_army.name, " efficiency to ", pending_conquest_army.get_efficiency(), "% after battle")
		elif battle_result == "withdrawal":
			# Army withdrew - move back to previous region and reduce efficiency
			_handle_army_withdrawal(pending_conquest_army)
		else:
			# Attackers lost - remove the army from the map
			_handle_battle_defeat(pending_conquest_army)
			# No efficiency reduction needed for defeated armies (they're removed)
		
		# Clear pending conquest
		pending_conquest_army = null
		pending_conquest_region = null
	else:
		print("[BattleManager] No pending conquest found")
	
	# Emit battle finished signal for TurnController
	var result = _get_battle_result()
	emit_signal("battle_finished", result)
	print("[BattleManager] Battle finished with result: ", result)

func _apply_battle_losses() -> void:
	"""Apply battle losses from the battle modal to armies and region"""
	if _battle_modal == null or _battle_modal.battle_report == null:
		print("[BattleManager] No battle report available")
		return
	var report := _battle_modal.battle_report
	
	# Attackers' losses across all attacking armies (currently just the attacker)
	_apply_losses_proportionally(report.attacker_losses, _pending_attackers, null)
	
	# Defenders' losses across all defending armies + garrison
	_apply_losses_proportionally(report.defender_losses, _pending_defenders, _pending_garrison)
	
	# Cleanup any destroyed armies
	if _army_manager != null:
		_army_manager.remove_destroyed_armies()

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
	
	print("[BattleManager] Army ", withdrawing_army.name, " withdrew from battle")
	
	# Reduce efficiency by 5 for withdrawal (in addition to movement penalty already applied)
	withdrawing_army.reduce_efficiency(5)
	print("[BattleManager] Reduced ", withdrawing_army.name, " efficiency to ", withdrawing_army.get_efficiency(), "% after withdrawal")
	
	# Move army back to previous region using ArmyManager
	if _army_manager != null:
		_army_manager.retreat_army_to_previous_region(withdrawing_army)
	else:
		print("[BattleManager] Warning: ArmyManager not available for army retreat")

func _handle_battle_defeat(defeated_army: Army) -> void:
	"""Handle when an army is defeated in battle"""
	if defeated_army == null or not is_instance_valid(defeated_army):
		return
	
	print("[BattleManager] Army ", defeated_army.name, " was defeated and will be removed from the map")
	
	# Get the army's parent (region container)
	var parent_region = defeated_army.get_parent()
	
	# Remove the army from the scene
	if parent_region != null:
		parent_region.remove_child(defeated_army)
	
	# Remove the army from army manager tracking
	if _army_manager != null:
		_army_manager.remove_army_from_tracking(defeated_army)
	
	# Free the army node
	defeated_army.queue_free()
	
	print("[BattleManager] Defeated army removed from map")

func _check_ai_turn_resumption(army_player_id: int) -> void:
	"""Check if an AI player needs to resume their turn after battle completion"""
	# NOTE: This function is no longer needed since AI turns now properly wait for battles
	# to complete using async/await in _execute_army_move(). The battle completion is 
	# handled automatically within the AI turn processing flow.
	print("[BattleManager] Battle completed for Player %d - AI turn will continue automatically" % army_player_id)

# --- Collect all defending armies owned by the region owner in the region (excluding the attacker if already reparented) ---
func _collect_defender_armies(region: Region, owner_id: int, attacker: Army) -> Array[Army]:
	var list: Array[Army] = []
	for child in region.get_children():
		if child is Army and child != attacker and child.get_player_id() == owner_id:
			list.append(child)
	return list

# --- Convert contributors into ArmyComposition array for the simulator ---
func _compositions_from_armies(armies: Array[Army]) -> Array:
	var comps: Array = []
	for a in armies:
		comps.append(a.get_composition())
	return comps

# --- Expose compositions for battle modal ---
func get_pending_attacking_compositions() -> Array:
	return _compositions_from_armies(_pending_attackers)

func get_pending_defending_compositions() -> Array:
	return _compositions_from_armies(_pending_defenders)

func get_pending_garrison() -> ArmyComposition:
	return _pending_garrison

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
