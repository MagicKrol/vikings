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

func _convert_size_name(old_size: String) -> String:
	"""Convert old size names to new display names: XTiny->Small, Tiny->Medium, Small->Large, Medium->Huge"""
	var size_lower = old_size.to_lower()
	match size_lower:
		"xtiny":
			return "Small"
		"tiny":
			return "Medium"
		"small":
			return "Large"
		"medium":
			return "Huge"
		_:
			# For any other size (including already new names), just capitalize
			return old_size.capitalize()

func _is_valid_map_file(filename: String) -> bool:
	"""Check if filename follows valid map file pattern (old or new format)"""
	if not filename.to_lower().ends_with(".json"):
		return false
		
	var name_without_extension = filename.trim_suffix(".json")
	var parts = name_without_extension.split("-")
	
	# Old format: mapdata-id-size (3 parts)
	if parts.size() == 3 and parts[0] == "mapdata":
		return true
	
	# New format: MapName-id-size (at least 3 parts, but could be more for multi-word names)
	if parts.size() >= 3:
		var size_part = parts[parts.size() - 1].to_lower()
		# Check if last part is a valid size (old or new naming)
		var valid_old_sizes = ["xtiny", "tiny", "small", "medium", "large", "huge"]
		var valid_new_sizes = ["small", "medium", "large", "huge"]
		return size_part in valid_old_sizes or size_part in valid_new_sizes
	
	return false

func _extract_size_from_map_filename(name: String) -> String:
	# Expected: mapdata-XXX-small.json or Road_to_Hell-34-small.json → returns "small"
	var base := name.get_basename()
	var parts := base.split("-")
	if parts.size() >= 3:
		return parts[parts.size() - 1]
	return "small"
