extends Control
class_name EditorStart

var _map_select: OptionButton
var _scenario_select: OptionButton
const MAP_LIST_SIZE_ORDER: Dictionary = {
	"XS": 0,
	"S": 1,
	"M": 2,
	"L": 3
}

func _ready() -> void:
	_map_select = get_node("Center/MapSelect") as OptionButton
	_scenario_select = get_node("Center/ScenarioSelect") as OptionButton
	get_node("Center/EditMapButton").pressed.connect(_on_edit_map_pressed)
	get_node("Center/EditScenarioButton").pressed.connect(_on_edit_scenario_pressed)
	_populate_map_list()
	_populate_scenario_list()

func _populate_map_list() -> void:
	_map_select.clear()
	var scenario_map: Dictionary = _build_scenario_map_index()
	var dir := DirAccess.open("res://mapdata")
	if dir == null:
		return
	dir.list_dir_begin()
	var files: Array[String] = []
	while true:
		var f := dir.get_next()
		if f == "":
			break
		if dir.current_is_dir():
			continue
		if _is_valid_map_file(f):
			files.append(f)
	dir.list_dir_end()
	files.sort()
	var named_entries: Array[Dictionary] = []
	var unnamed_files: Array[String] = []
	for f in files:
		var metadata: Dictionary = _read_map_metadata(f)
		var display_name_key: String = String(metadata.get("display_name_key", "")).strip_edges()
		if display_name_key == "":
			unnamed_files.append(f)
			continue
		named_entries.append(_build_named_map_entry(f, metadata, scenario_map))
	named_entries.sort_custom(_sort_named_map_entries)
	for entry in named_entries:
		_add_map_item(String(entry.get("label", "")), String(entry.get("filename", "")))
	for f in unnamed_files:
		_add_map_item(_append_scenario_suffix(f, f, scenario_map), f)

func _populate_scenario_list() -> void:
	_scenario_select.clear()
	var dir := DirAccess.open("res://scenarios")
	if dir == null:
		return
	dir.list_dir_begin()
	var files: Array[String] = []
	while true:
		var f := dir.get_next()
		if f == "":
			break
		if dir.current_is_dir():
			continue
		if f.to_lower().ends_with(".json"):
			files.append(f)
	dir.list_dir_end()
	files.sort()
	for f in files:
		_scenario_select.add_item(f)

func _on_edit_map_pressed() -> void:
	var idx := _map_select.get_selected()
	if idx < 0:
		return
	var filename: String = String(_map_select.get_item_metadata(idx))
	var size_str := _resolve_map_size_token_for_map_file(filename)
	var payload = {
		"type": "map",
		"map_file": filename,
		"map_size": size_str
	}
	get_tree().set_meta("editor_start_payload", payload)
	get_tree().change_scene_to_file("res://main.tscn")

func _on_edit_scenario_pressed() -> void:
	var idx := _scenario_select.get_selected()
	if idx < 0:
		return
	var scen_file := _scenario_select.get_item_text(idx)
	# Load scenario to get map_file and infer map size
	var scen := ScenarioManager.new().load_scenario(scen_file)
	var map_file := String(scen.get("map_file", "")).get_file()
	var size_str := _resolve_map_size_token_for_map_file(map_file)
	var payload = {
		"type": "scenario",
		"scenario_path": scen_file,
		"map_file": map_file,
		"map_size": size_str
	}
	get_tree().set_meta("editor_start_payload", payload)
	get_tree().change_scene_to_file("res://main.tscn")

func _is_valid_map_file(filename: String) -> bool:
	"""Check if filename follows valid map file pattern (old or new format)"""
	if not filename.to_lower().ends_with(".json"):
		return false
	var token: String = Utils.extract_map_size_token(filename)
	if token == "":
		return false
	if token.is_valid_int():
		return int(token) > 0
	var canonical: String = Utils.canonical_label_from_token(token)
	return canonical != ""

func _add_map_item(label: String, filename: String) -> void:
	var item_index: int = _map_select.item_count
	_map_select.add_item(label)
	_map_select.set_item_metadata(item_index, filename)

func _build_named_map_entry(filename: String, metadata: Dictionary, scenario_map: Dictionary) -> Dictionary:
	var region_count: int = int(metadata.get("region_count", 0))
	var frontend_region_count: int = int(metadata.get("non_ocean_region_count", 0))
	var profile: Dictionary = Utils.resolve_map_profile(filename, region_count, frontend_region_count)
	var size_code: String = String(profile.get("frontend_size_code", "S"))
	var display_name: String = _resolve_map_display_name(filename, metadata)
	var preview_marker: String = "+" if _map_preview_exists(filename) else "-"
	var label: String = _append_scenario_suffix(size_code + " " + display_name + " " + preview_marker, filename, scenario_map)
	return {
		"filename": filename,
		"label": label,
		"display_name": display_name,
		"size_order": int(MAP_LIST_SIZE_ORDER.get(size_code, 99))
	}

func _sort_named_map_entries(a: Dictionary, b: Dictionary) -> bool:
	var a_size_order: int = int(a.get("size_order", 99))
	var b_size_order: int = int(b.get("size_order", 99))
	if a_size_order != b_size_order:
		return a_size_order < b_size_order
	var a_name: String = String(a.get("display_name", ""))
	var b_name: String = String(b.get("display_name", ""))
	return a_name.nocasecmp_to(b_name) < 0

func _resolve_map_display_name(filename: String, metadata: Dictionary) -> String:
	var display_name_key: String = String(metadata.get("display_name_key", "")).strip_edges()
	if display_name_key != "":
		return tr(display_name_key)
	return filename

func _map_preview_exists(filename: String) -> bool:
	var preview_path: String = "res://previews/" + filename.get_basename() + ".png"
	return FileAccess.file_exists(preview_path)

func _read_map_metadata(filename: String) -> Dictionary:
	var result: Dictionary = {
		"region_count": 0,
		"non_ocean_region_count": 0,
		"display_name_key": ""
	}
	var file_path: String = "res://mapdata/" + filename
	var content: String = FileAccess.get_file_as_string(file_path)
	if content == "":
		return result
	var json: JSON = JSON.new()
	if json.parse(content) != OK:
		return result
	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return result
	var dict_data: Dictionary = data
	result["display_name_key"] = String(dict_data.get("display_name_key", "")).strip_edges()
	var regions_value: Variant = dict_data.get("regions", [])
	if typeof(regions_value) == TYPE_ARRAY:
		var regions_array: Array = regions_value as Array
		result["region_count"] = regions_array.size()
		result["non_ocean_region_count"] = _resolve_non_ocean_region_count(dict_data, regions_array)
	return result

func _resolve_non_ocean_region_count(map_data: Dictionary, regions_array: Array) -> int:
	var stored_count: int = int(map_data.get("non_ocean_region_count", 0))
	if stored_count > 0:
		return stored_count
	var count: int = 0
	for raw_region in regions_array:
		if not (raw_region is Dictionary):
			continue
		var region_data: Dictionary = raw_region as Dictionary
		var biome_name: String = String(region_data.get("biome", "")).to_lower()
		if bool(region_data.get("ocean", false)) or biome_name == "ocean":
			continue
		count += 1
	return count

func _build_scenario_map_index() -> Dictionary:
	var result: Dictionary = {}
	var dir := DirAccess.open("res://scenarios")
	if dir == null:
		return result
	dir.list_dir_begin()
	var scenario_files: Array[String] = []
	while true:
		var f := dir.get_next()
		if f == "":
			break
		if dir.current_is_dir():
			continue
		if f.to_lower().ends_with(".json"):
			scenario_files.append(f)
	dir.list_dir_end()
	scenario_files.sort()
	for scenario_file in scenario_files:
		var map_file: String = _read_scenario_map_file(scenario_file)
		if map_file == "":
			continue
		var raw_scenario_names: Variant = result.get(map_file, [])
		var scenario_names: Array = raw_scenario_names as Array
		scenario_names.append(scenario_file)
		result[map_file] = scenario_names
	return result

func _read_scenario_map_file(scenario_filename: String) -> String:
	var scenario_path: String = "res://scenarios/" + scenario_filename
	var content: String = FileAccess.get_file_as_string(scenario_path)
	if content == "":
		return ""
	var json: JSON = JSON.new()
	if json.parse(content) != OK:
		return ""
	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	var scenario_data: Dictionary = data
	return _normalize_map_filename(String(scenario_data.get("map_file", "")).get_file())

func _normalize_map_filename(filename: String) -> String:
	var clean_filename: String = filename.strip_edges()
	if clean_filename == "":
		return ""
	if clean_filename.ends_with(".json"):
		return clean_filename
	return clean_filename + ".json"

func _append_scenario_suffix(label: String, filename: String, scenario_map: Dictionary) -> String:
	var scenario_names: Array[String] = _get_scenario_names_for_map(filename, scenario_map)
	if scenario_names.is_empty():
		return label
	return label + " [" + _join_strings(scenario_names, ", ") + "]"

func _join_strings(values: Array[String], separator: String) -> String:
	var result: String = ""
	for value in values:
		if result != "":
			result += separator
		result += value
	return result

func _get_scenario_names_for_map(filename: String, scenario_map: Dictionary) -> Array[String]:
	var scenario_names: Array[String] = []
	var raw_names: Variant = scenario_map.get(_normalize_map_filename(filename), [])
	if raw_names is Array:
		for raw_name in raw_names:
			scenario_names.append(String(raw_name))
	return scenario_names

func _resolve_map_size_token_for_map_file(map_file_name: String) -> String:
	var file_only: String = map_file_name.get_file()
	var file_name: String = file_only if file_only.ends_with(".json") else (file_only + ".json")
	var metadata: Dictionary = _read_map_metadata(file_name)
	var region_count: int = int(metadata.get("region_count", 0))
	var frontend_region_count: int = int(metadata.get("non_ocean_region_count", 0))
	var profile: Dictionary = Utils.resolve_map_profile(file_name, region_count, frontend_region_count)
	return String(profile.get("canonical_size_token", "small"))
