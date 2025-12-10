extends RefCounted
class_name TutorialManager

var region_manager: RegionManager
var tutorial_modal: TutorialModal
var message_modal: MessageModal
var camera: Camera2D
var ai_camera_director: AICameraDirector

var active: bool = false
var step_index: int = -1
var expected_region_id: int = -1
var expected_action: String = ""
var tutorial_player_id: int = 1
var expected_ui_target: String = ""
var steps: Array = []

func _init(region_mgr: RegionManager, tutorial_ui: TutorialModal, msg_modal: MessageModal, cam: Camera2D, camera_director: AICameraDirector) -> void:
	region_manager = region_mgr
	tutorial_modal = tutorial_ui
	message_modal = msg_modal
	camera = cam
	ai_camera_director = camera_director
	_connect_message_signal()
	DebugLogger.log("Tutorial", "TutorialManager initialized")
	steps = _build_default_steps()

func is_active() -> bool:
	return active

func get_expected_action() -> String:
	return expected_action

func is_ui_step_active() -> bool:
	return active and expected_action == "ui"

func get_expected_ui_target() -> String:
	return expected_ui_target

func start_tutorial(player_id: int) -> void:
	active = true
	step_index = -1
	tutorial_player_id = player_id
	DebugLogger.log("Tutorial", "Starting tutorial for player " + str(player_id))
	_advance_step()
	return

func handle_region_click(region: Region) -> bool:
	if not active:
		return true
	if expected_action != "region":
		DebugLogger.log("Tutorial", "Region click ignored, expected action: " + expected_action)
		return true
	if region == null:
		return false
	if region.get_region_id() != expected_region_id:
		DebugLogger.log("Tutorial", "Region click wrong target: " + str(region.get_region_id()) + " expected " + str(expected_region_id))
		return false
	DebugLogger.log("Tutorial", "Region click matched tutorial target: " + str(region.get_region_id()))
	_advance_step()
	return true

func _on_continue_clicked() -> void:
	DebugLogger.log("Tutorial", "Continue clicked, expected_action=" + expected_action + ", active=" + str(active))
	if not active:
		return
	if expected_action == "continue":
		_advance_step()
	else:
		DebugLogger.log("Tutorial", "Continue ignored; expected_action is not continue")

func handle_ui_click(target: String) -> void:
	if not active:
		return
	if expected_action != "ui":
		return
	if target != expected_ui_target:
		DebugLogger.log("Tutorial", "UI click ignored, expected " + expected_ui_target + ", got " + target)
		return
	DebugLogger.log("Tutorial", "UI click matched target: " + target)
	_advance_step()

func _advance_step() -> void:
	step_index += 1
	expected_region_id = -1
	expected_action = ""
	if tutorial_modal:
		tutorial_modal.hide_all_arrows()
	_connect_message_signal()
	DebugLogger.log("Tutorial", "Advancing to step " + str(step_index))
	if step_index >= steps.size():
		_finish()
		return
	_apply_step(steps[step_index])

func _connect_message_signal() -> void:
	if message_modal:
		var cb = Callable(self, "_on_continue_clicked")
		if not message_modal.continue_clicked.is_connected(cb):
			message_modal.continue_clicked.connect(cb)

func _finish() -> void:
	active = false
	if tutorial_modal:
		tutorial_modal.hide_all_arrows()
	if message_modal:
		message_modal.hide_modal()

func is_waiting_for_region() -> bool:
	return active and expected_action == "region"

func _apply_step(step: Dictionary) -> void:
	expected_action = String(step.get("expected_action", ""))
	expected_ui_target = String(step.get("ui_target", ""))
	if message_modal:
		message_modal.hide_modal()
		await Engine.get_main_loop().process_frame
		var text = String(step.get("message", ""))
		var show_continue = bool(step.get("show_continue", false))
		var block_input = bool(step.get("block_input", true))
		var panel_pos: Vector2 = step.get("panel_position", Vector2.INF)
		message_modal.show_tutorial_message(text, show_continue, block_input)
		if panel_pos != Vector2.INF:
			message_modal.set_panel_position(panel_pos)
		else:
			message_modal.reset_panel_position()
	var focus_data: Dictionary = step.get("camera_focus", {})
	if not focus_data.is_empty():
		await _apply_camera_focus(focus_data)
	var arrow_data: Dictionary = step.get("arrow", {})
	if not arrow_data.is_empty() and tutorial_modal:
		var arrow_id = String(arrow_data.get("id", ""))
		var anchor = String(arrow_data.get("anchor", "screen"))
		var rotation = float(arrow_data.get("rotation", 0.0))
		var offset: Vector2 = arrow_data.get("offset", Vector2.ZERO)
		if anchor == "world":
			var region_id = int(arrow_data.get("region_id", -1))
			if region_id != -1:
				var region = region_manager.map_generator.get_region_container_by_id(region_id) as Region
				if region != null:
					var world_pos = region.to_global(region.center) + offset
					tutorial_modal.set_camera(camera)
					tutorial_modal.show_arrow(arrow_id, Vector2.ZERO, true, world_pos, rotation)
		else:
			var pos: Vector2 = arrow_data.get("screen_pos", Vector2.ZERO) + offset
			tutorial_modal.show_arrow(arrow_id, pos, false, Vector2.ZERO, rotation)
	if expected_action == "region":
		expected_region_id = int(step.get("target_region_id", -1))
		if expected_region_id == -1:
			expected_region_id = _get_player_castle_region()
	if tutorial_modal:
		DebugLogger.log("Tutorial", "Applying step: action=" + expected_action + ", arrow_keys=" + str(tutorial_modal.arrows.keys()) + ", arrow_exists=" + str(tutorial_modal.arrows.has("1")))

func _get_player_castle_region() -> int:
	return region_manager.get_castle_starting_position(tutorial_player_id)

func _build_default_steps() -> Array:
	var castle_region = _get_player_castle_region()
	return [
		{
			"message": "Welcome to the tutorial",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue"
		},
		{
			"message": "This is your home region.\n Click on it",
			"show_continue": false,
			"block_input": false,
			"expected_action": "region",
			"target_region_id": 190,
			"panel_position": Vector2(300, 450),
			"arrow": {
				"id": "1",
				"anchor": "world",
				"region_id": 190,
				"offset": Vector2(-150, 0),
				"rotation": -25.0
			},
			"camera_focus": {"type": "region", "region_id": 190}
		},
		{
			"message": "Now, select your army from the region's list.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "GeneralSelectModal/ArmyButton0",
			"panel_position": Vector2(350, 700),
			"arrow": {
				"id": "1",
				"anchor": "screen"
			}
		},
		{
			"message": "Before we jump into battle. Let's recruit more soldiers.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "ArmySelectModal/recruit_soldiers",
			"panel_position": Vector2(350, 700),
			"arrow": {
				"id": "2",
				"anchor": "screen"
			}
		},
		{
			"message": "Add some archers to you army.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "RecruitmentModal/Archers/Button10",
			"panel_position": Vector2(150, 500),
			"arrow": {
				"id": "3",
				"anchor": "screen"
			}
		}
	]

func _apply_camera_focus(focus_data: Dictionary) -> void:
	if ai_camera_director == null:
		return
	var focus_type = String(focus_data.get("type", ""))
	if focus_type == "region":
		var rid = int(focus_data.get("region_id", -1))
		if rid == -1:
			rid = _get_player_castle_region()
		if rid == -1:
			return
		var region = region_manager.map_generator.get_region_container_by_id(rid) as Region
		if region != null:
			await ai_camera_director.await_focus_on_region(region)
	elif focus_type == "position":
		var pos: Vector2 = focus_data.get("position", Vector2.ZERO)
		await ai_camera_director.await_focus_on_position(pos)
