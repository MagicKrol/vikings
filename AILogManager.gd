extends RefCounted
class_name AILogManager

var logs_dir: String = "res://logs"
var current_file_path: String = ""
var current_game_label: String = ""

func start_new_game_log(raw_label: String) -> void:
	current_game_label = _sanitize_label(raw_label)
	_prepare_logs_directory()
	var timestamp = Time.get_datetime_string_from_system(true)
	timestamp = timestamp.replace(":", "-").replace(" ", "_")
	var file_name = "%s_%s.txt" % [current_game_label, timestamp]
	current_file_path = "%s/%s" % [logs_dir, file_name]
	var header_file := _open_file(current_file_path, FileAccess.WRITE)
	header_file.store_string("AI Log File: %s\n\n" % current_game_label)
	header_file.close()

func log_turn_intro(turn_number: int, player_label: String, resources: Dictionary, signals: Dictionary, decision: String, region_names: Array, wealth_label: String = "") -> void:
	var lines: Array[String] = []
	lines.append("-------")
	lines.append("[Turn %d]" % turn_number)
	lines.append("-------")
	lines.append("[Player %s]" % player_label)
	if wealth_label != "":
		lines.append("Wealth: %s" % wealth_label)
	lines.append("Resources:")
	for resource_type in ResourcesEnum.get_all_types():
		lines.append("%s: %d" % [ResourcesEnum.type_to_string(resource_type), int(resources.get(resource_type, 0))])
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
