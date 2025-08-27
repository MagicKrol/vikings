extends Control
class_name CallToArmsModal

# Styling constants (same as other modals)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# UI elements - references to static nodes from scene
var call_to_arms_title_label: Label
var regions_header_label: Label
var called_recruits_header_label: Label
var available_recruits_header_label: Label
var regions_container: VBoxContainer
var continue_button: Button

# Call to Arms data
var target_region: Region = null
var neighboring_regions: Array[Region] = []
var called_recruits: Dictionary = {} # region_id -> count to call
var total_called: int = 0

# Manager references
var sound_manager: SoundManager = null
var ui_manager: UIManager = null
var game_manager: GameManager = null

func _ready():
	# Get references to static UI elements from scene
	call_to_arms_title_label = get_node("BorderMargin/MainContainer/TitleContainer/CallToArmsTitleLabel")
	regions_header_label = get_node("BorderMargin/MainContainer/HeaderContainer/HeaderRow/RegionsHeaderLabel")
	called_recruits_header_label = get_node("BorderMargin/MainContainer/HeaderContainer/HeaderRow/CalledRecruitsHeaderLabel")
	available_recruits_header_label = get_node("BorderMargin/MainContainer/HeaderContainer/HeaderRow/AvailableRecruitsHeaderLabel")
	regions_container = get_node("BorderMargin/MainContainer/MainContent/RegionsContainer")
	continue_button = get_node("BorderMargin/MainContainer/ButtonContainer/ContinueButton")
	
	# Connect button signal
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Get manager references
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	game_manager = get_node("../../GameManager") as GameManager
	
	# Initially hidden
	visible = false

func show_call_to_arms(region: Region) -> void:
	"""Show the call to arms modal for the specified region"""
	if region == null:
		hide_modal()
		return
	
	target_region = region
	
	# Reset state
	called_recruits.clear()
	total_called = 0
	
	# Get neighboring regions owned by the same player
	_find_neighboring_regions()
	
	# Update display
	_update_display()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)

func hide_modal() -> void:
	"""Hide the call to arms modal"""
	# Reset state
	target_region = null
	neighboring_regions.clear()
	called_recruits.clear()
	total_called = 0
	
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _find_neighboring_regions() -> void:
	"""Find all neighboring regions owned by the same player"""
	neighboring_regions.clear()
	
	if target_region == null or game_manager == null:
		return
	
	# Get region manager from game manager
	var region_manager = game_manager.get_region_manager()
	if region_manager == null:
		return
	
	# Get the player who owns the target region
	var target_region_owner = region_manager.get_region_owner(target_region.get_region_id())
	if target_region_owner == -1:
		return  # Unowned region
	
	# Get all neighboring region IDs
	var neighbor_ids = region_manager.get_neighbor_regions(target_region.get_region_id())
	
	# Get map generator to find region nodes
	var map_generator = game_manager.get_node("../Map") as MapGenerator
	if map_generator == null:
		return
	
	var regions_node = map_generator.get_node_or_null("Regions")
	if regions_node == null:
		return
	
	# Find neighboring regions owned by the same player
	for neighbor_id in neighbor_ids:
		var neighbor_owner = region_manager.get_region_owner(neighbor_id)
		if neighbor_owner == target_region_owner:
			# Find the region node
			for child in regions_node.get_children():
				if child is Region and child.get_region_id() == neighbor_id:
					neighboring_regions.append(child)
					break

func _update_display() -> void:
	"""Update the display with current call to arms information"""
	if target_region == null:
		hide_modal()
		return
	
	# Update title
	call_to_arms_title_label.text = "Call to Arms"
	
	# Update headers
	regions_header_label.text = "Regions"
	called_recruits_header_label.text = "Called Recruits"
	available_recruits_header_label.text = "Available Recruits"
	
	# Update regions display
	_update_regions_display()

func _update_regions_display() -> void:
	"""Update the regions list with call to arms controls"""
	# Clear existing displays
	for child in regions_container.get_children():
		child.queue_free()
	
	# Create rows for neighboring regions
	for region in neighboring_regions:
		_create_region_row(region)

func _create_region_row(region: Region) -> void:
	"""Create a single region row with: Region Name | Called Recruits | Buttons | Available Recruits"""
	# Add margin before this row (except for the first row)
	if regions_container.get_child_count() > 0:
		var margin = MarginContainer.new()
		margin.custom_minimum_size = Vector2(0, 5)
		regions_container.add_child(margin)
	
	# Main row container
	var row_container = HBoxContainer.new()
	row_container.add_theme_constant_override("separation", 0)
	regions_container.add_child(row_container)
	
	# Region name (left-aligned, 200px width)
	var region_label = Label.new()
	region_label.text = region.get_region_name()
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	region_label.custom_minimum_size = Vector2(200, 0)
	region_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_standard_theme(region_label)
	row_container.add_child(region_label)
	
	# Margin 50px
	var margin1 = Control.new()
	margin1.custom_minimum_size = Vector2(50, 0)
	row_container.add_child(margin1)
	
	# Called recruits count (center-aligned, 80px width)
	var called_count_label = Label.new()
	var region_id = region.get_region_id()
	var count_called = called_recruits.get(region_id, 0)
	called_count_label.text = str(count_called)
	called_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	called_count_label.custom_minimum_size = Vector2(80, 0)
	called_count_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	called_count_label.name = "CalledCount_" + str(region_id)
	_apply_standard_theme(called_count_label)
	row_container.add_child(called_count_label)
	
	# Margin 20px
	var margin2 = Control.new()
	margin2.custom_minimum_size = Vector2(20, 0)
	row_container.add_child(margin2)
	
	# Call buttons: |< < > >|
	var call_max_button = Button.new()
	call_max_button.text = "|<"
	call_max_button.custom_minimum_size = Vector2(30, 25)
	call_max_button.pressed.connect(_on_call_max_pressed.bind(region))
	row_container.add_child(call_max_button)
	
	var call_one_button = Button.new()
	call_one_button.text = "<"
	call_one_button.custom_minimum_size = Vector2(25, 25)
	call_one_button.pressed.connect(_on_call_one_pressed.bind(region))
	row_container.add_child(call_one_button)
	
	var uncall_one_button = Button.new()
	uncall_one_button.text = ">"
	uncall_one_button.custom_minimum_size = Vector2(25, 25)
	uncall_one_button.pressed.connect(_on_uncall_one_pressed.bind(region))
	row_container.add_child(uncall_one_button)
	
	var uncall_all_button = Button.new()
	uncall_all_button.text = ">|"
	uncall_all_button.custom_minimum_size = Vector2(30, 25)
	uncall_all_button.pressed.connect(_on_uncall_all_pressed.bind(region))
	row_container.add_child(uncall_all_button)
	
	# Margin 20px
	var margin3 = Control.new()
	margin3.custom_minimum_size = Vector2(20, 0)
	row_container.add_child(margin3)
	
	# Available recruits (right-aligned, 80px width)
	var available_label = Label.new()
	available_label.text = str(region.get_available_recruits())
	available_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	available_label.custom_minimum_size = Vector2(80, 0)
	available_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_standard_theme(available_label)
	row_container.add_child(available_label)

# Button handlers
func _on_call_max_pressed(region: Region) -> void:
	"""Call maximum possible recruits from this region"""
	var region_id = region.get_region_id()
	var available_recruits = region.get_available_recruits()
	var current_called = called_recruits.get(region_id, 0)
	var max_to_call = available_recruits - current_called
	
	if max_to_call > 0:
		called_recruits[region_id] = available_recruits
		total_called += max_to_call
		_update_regions_display()

func _on_call_one_pressed(region: Region) -> void:
	"""Call one recruit from this region"""
	var region_id = region.get_region_id()
	var available_recruits = region.get_available_recruits()
	var current_called = called_recruits.get(region_id, 0)
	
	if current_called < available_recruits:
		called_recruits[region_id] = current_called + 1
		total_called += 1
		_update_regions_display()

func _on_uncall_one_pressed(region: Region) -> void:
	"""Uncall one recruit from this region"""
	var region_id = region.get_region_id()
	var current_called = called_recruits.get(region_id, 0)
	
	if current_called > 0:
		called_recruits[region_id] = current_called - 1
		total_called -= 1
		if called_recruits[region_id] == 0:
			called_recruits.erase(region_id)
		_update_regions_display()

func _on_uncall_all_pressed(region: Region) -> void:
	"""Uncall all recruits from this region"""
	var region_id = region.get_region_id()
	if called_recruits.has(region_id):
		var count_to_uncall = called_recruits[region_id]
		total_called -= count_to_uncall
		called_recruits.erase(region_id)
		_update_regions_display()

func _on_continue_pressed() -> void:
	"""Handle Continue button press"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Apply call to arms if any recruits were called
	if not called_recruits.is_empty():
		_apply_call_to_arms()
	
	# Hide modal
	hide_modal()

func _apply_call_to_arms() -> void:
	"""Apply the call to arms - move recruits from neighboring regions to target region"""
	if target_region == null:
		return
	
	print("[CallToArmsModal] Applying call to arms to ", target_region.get_region_name())
	
	# Move recruits from each region to the target region
	for region_id in called_recruits:
		var count_to_move = called_recruits[region_id]
		if count_to_move > 0:
			# Find the source region
			var source_region: Region = null
			for region in neighboring_regions:
				if region.get_region_id() == region_id:
					source_region = region
					break
			
			if source_region != null:
				# Remove recruits from source region (like hiring them)
				var actual_moved = source_region.hire_recruits(count_to_move)
				
				# Add recruits directly to target region (exceeding max if needed)
				target_region.available_recruits += actual_moved
				
				print("[CallToArmsModal] Moved ", actual_moved, " recruits from ", source_region.get_region_name(), " to ", target_region.get_region_name())
				print("[CallToArmsModal] ", target_region.get_region_name(), " now has ", target_region.get_available_recruits(), "/", target_region.get_max_recruits(), " recruits")

func _apply_standard_theme(label: Label) -> void:
	"""Apply standard theme to a label"""
	label.theme = preload("res://themes/standard_text_theme.tres")
	label.add_theme_color_override("font_color", Color.WHITE)

func _draw():
	# Draw shadow first (behind everything)
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)
	
	# Draw background fill
	var bg_rect = Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, FRAME_COLOR)
	
	# Draw black border on top
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)