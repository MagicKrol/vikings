extends Control
class_name GameGuideMenuModal

signal back_requested

@onready var header_label: Label = $InnerPanel/HeaderSection/HeaderLabel
@onready var back_button: Button = $InnerPanel/ButtonContainer/ContinueButton
@onready var region_button: Button = $InnerPanel/ButtonContainer/OptionsButton
@onready var economy_button: Button = $InnerPanel/ButtonContainer/SaveGameButton
@onready var recruitment_button: Button = $InnerPanel/ButtonContainer/MainMenuButton
@onready var battles_button: Button = $InnerPanel/ButtonContainer/Help
@onready var tips_button: Button = $InnerPanel/ButtonContainer/ExitButton
@onready var game_guide_modal: GameGuideModal = get_node("../GameGuideModal") as GameGuideModal
@onready var sound_manager: SoundManager = get_node("../../SoundManager") as SoundManager
@onready var ui_manager: UIManager = get_node("../UIManager") as UIManager

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	header_label.text = tr("Game Guide")
	back_button.text = tr("Back")
	region_button.text = tr("Region")
	economy_button.text = tr("Economy")
	recruitment_button.text = tr("Recruitment")
	battles_button.text = tr("Battles")
	tips_button.text = tr("Tips")
	back_button.pressed.connect(_on_back_pressed)
	region_button.pressed.connect(_on_region_pressed)
	economy_button.pressed.connect(_on_economy_pressed)
	recruitment_button.pressed.connect(_on_recruitment_pressed)
	battles_button.pressed.connect(_on_battles_pressed)
	tips_button.pressed.connect(_on_tips_pressed)
	game_guide_modal.closed.connect(_on_game_guide_closed)

func show_modal() -> void:
	visible = true
	move_to_front()
	ui_manager.set_modal_active(true)

func hide_modal() -> void:
	visible = false
	ui_manager.set_modal_active(false)

func close_modal() -> void:
	hide_modal()
	back_requested.emit()

func _open_section(section_id: String) -> void:
	sound_manager.click_sound()
	visible = false
	game_guide_modal.show_modal_for_section(section_id)

func _on_back_pressed() -> void:
	sound_manager.click_sound()
	close_modal()

func _on_region_pressed() -> void:
	_open_section(GameGuideModal.SECTION_REGIONS)

func _on_economy_pressed() -> void:
	_open_section(GameGuideModal.SECTION_ECONOMY)

func _on_recruitment_pressed() -> void:
	_open_section(GameGuideModal.SECTION_RECRUITMENT)

func _on_battles_pressed() -> void:
	_open_section(GameGuideModal.SECTION_BATTLES)

func _on_tips_pressed() -> void:
	_open_section(GameGuideModal.SECTION_TIPS)

func _on_game_guide_closed() -> void:
	visible = true
	move_to_front()
	ui_manager.set_modal_active(true)
