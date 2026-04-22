extends TestCase
class_name TestFamineSystem

class FakeMapGenerator:
	extends MapGenerator
	var regions_by_id: Dictionary = {}
	
	func _init() -> void:
		region_container_by_id = {}
		regions = []
		edges = []
	
	func get_region_container_by_id(region_id: int) -> Node:
		if regions_by_id.has(region_id):
			return regions_by_id[region_id]
		return null

class FakeRegionManager:
	extends RegionManager
	var player_regions_map: Dictionary = {}
	
	func _init(map_gen: MapGenerator) -> void:
		map_generator = map_gen
		region_ownership = {}
	
	func get_player_regions(player_id: int) -> Array[int]:
		var raw_regions: Array = player_regions_map.get(player_id, [])
		var result: Array[int] = []
		for region_id in raw_regions:
			result.append(int(region_id))
		return result

class FakeArmyManager:
	extends ArmyManager
	var all_armies_list: Array[Army] = []
	
	func _init(map_gen: MapGenerator, region_mgr: RegionManager) -> void:
		map_generator = map_gen
		region_manager = region_mgr
		armies_by_player = {}
	
	func get_all_armies() -> Array[Army]:
		return all_armies_list
	
	func get_player_armies(player_id: int) -> Array[Army]:
		var result: Array[Army] = []
		for army in all_armies_list:
			if army.get_player_id() == player_id:
				result.append(army)
		return result
	
	func remove_destroyed_armies() -> void:
		var alive_armies: Array[Army] = []
		for army in all_armies_list:
			if army.get_total_soldiers() > 0:
				alive_armies.append(army)
		all_armies_list = alive_armies

var _root: Node
var _map: FakeMapGenerator
var _region_manager: FakeRegionManager
var _army_manager: FakeArmyManager
var _game_manager: GameManager
var _player_manager: PlayerManagerNode

func setup() -> void:
	_root = Node.new()
	_map = FakeMapGenerator.new()
	_map.name = "Map"
	_root.add_child(_map)
	
	_region_manager = FakeRegionManager.new(_map)
	_army_manager = FakeArmyManager.new(_map, _region_manager)
	
	_game_manager = GameManager.new()
	_game_manager.name = "GameManager"
	_root.add_child(_game_manager)
	_game_manager._region_manager = _region_manager
	_game_manager._army_manager = _army_manager
	
	_player_manager = PlayerManagerNode.new()
	_player_manager.region_manager = _region_manager
	_player_manager.map_generator = _map
	_player_manager.army_manager = _army_manager
	
	var player: Player = Player.new(1, "Player 1")
	_player_manager.players = {1: player}

func teardown() -> void:
	if is_instance_valid(_root):
		_root.free()

func test_garrison_upkeep_enabled_in_total_food_cost() -> void:
	var region: Region = _new_region(1, "Northhold", 1, 1000)
	region.get_garrison().set_soldier_count(SoldierTypeEnum.Type.PEASANTS, 10)  # 1.0 food
	_register_region_for_player(region, 1)
	
	var army: Army = _new_army(1, "I", region, {SoldierTypeEnum.Type.PEASANTS: 10})  # 1.0 food
	_army_manager.all_armies_list = [army]
	
	var upkeep: float = _player_manager.calculate_total_army_food_cost(1)
	assert_equals(snappedf(upkeep, 0.01), 2.0, "Upkeep should include active garrison + active army")

func test_famine_does_not_change_population() -> void:
	var region_a: Region = _new_region(1, "A", 1, 1200)
	var region_b: Region = _new_region(2, "B", 1, 900)
	region_a.get_garrison().set_soldier_count(SoldierTypeEnum.Type.PEASANTS, 30)
	region_b.get_garrison().set_soldier_count(SoldierTypeEnum.Type.SPEARMEN, 20)
	_register_region_for_player(region_a, 1)
	_register_region_for_player(region_b, 1)
	
	var army: Army = _new_army(1, "I", region_a, {
		SoldierTypeEnum.Type.PEASANTS: 20,
		SoldierTypeEnum.Type.HORSEMEN: 10
	})
	_army_manager.all_armies_list = [army]
	
	var pop_a_before: int = region_a.get_population()
	var pop_b_before: int = region_b.get_population()
	var famine_result: Dictionary = _game_manager.famine_regions(1, 5.0)  # 50 points
	
	assert_equals(region_a.get_population(), pop_a_before, "Famine should not change region population")
	assert_equals(region_b.get_population(), pop_b_before, "Famine should not change region population")
	assert_true(bool(famine_result.get("triggered", false)), "Famine result should be marked as triggered")
	assert_equals(int(famine_result.get("target_points", 0)), 50, "Missing food should convert to 50 loss points")

func test_food_weighted_unit_losses_use_point_costs() -> void:
	var composition: ArmyComposition = ArmyComposition.new()
	composition.set_soldier_count(SoldierTypeEnum.Type.HORSEMEN, 10)  # 2 points each
	var force_entry: Dictionary = {
		"allocated_points": 10,
		"composition": composition
	}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var result: Dictionary = _game_manager._apply_famine_points_to_force(force_entry, rng)
	
	assert_equals(int(result.get("removed_points", 0)), 10, "Removed points should match allocated points")
	assert_equals(int(result.get("soldiers_lost", 0)), 5, "10 points should remove 5 horsemen")
	assert_equals(composition.get_soldier_count(SoldierTypeEnum.Type.HORSEMEN), 5, "Composition should be reduced by 5 horsemen")

func test_proportional_distribution_hits_bigger_force_harder() -> void:
	var region_a: Region = _new_region(1, "A", 1, 1000)
	var region_b: Region = _new_region(2, "B", 1, 1000)
	_register_region_for_player(region_a, 1)
	_register_region_for_player(region_b, 1)
	
	var big_army: Army = _new_army(1, "I", region_a, {SoldierTypeEnum.Type.PEASANTS: 100})
	var small_army: Army = _new_army(1, "II", region_b, {SoldierTypeEnum.Type.PEASANTS: 10})
	_army_manager.all_armies_list = [big_army, small_army]
	
	var result: Dictionary = _game_manager.famine_regions(1, 5.5)  # 55 points
	var by_force: Array = result.get("by_force", [])
	var big_lost: int = _get_force_loss_by_name(by_force, "Army I")
	var small_lost: int = _get_force_loss_by_name(by_force, "Army II")
	
	assert_true(big_lost >= small_lost, "Bigger upkeep force should lose at least as many soldiers as smaller force")
	assert_true(big_lost > 0, "Bigger force should lose soldiers")
	assert_true(small_lost > 0, "Smaller force should lose soldiers")

func test_famine_summary_totals_are_consistent() -> void:
	var region: Region = _new_region(1, "Core", 1, 1000)
	region.get_garrison().set_soldier_count(SoldierTypeEnum.Type.PEASANTS, 20)
	_register_region_for_player(region, 1)
	
	var army: Army = _new_army(1, "I", region, {
		SoldierTypeEnum.Type.PEASANTS: 20,
		SoldierTypeEnum.Type.HORSEMEN: 10
	})
	_army_manager.all_armies_list = [army]
	
	var result: Dictionary = _game_manager.famine_regions(1, 5.0)
	var by_force: Array = result.get("by_force", [])
	var by_unit_type: Dictionary = result.get("by_unit_type", {})
	var soldiers_from_forces: int = 0
	var points_from_forces: int = 0
	for force_row in by_force:
		soldiers_from_forces += int(force_row.get("soldiers_lost", 0))
		points_from_forces += int(force_row.get("removed_points", 0))
	
	var soldiers_from_units: int = 0
	var points_from_units: int = 0
	for unit_name in by_unit_type.keys():
		var count: int = int(by_unit_type.get(unit_name, 0))
		soldiers_from_units += count
		points_from_units += count * _unit_points_from_name(String(unit_name))
	
	assert_equals(int(result.get("soldiers_lost", 0)), soldiers_from_forces, "Summary soldiers_lost should match by_force aggregate")
	assert_equals(int(result.get("soldiers_lost", 0)), soldiers_from_units, "Summary soldiers_lost should match by_unit_type aggregate")
	assert_equals(int(result.get("actual_points_removed", 0)), points_from_forces, "Summary points should match by_force aggregate")
	assert_equals(int(result.get("actual_points_removed", 0)), points_from_units, "Summary points should match by_unit_type aggregate")

func _register_region_for_player(region: Region, player_id: int) -> void:
	_map.regions_by_id[region.get_region_id()] = region
	_map.region_container_by_id[region.get_region_id()] = region
	_map.add_child(region)
	var owned: Array = _region_manager.player_regions_map.get(player_id, [])
	owned.append(region.get_region_id())
	_region_manager.player_regions_map[player_id] = owned

func _new_region(region_id: int, region_name: String, owner_id: int, population: int) -> Region:
	var region: Region = Region.new()
	region.region_id = region_id
	region.region_name = region_name
	region.name = region_name
	region.region_level = RegionLevelEnum.Level.L1
	region.population = population
	region.current_owner_id = owner_id
	region.garrison = ArmyComposition.new()
	region.wounded_garrison = ArmyComposition.new()
	region.wounded_recruits = ArmyComposition.new()
	region.resources = ResourceComposition.new()
	region.base_resources = ResourceComposition.new()
	return region

func _new_army(player_id: int, roman: String, region: Region, units: Dictionary) -> Army:
	var army: Army = Army.new()
	army.player_id = player_id
	army.number = roman
	army.composition = ArmyComposition.new()
	army.wounded_composition = ArmyComposition.new()
	for unit_type in units.keys():
		army.composition.set_soldier_count(unit_type, int(units[unit_type]))
	region.add_child(army)
	return army

func _get_force_loss_by_name(by_force: Array, force_name: String) -> int:
	for row in by_force:
		if String(row.get("force_name", "")) == force_name:
			return int(row.get("soldiers_lost", 0))
	return 0

func _unit_points_from_name(unit_name: String) -> int:
	var unit_type: SoldierTypeEnum.Type = SoldierTypeEnum.string_to_type(unit_name)
	var food_cost: float = float(GameParameters.get_unit_food_cost(unit_type))
	return int(round(food_cost * 10.0))
