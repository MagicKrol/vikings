extends Control
class_name MoveTooltip

const MOUSE_OFFSET := Vector2(20, -10)

@onready var texture_rect: TextureRect = $TextureRect
@onready var panel: Panel = $Panel
@onready var move_containers := {
	1: $Panel/MoveContainer1,
	2: $Panel/MoveContainer2,
	3: $Panel/MoveContainer3,
	4: $Panel/MoveContainer4
}

func _ready() -> void:
	visible = false
	_disable_mouse_input(self)
	_hide_all_containers()

func show_move_tooltip(cost: int, mouse_pos: Vector2) -> void:
	_set_active_container(cost)
	position = mouse_pos + MOUSE_OFFSET
	_clamp_to_screen()
	visible = true

func hide_tooltip() -> void:
	visible = false
	_hide_all_containers()

func update_position(mouse_pos: Vector2) -> void:
	if visible:
		position = mouse_pos + MOUSE_OFFSET
		_clamp_to_screen()

func _clamp_to_screen() -> void:
	var viewport_rect := get_viewport().get_visible_rect()
	if position.x + size.x > viewport_rect.size.x:
		position.x = viewport_rect.size.x - size.x - 10
	if position.y + size.y > viewport_rect.size.y:
		position.y = viewport_rect.size.y - size.y - 10
	if position.x < 10:
		position.x = 10
	if position.y < 10:
		position.y = 10

func _disable_mouse_input(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_disable_mouse_input(child)

func _set_active_container(cost: int) -> void:
	_hide_all_containers()
	if move_containers.has(cost):
		var container: HBoxContainer = move_containers[cost]
		container.visible = true

func _hide_all_containers() -> void:
	for container in move_containers.values():
		container.visible = false
