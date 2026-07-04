extends ScrollContainer
class_name TouchScrollContainer

const TOUCH_SCROLL_THRESHOLD: float = 4.0

var _touch_active: bool = false
var _touch_index: int = -1
var _last_touch_position: Vector2 = Vector2.ZERO
var _touch_dragging: bool = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_touch_active = true
			_touch_index = touch_event.index
			_last_touch_position = touch_event.position
			_touch_dragging = false
			accept_event()
			return
		if _touch_active and touch_event.index == _touch_index:
			_touch_active = false
			_touch_index = -1
			_touch_dragging = false
			accept_event()
			return

	if event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		if not _touch_active:
			return
		if drag_event.index != _touch_index:
			return
		var delta_y: float = _last_touch_position.y - drag_event.position.y
		_last_touch_position = drag_event.position
		if absf(delta_y) < TOUCH_SCROLL_THRESHOLD and not _touch_dragging:
			return
		_touch_dragging = true
		var next_scroll: int = scroll_vertical + int(delta_y)
		scroll_vertical = clampi(next_scroll, 0, int(get_v_scroll_bar().max_value))
		accept_event()
