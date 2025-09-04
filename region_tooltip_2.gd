extends Control
class_name RegionTooltip2

const MOUSE_OFFSET = Vector2(20, 20)

# UI element references
@onready var region_name_label: Label = $Panel/Army/HeaderSection/RegionName

# Icon references
@onready var population_icon: TextureRect = $Panel/Army/ValuesSection/Images/PopulationIcon
@onready var food_icon: TextureRect = $Panel/Army/ValuesSection/Images/FoodIcon
@onready var wood_icon: TextureRect = $Panel/Army/ValuesSection/Images/WoodIcon
@onready var stone_icon: TextureRect = $Panel/Army/ValuesSection/Images/StoneIcon
@onready var iron_icon: TextureRect = $Panel/Army/ValuesSection/Images/IronIcon
@onready var gold_icon: TextureRect = $Panel/Army/ValuesSection/Images/GoldIcon

# Value label references
@onready var population_value: Label = $Panel/Army/ValuesSection/Values/PopulationValue
@onready var food_value: Label = $Panel/Army/ValuesSection/Values/FoodValue
@onready var wood_value: Label = $Panel/Army/ValuesSection/Values/WoodValue
@onready var stone_value: Label = $Panel/Army/ValuesSection/Values/StoneValue
@onready var iron_value: Label = $Panel/Army/ValuesSection/Values/IronValue
@onready var gold_value: Label = $Panel/Army/ValuesSection/Values/GoldValue

@onready var texture_rect: TextureRect = $TextureRect
@onready var panel: Panel = $Panel

var current_region: Region = null
var is_debug_mode: bool = false

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set initial size
	custom_minimum_size = Vector2(240, 145)
	size = Vector2(240, 145)

func show_region_tooltip(region: Region, mouse_pos: Vector2):
	"""Show tooltip for the given region at mouse position"""
	if region == null:
		hide_tooltip()
		return
	
	current_region = region
	
	# Update region name with level (e.g., "Shire of Hornhold")
	var region_level = region.get_region_level()
	var level_text = RegionLevelEnum.level_to_string(region_level)
	region_name_label.text = level_text + " of " + region.get_region_name()
	
	# Update population
	population_value.text = str(region.get_population())
	
	# Update resource displays using existing labels
	_update_resource_displays(region)
	
	# Position at mouse with offset
	position = mouse_pos + MOUSE_OFFSET
	_clamp_to_screen()
	
	visible = true

func hide_tooltip():
	"""Hide the tooltip"""
	visible = false
	current_region = null

func update_position(mouse_pos: Vector2):
	"""Update tooltip position when mouse moves"""
	if visible:
		position = mouse_pos + MOUSE_OFFSET
		_clamp_to_screen()

func _update_resource_displays(region: Region):
	"""Update icons and values based on region resources"""
	# Population is always shown
	population_icon.visible = true
	population_value.visible = true
	
	# Check food
	var food_amount = region.get_resource_amount(ResourcesEnum.Type.FOOD)
	if food_amount > 0:
		food_icon.visible = true
		food_value.visible = true
		food_value.text = str(food_amount)
	else:
		food_icon.visible = false
		food_value.visible = false
	
	# Check wood
	var wood_amount = region.get_resource_amount(ResourcesEnum.Type.WOOD)
	if wood_amount > 0:
		wood_icon.visible = true
		wood_value.visible = true
		wood_value.text = str(wood_amount)
	else:
		wood_icon.visible = false
		wood_value.visible = false
	
	# Check stone
	var stone_amount = region.get_resource_amount(ResourcesEnum.Type.STONE)
	if stone_amount > 0:
		stone_icon.visible = true
		stone_value.visible = true
		stone_value.text = str(stone_amount)
	else:
		stone_icon.visible = false
		stone_value.visible = false
	
	# Check iron (only show if discovered)
	var iron_amount = region.get_resource_amount(ResourcesEnum.Type.IRON)
	if iron_amount > 0 and region.has_discovered_ore(ResourcesEnum.Type.IRON):
		iron_icon.visible = true
		iron_value.visible = true
		iron_value.text = str(iron_amount)
	else:
		iron_icon.visible = false
		iron_value.visible = false
	
	# Check gold (only show if discovered)
	var gold_amount = region.get_resource_amount(ResourcesEnum.Type.GOLD)
	if gold_amount > 0 and region.has_discovered_ore(ResourcesEnum.Type.GOLD):
		gold_icon.visible = true
		gold_value.visible = true
		gold_value.text = str(gold_amount)
	else:
		gold_icon.visible = false
		gold_value.visible = false

func _clamp_to_screen():
	"""Keep tooltip within screen bounds"""
	var screen_size = get_viewport().get_visible_rect().size
	
	# Adjust position if tooltip would go off-screen
	if position.x + size.x > screen_size.x:
		position.x = screen_size.x - size.x - 10
	if position.y + size.y > screen_size.y:
		position.y = screen_size.y - size.y - 10
	
	# Ensure it doesn't go negative
	position.x = max(10, position.x)
	position.y = max(10, position.y)

# These functions are needed for compatibility with the old interface
# but will only show debug info if debug mode is enabled
func _get_debug_info(region: Region) -> String:
	if not is_debug_mode:
		return ""
	# Debug info not implemented in new tooltip
	return ""

func _set_debug_font():
	pass

func _reset_font():
	pass
