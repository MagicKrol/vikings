extends Control
class_name BattleModal

# Styling constants (same as other modals)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# UI elements
var army_label: Label
var army_composition_label: Label
var region_label: Label
var region_composition_label: Label
var ok_button: Button

# Battle data
var attacking_army: Army = null
var defending_region: Region = null

# Sound manager reference
var sound_manager: SoundManager = null
# UI manager reference for modal mode
var ui_manager: UIManager = null

func _ready():
	# Get references to UI elements from the scene tree
	army_label = get_node_or_null("LeftSide/ArmyLabel") as Label
	army_composition_label = get_node_or_null("LeftSide/ArmyCompositionLabel") as Label
	region_label = get_node_or_null("RightSide/RegionLabel") as Label
	region_composition_label = get_node_or_null("RightSide/RegionCompositionLabel") as Label
	ok_button = get_node_or_null("OkButton") as Button
	
	# Get sound manager reference
	sound_manager = get_node_or_null("../../SoundManager") as SoundManager
	
	# Get UI manager reference
	ui_manager = get_node_or_null("../UIManager") as UIManager
	
	# Connect OK button
	if ok_button:
		ok_button.pressed.connect(_on_ok_pressed)
	
	# Apply text themes to match other modals
	_apply_text_themes()
	
	# Initially hidden
	visible = false

func show_battle(army: Army, region: Region) -> void:
	"""Show the battle modal with army vs region information"""
	if army == null or region == null:
		hide_modal()
		return
	
	attacking_army = army
	defending_region = region
	_update_display()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)

func hide_modal() -> void:
	"""Hide the battle modal"""
	attacking_army = null
	defending_region = null
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _update_display() -> void:
	"""Update the display with current battle information"""
	if attacking_army == null or defending_region == null:
		hide_modal()
		return
	
	# Update army information (left side)
	army_label.text = attacking_army.name
	
	var army_composition_text = attacking_army.get_army_composition_string()
	army_composition_label.text = army_composition_text
	
	# Update region information (right side)
	var region_id = defending_region.get_region_id()
	var region_name = defending_region.get_region_name()
	region_label.text = "Region " + str(region_id) + "\n(" + region_name + ")"
	
	var region_composition_text = defending_region.get_garrison_composition_string()
	region_composition_label.text = region_composition_text

func _on_ok_pressed() -> void:
	"""Handle OK button press"""
	# Play click sound for button press
	if sound_manager:
		sound_manager.click_sound()
	hide_modal()

func _apply_text_themes() -> void:
	"""Apply text themes to match other modals"""
	# Apply header theme to main labels (30px font size)
	if army_label:
		army_label.theme = preload("res://themes/header_text_theme.tres")
		army_label.add_theme_color_override("font_color", Color.WHITE)
		army_label.add_theme_font_size_override("font_size", 30)
		army_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if region_label:
		region_label.theme = preload("res://themes/header_text_theme.tres")
		region_label.add_theme_color_override("font_color", Color.WHITE)
		region_label.add_theme_font_size_override("font_size", 30)
		region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Apply standard theme to composition labels (20px font size)
	if army_composition_label:
		army_composition_label.theme = preload("res://themes/standard_text_theme.tres")
		army_composition_label.add_theme_color_override("font_color", Color.WHITE)
		army_composition_label.add_theme_font_size_override("font_size", 20)
		army_composition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	if region_composition_label:
		region_composition_label.theme = preload("res://themes/standard_text_theme.tres")
		region_composition_label.add_theme_color_override("font_color", Color.WHITE)
		region_composition_label.add_theme_font_size_override("font_size", 20)
		region_composition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _draw():
	# Draw black border
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)
	
	# Draw shadow
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)
