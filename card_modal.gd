extends Control
class_name CardModal

signal continued

const LEVEL_1_TEXTURE: Texture2D = preload("res://images/level1.png")
const LEVEL_2_TEXTURE: Texture2D = preload("res://images/level2.png")
const LEVEL_3_TEXTURE: Texture2D = preload("res://images/level3.png")
const LEVEL_LOCKED_TEXTURE: Texture2D = preload("res://images/level_locked.png")

@onready var title_label: Label = get_node("PanelRoot/Content/Title") as Label
@onready var upgrade_card: UpgradeCard = get_node("PanelRoot/Content/CardCenter/UpgradeCard") as UpgradeCard
@onready var continue_button: Button = get_node("PanelRoot/Content/ButtonRow/ContinueButton") as Button
@onready var ui_manager: UIManager = get_node("../UIManager") as UIManager

func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue_pressed)

func show_unlocked_card(card_config: Dictionary, level: int) -> void:
	show_card(card_config, level, false)

func show_level_up_card(card_config: Dictionary, level: int) -> void:
	show_card(card_config, level, true)

func show_card(card_config: Dictionary, level: int, level_up: bool) -> void:
	_hide_other_modals()
	title_label.text = tr("Card Level Up") if level_up else tr("Card Unlocked")
	_apply_card_config(card_config)
	_apply_level(level)
	visible = true
	ui_manager.set_modal_active(true)
	move_to_front()

func _apply_card_config(card_config: Dictionary) -> void:
	upgrade_card.card_texture_path = String(card_config.get("card_texture_path", upgrade_card.card_texture_path))
	upgrade_card.title_key = String(card_config.get("title_key", upgrade_card.title_key))
	upgrade_card.icon_texture_path = String(card_config.get("icon_texture_path", upgrade_card.icon_texture_path))
	upgrade_card.icon_offset_left = float(card_config.get("icon_offset_left", upgrade_card.icon_offset_left))
	upgrade_card.icon_offset_top = float(card_config.get("icon_offset_top", upgrade_card.icon_offset_top))
	upgrade_card.icon_offset_right = float(card_config.get("icon_offset_right", upgrade_card.icon_offset_right))
	upgrade_card.icon_offset_bottom = float(card_config.get("icon_offset_bottom", upgrade_card.icon_offset_bottom))
	upgrade_card.icon_scale_value = Vector2(
		float(card_config.get("icon_scale_x", upgrade_card.icon_scale_value.x)),
		float(card_config.get("icon_scale_y", upgrade_card.icon_scale_value.y))
	)
	upgrade_card.description_key = String(card_config.get("description_key", upgrade_card.description_key))
	upgrade_card.apply_configuration()
	(upgrade_card.get_node("CardIcon") as TextureRect).visible = true
	(upgrade_card.get_node("CardText") as RichTextLabel).visible = true
	(upgrade_card.get_node("Lock") as TextureRect).visible = false
	if card_config.has("amount"):
		var description_text: String = tr(upgrade_card.description_key).replace("{amount}", str(int(card_config.get("amount", 0))))
		(upgrade_card.get_node("CardText") as RichTextLabel).text = description_text

func _apply_level(level: int) -> void:
	var visible_level: int = clampi(level, 1, 3)
	for index: int in range(3):
		var level_node: TextureRect = upgrade_card.get_node("Level" + str(index + 1)) as TextureRect
		if index < visible_level:
			level_node.texture = _get_level_texture(index + 1)
		else:
			level_node.texture = LEVEL_LOCKED_TEXTURE

func _get_level_texture(level: int) -> Texture2D:
	match level:
		1:
			return LEVEL_1_TEXTURE
		2:
			return LEVEL_2_TEXTURE
		_:
			return LEVEL_3_TEXTURE

func _hide_other_modals() -> void:
	var main_scene: Node = get_tree().current_scene
	var ui_root: Node = main_scene.get_node("UI")
	for child: Node in ui_root.get_children():
		if child == self:
			continue
		if child is Control and _is_modal_node(child):
			(child as Control).visible = false

func _is_modal_node(node: Node) -> bool:
	var node_name: String = node.name
	return node_name.contains("Modal") or node_name.contains("Tooltip") or node_name == "Options"

func _on_continue_pressed() -> void:
	visible = false
	ui_manager.set_modal_active(false)
	continued.emit()
