extends Control
class_name SelectTooltipModalNoRes

const DEFAULT_TEXT = "No information available."
const SELECT_TOOLTIP_SCRIPT = preload("res://select_tooltip_modal.gd")

@onready var tooltip_label: Label = $TooltipLabel

func _ready():
	visible = false

func show_tooltip(tooltip_key: String, context_data: Dictionary = {}) -> void:
	var key = String(tooltip_key).to_lower()
	var tooltip_text = tr(SELECT_TOOLTIP_SCRIPT.TOOLTIP_TEXTS.get(key, DEFAULT_TEXT))
	
	if tooltip_key == "ore_search" and context_data.has("current_region"):
		var current_region = context_data["current_region"]
		if current_region != null:
			var discovered_ores = current_region.get_discovered_ores()
			if not discovered_ores.is_empty():
				var ore_messages: Array[String] = []
				for ore_type in discovered_ores:
					var ore_name = ResourcesEnum.type_to_display_string(ore_type).capitalize()
					var ore_amount = current_region.get_resource_amount(ore_type)
					ore_messages.append((tr("%s was discovered") % ore_name) + "\n" + (tr("Mines extract %d units per turn") % ore_amount))
				tooltip_text = "\n\n".join(ore_messages)
	tooltip_label.text = tooltip_text
	visible = true

func hide_tooltip() -> void:
	visible = false

func show_text(text: String) -> void:
	tooltip_label.text = text
	visible = true
