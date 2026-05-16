extends Control
class_name GameGuideModal

signal closed

const SECTION_REGIONS: String = "regions"
const SECTION_ECONOMY: String = "economy"
const SECTION_RECRUITMENT: String = "recruitment"
const SECTION_BATTLES: String = "battles"
const SECTION_TIPS: String = "tips"

const GUIDE_FILES_BY_LOCALE: Dictionary = {
	"en": {
		SECTION_REGIONS: "res://translations/game_guide/sections/game_guide.en.regions.bbcode",
		SECTION_ECONOMY: "res://translations/game_guide/sections/game_guide.en.economy.bbcode",
		SECTION_RECRUITMENT: "res://translations/game_guide/sections/game_guide.en.recruitment.bbcode",
		SECTION_BATTLES: "res://translations/game_guide/sections/game_guide.en.battles.bbcode",
		SECTION_TIPS: "res://translations/game_guide/sections/game_guide.en.tips.bbcode"
	},
	"de": {
		SECTION_REGIONS: "res://translations/game_guide/sections/game_guide.de.regions.bbcode",
		SECTION_ECONOMY: "res://translations/game_guide/sections/game_guide.de.economy.bbcode",
		SECTION_RECRUITMENT: "res://translations/game_guide/sections/game_guide.de.recruitment.bbcode",
		SECTION_BATTLES: "res://translations/game_guide/sections/game_guide.de.battles.bbcode",
		SECTION_TIPS: "res://translations/game_guide/sections/game_guide.de.tips.bbcode"
	},
	"pl": {
		SECTION_REGIONS: "res://translations/game_guide/sections/game_guide.pl.regions.bbcode",
		SECTION_ECONOMY: "res://translations/game_guide/sections/game_guide.pl.economy.bbcode",
		SECTION_RECRUITMENT: "res://translations/game_guide/sections/game_guide.pl.recruitment.bbcode",
		SECTION_BATTLES: "res://translations/game_guide/sections/game_guide.pl.battles.bbcode",
		SECTION_TIPS: "res://translations/game_guide/sections/game_guide.pl.tips.bbcode"
	},
	"br": {
		SECTION_REGIONS: "res://translations/game_guide/sections/game_guide.br.regions.bbcode",
		SECTION_ECONOMY: "res://translations/game_guide/sections/game_guide.br.economy.bbcode",
		SECTION_RECRUITMENT: "res://translations/game_guide/sections/game_guide.br.recruitment.bbcode",
		SECTION_BATTLES: "res://translations/game_guide/sections/game_guide.br.battles.bbcode",
		SECTION_TIPS: "res://translations/game_guide/sections/game_guide.br.tips.bbcode"
	}
}
const FALLBACK_LOCALE: String = "en"
const FALLBACK_SECTION: String = SECTION_REGIONS

@onready var ui_manager: UIManager = get_node("../UIManager") as UIManager
@onready var sound_manager: SoundManager = get_node("../../SoundManager") as SoundManager
@onready var continue_button: Button = get_node("PanelRoot/ContentContainer/ContinueButton") as Button
@onready var guide_scroll: ScrollContainer = get_node("PanelRoot/ContentContainer/MessageScroll") as ScrollContainer
@onready var guide_rich_text: RichTextLabel = get_node("PanelRoot/ContentContainer/MessageScroll/GuideRichText") as RichTextLabel

func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.text = tr("Continue")
	guide_rich_text.bbcode_enabled = true

func show_modal() -> void:
	show_modal_for_section(FALLBACK_SECTION)

func show_modal_for_section(section_id: String) -> void:
	_load_localized_section(section_id)
	guide_scroll.scroll_vertical = 0
	move_to_front()
	visible = true
	ui_manager.set_modal_active(true)

func hide_modal() -> void:
	visible = false
	ui_manager.set_modal_active(false)

func close_modal() -> void:
	hide_modal()
	closed.emit()

func _on_continue_pressed() -> void:
	sound_manager.click_sound()
	close_modal()

func _resolve_locale_key() -> String:
	var locale: String = TranslationServer.get_locale().to_lower()
	if locale.begins_with("de"):
		return "de"
	if locale.begins_with("pl"):
		return "pl"
	if locale.begins_with("br") or locale.begins_with("pt"):
		return "br"
	return FALLBACK_LOCALE

func _resolve_section_file_path(section_id: String) -> String:
	var locale_key: String = _resolve_locale_key()
	var locale_paths: Dictionary = GUIDE_FILES_BY_LOCALE[locale_key] as Dictionary
	if not locale_paths.has(section_id):
		return String(locale_paths[FALLBACK_SECTION])
	return String(locale_paths[section_id])

func _load_localized_section(section_id: String) -> void:
	var section_path: String = _resolve_section_file_path(section_id)
	var guide_text: String = FileAccess.get_file_as_string(section_path)
	guide_rich_text.text = guide_text
