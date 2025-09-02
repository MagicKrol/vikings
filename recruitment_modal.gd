extends Control
class_name RecruitmentModal

# Styling constants (same as other modals)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

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

# Manager references
var sound_manager: SoundManager = null
var ui_manager: UIManager = null
var player_manager: PlayerManagerNode = null

func _ready():
	# Get references to static UI elements from scene
	recruitment_title_label = get_node("BorderMargin/MainContainer/TitleContainer/RecruitmentTitleLabel")
	army_header_label = get_node("BorderMargin/MainContainer/HeaderContainer/HeaderRow/ArmyHeaderLabel")
	recruit_header_label = get_node("BorderMargin/MainContainer/HeaderContainer/HeaderRow/RecruitHeaderLabel")
	cost_header_label = get_node("BorderMargin/MainContainer/HeaderContainer/HeaderRow/CostHeaderLabel")
	army_units_container = get_node("BorderMargin/MainContainer/MainContent/ArmyUnitsContainer")
	total_count_label = get_node("BorderMargin/MainContainer/TotalRow/TotalRowContainer/TotalCountLabel")
	total_recruit_label = get_node("BorderMargin/MainContainer/TotalRow/TotalRowContainer/TotalRecruitLabel")
	continue_button = get_node("BorderMargin/MainContainer/ButtonContainer/ContinueButton")
	
	# Connect button signal
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Get manager references
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	player_manager = get_node("../../PlayerManager") as PlayerManagerNode
	
	# Initially hidden
	visible = false

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
	
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _update_display() -> void:
	"""Update the display with current recruitment information"""
	if target_region == null:
		hide_modal()
		return
	
	# Update title with castle level info
	var castle_type = target_region.get_castle_type()
	var max_tier = GameParameters.get_castle_max_tier(castle_type)
	recruitment_title_label.text = "Recruitment in " + target_region.get_region_name()
	
	# Update header based on recruitment type
	if target_army != null:
		army_header_label.text = "Army " + target_army.number
	else:
		army_header_label.text = "Garrison"
	
	# Update recruitment rows (single column layout)
	_update_recruitment_display()
	
	# Update total row
	_update_total_row()

func _update_army_display() -> void:
	"""Update the army composition display (read-only)"""
	# Clear existing displays
	for child in army_units_container.get_children():
		child.queue_free()
	
	var army_comp = target_army.get_composition()
	# Show ALL unit types, even if count is 0
	for unit_type in SoldierTypeEnum.get_all_types():
		var count = army_comp.get_soldier_count(unit_type)
		_create_army_unit_row(unit_type, count)

func _create_army_unit_row(unit_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Create a unit row for army display: 'Unit: <count>'"""
	# Add margin before this row (except for the first row)
	if army_units_container.get_child_count() > 0:
		var margin = MarginContainer.new()
		margin.custom_minimum_size = Vector2(0, 5)
		army_units_container.add_child(margin)
	
	var row_container = HBoxContainer.new()
	row_container.add_theme_constant_override("separation", 0)
	army_units_container.add_child(row_container)
	
	# Unit name (left-aligned)
	var unit_label = Label.new()
	unit_label.text = SoldierTypeEnum.type_to_string(unit_type) + ":"
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	unit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_standard_theme(unit_label)
	row_container.add_child(unit_label)
	
	# Count (right-aligned, fixed width)
	var count_label = Label.new()
	count_label.text = str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.custom_minimum_size = Vector2(60, 0)
	_apply_standard_theme(count_label)
	row_container.add_child(count_label)

func _update_recruitment_display() -> void:
	"""Update recruitment controls and cost display"""
	# Clear existing displays
	for child in army_units_container.get_children():
		child.queue_free()
	
	# Get castle type for availability checking
	if target_region == null:
		return
	
	var castle_type = target_region.get_castle_type()
	
	# Create recruitment rows for all unit types, but mark unavailable ones as disabled
	for unit_type in SoldierTypeEnum.get_all_types():
		var is_available = GameParameters.can_recruit_unit_with_castle(unit_type, castle_type)
		_create_recruitment_row(unit_type, is_available)

func _create_recruitment_row(unit_type: SoldierTypeEnum.Type, is_available: bool = true) -> void:
	"""Create a single recruitment row with: Unit Name | Unit Count | Buttons | Cost"""
	# Add margin before this row (except for the first row)
	if army_units_container.get_child_count() > 0:
		var margin = MarginContainer.new()
		margin.custom_minimum_size = Vector2(0, 5)
		army_units_container.add_child(margin)
	
	# Main row container
	var row_container = HBoxContainer.new()
	row_container.add_theme_constant_override("separation", 0)
	army_units_container.add_child(row_container)
	
	# Unit name (left-aligned, 200px width)
	var unit_label = Label.new()
	unit_label.text = SoldierTypeEnum.type_to_string(unit_type) + ":"
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	unit_label.custom_minimum_size = Vector2(200, 0)
	unit_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_standard_theme(unit_label)
	if not is_available:
		# Gray out unavailable units
		unit_label.add_theme_color_override("font_color", Color.GRAY)
	row_container.add_child(unit_label)
	
	# Current count (right-aligned, 80px width) - from garrison or army
	var current_count: int
	if target_army != null:
		var army_comp = target_army.get_composition()
		current_count = army_comp.get_soldier_count(unit_type)
	else:
		# Show garrison composition
		current_count = target_region.garrison.get_soldier_count(unit_type)
	
	var count_label = Label.new()
	count_label.text = str(current_count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.custom_minimum_size = Vector2(80, 0)
	count_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_standard_theme(count_label)
	if not is_available:
		# Gray out unavailable units
		count_label.add_theme_color_override("font_color", Color.GRAY)
	row_container.add_child(count_label)
	
	# Margin 50px
	var margin1 = Control.new()
	margin1.custom_minimum_size = Vector2(50, 0)
	row_container.add_child(margin1)
	
	# Hiring count (center-aligned, 80px width)
	var recruit_count_label = Label.new()
	var count_to_hire = recruitment_counts.get(unit_type, 0) if is_available else 0
	recruit_count_label.text = str(count_to_hire)
	recruit_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recruit_count_label.custom_minimum_size = Vector2(80, 0)
	recruit_count_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	recruit_count_label.name = "RecruitCount_" + str(unit_type)
	_apply_standard_theme(recruit_count_label)
	if not is_available:
		# Gray out unavailable units
		recruit_count_label.add_theme_color_override("font_color", Color.GRAY)
	row_container.add_child(recruit_count_label)
	
	# Margin 20px
	if is_available:
		var margin2 = Control.new()
		margin2.custom_minimum_size = Vector2(20, 0)
		row_container.add_child(margin2)
	
	# Recruitment buttons: |< < > >| (only for available units)
	if is_available:
		var hire_max_button = Button.new()
		hire_max_button.text = "|<"
		hire_max_button.custom_minimum_size = Vector2(30, 25)
		hire_max_button.pressed.connect(_on_hire_max_pressed.bind(unit_type))
		row_container.add_child(hire_max_button)
		
		var hire_one_button = Button.new()
		hire_one_button.text = "<"
		hire_one_button.custom_minimum_size = Vector2(25, 25)
		hire_one_button.pressed.connect(_on_hire_one_pressed.bind(unit_type))
		row_container.add_child(hire_one_button)
		
		var unhire_one_button = Button.new()
		unhire_one_button.text = ">"
		unhire_one_button.custom_minimum_size = Vector2(25, 25)
		unhire_one_button.pressed.connect(_on_unhire_one_pressed.bind(unit_type))
		row_container.add_child(unhire_one_button)
		
		var unhire_all_button = Button.new()
		unhire_all_button.text = ">|"
		unhire_all_button.custom_minimum_size = Vector2(30, 25)
		unhire_all_button.pressed.connect(_on_unhire_all_pressed.bind(unit_type))
		row_container.add_child(unhire_all_button)
	
	# Margin 20px
	var margin3 = Control.new()
	margin3.custom_minimum_size = Vector2(20, 0)
	row_container.add_child(margin3)
	
	# Unit costs in single line: Gold first, then Wood or Iron (200px width)
	var unit_costs = _get_unit_costs(unit_type)
	var cost_parts: Array[String] = []
	
	# Always show Gold first if it exists
	if unit_costs.has(ResourcesEnum.Type.GOLD):
		cost_parts.append("G: " + str(unit_costs[ResourcesEnum.Type.GOLD]))
	
	# Then Wood or Iron
	if unit_costs.has(ResourcesEnum.Type.WOOD):
		cost_parts.append("W: " + str(unit_costs[ResourcesEnum.Type.WOOD]))
	if unit_costs.has(ResourcesEnum.Type.IRON):
		cost_parts.append("I: " + str(unit_costs[ResourcesEnum.Type.IRON]))
	
	# Cost label (left-aligned, 200px width)
	var cost_label = Label.new()
	if is_available:
		cost_label.text = " | ".join(cost_parts) if not cost_parts.is_empty() else "Free"
	else:
		# Show "Unavailable" for units that can't be recruited
		var unit_tier = GameParameters.get_unit_tier(unit_type)
		var required_castle = ""
		match unit_tier:
			1:
				required_castle = "No castle required"
			2:
				required_castle = "Requires Outpost"
			3:
				required_castle = "Requires Keep"
			4:
				required_castle = "Requires Castle"
			5:
				required_castle = "Requires Stronghold"
			_:
				required_castle = "Requires Castle Tier " + str(unit_tier)
		cost_label.text = required_castle
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cost_label.custom_minimum_size = Vector2(200, 0)
	cost_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_standard_theme(cost_label)
	if not is_available:
		# Gray out unavailable units
		cost_label.add_theme_color_override("font_color", Color.GRAY)
	row_container.add_child(cost_label)

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
	total_recruit_label.text = str(total_to_hire) + " / " + str(available_recruits)

# Button handlers
func _on_hire_max_pressed(unit_type: SoldierTypeEnum.Type) -> void:
	"""Hire maximum possible units of this type"""
	var available_recruits = target_region.get_available_recruits()
	var current_total_hired = 0
	for count in recruitment_counts.values():
		current_total_hired += count
	
	var remaining_recruits = available_recruits - current_total_hired
	var unit_costs = _get_unit_costs(unit_type)
	var max_affordable = _calculate_max_affordable(unit_costs)
	var max_to_hire = min(remaining_recruits, max_affordable)
	
	if max_to_hire > 0:
		# Deduct resources for the units we're hiring
		_deduct_unit_cost(unit_type, max_to_hire)
		recruitment_counts[unit_type] = recruitment_counts.get(unit_type, 0) + max_to_hire
		_update_costs()
		_update_recruitment_display()
		_update_total_row()

func _on_hire_one_pressed(unit_type: SoldierTypeEnum.Type) -> void:
	"""Hire one unit of this type"""
	var available_recruits = target_region.get_available_recruits()
	var current_total_hired = 0
	for count in recruitment_counts.values():
		current_total_hired += count
	
	if current_total_hired < available_recruits:
		var unit_costs = _get_unit_costs(unit_type)
		if _can_afford_cost(unit_costs):
			# Deduct resources for this unit
			_deduct_unit_cost(unit_type, 1)
			recruitment_counts[unit_type] = recruitment_counts.get(unit_type, 0) + 1
			_update_costs()
			_update_recruitment_display()
			_update_total_row()

func _on_unhire_one_pressed(unit_type: SoldierTypeEnum.Type) -> void:
	"""Unhire one unit of this type"""
	var current_count = recruitment_counts.get(unit_type, 0)
	if current_count > 0:
		# Refund resources for this unit
		_refund_unit_cost(unit_type, 1)
		recruitment_counts[unit_type] = current_count - 1
		if recruitment_counts[unit_type] == 0:
			recruitment_counts.erase(unit_type)
		_update_costs()
		_update_recruitment_display()
		_update_total_row()

func _on_unhire_all_pressed(unit_type: SoldierTypeEnum.Type) -> void:
	"""Unhire all units of this type"""
	if recruitment_counts.has(unit_type):
		var count_to_refund = recruitment_counts[unit_type]
		# Refund resources for all units of this type
		_refund_unit_cost(unit_type, count_to_refund)
		recruitment_counts.erase(unit_type)
		_update_costs()
		_update_recruitment_display()
		_update_total_row()

func _calculate_max_affordable(unit_costs: Dictionary) -> int:
	"""Calculate maximum affordable units based on available resources"""
	if unit_costs.is_empty():
		# If no costs (like peasants), return a very high number
		return 999999
	
	var max_affordable = 999999
	for resource_type in unit_costs:
		var cost_per_unit = unit_costs[resource_type]
		if cost_per_unit > 0:
			# Current available resources (not including what we've already "spent")
			var available_resources = player_manager.get_resource_amount(resource_type)
			var affordable_count = available_resources / cost_per_unit
			max_affordable = min(max_affordable, affordable_count)
	
	return max_affordable

func _can_afford_cost(unit_costs: Dictionary) -> bool:
	"""Check if player can afford the cost of one unit"""
	for resource_type in unit_costs:
		var cost = unit_costs[resource_type]
		if cost > 0:
			var available = player_manager.get_resource_amount(resource_type)
			if available < cost:
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

func _draw():
	# Draw shadow first (behind everything)
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)
	
	# Draw background fill
	var bg_rect = Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, FRAME_COLOR)
	
	# Draw black border on top
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)
