extends Node
class_name AnimatedBattleSimulator

# Signals for battle events
signal round_completed(round_data: Dictionary)
signal battle_finished(report: BattleSimulator.BattleReport)
signal ai_withdrawal_started

var battle_simulator: BattleSimulator
var battle_timer: Timer
var is_battle_running: bool = false
var battle_session: BattleSimulator.BattleSession = null

func _ready():
	battle_simulator = BattleSimulator.new()
	battle_timer = Timer.new()
	battle_timer.wait_time = GameParameters.get_battle_round_time()
	battle_timer.timeout.connect(_process_next_round)
	battle_timer.one_shot = true
	add_child(battle_timer)

func set_round_time(seconds: float) -> void:
	battle_timer.wait_time = seconds
	if is_battle_running:
		battle_timer.start()

func start_animated_battle(attacking_armies: Array, defending_armies: Array, region_garrison: ArmyComposition = null, attacker_efficiency: int = 100, defender_efficiency: int = 100, terrain_type: RegionTypeEnum.Type = RegionTypeEnum.Type.GRASSLAND, castle_type: CastleTypeEnum.Type = CastleTypeEnum.Type.NONE, attacker_can_withdraw: bool = false, defender_can_withdraw: bool = false, castle_defense_bonus_override: int = -1, attacker_effectiveness_ratio: float = 0.0, siege_payload: Dictionary = {}) -> void:
	if is_battle_running:
		DebugLogger.log("BattleAnimation", "Battle already running!")
		return
	battle_session = battle_simulator.start_battle_session(attacking_armies, defending_armies, region_garrison, attacker_efficiency, defender_efficiency, terrain_type, castle_type, attacker_can_withdraw, defender_can_withdraw, castle_defense_bonus_override, attacker_effectiveness_ratio, siege_payload)
	is_battle_running = battle_session != null and battle_session.is_battle_running
	if not is_battle_running:
		return
	battle_timer.wait_time = GameParameters.get_battle_round_time()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var volley_result = battle_simulator.process_opening_volley_session(battle_session, rng)
	_emit_battle_step(volley_result)
	if is_battle_running and battle_session != null and battle_session.is_battle_running and volley_result.get("battle_report", null) == null:
		battle_timer.start()

func _emit_battle_step(step_result: Dictionary) -> void:
	if step_result == null or not (step_result is Dictionary):
		return
	var withdrawing_side: int = int(step_result.get("withdrawing_side", 0))
	if withdrawing_side != 0:
		ai_withdrawal_started.emit()
	var round_data: Dictionary = {}
	var maybe_round = step_result.get("round_data")
	if maybe_round is Dictionary:
		round_data = maybe_round
	if not round_data.is_empty():
		round_completed.emit(round_data)
	var report: BattleSimulator.BattleReport = step_result.get("battle_report", null)
	if report != null:
		is_battle_running = false
		battle_finished.emit(report)

func _process_next_round() -> void:
	if not is_battle_running or battle_session == null or not battle_session.is_battle_running:
		return
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var round_result = battle_simulator.process_next_round_session(battle_session, rng)
	_emit_battle_step(round_result)
	if is_battle_running and battle_session != null and battle_session.is_battle_running:
		battle_timer.start()
	else:
		is_battle_running = false

func stop_battle() -> void:
	if is_battle_running:
		is_battle_running = false
		battle_timer.stop()
	battle_session = null

func is_running() -> bool:
	return is_battle_running

func start_withdrawal_round(side: int) -> void:
	if battle_session == null or not battle_session.is_battle_running or battle_session.is_withdrawing or side == 0:
		return
	battle_simulator._start_withdrawal_round_session(battle_session, side)
	ai_withdrawal_started.emit()
	is_battle_running = true
	battle_timer.start()
