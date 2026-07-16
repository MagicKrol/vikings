extends Control
class_name MapFilterModal

const RESOURCE_ALPHA_ZERO: float = 0.2
const RESOURCE_ALPHA_MAXIMUM: float = 0.85
const RESOURCE_VALUE_ALPHA_ZERO: float = 0.0
const DATA_ALPHA_MINIMUM: float = 0.1
const DATA_ALPHA_MAXIMUM: float = 0.9
const OWNERSHIP_ALPHA_DEFAULT: float = 0.4
const NEUTRAL_RESOURCE_COLOR: Color = Color.YELLOW
const OWNERSHIP_TOOLTIP_TEXT: String = "Change regions' ownership visibility."
const PLAYER_ONLY_TOOLTIP_TEXT: String = "Show filters only for regions owned by the current player."
const LEVEL_BONUS_TOOLTIP_TEXT: String = "Include region level bonuses in resource filters."

enum FilterType {
	FOOD,
	WOOD,
	STONE,
	IRON,
	GOLD,
	POPULATION,
	REGION_LEVEL,
	SEARCH_ORE
}

var food_button: Button
var wood_button: Button
var stone_button: Button
var iron_button: Button
var gold_button: Button
var population_button: Button
var level_button: Button
var search_ore_button: Button
var ownership_on_button: Button
var ownership_off_button: Button
var player_only_on_button: Button
var player_only_off_button: Button
var level_bonus_on_button: Button
var level_bonus_off_button: Button
var filter_tooltip: SelectTooltipModalNoRes
var ui_manager: UIManager
var map_generator: MapGenerator
var region_manager: RegionManager
var visual_manager: VisualManager
var game_manager: GameManager
var selected_filter: FilterType = FilterType.FOOD
var show_ownership: bool = true
var player_only: bool = false
var include_level_bonus: bool = false

func _ready() -> void:
	food_button = get_node("ContentContainer/HBoxContainer/Food") as Button
	gold_button = get_node("ContentContainer/HBoxContainer/Gold") as Button
	wood_button = get_node("ContentContainer/HBoxContainer2/Wood") as Button
	population_button = get_node("ContentContainer/HBoxContainer2/Population") as Button
	stone_button = get_node("ContentContainer/HBoxContainer3/Stone") as Button
	level_button = get_node("ContentContainer/HBoxContainer3/Level") as Button
	iron_button = get_node("ContentContainer/HBoxContainer4/Iron") as Button
	search_ore_button = get_node("ContentContainer/HBoxContainer4/SearchOre") as Button
	ownership_on_button = get_node("ContentContainer/Ownership/OwnershipOn") as Button
	ownership_off_button = get_node("ContentContainer/Ownership/OwnershipOff") as Button
	player_only_on_button = get_node("ContentContainer/Ownership2/PlayerOnlyOn") as Button
	player_only_off_button = get_node("ContentContainer/Ownership2/PlayerOnlyOff") as Button
	level_bonus_on_button = get_node("ContentContainer/LevelBonus/BonusOn") as Button
	level_bonus_off_button = get_node("ContentContainer/LevelBonus/BonusOff") as Button
	filter_tooltip = get_node("FilterModal") as SelectTooltipModalNoRes
	ui_manager = get_parent().get_node("UIManager") as UIManager
	map_generator = get_parent().get_parent().get_node("Map") as MapGenerator
	game_manager = get_parent().get_parent().get_node("GameManager") as GameManager
	region_manager = game_manager.get_region_manager()
	visual_manager = game_manager.get_visual_manager()
	food_button.pressed.connect(_on_filter_button_pressed.bind(FilterType.FOOD))
	wood_button.pressed.connect(_on_filter_button_pressed.bind(FilterType.WOOD))
	stone_button.pressed.connect(_on_filter_button_pressed.bind(FilterType.STONE))
	iron_button.pressed.connect(_on_filter_button_pressed.bind(FilterType.IRON))
	gold_button.pressed.connect(_on_filter_button_pressed.bind(FilterType.GOLD))
	population_button.pressed.connect(_on_filter_button_pressed.bind(FilterType.POPULATION))
	level_button.pressed.connect(_on_filter_button_pressed.bind(FilterType.REGION_LEVEL))
	search_ore_button.pressed.connect(_on_filter_button_pressed.bind(FilterType.SEARCH_ORE))
	ownership_on_button.pressed.connect(_on_ownership_button_pressed.bind(true))
	ownership_off_button.pressed.connect(_on_ownership_button_pressed.bind(false))
	player_only_on_button.pressed.connect(_on_player_only_button_pressed.bind(true))
	player_only_off_button.pressed.connect(_on_player_only_button_pressed.bind(false))
	level_bonus_on_button.pressed.connect(_on_level_bonus_button_pressed.bind(true))
	level_bonus_off_button.pressed.connect(_on_level_bonus_button_pressed.bind(false))
	_connect_filter_option_tooltips()

func show_modal() -> void:
	ui_manager.close_all_active_modals()
	visible = true
	ui_manager.set_modal_active(true)
	visual_manager.set_ready_army_highlights_suspended_for_map_filter(true)
	_set_ownership(true)
	_set_player_only(false)
	_set_level_bonus(false)
	_select_filter(FilterType.FOOD)

func hide_modal() -> void:
	visible = false
	filter_tooltip.hide_tooltip()
	_restore_ownership_overlay_alpha()
	visual_manager.set_ready_army_highlights_suspended_for_map_filter(false)
	ui_manager.set_modal_active(false)

func _on_filter_button_pressed(filter_type: FilterType) -> void:
	_select_filter(filter_type)

func _on_ownership_button_pressed(enabled: bool) -> void:
	_set_ownership(enabled)
	_apply_filter_overlay()

func _on_player_only_button_pressed(enabled: bool) -> void:
	_set_player_only(enabled)
	_apply_filter_overlay()

func _on_level_bonus_button_pressed(enabled: bool) -> void:
	_set_level_bonus(enabled)
	_apply_filter_overlay()

func _set_ownership(enabled: bool) -> void:
	show_ownership = enabled
	ownership_on_button.button_pressed = enabled
	ownership_off_button.button_pressed = not enabled

func _set_player_only(enabled: bool) -> void:
	player_only = enabled
	player_only_on_button.button_pressed = enabled
	player_only_off_button.button_pressed = not enabled

func _set_level_bonus(enabled: bool) -> void:
	include_level_bonus = enabled
	level_bonus_on_button.button_pressed = enabled
	level_bonus_off_button.button_pressed = not enabled

func _connect_filter_option_tooltips() -> void:
	_connect_filter_option_tooltip(ownership_on_button, OWNERSHIP_TOOLTIP_TEXT)
	_connect_filter_option_tooltip(ownership_off_button, OWNERSHIP_TOOLTIP_TEXT)
	_connect_filter_option_tooltip(player_only_on_button, PLAYER_ONLY_TOOLTIP_TEXT)
	_connect_filter_option_tooltip(player_only_off_button, PLAYER_ONLY_TOOLTIP_TEXT)
	_connect_filter_option_tooltip(level_bonus_on_button, LEVEL_BONUS_TOOLTIP_TEXT)
	_connect_filter_option_tooltip(level_bonus_off_button, LEVEL_BONUS_TOOLTIP_TEXT)

func _connect_filter_option_tooltip(button: Button, tooltip_text: String) -> void:
	button.mouse_entered.connect(_show_filter_tooltip.bind(tooltip_text))
	button.mouse_exited.connect(filter_tooltip.hide_tooltip)

func _show_filter_tooltip(tooltip_text: String) -> void:
	filter_tooltip.show_text(tr(tooltip_text))

func _select_filter(filter_type: FilterType) -> void:
	selected_filter = filter_type
	food_button.button_pressed = filter_type == FilterType.FOOD
	wood_button.button_pressed = filter_type == FilterType.WOOD
	stone_button.button_pressed = filter_type == FilterType.STONE
	iron_button.button_pressed = filter_type == FilterType.IRON
	gold_button.button_pressed = filter_type == FilterType.GOLD
	population_button.button_pressed = filter_type == FilterType.POPULATION
	level_button.button_pressed = filter_type == FilterType.REGION_LEVEL
	search_ore_button.button_pressed = filter_type == FilterType.SEARCH_ORE
	_apply_filter_overlay()

func _apply_filter_overlay() -> void:
	var population_range: Vector2i = _get_population_range()
	for region_node in map_generator.region_container_by_id.values():
		var region: Region = region_node as Region
		if region.is_ocean_region():
			continue
		var overlay: Polygon2D = region.get_node("OwnershipOverlay") as Polygon2D
		var owner_id: int = region_manager.get_region_owner(region.get_region_id())
		var overlay_color: Color = _get_filter_overlay_color(owner_id)
		if player_only and owner_id != game_manager.current_player:
			overlay_color.a = 0.0
			overlay.color = overlay_color
			continue
		overlay_color.a = _get_filter_alpha(region, population_range)
		overlay.color = overlay_color

func _get_filter_overlay_color(owner_id: int) -> Color:
	if not show_ownership or owner_id <= 0:
		return NEUTRAL_RESOURCE_COLOR
	var player_color: Color = GameParameters.get_player_color(owner_id)
	return Color(player_color.r, player_color.g, player_color.b, 1.0)

func _get_filter_alpha(region: Region, population_range: Vector2i) -> float:
	match selected_filter:
		FilterType.FOOD:
			return _get_resource_alpha(region, ResourcesEnum.Type.FOOD)
		FilterType.WOOD:
			return _get_resource_alpha(region, ResourcesEnum.Type.WOOD)
		FilterType.STONE:
			return _get_resource_alpha(region, ResourcesEnum.Type.STONE)
		FilterType.IRON:
			return _get_resource_alpha(region, ResourcesEnum.Type.IRON)
		FilterType.GOLD:
			return _get_resource_alpha(region, ResourcesEnum.Type.GOLD)
		FilterType.POPULATION:
			return _get_population_alpha(region, population_range)
		FilterType.REGION_LEVEL:
			return _get_region_level_alpha(region)
		FilterType.SEARCH_ORE:
			return _get_search_ore_alpha(region)
	return RESOURCE_ALPHA_ZERO

func _get_resource_alpha(region: Region, resource_type: ResourcesEnum.Type) -> float:
	if (resource_type == ResourcesEnum.Type.IRON or resource_type == ResourcesEnum.Type.GOLD) and not region.has_discovered_ore(resource_type):
		return RESOURCE_VALUE_ALPHA_ZERO
	var resource_amount: int = region.get_base_resource_amount(resource_type)
	if include_level_bonus:
		resource_amount = region.get_resource_amount(resource_type)
	if resource_amount <= 0:
		return RESOURCE_VALUE_ALPHA_ZERO
	var maximum_amount: int = _get_resource_maximum(resource_type)
	var progress: float = float(resource_amount) / float(maximum_amount)
	return RESOURCE_ALPHA_MAXIMUM * clampf(progress, 0.0, 1.0)

func _get_resource_maximum(resource_type: ResourcesEnum.Type) -> int:
	if include_level_bonus:
		if resource_type == ResourcesEnum.Type.GOLD:
			return 20
		return 8
	match resource_type:
		ResourcesEnum.Type.GOLD:
			return 8
		ResourcesEnum.Type.FOOD, ResourcesEnum.Type.WOOD, ResourcesEnum.Type.STONE, ResourcesEnum.Type.IRON:
			# Fixed global scale: lower-yield biomes still use the full 0-3 range.
			return 3
	return 1

func _get_population_range() -> Vector2i:
	var minimum_population: int = 0
	var maximum_population: int = 0
	var has_land_region: bool = false
	for region_node in map_generator.region_container_by_id.values():
		var region: Region = region_node as Region
		if region.is_ocean_region():
			continue
		var population: int = region.get_population()
		if not has_land_region:
			minimum_population = population
			maximum_population = population
			has_land_region = true
			continue
		minimum_population = mini(minimum_population, population)
		maximum_population = maxi(maximum_population, population)
	return Vector2i(minimum_population, maximum_population)

func _get_population_alpha(region: Region, population_range: Vector2i) -> float:
	if population_range.x == population_range.y:
		return DATA_ALPHA_MAXIMUM
	var progress: float = float(region.get_population() - population_range.x) / float(population_range.y - population_range.x)
	return lerpf(DATA_ALPHA_MINIMUM, DATA_ALPHA_MAXIMUM, clampf(progress, 0.0, 1.0))

func _get_region_level_alpha(region: Region) -> float:
	var level: int = RegionLevelEnum.level_to_number(region.get_region_level())
	match level:
		1:
			return 0.2
		2:
			return 0.37
		3:
			return 0.54
		4:
			return 0.71
		5:
			return 0.88
	return 0.2

func _get_search_ore_alpha(region: Region) -> float:
	if region.get_ore_search_attempts_remaining() > 0 and region.get_discovered_ores().is_empty():
		return RESOURCE_ALPHA_MAXIMUM
	return RESOURCE_ALPHA_ZERO

func _restore_ownership_overlay_alpha() -> void:
	for region_node in map_generator.region_container_by_id.values():
		var region: Region = region_node as Region
		if region.is_ocean_region():
			continue
		var overlay: Polygon2D = region.get_node("OwnershipOverlay") as Polygon2D
		var owner_id: int = region_manager.get_region_owner(region.get_region_id())
		if owner_id > 0:
			var player_color: Color = GameParameters.get_player_color(owner_id)
			overlay.color = Color(player_color.r, player_color.g, player_color.b, OWNERSHIP_ALPHA_DEFAULT)
		else:
			overlay.color = Color(0.0, 0.0, 0.0, 0.0)
