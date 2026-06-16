extends RefCounted
class_name UpgradesManager

const PROGRESS_FILE_PATH: String = "user://upgrade_progress.cfg"
const PROGRESS_FILE_PASSWORD: String = "HornOfTheWarlordUpgradeProgressV1"
const PROGRESS_SECTION: String = "levels"
const STATS_SECTION: String = "stats"
const TOTAL_GAMES_KEY: String = "total_games"
const SOURCE_NONE: String = "none"
const SOURCE_SCENARIO: String = "scenario"
const SOURCE_SKIRMISH: String = "skirmish"
const REQUIREMENT_SOURCE: String = "source"
const REQUIREMENT_TOTAL_GAMES: String = "total_games"
const BONUS_RESOURCE: String = "resource"
const BONUS_UNIT: String = "unit"
const CARD_BONUS_LEVEL_AMOUNTS: Dictionary = {
	"Card1": [10, 20, 40],
	"Card2": [5, 10, 20],
	"Card3": [5, 10, 20],
	"Card4": [5, 10, 20],
	"Card5": [10, 20, 40],
	"Card6": [10, 20, 40],
	"Card7": [6, 12, 25],
	"Card8": [5, 10, 20],
	"Card9": [5, 10, 20],
	"Card10": [5, 10, 20],
	"Card11": [3, 6, 12],
	"Card12": [1, 2, 4]
}

static func get_all_cards() -> Array[Dictionary]:
	return [
		_make_resource_card("Card1", ResourcesEnum.Type.FOOD, _requirements([
			_source_requirement(1, SOURCE_SCENARIO, "tutorial", ""),
			_total_games_requirement(2, 5),
			_total_games_requirement(3, 10)
		])),
		_make_resource_card("Card2", ResourcesEnum.Type.WOOD, _difficulty_requirements(SOURCE_SCENARIO, "mission-2")),
		_make_resource_card("Card3", ResourcesEnum.Type.STONE, _difficulty_requirements(SOURCE_SCENARIO, "Vikings Invasion")),
		_make_resource_card("Card4", ResourcesEnum.Type.IRON, _difficulty_requirements(SOURCE_SCENARIO, "Last Stand")),
		_make_resource_card("Card5", ResourcesEnum.Type.GOLD, _difficulty_requirements(SOURCE_SCENARIO, "horde")),
		_make_unit_card("Card6", SoldierTypeEnum.Type.PEASANTS, 10, _requirements([
			_source_requirement(1, SOURCE_SCENARIO, "mission-1", ""),
			_source_requirement(2, SOURCE_SCENARIO, "scenario4", "normal"),
			_source_requirement(3, SOURCE_SCENARIO, "scenario4", "hard")
		])),
		_make_unit_card("Card7", SoldierTypeEnum.Type.SPEARMEN, 5, _difficulty_requirements(SOURCE_SCENARIO, "mission-3")),
		_make_unit_card("Card8", SoldierTypeEnum.Type.ARCHERS, 5, _difficulty_requirements(SOURCE_SCENARIO, "mission-4")),
		_make_unit_card("Card9", SoldierTypeEnum.Type.SWORDSMEN, 4, _difficulty_requirements(SOURCE_SCENARIO, "mission-5")),
		_make_unit_card("Card10", SoldierTypeEnum.Type.CROSSBOWMEN, 3, _difficulty_requirements(SOURCE_SCENARIO, "mission-6")),
		_make_unit_card("Card11", SoldierTypeEnum.Type.HORSEMEN, 2, _difficulty_requirements(SOURCE_SCENARIO, "mission7")),
		_make_unit_card("Card12", SoldierTypeEnum.Type.KNIGHTS, 1, _difficulty_requirements(SOURCE_SKIRMISH, "skirmish"))
	]

static func get_card(card_id: String) -> Dictionary:
	for card: Dictionary in get_all_cards():
		if String(card.get("id", "")) == card_id:
			return card
	return {}

static func get_card_level(card_id: String) -> int:
	var card: Dictionary = get_card(card_id)
	if card.is_empty():
		return 0
	var config: ConfigFile = _load_progress_config()
	return clampi(int(config.get_value(PROGRESS_SECTION, card_id, 0)), 0, 3)

static func is_card_unlocked(card_id: String) -> bool:
	return get_card_level(card_id) > 0

static func has_unlocked_cards() -> bool:
	for card: Dictionary in get_all_cards():
		var card_id: String = String(card.get("id", ""))
		if is_card_unlocked(card_id):
			return true
	return false

static func get_selection_limit_for_difficulty(difficulty_name: String) -> int:
	var normalized: String = difficulty_name.to_lower()
	if normalized == "easy":
		return 1
	if normalized == "hard":
		return 3
	return 2

static func get_valid_selected_cards(raw_card_ids: Array, difficulty_name: String) -> Array[String]:
	var valid_ids: Array[String] = []
	var limit: int = get_selection_limit_for_difficulty(difficulty_name)
	for raw_card_id in raw_card_ids:
		var card_id: String = String(raw_card_id)
		if valid_ids.has(card_id):
			continue
		if not is_card_unlocked(card_id):
			continue
		if get_card(card_id).is_empty():
			continue
		valid_ids.append(card_id)
		if valid_ids.size() >= limit:
			break
	return valid_ids

static func get_card_bonus_amount(card_id: String, level: int) -> int:
	var card: Dictionary = get_card(card_id)
	if card.is_empty():
		return 0
	var amounts: Array = card.get("bonus_amounts", [])
	var level_index: int = clampi(level, 1, 3) - 1
	if level_index >= amounts.size():
		return 0
	return int(amounts[level_index])

static func get_card_bonus_table() -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	for card: Dictionary in get_all_cards():
		var card_id: String = String(card.get("id", ""))
		table.append({
			"id": card_id,
			"level_1": get_card_bonus_amount(card_id, 1),
			"level_2": get_card_bonus_amount(card_id, 2),
			"level_3": get_card_bonus_amount(card_id, 3)
		})
	return table

static func record_completion(source_type: String, source_id: String, difficulty_name: String) -> bool:
	var result: Dictionary = record_completion_result(source_type, source_id, difficulty_name)
	return bool(result.get("changed", false))

static func record_completion_result(source_type: String, source_id: String, difficulty_name: String) -> Dictionary:
	var normalized_source_type: String = source_type.strip_edges().to_lower()
	if normalized_source_type == "":
		return {"changed": false}
	var changed: bool = false
	var changed_card_id: String = ""
	var changed_previous_level: int = 0
	var changed_new_level: int = 0
	var config: ConfigFile = _load_progress_config()
	var total_games: int = _record_total_game_completion(config)
	for card: Dictionary in get_all_cards():
		var card_id: String = String(card.get("id", ""))
		var current_level: int = clampi(int(config.get_value(PROGRESS_SECTION, card_id, 0)), 0, 3)
		var unlocked_level: int = _get_completion_unlocked_level(card, source_type, source_id, difficulty_name, total_games)
		if unlocked_level > current_level:
			config.set_value(PROGRESS_SECTION, card_id, unlocked_level)
			changed = true
			if changed_card_id == "":
				changed_card_id = card_id
				changed_previous_level = current_level
				changed_new_level = unlocked_level
	_save_progress_config(config)
	return {
		"changed": changed,
		"card_id": changed_card_id,
		"previous_level": changed_previous_level,
		"new_level": changed_new_level
	}

static func get_card_level_requirement(card_id: String, level: int) -> Dictionary:
	var card: Dictionary = get_card(card_id)
	if card.is_empty():
		return {}
	var requirements: Array = card.get("level_requirements", [])
	for raw_requirement in requirements:
		var requirement: Dictionary = raw_requirement
		if int(requirement.get("level", 0)) == level:
			return requirement.duplicate(true)
	return {}

static func _record_total_game_completion(config: ConfigFile) -> int:
	var total_games: int = int(config.get_value(STATS_SECTION, TOTAL_GAMES_KEY, 0)) + 1
	config.set_value(STATS_SECTION, TOTAL_GAMES_KEY, total_games)
	return total_games

static func _get_completion_unlocked_level(card: Dictionary, source_type: String, source_id: String, difficulty_name: String, total_games: int) -> int:
	var unlocked_level: int = 0
	var requirements: Array = card.get("level_requirements", [])
	for raw_requirement in requirements:
		var requirement: Dictionary = raw_requirement
		if _requirement_matches_completion(requirement, source_type, source_id, difficulty_name, total_games):
			unlocked_level = maxi(unlocked_level, int(requirement.get("level", 0)))
	return unlocked_level

static func _requirement_matches_completion(requirement: Dictionary, source_type: String, source_id: String, difficulty_name: String, total_games: int) -> bool:
	var requirement_type: String = String(requirement.get("type", "")).to_lower()
	if requirement_type == REQUIREMENT_TOTAL_GAMES:
		return total_games >= int(requirement.get("count", 0))
	if requirement_type != REQUIREMENT_SOURCE:
		return false
	var required_source_type: String = String(requirement.get("source_type", SOURCE_NONE)).to_lower()
	var required_source_id: String = _normalize_source_id(String(requirement.get("source_id", "")))
	var required_difficulty: String = String(requirement.get("difficulty", "")).to_lower()
	if source_type.to_lower() != required_source_type:
		return false
	if _normalize_source_id(source_id) != required_source_id:
		return false
	if required_difficulty == "":
		return true
	return _level_for_difficulty(difficulty_name) >= _level_for_difficulty(required_difficulty)

static func _requirements(level_requirements: Array[Dictionary]) -> Array[Dictionary]:
	return level_requirements

static func _difficulty_requirements(source_type: String, source_id: String) -> Array[Dictionary]:
	return _requirements([
		_source_requirement(1, source_type, source_id, "easy"),
		_source_requirement(2, source_type, source_id, "normal"),
		_source_requirement(3, source_type, source_id, "hard")
	])

static func _source_requirement(level: int, source_type: String, source_id: String, difficulty: String) -> Dictionary:
	return {
		"type": REQUIREMENT_SOURCE,
		"level": level,
		"source_type": source_type,
		"source_id": source_id,
		"difficulty": difficulty
	}

static func _total_games_requirement(level: int, count: int) -> Dictionary:
	return {
		"type": REQUIREMENT_TOTAL_GAMES,
		"level": level,
		"count": count
	}

static func get_resource_bonuses(card_ids: Array[String]) -> Dictionary:
	var bonuses: Dictionary = {}
	for card_id: String in card_ids:
		var level: int = get_card_level(card_id)
		if level <= 0:
			continue
		var card: Dictionary = get_card(card_id)
		if String(card.get("bonus_type", "")) != BONUS_RESOURCE:
			continue
		var resource_type: ResourcesEnum.Type = int(card.get("resource_type", ResourcesEnum.Type.GOLD))
		var amount: int = get_card_bonus_amount(card_id, level)
		bonuses[resource_type] = int(bonuses.get(resource_type, 0)) + amount
	return bonuses

static func get_unit_bonuses(card_ids: Array[String]) -> Dictionary:
	var bonuses: Dictionary = {}
	for card_id: String in card_ids:
		var level: int = get_card_level(card_id)
		if level <= 0:
			continue
		var card: Dictionary = get_card(card_id)
		if String(card.get("bonus_type", "")) != BONUS_UNIT:
			continue
		var soldier_type: SoldierTypeEnum.Type = int(card.get("soldier_type", SoldierTypeEnum.Type.PEASANTS))
		var amount: int = get_card_bonus_amount(card_id, level)
		bonuses[soldier_type] = int(bonuses.get(soldier_type, 0)) + amount
	return bonuses

static func _make_resource_card(card_id: String, resource_type: ResourcesEnum.Type, level_requirements: Array[Dictionary]) -> Dictionary:
	return {
		"id": card_id,
		"bonus_type": BONUS_RESOURCE,
		"resource_type": resource_type,
		"bonus_amounts": CARD_BONUS_LEVEL_AMOUNTS.get(card_id, []),
		"source_type": _get_first_requirement_source_type(level_requirements),
		"source_id": _get_first_requirement_source_id(level_requirements),
		"level_requirements": level_requirements,
		"color": "green"
	}

static func _make_unit_card(card_id: String, soldier_type: SoldierTypeEnum.Type, base_amount: int, level_requirements: Array[Dictionary]) -> Dictionary:
	return {
		"id": card_id,
		"bonus_type": BONUS_UNIT,
		"soldier_type": soldier_type,
		"bonus_amounts": CARD_BONUS_LEVEL_AMOUNTS.get(card_id, [base_amount, base_amount * 2, base_amount * 3]),
		"source_type": _get_first_requirement_source_type(level_requirements),
		"source_id": _get_first_requirement_source_id(level_requirements),
		"level_requirements": level_requirements,
		"color": "blue"
	}

static func _get_first_requirement_source_type(level_requirements: Array[Dictionary]) -> String:
	for requirement: Dictionary in level_requirements:
		if String(requirement.get("type", "")) == REQUIREMENT_SOURCE:
			return String(requirement.get("source_type", SOURCE_NONE))
	return SOURCE_NONE

static func _get_first_requirement_source_id(level_requirements: Array[Dictionary]) -> String:
	for requirement: Dictionary in level_requirements:
		if String(requirement.get("type", "")) == REQUIREMENT_SOURCE:
			return String(requirement.get("source_id", ""))
	return ""

static func _load_progress_config() -> ConfigFile:
	var config: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(PROGRESS_FILE_PATH):
		var error: int = config.load_encrypted_pass(PROGRESS_FILE_PATH, PROGRESS_FILE_PASSWORD)
		if error != OK:
			error = config.load(PROGRESS_FILE_PATH)
			if error == OK:
				_save_progress_config(config)
		if error != OK:
			DebugLogger.log("Upgrades", "ERROR: Failed to load upgrade progress")
	return config

static func _save_progress_config(config: ConfigFile) -> void:
	var error: int = config.save_encrypted_pass(PROGRESS_FILE_PATH, PROGRESS_FILE_PASSWORD)
	if error != OK:
		DebugLogger.log("Upgrades", "ERROR: Failed to save upgrade progress")

static func _level_for_difficulty(difficulty_name: String) -> int:
	var normalized: String = difficulty_name.to_lower()
	if normalized == "easy":
		return 1
	if normalized == "normal":
		return 2
	if normalized == "hard":
		return 3
	return 0

static func _normalize_source_id(source_id: String) -> String:
	return source_id.get_file().get_basename().strip_edges().to_lower()
