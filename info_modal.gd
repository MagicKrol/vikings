extends Control
class_name InfoModal

# UI manager reference for modal mode
var ui_manager: UIManager = null
# Sound manager reference
var sound_manager: SoundManager = null

# Current display mode
enum DisplayMode { NONE, ARMY, REGION }
var current_mode: DisplayMode = DisplayMode.NONE

# Current data references
var current_army: Army = null
var current_region: Region = null

func _ready():
	# Get references
	ui_manager = get_node("../UIManager") as UIManager
	sound_manager = get_node("../../SoundManager") as SoundManager
	
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
	visible = false
	
	# Always set modal mode inactive when fully closing
	if ui_manager:
		ui_manager.set_modal_active(false)

func _update_army_display() -> void:
	"""Update the display with current army information"""
	if current_army == null:
		hide_modal()
		return
	
	# Show Army node, hide Region node
	var army_node = get_node("Panel/Army")
	var region_node = get_node("Panel/Region")
	army_node.visible = true
	region_node.visible = false
	
	# Update army header
	var army_name_label = get_node("Panel/Army/HeaderSection/ArmyName")
	army_name_label.text = "Army " + str(current_army.number)
	
	# Update movement points
	var mp_value = get_node("Panel/Army/PopulationSection/MP/Value")
	var max_mp = GameParameters.MOVEMENT_POINTS_PER_TURN
	mp_value.text = str(current_army.get_movement_points()) + " / " + str(max_mp)
	
	# Update vigor
	var vigor_value = get_node("Panel/Army/PopulationSection/Vigor/Value")
	vigor_value.text = str(current_army.get_efficiency()) + "%"
	
	# Update total men count
	var men_value = get_node("Panel/Army/PopulationSection/Men/Value")
	men_value.text = str(current_army.get_total_soldiers())
	
	# Update unit composition
	_update_army_unit_values()

func _update_region_display() -> void:
	"""Update the display with current region information"""
	if current_region == null:
		hide_modal()
		return
	
	# Show Region node, hide Army node
	var army_node = get_node("Panel/Army")
	var region_node = get_node("Panel/Region")
	army_node.visible = false
	region_node.visible = true
	
	# Update region header with formatted name
	var region_name_label = get_node("Panel/Region/HeaderSection/RegionName")
	var formatted_name = current_region.get_region_level_string() + " of " + current_region.get_region_name()
	region_name_label.text = formatted_name
	
	# Update population
	var population_value = get_node("Panel/Region/PopulationSection/Population/Value")
	population_value.text = str(current_region.get_population())
	
	# Update growth rate
	var growth_value = get_node("Panel/Region/PopulationSection/Growth/Value")
	var growth_rate = GameParameters.POPULATION_GROWTH_RATE * 100
	growth_value.text = "+" + str(snappedf(growth_rate, 0.1)) + "%"
	
	# Update income (last population growth)
	var income_value = get_node("Panel/Region/PopulationSection/Income/Value")
	income_value.text = str(current_region.last_population_growth)
	
	# Update castle/defenses
	var castle_value = get_node("Panel/Region/GarisonSection/Castle/Value")
	castle_value.text = current_region.get_castle_type_string().to_upper()
	
	# Update defense score
	var defense_value = get_node("Panel/Region/GarisonSection/Growth/Value")
	var defense_bonus = GameParameters.get_castle_defense_bonus(current_region.get_castle_type())
	defense_value.text = str(defense_bonus) + "%"
	
	# Update recruits
	var recruits_value = get_node("Panel/Region/GarisonSection/Recruits/Value")
	var available = current_region.get_available_recruits()
	var max_recruits = current_region.get_max_recruits()
	recruits_value.text = str(available) + " / " + str(max_recruits)
	
	# Update resources
	_update_region_resource_values()
	
	# Update construction status
	_update_construction_status()
	
	# Update mine status
	_update_mine_status()

func _update_army_unit_values() -> void:
	"""Update army unit composition values"""
	if current_army == null:
		return
	
	var composition = current_army.get_composition()
	
	# Update each unit type
	var unit_nodes = [
		"Peasants", "Spearmen", "Archers", "Swordmen", 
		"Crossbowmen", "Horsemen", "Knights", "Mounted Knights", "Royal Guard"
	]
	
	var unit_types = [
		SoldierTypeEnum.Type.PEASANTS, SoldierTypeEnum.Type.SPEARMEN, 
		SoldierTypeEnum.Type.ARCHERS, SoldierTypeEnum.Type.SWORDSMEN,
		SoldierTypeEnum.Type.CROSSBOWMEN, SoldierTypeEnum.Type.HORSEMEN,
		SoldierTypeEnum.Type.KNIGHTS, SoldierTypeEnum.Type.MOUNTED_KNIGHTS,
		SoldierTypeEnum.Type.ROYAL_GUARD
	]
	
	for i in unit_nodes.size():
		var value_node = get_node("Panel/Army/UnitsSection/" + unit_nodes[i] + "/Value")
		var count = composition.get_soldier_count(unit_types[i])
		value_node.text = str(count)

func _update_region_resource_values() -> void:
	"""Update region resource values"""
	if current_region == null:
		return
	
	var resource_nodes = ["Resource1", "Resource2", "Resource3"]
	var resource_types = [ResourcesEnum.Type.FOOD, ResourcesEnum.Type.WOOD, ResourcesEnum.Type.STONE, ResourcesEnum.Type.IRON, ResourcesEnum.Type.GOLD]
	var resource_index = 0
	
	# Fill resources that exist and can be collected
	for resource_type in resource_types:
		var amount = current_region.get_resource_amount(resource_type)
		if amount > 0 and current_region.can_collect_resource(resource_type) and resource_index < resource_nodes.size():
			var label_node = get_node("Panel/Region/ResourcesSection/" + resource_nodes[resource_index] + "/Label")
			var value_node = get_node("Panel/Region/ResourcesSection/" + resource_nodes[resource_index] + "/Value")
			var resource_name = ResourcesEnum.type_to_string(resource_type)
			label_node.text = resource_name.capitalize() + ":"
			value_node.text = str(amount)
			resource_index += 1
	
	# Clear remaining resource slots
	while resource_index < resource_nodes.size():
		var label_node = get_node("Panel/Region/ResourcesSection/" + resource_nodes[resource_index] + "/Label")
		var value_node = get_node("Panel/Region/ResourcesSection/" + resource_nodes[resource_index] + "/Value")
		label_node.text = ""
		value_node.text = ""
		resource_index += 1

func _update_construction_status() -> void:
	"""Update construction status label"""
	var construction_label = get_node("Panel/Region/OtherSection/Construction")
	
	if current_region == null:
		construction_label.text = ""
		return
	
	if current_region.is_castle_under_construction():
		var castle_type = current_region.get_castle_under_construction()
		var turns_remaining = current_region.get_castle_build_turns_remaining()
		var castle_name = CastleTypeEnum.type_to_string(castle_type)
		construction_label.text = "Construction " + castle_name + " - " + str(turns_remaining) + " turn"
	else:
		construction_label.text = ""

func _update_mine_status() -> void:
	"""Update mine status label"""
	var mine_label = get_node("Panel/Region/OtherSection/Mine")
	
	if current_region == null:
		mine_label.text = ""
		return
	
	# Only show mine info for hills and forest hills
	if not GameParameters.can_search_for_ore_in_region(current_region.get_region_type()):
		mine_label.text = ""
		return
	
	var discovered_ores = current_region.get_discovered_ores()
	if not discovered_ores.is_empty():
		var ore_names: Array[String] = []
		for ore in discovered_ores:
			ore_names.append(ResourcesEnum.type_to_string(ore))
		mine_label.text = ", ".join(ore_names) + " discovered"
	elif current_region.get_ore_search_attempts_remaining() > 0:
		mine_label.text = "ore search potential!"
	else:
		mine_label.text = "Region has no ore"
