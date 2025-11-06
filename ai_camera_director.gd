extends Node
class_name AICameraDirector

var _camera: CameraController

func initialize(camera: CameraController) -> void:
	_camera = camera

func await_focus_on_army(army: Army) -> void:
	_camera.center_on_army(army)
	await _camera.await_target_reached()

func await_focus_on_region(region: Region) -> void:
	if region == null or not is_instance_valid(region):
		return
	var target: Vector2 = Vector2.ZERO
	var target_found := false
	var polygon := region.get_node_or_null("Polygon") as Polygon2D
	if polygon != null:
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
	_camera.center_on_position(target)
	await _camera.await_target_reached()

func await_focus_on_position(position: Vector2) -> void:
	_camera.center_on_position(position)
	await _camera.await_target_reached()

func await_delay(duration: float) -> void:
	if duration <= 0.0:
		return
	var timer := get_tree().create_timer(duration)
	await timer.timeout
