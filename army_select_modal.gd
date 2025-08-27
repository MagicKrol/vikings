extends Control
class_name ArmySelectModal

# Styling constants (same as UIModal)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# UI elements
@onready var button_container: VBoxContainer = $ButtonContainer

# Current army and region
var current_army: Army = null
var current_region: Region = null

# Sound manager reference
var sound_manager: SoundManager = null
# UI manager reference for modal mode
var ui_manager: UIManager = null
# References to other modals
var select_modal: SelectModal = null
var info_modal: InfoModal = null
var recruitment_modal: RecruitmentModal = null
var transfer_soldiers_modal: TransferSoldiersModal = null
var transfer_select_modal: TransferSelectModal = null
var select_tooltip_modal: SelectTooltipModal = null
# Army manager reference for movement
var army_manager: ArmyManager = null
# Game manager reference for current player
var game_manager: GameManager = null

func _ready():
	# Get sound manager reference
	sound_manager = get_node("../../SoundManager") as SoundManager
	
	# Get UI manager reference
	ui_manager = get_node("../UIManager") as UIManager
	
	# Get reference to SelectModal
	select_modal = get_node("../SelectModal") as SelectModal
	
	# Get reference to InfoModal
	info_modal = get_node("../InfoModal") as InfoModal
	
	# Get reference to RecruitmentModal
	recruitment_modal = get_node("../RecruitmentModal") as RecruitmentModal
	
	# Get reference to TransferSoldiersModal
	transfer_soldiers_modal = get_node("../TransferSoldiersModal") as TransferSoldiersModal
	
	# Get reference to TransferSelectModal
	transfer_select_modal = get_node("../TransferSelectModal") as TransferSelectModal
	
	# Get reference to SelectTooltipModal
	select_tooltip_modal = get_node("../SelectTooltipModal") as SelectTooltipModal
	
	# Get army manager reference from ClickManager
	var click_manager = get_node("../../ClickManager")
	if click_manager and click_manager.has_method("get_army_manager"):
		army_manager = click_manager.get_army_manager()
	
	# Get game manager reference
	game_manager = get_node("../../GameManager") as GameManager
	
	# Initially hidden
	visible = false

func show_army_actions(army: Army, region: Region) -> void:
	"""Show the army action modal"""
	if army == null:
		hide_modal()
		return
	
	current_army = army
	current_region = region
	_create_action_buttons()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)
	
	# Always show the army info in InfoModal
	if info_modal != null and current_army != null:
		info_modal.show_army_info(current_army, false)  # Don't manage modal mode

func hide_modal() -> void:
	"""Hide the modal and clear content"""
	# Hide the InfoModal first
	if info_modal != null and info_modal.visible:
		info_modal.hide_modal(false)  # Don't manage modal mode
	
	current_army = null
	current_region = null
	_clear_buttons()
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _create_action_buttons() -> void:
	"""Create action buttons for the army"""
	_clear_buttons()
	
	# Move Army button
	var move_button = Button.new()
	move_button.text = "Move Army"
	move_button.custom_minimum_size = Vector2(260, 40)
	move_button.add_theme_color_override("font_color", Color.WHITE)
	move_button.pressed.connect(_on_move_army_pressed)
	move_button.mouse_entered.connect(_on_tooltip_hovered.bind("move_army"))
	move_button.mouse_exited.connect(_on_tooltip_unhovered)
	button_container.add_child(move_button)
	
	# Make Camp button
	var camp_button = Button.new()
	camp_button.text = "Make Camp"
	camp_button.custom_minimum_size = Vector2(260, 40)
	camp_button.add_theme_color_override("font_color", Color.WHITE)
	camp_button.pressed.connect(_on_make_camp_pressed)
	camp_button.mouse_entered.connect(_on_tooltip_hovered.bind("make_camp"))
	camp_button.mouse_exited.connect(_on_tooltip_unhovered)
	button_container.add_child(camp_button)
	
	# Transfer Soldiers button
	var muster_button = Button.new()
	muster_button.text = "Transfer Soldiers"
	muster_button.custom_minimum_size = Vector2(260, 40)
	muster_button.add_theme_color_override("font_color", Color.WHITE)
	muster_button.pressed.connect(_on_muster_soldiers_pressed)
	muster_button.mouse_entered.connect(_on_tooltip_hovered.bind("transfer_soldiers"))
	muster_button.mouse_exited.connect(_on_tooltip_unhovered)
	button_container.add_child(muster_button)
	
	# Recruit Soldiers button
	var recruit_button = Button.new()
	recruit_button.text = "Recruit Soldiers"
	recruit_button.custom_minimum_size = Vector2(260, 40)
	recruit_button.add_theme_color_override("font_color", Color.WHITE)
	recruit_button.pressed.connect(_on_recruit_soldiers_pressed)
	recruit_button.mouse_entered.connect(_on_tooltip_hovered.bind("recruit_soldiers"))
	recruit_button.mouse_exited.connect(_on_tooltip_unhovered)
	button_container.add_child(recruit_button)
	
	# Back button
	var back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(260, 40)
	back_button.add_theme_color_override("font_color", Color.WHITE)
	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_entered.connect(_on_tooltip_hovered.bind("back"))
	back_button.mouse_exited.connect(_on_tooltip_unhovered)
	button_container.add_child(back_button)

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

func _on_move_army_pressed() -> void:
	"""Handle Move Army button - select army for movement"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Select army for movement using existing army manager logic
	if army_manager != null and current_army != null and current_region != null and game_manager != null:
		# Get the region container - we need to find the node that contains the army
		var region_container = current_army.get_parent()
		if region_container != null:
			var current_player_id = game_manager.get_current_player_id()
			army_manager.select_army(current_army, region_container, current_player_id)
	
	# Hide only the ArmySelectModal, but keep InfoModal visible
	# Don't call hide_modal() as it would hide InfoModal too
	current_army = null
	current_region = null
	_clear_buttons()
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _on_make_camp_pressed() -> void:
	"""Handle Make Camp button - subtract 1 from movement points"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Make camp - this will reduce movement points and potentially other effects
	if current_army and current_army.has_method("make_camp"):
		current_army.make_camp()
		
		# Update the InfoModal to reflect the change
		if info_modal != null and info_modal.visible:
			info_modal.show_army_info(current_army, false)  # Refresh display

func _on_muster_soldiers_pressed() -> void:
	"""Handle Transfer Soldiers button - open transfer modal or transfer select modal"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Store army and region before hiding modal
	var army_to_transfer = current_army
	var region_to_transfer = current_region
	
	# Get all armies in the region (excluding the current army)
	var other_armies: Array[Army] = []
	if region_to_transfer != null:
		for child in region_to_transfer.get_children():
			if child is Army and child != army_to_transfer:
				other_armies.append(child as Army)
	
	# Hide this modal
	hide_modal()
	
	# Check if there are 2+ armies in the region (current army + at least 1 other)
	if other_armies.size() > 0:
		# Multiple armies: show Transfer Select Modal first
		if transfer_select_modal != null and army_to_transfer != null and region_to_transfer != null:
			transfer_select_modal.show_transfer_selection(army_to_transfer, region_to_transfer, other_armies)
	else:
		# Single army: show Transfer Modal directly for Army-to-Garrison transfer
		if transfer_soldiers_modal != null and army_to_transfer != null and region_to_transfer != null:
			transfer_soldiers_modal.show_transfer_to_garrison(army_to_transfer, region_to_transfer)

func _on_recruit_soldiers_pressed() -> void:
	"""Handle Recruit Soldiers button - open recruitment modal"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Store army and region before hiding modal
	var army_to_recruit = current_army
	var region_to_recruit = current_region
	
	# Hide this modal
	hide_modal()
	
	# Show recruitment modal with stored army and region
	if recruitment_modal != null and army_to_recruit != null and region_to_recruit != null:
		recruitment_modal.show_recruitment(army_to_recruit, region_to_recruit)

func _on_back_pressed() -> void:
	"""Handle Back button - return to SelectModal"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Store region and armies data before hiding modal
	var region_to_show = current_region
	var armies_in_region: Array[Army] = []
	
	if region_to_show != null:
		# Get armies in the region by searching through the region container's children
		for child in region_to_show.get_children():
			if child is Army:
				armies_in_region.append(child as Army)
		
		# If no armies found but we have current_army, include it
		if armies_in_region.is_empty() and current_army != null:
			armies_in_region = [current_army]
	
	# Hide this modal
	hide_modal()
	
	# Show SelectModal for the current region
	if select_modal != null and region_to_show != null and is_instance_valid(select_modal) and is_instance_valid(region_to_show):
		select_modal.show_selection(region_to_show, armies_in_region)

func _on_tooltip_hovered(tooltip_key: String) -> void:
	"""Handle button hover - show tooltip"""
	if select_tooltip_modal != null:
		select_tooltip_modal.show_tooltip(tooltip_key)

func _on_tooltip_unhovered() -> void:
	"""Handle button unhover - hide tooltip"""
	if select_tooltip_modal != null:
		select_tooltip_modal.hide_tooltip()
