extends ActionModalBase
class_name RecruitmentModal

# UI elements - references to static nodes from scene
var recruitment_title_label: Label
var army_header_label: Label
var recruit_header_label: Label
var cost_header_label: Label
var army_units_container: VBoxContainer
var total_count_label: Label
var total_recruit_label: Label
var continue_button: Button

# Recruitment data
var target_army: Army = null
var target_region: Region = null
var recruitment_counts: Dictionary = {} # unit_type -> count to hire
var total_cost: Dictionary = {} # resource_type -> total cost

# Additional manager reference
var player_manager: PlayerManagerNode = null

# Flag to prevent recursive slider updates
var is_updating_sliders: bool = false

func _ready():
	# Setup base references but skip button_container setup
	_setup_references()
	visible = false
	
	# Get references to static UI elements from scene
	recruitment_title_label = get_node("Panel/Army/Header/RecruitmentRegion")
	army_header_label = get_node("Panel/Army/HeaderSection/HBoxContainer/ArmyName")
	recruit_header_label = get_node("Panel/Army/HeaderSection/HBoxContainer/RecruitmentLabel")
	cost_header_label = get_node("Panel/Army/HeaderSection/HBoxContainer/CostLabel")
	army_units_container = get_node("Panel/Army/UnitsSection")
	total_count_label = get_node("Panel/Army/TotalSection/HBoxContainer/TotalValue")
	total_recruit_label = get_node("Panel/Army/TotalSection/HBoxContainer/TotalHiredValue")
	continue_button = get_node("Panel/Army/ButtonSection/HBoxContainer/Button")
	
	# Connect button signal
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Connect slider signals for all unit types
	_connect_slider_signals()
	
	# Get additional manager reference
	player_manager = get_node("../../PlayerManager") as PlayerManagerNode

func _connect_slider_signals():
	"""Connect all slider value_changed signals to handlers"""
	var sliders = [
		{"path": "Panel/Army/UnitsSection/Peasants/Buttons", "type": SoldierTypeEnum.Type.PEASANTS},
		{"path": "Panel/Army/UnitsSection/Spearmen/Buttons", "type": SoldierTypeEnum.Type.SPEARMEN},
		{"path": "Panel/Army/UnitsSection/Archers/Buttons", "type": SoldierTypeEnum.Type.ARCHERS},
		{"path": "Panel/Army/UnitsSection/Swordmen/Buttons", "type": SoldierTypeEnum.Type.SWORDSMEN},
		{"path": "Panel/Army/UnitsSection/Crossbowmen/Buttons", "type": SoldierTypeEnum.Type.CROSSBOWMEN},
		{"path": "Panel/Army/UnitsSection/Horsemen/Buttons", "type": SoldierTypeEnum.Type.HORSEMEN},
		{"path": "Panel/Army/UnitsSection/Knights/Buttons", "type": SoldierTypeEnum.Type.KNIGHTS},
		{"path": "Panel/Army/UnitsSection/Mounted Knights/Buttons", "type": SoldierTypeEnum.Type.MOUNTED_KNIGHTS},
		{"path": "Panel/Army/UnitsSection/Royal Guard/Buttons", "type": SoldierTypeEnum.Type.ROYAL_GUARD}
	]
	
	for slider_data in sliders:
		var slider = get_node(slider_data.path) as HSlider
		slider.value_changed.connect(_on_slider_changed.bind(slider_data.type))

func show_recruitment(army: Army, region: Region) -> void:
	"""Show the recruitment modal with army and region information"""
	if army == null or region == null:
		hide_modal()
		return
	
	target_army = army
	target_region = region
	
	# Reset recruitment state
	recruitment_counts.clear()
	total_cost.clear()
	
	# Update display
	_update_display()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)

func show_region_recruitment(region: Region) -> void:
	"""Show the recruitment modal for region garrison recruitment"""
	if region == null:
		hide_modal()
		return
	
	target_army = null  # No specific army, recruiting to garrison
	target_region = region
	
	# Reset recruitment state
	recruitment_counts.clear()
	total_cost.clear()
	
	# Update display
	_update_display()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)

func hide_modal() -> void:
	"""Hide the recruitment modal"""
	# If we have pending recruitment that wasn't finalized, refund the resources
	if not recruitment_counts.is_empty():
		for unit_type in recruitment_counts:
			var count = recruitment_counts[unit_type]
			_refund_unit_cost(unit_type, count)
	
	# Reset state
	target_army = null
	target_region = null
	recruitment_counts.clear()
	total_cost.clear()
	
	super.hide_modal()

func _update_display() -> void:
	"""Update the display with current recruitment information"""
	if target_region == null:
		hide_modal()
		return
	
	# Update title with castle level info
	var castle_type = target_region.get_castle_type()
	recruitment_title_label.text = "Recruitment in " + target_region.get_region_name()
	
	# Update header based on recruitment type
	if target_army != null:
		army_header_label.text = "Army " + str(target_army.number)
	else:
		army_header_label.text = "Garrison"
	
	# Update recruitment rows using static elements
	_update_recruitment_display()
	
	# Update total row
	_update_total_row()

func _update_recruitment_display() -> void:
	"""Update recruitment controls and cost display using static scene elements"""
	if target_region == null:
		return
	
	var castle_type = target_region.get_castle_type()
	
	# Update existing unit sections (Peasants, Spearmen, Archers, etc.)
	_update_unit_section("Peasants", SoldierTypeEnum.Type.PEASANTS, castle_type)
	_update_unit_section("Spearmen", SoldierTypeEnum.Type.SPEARMEN, castle_type)
	_update_unit_section("Archers", SoldierTypeEnum.Type.ARCHERS, castle_type)
	_update_unit_section("Swordmen", SoldierTypeEnum.Type.SWORDSMEN, castle_type)
	_update_unit_section("Crossbowmen", SoldierTypeEnum.Type.CROSSBOWMEN, castle_type)
	_update_unit_section("Horsemen", SoldierTypeEnum.Type.HORSEMEN, castle_type)
	_update_unit_section("Knights", SoldierTypeEnum.Type.KNIGHTS, castle_type)
	_update_unit_section("Mounted Knights", SoldierTypeEnum.Type.MOUNTED_KNIGHTS, castle_type)
	_update_unit_section("Royal Guard", SoldierTypeEnum.Type.ROYAL_GUARD, castle_type)

func _update_unit_section(section_name: String, unit_type: SoldierTypeEnum.Type, castle_type: CastleTypeEnum.Type) -> void:
	"""Update a static unit section with current values"""
	var is_available = GameParameters.can_recruit_unit_with_castle(unit_type, castle_type)
	var section = get_node("Panel/Army/UnitsSection/" + section_name)
	
	# Update current count
	var current_count: int
	if target_army != null:
		var army_comp = target_army.get_composition()
		current_count = army_comp.get_soldier_count(unit_type)
	else:
		current_count = target_region.garrison.get_soldier_count(unit_type)
	
	var value_label = section.get_node("Value")
	value_label.text = str(current_count)
	
	# Update hired count
	var hired_label = section.get_node("HiredRecruits")
	var count_to_hire = recruitment_counts.get(unit_type, 0) if is_available else 0
	hired_label.text = str(count_to_hire)
	
	# Update cost
	var cost_label = section.get_node("Cost")
	if is_available:
		var unit_costs = _get_unit_costs(unit_type)
		var cost_parts: Array[String] = []
		if unit_costs.has(ResourcesEnum.Type.GOLD):
			cost_parts.append("Gold: " + str(unit_costs[ResourcesEnum.Type.GOLD]))
		if unit_costs.has(ResourcesEnum.Type.WOOD):
			cost_parts.append("Wood: " + str(unit_costs[ResourcesEnum.Type.WOOD]))
		if unit_costs.has(ResourcesEnum.Type.IRON):
			cost_parts.append("Iron: " + str(unit_costs[ResourcesEnum.Type.IRON]))
		cost_label.text = " | ".join(cost_parts) if not cost_parts.is_empty() else "Free"
	else:
		var unit_tier = GameParameters.get_unit_tier(unit_type)
		var required_castle = ""
		match unit_tier:
			1: required_castle = "No castle required"
			2: required_castle = "Requires Outpost"
			3: required_castle = "Requires Keep"
			4: required_castle = "Requires Castle"
			5: required_castle = "Requires Stronghold"
			_: required_castle = "Requires Castle Tier " + str(unit_tier)
		cost_label.text = required_castle
	
	# Handle slider setup
	var slider = section.get_node("Buttons") as HSlider
	slider.editable = is_available
	
	if is_available:
		# Calculate available recruits for this unit type
		var total_available = target_region.get_available_recruits()
		var hired_by_others = _get_total_hired_excluding(unit_type)
		var max_for_this_unit = total_available - hired_by_others
		
		# Store old max to check if it changed
		var old_max = slider.max_value
		
		# Always update min/max values
		slider.min_value = 0
		slider.max_value = max(0, max_for_this_unit)
		
		# Update slider value
		if not is_updating_sliders:
			# Normal update: position based on hired count
			slider.value = slider.max_value - count_to_hire
		elif old_max != slider.max_value and count_to_hire == 0:
			# Max changed but this unit type has 0 hired, keep at max position
			slider.value = slider.max_value
	else:
		slider.value = 0
		slider.max_value = 0

func _update_total_row() -> void:
	"""Update the total row with army/garrison totals and recruitment totals"""
	# Calculate total units (army or garrison) - count all units, not just available for recruitment
	var total_units = 0
	if target_army != null:
		var army_comp = target_army.get_composition()
		for unit_type in SoldierTypeEnum.get_all_types():
			total_units += army_comp.get_soldier_count(unit_type)
	else:
		# Calculate garrison totals
		for unit_type in SoldierTypeEnum.get_all_types():
			total_units += target_region.garrison.get_soldier_count(unit_type)
	
	# Calculate total recruitment
	var total_to_hire = 0
	for count in recruitment_counts.values():
		total_to_hire += count
	
	var available_recruits = target_region.get_available_recruits()
	
	# Update labels
	total_count_label.text = str(total_units)
	total_recruit_label.text = str(total_to_hire)
	
	# Update the "TotalAvailable" label to show available recruits
	var total_available_label = get_node("Panel/Army/TotalSection/HBoxContainer/TotalAvailable")
	total_available_label.text = "/ " + str(available_recruits) + " Available"

func _on_slider_changed(value: float, unit_type: SoldierTypeEnum.Type) -> void:
	"""Handle slider value changes for recruitment"""
	if is_updating_sliders:
		return  # Prevent recursive updates
	
	var slider = _get_slider_for_unit_type(unit_type)
	var new_count = int(slider.max_value - value)  # hired = max - slider_value
	var old_count = recruitment_counts.get(unit_type, 0)
	var count_diff = new_count - old_count
	
	# Validate against total available recruits
	var total_available = target_region.get_available_recruits()
	var total_hired = _get_total_hired_excluding(unit_type) + new_count
	if total_hired > total_available:
		# Trying to hire more than available, adjust to max possible
		new_count = total_available - _get_total_hired_excluding(unit_type)
		count_diff = new_count - old_count
		is_updating_sliders = true
		slider.value = slider.max_value - new_count
		is_updating_sliders = false
	
	if count_diff > 0:
		# Hiring more units (slider moved down)
		var unit_costs = _get_unit_costs(unit_type)
		if _can_afford_cost_multiple(unit_costs, count_diff):
			_deduct_unit_cost(unit_type, count_diff)
			if new_count > 0:
				recruitment_counts[unit_type] = new_count
			else:
				recruitment_counts.erase(unit_type)
		else:
			# Can't afford, reset slider
			is_updating_sliders = true
			slider.value = slider.max_value - old_count
			is_updating_sliders = false
			return
	elif count_diff < 0:
		# Unhiring units (slider moved up)
		_refund_unit_cost(unit_type, -count_diff)
		if new_count > 0:
			recruitment_counts[unit_type] = new_count
		else:
			recruitment_counts.erase(unit_type)
	
	_update_costs()
	is_updating_sliders = true
	_update_recruitment_display()
	is_updating_sliders = false
	_update_total_row()

func _get_total_hired_excluding(exclude_type: SoldierTypeEnum.Type) -> int:
	"""Calculate total hired recruits excluding a specific unit type"""
	var total = 0
	for unit_type in recruitment_counts:
		if unit_type != exclude_type:
			total += recruitment_counts[unit_type]
	return total

func _get_slider_for_unit_type(unit_type: SoldierTypeEnum.Type) -> HSlider:
	"""Get the slider for a specific unit type"""
	match unit_type:
		SoldierTypeEnum.Type.PEASANTS:
			return get_node("Panel/Army/UnitsSection/Peasants/Buttons")
		SoldierTypeEnum.Type.SPEARMEN:
			return get_node("Panel/Army/UnitsSection/Spearmen/Buttons")
		SoldierTypeEnum.Type.ARCHERS:
			return get_node("Panel/Army/UnitsSection/Archers/Buttons")
		SoldierTypeEnum.Type.SWORDSMEN:
			return get_node("Panel/Army/UnitsSection/Swordmen/Buttons")
		SoldierTypeEnum.Type.CROSSBOWMEN:
			return get_node("Panel/Army/UnitsSection/Crossbowmen/Buttons")
		SoldierTypeEnum.Type.HORSEMEN:
			return get_node("Panel/Army/UnitsSection/Horsemen/Buttons")
		SoldierTypeEnum.Type.KNIGHTS:
			return get_node("Panel/Army/UnitsSection/Knights/Buttons")
		SoldierTypeEnum.Type.MOUNTED_KNIGHTS:
			return get_node("Panel/Army/UnitsSection/Mounted Knights/Buttons")
		SoldierTypeEnum.Type.ROYAL_GUARD:
			return get_node("Panel/Army/UnitsSection/Royal Guard/Buttons")
		_:
			return null

func _get_unit_costs(unit_type: SoldierTypeEnum.Type) -> Dictionary:
	"""Get the resource costs for a unit type from GameParameters"""
	var costs = {}
	
	# Get costs from GameParameters
	var gold_cost = GameParameters.get_unit_gold_cost(unit_type)
	var wood_cost = GameParameters.get_unit_wood_cost(unit_type)
	var iron_cost = GameParameters.get_unit_iron_cost(unit_type)
	
	# Only include costs that are greater than 0
	if gold_cost > 0:
		costs[ResourcesEnum.Type.GOLD] = gold_cost
	if wood_cost > 0:
		costs[ResourcesEnum.Type.WOOD] = wood_cost
	if iron_cost > 0:
		costs[ResourcesEnum.Type.IRON] = iron_cost
	
	return costs

func _can_afford_cost(unit_costs: Dictionary) -> bool:
	"""Check if player can afford the cost of one unit"""
	for resource_type in unit_costs:
		var cost = unit_costs[resource_type]
		if cost > 0:
			var available = player_manager.get_resource_amount(resource_type)
			if available < cost:
				return false
	return true

func _can_afford_cost_multiple(unit_costs: Dictionary, count: int) -> bool:
	"""Check if player can afford the cost of multiple units"""
	for resource_type in unit_costs:
		var total_cost = unit_costs[resource_type] * count
		if total_cost > 0:
			var available = player_manager.get_resource_amount(resource_type)
			if available < total_cost:
				return false
	return true

func _update_costs() -> void:
	"""Update total cost based on recruitment counts"""
	total_cost.clear()
	
	for unit_type in recruitment_counts:
		var count = recruitment_counts[unit_type]
		var unit_costs = _get_unit_costs(unit_type)
		
		for resource_type in unit_costs:
			var cost = unit_costs[resource_type] * count
			total_cost[resource_type] = total_cost.get(resource_type, 0) + cost
	
	# Update player status modal to show resource changes
	_update_player_status_modal()

func _on_continue_pressed() -> void:
	"""Handle Continue button press"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Apply recruitment if any units were selected
	if not recruitment_counts.is_empty():
		_apply_recruitment()
		# Spend 1 movement point from army for recruitment operation (only if recruiting to specific army)
		if target_army != null:
			target_army.spend_movement_points(1)
			DebugLogger.log("UISystem", "Army " + str(target_army.number) + " spent 1 movement point for recruitment (remaining: " + str(target_army.get_movement_points()) + ")")
	
	# Update player status modal after recruitment
	_update_player_status_modal()
	
	# Clear recruitment state without refunding (since we finalized the purchase)
	target_army = null
	target_region = null
	recruitment_counts.clear()
	total_cost.clear()
	
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _apply_recruitment() -> void:
	"""Apply the recruitment to the army/garrison and region"""
	# Add soldiers to army or garrison
	for unit_type in recruitment_counts:
		var count = recruitment_counts[unit_type]
		if target_army != null:
			# Recruiting to specific army
			target_army.add_soldiers(unit_type, count)
		else:
			# Recruiting to region garrison
			target_region.garrison.add_soldiers(unit_type, count)
	
	# Remove recruits from region
	var total_recruited = 0
	for count in recruitment_counts.values():
		total_recruited += count
	
	target_region.hire_recruits(total_recruited)
	
	# Resources have already been deducted in real-time, no need to deduct again

func _deduct_unit_cost(unit_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Immediately deduct resources for hiring units"""
	var unit_costs = _get_unit_costs(unit_type)
	for resource_type in unit_costs:
		var cost = unit_costs[resource_type] * count
		if cost > 0:
			player_manager.spend_resource(resource_type, cost)
	
	# Update player status modal to show the change
	_update_player_status_modal()

func _refund_unit_cost(unit_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Immediately refund resources for unhiring units"""
	var unit_costs = _get_unit_costs(unit_type)
	for resource_type in unit_costs:
		var refund = unit_costs[resource_type] * count
		if refund > 0:
			player_manager.add_resources_to_player(player_manager.current_player_id, resource_type, refund)
	
	# Update player status modal to show the change
	_update_player_status_modal()

func _update_player_status_modal() -> void:
	"""Update the player status modal to reflect current resource costs"""
	# Get the player status modal
	var player_status_modal2 = get_node("../PlayerStatusModal2") as PlayerStatusModal2
	if player_status_modal2 and player_status_modal2.visible:
		player_status_modal2.refresh_from_game_state()

func _apply_standard_theme(label: Label) -> void:
	"""Apply standard theme to a label"""
	label.theme = preload("res://themes/standard_text_theme.tres")
	label.add_theme_color_override("font_color", Color.WHITE)
