extends Camera2D

class_name CameraController

# Camera Controller for Map Generator
# 
# Touch Controls (macOS Trackpad):
# - Two-finger pan: Move camera around
# - Pinch gesture: Zoom in/out
# 
# Keyboard Controls (Fallback):
# - WASD or Arrow Keys: Pan camera
# - Q/E: Zoom in/out
# - R: Reset camera to center
# 
# Mouse Controls:
# - Mouse wheel: Zoom in/out
# - Shift + Left mouse drag: Pan camera (to avoid interfering with region clicking)

# Touch and gesture settings
@export var pan_speed: float = 2.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.1
@export var max_zoom: float = 5.0
@export var smooth_pan: bool = true
@export var smooth_zoom: bool = true
@export var pan_smoothing: float = 15.0
@export var zoom_smoothing: float = 12.0

# Touch tracking variables
var touch_points: Dictionary = {}
var is_panning: bool = false
var is_zooming: bool = false
var last_pan_center: Vector2
var last_zoom_distance: float
var target_position: Vector2
var target_zoom: Vector2

# Mouse drag variables
var is_mouse_dragging: bool = false
var last_mouse_position: Vector2

# Enable touch input processing
var touch_enabled: bool = true

func _ready() -> void:
	# Initialize target values to current values
	target_position = global_position
	target_zoom = zoom
	
	# Enable input processing
	set_process_input(true)
	set_process(true)

func _process(delta: float) -> void:
	# Handle continuous keyboard input for smooth movement
	_handle_continuous_keyboard_input(delta)
	
	if not touch_enabled:
		return
		
	# Smooth camera movement
	if smooth_pan:
		global_position = global_position.lerp(target_position, pan_smoothing * delta)
	else:
		global_position = target_position
		
	if smooth_zoom:
		zoom = zoom.lerp(target_zoom, zoom_smoothing * delta)
	else:
		zoom = target_zoom

func _input(event: InputEvent) -> void:
	# Handle keyboard controls for discrete actions (zoom, reset)
	if event is InputEventKey and event.pressed:
		_handle_discrete_keyboard_input(event)
	elif event is InputEventMouseButton:
		_handle_mouse_input(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
		
	# Handle macOS trackpad gestures (these work better than touch events on macOS)
	if event is InputEventMagnifyGesture:
		_handle_magnify_gesture(event)
	elif event is InputEventPanGesture:
		_handle_pan_gesture(event)
		
	if not touch_enabled:
		return
		
	# Handle touch events (fallback for other devices)
	if event is InputEventScreenTouch:
		_handle_touch_event(event)
	elif event is InputEventScreenDrag:
		_handle_drag_event(event)

func _handle_mouse_input(event: InputEventMouseButton) -> void:
	if event.pressed:
		var zoom_amount = 0.1
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var new_zoom = target_zoom * (1.0 + zoom_amount)
			target_zoom = Vector2(
				clamp(new_zoom.x, min_zoom, max_zoom),
				clamp(new_zoom.y, min_zoom, max_zoom)
			)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var new_zoom = target_zoom * (1.0 - zoom_amount)
			target_zoom = Vector2(
				clamp(new_zoom.x, min_zoom, max_zoom),
				clamp(new_zoom.y, min_zoom, max_zoom)
			)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# Only start drag if a modifier key is held (e.g., Shift)
			# This allows region clicking without camera interference
			if Input.is_key_pressed(KEY_SHIFT):
				is_mouse_dragging = true
				last_mouse_position = event.position
	else:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Stop mouse drag
			is_mouse_dragging = false

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if is_mouse_dragging:
		var mouse_delta = last_mouse_position - event.position
		var pan_delta = mouse_delta * pan_speed / zoom.x
		target_position += pan_delta
		last_mouse_position = event.position
	

func _handle_continuous_keyboard_input(delta: float) -> void:
	"""Handle continuous keyboard input for smooth camera movement"""
	var pan_speed_per_second = 400.0 / zoom.x  # Pixels per second, scaled by zoom
	var pan_amount = pan_speed_per_second * delta
	
	# Check for continuous movement keys
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		target_position.y -= pan_amount
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		target_position.y += pan_amount
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		target_position.x -= pan_amount
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		target_position.x += pan_amount

func _handle_discrete_keyboard_input(event: InputEventKey) -> void:
	"""Handle discrete keyboard input for zoom and reset actions"""
	var zoom_amount = 0.2  # Increased zoom speed
	
	match event.keycode:
		KEY_Q:
			var new_zoom = target_zoom * (1.0 + zoom_amount)
			target_zoom = Vector2(
				clamp(new_zoom.x, min_zoom, max_zoom),
				clamp(new_zoom.y, min_zoom, max_zoom)
			)
		KEY_E:
			var new_zoom = target_zoom * (1.0 - zoom_amount)
			target_zoom = Vector2(
				clamp(new_zoom.x, min_zoom, max_zoom),
				clamp(new_zoom.y, min_zoom, max_zoom)
			)
		KEY_R:
			# Reset camera
			reset_camera()

func _handle_touch_event(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Touch started
		touch_points[event.index] = event.position
	else:
		# Touch ended
		if event.index in touch_points:
			touch_points.erase(event.index)
		
	# Update gesture states based on number of active touches
	_update_gesture_state()

func _handle_drag_event(event: InputEventScreenDrag) -> void:
	if event.index in touch_points:
		touch_points[event.index] = event.position
		
	_update_gesture_state()
	
	# Handle two-finger pan
	if is_panning and touch_points.size() == 2:
		var current_center = _get_touch_center()
		if last_pan_center != Vector2.ZERO:
			var delta_pan = (last_pan_center - current_center) * pan_speed / zoom.x
			target_position += delta_pan
		last_pan_center = current_center

func _handle_magnify_gesture(event: InputEventMagnifyGesture) -> void:
	# Handle pinch-to-zoom using magnify gesture (preferred on macOS)
	var zoom_factor = event.factor
	var new_zoom = target_zoom * zoom_factor
	target_zoom = Vector2(
		clamp(new_zoom.x, min_zoom, max_zoom),
		clamp(new_zoom.y, min_zoom, max_zoom)
	)

func _handle_pan_gesture(event: InputEventPanGesture) -> void:
	# Handle two-finger pan gesture (macOS trackpad primary method)
	var pan_delta = event.delta * pan_speed / zoom.x
	target_position += pan_delta

func _update_gesture_state() -> void:
	var touch_count = touch_points.size()
	
	if touch_count == 2:
		if not is_panning:
			is_panning = true
			last_pan_center = _get_touch_center()

		if not is_zooming:
			is_zooming = true
			last_zoom_distance = _get_touch_distance()
			
		# Handle manual zoom calculation for touch points
		var current_distance = _get_touch_distance()
		if is_zooming and last_zoom_distance > 0:
			var zoom_factor = current_distance / last_zoom_distance
			var new_zoom = target_zoom * zoom_factor
			target_zoom = Vector2(
				clamp(new_zoom.x, min_zoom, max_zoom),
				clamp(new_zoom.y, min_zoom, max_zoom)
			)
		last_zoom_distance = current_distance
	else:
		if is_panning:
			is_panning = false
			last_pan_center = Vector2.ZERO
		if is_zooming:
			is_zooming = false
			last_zoom_distance = 0.0
			
func _get_touch_center() -> Vector2:
	if touch_points.size() < 2:
		return Vector2.ZERO
		
	var center = Vector2.ZERO
	for pos in touch_points.values():
		center += pos
	return center / touch_points.size()

func _get_touch_distance() -> float:
	if touch_points.size() < 2:
		return 0.0
		
	var positions = touch_points.values()
	return positions[0].distance_to(positions[1])

# Public methods for external control
func set_camera_target(pos: Vector2) -> void:
	target_position = pos

func set_zoom_target(zoom_level: float) -> void:
	target_zoom = Vector2(zoom_level, zoom_level)

func reset_camera() -> void:
	target_position = Vector2.ZERO
	target_zoom = Vector2.ONE

func enable_touch_controls(enable: bool) -> void:
	touch_enabled = enable
	if not enable:
		# Reset gesture states
		is_panning = false
		is_zooming = false
		touch_points.clear()
