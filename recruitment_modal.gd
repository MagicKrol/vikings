extends Control
class_name RecruitmentModal

# UI elements - references to static nodes from scene
var recruitment_title_label: Label
var army_header_label: Label
var recruit_header_label: Label
var cost_header_label: Label
var army_units_container: VBoxContainer
var total_count_label: Label
var total_recruit_label: Label
var available_recruits_label: Label
var continue_button: Button

# Recruitment data
var target_army: Army = null
var target_region: Region = null
var recruitment_counts: Dictionary = {} # unit_type -> count to hire
var total_cost: Dictionary = {} # resource_type -> total cost

# Additional manager reference
var player_manager: PlayerManagerNode = null

# Common references
var sound_manager: SoundManager = null
var ui_manager: UIManager = null
var info_modal: InfoModal = null
var select_tooltip_modal: SelectTooltipModal = null

func _setup_references():
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	info_modal = get_node("../InfoModal") as InfoModal
	select_tooltip_modal = get_node("../SelectTooltipModal") as SelectTooltipModal

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
	available_recruits_label = get_node("Panel/Army/AvailableRecruits/HBoxContainer/Value")
	continue_button = get_node("Panel/Army/ButtonSection/HBoxContainer/Button")
	
	# Connect button signal
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Connect unit adjustment buttons
	_connect_button_signals()
	
	# Get additional manager reference
	player_manager = get_node("../../PlayerManager") as PlayerManagerNode

func _connect_button_signals() -> void:
	var sections = [
		{"path": "Panel/Army/UnitsSection/Peasants", "type": SoldierTypeEnum.Type.PEASANTS},
		{"path": "Panel/Army/UnitsSection/Spearmen", "type": SoldierTypeEnum.Type.SPEARMEN},
		{"path": "Panel/Army/UnitsSection/Archers", "type": SoldierTypeEnum.Type.ARCHERS},
		{"path": "Panel/Army/UnitsSection/Swordmen", "type": SoldierTypeEnum.Type.SWORDSMEN},
		{"path": "Panel/Army/UnitsSection/Crossbowmen", "type": SoldierTypeEnum.Type.CROSSBOWMEN},
		{"path": "Panel/Army/UnitsSection/Horsemen", "type": SoldierTypeEnum.Type.HORSEMEN},
		{"path": "Panel/Army/UnitsSection/Knights", "type": SoldierTypeEnum.Type.KNIGHTS},
		{"path": "Panel/Army/UnitsSection/Mounted Knights", "type": SoldierTypeEnum.Type.MOUNTED_KNIGHTS},
		{"path": "Panel/Army/UnitsSection/Royal Guard", "type": SoldierTypeEnum.Type.ROYAL_GUARD}
	]

	for section_data in sections:
		var section = get_node(section_data.path)
		(section.get_node("Button10") as Button).pressed.connect(_on_unit_button_pressed.bind(section_data.type, 10))
		(section.get_node("Button1") as Button).pressed.connect(_on_unit_button_pressed.bind(section_data.type, 1))
		(section.get_node("Button1m") as Button).pressed.connect(_on_unit_button_pressed.bind(section_data.type, -1))
		(section.get_node("Button10m") as Button).pressed.connect(_on_unit_button_pressed.bind(section_data.type, -10))

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
	
	if info_modal != null and info_modal.visible:
		info_modal.hide_modal(false)
	
	visible = false
	
	if ui_manager:
		ui_manager.set_modal_active(false)

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
	
	var button_increase_large = section.get_node("Button10") as Button
	var button_increase_small = section.get_node("Button1") as Button
	var button_decrease_small = section.get_node("Button1m") as Button
	var button_decrease_large = section.get_node("Button10m") as Button

	if not is_available:
		button_increase_large.disabled = true
		button_increase_small.disabled = true
		button_decrease_small.disabled = true
		button_decrease_large.disabled = true
		button_increase_large.focus_mode = Control.FOCUS_NONE
		button_increase_small.focus_mode = Control.FOCUS_NONE
		button_decrease_small.focus_mode = Control.FOCUS_NONE
		button_decrease_large.focus_mode = Control.FOCUS_NONE
		return

	var can_hire_one = _can_hire_amount(unit_type, 1)
	button_increase_small.disabled = not can_hire_one
	button_increase_large.disabled = not can_hire_one
	button_decrease_small.disabled = count_to_hire <= 0
	button_decrease_large.disabled = count_to_hire <= 0

	button_increase_small.focus_mode = Control.FOCUS_ALL
	button_increase_large.focus_mode = Control.FOCUS_ALL
	button_decrease_small.focus_mode = Control.FOCUS_ALL
	button_decrease_large.focus_mode = Control.FOCUS_ALL

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
	var remaining_recruits = max(0, available_recruits - total_to_hire)

	# Update labels
	total_count_label.text = str(total_units)
	total_recruit_label.text = str(total_to_hire)

	if available_recruits_label:
		available_recruits_label.text = str(remaining_recruits)

func _on_unit_button_pressed(unit_type: SoldierTypeEnum.Type, amount: int) -> void:
	_adjust_recruitment(unit_type, amount)

func _adjust_recruitment(unit_type: SoldierTypeEnum.Type, delta: int) -> void:
	if target_region == null or delta == 0 or player_manager == null:
		return

	var castle_type = target_region.get_castle_type()
	if not GameParameters.can_recruit_unit_with_castle(unit_type, castle_type):
		return

	var current_count = recruitment_counts.get(unit_type, 0)
	if delta > 0:
		var free_recruits = target_region.get_available_recruits() - _get_total_hired()
		if free_recruits <= 0:
			return
		var desired = min(delta, free_recruits)
		var unit_costs = _get_unit_costs(unit_type)
		var affordable = _max_affordable_units(unit_costs, desired)
		if affordable <= 0:
			return
		_deduct_unit_cost(unit_type, affordable)
		recruitment_counts[unit_type] = current_count + affordable
	elif delta < 0:
		if current_count <= 0:
			return
		var remove_amount = min(current_count, -delta)
		if remove_amount <= 0:
			return
		_refund_unit_cost(unit_type, remove_amount)
		var new_count = current_count - remove_amount
		if new_count > 0:
			recruitment_counts[unit_type] = new_count
		else:
			recruitment_counts.erase(unit_type)

	_update_costs()
	_update_recruitment_display()
	_update_total_row()

func _max_affordable_units(unit_costs: Dictionary, desired: int) -> int:
	var result = desired
	for resource_type in unit_costs:
		var cost_per_unit = unit_costs[resource_type]
		if cost_per_unit <= 0:
			continue
		var available = player_manager.get_resource_amount(resource_type)
		var possible = int(available / cost_per_unit)
		if possible < result:
			result = possible
	if result < 0:
		return 0
	return result

func _get_total_hired() -> int:
	var total = 0
	for count in recruitment_counts.values():
		total += count
	return total

func _can_hire_amount(unit_type: SoldierTypeEnum.Type, amount: int) -> bool:
	if amount <= 0 or target_region == null or player_manager == null:
		return false
	var castle_type = target_region.get_castle_type()
	if not GameParameters.can_recruit_unit_with_castle(unit_type, castle_type):
		return false
	var free_recruits = target_region.get_available_recruits() - _get_total_hired()
	if free_recruits < amount:
		return false
	var unit_costs = _get_unit_costs(unit_type)
	return _can_afford_cost_multiple(unit_costs, amount)

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
