extends TestCase
class_name TestAIWoundedHealing

class FakeGameManager:
	extends GameManager
	var difficulty_override: int = GameParameters.Difficulty.NORMAL

	func get_game_difficulty() -> int:
		return difficulty_override

class FakeCampArmy:
	extends Army
	var heal_per_camp: int = 0
	var camp_calls: int = 0

	func _init(active_count: int, wounded_count: int, mp: int, heal_step: int) -> void:
		player_id = 1
		number = "I"
		movement_points = mp
		efficiency = 100
		composition = ArmyComposition.new()
		wounded_composition = ArmyComposition.new()
		composition.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, active_count)
		wounded_composition.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, wounded_count)
		heal_per_camp = heal_step

	func make_camp() -> void:
		if movement_points <= 0:
			return
		movement_points -= 1
		camp_calls += 1
		var wounded_now: int = wounded_composition.get_soldier_count(SoldierTypeEnum.Type.PEASANTS)
		var heal_amount: int = mini(heal_per_camp, wounded_now)
		if heal_amount > 0:
			wounded_composition.remove_soldiers(SoldierTypeEnum.Type.PEASANTS, heal_amount)
			composition.add_soldiers(SoldierTypeEnum.Type.PEASANTS, heal_amount)

var _root: Node
var _turn_controller: TurnController
var _game_manager: FakeGameManager

func setup() -> void:
	_root = Node.new()
	_turn_controller = TurnController.new()
	_turn_controller.name = "TurnController"
	_root.add_child(_turn_controller)
	_game_manager = FakeGameManager.new()
	_turn_controller.game_manager = _game_manager

func teardown() -> void:
	if is_instance_valid(_root):
		_root.free()

func test_easy_threshold_trigger_and_below() -> void:
	_game_manager.difficulty_override = GameParameters.Difficulty.EASY
	var at_threshold: FakeCampArmy = FakeCampArmy.new(50, 50, 2, 0)
	var below_threshold: FakeCampArmy = FakeCampArmy.new(51, 49, 2, 0)

	var triggered: bool = _turn_controller._check_if_heal_wounded(at_threshold)
	var skipped: bool = _turn_controller._check_if_heal_wounded(below_threshold)

	assert_true(triggered, "Easy should trigger healing when wounded ratio is exactly 50%")
	assert_equals(at_threshold.camp_calls, 2, "At-threshold army should camp while MP remains")
	assert_false(skipped, "Easy should not trigger healing below 50% wounded ratio")
	assert_equals(below_threshold.camp_calls, 0, "Below-threshold army should not camp")

func test_normal_threshold_boundary_behavior() -> void:
	_game_manager.difficulty_override = GameParameters.Difficulty.NORMAL
	var at_threshold: FakeCampArmy = FakeCampArmy.new(65, 35, 1, 0)
	var below_threshold: FakeCampArmy = FakeCampArmy.new(66, 34, 1, 0)

	var triggered: bool = _turn_controller._check_if_heal_wounded(at_threshold)
	var skipped: bool = _turn_controller._check_if_heal_wounded(below_threshold)

	assert_true(triggered, "Normal should trigger healing when wounded ratio is exactly 35%")
	assert_equals(at_threshold.camp_calls, 1, "Boundary-triggered army should camp once with 1 MP")
	assert_false(skipped, "Normal should not trigger healing below 35% wounded ratio")
	assert_equals(below_threshold.camp_calls, 0, "Below-threshold army should not camp")

func test_hard_threshold_boundary_behavior() -> void:
	_game_manager.difficulty_override = GameParameters.Difficulty.HARD
	var at_threshold: FakeCampArmy = FakeCampArmy.new(80, 20, 1, 0)
	var below_threshold: FakeCampArmy = FakeCampArmy.new(81, 19, 1, 0)

	var triggered: bool = _turn_controller._check_if_heal_wounded(at_threshold)
	var skipped: bool = _turn_controller._check_if_heal_wounded(below_threshold)

	assert_true(triggered, "Hard should trigger healing when wounded ratio is exactly 20%")
	assert_equals(at_threshold.camp_calls, 1, "Boundary-triggered army should camp once with 1 MP")
	assert_false(skipped, "Hard should not trigger healing below 20% wounded ratio")
	assert_equals(below_threshold.camp_calls, 0, "Below-threshold army should not camp")

func test_loop_stops_when_ratio_drops_below_threshold() -> void:
	_game_manager.difficulty_override = GameParameters.Difficulty.EASY
	var army: FakeCampArmy = FakeCampArmy.new(10, 10, 5, 4)

	var triggered: bool = _turn_controller._check_if_heal_wounded(army)

	assert_true(triggered, "Healing should trigger at 50% wounded ratio")
	assert_equals(army.camp_calls, 1, "Healing loop should stop once ratio drops below threshold")
	assert_equals(army.get_movement_points(), 4, "Army should keep remaining MP after loop exits")

func test_loop_spends_all_mp_if_ratio_stays_high() -> void:
	_game_manager.difficulty_override = GameParameters.Difficulty.EASY
	var army: FakeCampArmy = FakeCampArmy.new(0, 10, 3, 1)

	var triggered: bool = _turn_controller._check_if_heal_wounded(army)

	assert_true(triggered, "Healing should trigger when army is fully wounded")
	assert_equals(army.camp_calls, 3, "Loop should keep camping while ratio stays above threshold and MP remains")
	assert_equals(army.get_movement_points(), 0, "Loop should stop when movement points reach zero")

func test_mp_gate_blocks_heal_check() -> void:
	_game_manager.difficulty_override = GameParameters.Difficulty.EASY
	var army: FakeCampArmy = FakeCampArmy.new(0, 10, 0, 1)

	var triggered: bool = _turn_controller._check_if_heal_wounded(army)

	assert_false(triggered, "Heal check should not trigger with zero movement points")
	assert_equals(army.camp_calls, 0, "Army with zero MP must not camp")

func test_ratio_uses_total_pool_not_active_only() -> void:
	_game_manager.difficulty_override = GameParameters.Difficulty.EASY
	var army: FakeCampArmy = FakeCampArmy.new(20, 10, 2, 0)

	var ratio: float = _turn_controller._get_army_wounded_ratio(army)
	var triggered: bool = _turn_controller._check_if_heal_wounded(army)

	assert_equals(snappedf(ratio, 0.001), 0.333, "Ratio should be wounded/(active+wounded)")
	assert_false(triggered, "20 active + 10 wounded should not trigger Easy threshold")
	assert_equals(army.camp_calls, 0, "Army should not camp when total-pool ratio is below threshold")
