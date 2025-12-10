extends Node
class_name AICameraDirector

var _camera: CameraController

func initialize(camera: CameraController) -> void:
	_camera = camera
	DebugLogger.log("AICamera", "AI Camera Director initialized with camera: " + str(_camera))

func await_focus_on_army(army: Army) -> void:
	if army == null or not is_instance_valid(army):
		DebugLogger.log("AICamera", "Requested focus on invalid army", 1)
		return
	DebugLogger.log("AICamera", "Focusing camera on army %s at %s" % [army.name, str(army.global_position)])
	_camera.center_on_army(army)
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
	await _camera.await_target_reached()
	DebugLogger.log("AICamera", "Camera reached region %s" % region.name, 1)

func await_focus_on_position(position: Vector2) -> void:
	DebugLogger.log("AICamera", "Focusing camera on position %s" % str(position))
	_camera.center_on_position(position)
	await _camera.await_target_reached()
	DebugLogger.log("AICamera", "Camera reached position %s" % str(position), 1)

func await_delay(duration: float) -> void:
	if duration <= 0.0:
		DebugLogger.log("AICamera", "Delay skipped (<=0)", 1)
		return
	DebugLogger.log("AICamera", "Starting camera delay: %.2fs" % duration)
	var timer := get_tree().create_timer(duration)
	await timer.timeout
	DebugLogger.log("AICamera", "Camera delay finished (%.2fs)" % duration, 1)
