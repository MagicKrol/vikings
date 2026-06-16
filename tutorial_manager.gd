extends RefCounted
class_name TutorialManager

var region_manager: RegionManager
var tutorial_modal: TutorialModal
var message_modal: MessageModal
var info_modal: InfoModal
var game_manager: GameManager
var camera: Camera2D
var ai_camera_director_ref: AICameraDirector

var active: bool = false
var step_index: int = -1
var expected_region_id: int = -1
var expected_action: String = ""
var tutorial_player_id: int = 1
var expected_ui_target: String = ""
var steps: Array = []
var ai_camera_director: AICameraDirector
var _battle_finished_flag: bool = false

func _init(region_mgr: RegionManager, tutorial_ui: TutorialModal, msg_modal: MessageModal, cam: Camera2D, camera_director: AICameraDirector) -> void:
	region_manager = region_mgr
	tutorial_modal = tutorial_ui
	message_modal = msg_modal
	info_modal = message_modal.get_parent().get_node("InfoModal") as InfoModal
	game_manager = message_modal.get_node("../../GameManager") as GameManager
	camera = cam
	ai_camera_director_ref = camera_director
	_connect_message_signal()
	_connect_info_modal_signal()
	_connect_camera_signal()
	DebugLogger.log("Tutorial", "TutorialManager initialized")
	steps = _build_default_steps()

func set_ai_camera_director(director: AICameraDirector) -> void:
	ai_camera_director_ref = director

func is_active() -> bool:
	return active

func get_expected_action() -> String:
	return expected_action

func is_expected_action(action: String) -> bool:
	return active and expected_action == action

func is_ui_step_active() -> bool:
	return active and expected_action == "ui"

func get_expected_ui_target() -> String:
	return expected_ui_target

func start_tutorial(player_id: int) -> void:
	active = true
	step_index = -1
	tutorial_player_id = player_id
	_set_camera_tutorial_signal_enabled(true)
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

func should_block_region_click(button_index: int, has_selected_army: bool) -> bool:
	if not active:
		return false
	if expected_action != "region":
		return false
	if not has_selected_army:
		return false
	if step_index < 0 or step_index >= steps.size():
		return false
	var step: Dictionary = steps[step_index]
	var enforce_move_trigger_click: bool = bool(step.get("enforce_move_trigger_click", false))
	if enforce_move_trigger_click and button_index != _get_move_trigger_button():
		return true
	return false

func should_block_map_click() -> bool:
	if not active:
		return false
	if step_index < 0 or step_index >= steps.size():
		return false
	var step: Dictionary = steps[step_index]
	return bool(step.get("block_map_click", false))

func _get_move_trigger_button() -> int:
	var move_trigger_right: bool = GameParameters.get_army_move_trigger() == GameParameters.ArmyMoveTrigger.RIGHT_CLICK
	if move_trigger_right:
		return MOUSE_BUTTON_RIGHT
	return MOUSE_BUTTON_LEFT

func _get_move_click_hint_key() -> String:
	if _get_move_trigger_button() == MOUSE_BUTTON_RIGHT:
		return "tutorial_move_click_hint_right"
	return "tutorial_move_click_hint_left"

func _apply_tutorial_message_tokens(text: String) -> String:
	if text.find("{move_click_hint}") == -1:
		return text
	return text.replace("{move_click_hint}", tr(_get_move_click_hint_key()))

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
	var current_step: Dictionary = steps[step_index]
	_advance_step()
	_apply_step_completion_effects(current_step)

func _apply_step_completion_effects(step: Dictionary) -> void:
	var should_deselect_army: bool = bool(step.get("on_complete_deselect_army", false))
	var should_close_info_modal: bool = bool(step.get("on_complete_close_info_modal", false))
	if not should_deselect_army and not should_close_info_modal:
		return
	_apply_deferred_step_completion_effects(should_deselect_army, should_close_info_modal)

func _apply_deferred_step_completion_effects(should_deselect_army: bool, should_close_info_modal: bool) -> void:
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	if should_deselect_army:
		game_manager.get_army_manager().deselect_army()
	if should_close_info_modal:
		info_modal.hide_modal()

func handle_battle_finished() -> void:
	_battle_finished_flag = true
	if not active:
		return
	if expected_action != "battle_finished":
		return
	DebugLogger.log("Tutorial", "Battle finished, advancing tutorial")
	_battle_finished_flag = false
	_advance_step()

func _on_info_modal_closed() -> void:
	if not active:
		return
	if expected_action != "closed_info_modal":
		return
	DebugLogger.log("Tutorial", "Info modal closed, advancing tutorial")
	_advance_step()

func _on_camera_moved(_target: Vector2) -> void:
	if not active:
		return
	if expected_action != "camera_move":
		return
	DebugLogger.log("Tutorial", "Camera moved by player, advancing tutorial")
	_advance_step()

func _on_camera_zoomed(_zoom: Vector2) -> void:
	if not active:
		return
	if expected_action != "camera_zoom":
		return
	DebugLogger.log("Tutorial", "Camera zoomed by player, advancing tutorial")
	_advance_step()

func _advance_step() -> void:
	step_index += 1
	expected_region_id = -1
	expected_action = ""
	if tutorial_modal:
		tutorial_modal.hide_all_arrows()
	_connect_message_signal()
	_connect_info_modal_signal()
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

func _connect_info_modal_signal() -> void:
	if info_modal:
		var cb: Callable = Callable(self, "_on_info_modal_closed")
		if not info_modal.closed_info_modal.is_connected(cb):
			info_modal.closed_info_modal.connect(cb)

func _connect_camera_signal() -> void:
	var cam: CameraController = camera as CameraController
	var cb = Callable(self, "_on_camera_moved")
	if not cam.camera_moved_by_player.is_connected(cb):
		cam.camera_moved_by_player.connect(cb)
	var cb_zoom = Callable(self, "_on_camera_zoomed")
	if not cam.camera_zoomed_by_player.is_connected(cb_zoom):
		cam.camera_zoomed_by_player.connect(cb_zoom)

func _set_camera_tutorial_signal_enabled(enabled: bool) -> void:
	var cam: CameraController = camera as CameraController
	if cam:
		cam.set_tutorial_signal_enabled(enabled)

func _finish() -> void:
	active = false
	_set_camera_tutorial_signal_enabled(false)
	if tutorial_modal:
		tutorial_modal.hide_all_arrows()
		tutorial_modal.show_block("")  # Clear all blocks to re-enable input
	if message_modal:
		message_modal.hide_modal()
		_restore_modal_state()
	game_manager.finish_tutorial_analytics_run()
	var tree: SceneTree = _get_scene_tree()
	if tree != null:
		tree.paused = false
		tree.change_scene_to_file("res://scenes/main_menu.tscn")

func _get_scene_tree() -> SceneTree:
	if message_modal:
		return message_modal.get_tree()
	if tutorial_modal:
		return tutorial_modal.get_tree()
	return null

func is_waiting_for_region() -> bool:
	return active and expected_action == "region"

func _apply_step(step: Dictionary) -> void:
	expected_action = String(step.get("expected_action", ""))
	expected_ui_target = String(step.get("ui_target", ""))
	DebugLogger.log("Tutorial", "Applying step data: expected_action=" + expected_action + ", ui_target=" + expected_ui_target + ", camera_focus=" + str(step.get("camera_focus", {})))
	var hide_message = bool(step.get("hide_message", false))
	if message_modal and not hide_message:
		message_modal.hide_modal()
		await Engine.get_main_loop().process_frame
		var text = String(step.get("message", ""))
		var show_continue = bool(step.get("show_continue", false))
		var block_input = bool(step.get("block_input", true))
		var panel_pos: Vector2 = step.get("panel_position", Vector2.INF)
		var translated_text: String = _apply_tutorial_message_tokens(tr(text))
		message_modal.show_tutorial_message(translated_text, show_continue, block_input)
		if panel_pos != Vector2.INF:
			message_modal.set_panel_position(panel_pos)
		else:
			message_modal.reset_panel_position()
	elif message_modal and hide_message:
		message_modal.hide_modal()
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
	if tutorial_modal:
		var block_id := String(step.get("block", ""))
		tutorial_modal.show_block(block_id)
	if expected_action == "region":
		expected_region_id = int(step.get("target_region_id", -1))
		if expected_region_id == -1:
			expected_region_id = _get_player_castle_region()
	if tutorial_modal:
		DebugLogger.log("Tutorial", "Applying step: action=" + expected_action + ", arrow_keys=" + str(tutorial_modal.arrows.keys()) + ", arrow_exists=" + str(tutorial_modal.arrows.has("1")))

	# Handle race condition: if expecting battle_finished but battle already finished
	if expected_action == "battle_finished":
		DebugLogger.log("Tutorial", "Step expects battle_finished, flag status: " + str(_battle_finished_flag))
		if _battle_finished_flag:
			DebugLogger.log("Tutorial", "Battle already finished, auto-advancing")
			_battle_finished_flag = false
			await Engine.get_main_loop().process_frame
			_advance_step()

func _get_player_castle_region() -> int:
	return region_manager.get_castle_starting_position(tutorial_player_id)

func _build_default_steps() -> Array:
	var castle_region = _get_player_castle_region()
	return [
		{
			"message": "tutorial_step_1",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_2",
			"show_continue": false,
			"block_input": false,
			"expected_action": "region",
			"target_region_id": 190,
			"panel_position": Vector2(200, 450),
			"arrow": {
				"id": "1",
				"anchor": "world",
				"region_id": 190,
				"offset": Vector2(-150, 0),
				"rotation": -25.0
			},
			"block": "trade,endturn",
			"camera_focus": {"type": "region", "region_id": 190}
		},
		{
			"message": "tutorial_step_3",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "InfoModal/armies_tab",
			"arrow": {
				"id": "28",
				"anchor": "screen",
			},
			"block": "trade,endturn,regionactions",
		},
		{
			"message": "tutorial_step_4",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"arrow": {
				"id": "29",
				"anchor": "screen"
			},
			"block": "trade,endturn",
		},
		{
			"message": "tutorial_step_5",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "MoveModal/recruit_soldiers",
			"block_map_click": true,
			"panel_position": Vector2(300, 600),
			"arrow": {
				"id": "23",
				"anchor": "screen"
			},
			"block": "trade,endturn,makecamp,cancelmove,regionactionsfull",
		},
		{
			"message": "tutorial_step_6",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(100, 400),
			"block": "trade,endturn,recruitmentall,recruitmentrecruit",
		},
		{
			"message": "tutorial_step_7",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(100, 400),
			"arrow": {
				"id": "9",
				"anchor": "screen"
			},
			"block": "trade,endturn,recruitmentall,recruitmentrecruit",
		},
		{
			"message": "tutorial_step_8",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "RecruitmentModal/1archers",
			"panel_position": Vector2(100, 400),
			"arrow": {
				"id": "3",
				"anchor": "screen"
			},
			"block": "trade,endturn,recruitmentarchers,recruitmentrecruit",
		},
		{
			"message": "tutorial_step_9",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "RecruitmentModal/10archers",
			"panel_position": Vector2(100, 400),
			"arrow": {
				"id": "3",
				"anchor": "screen"
			},
			"block": "trade,endturn,recruitmentarchers,recruitmentrecruit",
		},
		{
			"message": "tutorial_step_10",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "RecruitmentModal/recruit_all",
			"panel_position": Vector2(100, 400),
			"arrow": {
				"id": "4",
				"anchor": "screen"
			},
			"block": "trade,endturn,recruitmentall",
		},
		{
			"message": "tutorial_step_11",
			"show_continue": false,
			"block_input": false,
			"expected_action": "region",
			"enforce_move_trigger_click": true,
			"target_region_id": 196,
			"panel_position": Vector2(500, 200),
			"block": "trade,endturn,cancelmove,makecamp,armyactions3,regionactionsfull"
		},
		{
			"message": "tutorial_step_12",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "PrebattleModal/continue",
			"panel_position": Vector2(100, 500),
			"block": "trade,endturn,battlewithdraw"
		},
		{
			"message": "tutorial_step_13",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(100, 500),
			"block": "trade,endturn,battlecontinue,battlewithdraw"
		},
		{
			"message": "tutorial_step_14",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(100, 500),
			"block": "trade,endturn,battlecontinue,battlewithdraw"
		},
		{
			"message": "",
			"show_continue": false,
			"hide_message": true,
			"block_input": false,
			"expected_action": "battle_finished",
			"panel_position": Vector2(100, 500),
			"block": "trade,endturn,battlewithdraw"
		},
		{
			"message": "tutorial_step_15",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"panel_position": Vector2(100, 500),
			"ui_target": "BattleModal/continue",
			"arrow": {
				"id": "5",
				"anchor": "screen"
			},
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_16",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(0, 50),
			"block": "trade,endturn,continue"
		},
		{
			"message": "tutorial_step_17",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(0, 50),
			"arrow": {
				"id": "6",
				"anchor": "screen"
			},
			"block": "trade,endturn,continue"
		},
		{
			"message": "tutorial_step_18",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(0, 50),
			"arrow": {
				"id": "7",
				"anchor": "screen"
			},
			"block": "trade,endturn,continue"
		},
		{
			"message": "tutorial_step_19",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"panel_position": Vector2(0, 50),
			"ui_target": "BattleSummaryModal/continue",
			"block": "trade,endturn,"
		},
		{
			"message": "tutorial_step_20",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(800, 100),
			"arrow": {
				"id": "29",
				"anchor": "screen"
			},
			"block": "trade,endturn,cancelmove,makecamp,armyactions3"
		},
		{
			"message": "tutorial_step_21",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(800, 100),
			"arrow": {
				"id": "29",
				"anchor": "screen"
			},
			"block": "trade,endturn,cancelmove,makecamp,armyactions3"
		},
		{
			"message": "tutorial_step_22",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(800, 100),
			"arrow": {
				"id": "29",
				"anchor": "screen"
			},
			"block": "trade,endturn,cancelmove,makecamp,armyactions3"
		},
		{
			"message": "tutorial_step_23",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "MoveModal/make_camp",
			"block_map_click": true,
			"panel_position": Vector2(800, 100),
			"arrow": {
				"id": "10",
				"anchor": "screen"
			},
			"block": "trade,endturn,cancelmove,armyactions3,regionactionsfull"
		},

		{
			"message": "tutorial_step_23a",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(800, 100),
			"arrow": {
				"id": "10",
				"anchor": "screen"
			},
			"block": "makecamp,trade,endturn,cancelmove,armyactions3,regionactionsfull"
		},
		{
			"message": "tutorial_step_24",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(800, 100),
			"block": "trade,endturn,cancelmove,makecamp,armyactions3"
		},
		{
			"message": "tutorial_step_25",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(800, 100),
			"block": "trade,endturn,cancelmove,makecamp,armyactions3"
		},
		{
			"message": "tutorial_step_26",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "MoveModal/army_deselect",
			"target_region_id": 196,
			"panel_position": Vector2(800, 100),
			"arrow": {
				"id": "1",
				"anchor": "world",
				"region_id": 196,
				"offset": Vector2(-150, 0),
				"rotation": -25.0
			},
			"block": "trade,endturn,makecamp,armyactions3,cancelmove,regionactionsfull"
		},
		# {
		# 	"message": "tutorial_step_27",
		# 	"show_continue": false,
		# 	"block_input": false,
		# 	"expected_action": "closed_info_modal",
		# 	"panel_position": Vector2(500, 300),
		# 	"block": "endturn,regionactionsfull,armyaction3,makecamp,cancelmove"
		# },
		{
			"message": "tutorial_step_28",
			"show_continue": false,
			"block_input": true,
			"expected_action": "camera_move",
			"panel_position": Vector2(500, 300),
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_29",
			"show_continue": false,
			"block_input": true,
			"expected_action": "camera_zoom",
			"panel_position": Vector2(500, 300),
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_30",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "TurnModal/EndTurnButton",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "12",
				"anchor": "screen"
			},
			"block": "trade,trade,regionactionsfull"
		},
		{
			"message": "tutorial_step_31",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(800, 100),
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_32",
			"show_continue": false,
			"block_input": false,
			"expected_action": "region",
			"enforce_move_trigger_click": true,
			"target_region_id": 196,
			"panel_position": Vector2(800, 100),
			"block": "trade,endturn",
			"camera_focus": {"type": "region", "region_id": 228}
		},
		{
			"message": "tutorial_step_33",
			"show_continue": false,
			"block_input": false,
			"expected_action": "region",
			"enforce_move_trigger_click": true,
			"target_region_id": 228,
			"panel_position": Vector2(800, 100),
			"block": "trade,endturn,cancelmove,makecamp,armyactions3,regionactionsfull"
		},
		{
			"message": "tutorial_step_34",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(50, 800),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "14",
				"anchor": "screen"
			},
		},
		{
			"message": "tutorial_step_35",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(50, 800),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "24",
				"anchor": "screen"
			},
		},
		{
			"message": "tutorial_step_36",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(50, 800),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "27",
				"anchor": "screen"
			},
		},
		{
			"message": "tutorial_step_37",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(50, 800),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "25",
				"anchor": "screen"
			},
		},
		{
			"message": "tutorial_step_38",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(50, 800),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "26",
				"anchor": "screen"
			},
		},
		{
			"message": "tutorial_step_39",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(50, 800),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "13",
				"anchor": "screen"
			},
		},
		{
			"message": "tutorial_step_40",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "PrebattleModal/continue",
			"panel_position": Vector2(50, 800),
			"block": "trade,withdraw,endturn,continue3,nonladders",
		},
		{
			"message": "tutorial_step_41",
			"show_continue": false,
			"block_input": false,
			"expected_action": "battle_finished",
			"panel_position": Vector2(100, 600),
			"block": "trade,continue3,endturn,battlewithdraw"
		},
		{
			"message": "tutorial_step_42",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"panel_position": Vector2(100, 600),
			"ui_target": "BattleModal/continue",
			"arrow": {
				"id": "5",
				"anchor": "screen"
			},
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_43",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"panel_position": Vector2(20, 50),
			"ui_target": "BattleSummaryModal/continue",
			"on_complete_deselect_army": true,
			"on_complete_close_info_modal": true,
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_44",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_45",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "15",
				"anchor": "screen"
			},
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_46",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "15",
				"anchor": "screen"
			},
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_47",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "16",
				"anchor": "screen"
			},
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_48",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "16",
				"anchor": "screen"
			},
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_49",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "17",
				"anchor": "screen"
			},
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_50",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "17",
				"anchor": "screen"
			},
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_51",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "18",
				"anchor": "screen"
			},
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_52",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "19",
				"anchor": "screen"
			},
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_53",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "19",
				"anchor": "screen"
			},
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_54",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "20",
				"anchor": "screen"
			},
			"block": "trade,endturn"
		},
		{
			"message": "tutorial_step_55",
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
			"block": "trade,endturn,armyactions3,makecamp,cancelmove,regionactionsfull",
			"camera_focus": {"type": "region", "region_id": 190}
		},
		{
			"message": "tutorial_step_56",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(700, 400),
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "tutorial_step_57",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(700, 400),
			"arrow": {
				"id": "30",
				"anchor": "screen"
			},
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "tutorial_step_58",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(700, 400),
			"arrow": {
				"id": "31",
				"anchor": "screen"
			},
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "tutorial_step_59",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(700, 400),
			"arrow": {
				"id": "32",
				"anchor": "screen"
			},
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "tutorial_step_60",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(700, 400),
			"arrow": {
				"id": "33",
				"anchor": "screen"
			},
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "tutorial_step_61",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(700, 400),
			"arrow": {
				"id": "34",
				"anchor": "screen"
			},
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "tutorial_step_62",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(700, 400),
			"arrow": {
				"id": "34",
				"anchor": "screen"
			},
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "tutorial_step_63",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(700, 400),
			"arrow": {
				"id": "35",
				"anchor": "screen"
			},
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "tutorial_step_64",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(700, 400),
			"arrow": {
				"id": "36",
				"anchor": "screen"
			},
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "tutorial_step_65",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(700, 400),
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "tutorial_step_65a",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(700, 400),
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "tutorial_step_66",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(700, 400),
			"block": "trade,endturn,regionsactions"
		}
	]

func _apply_camera_focus(focus_data: Dictionary) -> void:
	if ai_camera_director_ref == null:
		DebugLogger.log("Tutorial", "Camera focus skipped: director null")
		return
	var focus_type = String(focus_data.get("type", ""))
	if focus_type == "region":
		var rid = int(focus_data.get("region_id", -1))
		if rid == -1:
			rid = _get_player_castle_region()
		if rid == -1:
			DebugLogger.log("Tutorial", "Camera focus skipped: no region id")
			return
		var region = region_manager.map_generator.get_region_container_by_id(rid) as Region
		if region != null:
			await ai_camera_director_ref.await_focus_on_region(region)
			DebugLogger.log("Tutorial", "Camera focused on region " + str(rid))
	elif focus_type == "position":
		var pos: Vector2 = focus_data.get("position", Vector2.ZERO)
		await ai_camera_director_ref.await_focus_on_position(pos)
		DebugLogger.log("Tutorial", "Camera focused on position " + str(pos))

func _restore_modal_state() -> void:
	if message_modal == null:
		return
	var ui_manager := message_modal.ui_manager
	if ui_manager == null:
		return
	var should_enable := ui_manager.is_any_modal_visible()
	ui_manager.set_modal_active(should_enable)
	ui_manager.call_deferred("set_modal_active", should_enable)
