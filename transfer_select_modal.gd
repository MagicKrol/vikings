extends Control
class_name TransferSelectModal

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
var source_army: Army = null  # The army that wants to transfer soldiers

# Sound manager reference
var sound_manager: SoundManager = null
# UI manager reference for modal mode
var ui_manager: UIManager = null
# References to other modals
var transfer_soldiers_modal: TransferSoldiersModal = null
var info_modal: InfoModal = null

func _ready():
	# Get sound manager reference
	sound_manager = get_node("../../SoundManager") as SoundManager
	
	# Get UI manager reference
	ui_manager = get_node("../UIManager") as UIManager
	
	# Get references to other modals
	transfer_soldiers_modal = get_node("../TransferSoldiersModal") as TransferSoldiersModal
	info_modal = get_node("../InfoModal") as InfoModal
	
	# Initially hidden
	visible = false

func show_transfer_selection(source_army: Army, region: Region, other_armies: Array[Army]) -> void:
	"""Show the transfer selection modal with region and other armies"""
	if source_army == null or region == null:
		hide_modal()
		return
	
	self.source_army = source_army
	current_region = region
	current_armies = other_armies
	_create_buttons()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)

func hide_modal() -> void:
	"""Hide the modal and clear content"""
	source_army = null
	current_region = null
	current_armies.clear()
	_clear_buttons()
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _create_buttons() -> void:
	"""Create buttons for region and other armies"""
	_clear_buttons()
	
	# Create region button (first button) - transfer to garrison
	var region_button = Button.new()
	region_button.text = current_region.get_region_name() + " (Garrison)"
	region_button.custom_minimum_size = Vector2(260, 40)  # Slightly smaller than modal width (300)
	region_button.add_theme_color_override("font_color", Color.WHITE)
	region_button.pressed.connect(_on_region_button_pressed)
	region_button.mouse_entered.connect(_on_region_button_hovered)
	region_button.mouse_exited.connect(_on_button_unhovered)
	button_container.add_child(region_button)
	
	# Create army buttons for other armies in the region
	for i in range(current_armies.size()):
		var army = current_armies[i]
		# Skip the source army (shouldn't be in the list anyway, but safety check)
		if army == source_army:
			continue
			
		var army_button = Button.new()
		army_button.text = "Army " + str(army.number)
		army_button.custom_minimum_size = Vector2(260, 40)
		army_button.add_theme_color_override("font_color", Color.WHITE)
		army_button.pressed.connect(_on_army_button_pressed.bind(army))
		army_button.mouse_entered.connect(_on_army_button_hovered.bind(army))
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
	"""Handle region button click - transfer to garrison"""
	# Store references before hiding modal
	var army_to_transfer = source_army
	var region_to_transfer = current_region
	
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Hide this modal
	hide_modal()
	
	# Show TransferSoldiersModal for army to garrison transfer
	if transfer_soldiers_modal != null and army_to_transfer != null and region_to_transfer != null:
		transfer_soldiers_modal.show_transfer_to_garrison(army_to_transfer, region_to_transfer)

func _on_army_button_pressed(target_army: Army) -> void:
	"""Handle army button click - transfer to another army"""
	# Store references before hiding modal
	var source_army_ref = source_army
	var target_army_ref = target_army
	var region_ref = current_region
	
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Hide this modal
	hide_modal()
	
	# Show TransferSoldiersModal for army to army transfer
	if transfer_soldiers_modal != null and source_army_ref != null and target_army_ref != null and region_ref != null:
		transfer_soldiers_modal.show_transfer_to_army(source_army_ref, target_army_ref, region_ref)

func _on_region_button_hovered() -> void:
	"""Handle region button hover - show InfoModal with region info"""
	if info_modal != null and current_region != null and is_instance_valid(info_modal) and is_instance_valid(current_region):
		info_modal.show_region_info(current_region, false)  # Don't manage modal mode

func _on_army_button_hovered(army: Army) -> void:
	"""Handle army button hover - show InfoModal with army info"""
	if info_modal != null and army != null and is_instance_valid(info_modal) and is_instance_valid(army):
		info_modal.show_army_info(army, false)  # Don't manage modal mode

func _on_button_unhovered() -> void:
	"""Handle button unhover - hide InfoModal"""
	if info_modal != null and info_modal.visible:
		info_modal.hide_modal(false)  # Don't manage modal mode
