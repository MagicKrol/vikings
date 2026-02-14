extends Control
class_name InfoModal

# UI manager reference for modal mode
var ui_manager: UIManager = null
# Sound manager reference
var sound_manager: SoundManager = null
var game_manager: GameManager = null
var recruitment_modal: RecruitmentModal = null
var message_modal: MessageModal = null
var army_manager: ArmyManager = null
var player_manager: PlayerManagerNode = null
var region_manager: RegionManager = null

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
const BUTTON_GREEN_THEME: Theme = preload("res://themes/button_green_styles.tres")
const BUTTON_DEFAULT_THEME: Theme = preload("res://themes/button_styles.tres")
const ARMY_CARD_TEX_DEFAULT: Texture2D = preload("res://images/army_item3.png")
const ARMY_CARD_TEX_HOVER: Texture2D = preload("res://images/army_item_selected2.png")

var _progress_style_green: StyleBoxTexture
var _progress_style_yellow: StyleBoxTexture
var _progress_style_red: StyleBoxTexture
var _army_card_style_default: StyleBoxTexture
var _army_card_style_hover: StyleBoxTexture
var _army_card_armies: Array[Army] = []
var _army_card_labels: Array[Label] = []
var _army_card_label_colors: Array[Color] = []
var _suppress_auto_select: bool = false

enum TabType { REGION, ARMIES }
var _active_tab: TabType = TabType.REGION
var _inactive_tab_color: Color = Color(0.595154, 0.595154, 0.595154, 1)

@onready var _region_tab_label: Label = get_node("RegionPanel/Header/TabsSections/Container/RegionTab")
@onready var _armies_tab_label: Label = get_node("RegionPanel/Header/TabsSections/Container/ArmiesTab")
@onready var _region_panel_root: Panel = get_node("RegionPanel") as Panel
@onready var _region_panel: Control = get_node("RegionPanel/Body/Region")
@onready var _army_panel: Control = get_node("RegionPanel/Body/Army")
@onready var _region_textures: Control = get_node("RegionTextures")
@onready var _army_textures: Control = get_node("ArmyTextures")
@onready var _promote_button: Button = get_node("RegionPanel/Body/Region/Actions/RegionLevel/ActionSection/PromoteButton")
@onready var _build_button: Button = get_node("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/BuildButton")
@onready var _search_ore_button: Button = get_node("RegionPanel/Body/Region/Actions/Mine/ActionSection/SearchOreButton")
@onready var _raise_army_button: Button = get_node("RegionPanel/Body/Region/Actions/RaiseArmy/ActionSection/RaiseArmyButton")
@onready var _recruit_button: Button = get_node("RegionPanel/Body/Region/Actions/Garrison/VBoxContainer3/HBoxContainer/ActionSection/RecruitButton")
@onready var _army_cards: Array[Panel] = [
	get_node("RegionPanel/Body/Army/Army1") as Panel,
	get_node("RegionPanel/Body/Army/Army2") as Panel,
	get_node("RegionPanel/Body/Army/Army3") as Panel,
	get_node("RegionPanel/Body/Army/Army4") as Panel,
	get_node("RegionPanel/Body/Army/Army5") as Panel
]

func _ready():
	# Get references
	ui_manager = get_node("../UIManager") as UIManager
	sound_manager = get_node("../../SoundManager") as SoundManager
	game_manager = get_node("../../GameManager") as GameManager
	recruitment_modal = get_node("../RecruitmentModal") as RecruitmentModal
	message_modal = get_node("../MessageModal") as MessageModal
	player_manager = get_node("../../PlayerManager") as PlayerManagerNode
	army_manager = game_manager.get_army_manager()
	region_manager = game_manager.get_region_manager()
	_initialize_progress_bar_styles()
	_initialize_tabs()
	_initialize_army_cards()
	_initialize_region_actions()
	_region_panel_root.mouse_entered.connect(_on_region_panel_mouse_entered)
	
	# Initially hidden
	visible = false

func _initialize_tabs() -> void:
	if _armies_tab_label:
		_inactive_tab_color = _armies_tab_label.get_theme_color("font_color")
	_region_tab_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_armies_tab_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_region_tab_label.mouse_entered.connect(_on_region_tab_mouse_entered)
	_region_tab_label.mouse_exited.connect(_on_region_tab_mouse_exited)
	_region_tab_label.gui_input.connect(_on_region_tab_gui_input)
	_armies_tab_label.mouse_entered.connect(_on_armies_tab_mouse_entered)
	_armies_tab_label.mouse_exited.connect(_on_armies_tab_mouse_exited)
	_armies_tab_label.gui_input.connect(_on_armies_tab_gui_input)
	_set_active_tab(TabType.REGION)

func _initialize_army_cards() -> void:
	_army_card_style_default = StyleBoxTexture.new()
	_army_card_style_default.texture = ARMY_CARD_TEX_DEFAULT
	_army_card_style_hover = StyleBoxTexture.new()
	_army_card_style_hover.texture = ARMY_CARD_TEX_HOVER
	_army_card_labels.clear()
	_army_card_label_colors.clear()
	_army_card_armies.resize(_army_cards.size())
	for i in range(_army_cards.size()):
		var card = _army_cards[i]
		card.add_theme_stylebox_override("panel", _army_card_style_default)
		_set_cursor_shape_recursive(card, Control.CURSOR_POINTING_HAND)
		card.mouse_entered.connect(Callable(self, "_on_army_card_mouse_entered").bind(i))
		card.mouse_exited.connect(Callable(self, "_on_army_card_mouse_exited").bind(i))
		card.gui_input.connect(Callable(self, "_on_army_card_gui_input").bind(i))
		var label_path = NodePath(str(card.name) + "/HBoxContainer/ArmyName")
		var label = card.get_node(label_path) as Label
		_army_card_labels.append(label)
		_army_card_label_colors.append(label.get_theme_color("font_color"))

func _initialize_region_actions() -> void:
	_promote_button.pressed.connect(_on_promote_region_pressed)
	_build_button.pressed.connect(_on_build_button_pressed)
	_search_ore_button.pressed.connect(_on_ore_search_pressed)
	_raise_army_button.pressed.connect(_on_raise_army_pressed)
	_recruit_button.pressed.connect(_on_recruit_soldiers_pressed)

func _set_cursor_shape_recursive(node: Node, shape: int) -> void:
	if node is Control:
		var control_node := node as Control
		control_node.mouse_default_cursor_shape = shape
	for child in node.get_children():
		_set_cursor_shape_recursive(child, shape)

func show_army_info(army: Army, manage_modal_mode: bool = true) -> void:
	"""Show the modal with army information"""
	# Prevent showing during AI/computer turns
	if not _is_human_turn():
		return
	if army == null:
		hide_modal()
		return
	
	current_army = army
	_suppress_auto_select = false
	current_region = army.get_parent() as Region
	current_mode = DisplayMode.ARMY
	if _active_tab == TabType.ARMIES:
		_update_army_display()
	else:
		_update_region_display()
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
	if current_region == region and _active_tab == TabType.REGION:
		var armies_in_region := _get_armies_in_region(region)
		if not armies_in_region.is_empty():
			_set_active_tab(TabType.ARMIES)
			_update_army_display()
			visible = true
			if manage_modal_mode and ui_manager:
				ui_manager.set_modal_active(true)
			return
	
	current_region = region
	current_army = null
	if current_region != null:
		var armies_in_region := _get_armies_in_region(current_region)
		current_army = _find_army_with_most_movement_points(armies_in_region)
	_suppress_auto_select = false
	current_mode = DisplayMode.REGION
	if _active_tab == TabType.ARMIES:
		_update_army_display()
	else:
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
	DebugLogger.log("click", "InfoModal: hide_modal manage=" + str(manage_modal_mode))
	visible = false
	
	# Set modal mode inactive only if requested
	if manage_modal_mode and ui_manager:
		ui_manager.set_modal_active(false)

func close_modal() -> void:
	"""Close the modal and clear all content"""
	DebugLogger.log("click", "InfoModal: close_modal")
	current_army = null
	current_region = null
	current_mode = DisplayMode.NONE
	visible = false
	
	# Always set modal mode inactive when fully closing
	if ui_manager:
		ui_manager.set_modal_active(false)

func _update_army_display() -> void:
	"""Update the display with current army information"""
	if current_region == null and current_army != null:
		var parent_region: Region = current_army.get_parent() as Region
		if parent_region != null:
			current_region = parent_region
	if current_region == null:
		for card in _army_cards:
			card.visible = false
		return
	
	_update_region_header()

	var armies: Array[Army] = _get_armies_in_region(current_region)

	if current_army == null or not armies.has(current_army):
		if not _suppress_auto_select:
			current_army = _find_army_with_most_movement_points(armies)
	if current_army != null and not _suppress_auto_select:
		_select_army_for_move(current_army)

	for i in range(_army_cards.size()):
		var card = _army_cards[i]
		if i < armies.size():
			_update_army_card(card, armies[i])
			_army_card_armies[i] = armies[i]
		else:
			card.visible = false
			_army_card_armies[i] = null

func _update_army_card(card: Panel, army: Army) -> void:
	card.visible = true
	var selection_button = card.get_node("SelectionStatus") as Button
	if army == current_army:
		selection_button.theme = BUTTON_GREEN_THEME
		selection_button.text = "Selected"
		card.add_theme_stylebox_override("panel", _army_card_style_hover)
	else:
		selection_button.theme = BUTTON_DEFAULT_THEME
		selection_button.text = "Select"
		card.add_theme_stylebox_override("panel", _army_card_style_default)

	var content = card.get_node(NodePath(str(card.name))) as VBoxContainer
	var army_name_label = content.get_node("HBoxContainer/ArmyName") as Label
	army_name_label.text = "Army " + str(army.number)

	var move_container = content.get_node("MP/MoveContainer") as HBoxContainer
	_update_move_points_icons(move_container, army.get_movement_points())

	var progress_bar = content.get_node("Vigor/ProgressBar") as ProgressBar
	var vigor_percent = int(round(army.get_efficiency()))
	_update_vigor_bar(progress_bar, vigor_percent)
	var vigor_value = content.get_node("Vigor/ProgressBar/Value") as Label
	vigor_value.text = str(vigor_percent) + "%"

	var composition = army.get_composition()
	var wounded_composition = army.get_wounded_composition()
	var info_root = content.get_node("GarrisonInfo")
	_update_army_unit_values(composition, wounded_composition, info_root)

func _find_army_with_most_movement_points(armies: Array[Army]) -> Army:
	var best_army: Army = null
	var best_points: int = -1
	for army in armies:
		var points: int = army.get_movement_points()
		if points > best_points:
			best_points = points
			best_army = army
	return best_army

func _get_armies_in_region(region: Region) -> Array[Army]:
	var armies: Array[Army] = []
	if region == null:
		return armies
	for child in region.get_children():
		if child is Army:
			armies.append(child as Army)
	return armies

func _select_army_for_move(army: Army) -> void:
	var army_manager = game_manager.get_army_manager()
	if army_manager.selected_army == army:
		return
	var region_container: Region = army.get_parent() as Region
	var player_id: int = game_manager.get_current_player_id()
	army_manager.select_army(army, region_container, player_id)

func switch_to_region_tab() -> void:
	if _active_tab == TabType.REGION:
		return
	_set_active_tab(TabType.REGION)
	_update_region_display()

func _update_move_points_icons(move_container: HBoxContainer, move_points: int) -> void:
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
	var progress_bar = get_node("RegionPanel/Body/Army/Army1/Army1/Vigor/ProgressBar") as ProgressBar
	if progress_bar != null:
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 0
		progress_bar.add_theme_stylebox_override("fill", _progress_style_red)

func _update_vigor_bar(progress_bar: ProgressBar, vigor: int) -> void:
	if _progress_style_green == null:
		_initialize_progress_bar_styles()
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
		return
	
	_update_region_header()
	_update_region_level_section()
	_update_castle_section()
	_update_mine_status()
	_update_raise_army_section()
	_update_garrison_section()
	_update_defenders_section()
	_update_region_resource_values()

func _update_region_header() -> void:
	"""Update the region header name"""
	var region_name_label: Label = get_node("RegionPanel/Header/HeaderSection/RegionName")
	var formatted_name: String = current_region.get_region_level_string() + " of " + current_region.get_region_name()
	region_name_label.text = formatted_name

func _update_region_level_section() -> void:
	"""Update region level name/number and promotion cost"""
	var level_label: Label = get_node("RegionPanel/Body/Region/Actions/RegionLevel/VBoxContainer/Label")
	level_label.text = current_region.get_region_level_string()
	var level_value: Label = get_node("RegionPanel/Body/Region/Actions/RegionLevel/VBoxContainer/Info/RegionLevelValue")
	level_value.text = current_region.get_region_level_number()

	var current_level: RegionLevelEnum.Level = current_region.get_region_level()
	var target_level: RegionLevelEnum.Level = current_level
	if current_level < RegionLevelEnum.Level.L5:
		target_level = current_level + 1

	var cost: Dictionary = GameParameters.get_promotion_cost(target_level)
	var food_cost: int = int(cost.get(ResourcesEnum.Type.FOOD, 0))
	var wood_cost: int = int(cost.get(ResourcesEnum.Type.WOOD, 0))
	_set_cost_value("RegionPanel/Body/Region/Actions/RegionLevel/ActionSection/Resources/Food", food_cost)
	_set_cost_value("RegionPanel/Body/Region/Actions/RegionLevel/ActionSection/Resources/Wood", wood_cost)
	var promotion_available: bool = not current_region.has_promoted_this_turn()
	var can_afford_promotion: bool = _can_player_afford_promotion(target_level)
	_promote_button.disabled = current_level >= RegionLevelEnum.Level.L5 or not promotion_available or not can_afford_promotion

func _update_castle_section() -> void:
	"""Update castle name, defense, build/repair status, and cost display"""
	var castle_name_label: Label = get_node("RegionPanel/Body/Region/Actions/CastleLevel/Info/CastleLevelName")
	castle_name_label.text = current_region.get_castle_type_string().capitalize()

	var defense_value: Label = get_node("RegionPanel/Body/Region/Actions/CastleLevel/Info/Defense/DefenseValue")
	var base_defense: int = GameParameters.get_castle_defense_bonus(current_region.get_castle_type())
	var effective_defense: int = game_manager.get_battle_manager().get_effective_defense_for_region(current_region)
	defense_value.text = str(effective_defense) + "%"
	var min_defense: int = GameParameters.CASTLE_DEFENSE_BONUSES_MIN.get(current_region.get_castle_type(), 0)
	defense_value.add_theme_color_override("font_color", Color.WHITE)
	if base_defense > 0:
		if min_defense > 0 and effective_defense <= min_defense:
			defense_value.add_theme_color_override("font_color", Color.html("#d13131"))
		elif effective_defense < base_defense:
			defense_value.add_theme_color_override("font_color", GameParameters.UI_COLOR_WOUNDED)

	_update_construction_status()

	var cost: Dictionary = _get_castle_cost_for_display()
	var food_cost: int = int(cost.get(ResourcesEnum.Type.FOOD, 0))
	var wood_cost: int = int(cost.get(ResourcesEnum.Type.WOOD, 0))
	var stone_cost: int = int(cost.get(ResourcesEnum.Type.STONE, 0))
	var iron_cost: int = int(cost.get(ResourcesEnum.Type.IRON, 0))
	_set_cost_value("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/Resources/Food", food_cost)
	_set_cost_value("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/Resources/Wood", wood_cost)
	_set_cost_value("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/Resources/Stone", stone_cost)
	_set_cost_value("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/Resources/Iron", iron_cost)

func _get_castle_cost_for_display() -> Dictionary:
	var cost: Dictionary = {}
	if current_region.is_castle_under_repair() or current_region.has_castle_damage():
		return current_region.get_castle_repair_cost()
	if current_region.is_castle_under_construction():
		var building_type: CastleTypeEnum.Type = current_region.get_castle_under_construction()
		if building_type != CastleTypeEnum.Type.NONE:
			return GameParameters.get_castle_building_cost(building_type)
		return cost
	var current_type: CastleTypeEnum.Type = current_region.get_castle_type()
	var next_type: CastleTypeEnum.Type = CastleTypeEnum.get_next_level(current_type)
	if next_type == CastleTypeEnum.Type.NONE:
		return cost
	return GameParameters.get_castle_building_cost(next_type)

func _update_raise_army_section() -> void:
	"""Update raise army label and cost"""
	var owner_id: int = current_region.get_region_owner()
	var roman_number: String = game_manager.get_army_manager().get_next_army_roman_numeral_for_player(owner_id)
	var next_army_label: Label = get_node("RegionPanel/Body/Region/Actions/RaiseArmy/Info/Army/NextArmyName")
	next_army_label.text = "Army " + roman_number

	var gold_cost: int = GameParameters.get_raise_army_cost()
	_set_cost_value("RegionPanel/Body/Region/Actions/RaiseArmy/ActionSection/Resources/Gold", gold_cost)
	var castle_type := current_region.get_castle_type()
	var has_keep_or_higher: bool = castle_type >= CastleTypeEnum.Type.KEEP
	var can_afford_army: bool = _can_player_afford_raise_army()
	var has_used_raise_army: bool = current_region.has_raised_army_this_turn()
	var army_capacity_available: bool = _region_has_army_capacity()
	_raise_army_button.disabled = not has_keep_or_higher or not can_afford_army or has_used_raise_army or not army_capacity_available

func _update_garrison_section() -> void:
	"""Update garrison totals and recruits"""
	var garrison_value: Label = get_node("RegionPanel/Body/Region/Actions/Garrison/VBoxContainer3/HBoxContainer/Info/Men/GarrisonMenValue")
	var garrison_comp: ArmyComposition = current_region.get_garrison()
	garrison_value.text = str(garrison_comp.get_total_soldiers())

	var recruits_value: Label = get_node("RegionPanel/Body/Region/Actions/Garrison/VBoxContainer3/HBoxContainer/ActionSection/Resources/Population/Recruits")
	var recruits_max: Label = get_node("RegionPanel/Body/Region/Actions/Garrison/VBoxContainer3/HBoxContainer/ActionSection/Resources/Population/RecruitsMax")
	recruits_value.text = str(current_region.get_available_recruits())
	recruits_max.text = str(current_region.get_max_recruits())
	_recruit_button.disabled = false

func _update_defenders_section() -> void:
	"""Update garrison unit composition values"""
	var garrison_comp: ArmyComposition = current_region.get_garrison()
	var wounded_comp: ArmyComposition = current_region.get_wounded_garrison()
	var unit_nodes: Array[String] = [
		"Peasants", "Spearmen", "Archers", "Swordsmen",
		"Horsemen", "Crossbowmen", "Knights", "MountedKnights", "RoyalGuard"
	]
	var unit_types: Array[SoldierTypeEnum.Type] = [
		SoldierTypeEnum.Type.PEASANTS, SoldierTypeEnum.Type.SPEARMEN,
		SoldierTypeEnum.Type.ARCHERS, SoldierTypeEnum.Type.SWORDSMEN,
		SoldierTypeEnum.Type.HORSEMEN, SoldierTypeEnum.Type.CROSSBOWMEN,
		SoldierTypeEnum.Type.KNIGHTS, SoldierTypeEnum.Type.MOUNTED_KNIGHTS,
		SoldierTypeEnum.Type.ROYAL_GUARD
	]
	for i in unit_nodes.size():
		var value_node: Label = get_node("RegionPanel/Body/Region/DefendersSection/GarrisonInfo/" + unit_nodes[i] + "/Value")
		var healthy: int = garrison_comp.get_soldier_count(unit_types[i])
		var wounded: int = 0
		if wounded_comp != null:
			wounded = wounded_comp.get_soldier_count(unit_types[i])
		_set_unit_value_with_wounded(value_node, healthy, wounded)

func _set_cost_value(container_path: String, value: int) -> void:
	var container: HBoxContainer = get_node(container_path)
	container.visible = value > 0
	var value_label: Label = get_node(container_path + "/Value")
	value_label.text = str(value)

func _update_army_unit_values(composition: ArmyComposition, wounded_composition: ArmyComposition, info_root: Node) -> void:
	"""Update army unit composition values"""
	if composition == null or info_root == null:
		return

	var unit_nodes: Array[String] = [
		"Peasants", "Spearmen", "Archers", "Swordsmen",
		"Horsemen", "Crossbowmen", "Knights", "MountedKnights", "RoyalGuard"
	]
	var unit_types: Array[SoldierTypeEnum.Type] = [
		SoldierTypeEnum.Type.PEASANTS, SoldierTypeEnum.Type.SPEARMEN,
		SoldierTypeEnum.Type.ARCHERS, SoldierTypeEnum.Type.SWORDSMEN,
		SoldierTypeEnum.Type.HORSEMEN, SoldierTypeEnum.Type.CROSSBOWMEN,
		SoldierTypeEnum.Type.KNIGHTS, SoldierTypeEnum.Type.MOUNTED_KNIGHTS,
		SoldierTypeEnum.Type.ROYAL_GUARD
	]

	for i in unit_nodes.size():
		var value_node: Label = info_root.get_node(unit_nodes[i] + "/Value")
		var healthy: int = composition.get_soldier_count(unit_types[i])
		var wounded: int = 0
		if wounded_composition != null:
			wounded = wounded_composition.get_soldier_count(unit_types[i])
		_set_unit_value_with_wounded(value_node, healthy, wounded)

func _set_unit_value_with_wounded(value_node: Label, healthy: int, wounded: int) -> void:
	if wounded > 0:
		value_node.text = str(healthy) + "+" + str(wounded)
	else:
		value_node.text = str(healthy)

func _update_region_resource_values() -> void:
	"""Update region resource values"""
	if current_region == null:
		return

	var population_value = get_node("RegionPanel/Body/Region/RegionResources/Population/PopulationValue") as Label
	population_value.text = str(current_region.get_population())

	var growth_value = get_node("RegionPanel/Body/Region/RegionResources/Population/GrowthValue") as Label
	var growth_change = current_region.get_growth()
	if growth_change > 0:
		growth_value.text = "(+" + str(snappedf(growth_change * 100, 0.1)) + "%)"
		growth_value.modulate = Color.html("#41b43e")
	elif growth_change < 0:
		growth_value.text = "(" + str(snappedf(growth_change * 100, 0.1)) + "%)"
		growth_value.modulate = Color.html("#d13131")
	else:
		growth_value.text = "(+0%)"
		growth_value.modulate = Color.WHITE

	var income_value = get_node("RegionPanel/Body/Region/RegionResources/Income/Value") as Label
	income_value.text = str(current_region.get_income())

	var food_value = get_node("RegionPanel/Body/Region/RegionResources/Food/Value") as Label
	food_value.text = str(current_region.get_resource_amount(ResourcesEnum.Type.FOOD))
	var wood_value = get_node("RegionPanel/Body/Region/RegionResources/Wood/Value") as Label
	wood_value.text = str(current_region.get_resource_amount(ResourcesEnum.Type.WOOD))
	var stone_value = get_node("RegionPanel/Body/Region/RegionResources/Stone/Value") as Label
	stone_value.text = str(current_region.get_resource_amount(ResourcesEnum.Type.STONE))

	var iron_amount: int = current_region.get_resource_amount(ResourcesEnum.Type.IRON)
	var iron_container = get_node("RegionPanel/Body/Region/RegionResources/Iron") as HBoxContainer
	iron_container.visible = iron_amount > 0 and current_region.can_collect_resource(ResourcesEnum.Type.IRON)
	var iron_value = get_node("RegionPanel/Body/Region/RegionResources/Iron/Value") as Label
	iron_value.text = str(iron_amount)

	var gold_amount: int = current_region.get_resource_amount(ResourcesEnum.Type.GOLD)
	var gold_container = get_node("RegionPanel/Body/Region/RegionResources/Gold") as HBoxContainer
	gold_container.visible = gold_amount > 0 and current_region.can_collect_resource(ResourcesEnum.Type.GOLD)
	var gold_value = get_node("RegionPanel/Body/Region/RegionResources/Gold/Value") as Label
	gold_value.text = str(gold_amount)

func _update_construction_status() -> void:
	"""Update construction status label"""
	var build_button = get_node("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/BuildButton") as Button
	if current_region.is_castle_under_construction():
		build_button.text = "Building"
		build_button.disabled = true
	elif current_region.is_castle_under_repair():
		build_button.text = "Repairing"
		build_button.disabled = true
	elif current_region.has_castle_damage():
		build_button.text = "Repair"
		var can_repair: bool = _can_player_afford_repair() and current_region.has_castle()
		build_button.disabled = not can_repair
	elif current_region.get_castle_type() == CastleTypeEnum.Type.NONE:
		build_button.text = "Build"
		build_button.disabled = not (_can_player_afford_any_castle() and current_region.can_build_castle())
	else:
		build_button.text = "Upgrade"
		var next_type: CastleTypeEnum.Type = CastleTypeEnum.get_next_level(current_region.get_castle_type())
		if next_type == CastleTypeEnum.Type.NONE:
			build_button.disabled = true
		else:
			build_button.disabled = not (_can_player_afford_castle(next_type) and current_region.can_upgrade_castle())

func _update_mine_status() -> void:
	"""Update mine status label"""
	var mine_label = get_node("RegionPanel/Body/Region/Actions/Mine/Info/Search/SearchStatus") as Label
	mine_label.text = current_region.get_ore_search_status_string()
	var gold_cost: int = GameParameters.get_ore_search_cost()
	_set_cost_value("RegionPanel/Body/Region/Actions/Mine/ActionSection/Resources/Gold", gold_cost)
	var can_search_region: bool = GameParameters.can_search_for_ore_in_region(current_region.get_region_type())
	var can_search: bool = current_region.can_search_for_ore()
	var can_afford: bool = _can_player_afford_ore_search()
	_search_ore_button.disabled = not (can_search_region and can_search and can_afford)

func _on_promote_region_pressed() -> void:
	sound_manager.click_sound()
	if current_region.get_region_level() >= RegionLevelEnum.Level.L5:
		return
	var next_level: RegionLevelEnum.Level = current_region.get_region_level() + 1
	if not _can_player_afford_promotion(next_level):
		return
	var promotion_cost: Dictionary = GameParameters.get_promotion_cost(next_level)
	var current_player: Player = player_manager.get_player(1)
	if not current_player.pay_cost(promotion_cost):
		return
	current_region.promote_region()
	current_region.mark_promoted_this_turn()
	var level_name = RegionLevelEnum.level_to_string(next_level)
	var promotion_message = "Region promoted to " + level_name + " \n(level " + str(int(next_level) + 1) + ")"
	message_modal.display_message(promotion_message)
	_refresh_current_region()
	_request_player_status_refresh()

func _on_recruit_soldiers_pressed() -> void:
	sound_manager.click_sound()
	ui_manager.remember_region_select(current_region)
	recruitment_modal.show_region_recruitment(current_region)

func _on_build_button_pressed() -> void:
	if current_region.is_castle_under_construction():
		return
	if current_region.is_castle_under_repair():
		return
	if current_region.has_castle_damage():
		_on_repair_castle_pressed()
		return
	if current_region.get_castle_type() == CastleTypeEnum.Type.NONE:
		_on_build_castle_pressed()
	else:
		_on_upgrade_castle_pressed()

func _on_build_castle_pressed() -> void:
	sound_manager.click_sound()
	if not current_region.can_build_castle():
		return
	if not _can_player_afford_any_castle():
		return
	_start_castle_construction(CastleTypeEnum.Type.OUTPOST)

func _on_upgrade_castle_pressed() -> void:
	sound_manager.click_sound()
	if not current_region.can_upgrade_castle():
		return
	var current_castle_type = current_region.get_castle_type()
	var next_castle_type = CastleTypeEnum.get_next_level(current_castle_type)
	if next_castle_type == CastleTypeEnum.Type.NONE:
		return
	if not _can_player_afford_castle(next_castle_type):
		return
	_start_castle_construction(next_castle_type)

func _on_repair_castle_pressed() -> void:
	sound_manager.click_sound()
	if current_region.is_castle_under_repair() or not current_region.has_castle_damage():
		return
	if not _can_player_afford_repair():
		return
	var current_player = player_manager.get_player(1)
	if not region_manager.try_repair_castle(current_region, current_player):
		return
	message_modal.display_message("Repair started", "Repairs will finish in 1 turn.")
	_refresh_current_region()
	_request_player_status_refresh()

func _start_castle_construction(castle_type: CastleTypeEnum.Type) -> void:
	var construction_cost = GameParameters.get_castle_building_cost(castle_type)
	var current_player = player_manager.get_player(1)
	if not current_player.pay_cost(construction_cost):
		return
	current_region.start_castle_construction(castle_type)
	var turns_left = current_region.get_castle_build_turns_remaining()
	var building_name = CastleTypeEnum.type_to_string(castle_type)
	message_modal.display_message(building_name + " will be done in " + str(turns_left) + " turn(s).")
	_refresh_current_region()
	_request_player_status_refresh()

func _on_ore_search_pressed() -> void:
	sound_manager.click_sound()
	if not GameParameters.can_search_for_ore_in_region(current_region.get_region_type()):
		return
	if not current_region.can_search_for_ore():
		return
	if not _can_player_afford_ore_search():
		return
	var search_result = region_manager.perform_ore_search(current_region, 1, player_manager)
	if search_result.success and search_result.has("ore_type"):
		var ore_type = search_result.ore_type
		var ore_type_string = ResourcesEnum.type_to_string(ore_type)
		var ore_amount = current_region.get_resource_amount(ore_type)
		var header = ore_type_string.capitalize() + " Found!"
		var message = "Ore size was estimated to " + str(ore_amount) + " units."
		message_modal.display_message(header, message)
	elif not search_result.success:
		var header = "Ore Search"
		var remaining_attempts = current_region.get_ore_search_attempts_remaining()
		var message: String
		if remaining_attempts > 0:
			message = "No luck this turn."
		else:
			message = "Ore searches exhausted."
		message_modal.display_message(header, message)
	_refresh_current_region()
	_request_player_status_refresh()

func _on_raise_army_pressed() -> void:
	sound_manager.click_sound()
	if not _region_has_army_capacity():
		return
	if not _can_player_afford_raise_army():
		return
	var current_player = player_manager.get_player(game_manager.get_current_player())
	var raise_army_cost = GameParameters.get_raise_army_cost()
	if current_player.get_resource_amount(ResourcesEnum.Type.GOLD) < raise_army_cost:
		return
	current_player.remove_resources(ResourcesEnum.Type.GOLD, raise_army_cost)
	var new_army = army_manager.create_raised_army(current_region, game_manager.get_current_player())
	if new_army != null:
		current_region.mark_raise_army_used()
		var army_name = new_army.name if new_army.name else "New Army"
		message_modal.display_message(army_name + " is being raised")
		_refresh_current_region()
		_request_player_status_refresh()
	else:
		current_player.add_resources(ResourcesEnum.Type.GOLD, raise_army_cost)

func _calculate_repair_cost() -> Dictionary:
	return current_region.get_castle_repair_cost()

func _can_player_afford_repair() -> bool:
	var current_player = player_manager.get_player(1)
	var repair_cost = _calculate_repair_cost()
	return current_player.can_afford_cost(repair_cost)

func _can_player_afford_promotion(target_level: RegionLevelEnum.Level) -> bool:
	var promotion_cost = GameParameters.get_promotion_cost(target_level)
	var current_player = player_manager.get_player(1)
	var player_resources = {
		ResourcesEnum.Type.GOLD: current_player.get_resource_amount(ResourcesEnum.Type.GOLD),
		ResourcesEnum.Type.FOOD: current_player.get_resource_amount(ResourcesEnum.Type.FOOD),
		ResourcesEnum.Type.WOOD: current_player.get_resource_amount(ResourcesEnum.Type.WOOD),
		ResourcesEnum.Type.IRON: current_player.get_resource_amount(ResourcesEnum.Type.IRON),
		ResourcesEnum.Type.STONE: current_player.get_resource_amount(ResourcesEnum.Type.STONE)
	}
	if not GameParameters.can_afford_promotion(target_level, player_resources):
		return false
	if game_manager.is_player_computer(current_player.get_player_id()):
		return _passes_food_upgrade_safeguard(current_player.get_player_id(), promotion_cost)
	return true

func _passes_food_upgrade_safeguard(player_id: int, promotion_cost: Dictionary) -> bool:
	var food_cost = int(promotion_cost.get(ResourcesEnum.Type.FOOD, 0))
	return player_manager.meets_food_upgrade_safeguard(player_id, food_cost)

func _can_player_afford_castle(castle_type: CastleTypeEnum.Type) -> bool:
	var current_player = player_manager.get_player(1)
	var player_resources = {
		ResourcesEnum.Type.GOLD: current_player.get_resource_amount(ResourcesEnum.Type.GOLD),
		ResourcesEnum.Type.FOOD: current_player.get_resource_amount(ResourcesEnum.Type.FOOD),
		ResourcesEnum.Type.WOOD: current_player.get_resource_amount(ResourcesEnum.Type.WOOD),
		ResourcesEnum.Type.IRON: current_player.get_resource_amount(ResourcesEnum.Type.IRON),
		ResourcesEnum.Type.STONE: current_player.get_resource_amount(ResourcesEnum.Type.STONE)
	}
	return GameParameters.can_afford_castle(castle_type, player_resources)

func _can_player_afford_any_castle() -> bool:
	return _can_player_afford_castle(CastleTypeEnum.Type.OUTPOST)

func _can_player_afford_ore_search() -> bool:
	var current_player = player_manager.get_player(1)
	var search_cost = GameParameters.get_ore_search_cost()
	return current_player.get_resource_amount(ResourcesEnum.Type.GOLD) >= search_cost

func _can_player_afford_raise_army() -> bool:
	var current_player = player_manager.get_player(1)
	var raise_army_cost = GameParameters.get_raise_army_cost()
	return current_player.get_resource_amount(ResourcesEnum.Type.GOLD) >= raise_army_cost

func _region_has_army_capacity() -> bool:
	return not army_manager.is_region_at_army_cap(current_region)

func _request_player_status_refresh() -> void:
	GlobalSignals.emit_signal("player_status_refresh_requested")

func _refresh_current_region() -> void:
	if _active_tab == TabType.ARMIES:
		_update_army_display()
	else:
		_update_region_display()

func _set_active_tab(tab: TabType) -> void:
	_active_tab = tab
	_apply_tab_visibility()
	_apply_tab_colors()

func _apply_tab_visibility() -> void:
	var is_region_tab: bool = _active_tab == TabType.REGION
	_region_panel.visible = is_region_tab
	_army_panel.visible = not is_region_tab
	_region_textures.visible = is_region_tab
	_army_textures.visible = not is_region_tab

func _apply_tab_colors() -> void:
	if _active_tab == TabType.REGION:
		_region_tab_label.remove_theme_color_override("font_color")
		_armies_tab_label.add_theme_color_override("font_color", _inactive_tab_color)
	else:
		_armies_tab_label.remove_theme_color_override("font_color")
		_region_tab_label.add_theme_color_override("font_color", _inactive_tab_color)

func _on_region_tab_mouse_entered() -> void:
	if _active_tab != TabType.REGION:
		_region_tab_label.add_theme_color_override("font_color", Color.WHITE)

func _on_region_tab_mouse_exited() -> void:
	if _active_tab != TabType.REGION:
		_region_tab_label.add_theme_color_override("font_color", _inactive_tab_color)

func _on_armies_tab_mouse_entered() -> void:
	if _active_tab != TabType.ARMIES:
		_armies_tab_label.add_theme_color_override("font_color", Color.WHITE)

func _on_armies_tab_mouse_exited() -> void:
	if _active_tab != TabType.ARMIES:
		_armies_tab_label.add_theme_color_override("font_color", _inactive_tab_color)

func _on_region_tab_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		DebugLogger.log("click", "InfoModal: Region tab click")
		if _active_tab != TabType.REGION:
			current_army = null
			game_manager.get_army_manager().deselect_army()
			_set_active_tab(TabType.REGION)
			_update_region_display()
		_region_tab_label.accept_event()
		get_viewport().set_input_as_handled()

func _on_armies_tab_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		DebugLogger.log("click", "InfoModal: Armies tab click")
		if _active_tab != TabType.ARMIES:
			current_army = null
			game_manager.get_army_manager().deselect_army()
			_set_active_tab(TabType.ARMIES)
			_update_army_display()
		_armies_tab_label.accept_event()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		current_army = null
		game_manager.get_army_manager().deselect_army()
		if _active_tab == TabType.REGION:
			_set_active_tab(TabType.ARMIES)
			_update_army_display()
		else:
			_set_active_tab(TabType.REGION)
			_update_region_display()
		get_viewport().set_input_as_handled()

func _on_region_panel_mouse_entered() -> void:
	if ui_manager:
		ui_manager.hide_region_tooltip()

func _on_army_card_mouse_entered(index: int) -> void:
	var card = _army_cards[index]
	card.add_theme_stylebox_override("panel", _army_card_style_hover)
	var label = _army_card_labels[index]
	label.add_theme_color_override("font_color", Color.WHITE)
	if ui_manager:
		ui_manager.hide_region_tooltip()

func _on_army_card_mouse_exited(index: int) -> void:
	var card = _army_cards[index]
	var army = _army_card_armies[index]
	if army != null and army == current_army:
		card.add_theme_stylebox_override("panel", _army_card_style_hover)
	else:
		card.add_theme_stylebox_override("panel", _army_card_style_default)
	var label = _army_card_labels[index]
	label.add_theme_color_override("font_color", _army_card_label_colors[index])

func _on_army_card_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var army = _army_card_armies[index]
		if army != null and army == current_army:
			game_manager.get_army_manager().deselect_army()
			current_army = null
			_suppress_auto_select = true
			_update_army_display()
		else:
			current_army = army
			_suppress_auto_select = false
			_select_army_for_move(army)
			_update_army_display()
		(_army_cards[index] as Control).accept_event()
		get_viewport().set_input_as_handled()
