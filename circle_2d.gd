extends Node2D

class_name Circle2D

@export var radius: float = 4.0 : set = set_radius
@export var color: Color = Color.BLACK : set = set_color

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)

func set_radius(value: float) -> void:
	radius = max(value, 0.0)
	queue_redraw()

func set_color(value: Color) -> void:
	color = value
	queue_redraw()
