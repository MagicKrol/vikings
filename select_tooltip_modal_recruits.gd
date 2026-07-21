extends Control
class_name SelectTooltipModalRecruits

const ROW_HEIGHT: float = 28.0
const VERTICAL_PADDING: float = 30.0
const MINIMUM_HEIGHT: float = 240.0

@onready var rows_container: VBoxContainer = get_node("MarginContainer/Rows") as VBoxContainer
@onready var row_template: HBoxContainer = get_node("MarginContainer/Rows/RowTemplate") as HBoxContainer

func _ready() -> void:
	visible = false

func show_recruits(region_rows: Array[Dictionary]) -> void:
	_clear_rows()
	for row_index: int in range(region_rows.size()):
		var row_data: Dictionary = region_rows[row_index]
		var row: HBoxContainer = row_template.duplicate() as HBoxContainer
		row.name = "RegionRow%d" % row_index
		row.visible = true
		(row.get_node("RegionName") as Label).text = String(row_data.get("region_name", ""))
		(row.get_node("Available") as Label).text = str(int(row_data.get("available", 0)))
		(row.get_node("Maximum") as Label).text = str(int(row_data.get("maximum", 0)))
		(row.get_node("Replenish") as Label).text = String(row_data.get("replenish", "+0.0"))
		rows_container.add_child(row)
	size.y = maxf(MINIMUM_HEIGHT, VERTICAL_PADDING + ROW_HEIGHT * float(region_rows.size()))
	visible = true

func hide_tooltip() -> void:
	visible = false

func _clear_rows() -> void:
	for child: Node in rows_container.get_children():
		if child == row_template:
			continue
		rows_container.remove_child(child)
		child.queue_free()
