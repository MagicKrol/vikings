extends Control
class_name InfoModal

# UI manager reference for modal mode
var ui_manager: UIManager = null
# Sound manager reference
var sound_manager: SoundManager = null
var game_manager: GameManager = null

# Current display mode
enum DisplayMode { NONE, ARMY, REGION }
var current_mode: DisplayMode = DisplayMode.NONE

# Current data references
var current_army: Army = null
var current_region: Region = null

const MOVE_ICON_GREEN: Texture2D = preload("res://images/icons/move_green.png")
const MOVE_ICON_YELLOW: Texture2D = preload("res://images/icons/move_yellow.png")
const MOVE_ICON_RED: Texture2D = preload("res://images/icons/move_red.png")
const MOVE_ICON_EMPTY: Texture2D = preload("res://images/icons/move_empty2.png")
const PROGRESS_TEX_GREEN: Texture2D = preload("res://images/progressbar_green.png")
const PROGRESS_TEX_YELLOW: Texture2D = preload("res://images/progressbar_yellow.png")
const PROGRESS_TEX_RED: Texture2D = preload("res://images/progressbar_red.png")

var _progress_style_green: StyleBoxTexture
var _progress_style_yellow: StyleBoxTexture
var _progress_style_red: StyleBoxTexture
@onready var army_texture: TextureRect = $ArmyTexture

func _ready():
	# Get references
	ui_manager = get_node("../UIManager") as UIManager
	sound_manager = get_node("../../SoundManager") as SoundManager
	game_manager = get_node("../../GameManager") as GameManager
	_initialize_progress_bar_styles()
	
	# Initially hidden
	visible = false

func show_army_info(army: Army, manage_modal_mode: bool = true) -> void:
	"""Show the modal with army information"""
	# Prevent showing during AI/computer turns
	if not _is_human_turn():
		return
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
	# Prevent showing during AI/computer turns
	if not _is_human_turn():
		return
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

func _is_human_turn() -> bool:
	var pid := game_manager.get_current_player_id()
	return game_manager.is_player_human(pid)

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
	army_texture.visible = true
	
	# Update army header
	var army_name_label = get_node("Panel/Army/HeaderSection/ArmyName")
	army_name_label.text = "Army " + str(current_army.number)
	
	# Update movement points icons
	_update_move_points_icons(current_army.get_movement_points())
	
	# Update vigor
	var vigor_value = get_node("Panel/Army/PopulationSection/Vigor/Value")
	var vigor_percent = int(round(current_army.get_efficiency()))
	vigor_value.text = str(vigor_percent) + "%"
	_update_vigor_bar(vigor_percent)
	
	# Update total men count
	var men_value = get_node("Panel/Army/PopulationSection/Men/Value")
	men_value.text = str(current_army.get_total_soldiers())

	# Update Wounded label for total men
	var wounded_label_node = get_node("Panel/Army/PopulationSection/Men/Wounded") as Label
	var wounded_total_soldiers = current_army.get_wounded_composition().get_total_soldiers()
	if wounded_total_soldiers > 0:
		wounded_label_node.visible = true
		wounded_label_node.add_theme_color_override("font_color", GameParameters.UI_COLOR_WOUNDED)
	else:
		wounded_label_node.visible = false
	
	# Update unit composition
	_update_army_unit_values()

func _update_move_points_icons(move_points: int) -> void:
	var move_container = get_node("Panel/Army/PopulationSection/MP/MoveContainer")
	if move_container == null:
		return
	var points = int(move_points)
	var filled_icons = clamp(points, 0, 5)
	var active_texture: Texture2D = MOVE_ICON_EMPTY
	if points >= 5:
		filled_icons = 5
		active_texture = MOVE_ICON_GREEN
	elif points >= 3:
		active_texture = MOVE_ICON_YELLOW
	elif points >= 1:
		active_texture = MOVE_ICON_RED
	else:
		filled_icons = 0
	for i in range(move_container.get_child_count()):
		var child = move_container.get_child(i)
		if child is TextureRect:
			var icon := child as TextureRect
			if i < filled_icons:
				icon.texture = active_texture
			else:
				icon.texture = MOVE_ICON_EMPTY

func _initialize_progress_bar_styles() -> void:
	_progress_style_green = StyleBoxTexture.new()
	_progress_style_green.texture = PROGRESS_TEX_GREEN
	_progress_style_yellow = StyleBoxTexture.new()
	_progress_style_yellow.texture = PROGRESS_TEX_YELLOW
	_progress_style_red = StyleBoxTexture.new()
	_progress_style_red.texture = PROGRESS_TEX_RED
	var progress_bar = get_node("Panel/Army/PopulationSection/ProgressBar") as ProgressBar
	if progress_bar != null:
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 0
		progress_bar.add_theme_stylebox_override("fill", _progress_style_red)

func _update_vigor_bar(vigor: int) -> void:
	if _progress_style_green == null:
		_initialize_progress_bar_styles()
	var progress_bar = get_node("Panel/Army/PopulationSection/ProgressBar") as ProgressBar
	if progress_bar == null:
		return
	var clamped_vigor = clamp(vigor, 0, 100)
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = clamped_vigor
	var style: StyleBoxTexture = _progress_style_red
	if clamped_vigor >= 81:
		style = _progress_style_green
	elif clamped_vigor >= 51:
		style = _progress_style_yellow
	progress_bar.add_theme_stylebox_override("fill", style)
	progress_bar.queue_redraw()

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
	army_texture.visible = false
	
	# Update region header with formatted name
	var region_name_label = get_node("Panel/Region/HeaderSection/RegionName")
	var formatted_name = current_region.get_region_level_string() + " of " + current_region.get_region_name()
	region_name_label.text = formatted_name
	
	# Update population
	var population_value = get_node("Panel/Region/PopulationSection/Population/Value")
	population_value.text = str(current_region.get_population())
	
	# Update growth rate
	var growth_value = get_node("Panel/Region/PopulationSection/Growth/Value")
	var growth_change = current_region.get_growth()
	if growth_change > 0:
		growth_value.text = "+" + str(snappedf(growth_change * 100, 0.1)) + "%"
		growth_value.modulate = Color.html("#41b43e")
	elif growth_change < 0:
		growth_value.text = "-" + str(snappedf(growth_change * 100, 0.1)) + "%"
		growth_value.modulate = Color.html("#d13131")
	else:
		growth_value.text = "+0%"
		growth_value.modulate = Color.WHITE
	
	# Update income (gold income from population)
	var income_value = get_node("Panel/Region/PopulationSection/Income/Value")
	var gold_income = current_region.get_income()
	income_value.text = str(gold_income)
	
	# Update region level
	var level_value = get_node("Panel/Region/PopulationSection/Level/Value")
	level_value.text = current_region.get_region_level_number()
	
	# Update castle/defenses
	var castle_value = get_node("Panel/Region/GarisonSection/Castle/Value")
	castle_value.text = current_region.get_castle_type_string().to_upper()
	
	# Update defense score
	var defense_value = get_node("Panel/Region/GarisonSection/Growth/Value") as Label
	var defense_bonus = GameParameters.get_castle_defense_bonus(current_region.get_castle_type())
	var min_defense = GameParameters.CASTLE_DEFENSE_BONUSES_MIN.get(current_region.get_castle_type(), 0)
	var damage_total = current_region.gate_damage + current_region.wall_damage
	var effective_defense = max(min_defense, defense_bonus - damage_total)
	defense_value.text = str(effective_defense) + "%"
	defense_value.remove_theme_color_override("font_color")
	if defense_bonus > 0:
		if min_defense > 0 and effective_defense <= min_defense:
			defense_value.add_theme_color_override("font_color", Color.html("#d13131"))
		elif effective_defense < defense_bonus:
			defense_value.add_theme_color_override("font_color", GameParameters.UI_COLOR_WOUNDED)

	# Update local garrison total (exclude recruits; garrison is a separate composition)
	var garrison_value = get_node("Panel/Region/GarisonSection/Garison/Value")
	var garrison_comp = current_region.get_garrison()
	var garrison_total: int = 0
	if garrison_comp != null:
		garrison_total = garrison_comp.get_total_soldiers()
	garrison_value.text = str(garrison_total)
	# Update garrison wounded "(n)" or empty when zero
	var garrison_wounded_label = get_node("Panel/Region/GarisonSection/Garison/WoundedValue") as Label
	var wg_total: int = 0
	var wg_comp = current_region.get_wounded_garrison()
	if wg_comp != null:
		wg_total = wg_comp.get_total_soldiers()
	if wg_total > 0:
		garrison_wounded_label.text = "(" + str(wg_total) + ")"
		garrison_wounded_label.add_theme_color_override("font_color", GameParameters.UI_COLOR_WOUNDED)
	else:
		garrison_wounded_label.text = ""
	
	# Update recruits
	var recruits_value = get_node("Panel/Region/GarisonSection/Recruits/Value")
	var available = current_region.get_available_recruits()
	var max_recruits = current_region.get_max_recruits()
	recruits_value.text = str(available) + " / " + str(max_recruits)
	# Update recruits wounded (peasants only) "(n)" or empty when zero
	var recruits_wounded_label = get_node("Panel/Region/GarisonSection/Recruits/WoundedValue") as Label
	var wr_total: int = current_region.get_wounded_recruits_total()
	if wr_total > 0:
		recruits_wounded_label.text = "(" + str(wr_total) + ")"
		recruits_wounded_label.add_theme_color_override("font_color", GameParameters.UI_COLOR_WOUNDED)
	else:
		recruits_wounded_label.text = ""
	
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
	var wounded_comp = current_army.get_wounded_composition()
	
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
		var base_path = "Panel/Army/UnitsSection/" + unit_nodes[i]
		var value_node = get_node(base_path + "/Value")
		var count = composition.get_soldier_count(unit_types[i])
		value_node.text = str(count)
		# Wounded display as "(n)" in yellow; empty if none
		var wounded_node = get_node(base_path + "/Wounded") as Label
		var wcount: int = wounded_comp.get_soldier_count(unit_types[i])
		if wcount > 0:
			wounded_node.text = "(" + str(wcount) + ")"
			wounded_node.add_theme_color_override("font_color", GameParameters.UI_COLOR_WOUNDED)
		else:
			wounded_node.text = ""

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
		construction_label.text = "Building " + castle_name + " - " + str(turns_remaining) + " turn"
		if turns_remaining > 1: 
			construction_label.text = construction_label.text + "s"
	elif current_region.is_castle_under_repair():
		construction_label.text = "Repairing castle - 1 turn"
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
		mine_label.text = "Ore search potential!"
	else:
		mine_label.text = "Region has no ore"
