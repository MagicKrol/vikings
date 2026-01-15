extends Node
class_name AICameraDirector

var _camera: CameraController

func initialize(camera: CameraController) -> void:
	_camera = camera
	DebugLogger.log("AICamera", "AI Camera Director initialized with camera: " + str(_camera))

func _fast_forward_camera_if_needed(label: String) -> bool:
	var multiplier: float = GameParameters.get_ai_move_speed_multiplier()
	if multiplier <= GameParameters.AI_MOVE_SPEED_NORMAL:
		return false
	_camera.set_instant_mode(true)
	_camera.snap_to_target()
	_camera.set_instant_mode(false)
	DebugLogger.log("AICamera", "Camera fast-forwarded for %s (multiplier=%.1f)" % [label, multiplier], 1)
	return true

func await_focus_on_army(army: Army) -> void:
	if army == null or not is_instance_valid(army):
		DebugLogger.log("AICamera", "Requested focus on invalid army", 1)
		return
	DebugLogger.log("AICamera", "Focusing camera on army %s at %s" % [army.name, str(army.global_position)])
	_camera.center_on_army(army)
	if _fast_forward_camera_if_needed(army.name):
		return
	await _camera.await_target_reached()
	if army == null or not is_instance_valid(army):
		DebugLogger.log("AICamera", "Camera reached army (freed object)", 1)
		return
	DebugLogger.log("AICamera", "Camera reached army %s" % army.name, 1)

func await_focus_on_region(region: Region) -> void:
	if region == null or not is_instance_valid(region):
		DebugLogger.log("AICamera", "Requested focus on invalid region", 1)
		return
	var target: Vector2 = Vector2.ZERO
	var target_found := false
	var polygon := region.get_node_or_null("Polygon") as Polygon2D
	if polygon != null and polygon.get_meta_list().has("center"):
		var center_meta = polygon.get_meta("center")
		if center_meta is Vector2:
			target = region.to_global(center_meta)
			target_found = true
	elif region.center != Vector2.ZERO:
		target = region.center
		if region.get_parent() != null:
			target = region.to_global(region.center)
		target_found = true
	if not target_found:
		target = region.global_position
	DebugLogger.log("AICamera", "Focusing camera on region %s at %s" % [region.name, str(target)])
	_camera.center_on_position(target)
	if _fast_forward_camera_if_needed(region.name):
		return
	await _camera.await_target_reached()
	DebugLogger.log("AICamera", "Camera reached region %s" % region.name, 1)

func await_focus_on_position(position: Vector2) -> void:
	DebugLogger.log("AICamera", "Focusing camera on position %s" % str(position))
	_camera.center_on_position(position)
	if _fast_forward_camera_if_needed(str(position)):
		return
	await _camera.await_target_reached()
	DebugLogger.log("AICamera", "Camera reached position %s" % str(position), 1)

func await_delay(duration: float) -> void:
	if duration <= 0.0:
		DebugLogger.log("AICamera", "Delay skipped (<=0)", 1)
		return
	var multiplier: float = max(GameParameters.get_ai_move_speed_multiplier(), GameParameters.AI_MOVE_SPEED_NORMAL)
	var scaled_duration: float = duration / multiplier
	DebugLogger.log("AICamera", "Starting camera delay: %.2fs (scaled from %.2fs, mult=%.1f)" % [scaled_duration, duration, multiplier])
	var timer := get_tree().create_timer(scaled_duration)
	await timer.timeout
	DebugLogger.log("AICamera", "Camera delay finished (%.2fs)" % scaled_duration, 1)
