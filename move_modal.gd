extends Control
class_name MoveModal

signal army_deselect_target_reached

# Reference to ArmyManager for canceling moves
var army_manager: ArmyManager = null

# Reference to the selected army
var selected_army: Army = null

# Reference to the sound manager
var sound_manager: SoundManager = null
var ui_manager: UIManager = null
var info_modal: InfoModal = null
var recruitment_modal: RecruitmentModal = null
var transfer_select_modal: TransferSelectModal = null
var transfer_soldiers_modal: TransferSoldiersModal = null
var tutorial_manager: TutorialManager = null
var game_manager: GameManager = null
var camera_controller: CameraController = null
var make_camp_button: Button = null
var cancel_button: Button = null
var army_actions_button: Button = null
var next_army_button: Button = null
var recruit_button_border: Control = null
var make_camp_button_border: Control = null
var transfer_button_border: Control = null
var next_army_button_border: Control = null
const TUTORIAL_TARGET_ARMY_DESELECT: String = "MoveModal/army_deselect"
const NO_ACTIONS_TEXT: String = "Not enough movement points"

func _ready():
	# Get button reference and connect signal
	cancel_button = get_node("Panel/Army/ButtonSection/HBoxContainer2/ButtonBorder/Button") as Button
	cancel_button.pressed.connect(_on_cancel_move_pressed)
	army_actions_button = get_node("Panel/Army/ButtonSection/HBoxContainer3/ButtonBorder/ArmyActions") as Button
	army_actions_button.pressed.connect(_on_army_actions_pressed)
	make_camp_button = get_node("Panel/Army/ButtonSection/HBoxContainer/ButtonBorder/MakeCamp") as Button
	make_camp_button.pressed.connect(_on_make_camp_pressed)
	next_army_button = get_node("Panel2/List/ButtonSection/HBoxContainer3/ButtonBorder/NextArmy") as Button
	next_army_button.pressed.connect(_on_next_army_pressed)
	recruit_button_border = get_node("Panel/Army/ButtonSection/HBoxContainer3/ButtonBorder") as Control
	make_camp_button_border = get_node("Panel/Army/ButtonSection/HBoxContainer/ButtonBorder") as Control
	transfer_button_border = get_node("Panel/Army/ButtonSection/HBoxContainer2/ButtonBorder") as Control
	next_army_button_border = get_node("Panel2/List/ButtonSection/HBoxContainer3/ButtonBorder") as Control
	set_process_input(true)
	
	# Get sound manager reference
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	info_modal = get_node("../InfoModal") as InfoModal
	recruitment_modal = get_node("../RecruitmentModal") as RecruitmentModal
	transfer_select_modal = get_node("../TransferSelectModal") as TransferSelectModal
	transfer_soldiers_modal = get_node("../TransferSoldiersModal") as TransferSoldiersModal
	game_manager = get_node("../../GameManager") as GameManager
	camera_controller = get_node("../../Camera2D") as CameraController
	if game_manager:
		tutorial_manager = game_manager.get_tutorial_manager()
		if tutorial_manager != null:
			if make_camp_button:
				make_camp_button.name = "make_camp"
				make_camp_button.pressed.connect(func(): tutorial_manager.handle_ui_click("MoveModal/" + make_camp_button.name))
			if cancel_button:
				cancel_button.name = "transfer"
				cancel_button.pressed.connect(func(): tutorial_manager.handle_ui_click("MoveModal/" + cancel_button.name))
			if army_actions_button:
				army_actions_button.name = "recruit_soldiers"
				army_actions_button.pressed.connect(func(): tutorial_manager.handle_ui_click("MoveModal/" + army_actions_button.name))
			var army_deselect_cb: Callable = Callable(self, "_on_army_deselect_target_reached")
			if not army_deselect_target_reached.is_connected(army_deselect_cb):
				army_deselect_target_reached.connect(army_deselect_cb)
	_connect_region_tooltip_hide_on_hover(self)
	_connect_no_actions_hover()
	_hide_no_actions()
	
	# Initially hidden
	visible = false

func show_move_modal(army: Army) -> void:
	"""Show the move modal for the given army"""
	var modal_ui_manager: UIManager = get_node("../UIManager") as UIManager
	var previous_army: Army = selected_army
	if previous_army and previous_army.movement_points_changed.is_connected(_on_army_movement_points_changed):
		previous_army.movement_points_changed.disconnect(_on_army_movement_points_changed)
	selected_army = army
	if selected_army and not selected_army.movement_points_changed.is_connected(_on_army_movement_points_changed):
		selected_army.movement_points_changed.connect(_on_army_movement_points_changed)
	
	_update_action_buttons_state()
	modal_ui_manager.set_modal_active(false)
	visible = true
	modal_ui_manager.set_overlay_suppressed(true)
	army_manager.refresh_selected_move_targets()
	
	# Position at bottom center of screen
	# Modal is already positioned in the scene file at offset_top = 360

func hide_move_modal() -> void:
	"""Hide the move modal"""
	var modal_ui_manager: UIManager = get_node("../UIManager") as UIManager
	if selected_army and selected_army.movement_points_changed.is_connected(_on_army_movement_points_changed):
		selected_army.movement_points_changed.disconnect(_on_army_movement_points_changed)
	visible = false
	selected_army = null
	_hide_no_actions()
	modal_ui_manager.set_overlay_suppressed(false)

func _on_cancel_move_pressed() -> void:
	"""Handle transfer button press"""
	if cancel_button.disabled:
		return
	if sound_manager:
		sound_manager.click_sound()
	_start_transfer_flow()

func _cancel_move() -> void:
	"""Cancel the current move operation"""
	if army_manager:
		army_manager.deselect_army()
	hide_move_modal()

func emit_army_deselect_target_reached() -> void:
	emit_signal("army_deselect_target_reached")

func _on_army_deselect_target_reached() -> void:
	tutorial_manager.handle_ui_click(TUTORIAL_TARGET_ARMY_DESELECT)

func _on_army_actions_pressed() -> void:
	if army_actions_button.disabled:
		return
	if sound_manager:
		sound_manager.click_sound()
	_start_recruit_flow()

func _start_recruit_flow() -> void:
	if selected_army == null:
		return
	if not _selected_army_has_action_points():
		return
	var army_to_recruit: Army = selected_army
	var region_to_recruit: Region = army_to_recruit.get_parent() as Region
	if region_to_recruit == null:
		return
	ui_manager.remember_army_select(army_to_recruit, region_to_recruit)
	hide_move_modal()
	if recruitment_modal != null:
		recruitment_modal.show_recruitment(army_to_recruit, region_to_recruit, true)

func _start_transfer_flow() -> void:
	if selected_army == null:
		return
	if not _selected_army_has_action_points():
		return
	var army_to_transfer: Army = selected_army
	var region_to_transfer: Region = army_to_transfer.get_parent() as Region
	if region_to_transfer == null:
		return
	ui_manager.remember_army_select(army_to_transfer, region_to_transfer)
	var other_armies: Array[Army] = []
	for child in region_to_transfer.get_children():
		if child is Army and child != army_to_transfer:
			other_armies.append(child as Army)
	hide_move_modal()
	if other_armies.size() > 0:
		if transfer_select_modal != null:
			transfer_select_modal.show_transfer_selection(army_to_transfer, region_to_transfer, other_armies)
	else:
		if transfer_soldiers_modal != null:
			transfer_soldiers_modal.show_transfer_to_garrison(army_to_transfer, region_to_transfer)

func _on_make_camp_pressed() -> void:
	"""Handle Make Camp button press"""
	if make_camp_button.disabled:
		return
	if sound_manager:
		sound_manager.click_sound()
	if selected_army:
		selected_army.make_camp()
		army_manager.refresh_selected_move_targets()
		_update_action_buttons_state()
		_refresh_info_modal()

func _on_army_movement_points_changed(army: Army, new_points: int) -> void:
	if army == selected_army:
		_update_action_buttons_state()

func _selected_army_has_action_points() -> bool:
	if selected_army == null:
		return false
	return selected_army.get_movement_points() > 0

func _update_action_buttons_state() -> void:
	var has_action_points: bool = _selected_army_has_action_points()
	var disabled: bool = not has_action_points
	_set_action_button_disabled_state(make_camp_button, disabled)
	_set_action_button_disabled_state(cancel_button, disabled)
	_set_action_button_disabled_state(army_actions_button, disabled)
	_set_action_button_disabled_state(next_army_button, false)
	_hide_no_actions()

func _set_action_button_disabled_state(button: Button, disabled: bool) -> void:
	button.disabled = disabled
	if disabled:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	button.mouse_filter = Control.MOUSE_FILTER_STOP

func _connect_no_actions_hover() -> void:
	_connect_hover_pair(army_actions_button, recruit_button_border)
	_connect_hover_pair(make_camp_button, make_camp_button_border)
	_connect_hover_pair(cancel_button, transfer_button_border)
	_connect_hover_pair(next_army_button, next_army_button_border)

func _connect_hover_pair(button: Button, hover_control: Control) -> void:
	button.mouse_entered.connect(_on_action_hovered.bind(button))
	button.mouse_exited.connect(_on_action_unhovered)
	hover_control.mouse_entered.connect(_on_action_hovered.bind(button))
	hover_control.mouse_exited.connect(_on_action_unhovered)

func _on_action_hovered(button: Button) -> void:
	if not button.disabled:
		_hide_no_actions()
		return
	_show_no_actions_for(button)

func _on_action_unhovered() -> void:
	_hide_no_actions()

func _show_no_actions_for(button: Button) -> void:
	var no_actions: SelectTooltipModalNoRes = get_node("NoActions") as SelectTooltipModalNoRes
	no_actions.show_text(NO_ACTIONS_TEXT)

func _hide_no_actions() -> void:
	var no_actions: SelectTooltipModalNoRes = get_node("NoActions") as SelectTooltipModalNoRes
	no_actions.hide_tooltip()

func _refresh_info_modal() -> void:
	if info_modal.visible and selected_army:
		info_modal.show_army_info(selected_army, false)

func _connect_region_tooltip_hide_on_hover(control: Control) -> void:
	control.mouse_entered.connect(_on_move_modal_control_mouse_entered.bind(control))
	for child in control.get_children():
		if child is Control:
			_connect_region_tooltip_hide_on_hover(child as Control)

func _on_move_modal_control_mouse_entered(control: Control) -> void:
	ui_manager.hide_tooltip_due_to(control)
	_hide_no_actions()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _is_tutorial_mode_active():
		return
	if GameParameters.is_next_army_key_pressed(event):
		if ui_manager.is_recruitment_or_transfer_modal_visible():
			get_viewport().set_input_as_handled()
			accept_event()
			return
		_cycle_to_next_army()
		get_viewport().set_input_as_handled()
		accept_event()
		return
	if GameParameters.is_recruit_key_pressed(event):
		_on_army_actions_pressed()
		get_viewport().set_input_as_handled()
		accept_event()
		return
	if GameParameters.is_camp_rest_key_pressed(event):
		_on_make_camp_pressed()
		get_viewport().set_input_as_handled()
		accept_event()
		return
	if GameParameters.is_transfer_key_pressed(event):
		_on_cancel_move_pressed()
		get_viewport().set_input_as_handled()
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	"""Handle ESC key to cancel move"""
	if not visible:
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and _is_tutorial_mode_active():
			return
		if event.keycode == KEY_ESCAPE:
			_cancel_move()
			get_viewport().set_input_as_handled()
		if _is_tutorial_mode_active():
			return
		if GameParameters.is_next_army_key_pressed(event):
			if ui_manager.is_recruitment_or_transfer_modal_visible():
				get_viewport().set_input_as_handled()
				return
			_cycle_to_next_army()
			get_viewport().set_input_as_handled()
			return
		if GameParameters.is_recruit_key_pressed(event):
			_on_army_actions_pressed()
			get_viewport().set_input_as_handled()
			return
		if GameParameters.is_camp_rest_key_pressed(event):
			_on_make_camp_pressed()
			get_viewport().set_input_as_handled()
			return
		if GameParameters.is_transfer_key_pressed(event):
			_on_cancel_move_pressed()
			get_viewport().set_input_as_handled()

func _is_tutorial_mode_active() -> bool:
	return game_manager != null and game_manager.tutorial_enabled

func set_army_manager(manager: ArmyManager) -> void:
	"""Set the army manager reference"""
	army_manager = manager

func _on_next_army_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	_cycle_to_next_army()

func _cycle_to_next_army() -> void:
	if not visible:
		return
	if game_manager == null or army_manager == null:
		return
	var player_id: int = game_manager.get_current_player_id()
	var next_army: Army = army_manager.select_next_army_for_player(player_id)
	if next_army == null:
		return
	_focus_camera_on_army(next_army)

func _focus_camera_on_army(army: Army) -> void:
	camera_controller.center_on_army(army)
