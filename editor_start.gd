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
		if f.begins_with("mapdata-") and f.to_lower().ends_with(".json"):
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
	var size_str := _extract_size_from_map_filename(filename)
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
	var size_str := _extract_size_from_map_filename(map_file)
	var payload = {
		"type": "scenario",
		"scenario_path": scen_file,
		"map_file": map_file,
		"map_size": size_str
	}
	get_tree().set_meta("editor_start_payload", payload)
	get_tree().change_scene_to_file("res://main.tscn")

func _extract_size_from_map_filename(name: String) -> String:
	# Expected: mapdata-XXX-small.json → returns "small"
	var base := name.get_basename()
	var parts := base.split("-")
	if parts.size() >= 3:
		return parts[parts.size() - 1]
	return "small"
