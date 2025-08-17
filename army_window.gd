extends Control
class_name ArmyWindow

# UI elements (referenced from scene tree)
var army_label: Label
var movement_label: Label
var composition_label: Label

# Current army reference
var current_army: Army = null
# UI manager reference for modal mode
var ui_manager: UIManager = null

func _ready():
	# Get references to UI elements from the scene tree
	army_label = get_node_or_null("ArmyLabel") as Label
	movement_label = get_node_or_null("MovementLabel") as Label
	composition_label = get_node_or_null("CompositionLabel") as Label
	
	# Get UI manager reference
	ui_manager = get_node_or_null("../UIManager") as UIManager
	
	# Initially hidden
	visible = false

func show_army_info(army: Army) -> void:
	"""Show the modal with army information"""
	if army == null:
		hide_modal()
		return
	
	current_army = army
	_update_display()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)

func hide_modal() -> void:
	"""Hide the modal"""
	current_army = null
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func update_movement_points() -> void:
	"""Update the movement points display"""
	if current_army != null and is_instance_valid(current_army):
		_update_display()

func _update_display() -> void:
	"""Update the display with current army information"""
	if current_army == null or not is_instance_valid(current_army):
		hide_modal()
		return
	
	# Update army label
	var player_id = current_army.get_player_id()
	army_label.text = "Army " + str(player_id)
	
	# Update movement label
	var current_points = current_army.get_movement_points()
	movement_label.text = "Movement: " + str(current_points) + " / 5"
	
	# Change color based on movement points
	if current_points <= 0:
		movement_label.add_theme_color_override("font_color", Color.RED)
	elif current_points <= 2:
		movement_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		movement_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Update composition label
	var composition_text = current_army.get_army_composition_string()
	composition_label.text = "Composition:\n" + composition_text

func _process(_delta: float) -> void:
	"""Check if current army is still valid"""
	if current_army != null and not is_instance_valid(current_army):
		hide_modal()