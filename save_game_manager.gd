extends RefCounted
class_name SaveGameManager

const SAVE_FILE_PATH: String = "user://savegame.json"
const SETTINGS_FILE_PATH: String = "user://settings.cfg"
const SAVE_VERSION: int = 1

static func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)

static func save_game(game_manager: GameManager) -> bool:
	var save_data: Dictionary = _build_save_data(game_manager)
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		DebugLogger.log("SaveGame", "ERROR: Could not open save file for writing: " + SAVE_FILE_PATH)
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	DebugLogger.log("SaveGame", "Saved game file: " + ProjectSettings.globalize_path(SAVE_FILE_PATH))
	var sound_manager: SoundManager = game_manager.get_node("../SoundManager") as SoundManager
	save_settings(sound_manager)
	return true

static func load_game() -> Dictionary:
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		DebugLogger.log("SaveGame", "ERROR: Could not open save file: " + SAVE_FILE_PATH)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(text)
	if parse_result != OK:
		DebugLogger.log("SaveGame", "ERROR: Failed to parse save file: " + json.error_string)
		return {}
	return json.data as Dictionary

static func save_settings(sound_manager: SoundManager) -> bool:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "sound_enabled", sound_manager.sound_enabled)
	config.set_value("audio", "music_enabled", sound_manager.music_enabled)
	config.set_value("audio", "sound_db", sound_manager.click_player.volume_db)
	config.set_value("audio", "music_db", sound_manager.music_player.volume_db)
	config.set_value("visual", "clouds_enabled", Clouds.is_global_clouds_enabled())
	config.set_value("gameplay", "ai_speed", GameParameters.get_ai_move_speed_multiplier())
	config.set_value("gameplay", "battle_speed", GameParameters.get_battle_round_time())
	var error: int = config.save(SETTINGS_FILE_PATH)
	return error == OK

static func load_settings(sound_manager: SoundManager) -> void:
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		return
	var config: ConfigFile = ConfigFile.new()
	var error: int = config.load(SETTINGS_FILE_PATH)
	if error != OK:
		DebugLogger.log("SaveGame", "ERROR: Failed to load settings file")
		return
	var default_sound_db: float = linear_to_db(0.5)
	var default_music_db: float = linear_to_db(0.5)
	var sound_enabled: bool = bool(config.get_value("audio", "sound_enabled", true))
	var music_enabled: bool = bool(config.get_value("audio", "music_enabled", true))
	var sound_db: float = float(config.get_value("audio", "sound_db", default_sound_db))
	var music_db: float = float(config.get_value("audio", "music_db", default_music_db))
	var clouds_enabled: bool = bool(config.get_value("visual", "clouds_enabled", Clouds.is_global_clouds_enabled()))
	Clouds.set_global_clouds_enabled(clouds_enabled)
	var ai_speed: float = float(config.get_value("gameplay", "ai_speed", GameParameters.get_ai_move_speed_multiplier()))
	var battle_speed: float = float(config.get_value("gameplay", "battle_speed", GameParameters.get_battle_round_time()))
	GameParameters.set_ai_move_speed_multiplier(ai_speed)
	GameParameters.set_battle_round_time(battle_speed)
	if sound_manager.is_node_ready():
		_apply_sound_settings(sound_manager, sound_enabled, music_enabled, sound_db, music_db)
	else:
		sound_manager.ready.connect(func() -> void:
			_apply_sound_settings(sound_manager, sound_enabled, music_enabled, sound_db, music_db)
		, CONNECT_ONE_SHOT)

static func _apply_sound_settings(sound_manager: SoundManager, sound_enabled: bool, music_enabled: bool, sound_db: float, music_db: float) -> void:
	sound_manager.sound_enabled = sound_enabled
	sound_manager.music_enabled = music_enabled
	sound_manager.click_player.volume_db = sound_db
	sound_manager.horn_player.volume_db = sound_db
	sound_manager.battle_player.volume_db = sound_db
	sound_manager.music_player.volume_db = music_db
	if not music_enabled:
		sound_manager.stop_all_music()

static func apply_save_data(game_manager: GameManager, save_data: Dictionary) -> void:
	var game_state: Dictionary = save_data.get("game_state", {})
	var source: Dictionary = save_data.get("source", {})
	game_manager.current_turn = int(game_state.get("current_turn", 1))
	game_manager.current_player = int(game_state.get("current_player", 1))
	game_manager.total_players = int(game_state.get("total_players", 6))
	game_manager.castle_placing_mode = bool(game_state.get("castle_placing_mode", false))
	game_manager.castles_placed = int(game_state.get("castles_placed", 0))
	game_manager.armies_per_castle = int(game_state.get("armies_per_castle", 3))
	game_manager.castle_placement_order = _to_int_array(game_state.get("castle_placement_order", []))
	game_manager.players_per_round = _to_int_array(game_state.get("players_per_round", [1, 2, 3, 4, 5, 6]))
	game_manager.player_types = _deserialize_player_types(game_state.get("player_types", []))
	game_manager._player_initial_turn_completed = _deserialize_initial_turn_flags(game_state.get("player_initial_turn_completed", {}))
	game_manager.game_mode = String(source.get("mode", "custom"))
	game_manager.scenario_path = String(source.get("scenario_path", ""))
	game_manager.load_victory_conditions_from_source(source)

	var player_manager: PlayerManagerNode = game_manager.get_player_manager()
	var player_manager_data: Dictionary = save_data.get("player_manager", {})
	player_manager.load_from_dictionary(player_manager_data)
	_apply_player_resources_from_save(player_manager, player_manager_data)

	var map_generator: MapGenerator = game_manager.get_node("../Map") as MapGenerator
	var region_manager: RegionManager = game_manager.get_region_manager()
	_apply_regions_from_save(game_manager, map_generator, region_manager, save_data.get("regions", []))

	var army_manager: ArmyManager = game_manager.get_army_manager()
	_clear_all_armies(army_manager)
	_apply_armies_from_save(map_generator, army_manager, save_data.get("armies", []))

	var source_map_size: String = String(source.get("map_size", "small"))
	game_manager._map_set_size_from_string(map_generator, source_map_size)

	player_manager.set_current_player(game_manager.current_player)
	game_manager._update_average_army_power()
	game_manager._apply_debug_ui_visibility_for_player(game_manager.current_player)
	game_manager._update_player_status_display()

	var ui_node: Node = game_manager.get_node("../UI")
	var player_status_modal2: PlayerStatusModal2 = ui_node.get_node("PlayerStatusModal2") as PlayerStatusModal2
	player_status_modal2.refresh_from_game_state()
	var turn_modal: TurnModal = ui_node.get_node("TurnModal") as TurnModal
	if game_manager.castle_placing_mode:
		turn_modal.hide()
	else:
		turn_modal.show_and_update()
	var runtime_clouds: Clouds = game_manager.get_node("../Map/Clouds") as Clouds
	runtime_clouds.set_clouds_enabled(Clouds.is_global_clouds_enabled())
	army_manager.set_ready_highlight_player(game_manager.current_player)

static func _apply_player_resources_from_save(player_manager: PlayerManagerNode, player_manager_data: Dictionary) -> void:
	var players_data: Dictionary = player_manager_data.get("players", {})
	for player_id_key in players_data:
		var player_payload: Dictionary = players_data.get(player_id_key, {})
		var resources_data: Dictionary = player_payload.get("resources", {})
		player_manager.set_player_resources(int(player_id_key), resources_data)

static func _build_save_data(game_manager: GameManager) -> Dictionary:
	var map_generator: MapGenerator = game_manager.get_node("../Map") as MapGenerator
	var region_manager: RegionManager = game_manager.get_region_manager()
	var army_manager: ArmyManager = game_manager.get_army_manager()
	var player_manager: PlayerManagerNode = game_manager.get_player_manager()
	var source: Dictionary = {
		"mode": game_manager.game_mode,
		"scenario_path": game_manager.scenario_path,
		"map_file": map_generator.data_file_path,
		"map_size": _map_size_to_string(map_generator.map_size),
		"player_settings": _player_types_to_settings(game_manager.player_types),
		"victory_conditions": game_manager.get_victory_conditions_for_save()
	}
	var game_state: Dictionary = {
		"current_turn": game_manager.current_turn,
		"current_player": game_manager.current_player,
		"total_players": game_manager.total_players,
		"castle_placing_mode": game_manager.castle_placing_mode,
		"castle_placement_order": game_manager.castle_placement_order.duplicate(),
		"castles_placed": game_manager.castles_placed,
		"armies_per_castle": game_manager.armies_per_castle,
		"players_per_round": game_manager.players_per_round.duplicate(),
		"player_types": _serialize_player_types(game_manager.player_types),
		"player_initial_turn_completed": _serialize_initial_turn_flags(game_manager._player_initial_turn_completed)
	}

	var regions_data: Array = []
	var regions_node: Node = map_generator.get_node("Regions")
	for child in regions_node.get_children():
		if child is Region:
			var region: Region = child as Region
			regions_data.append(_serialize_region(region, region_manager))

	var armies_data: Array = []
	var armies: Array[Army] = army_manager.get_all_armies()
	for army in armies:
		armies_data.append(_serialize_army(army))

	return {
		"version": SAVE_VERSION,
		"source": source,
		"game_state": game_state,
		"player_manager": player_manager.save_to_dictionary(),
		"regions": regions_data,
		"armies": armies_data
	}

static func _apply_regions_from_save(game_manager: GameManager, map_generator: MapGenerator, region_manager: RegionManager, regions_data: Array) -> void:
	var region_by_id: Dictionary = {}
	for entry in regions_data:
		if entry is Dictionary:
			var region_id: int = int(entry.get("id", -1))
			region_by_id[region_id] = entry

	var regions_node: Node = map_generator.get_node("Regions")
	for child in regions_node.get_children():
		if child is Region:
			var region: Region = child as Region
			var region_id: int = region.get_region_id()
			if region_by_id.has(region_id):
				var payload: Dictionary = region_by_id[region_id]
				_apply_region_payload(region, payload)

	for child in regions_node.get_children():
		if child is Region:
			var region: Region = child as Region
			var region_id: int = region.get_region_id()
			if region_by_id.has(region_id):
				var payload: Dictionary = region_by_id[region_id]
				var owner: int = int(payload.get("owner", -1))
				region_manager.set_region_ownership(region_id, owner)
				region.ownership_turns_counter = int(payload.get("ownership_turns_counter", region.ownership_turns_counter))
				region.just_conquered_this_turn = bool(payload.get("just_conquered_this_turn", false))

	_refresh_castle_visuals(game_manager, regions_node)

static func _apply_region_payload(region: Region, payload: Dictionary) -> void:
	var region_name: String = String(payload.get("name", region.get_region_name())).strip_edges()
	if region_name != "":
		region.set_region_name(region_name)
	var is_ocean: bool = bool(payload.get("ocean", region.is_ocean_region()))
	if is_ocean:
		region.set_ocean(true)
	else:
		var biome: String = String(payload.get("biome", region.get_biome()))
		region.set_region_type(RegionTypeEnum.string_to_type(biome))
		region.set_ocean(false)

	var level_text: String = String(payload.get("level", region.get_region_level_string()))
	region.set_region_level(RegionLevelEnum.string_to_level(level_text))
	region.set_population(int(payload.get("population", region.get_population())))

	var base_resources_data: Dictionary = payload.get("base_resources", payload.get("resources", {}))
	region.set_resources_from_dict(base_resources_data)
	region.available_recruits = int(payload.get("available_recruits", region.get_base_available_recruits()))

	var discovered_ores: Array[ResourcesEnum.Type] = []
	var ores_payload: Array = payload.get("discovered_ores", [])
	for ore_name in ores_payload:
		discovered_ores.append(ResourcesEnum.string_to_type(String(ore_name)))
	region.discovered_ores = discovered_ores

	region.ore_search_attempts_remaining = int(payload.get("ore_search_attempts_remaining", region.ore_search_attempts_remaining))
	region.ore_search_used_this_turn = bool(payload.get("ore_search_used_this_turn", false))
	region.raise_army_used_this_turn = bool(payload.get("raise_army_used_this_turn", false))
	region.promotion_used_this_turn = bool(payload.get("promotion_used_this_turn", false))
	region.promotion_growth_bonus_turns_remaining = int(payload.get("promotion_growth_bonus_turns_remaining", 0))
	region.promotion_cooldown_turns = int(payload.get("promotion_cooldown_turns", 0))

	var castle_type_text: String = String(payload.get("castle_type", CastleTypeEnum.type_to_string(region.get_castle_type())))
	region.set_castle_type(CastleTypeEnum.string_to_type(castle_type_text))
	var castle_under_construction_text: String = String(payload.get("castle_under_construction", "None"))
	region.castle_under_construction = CastleTypeEnum.string_to_type(castle_under_construction_text)
	region.castle_build_turns_remaining = int(payload.get("castle_build_turns_remaining", 0))
	region.castle_repair_turns_remaining = int(payload.get("castle_repair_turns_remaining", 0))
	region.castle_repair_in_progress = bool(payload.get("castle_repair_in_progress", false))
	region.gate_conditions = _to_int_array(payload.get("gate_conditions", []))
	region.wall_section_conditions = _to_int_array(payload.get("wall_section_conditions", []))

	var garrison_data: Dictionary = payload.get("garrison", {})
	_apply_composition(region.get_garrison(), garrison_data)
	var wounded_garrison_data: Dictionary = payload.get("wounded_garrison", {})
	_apply_composition(region.get_wounded_garrison(), wounded_garrison_data)
	var wounded_recruits_data: Dictionary = payload.get("wounded_recruits", {})
	_apply_composition(region.get_wounded_recruits(), wounded_recruits_data)

static func _refresh_castle_visuals(game_manager: GameManager, regions_node: Node) -> void:
	var visual_manager: VisualManager = game_manager.get_visual_manager()
	for child in regions_node.get_children():
		if child is Region:
			var region: Region = child as Region
			for sub in region.get_children():
				if sub is Sprite2D and sub.name == "Castle":
					region.remove_child(sub)
					sub.queue_free()
			if region.get_castle_type() != CastleTypeEnum.Type.NONE:
				visual_manager.place_castle_visual(region)

static func _clear_all_armies(army_manager: ArmyManager) -> void:
	army_manager.deselect_army()
	var armies: Array[Army] = army_manager.get_all_armies()
	for army in armies:
		army_manager.remove_army_from_tracking(army)
		var parent_node: Node = army.get_parent()
		parent_node.remove_child(army)
		army.queue_free()

static func _apply_armies_from_save(map_generator: MapGenerator, army_manager: ArmyManager, armies_data: Array) -> void:
	for entry in armies_data:
		if entry is Dictionary:
			var region_id: int = int(entry.get("region_id", -1))
			var player_id: int = int(entry.get("player_id", 1))
			var region: Region = map_generator.get_region_container_by_id(region_id) as Region
			var army: Army = army_manager.create_army(region, player_id)
			army.name = String(entry.get("name", army.name))
			army.number = String(entry.get("number", army.number))
			army.movement_points = int(entry.get("movement_points", GameParameters.MOVEMENT_POINTS_PER_TURN))
			army.efficiency = int(entry.get("efficiency", 100))
			army.recruitment_requested = bool(entry.get("recruitment_requested", false))
			army.just_raised = bool(entry.get("just_raised", false))
			_apply_composition(army.get_composition(), entry.get("composition", {}))
			_apply_composition(army.get_wounded_composition(), entry.get("wounded_composition", {}))

static func _serialize_region(region: Region, region_manager: RegionManager) -> Dictionary:
	var base_resources: Dictionary = {}
	for resource_type in ResourcesEnum.get_all_types():
		var resource_name: String = ResourcesEnum.type_to_string(resource_type)
		base_resources[resource_name] = region.base_resources.get_resource_amount(resource_type)

	var discovered_ores: Array = []
	for ore_type in region.discovered_ores:
		discovered_ores.append(ResourcesEnum.type_to_string(ore_type))

	return {
		"id": region.get_region_id(),
		"name": region.get_region_name(),
		"biome": region.get_biome(),
		"ocean": region.is_ocean_region(),
		"level": RegionLevelEnum.level_to_string(region.get_region_level()),
		"population": region.get_population(),
		"available_recruits": region.get_base_available_recruits(),
		"owner": region_manager.get_region_owner(region.get_region_id()),
		"ownership_turns_counter": region.ownership_turns_counter,
		"just_conquered_this_turn": region.just_conquered_this_turn,
		"base_resources": base_resources,
		"discovered_ores": discovered_ores,
		"ore_search_attempts_remaining": region.ore_search_attempts_remaining,
		"ore_search_used_this_turn": region.ore_search_used_this_turn,
		"raise_army_used_this_turn": region.raise_army_used_this_turn,
		"promotion_used_this_turn": region.promotion_used_this_turn,
		"promotion_growth_bonus_turns_remaining": region.promotion_growth_bonus_turns_remaining,
		"promotion_cooldown_turns": region.promotion_cooldown_turns,
		"castle_type": CastleTypeEnum.type_to_string(region.get_castle_type()),
		"castle_under_construction": CastleTypeEnum.type_to_string(region.castle_under_construction),
		"castle_build_turns_remaining": region.castle_build_turns_remaining,
		"castle_repair_turns_remaining": region.castle_repair_turns_remaining,
		"castle_repair_in_progress": region.castle_repair_in_progress,
		"gate_conditions": region.gate_conditions.duplicate(),
		"wall_section_conditions": region.wall_section_conditions.duplicate(),
		"garrison": _serialize_composition(region.get_garrison()),
		"wounded_garrison": _serialize_composition(region.get_wounded_garrison()),
		"wounded_recruits": _serialize_composition(region.get_wounded_recruits())
	}

static func _serialize_army(army: Army) -> Dictionary:
	var region: Region = army.get_parent() as Region
	return {
		"region_id": region.get_region_id(),
		"player_id": army.get_player_id(),
		"name": army.name,
		"number": army.number,
		"movement_points": army.get_movement_points(),
		"efficiency": army.get_efficiency(),
		"recruitment_requested": army.is_recruitment_requested(),
		"just_raised": army.just_raised,
		"composition": _serialize_composition(army.get_composition()),
		"wounded_composition": _serialize_composition(army.get_wounded_composition())
	}

static func _serialize_composition(composition: ArmyComposition) -> Dictionary:
	var data: Dictionary = {}
	for soldier_type in SoldierTypeEnum.get_all_types():
		var soldier_name: String = SoldierTypeEnum.type_to_string(soldier_type)
		data[soldier_name] = composition.get_soldier_count(soldier_type)
	return data

static func _apply_composition(composition: ArmyComposition, data: Dictionary) -> void:
	for soldier_type in SoldierTypeEnum.get_all_types():
		var soldier_name: String = SoldierTypeEnum.type_to_string(soldier_type)
		composition.set_soldier_count(soldier_type, int(data.get(soldier_name, 0)))

static func _serialize_player_types(player_types: Array[PlayerTypeEnum.Type]) -> Array:
	var result: Array = []
	for player_type in player_types:
		result.append(PlayerTypeEnum.type_to_string(player_type))
	return result

static func _deserialize_player_types(raw_types: Array) -> Array[PlayerTypeEnum.Type]:
	var result: Array[PlayerTypeEnum.Type] = []
	for raw_type in raw_types:
		result.append(PlayerTypeEnum.from_string(String(raw_type)))
	if result.size() == 6:
		return result
	return [
		PlayerTypeEnum.Type.HUMAN,
		PlayerTypeEnum.Type.COMPUTER,
		PlayerTypeEnum.Type.COMPUTER,
		PlayerTypeEnum.Type.COMPUTER,
		PlayerTypeEnum.Type.OFF,
		PlayerTypeEnum.Type.OFF
	]

static func _player_types_to_settings(player_types: Array[PlayerTypeEnum.Type]) -> Array:
	var settings: Array = []
	for i in range(player_types.size()):
		var player_id: int = i + 1
		var control_type: String = "Off"
		var player_type: PlayerTypeEnum.Type = player_types[i]
		if player_type == PlayerTypeEnum.Type.HUMAN:
			control_type = "Player"
		elif player_type == PlayerTypeEnum.Type.COMPUTER:
			control_type = "Computer"
		settings.append({
			"player_id": player_id,
			"control_type": control_type
		})
	return settings

static func _serialize_initial_turn_flags(flags: Dictionary) -> Dictionary:
	var serialized: Dictionary = {}
	for key in flags.keys():
		serialized[str(key)] = bool(flags[key])
	return serialized

static func _deserialize_initial_turn_flags(raw: Dictionary) -> Dictionary:
	var deserialized: Dictionary = {}
	for key in raw.keys():
		deserialized[int(key)] = bool(raw[key])
	return deserialized

static func _to_int_array(raw: Array) -> Array[int]:
	var values: Array[int] = []
	for item in raw:
		values.append(int(item))
	return values

static func _map_size_to_string(map_size: MapGenerator.MapSize) -> String:
	match map_size:
		MapGenerator.MapSize.XTINY:
			return "xtiny"
		MapGenerator.MapSize.TINY:
			return "tiny"
		MapGenerator.MapSize.SMALL:
			return "small"
		MapGenerator.MapSize.MEDIUM:
			return "medium"
		MapGenerator.MapSize.LARGE:
			return "large"
		MapGenerator.MapSize.HUGE:
			return "huge"
		_:
			return "small"
