extends HBoxContainer
class_name MapListRow

var _highlight_color: Color = Color(0, 0, 0, 0)

func set_highlight_color(color: Color) -> void:
	_highlight_color = color
	queue_redraw()

func _draw() -> void:
	if _highlight_color.a <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), _highlight_color, true)
