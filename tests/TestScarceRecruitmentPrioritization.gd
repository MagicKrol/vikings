extends TestCase
class_name TestScarceRecruitmentPrioritization

var _root: Node
var _map: MapGenerator
var _region_manager: RegionManager
var _army_manager: ArmyManager
var _player_manager: PlayerManagerNode
var _game_manager: GameManager
var _economy: EconomyAIManager

func setup() -> void:
	_root = Node.new()
	_map = MapGenerator.new()
	_root.add_child(_map)
	_region_manager = RegionManager.new(_map)
	_army_manager = ArmyManager.new(_map, _region_manager)
	_player_manager = PlayerManagerNode.new()
	_game_manager = GameManager.new()
	_game_manager.player_manager = _player_manager
	_player_manager.players = {1: _new_player(1, 200, 100, 100)}
	_player_manager.region_manager = _region_manager
	_player_manager.map_generator = _map
	_player_manager.army_manager = _army_manager
	_economy = EconomyAIManager.new(_region_manager, _army_manager, _player_manager, _game_manager)

func teardown() -> void:
	if is_instance_valid(_root):
		_root.free()
	_economy = null
	_game_manager = null
	_player_manager = null
	_army_manager = null
	_region_manager = null
	_map = null

func test_single_army_keeps_budget_when_still_below_minimum() -> void:
	var castle: Region = _make_castle(101, 1)
	var army: Army = _new_army(castle, "A", 0)
	army.assign_recruitment_budget(BudgetComposition.new(1, 0, 0, 1))
	var assigned: int = _economy._prioritize_army_recruitment_budgets_for_minimum_power(1, 1, [army], 1)
	assert_equals(assigned, 1, "Single queued army should keep its budget")
	assert_not_null(army.get_assigned_budget(), "Single queued army should not be deferred")

func test_three_armies_defers_largest_shortfall_and_funds_two() -> void:
	var castle: Region = _make_castle(102, 6)
	var near_one: Army = _new_army(castle, "A", 18)
	var near_two: Army = _new_army(castle, "B", 18)
	var weakest: Army = _new_army(castle, "C", 0)
	for army in [near_one, near_two, weakest]:
		army.assign_recruitment_budget(BudgetComposition.new(4, 0, 0, 2))
	var assigned: int = _economy._prioritize_army_recruitment_budgets_for_minimum_power(1, 1, [near_one, near_two, weakest], 3)
	assert_equals(assigned, 2, "Only two armies should keep recruitment budgets")
	assert_not_null(near_one.get_assigned_budget(), "Closest army should keep budget")
	assert_not_null(near_two.get_assigned_budget(), "Second closest army should keep budget")
	assert_null(weakest.get_assigned_budget(), "Largest-shortfall army should be deferred")
	assert_true(weakest.is_recruitment_requested(), "Deferred army should keep recruitment request")

func test_final_single_keeps_budget_when_no_candidate_can_pass() -> void:
	var castle: Region = _make_castle(103, 2)
	var first: Army = _new_army(castle, "A", 0)
	var second: Army = _new_army(castle, "B", 0)
	first.assign_recruitment_budget(BudgetComposition.new(1, 0, 0, 1))
	second.assign_recruitment_budget(BudgetComposition.new(1, 0, 0, 1))
	var assigned: int = _economy._prioritize_army_recruitment_budgets_for_minimum_power(1, 1, [first, second], 2)
	var kept: int = 0
	if first.get_assigned_budget() != null:
		kept += 1
	if second.get_assigned_budget() != null:
		kept += 1
	assert_equals(assigned, 1, "Final single candidate should keep the remaining budget")
	assert_equals(kept, 1, "Exactly one army should keep a budget")

func test_garrison_budget_is_unchanged_by_army_prioritization() -> void:
	var castle: Region = _make_castle(104, 10)
	var first: Army = _new_army(castle, "A", 0)
	var second: Army = _new_army(castle, "B", 0)
	_army_manager.armies_by_player[1] = [first, second]
	var request: Dictionary = {
		"region_id": castle.get_region_id(),
		"region": castle,
		"assigned_budget": null,
		"weight": 1.0
	}
	var player: Player = _player_manager.get_player(1)
	var assigned: int = _economy.budget_manager.allocate_recruitment_budgets([first, second], player, _region_manager, 1, [request])
	var garrison_budget: BudgetComposition = request.get("assigned_budget")
	var before: Dictionary = garrison_budget.to_dict()
	_economy._prioritize_army_recruitment_budgets_for_minimum_power(1, 1, [first, second], assigned)
	var after_budget: BudgetComposition = request.get("assigned_budget")
	assert_equals(after_budget.gold, int(before.get("gold", 0)), "Garrison gold budget should be unchanged")
	assert_equals(after_budget.wood, int(before.get("wood", 0)), "Garrison wood budget should be unchanged")
	assert_equals(after_budget.iron, int(before.get("iron", 0)), "Garrison iron budget should be unchanged")
	assert_equals(after_budget.available_recruits, int(before.get("available_recruits", 0)), "Garrison recruit cap should be unchanged")

func test_partial_recruitment_re_requests_army_below_minimum() -> void:
	var castle: Region = _make_castle(105, 1)
	var army: Army = _new_army(castle, "A", 0)
	army.assign_recruitment_budget(BudgetComposition.new(1, 0, 0, 1))
	var hires: Array[String] = _economy._execute_army_recruitment(1, [army], 1)
	assert_equals(hires.size(), 1, "Army should recruit with partial budget")
	assert_true(army.is_recruitment_requested(), "Army below minimal threshold should request recruitment again")

func _make_castle(region_id: int, recruits: int) -> Region:
	var region: Region = Region.new()
	var data: Dictionary = {"id": region_id, "biome": "grassland", "ocean": false, "center": [0.0, 0.0]}
	region.setup_region(data)
	region.castle_type = CastleTypeEnum.Type.OUTPOST
	region.available_recruits = recruits
	_root.add_child(region)
	_map.region_container_by_id[region_id] = region
	_region_manager.region_ownership[region_id] = 1
	return region

func _new_army(region: Region, label: String, peasants: int) -> Army:
	var army: Army = Army.new()
	army.setup_raised_army(1, label)
	army.add_soldiers(SoldierTypeEnum.Type.PEASANTS, peasants)
	army.request_recruitment()
	region.add_child(army)
	return army

func _new_player(player_id: int, gold: int, wood: int, iron: int) -> Player:
	var player: Player = Player.new(player_id, "P" + str(player_id))
	player.set_resource_amount(ResourcesEnum.Type.GOLD, gold)
	player.set_resource_amount(ResourcesEnum.Type.WOOD, wood)
	player.set_resource_amount(ResourcesEnum.Type.IRON, iron)
	return player
