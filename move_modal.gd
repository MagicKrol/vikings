extends Control
class_name MoveModal

# Reference to ArmyManager for canceling moves
var army_manager: ArmyManager = null

# Reference to the selected army
var selected_army: Army = null

# Reference to the sound manager
var sound_manager: SoundManager = null

func _ready():
	# Get button reference and connect signal
	var button = get_node("Panel/Army/ButtonSection/HBoxContainer/ButtonBorder/Button")
	if button:
		button.pressed.connect(_on_cancel_move_pressed)
	
	# Get sound manager reference
	sound_manager = get_node("../../SoundManager") as SoundManager
	
	# Initially hidden
	visible = false

func show_move_modal(army: Army) -> void:
	"""Show the move modal for the given army"""
	selected_army = army
	visible = true
	
	# Position at bottom center of screen
	# Modal is already positioned in the scene file at offset_top = 360

func hide_move_modal() -> void:
	"""Hide the move modal"""
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
