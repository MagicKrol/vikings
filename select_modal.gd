extends Control
class_name SelectModal

# Styling constants (same as UIModal)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# UI elements
@onready var button_container: VBoxContainer = $ButtonContainer

# Current region and armies
var current_region: Region = null
var current_armies: Array[Army] = []

# Sound manager reference
var sound_manager: SoundManager = null
# UI manager reference for modal mode
var ui_manager: UIManager = null
# References to other modals
var army_modal: Control = null  # Using ArmyModal instead
var region_modal: RegionModal = null
var army_select_modal: ArmySelectModal = null
var region_select_modal: RegionSelectModal = null
var info_modal: InfoModal = null
var select_tooltip_modal: SelectTooltipModal = null

func _ready():
	# Get sound manager reference
	sound_manager = get_node("../../SoundManager") as SoundManager
	
	# Get UI manager reference
	ui_manager = get_node("../UIManager") as UIManager
	
	# Get references to other modals
	army_modal = get_node("../ArmyModal") as Control
	region_modal = get_node("../RegionModal") as RegionModal
	army_select_modal = get_node("../ArmySelectModal") as ArmySelectModal
	region_select_modal = get_node("../RegionSelectModal") as RegionSelectModal
	info_modal = get_node("../InfoModal") as InfoModal
	select_tooltip_modal = get_node("../SelectTooltipModal") as SelectTooltipModal
	
	# Initially hidden
	visible = false

func show_selection(region: Region, armies: Array[Army]) -> void:
	"""Show the selection modal with region and armies"""
	if region == null or armies.is_empty():
		hide_modal()
		return
	
	current_region = region
	current_armies = armies
	_create_buttons()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)

func hide_modal() -> void:
	"""Hide the modal and clear content"""
	current_region = null
	current_armies.clear()
	_clear_buttons()
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _create_buttons() -> void:
	"""Create buttons for region and armies"""
	_clear_buttons()
	
	# Create region button (first button)
	var region_button = Button.new()
	region_button.text = current_region.get_region_name()
	region_button.custom_minimum_size = Vector2(260, 40)  # Slightly smaller than modal width (300)
	region_button.add_theme_color_override("font_color", Color.WHITE)
	region_button.pressed.connect(_on_region_button_pressed)
	region_button.mouse_entered.connect(_on_region_button_hovered)
	region_button.mouse_entered.connect(_on_region_tooltip_hovered)
	region_button.mouse_exited.connect(_on_button_unhovered)
	button_container.add_child(region_button)
	
	# Create army buttons
	for i in range(current_armies.size()):
		var army = current_armies[i]
		var army_button = Button.new()
		army_button.text = "Army " + str(army.number)
		army_button.custom_minimum_size = Vector2(260, 40)
		army_button.add_theme_color_override("font_color", Color.WHITE)
		army_button.pressed.connect(_on_army_button_pressed.bind(army))
		army_button.mouse_entered.connect(_on_army_button_hovered.bind(army))
		army_button.mouse_entered.connect(_on_army_tooltip_hovered)
		army_button.mouse_exited.connect(_on_button_unhovered)
		button_container.add_child(army_button)

func _draw():
	# Draw shadow first (behind everything)
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)
	
	# Draw black border
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)

func _clear_buttons() -> void:
	"""Remove all buttons from container"""
	for child in button_container.get_children():
		child.queue_free()

func _on_region_button_pressed() -> void:
	"""Handle region button click - open RegionSelectModal"""
	# Store region reference before hiding modal
	var region_to_show = current_region
	
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Hide this modal
	hide_modal()
	
	# Show RegionSelectModal
	if region_select_modal != null and region_to_show != null and is_instance_valid(region_select_modal) and is_instance_valid(region_to_show):
		region_select_modal.show_region_actions(region_to_show)

func _on_army_button_pressed(army: Army) -> void:
	"""Handle army button click - open ArmySelectModal"""
	# Store army and region references
	var army_to_show = army
	var region_to_show = current_region
	
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Hide this modal
	hide_modal()
	
	# Show ArmySelectModal with army actions
	if army_select_modal != null and army_to_show != null and is_instance_valid(army_select_modal) and is_instance_valid(army_to_show):
		army_select_modal.show_army_actions(army_to_show, region_to_show)

func _on_region_button_hovered() -> void:
	"""Handle region button hover - show InfoModal with region info"""
	if info_modal != null and current_region != null and is_instance_valid(info_modal) and is_instance_valid(current_region):
		info_modal.show_region_info(current_region, false)  # Don't manage modal mode

func _on_army_button_hovered(army: Army) -> void:
	"""Handle army button hover - show InfoModal with army info"""
	if info_modal != null and army != null and is_instance_valid(info_modal) and is_instance_valid(army):
		info_modal.show_army_info(army, false)  # Don't manage modal mode

func _on_button_unhovered() -> void:
	"""Handle button unhover - hide InfoModal and tooltip"""
	if info_modal != null and info_modal.visible:
		info_modal.hide_modal(false)  # Don't manage modal mode
	if select_tooltip_modal != null:
		select_tooltip_modal.hide_tooltip()

func _on_region_tooltip_hovered() -> void:
	"""Handle region button hover - show tooltip"""
	if select_tooltip_modal != null:
		select_tooltip_modal.show_tooltip("region")

func _on_army_tooltip_hovered() -> void:
	"""Handle army button hover - show tooltip"""
	if select_tooltip_modal != null:
		select_tooltip_modal.show_tooltip("army")

