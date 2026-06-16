extends Control
class_name UpgradeCard

@export var card_texture_path: String = "res://images/card_green.png"
@export var title_key: String = "upgrade_card_food_title"
@export var icon_texture_path: String = "res://images/icons/new_food.png"
@export var icon_offset_left: float = 90.0
@export var icon_offset_top: float = 54.0
@export var icon_offset_right: float = 290.0
@export var icon_offset_bottom: float = 254.0
@export var icon_scale_value: Vector2 = Vector2(0.34, 0.34)
@export var description_key: String = "upgrade_card_food_desc"

@onready var card_texture_node: TextureRect = get_node("CardTexture") as TextureRect
@onready var card_title_label: Label = get_node("CardTitle") as Label
@onready var card_icon: TextureRect = get_node("CardIcon") as TextureRect
@onready var card_text: RichTextLabel = get_node("CardText") as RichTextLabel

func _ready() -> void:
	apply_configuration()

func apply_configuration() -> void:
	card_texture_node.texture = load(card_texture_path) as Texture2D
	card_title_label.text = title_key
	card_icon.texture = load(icon_texture_path) as Texture2D
	card_icon.offset_left = icon_offset_left
	card_icon.offset_top = icon_offset_top
	card_icon.offset_right = icon_offset_right
	card_icon.offset_bottom = icon_offset_bottom
	card_icon.scale = icon_scale_value
	card_text.text = description_key
