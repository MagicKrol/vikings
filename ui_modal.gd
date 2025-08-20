extends Control
class_name UIModal

# Styling constants
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# UI manager reference for modal mode
var ui_manager: UIManager = null
# Sound manager reference
var sound_manager: SoundManager = null
# Close button reference
var close_button: Button = null

# UI elements for army display
var army_header: Label = null
var movement_label: Label = null
var morale_label: Label = null
var composition_container: VBoxContainer = null

# Current army reference
var current_army: Army = null

func _ready():
	# Set up the modal - center it on screen
	custom_minimum_size = Vector2(400, 300)
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -200
	offset_top = -150
	offset_right = 200
	offset_bottom = 150
	
	# Get references
	ui_manager = get_node("../UIManager") as UIManager
	sound_manager = get_node("../../SoundManager") as SoundManager
	close_button = get_node("CloseButton") as Button
	
	# Get UI element references
	army_header = get_node("ContentContainer/ArmyHeader") as Label
	movement_label = get_node("ContentContainer/MovementLabel") as Label
	morale_label = get_node("ContentContainer/MoraleLabel") as Label
	composition_container = get_node("ContentContainer/CompositionContainer") as VBoxContainer
	
	# Set styling for existing labels
	if army_header:
		army_header.add_theme_color_override("font_color", Color.WHITE)
	
	# Set other labels styling
	for label in [movement_label, morale_label]:
		if label:
			label.add_theme_color_override("font_color", Color.WHITE)
	
	# Connect close button
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Initially hidden
	visible = false

func show_modal() -> void:
	"""Show the modal"""
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)

func show_army_info(army: Army) -> void:
	"""Show the modal with army information"""
	if army == null:
		hide_modal()
		return
	
	current_army = army
	_update_army_display()
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

func _update_army_display() -> void:
	"""Update the display with current army information"""
	if current_army == null:
		hide_modal()
		return
	
	# Update army header - larger font, uppercase
	if army_header:
		army_header.text = current_army.name.to_upper()
	
	# Update movement label
	if movement_label:
		var current_points = current_army.get_movement_points()
		movement_label.text = "Movement: " + str(current_points) + " / 5"
	
	# Update morale label (hardcoded to 100% for now)
	if morale_label:
		morale_label.text = "Morale: 100%"
	
	# Update composition - create individual labels for each unit type
	_update_composition_display()

func _update_composition_display() -> void:
	"""Create individual labels for each unit type"""
	if not composition_container:
		return
	
	# Clear existing composition labels
	for child in composition_container.get_children():
		child.queue_free()
	
	if current_army == null:
		return
	
	# Get army composition and parse it
	var composition_text = current_army.get_army_composition_string()
	
	# Split by commas to get individual unit entries
	var unit_entries = composition_text.split(", ")
	
	for entry in unit_entries:
		if entry.strip_edges() != "":
			# Create a new label for each unit type
			var unit_label = Label.new()
			unit_label.text = entry.strip_edges()
			unit_label.theme = preload("res://themes/standard_text_theme.tres")
			unit_label.add_theme_color_override("font_color", Color.WHITE)
			unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			composition_container.add_child(unit_label)

func _on_close_pressed() -> void:
	"""Handle close button press"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	hide_modal()

func _draw():
	# Draw black border
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)
	
	# Draw shadow
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)
