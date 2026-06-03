extends Control
class_name SelectTooltipModalUpkeep

const DEFAULT_TEXT = "No information available."
const SELECT_TOOLTIP_SCRIPT = preload("res://select_tooltip_modal.gd")

@onready var tooltip_label: Label = get_node("MarginContainer/CostContainer/TooltipLabel") as Label
@onready var castle_section: HBoxContainer = get_node("MarginContainer/CostContainer/Castle") as HBoxContainer
@onready var region_section: HBoxContainer = get_node("MarginContainer/CostContainer/Region") as HBoxContainer
@onready var castle_wood_icon: TextureRect = get_node("MarginContainer/CostContainer/Castle/ValuesSection2/Images/WoodIcon") as TextureRect
@onready var castle_wood_value: Label = get_node("MarginContainer/CostContainer/Castle/ValuesSection2/Values/WoodValue") as Label
@onready var castle_stone_icon: TextureRect = get_node("MarginContainer/CostContainer/Castle/ValuesSection2/Images/StoneIcon") as TextureRect
@onready var castle_stone_value: Label = get_node("MarginContainer/CostContainer/Castle/ValuesSection2/Values/StoneValue") as Label
@onready var castle_time_value: Label = get_node("MarginContainer/CostContainer/Castle/ValuesSection/Values/TimeValue") as Label
@onready var region_food_icon: TextureRect = get_node("MarginContainer/CostContainer/Region/ValuesSection2/Images/FoodIcon") as TextureRect
@onready var region_food_value: Label = get_node("MarginContainer/CostContainer/Region/ValuesSection2/Values/FoodValue") as Label
@onready var region_wood_icon: TextureRect = get_node("MarginContainer/CostContainer/Region/ValuesSection2/Images/WoodIcon") as TextureRect
@onready var region_wood_value: Label = get_node("MarginContainer/CostContainer/Region/ValuesSection2/Values/WoodValue") as Label
@onready var region_stone_icon: TextureRect = get_node("MarginContainer/CostContainer/Region/ValuesSection2/Images/StoneIcon") as TextureRect
@onready var region_stone_value: Label = get_node("MarginContainer/CostContainer/Region/ValuesSection2/Values/StoneValue") as Label

func show_region_upkeep(tooltip_key: String, upkeep_cost: Dictionary) -> void:
	tooltip_label.text = _get_tooltip_text(tooltip_key)
	castle_section.visible = false
	region_section.visible = true
	_set_resource_visibility(region_food_icon, region_food_value, int(upkeep_cost.get(ResourcesEnum.Type.FOOD, 0)))
	_set_resource_visibility(region_wood_icon, region_wood_value, int(upkeep_cost.get(ResourcesEnum.Type.WOOD, 0)))
	_set_resource_visibility(region_stone_icon, region_stone_value, int(upkeep_cost.get(ResourcesEnum.Type.STONE, 0)))
	visible = true

func show_castle_upkeep(tooltip_key: String, wood_upkeep: int, stone_upkeep: int, build_time: int) -> void:
	tooltip_label.text = _get_tooltip_text(tooltip_key)
	castle_section.visible = true
	region_section.visible = false
	_set_resource_visibility(castle_wood_icon, castle_wood_value, wood_upkeep)
	_set_resource_visibility(castle_stone_icon, castle_stone_value, stone_upkeep)
	castle_time_value.text = str(build_time)
	visible = true

func hide_tooltip() -> void:
	visible = false

func _get_tooltip_text(tooltip_key: String) -> String:
	var key: String = String(tooltip_key).to_lower()
	return tr(SELECT_TOOLTIP_SCRIPT.TOOLTIP_TEXTS.get(key, DEFAULT_TEXT))

func _set_resource_visibility(icon: TextureRect, value_label: Label, amount: int) -> void:
	var has_cost: bool = amount > 0
	icon.visible = has_cost
	value_label.visible = has_cost
	value_label.text = str(amount)
