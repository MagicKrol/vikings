extends Control
class_name MainMenuSaveGameModal

signal back_requested
signal action_requested(mode: int, selected_file_name: String, entered_file_name: String)

enum Mode {
	SAVE,
	LOAD
}

@onready var header_label: Label = get_node("Panel/VBoxContainer/HeaderLabel") as Label
@onready var back_button: Button = get_node("Panel/VBoxContainer/BackRow/BackButton") as Button
@onready var action_button: Button = get_node("Panel/VBoxContainer/ActionRow/ActionButton") as Button
@onready var file_name_label: Label = get_node("Panel/VBoxContainer/FileNameLabel") as Label
@onready var file_name_input: LineEdit = get_node("Panel/VBoxContainer/FileNameInput") as LineEdit
@onready var load_margin: MarginContainer = get_node("Panel/VBoxContainer/LoadMargin") as MarginContainer
@onready var scroll_container: ScrollContainer = get_node("Panel/VBoxContainer/ScrollContainer") as ScrollContainer
@onready var army_texture: TextureRect = get_node("Panel/ArmyTexture") as TextureRect
@onready var save_list: VBoxContainer = get_node("Panel/VBoxContainer/ScrollContainer/SaveList") as VBoxContainer
@onready var row_template: HBoxContainer = get_node("Panel/VBoxContainer/ScrollContainer/SaveList/RowTemplate") as HBoxContainer

var current_mode: Mode = Mode.LOAD
var selected_row: HBoxContainer
var selected_file_name: String = ""
var base_scroll_height: float = 0.0
var base_army_texture_bottom: float = 0.0

const LOAD_LAYOUT_EXTRA_HEIGHT: float = 72.0

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	action_button.pressed.connect(_on_action_pressed)
	row_template.visible = false
	selected_row = row_template
	base_scroll_height = scroll_container.custom_minimum_size.y
	base_army_texture_bottom = army_texture.offset_bottom
	set_mode(Mode.LOAD)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			_on_back_pressed()

func configure(mode: Mode, entries: Array[Dictionary]) -> void:
	set_mode(mode)
	populate_save_list(entries)

func set_mode(mode: Mode) -> void:
	current_mode = mode
	if current_mode == Mode.SAVE:
		header_label.text = tr("Save Game")
		action_button.text = tr("Save Game")
		file_name_label.visible = true
		file_name_input.visible = true
		load_margin.visible = false
		_apply_layout_height(0.0)
		return
	header_label.text = tr("Load Game")
	action_button.text = tr("Load Game")
	file_name_label.visible = false
	file_name_input.visible = false
	load_margin.visible = false
	_apply_layout_height(LOAD_LAYOUT_EXTRA_HEIGHT)

func _apply_layout_height(extra_height: float) -> void:
	var scroll_size: Vector2 = scroll_container.custom_minimum_size
	scroll_size.y = base_scroll_height + extra_height
	scroll_container.custom_minimum_size = scroll_size
	army_texture.offset_bottom = base_army_texture_bottom + extra_height

func populate_save_list(entries: Array[Dictionary]) -> void:
	_clear_dynamic_rows()
	var row_index: int = 0
	for entry in entries:
		var row: HBoxContainer = row_template.duplicate() as HBoxContainer
		row.visible = true
		var file_name: String = String(entry.get("file_name", ""))
		var game_type: String = String(entry.get("type", ""))
		var save_date: String = String(entry.get("date", ""))
		var name_label: Label = row.get_node("GameName") as Label
		var type_label: Label = row.get_node("GameType") as Label
		var date_label: Label = row.get_node("GameDate") as Label
		name_label.text = file_name
		type_label.text = game_type
		date_label.text = save_date
		row.gui_input.connect(Callable(self, "_on_row_gui_input").bind(row, file_name))
		save_list.add_child(row)
		row_index += 1
		if row_index == 1:
			_set_selected_row(row, file_name)
	if row_index == 0:
		file_name_input.text = ""

func _clear_dynamic_rows() -> void:
	for child in save_list.get_children():
		if child == row_template:
			continue
		save_list.remove_child(child)
		child.queue_free()
	selected_row = row_template
	selected_file_name = ""

func _on_row_gui_input(event: InputEvent, row: HBoxContainer, file_name: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_set_selected_row(row, file_name)

func _set_selected_row(row: HBoxContainer, file_name: String) -> void:
	_set_row_selected(selected_row, false)
	selected_row = row
	selected_file_name = file_name
	_set_row_selected(selected_row, true)
	if current_mode == Mode.SAVE:
		file_name_input.text = selected_file_name

func _set_row_selected(row: HBoxContainer, is_selected: bool) -> void:
	var color: Color = Color(0.945098, 0.847059, 0.568627, 1.0) if is_selected else Color(1.0, 1.0, 1.0, 1.0)
	var name_label: Label = row.get_node("GameName") as Label
	var type_label: Label = row.get_node("GameType") as Label
	var date_label: Label = row.get_node("GameDate") as Label
	name_label.add_theme_color_override("font_color", color)
	type_label.add_theme_color_override("font_color", color)
	date_label.add_theme_color_override("font_color", color)

func _on_back_pressed() -> void:
	visible = false
	get_viewport().set_input_as_handled()
	back_requested.emit()

func _on_action_pressed() -> void:
	action_requested.emit(int(current_mode), selected_file_name, file_name_input.text.strip_edges())
