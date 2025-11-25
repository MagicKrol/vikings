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

func _ready():
	# Get button reference and connect signal
	var cancel_button = get_node("Panel/Army/ButtonSection/HBoxContainer2/ButtonBorder/Button")
	cancel_button.pressed.connect(_on_cancel_move_pressed)
	
	var make_camp_button = get_node("Panel/Army/ButtonSection/HBoxContainer/ButtonBorder/MakeCamp")
	make_camp_button.pressed.connect(_on_make_camp_pressed)
	
	# Get sound manager reference
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	info_modal = get_node("../InfoModal") as InfoModal
	mouse_entered.connect(_on_mouse_entered)
	var panel = get_node("Panel") as Control
	panel.mouse_entered.connect(_on_panel_mouse_entered)
	
	# Initially hidden
	visible = false

func show_move_modal(army: Army) -> void:
	"""Show the move modal for the given army"""
	selected_army = army
	if selected_army and not selected_army.movement_points_changed.is_connected(_on_army_movement_points_changed):
		selected_army.movement_points_changed.connect(_on_army_movement_points_changed)
	
	_update_make_camp_button_state()
	visible = true
	
	# Position at bottom center of screen
	# Modal is already positioned in the scene file at offset_top = 360

func hide_move_modal() -> void:
	"""Hide the move modal"""
	if selected_army and selected_army.movement_points_changed.is_connected(_on_army_movement_points_changed):
		selected_army.movement_points_changed.disconnect(_on_army_movement_points_changed)
	visible = false
	selected_army = null

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

func _on_make_camp_pressed() -> void:
	"""Handle Make Camp button press"""
	if sound_manager:
		sound_manager.click_sound()
	if selected_army:
		selected_army.make_camp()
		_update_make_camp_button_state()
		_refresh_info_modal()

func _on_army_movement_points_changed(army: Army, new_points: int) -> void:
	if army == selected_army:
		_update_make_camp_button_state()

func _update_make_camp_button_state() -> void:
	var make_camp_button = get_node("Panel/Army/ButtonSection/HBoxContainer/ButtonBorder/MakeCamp")
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

func _unhandled_input(event: InputEvent) -> void:
	"""Handle ESC key to cancel move"""
	if not visible:
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_cancel_move()
			get_viewport().set_input_as_handled()

func set_army_manager(manager: ArmyManager) -> void:
	"""Set the army manager reference"""
	army_manager = manager
