extends Control
class_name SiegePanel

var walls_breached_value: Label
var walls_damaged_value: Label
var walls_intact_value: Label
var wall_sections_total_value: Label
var gate_rows: Array[Dictionary] = []
var ram_rows: Array[HBoxContainer] = []
var ram_row_data: Array[Dictionary] = []
var siege_reserve_row: HBoxContainer
var ram_reserve_label: Label
var gate_buttons_container: HBoxContainer
var current_state: Dictionary = {}

func _ready() -> void:
	_setup_nodes()

static func build_state(region: Region, gate_state: Dictionary, ram_count: int) -> Dictionary:
	var normalized_gate_state: Dictionary = gate_state.duplicate(true) if not gate_state.is_empty() else region.get_gate_state().duplicate(true)
	var wall_state: Dictionary = region.get_wall_state()
	var gates: int = int(normalized_gate_state.get("gates", normalized_gate_state.get("gate_values", []).size()))
	var ram_hp_max: int = GameParameters.SIEGE_RAM_HP
	var ram_hp: Array[int] = []
	var active: int = min(ram_count, gates)
	for i in range(gates):
		ram_hp.append(ram_hp_max if i < active else 0)
	normalized_gate_state["ram_hp"] = ram_hp
	normalized_gate_state["ram_hp_max"] = ram_hp_max
	return {
		"wall_state": wall_state.duplicate(true),
		"gate_state": normalized_gate_state,
		"ram_count": ram_count
	}

func apply_state(state: Dictionary) -> void:
	gate_buttons_container.visible = false
	var wall_state: Dictionary = state.get("wall_state", {}).duplicate(true)
	var gate_state: Dictionary = state.get("gate_state", {}).duplicate(true)
	var ram_count: int = int(state.get("ram_count", 0))
	var gates: int = int(gate_state.get("gates", gate_state.get("gate_values", []).size()))
	var active_rams: int = int(state.get("active_rams", -1))
	var reserve_rams: int = int(state.get("reserve_rams", -1))
	if active_rams < 0:
		active_rams = min(ram_count, gates)
	if reserve_rams < 0:
		reserve_rams = max(0, ram_count - active_rams)
	_apply_wall_state(wall_state)
	_update_gate_rows(gate_state)
	_update_ram_rows(gate_state, ram_count, active_rams, reserve_rams)
	current_state = {
		"wall_state": wall_state,
		"gate_state": gate_state,
		"ram_count": ram_count,
		"active_rams": active_rams,
		"reserve_rams": reserve_rams
	}

func _setup_nodes() -> void:
	var siege_body: Control = get_node("Body")
	walls_breached_value = siege_body.get_node("Breached/Value")
	walls_damaged_value = siege_body.get_node("Danaged/Value")
	walls_intact_value = siege_body.get_node("Intact/Value")
	wall_sections_total_value = siege_body.get_node("WallSections/Value")
	gate_rows.clear()
	ram_rows.clear()
	ram_row_data.clear()
	for i in range(1, 4):
		var row: HBoxContainer = siege_body.get_node("Gate" + str(i) + "Body/Gate" + str(i))
		var name_label: Label = row.get_node("Name")
		var value_label: Label = row.get_node("Value")
		var bar: ProgressBar = row.get_node("ProgressBar")
		gate_rows.append({"container": row, "name": name_label, "value": value_label, "bar": bar})
		row.visible = false
		var ram_row: HBoxContainer = siege_body.get_node("Gate" + str(i) + "Body/Ram" + str(i))
		ram_rows.append(ram_row)
		ram_row.visible = false
		var ram_value: Label = ram_row.get_node("Value")
		var ram_bar: ProgressBar = ram_row.get_node("ProgressBar")
		ram_row_data.append({
			"container": ram_row,
			"value": ram_value,
			"bar": ram_bar
		})
	siege_reserve_row = siege_body.get_node("Reserve")
	ram_reserve_label = siege_reserve_row.get_node("Value")
	gate_buttons_container = get_node("GatesSelector")
	gate_buttons_container.visible = false

func _apply_wall_state(wall_state: Dictionary) -> void:
	var wall_sections: int = int(wall_state.get("wall_sections", 0))
	var destroyed: int = int(wall_state.get("destroyed_sections", 0))
	var damaged: int = int(wall_state.get("damaged_sections", 0))
	var intact: int = max(0, wall_sections - destroyed - damaged)
	wall_sections_total_value.text = str(wall_sections)
	walls_breached_value.text = str(destroyed)
	walls_damaged_value.text = str(damaged)
	walls_intact_value.text = str(intact)

func _update_gate_rows(gate_state: Dictionary) -> void:
	var base_hp: int = int(gate_state.get("gate_hp", 0))
	var gate_values: Array = gate_state.get("gate_values", [])
	var gates: int = int(gate_state.get("gates", gate_values.size()))
	for i in range(gate_rows.size()):
		var row_data: Dictionary = gate_rows[i]
		var container: HBoxContainer = row_data["container"]
		var ram_row: HBoxContainer = ram_rows[i]
		if i < gates and base_hp > 0:
			container.visible = true
			var name_label: Label = row_data["name"]
			var value_label: Label = row_data["value"]
			var bar: ProgressBar = row_data["bar"]
			var current_hp: float = float(base_hp)
			if i < gate_values.size():
				current_hp = float(gate_values[i])
			name_label.text = "Gate " + str(i + 1)
			var percent: int = int(round(float(current_hp) / float(base_hp) * 100.0))
			value_label.text = str(percent) + "%"
			bar.max_value = base_hp
			bar.value = current_hp
		else:
			container.visible = false
			ram_row.visible = false

func _update_ram_rows(gate_state: Dictionary, ram_total: int, active_rams: int, reserve_rams: int) -> void:
	var gates: int = int(gate_state.get("gates", 0))
	var ram_hp: Array = gate_state.get("ram_hp", [])
	var ram_hp_max: int = int(gate_state.get("ram_hp_max", GameParameters.SIEGE_RAM_HP))
	var gate_values: Array = gate_state.get("gate_values", [])
	for i in range(ram_rows.size()):
		var gate_alive := i < gate_values.size() and float(gate_values[i]) > 0.0
		var hp_val: int = ram_hp[i] if i < ram_hp.size() else 0
		var has_ram := hp_val > 0
		var visible := i < gates and gate_alive and has_ram
		ram_rows[i].visible = visible
		if not visible:
			continue
		var data: Dictionary = ram_row_data[i]
		var bar: ProgressBar = data["bar"]
		var value_label: Label = data["value"]
		var current_hp: int = hp_val
		current_hp = clampi(current_hp, 0, ram_hp_max)
		bar.max_value = ram_hp_max
		bar.value = current_hp
		var percent: int = 0
		if ram_hp_max > 0:
			percent = int(round(float(current_hp) / float(ram_hp_max) * 100.0))
		value_label.text = str(percent) + "%"
	var reserve: int = max(0, reserve_rams)
	ram_reserve_label.text = str(reserve)
