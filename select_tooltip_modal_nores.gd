extends Control
class_name SelectTooltipModalNoRes

const DEFAULT_TEXT = "No information available."
const SELECT_TOOLTIP_SCRIPT = preload("res://select_tooltip_modal.gd")

@onready var tooltip_label: Label = $TooltipLabel

func _ready():
	visible = false

func show_tooltip(tooltip_key: String, context_data: Dictionary = {}) -> void:
	var key = String(tooltip_key).to_lower()
	var tooltip_text = SELECT_TOOLTIP_SCRIPT.TOOLTIP_TEXTS.get(key, DEFAULT_TEXT)
	tooltip_label.text = tooltip_text
	visible = true

func hide_tooltip() -> void:
	visible = false
