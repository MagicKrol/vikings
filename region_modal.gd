extends Control
class_name RegionModal

# Styling constants (same as UIModal)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# Current region reference
var current_region: Region = null
# UI manager reference for modal mode
var ui_manager: UIManager = null
# Sound manager reference
var sound_manager: SoundManager = null

func _ready():
	# Get UI manager reference
	ui_manager = get_node("../UIManager") as UIManager
	
	# Get sound manager reference
	sound_manager = get_node("../../SoundManager") as SoundManager
	
	# Initially hidden
	visible = false

func show_region_info(region: Region, manage_modal_mode: bool = true) -> void:
	"""Show the modal with region information"""
	if region == null:
		hide_modal()
		return
	
	current_region = region
	_update_display()
	visible = true
	
	# Set modal mode active only if requested
	if manage_modal_mode and ui_manager:
		ui_manager.set_modal_active(true)

func hide_modal(manage_modal_mode: bool = true) -> void:
	"""Hide the modal"""
	current_region = null
	visible = false
	
	# Set modal mode inactive only if requested
	if manage_modal_mode and ui_manager:
		ui_manager.set_modal_active(false)


func _draw():
	# Draw shadow first (behind everything)
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)
	
	# Draw black border
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)

func _update_display() -> void:
	"""Update the display with current region information"""
	if current_region == null:
		hide_modal()
		return
	
	# Update header label with region name
	var header_label = get_node("HeaderLabel")
	header_label.text = current_region.get_region_name()
	
	# Update type label with region type
	var type_label = get_node("TypeLabel")
	var region_type_name = current_region.get_region_type_display_string()
	type_label.text = "Region Type: " + region_type_name
	
	# Update level label with region level
	var level_label = get_node("LevelLabel")
	var region_level_name = RegionLevelEnum.level_to_string(current_region.get_region_level())
	level_label.text = "Level: " + region_level_name
	
	# Update resources label with resource and population information
	var resources_label = get_node("ResourcesLabel")
	var population = current_region.get_population()
	var available_recruits = current_region.get_available_recruits()
	var max_recruits = current_region.get_max_recruits()
	
	var resources_text = "Population: " + str(population) + "\n"
	resources_text += "Recruits: " + str(available_recruits) + "/" + str(max_recruits) + "\n\nResources:\n"
	
	if current_region.resources and current_region.resources.has_resources():
		# Show each resource with its amount (but only if it can be collected)
		for resource_type in ResourcesEnum.get_all_types():
			var amount = current_region.get_resource_amount(resource_type)
			if amount > 0 and current_region.can_collect_resource(resource_type):  # Only show resources that have a positive amount and can be collected
				var resource_name = ResourcesEnum.type_to_string(resource_type)
				resource_name = resource_name.capitalize()
				resources_text += resource_name + ": " + str(amount) + "\n"
		
		# If no resources have positive amounts, show "None"
		var expected_prefix = "Population: " + str(population) + "\n" + "Recruits: " + str(available_recruits) + "/" + str(max_recruits) + "\n\nResources:\n"
		if resources_text == expected_prefix:
			resources_text += "None"
	else:
		resources_text += "None"
	
	resources_label.text = resources_text.strip_edges()
	
	print("[RegionModal] Showing info for region: ", current_region.get_region_name())
