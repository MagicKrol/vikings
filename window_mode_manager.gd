extends Node

const DEFAULT_WINDOWED_SIZE: Vector2i = Vector2i(1600, 900)
const MIN_WINDOWED_SIZE: Vector2i = Vector2i(640, 360)

var _windowed_size: Vector2i = DEFAULT_WINDOWED_SIZE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		_windowed_size = _sanitize_windowed_size(DisplayServer.window_get_size())

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if not _is_window_toggle_shortcut(key_event):
		return
	toggle_window_mode()
	get_viewport().set_input_as_handled()

func toggle_window_mode() -> void:
	var current_mode: int = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		_windowed_size = _sanitize_windowed_size(DisplayServer.window_get_size())
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_windowed_size = _sanitize_windowed_size(_windowed_size)
	DisplayServer.window_set_size(_windowed_size)
	_center_window(_windowed_size)

func _is_window_toggle_shortcut(key_event: InputEventKey) -> bool:
	var is_enter: bool = key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER
	return key_event.keycode == KEY_F11 or (is_enter and key_event.alt_pressed)

func _sanitize_windowed_size(window_size: Vector2i) -> Vector2i:
	var sanitized_width: int = maxi(window_size.x, MIN_WINDOWED_SIZE.x)
	var sanitized_height: int = maxi(window_size.y, MIN_WINDOWED_SIZE.y)
	return Vector2i(sanitized_width, sanitized_height)

func _center_window(window_size: Vector2i) -> void:
	var screen_index: int = DisplayServer.window_get_current_screen()
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
	var centered_offset: Vector2i = (usable_rect.size - window_size) / 2
	var centered_position: Vector2i = usable_rect.position + Vector2i(maxi(0, centered_offset.x), maxi(0, centered_offset.y))
	DisplayServer.window_set_position(centered_position)
