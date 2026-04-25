extends Control
class_name EditorStart

var _map_select: OptionButton
var _scenario_select: OptionButton

func _ready() -> void:
	_map_select = get_node("Center/MapSelect") as OptionButton
	_scenario_select = get_node("Center/ScenarioSelect") as OptionButton
	get_node("Center/EditMapButton").pressed.connect(_on_edit_map_pressed)
	get_node("Center/EditScenarioButton").pressed.connect(_on_edit_scenario_pressed)
	_populate_map_list()
	_populate_scenario_list()

func _populate_map_list() -> void:
	_map_select.clear()
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
	for f in files:
		_map_select.add_item(f)

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
	var filename := _map_select.get_item_text(idx)
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

func _resolve_map_size_token_for_map_file(map_file_name: String) -> String:
	var file_only: String = map_file_name.get_file()
	var file_name: String = file_only if file_only.ends_with(".json") else (file_only + ".json")
	var file_path: String = "res://mapdata/" + file_name
	var region_count: int = 0
	var content: String = FileAccess.get_file_as_string(file_path)
	if content != "":
		var json := JSON.new()
		if json.parse(content) == OK:
			var data: Variant = json.get_data()
			if typeof(data) == TYPE_DICTIONARY:
				var dict_data: Dictionary = data
				var regions_value: Variant = dict_data.get("regions", [])
				if typeof(regions_value) == TYPE_ARRAY:
					region_count = (regions_value as Array).size()
	var profile: Dictionary = Utils.resolve_map_profile(file_name, region_count)
	return String(profile.get("canonical_size_token", "small"))
