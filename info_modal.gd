extends Control
class_name InfoModal

# Styling constants (same as UIModal)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# UI manager reference for modal mode
var ui_manager: UIManager = null
# Sound manager reference
var sound_manager: SoundManager = null

# Content container reference
var content_container: VBoxContainer = null

# Current display mode
enum DisplayMode { NONE, ARMY, REGION }
var current_mode: DisplayMode = DisplayMode.NONE

# Current data references
var current_army: Army = null
var current_region: Region = null

# UI elements for army display
var army_header: Label = null
var army_info_container: VBoxContainer = null
var composition_container: VBoxContainer = null

# UI elements for region display
var region_header: Label = null
var region_info_container: VBoxContainer = null

func _ready():
	# Get references
	ui_manager = get_node("../UIManager") as UIManager
	sound_manager = get_node("../../SoundManager") as SoundManager
	content_container = get_node("ContentContainer") as VBoxContainer
	
	# Initially hidden
	visible = false

func show_army_info(army: Army, manage_modal_mode: bool = true) -> void:
	"""Show the modal with army information"""
	if army == null:
		hide_modal()
		return
	
	current_army = army
	current_region = null
	current_mode = DisplayMode.ARMY
	_update_army_display()
	visible = true
	
	# Set modal mode active only if requested
	if manage_modal_mode and ui_manager:
		ui_manager.set_modal_active(true)

func show_region_info(region: Region, manage_modal_mode: bool = true) -> void:
	"""Show the modal with region information"""
	if region == null:
		hide_modal()
		return
	
	current_region = region
	current_army = null
	current_mode = DisplayMode.REGION
	_update_region_display()
	visible = true
	
	# Set modal mode active only if requested
	if manage_modal_mode and ui_manager:
		ui_manager.set_modal_active(true)

func hide_modal(manage_modal_mode: bool = true) -> void:
	"""Hide the modal but keep content intact"""
	visible = false
	
	# Set modal mode inactive only if requested
	if manage_modal_mode and ui_manager:
		ui_manager.set_modal_active(false)

func close_modal() -> void:
	"""Close the modal and clear all content"""
	current_army = null
	current_region = null
	current_mode = DisplayMode.NONE
	_clear_content()
	visible = false
	
	# Always set modal mode inactive when fully closing
	if ui_manager:
		ui_manager.set_modal_active(false)

func _update_army_display() -> void:
	"""Update the display with current army information"""
	if current_army == null:
		hide_modal()
		return
	
	# Only clear and recreate UI if we don't have army UI elements
	if army_header == null or army_info_container == null:
		_clear_content()
		_create_army_ui()
	
	# Update army header
	if army_header:
		army_header.text = current_army.name.to_upper()
	
	# Clear existing info rows
	if army_info_container:
		for child in army_info_container.get_children():
			child.queue_free()
		
		# Add movement information
		var current_points = current_army.get_movement_points()
		_create_info_row(army_info_container, "Movement:", str(current_points) + " / 5")
		
		# Add efficiency information
		var current_efficiency = current_army.get_efficiency()
		_create_info_row(army_info_container, "Efficiency:", str(current_efficiency) + "%")
		
		# Add spacer
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		army_info_container.add_child(spacer)
	
	# Update composition
	_update_composition_display()

func _update_region_display() -> void:
	"""Update the display with current region information"""
	if current_region == null:
		hide_modal()
		return
	
	# Only clear and recreate UI if we don't have region UI elements
	if region_header == null or region_info_container == null:
		_clear_content()
		_create_region_ui()
	
	# Update region header
	if region_header:
		region_header.text = current_region.get_region_name()
	
	# Clear existing info rows
	if region_info_container:
		for child in region_info_container.get_children():
			child.queue_free()
		
		# Add region level
		_create_info_row(region_info_container, "Level:", current_region.get_region_level_string())
		
		# Add region type
		if current_region.is_ocean_region():
			_create_info_row(region_info_container, "Type:", "Ocean Region")
		else:
			var region_type_name = RegionTypeEnum.type_to_string(current_region.get_region_type())
			region_type_name = region_type_name.capitalize().replace("_", " ")
			_create_info_row(region_info_container, "Type:", region_type_name)
		
		# Add spacer
		var spacer1 = Control.new()
		spacer1.custom_minimum_size = Vector2(0, 10)
		region_info_container.add_child(spacer1)
		
		# Add population and recruit information
		var population = current_region.get_population()
		var available_recruits = current_region.get_available_recruits()
		var max_recruits = current_region.get_max_recruits()
		_create_info_row(region_info_container, "Population:", str(population))
		_create_info_row(region_info_container, "Recruits:", str(available_recruits) + "/" + str(max_recruits))
		
		# Add spacer
		var spacer2 = Control.new()
		spacer2.custom_minimum_size = Vector2(0, 10)
		region_info_container.add_child(spacer2)
		
		# Add resources information
		if current_region.resources and current_region.resources.has_resources():
			var has_resources = false
			# Show each resource with its amount (but only if it can be collected)
			for resource_type in ResourcesEnum.get_all_types():
				var amount = current_region.get_resource_amount(resource_type)
				if amount > 0 and current_region.can_collect_resource(resource_type):  # Only show resources that have a positive amount and can be collected
					var resource_name = ResourcesEnum.type_to_string(resource_type)
					resource_name = resource_name.capitalize()
					_create_info_row(region_info_container, resource_name + ":", str(amount))
					has_resources = true
			
			# If no resources have positive amounts, show "None"
			if not has_resources:
				_create_info_row(region_info_container, "Resources:", "None")
		else:
			_create_info_row(region_info_container, "Resources:", "None")

func _create_army_ui() -> void:
	"""Create UI elements for army display"""
	if not content_container:
		return
	
	# Army header
	army_header = Label.new()
	army_header.theme = preload("res://themes/header_text_theme.tres")
	army_header.add_theme_color_override("font_color", Color.WHITE)
	army_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(army_header)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	content_container.add_child(spacer1)
	
	# Army info container (for movement, morale, etc.)
	army_info_container = VBoxContainer.new()
	content_container.add_child(army_info_container)
	
	# Composition container
	composition_container = VBoxContainer.new()
	content_container.add_child(composition_container)

func _create_region_ui() -> void:
	"""Create UI elements for region display"""
	if not content_container:
		return
	
	# Region header
	region_header = Label.new()
	region_header.theme = preload("res://themes/header_text_theme.tres")
	region_header.add_theme_color_override("font_color", Color.WHITE)
	region_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(region_header)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	content_container.add_child(spacer)
	
	# Main region info container (will be populated with rows in _update_region_display)
	region_info_container = VBoxContainer.new()
	content_container.add_child(region_info_container)

func _create_info_row(container: VBoxContainer, text: String, value: String) -> void:
	"""Create a row with text label (300px, left-aligned) and value label (80px, right-aligned)"""
	var row_container = HBoxContainer.new()
	row_container.add_theme_constant_override("separation", 0)
	container.add_child(row_container)
	
	# Text label (300px, left-aligned)
	var text_label = Label.new()
	text_label.text = text
	text_label.theme = preload("res://themes/standard_text_theme.tres")
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_label.custom_minimum_size = Vector2(200, 0)
	text_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row_container.add_child(text_label)
	
	# Value label (80px, right-aligned)
	var value_label = Label.new()
	value_label.text = value
	value_label.theme = preload("res://themes/standard_text_theme.tres")
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(80, 0)
	value_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row_container.add_child(value_label)

func _update_composition_display() -> void:
	"""Create individual labels for each unit type using row layout"""
	if not composition_container or current_army == null:
		return
	
	# Clear existing composition labels
	for child in composition_container.get_children():
		child.queue_free()
	
	# Get army composition directly from the army object
	var composition = current_army.get_composition()
	
	# Show each unit type with its count using the row format
	for unit_type in SoldierTypeEnum.get_all_types():
		var count = composition.get_soldier_count(unit_type)
		if count > 0:  # Only show unit types that exist
			var unit_name = SoldierTypeEnum.type_to_string(unit_type)
			unit_name = unit_name.capitalize() + ":"
			_create_info_row(composition_container, unit_name, str(count))

func _clear_content() -> void:
	"""Clear all content from the container"""
	if not content_container:
		return
	
	for child in content_container.get_children():
		child.queue_free()
	
	# Reset references
	army_header = null
	army_info_container = null
	composition_container = null
	region_header = null
	region_info_container = null


func _draw():
	pass
