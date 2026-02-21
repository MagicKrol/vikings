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
		message_modal.show_tutorial_message(text, show_continue, block_input)
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
			"message": "Welcome to the tutorial.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"block": "trade,endturn"
		},
		{
			"message": "This is your home region.\nClick it.",
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
			"message": "This panel shows information and actions for the selected region. \n\nNow switch to the Armies tab.",
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
			"message": "This is your army. Use armies to conquer other regions.",
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
			"message": "Before we march to battle, we need more soldiers. Click the Recruit button for the selected army.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "MoveModal/recruit_soldiers",
			"panel_position": Vector2(300, 600),
			"arrow": {
				"id": "23",
				"anchor": "screen"
			},
			"block": "trade,endturn,makecamp,cancelmove,regionactionsfull",
		},
		{
			"message": "Here you can recruit different types of soldiers to strengthen your forces.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(100, 400),
			"block": "trade,endturn,recruitmentall,recruitmentrecruit",
		},
		{
			"message": "Each unit has its strengths and purpose. Hover over their abilities to learn how to use them effectively.",
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
			"message": "Add 10 Archers to your army.",
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
			"message": "Tip: Hold Shift while clicking to recruit 10 at once.\nYou can also hold the + button to recruit faster.",
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
			"message": "Perfect. This button recruits all selected units and closes the recruitment screen.",
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
			"message": "Click on the highlighted region to attack it.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "region",
			"target_region_id": 196,
			"panel_position": Vector2(500, 200),
			"block": "trade,endturn,cancelmove,makecamp,armyactions3,regionactionsfull"
		},
		{
			"message": "Before a battle you will get some intel on the region's defenders. \n\nPress the Attack button to start the battle.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "PrebattleModal/continue",
			"panel_position": Vector2(100, 500),
			"block": "endturn,trade,withdraw"
		},
		{
			"message": "You don't have much control over the battle.\nIt's resolved automatically.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(100, 500),
			"block": "endturn,battlecontinue,battlewithdraw"
		},
		{
			"message": "But you can always withdraw if the battle starts to go wrong. Expect additional losses in the process.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(100, 500),
			"block": "endturn,battlecontinue,battlewithdraw"
		},
		{
			"message": "",
			"show_continue": false,
			"hide_message": true,
			"block_input": false,
			"expected_action": "battle_finished",
			"panel_position": Vector2(100, 500),
			"block": "endturn,battlecontinue,battlewithdraw"
		},
		{
			"message": "Let's click continue and see the battle summary.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"panel_position": Vector2(100, 500),
			"ui_target": "BattleModal/continue",
			"arrow": {
				"id": "5",
				"anchor": "screen"
			},
			"block": "endturn,trade"
		},
		{
			"message": "This is the battle summary screen.\nIt presents detailed information about the battle result.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(0, 50),
			"block": "endturn,trade,continue"
		},
		{
			"message": "On the left hand side you can find information about your wounded soldiers...",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(0, 50),
			"arrow": {
				"id": "6",
				"anchor": "screen"
			},
			"block": "endturn,trade,continue"
		},
		{
			"message": "... and the fallen soldiers.\n\nFortunately, wounded soldiers are healed when the army rests.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(0, 50),
			"arrow": {
				"id": "7",
				"anchor": "screen"
			},
			"block": "endturn,trade,continue"
		},
		{
			"message": "Click continue.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"panel_position": Vector2(0, 50),
			"ui_target": "BattleSummaryModal/continue",
			"block": "endturn,trade"
		},
		{
			"message": "Before we move on. Take a look here.\n It's your Army status screen.",
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
			"message": "Every action uses some move points. Especially travelling through a difficult terrain!",
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
			"message": "Vigor represents the army's morale and stamina. It replenishes when resting and affects battle effectiveness.",
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
			"message": "Let's make a camp, to heal our wounded and restore some vigor. ",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "MoveModal/make_camp",
			"panel_position": Vector2(800, 100),
			"arrow": {
				"id": "10",
				"anchor": "screen"
			},
			"block": "trade,endturn,cancelmove,armyactions3,regionactionsfull"
		},
		{
			"message": "Vigor restored!\nTip: Any movement points left at the end of the turn are spent resting.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(800, 100),
			"block": "trade,endturn,cancelmove,makecamp,armyactions3"
		},
		{
			"message": "We don't have enough movement points to move this turn.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(800, 100),
			"block": "trade,endturn,cancelmove,makecamp,armyactions3"
		},
		{
			"message": "Let's cancel our move by deselecting the army. You can either click the region with the army or click the army in the list.",
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
		{
			"message": "You can close the Region or Armies window by pressing Esc or by clicking a region on the map that is not yours.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "closed_info_modal",
			"panel_position": Vector2(500, 300),
			"block": "trade,endturn,regionactionsfull,armyaction3,makecamp,cancelmove"
		},
		{
			"message": "You can navigate the map by holding the right mouse button and moving the mouse, or by using the arrow keys/WASD. Try it.",
			"show_continue": false,
			"block_input": true,
			"expected_action": "camera_move",
			"panel_position": Vector2(500, 300),
			"block": "trade,endturn"
		},
		{
			"message": "You can also zoom in and out. Use the mouse wheel, a pinch gesture on your touchpad, or press Q and E.",
			"show_continue": false,
			"block_input": true,
			"expected_action": "camera_zoom",
			"panel_position": Vector2(500, 300),
			"block": "trade,endturn"
		},
		{
			"message": "We can end our turn now.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "TurnModal/EndTurnButton",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "12",
				"anchor": "screen"
			},
			"block": "trade"
		},
		{
			"message": "New turn, new movement points. Let's attack the last region. Try it on your own.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(800, 100),
			"block": "trade,endturn"
		},
		{
			"message": "Select your army and click the region you wish to attack.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "region",
			"target_region_id": 196,
			"panel_position": Vector2(800, 100),
			"block": "trade,endturn",
			"camera_focus": {"type": "region", "region_id": 228}
		},
		{
			"message": "When an army is selected, movement is the default action. Simply click a region on the map to move there.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "region",
			"target_region_id": 228,
			"panel_position": Vector2(800, 100),
			"block": "trade,endturn,cancelmove,makecamp,armyactions3,regionactionsfull"
		},
		{
			"message": "During siege battles, defenders receive a defense bonus, which reduces damage taken.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(200, 800),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "14",
				"anchor": "screen"
			},
		},
		{
			"message": "Engaged shows how many of your soldiers will participate in direct melee combat.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(200, 800),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "24",
				"anchor": "screen"
			},
		},
		{
			"message": "Use Siege Points to construct siege equipment. Some troops increase your Siege Points.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(200, 800),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "27",
				"anchor": "screen"
			},
		},
		{
			"message": "Build trebuchets to reduce defense value, with a chance to breach the walls. ",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(200, 800),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "25",
				"anchor": "screen"
			},
		},
		{
			"message": "Siege rams attack the gates. Once breached, they gradually increase the Engaged value.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(200, 800),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "26",
				"anchor": "screen"
			},
		},
		{
			"message": "Ladders are the simplest way to increase the Engaged value by storming the walls directly.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(200, 800),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "13",
				"anchor": "screen"
			},
		},
		{
			"message": "Construct some ladders and let's attack.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "PrebattleModal/continue",
			"panel_position": Vector2(200, 800),
			"block": "trade,withdraw,endturn,continue3,nonladders",
		},
		{
			"message": "This battle should be easy.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "battle_finished",
			"panel_position": Vector2(100, 600),
			"block": "continue3,endturn,battlewithdraw,battlecontinue"
		},
		{
			"message": "Let's move to the battle summary.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"panel_position": Vector2(100, 600),
			"ui_target": "BattleModal/continue",
			"arrow": {
				"id": "5",
				"anchor": "screen"
			},
			"block": "endturn"
		},
		{
			"message": "Click continue.",
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
			"message": "We finished our conquests for now. Let's talk about economy and resources.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"block": "trade,endturn"
		},
		{
			"message": "Population is your main source of gold income and recruits for your armies.",
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
			"message": "Promoting a region boosts its growth. Hiring soldiers reduces it.",
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
			"message": "You need food to maintain your armies. Every soldier consumes 0.1 Food per turn.",
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
			"message": "Hungry armies will drain resources from local regions, bringing death and starvation.",
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
			"message": "Wood is your basic building resource. You need it to build outposts, upgrade castles or regions.",
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
			"message": "You will also need it to hire ranged units and build siege equipment.",
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
			"message": "Stone is mostly needed for your keeps, castles and strongholds.",
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
			"message": "Iron is a crucial resource used to produce the armour required by your top-tier units — Knights.",
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
			"message": "To gain access to iron you need mines. Conquer regions with hills and look for iron ore!",
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
			"message": "Raising armies, promoting regions, building, recruiting - you will need gold for all of it.\nA lot! ",
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
			"message": "Last few points before we finish the tutorial. Click your region again.",
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
			"message": "Let's return to the Region screen.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(700, 400),
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "Region promotion grants a temporary bonus to growth, increases the recruit pool, and improves income and the size of local resources. ",
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
			"message": "To recruit better units you need better castles. Greater castles will also increase region's defense bonus.",
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
			"message": "Regions with hills may contain precious iron or gold deposits. Their presence and size are random. Each region has three chances to discover them.",
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
			"message": "You will need more armies to conquer your enemies. If you build a Keep, you will be able to raise new armies.",
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
			"message": "Units can serve in your armies or remain in the region’s garrison. Garrisoned soldiers defend the region but can be reassigned at any time.",
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
			"message": "If you build at least an Outpost (Level 1 defense), you gain access to recruits from all neighboring owned regions.",
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
			"message": "This is your local garrison — units hired to defend this region. Any unhired recruits will automatically join the defense if the region is attacked.",
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
			"message": "Finally, here you can see the local population, growth, income, and resource output added to your pool each turn.",
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
			"message": "Congratulations!\nYou have finished the tutorial. Click Continue to exit.",
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
