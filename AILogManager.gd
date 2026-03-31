extends RefCounted
class_name AILogManager

var logs_dir: String = "res://logs"
var current_file_path: String = ""
var current_game_label: String = ""
var ascii = preload("res://ascii_utils.gd")
var last_logged_turn: int = -1

func start_new_game_log(raw_label: String) -> void:
	current_game_label = _sanitize_label(raw_label)
	_prepare_logs_directory()
	last_logged_turn = -1
	var timestamp = Time.get_datetime_string_from_system(true)
	timestamp = timestamp.replace(":", "-").replace(" ", "_")
	var file_name = "%s_%s.txt" % [current_game_label, timestamp]
	current_file_path = "%s/%s" % [logs_dir, file_name]
	var header_file := _open_file(current_file_path, FileAccess.WRITE)
	header_file.store_string("AI Log File: %s\n\n" % current_game_label)
	header_file.close()

func log_turn_intro(turn_number: int, player_label: String, player_id: int, resources: Dictionary, signals: Dictionary, decision: String, region_names: Array, wealth_label: String = "", upgrade_savings_gold: int = 0) -> void:
	if turn_number != last_logged_turn:
		last_logged_turn = turn_number
		_append_turn_header(turn_number)
	var lines: Array[String] = []
	lines.append("[Player %s]" % player_label)
	var player_ascii := ascii.get_player_ascii(str(player_id))
	if player_ascii != "":
		lines.append(player_ascii)
	if wealth_label != "":
		lines.append("Wealth: %s" % wealth_label)
	lines.append("Resources:")
	for resource_type in ResourcesEnum.get_all_types():
		lines.append("%s: %d" % [ResourcesEnum.type_to_string(resource_type), int(resources.get(resource_type, 0))])
	lines.append("Upgrade Saved Gold: %d" % upgrade_savings_gold)
	lines.append("")
	lines.append("Signals:")
	lines.append("frontier_pressure: %.3f" % float(signals.get("frontier_pressure", 0.0)))
	lines.append("underpowered_ratio: %.3f" % float(signals.get("underpowered_ratio", 0.0)))
	lines.append("castle_spacing: %.3f" % float(signals.get("castle_spacing", 0.0)))
	lines.append("bank_ratio: %.3f" % float(signals.get("bank_ratio", 0.0)))
	lines.append("power_gap_norm: %.3f" % float(signals.get("power_gap_norm", 0.0)))
	lines.append("")
	lines.append("______ ECONOMY ______")
	_append_lines(lines)

func log_turn_outro(resources: Dictionary) -> void:
	var lines: Array[String] = []
	lines.append("Resources (end):")
	for resource_type in ResourcesEnum.get_all_types():
		lines.append("%s: %d" % [ResourcesEnum.type_to_string(resource_type), int(resources.get(resource_type, 0))])
	lines.append("")
	_append_lines(lines)

func log_army_action(army_name: String, power: int, efficiency: int, action: String, target_region: String, composition_suffix: String = "") -> void:
	var lines: Array[String] = []
	var label = "%s [Power: %d, E: %d" % [army_name, power, efficiency]
	if composition_suffix != "":
		label += " - %s" % composition_suffix
	label += "]"
	lines.append(label)
	lines.append("Action: %s" % action)
	if target_region != "":
		lines.append("Target: %s" % target_region)
	lines.append("")
	_append_lines(lines)

func log_army_movemement() -> void:
	var lines: Array[String] = []
	lines.append("______ ARMY ACTIONS ______")
	_append_lines(lines)

func log_recruitment(message: String) -> void:
	_append_lines(["Recruitment: %s" % message, ""])

func log_economy(message: String) -> void:
	_append_lines(["Economy: %s" % message, ""])

func log_economy_block(header: String, rows: Array) -> void:
	if rows.is_empty():
		return
	var lines: Array[String] = []
	lines.append("%s:" % header)
	for row in rows:
		lines.append("- " + String(row))
	lines.append("")
	_append_lines(lines)

func log_economy_candidates(header: String, candidates: Array) -> void:
	var is_build := header.findn("Build Castle") != -1
	if candidates.is_empty() and not is_build:
		return
	var lines: Array[String] = []
	if is_build:
		lines.append("Canidates:")
		if candidates.is_empty():
			lines.append("- none")
	for entry in candidates:
		if entry is Dictionary:
			var dict_entry: Dictionary = entry
			if dict_entry.has("strategic_score"):
				lines.append(_format_build_candidate_line(dict_entry))
			elif dict_entry.has("recruit_score") or dict_entry.has("distance_score"):
				lines.append(_format_upgrade_candidate_line(dict_entry))
			else:
				lines.append("- " + str(dict_entry))
		else:
			lines.append("- " + str(entry))
	lines.append("")
	_append_lines(lines)

func _format_build_candidate_line(entry: Dictionary) -> String:
	var name: String = String(entry.get("name", ""))
	var rid: int = int(entry.get("region_id", -1))
	var desc: String = "%s (#%d)" % [name, rid] if name != "" else "Region %d" % rid
	var total_score: float = float(entry.get("total_score", 0.0))
	var strategic_score: float = float(entry.get("strategic_score", 0.0))
	var neighbor_score: float = float(entry.get("neighbor_score", 0.0))
	var distance_status: String = String(entry.get("distance_status", ""))
	var threshold: float = float(entry.get("score_threshold", EconomyAIManager.CASTLE_SCORE_THRESHOLD))
	var score_indicator: String = ">" if bool(entry.get("score_pass", false)) else "<"
	return "- %s | total:%.1f (strategy:%.1f, neighbor:%.1f, distance_status:%s, score:%.1f%s[%.1f])" % [
		desc,
		total_score,
		strategic_score,
		neighbor_score,
		distance_status,
		total_score,
		score_indicator,
		threshold
	]

func _format_upgrade_candidate_line(entry: Dictionary) -> String:
	var name: String = String(entry.get("name", ""))
	var rid: int = int(entry.get("region_id", -1))
	var desc: String = "%s (#%d)" % [name, rid] if name != "" else "Region %d" % rid
	var total_score: float = float(entry.get("total_score", 0.0))
	var recruit_score: float = float(entry.get("recruit_score", 0.0))
	var distance_score: float = float(entry.get("distance_score", 0.0))
	var distance: int = int(entry.get("distance", 0))
	var next_type: CastleTypeEnum.Type = entry.get("next_type", CastleTypeEnum.Type.NONE)
	var next_label: String = CastleTypeEnum.type_to_string(next_type)
	return "- %s | total:%.1f (recruits:%.1f, distance:%.1f, dist:%d, next:%s)" % [
		desc,
		total_score,
		recruit_score,
		distance_score,
		distance,
		next_label
	]

func log_castle_recruitment_summary(header: String, entries: Array, fallback_reason: String) -> void:
	var lines: Array[String] = []
	if entries.size() > 0:
		lines.append("%s:" % header)
		for entry in entries:
			lines.append("- %s" % String(entry))
	else:
		lines.append("No %s (%s)" % [header, fallback_reason])
	lines.append("")
	_append_lines(lines)

func log_army_detail(detail: String) -> void:
	_append_lines([detail])

func log_army_separator(army_number: String, role_label: String) -> void:
	var safe_number: String = army_number.strip_edges()
	if safe_number == "":
		safe_number = "?"
	var safe_role: String = role_label.strip_edges()
	if safe_role == "":
		safe_role = "Unknown"
	_append_lines(["-------------- ARMY %s (%s) -------------" % [safe_number, safe_role]])

func log_army_decision_tree(army_name: String, branch: String, reason: String) -> void:
	var safe_reason: String = reason
	if safe_reason == "":
		safe_reason = "n/a"
	_append_lines(["DecisionTree: %s -> %s (%s)" % [army_name, branch, safe_reason]])

func log_siege_preparation(points: int, wood_available: int, wood_limit_label: String, purchases: Dictionary, breached: int, damaged: int) -> void:
	var lines: Array[String] = []
	lines.append("Siege equipement")
	lines.append("Available points: %d" % points)
	lines.append("Available wood: %d (%s)" % [wood_available, wood_limit_label])
	lines.append("Bought: %d Trebuchets, %d Battling Rams, %d Ladders" % [
		int(purchases.get("trebuchets", 0)),
		int(purchases.get("rams", 0)),
		int(purchases.get("ladders", 0))
	])
	lines.append("Breached sections: %d, Damaged sections: %d" % [breached, damaged])
	lines.append("")
	_append_lines(lines)

func log_siege_gate_plan(lines: Array[String]) -> void:
	if lines.is_empty():
		return
	_append_lines(lines)

func _append_turn_header(turn_number: int) -> void:
	var lines: Array[String] = []
	lines.append("--------------------------------------------------------")
	lines.append("[Turn %d]" % turn_number)
	var ascii_turn := ascii.get_ascii_number(turn_number)
	if ascii_turn != "":
		lines.append(ascii_turn)
	lines.append("--------------------------------------------------------")
	lines.append("")
	_append_lines(lines)

func _append_lines(lines: Array[String]) -> void:
	var file := _open_file(current_file_path, FileAccess.READ_WRITE)
	file.seek_end()
	for line in lines:
		file.store_string(line + "\n")
	file.close()

func _prepare_logs_directory() -> void:
	var abs_dir = ProjectSettings.globalize_path(logs_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)

func _sanitize_label(label: String) -> String:
	var cleaned = label.replace(" ", "_").to_lower()
	if cleaned == "":
		return "scenario"
	return cleaned

func _open_file(path: String, mode: FileAccess.ModeFlags) -> FileAccess:
	var abs_path = ProjectSettings.globalize_path(path)
	return FileAccess.open(abs_path, mode)
