extends RefCounted
class_name TutorialManager

var region_manager: RegionManager
var tutorial_modal: TutorialModal
var message_modal: MessageModal
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
	camera = cam
	ai_camera_director_ref = camera_director
	_connect_message_signal()
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
	_advance_step()

func handle_battle_finished() -> void:
	_battle_finished_flag = true
	if not active:
		return
	if expected_action != "battle_finished":
		return
	DebugLogger.log("Tutorial", "Battle finished, advancing tutorial")
	_battle_finished_flag = false
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
			"message": "Welcome to the tutorial",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"block": "trade,endturn"
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
			"block": "trade,endturn",
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
			},
			"block": "trade,endturn,firstelement",
		},
		{
			"message": "Before we jump into battle let's recruit additional soldiers. \nSelect army actions.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "MoveModal/army_actions",
			"panel_position": Vector2(350, 700),
			"arrow": {
				"id": "23",
				"anchor": "screen"
			},
			"block": "trade,endturn,makecamp,cancelmove",
		},
		{
			"message": "Here is the list of all actions available to the army. Click on the Recruit Soldiers.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "ArmySelectModal/recruit_soldiers",
			"panel_position": Vector2(350, 700),
			"arrow": {
				"id": "2",
				"anchor": "screen"
			},
			"block": "trade,endturn,armyactions,cancelmove,makecamp",
		},
		{
			"message": "Every unit has it's role on the battlefield. You can learn more about it by hovering over the unit name.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(150, 500),
			"arrow": {
				"id": "9",
				"anchor": "screen"
			},
			"block": "trade,endturn,recruitment,continue",
		},
		{
			"message": "But for now, let's just add some archers to you army.\n\n When done. \nPress Continue button.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "RecruitmentModal/continue",
			"panel_position": Vector2(150, 500),
			"arrow": {
				"id": "3",
				"anchor": "screen"
			},
			"block": "trade,endturn,recruitment",
		},
		{
			"message": "We are ready to battle. \nClick Move Army button.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "ArmySelectModal/move_army",
			"panel_position": Vector2(350, 700),
			"arrow": {
				"id": "4",
				"anchor": "screen"
			},
			"block": "trade,endturn,armyactions2",
		},
		{
			"message": "Click on the highlighted region to attack it.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "region",
			"target_region_id": 196,
			"panel_position": Vector2(500, 200),
			"block": "trade,endturn,cancelmove,makecamp,armyactions3"
		},
		{
			"message": "Before a battle you will get some intel on the region's defenders. \n\nPress attack button to start the battle.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "PrebattleModal/continue",
			"panel_position": Vector2(200, 500),
			"block": "endturn,trade,withdraw"
		},
		{
			"message": "You don't have much control over the battle.\n It's resolved automatically.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(200, 500),
			"block": "endturn,continue3, continue2"
		},
		{
			"message": "But you can always withdraw, if battle starts to go wrong. Though expect some additional losses in the process.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(200, 500),
			"block": "endturn,continue3"
		},
		{
			"message": "",
			"show_continue": false,
			"hide_message": true,
			"block_input": false,
			"expected_action": "battle_finished",
			"panel_position": Vector2(200, 500),
			"block": "endturn,continue3"
		},
		{
			"message": "Let's click continue and see the battle summary.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"panel_position": Vector2(200, 500),
			"ui_target": "BattleModal/continue",
			"arrow": {
				"id": "5",
				"anchor": "screen"
			},
			"block": "endturn,trade"
		},
		{
			"message": "That's a battle summary screen. \nIt presents detailed information about battle result.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(20, 300),
			"block": "endturn,trade,continue"
		},
		{
			"message": "On the left hand side you can find information about your wounded soldiers...",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(20, 300),
			"arrow": {
				"id": "6",
				"anchor": "screen"
			},
			"block": "endturn,trade,continue"
		},
		{
			"message": "... end the dead one. \n\nFortunately wounded soldier get healed when army gets rest.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(20, 300),
			"arrow": {
				"id": "7",
				"anchor": "screen"
			},
			"block": "endturn,trade,continue"
		},
		{
			"message": "Let's click continue.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"panel_position": Vector2(20, 300),
			"ui_target": "BattleSummaryModal/continue",
			"block": "endturn,trade"
		},
		{
			"message": "Before we move on. Take a look here.\n It's your Army status screen.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "8",
				"anchor": "screen"
			},
			"block": "trade,endturn,cancelmove,makecamp,armyactions3"
		},
		{
			"message": "Every action uses some move points. Especially travelling through a difficult terrain!",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "8",
				"anchor": "screen"
			},
			"block": "trade,endturn,cancelmove,makecamp,armyactions3"
		},
		{
			"message": "Vigor represents your's army morale and stamina. It replesh upon resting. It affects army's battle effectiveness.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "8",
				"anchor": "screen"
			},
			"block": "trade,endturn,cancelmove,makecamp,armyactions3"
		},
		{
			"message": "Let's make a camp, to heal our wounded and restore some vigor. ",
			"show_continue": false,
			"block_input": true,
			"expected_action": "ui",
			"ui_target": "MoveModal/make_camp",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "10",
				"anchor": "screen"
			},
			"block": "trade,endturn,cancelmove,armyactions3"
		},
		{
			"message": "Vigor restored!\n Any movement points left at the end of the turn is spent resting. ",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"block": "trade,endturn,cancelmove,makecamp,armyactions3"
		},
		{
			"message": "We don't have enough movement points to move our army!\n Let's cancel our move.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "MoveModal/cancel_move",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "11",
				"anchor": "screen"
			},
			"block": "trade,endturn,makecamp,armyactions3"
		},
		{
			"message": "You can navigate the map by holding right mouse button and moving mouse or using key arrows/WASD. Try it.",
			"show_continue": false,
			"block_input": true,
			"expected_action": "camera_move",
			"panel_position": Vector2(500, 300),
			"block": "trade,endturn"
		},
		{
			"message": "You can also zoom in and out. Use mouse wheel, pinch gesture on your touchpad or press Q and E keys.",
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
			"message": "New turn and new movement points. Let's attack the last region. Try it on your own.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"block": "trade,endturn"
		},
		{
			"message": "",
			"show_continue": false,
			"block_input": false,
			"hide_message": true,
			"expected_action": "region",
			"target_region_id": 196,
			"panel_position": Vector2(0,0),
			"block": "trade,endturn",
			"camera_focus": {"type": "region", "region_id": 228}
		},
		{
			"message": "",
			"show_continue": false,
			"block_input": false,
			"hide_message": true,
			"expected_action": "ui",
			"ui_target": "GeneralSelectModal/ArmyButton0",
			"panel_position": Vector2(350, 700),
			"block": "trade,endturn,firstelement",
		},
		# {
		# 	"message": "",
		# 	"show_continue": false,
		# 	"block_input": false,
		# 	"expected_action": "ui",
		# 	"hide_message": true,
		# 	"ui_target": "ArmySelectModal/move_army",
		# 	"panel_position": Vector2(350, 700),
		# 	"block": "trade,endturn,armyactions2",
		# },
		{
			"message": "",
			"show_continue": false,
			"block_input": false,
			"expected_action": "region",
			"hide_message": true,
			"target_region_id": 228,
			"panel_position": Vector2(500, 200),
			"block": "trade,endturn,cancelmove,makecamp,armyactions3"
		},
		{
			"message": "During siege battles, defenders receive defense bonus. That allows them to receive less damage.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(200, 500),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "14",
				"anchor": "screen"
			},
		},
		{
			"message": "Engaged presents how many of your soldiers will be engaged in a direct melee combat.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(200, 500),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "24",
				"anchor": "screen"
			},
		},
		{
			"message": "Use your Siege Points to construct Siege Equipment. Some of your troops will increase these points.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(200, 500),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "27",
				"anchor": "screen"
			},
		},
		{
			"message": "Build trebuchets to reduce defense value, with a chance to breach a wall. ",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(200, 500),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "25",
				"anchor": "screen"
			},
		},
		{
			"message": "Siege rams will start attacking gates. Once breached it will gradually increase engaged value.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(200, 500),
			"block": "trade,withdraw,continue2,continue3,endturn,siegeeq",
			"arrow": {
				"id": "26",
				"anchor": "screen"
			},
		},
		{
			"message": "Ladders are the simplest way to increase engaged score by storming walls directly.",
			"show_continue": true,
			"block_input": false,
			"expected_action": "continue",
			"panel_position": Vector2(200, 500),
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
			"panel_position": Vector2(200, 500),
			"block": "trade,withdraw,endturn,continue3,nonladders",
		},
		{
			"message": "This battle should be easy.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "battle_finished",
			"panel_position": Vector2(200, 500),
			"block": "continue3,endturn"
		},
		{
			"message": "Let's move to the battle summary.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"panel_position": Vector2(200, 500),
			"ui_target": "BattleModal/continue",
			"arrow": {
				"id": "5",
				"anchor": "screen"
			},
			"block": "endturn"
		},
		{
			"message": "Let's click continue.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"panel_position": Vector2(20, 300),
			"ui_target": "BattleSummaryModal/continue",
			"block": "trade,endturn"
		},
		{
			"message": "We finished our conquests for now.\n Cancel our move.",
			"show_continue": false,
			"block_input": false,
			"expected_action": "ui",
			"ui_target": "MoveModal/cancel_move",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "11",
				"anchor": "screen"
			},
			"block": "trade,endturn,makecamp,armyactions3"
		},
		{
			"message": "Let's talk about economy and resources.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"block": "trade,endturn"
		},
		{
			"message": "Population is your main source for gold income and recruits for your armies.",
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
			"message": "Promoting regions will boost region's growth. Hiring soldiers will reduce it.",
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
			"message": "You need food to upkeep your armies. Every soldier uses 0.1 of Food per turn.",
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
			"message": "Hungry armies will drain resources from local regions. Bringing death and starvation.",
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
			"message": "Iron is a crucial resource to produce armour required by your top tier units - knights.",
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
			"message": "Last few points and we are done. Click your region again. I want to show you something.",
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
			"block": "trade,endturn",
			"camera_focus": {"type": "region", "region_id": 190}
		},
		{
			"message": "That's your region's status screen.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "8",
				"anchor": "screen"
			},
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "You can find basic information about your population, growth, region's level and income.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "8",
				"anchor": "screen"
			},
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "In this section you find a size of your local garrison. Current castle level, defense score.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "21",
				"anchor": "screen"
			},
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "But also information about available recruits. Recruits pool slowly replenish every turn.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "21",
				"anchor": "screen"
			},
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "Amount of recruits results from the size of the region's population and region's level.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "21",
				"anchor": "screen"
			},
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "And finally all local resources. Including information about possible ores veins.",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
			"arrow": {
				"id": "22",
				"anchor": "screen"
			},
			"block": "trade,endturn,regionsactions"
		},
		{
			"message": "Congratulations. You finished a basic tutorial. Click continue to exit. ",
			"show_continue": true,
			"block_input": true,
			"expected_action": "continue",
			"panel_position": Vector2(500, 300),
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
	var region_modal := ui_manager.get_node_or_null("../RegionSelectModal") as Control
	if region_modal and region_modal.visible:
		should_enable = true
	ui_manager.set_modal_active(should_enable)
	ui_manager.call_deferred("set_modal_active", should_enable)
