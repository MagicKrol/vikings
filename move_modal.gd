extends Control
class_name MoveModal

# Reference to ArmyManager for canceling moves
var army_manager: ArmyManager = null

# Reference to the selected army
var selected_army: Army = null

# Reference to the sound manager
var sound_manager: SoundManager = null
var ui_manager: UIManager = null
var info_modal: InfoModal = null
var tutorial_manager: TutorialManager = null
var game_manager: GameManager = null
var camera_controller: CameraController = null
var make_camp_button: Button = null
var cancel_button: Button = null
var army_actions_button: Button = null
var next_army_button: Button = null

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
	set_process_input(true)
	
	# Get sound manager reference
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	info_modal = get_node("../InfoModal") as InfoModal
	game_manager = get_node("../../GameManager") as GameManager
	camera_controller = get_node("../../Camera2D") as CameraController
	if game_manager:
		tutorial_manager = game_manager.get_tutorial_manager()
		if tutorial_manager != null:
			if make_camp_button:
				make_camp_button.name = "make_camp"
				make_camp_button.pressed.connect(func(): tutorial_manager.handle_ui_click("MoveModal/" + make_camp_button.name))
			if cancel_button:
				cancel_button.name = "cancel_move"
				cancel_button.pressed.connect(func(): tutorial_manager.handle_ui_click("MoveModal/" + cancel_button.name))
			if army_actions_button:
				army_actions_button.name = "army_actions"
				army_actions_button.pressed.connect(func(): tutorial_manager.handle_ui_click("MoveModal/" + army_actions_button.name))
	mouse_entered.connect(_on_mouse_entered)
	var panel = get_node("Panel") as Control
	panel.mouse_entered.connect(_on_panel_mouse_entered)
	
	# Initially hidden
	visible = false

func show_move_modal(army: Army) -> void:
	"""Show the move modal for the given army"""
	var previous_army: Army = selected_army
	if previous_army and previous_army.movement_points_changed.is_connected(_on_army_movement_points_changed):
		previous_army.movement_points_changed.disconnect(_on_army_movement_points_changed)
	selected_army = army
	if selected_army and not selected_army.movement_points_changed.is_connected(_on_army_movement_points_changed):
		selected_army.movement_points_changed.connect(_on_army_movement_points_changed)
	
	_update_make_camp_button_state()
	ui_manager.set_modal_active(false)
	visible = true
	ui_manager.set_overlay_suppressed(true)
	
	# Position at bottom center of screen
	# Modal is already positioned in the scene file at offset_top = 360

func hide_move_modal() -> void:
	"""Hide the move modal"""
	if selected_army and selected_army.movement_points_changed.is_connected(_on_army_movement_points_changed):
		selected_army.movement_points_changed.disconnect(_on_army_movement_points_changed)
	visible = false
	selected_army = null
	ui_manager.set_overlay_suppressed(false)

func _on_cancel_move_pressed() -> void:
	"""Handle cancel move button press"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	_cancel_move()

func _cancel_move() -> void:
	"""Cancel the current move operation"""
	if army_manager:
		army_manager.deselect_army()
	hide_move_modal()

func _on_army_actions_pressed() -> void:
	sound_manager.click_sound()
	var army := selected_army
	_cancel_move()
	info_modal.show_army_info(army)

func _on_make_camp_pressed() -> void:
	"""Handle Make Camp button press"""
	if sound_manager:
		sound_manager.click_sound()
	if selected_army:
		if selected_army.get_movement_points() <= 0:
			_update_make_camp_button_state()
			return
		selected_army.make_camp()
		_update_make_camp_button_state()
		_refresh_info_modal()

func _on_army_movement_points_changed(army: Army, new_points: int) -> void:
	if army == selected_army:
		_update_make_camp_button_state()

func _update_make_camp_button_state() -> void:
	if make_camp_button == null:
		return
	if selected_army:
		make_camp_button.disabled = selected_army.get_movement_points() <= 0
	else:
		make_camp_button.disabled = true

func _refresh_info_modal() -> void:
	if info_modal.visible and selected_army:
		info_modal.show_army_info(selected_army, false)

func _on_mouse_entered() -> void:
	ui_manager.hide_tooltip_due_to(self)

func _on_panel_mouse_entered() -> void:
	ui_manager.hide_tooltip_due_to(self)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_cycle_to_next_army()
		get_viewport().set_input_as_handled()
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	"""Handle ESC key to cancel move"""
	if not visible:
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_cancel_move()
			get_viewport().set_input_as_handled()
		if event.keycode == KEY_SPACE:
			_cycle_to_next_army()
			get_viewport().set_input_as_handled()

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
