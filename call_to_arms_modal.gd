extends Control
class_name CallToArmsModal

# UI elements - references to static nodes from scene
var call_to_arms_title_label: Label
var regions_header_label: Label
var called_recruits_header_label: Label
var available_recruits_header_label: Label
var buttons_header_label: Label
var regions_container: VBoxContainer
var continue_button: Button
var total_available_label: Label
var total_called_label: Label
var region_row_template: HBoxContainer

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
	call_to_arms_title_label = get_node("Panel/Army/Header/HeaderLabel")
	regions_header_label = get_node("Panel/Army/HeaderSection/HeaderRow/RegionsHeaderLabel")
	called_recruits_header_label = get_node("Panel/Army/HeaderSection/HeaderRow/CalledRecruitsHeaderLabel")
	available_recruits_header_label = get_node("Panel/Army/HeaderSection/HeaderRow/AvailableRecruitsHeaderLabel")
	buttons_header_label = get_node("Panel/Army/HeaderSection/HeaderRow/ButtonsHeaderLabel")
	regions_container = get_node("Panel/Army/RegionsSection/RegionsContainer")
	continue_button = get_node("Panel/Army/ButtonSection/HBoxContainer/Button")
	total_available_label = get_node("Panel/Army/AvailableSummary/HBoxContainer/AvailableValue")
	total_called_label = get_node("Panel/Army/TotalSection/HBoxContainer/TotalValue")
	region_row_template = regions_container.get_node_or_null("DefaultRegionRow") as HBoxContainer
	if region_row_template != null:
		regions_container.remove_child(region_row_template)
		region_row_template.visible = false
	if total_called_label != null:
		total_called_label.text = "0"

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
	total_available_label.text = "0"
	if total_called_label:
		total_called_label.text = "0"

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
	var map_generator: MapGenerator = game_manager.get_node("../Map")
	var regions_node = map_generator.get_node("Regions")
	
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
	call_to_arms_title_label.text = tr("Call to Arms")

	# Update headers
	regions_header_label.text = tr("Region")
	called_recruits_header_label.text = tr("Called")
	buttons_header_label.text = tr("Call")
	available_recruits_header_label.text = tr("Available")

	# Update regions display
	_update_regions_display()

func _update_regions_display() -> void:
	"""Update the regions list with call to arms controls"""
	# Clear existing displays (remove template row first for editor previews)
	for child in regions_container.get_children():
		child.queue_free()

	# Create rows for neighboring regions
	for region in neighboring_regions:
		_create_region_row(region)

	_update_total_called_label()
	_update_total_available_label()

func _create_region_row(region: Region) -> void:
	"""Create a single region row with: Region Name | Called Recruits | Buttons | Available Recruits"""
	if region_row_template == null:
		return
	var row_container := region_row_template.duplicate() as HBoxContainer
	row_container.visible = true
	row_container.name = "RegionRow_" + str(region.get_region_id())
	regions_container.add_child(row_container)

	var region_label := row_container.get_node("RegionLabel") as Label
	region_label.text = region.get_region_name()

	var region_id = region.get_region_id()
	var count_called = called_recruits.get(region_id, 0)

	var called_count_label := row_container.get_node("CalledCountLabel") as Label
	called_count_label.text = str(count_called)
	called_count_label.name = "CalledCount_" + str(region_id)

	var available_label := row_container.get_node("AvailableLabel") as Label
	available_label.text = str(_get_remaining_recruits(region))

	var increase_ten_button := row_container.get_node("IncreaseTenButton") as Button
	var increase_one_button := row_container.get_node("IncreaseOneButton") as Button
	var decrease_one_button := row_container.get_node("DecreaseOneButton") as Button
	var decrease_ten_button := row_container.get_node("DecreaseTenButton") as Button

	increase_ten_button.pressed.connect(_on_adjust_button_pressed.bind(region, 10))
	increase_one_button.pressed.connect(_on_adjust_button_pressed.bind(region, 1))
	decrease_one_button.pressed.connect(_on_adjust_button_pressed.bind(region, -1))
	decrease_ten_button.pressed.connect(_on_adjust_button_pressed.bind(region, -10))

	_update_region_row_buttons(row_container, region)

func _update_region_row_buttons(row_container: HBoxContainer, region: Region) -> void:
	var region_id := region.get_region_id()
	var remaining: int = _get_remaining_recruits(region)
	var count_called: int = called_recruits.get(region_id, 0)

	var increase_ten_button := row_container.get_node("IncreaseTenButton") as Button
	var increase_one_button := row_container.get_node("IncreaseOneButton") as Button
	var decrease_one_button := row_container.get_node("DecreaseOneButton") as Button
	var decrease_ten_button := row_container.get_node("DecreaseTenButton") as Button

	var can_increase: bool = remaining > 0
	increase_one_button.disabled = not can_increase
	increase_ten_button.disabled = not can_increase

	var can_decrease: bool = count_called > 0
	decrease_one_button.disabled = not can_decrease
	decrease_ten_button.disabled = not can_decrease

# Button handlers
func _on_adjust_button_pressed(region: Region, delta: int) -> void:
	"""Adjust called recruits for a region using transfer-style buttons"""
	var region_id = region.get_region_id()
	var available_recruits = region.get_available_recruits()
	var current_called = called_recruits.get(region_id, 0)
	var new_value = clamp(current_called + delta, 0, available_recruits)
	if new_value == current_called:
		return
	if new_value == 0 and called_recruits.has(region_id):
		called_recruits.erase(region_id)
	else:
		called_recruits[region_id] = new_value
	_update_regions_display()

func _update_total_available_label() -> void:
	var total_available := 0
	for region in neighboring_regions:
		total_available += _get_remaining_recruits(region)
	total_available_label.text = str(total_available)

func _update_total_called_label() -> void:
	total_called = 0
	for value in called_recruits.values():
		total_called += int(value)
	if total_called_label:
		total_called_label.text = str(total_called)

func _get_remaining_recruits(region: Region) -> int:
	var available_recruits = region.get_available_recruits()
	var region_id = region.get_region_id()
	var called = called_recruits.get(region_id, 0)
	return max(available_recruits - called, 0)

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
	_request_player_status_refresh()

func _apply_call_to_arms() -> void:
	"""Apply the call to arms - move recruits from neighboring regions to target region"""
	if target_region == null:
		return
	
	DebugLogger.log("UISystem", "Applying call to arms to " + target_region.get_region_name())
	
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
				
				# Add recruits to target region and bump population; allow exceeding current recruit cap
				target_region.add_call_to_arms_recruits(actual_moved)
				
				DebugLogger.log("UISystem", "Moved " + str(actual_moved) + " recruits from " + source_region.get_region_name() + " to " + target_region.get_region_name())
				DebugLogger.log("UISystem", target_region.get_region_name() + " now has " + str(target_region.get_available_recruits()) + "/" + str(target_region.get_max_recruits()) + " recruits")

func _request_player_status_refresh() -> void:
	GlobalSignals.emit_signal("player_status_refresh_requested")
