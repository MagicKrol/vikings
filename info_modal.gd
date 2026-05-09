extends Control
class_name InfoModal
signal closed_info_modal

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
var select_tooltip_modal: SelectTooltipModal = null
var select_tooltip_modal_nores: SelectTooltipModalNoRes = null
var tutorial_manager: TutorialManager = null

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
const ACTION_TOOLTIP_X: float = 550.0
const ACTION_TOOLTIP_BASE_Y: float = 175.0
const GARRISON_UNIT_NODE_NAMES: Array[String] = [
	"Peasants", "Spearmen", "Archers", "Swordsmen",
	"Horsemen", "Crossbowmen", "Knights", "MountedKnights", "RoyalGuard"
]
const GARRISON_UNIT_TYPES: Array[SoldierTypeEnum.Type] = [
	SoldierTypeEnum.Type.PEASANTS, SoldierTypeEnum.Type.SPEARMEN,
	SoldierTypeEnum.Type.ARCHERS, SoldierTypeEnum.Type.SWORDSMEN,
	SoldierTypeEnum.Type.HORSEMEN, SoldierTypeEnum.Type.CROSSBOWMEN,
	SoldierTypeEnum.Type.KNIGHTS, SoldierTypeEnum.Type.MOUNTED_KNIGHTS,
	SoldierTypeEnum.Type.ROYAL_GUARD
]

var _progress_style_green: StyleBoxTexture
var _progress_style_yellow: StyleBoxTexture
var _progress_style_red: StyleBoxTexture
var _army_card_style_default: StyleBoxTexture
var _army_card_style_hover: StyleBoxTexture
var _army_card_armies: Array[Army] = []
var _army_card_labels: Array[Label] = []
var _army_card_label_colors: Array[Color] = []
var _suppress_auto_select: bool = false
var _action_tooltip_base_pos_nores: Vector2 = Vector2.ZERO
var _action_tooltip_base_button_y: float = 0.0
var _action_tooltip_base_nores_ready: bool = false
var _action_tooltip_base_button_ready: bool = false
var _spawn_event_armies_only_mode: bool = false

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
@onready var _region_level_action_section: Control = get_node("RegionPanel/Body/Region/Actions/RegionLevel/ActionSection")
@onready var _castle_level_action_section: Control = get_node("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection")
@onready var _mine_action_section: Control = get_node("RegionPanel/Body/Region/Actions/Mine/ActionSection")
@onready var _raise_army_action_section: Control = get_node("RegionPanel/Body/Region/Actions/RaiseArmy/ActionSection")
@onready var _garrison_action_section: Control = get_node("RegionPanel/Body/Region/Actions/Garrison/VBoxContainer3/HBoxContainer/ActionSection")
@onready var _region_garrison_info: Control = get_node("RegionPanel/Body/Region/DefendersSection/GarrisonInfo") as Control
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
	select_tooltip_modal = get_node("../SelectTooltipModal") as SelectTooltipModal
	select_tooltip_modal_nores = get_node("../SelectTooltipModalNoRes") as SelectTooltipModalNoRes
	tutorial_manager = game_manager.get_tutorial_manager()
	army_manager = game_manager.get_army_manager()
	region_manager = game_manager.get_region_manager()
	_initialize_progress_bar_styles()
	_initialize_tabs()
	_initialize_army_cards()
	_initialize_region_actions()
	_initialize_action_tooltips()
	_initialize_garrison_unit_tooltips()
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

func _initialize_action_tooltips() -> void:
	_promote_button.mouse_entered.connect(_on_promote_tooltip_hovered)
	_promote_button.mouse_exited.connect(_on_action_tooltip_unhovered)
	_build_button.mouse_entered.connect(_on_castle_tooltip_hovered)
	_build_button.mouse_exited.connect(_on_action_tooltip_unhovered)
	_search_ore_button.mouse_entered.connect(_on_ore_search_tooltip_hovered)
	_search_ore_button.mouse_exited.connect(_on_action_tooltip_unhovered)
	_raise_army_button.mouse_entered.connect(_on_raise_army_tooltip_hovered)
	_raise_army_button.mouse_exited.connect(_on_action_tooltip_unhovered)
	_recruit_button.mouse_entered.connect(_on_recruit_garrison_tooltip_hovered)
	_recruit_button.mouse_exited.connect(_on_action_tooltip_unhovered)

func _initialize_garrison_unit_tooltips() -> void:
	_connect_garrison_info_unit_tooltips(_region_garrison_info)
	for card in _army_cards:
		var garrison_info: Control = card.get_node(NodePath(str(card.name) + "/GarrisonInfo")) as Control
		_connect_garrison_info_unit_tooltips(garrison_info)

func _connect_garrison_info_unit_tooltips(garrison_info: Control) -> void:
	for i in range(GARRISON_UNIT_NODE_NAMES.size()):
		var icon: TextureRect = garrison_info.get_node(NodePath(GARRISON_UNIT_NODE_NAMES[i] + "/TextureRect")) as TextureRect
		icon.mouse_entered.connect(Callable(self, "_on_garrison_unit_icon_hovered").bind(i, garrison_info))
		icon.mouse_exited.connect(_on_action_tooltip_unhovered)

func _set_cursor_shape_recursive(node: Node, shape: int) -> void:
	if node is Control:
		var control_node := node as Control
		control_node.mouse_default_cursor_shape = shape
	for child in node.get_children():
		_set_cursor_shape_recursive(child, shape)

func _on_promote_tooltip_hovered() -> void:
	var context_data = {"current_region": current_region}
	_cache_action_tooltip_base()
	_show_message_action_tooltip(_get_region_action_tooltip_key("promote_region"), context_data, _promote_button)

func _on_castle_tooltip_hovered() -> void:
	var tooltip_key: String = _get_castle_tooltip_key()
	var region_tooltip_key: String = _get_region_action_tooltip_key(tooltip_key)
	var context_data: Dictionary = {"current_region": current_region}
	if region_tooltip_key == "build_castle" or region_tooltip_key == "upgrade_castle":
		context_data["show_turns_only"] = true
		_show_turns_action_tooltip(region_tooltip_key, context_data, _build_button)
		return
	_show_message_action_tooltip(region_tooltip_key, context_data, _build_button)

func _on_ore_search_tooltip_hovered() -> void:
	var context_data = {"current_region": current_region}
	_show_message_action_tooltip(_get_region_action_tooltip_key("ore_search"), context_data, _search_ore_button)

func _on_raise_army_tooltip_hovered() -> void:
	var context_data = {
		"current_region": current_region,
		"army_capacity_available": _region_has_army_capacity(),
		"raise_used": current_region.has_raised_army_this_turn()
	}
	_show_message_action_tooltip(_get_region_action_tooltip_key("raise_army"), context_data, _raise_army_button)

func _on_recruit_garrison_tooltip_hovered() -> void:
	_show_message_action_tooltip(_get_region_action_tooltip_key("recruit_soldiers_garrison"), {}, _recruit_button)

func _on_action_tooltip_unhovered() -> void:
	_hide_action_tooltips()

func _show_message_action_tooltip(tooltip_key: String, context_data: Dictionary, button: Control) -> void:
	select_tooltip_modal.hide_tooltip()
	_position_action_tooltip(select_tooltip_modal_nores, button)
	select_tooltip_modal_nores.show_tooltip(tooltip_key, context_data)

func _show_turns_action_tooltip(tooltip_key: String, context_data: Dictionary, button: Control) -> void:
	select_tooltip_modal_nores.hide_tooltip()
	_position_action_tooltip(select_tooltip_modal, button)
	select_tooltip_modal.show_tooltip(tooltip_key, context_data)

func _on_garrison_unit_icon_hovered(unit_index: int, garrison_info: Control) -> void:
	var unit_type: SoldierTypeEnum.Type = GARRISON_UNIT_TYPES[unit_index]
	var unit_name: String = SoldierTypeEnum.type_to_display_string(unit_type)
	_show_garrison_unit_action_tooltip(unit_name, garrison_info)

func _show_garrison_unit_action_tooltip(unit_name: String, garrison_info: Control) -> void:
	select_tooltip_modal.hide_tooltip()
	_position_action_tooltip_at_garrison(select_tooltip_modal_nores, garrison_info)
	select_tooltip_modal_nores.show_text(unit_name)

func _hide_action_tooltips() -> void:
	select_tooltip_modal.hide_tooltip()
	select_tooltip_modal_nores.hide_tooltip()

func _cache_action_tooltip_base() -> void:
	if not _action_tooltip_base_button_ready:
		_action_tooltip_base_button_y = _promote_button.global_position.y
		_action_tooltip_base_button_ready = true
	if not _action_tooltip_base_nores_ready:
		_action_tooltip_base_pos_nores = Vector2(ACTION_TOOLTIP_X, ACTION_TOOLTIP_BASE_Y)
		_action_tooltip_base_nores_ready = true

func _position_action_tooltip(tooltip: Control, button: Control) -> void:
	if not _action_tooltip_base_button_ready or not _action_tooltip_base_nores_ready:
		_cache_action_tooltip_base()
	var base_y: float = _action_tooltip_base_pos_nores.y
	var delta_y: float = button.global_position.y - _action_tooltip_base_button_y
	tooltip.global_position = Vector2(ACTION_TOOLTIP_X, base_y + delta_y)

func _position_action_tooltip_at_garrison(tooltip: Control, garrison_info: Control) -> void:
	tooltip.global_position = Vector2(ACTION_TOOLTIP_X, garrison_info.global_position.y)

func _get_castle_tooltip_key() -> String:
	if current_region.is_castle_under_construction():
		return "castle_construction"
	if current_region.is_castle_under_repair() or current_region.has_castle_damage():
		return "repair_castle"
	if current_region.get_castle_type() == CastleTypeEnum.Type.NONE:
		return "build_castle"
	var next_type: CastleTypeEnum.Type = CastleTypeEnum.get_next_level(current_region.get_castle_type())
	if next_type == CastleTypeEnum.Type.NONE:
		return "castle_max_level"
	return "upgrade_castle"

func _is_region_management_blocked() -> bool:
	return current_region != null and current_region.just_conquered_this_turn

func _get_region_action_tooltip_key(default_key: String) -> String:
	if _is_region_management_blocked():
		return "conquered_region_blocked"
	return default_key

func _apply_conquered_region_action_lock() -> void:
	if not _is_region_management_blocked():
		return
	_promote_button.disabled = true
	_build_button.disabled = true
	_search_ore_button.disabled = true
	_raise_army_button.disabled = true
	_recruit_button.disabled = true

func _is_region_enemy_or_neutral(region: Region) -> bool:
	var owner_id: int = region_manager.get_region_owner(region.get_region_id())
	var current_player_id: int = game_manager.get_current_player_id()
	return owner_id != current_player_id

func _is_region_intel_mode(region: Region) -> bool:
	if game_manager.debug_mode:
		return false
	return _is_region_enemy_or_neutral(region)

func _is_current_region_intel_mode() -> bool:
	if current_region == null:
		return false
	return _is_region_intel_mode(current_region)

func _set_region_action_sections_visible(is_visible: bool) -> void:
	_region_level_action_section.visible = is_visible
	_castle_level_action_section.visible = is_visible
	_raise_army_action_section.visible = is_visible
	_garrison_action_section.visible = is_visible
	if not is_visible:
		_mine_action_section.visible = false

func _apply_region_intel_overrides() -> void:
	var is_intel_mode: bool = _is_current_region_intel_mode()
	if not is_intel_mode:
		_raise_army_action_section.visible = true
		_garrison_action_section.visible = true
		return
	_set_region_action_sections_visible(false)
	var mine_status: Label = get_node("RegionPanel/Body/Region/Actions/Mine/Info/Search/SearchStatus") as Label
	var next_army_name: Label = get_node("RegionPanel/Body/Region/Actions/RaiseArmy/Info/Army/NextArmyName") as Label
	var garrison_men_value: Label = get_node("RegionPanel/Body/Region/Actions/Garrison/VBoxContainer3/HBoxContainer/Info/Men/GarrisonMenValue") as Label
	mine_status.text = ""
	next_army_name.text = ""
	garrison_men_value.text = ""

func _get_selectable_armies(armies: Array[Army]) -> Array[Army]:
	var selectable_armies: Array[Army] = []
	for army in armies:
		if _is_army_selectable_for_current_player(army):
			selectable_armies.append(army)
	return selectable_armies

func _is_army_selectable_for_current_player(army: Army) -> bool:
	return army.get_player_id() == game_manager.get_current_player_id()

func _format_intel_turns_label(turns_ago: int) -> String:
	if turns_ago < 0:
		return "? " + tr("turns")
	return str(turns_ago) + " " + tr("turns")

func _get_enemy_army_intel_composition(army: Army) -> ArmyComposition:
	var observer_id: int = game_manager.get_current_player_id()
	var tracker_key: String = Player.get_enemy_tracker_key(army)
	return player_manager.get_tracked_enemy_army_composition(observer_id, tracker_key)

func _get_enemy_army_intel_wounded_composition(army: Army) -> ArmyComposition:
	var observer_id: int = game_manager.get_current_player_id()
	var tracker_key: String = Player.get_enemy_tracker_key(army)
	return player_manager.get_tracked_enemy_army_wounded_composition(observer_id, tracker_key)

func _get_enemy_garrison_intel_composition() -> ArmyComposition:
	var observer_id: int = game_manager.get_current_player_id()
	return player_manager.get_tracked_enemy_garrison_composition(observer_id, current_region.get_region_id())

func _get_enemy_garrison_intel_wounded_composition() -> ArmyComposition:
	var observer_id: int = game_manager.get_current_player_id()
	return player_manager.get_tracked_enemy_garrison_wounded_composition(observer_id, current_region.get_region_id())

func _set_unknown_unit_value(unit_node: Node) -> void:
	var healthy_node: Control = unit_node.get_node("Healthy") as Control
	var wounded_node: HBoxContainer = unit_node.get_node("Wounded") as HBoxContainer
	var healthy_value: Label = healthy_node.get_node("Value") as Label
	wounded_node.visible = false
	healthy_node.visible = true
	healthy_value.text = "?"
	healthy_value.add_theme_color_override("font_color", Color.WHITE)

func _set_unknown_unit_values(info_root: Node) -> void:
	for unit_name in GARRISON_UNIT_NODE_NAMES:
		var unit_node: Node = info_root.get_node(unit_name)
		_set_unknown_unit_value(unit_node)

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

func show_region_info(region: Region, manage_modal_mode: bool = true, allow_tab_switch: bool = true) -> void:
	"""Show the modal with region information"""
	# Prevent showing during AI/computer turns
	if not _is_human_turn():
		return
	if region == null:
		hide_modal()
		return
	if allow_tab_switch and current_region == region and _active_tab == TabType.REGION:
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
		var selectable_armies: Array[Army] = _get_selectable_armies(armies_in_region)
		current_army = _find_army_with_most_movement_points(selectable_armies)
		if armies_in_region.is_empty():
			_set_active_tab(TabType.REGION)
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
	var was_visible: bool = visible
	DebugLogger.log("click", "InfoModal: hide_modal manage=" + str(manage_modal_mode))
	visible = false
	_hide_action_tooltips()
	
	# Set modal mode inactive only if requested
	if manage_modal_mode and ui_manager:
		ui_manager.set_modal_active(false)
	if was_visible:
		closed_info_modal.emit()

func close_modal() -> void:
	"""Close the modal and clear all content"""
	var was_visible: bool = visible
	DebugLogger.log("click", "InfoModal: close_modal")
	current_army = null
	current_region = null
	current_mode = DisplayMode.NONE
	visible = false
	_hide_action_tooltips()
	
	# Always set modal mode inactive when fully closing
	if ui_manager:
		ui_manager.set_modal_active(false)
	if was_visible:
		closed_info_modal.emit()

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
	var selectable_armies: Array[Army] = _get_selectable_armies(armies)
	var intel_mode: bool = _is_current_region_intel_mode()

	if current_army == null or not armies.has(current_army) or not _is_army_selectable_for_current_player(current_army):
		if not _suppress_auto_select and not intel_mode:
			current_army = _find_army_with_most_movement_points(selectable_armies)
		else:
			current_army = null
	if current_army != null and not _suppress_auto_select and not intel_mode:
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
	var intel_mode: bool = _is_current_region_intel_mode()
	var is_selectable: bool = _is_army_selectable_for_current_player(army)
	var selection_button = card.get_node("SelectionStatus") as Button
	if intel_mode:
		selection_button.disabled = true
		selection_button.theme = BUTTON_DEFAULT_THEME
		var observer_id: int = game_manager.get_current_player_id()
		var tracker_key: String = Player.get_enemy_tracker_key(army)
		var turns_ago: int = player_manager.get_tracked_enemy_army_composition_turns_ago(observer_id, tracker_key)
		selection_button.text = _format_intel_turns_label(turns_ago)
		card.add_theme_stylebox_override("panel", _army_card_style_default)
	elif is_selectable and army == current_army:
		selection_button.disabled = false
		selection_button.theme = BUTTON_GREEN_THEME
		selection_button.text = tr("Selected")
		card.add_theme_stylebox_override("panel", _army_card_style_hover)
	else:
		selection_button.disabled = not is_selectable
		selection_button.theme = BUTTON_DEFAULT_THEME
		selection_button.text = tr("Select")
		card.add_theme_stylebox_override("panel", _army_card_style_default)

	var content = card.get_node(NodePath(str(card.name))) as VBoxContainer
	var army_name_label = content.get_node("HBoxContainer/ArmyName") as Label
	army_name_label.text = tr("Army %s") % army.number

	var move_container = content.get_node("MP/MoveContainer") as HBoxContainer
	if intel_mode:
		_update_move_points_icons(move_container, 0)
	else:
		_update_move_points_icons(move_container, army.get_movement_points())

	var progress_bar = content.get_node("Vigor/ProgressBar") as ProgressBar
	var vigor_value = content.get_node("Vigor/ProgressBar/Value") as Label
	if intel_mode:
		_update_vigor_bar(progress_bar, 0)
		vigor_value.text = "?"
	else:
		var vigor_percent = int(round(army.get_efficiency()))
		_update_vigor_bar(progress_bar, vigor_percent)
		vigor_value.text = str(vigor_percent) + "%"

	var composition: ArmyComposition = army.get_composition()
	var wounded_composition: ArmyComposition = army.get_wounded_composition()
	var has_known_composition: bool = true
	if intel_mode:
		composition = _get_enemy_army_intel_composition(army)
		wounded_composition = _get_enemy_army_intel_wounded_composition(army)
		if composition == null:
			has_known_composition = false
	var info_root = content.get_node("GarrisonInfo")
	if intel_mode and not has_known_composition:
		_set_unknown_unit_values(info_root)
	else:
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
	if not _is_army_selectable_for_current_player(army):
		return
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
	_apply_region_intel_overrides()
	_apply_conquered_region_action_lock()

func _update_region_header() -> void:
	"""Update the region header name"""
	var region_name_label: Label = get_node("RegionPanel/Header/HeaderSection/RegionName")
	var level_text: String = RegionLevelEnum.level_to_display_string(current_region.get_region_level())
	var formatted_name: String = tr("%s of %s") % [level_text, current_region.get_region_name()]
	region_name_label.text = formatted_name

func _update_region_level_section() -> void:
	"""Update region level name/number and promotion cost"""
	var level_label: Label = get_node("RegionPanel/Body/Region/Actions/RegionLevel/VBoxContainer/Label")
	level_label.text = RegionLevelEnum.level_to_display_string(current_region.get_region_level())
	var level_value: Label = get_node("RegionPanel/Body/Region/Actions/RegionLevel/VBoxContainer/Info/RegionLevelValue")
	level_value.text = current_region.get_region_level_number()

	var current_level: RegionLevelEnum.Level = current_region.get_region_level()
	var is_region_max_level: bool = current_level >= RegionLevelEnum.Level.L5
	_region_level_action_section.visible = not is_region_max_level
	var target_level: RegionLevelEnum.Level = current_level
	if current_level < RegionLevelEnum.Level.L5:
		target_level = current_level + 1

	var cost: Dictionary = GameParameters.get_promotion_cost(target_level)
	var gold_cost: int = int(cost.get(ResourcesEnum.Type.GOLD, 0))
	var food_cost: int = int(cost.get(ResourcesEnum.Type.FOOD, 0))
	var wood_cost: int = int(cost.get(ResourcesEnum.Type.WOOD, 0))
	_set_cost_value("RegionPanel/Body/Region/Actions/RegionLevel/ActionSection/Resources/Gold", gold_cost)
	_set_cost_value("RegionPanel/Body/Region/Actions/RegionLevel/ActionSection/Resources/Food", food_cost)
	_set_cost_value("RegionPanel/Body/Region/Actions/RegionLevel/ActionSection/Resources/Wood", wood_cost)
	var promotion_available: bool = not current_region.has_promoted_this_turn()
	var can_afford_promotion: bool = _can_player_afford_promotion(target_level)
	_promote_button.disabled = current_level >= RegionLevelEnum.Level.L5 or not promotion_available or not can_afford_promotion

func _update_castle_section() -> void:
	"""Update castle name, defense, build/repair status, and cost display"""
	var castle_name_label: Label = get_node("RegionPanel/Body/Region/Actions/CastleLevel/Info/CastleLevelName")
	castle_name_label.text = CastleTypeEnum.type_to_display_string(current_region.get_castle_type())

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

	var current_castle_type: CastleTypeEnum.Type = current_region.get_castle_type()
	var next_castle_type: CastleTypeEnum.Type = CastleTypeEnum.get_next_level(current_castle_type)
	var is_castle_max_level: bool = current_castle_type != CastleTypeEnum.Type.NONE and next_castle_type == CastleTypeEnum.Type.NONE
	var should_hide_castle_actions: bool = is_castle_max_level and not current_region.is_castle_under_construction() and not current_region.is_castle_under_repair() and not current_region.has_castle_damage()
	_castle_level_action_section.visible = not should_hide_castle_actions

	_update_construction_status()

	var cost: Dictionary = _get_castle_cost_for_display()
	var gold_cost: int = int(cost.get(ResourcesEnum.Type.GOLD, 0))
	var wood_cost: int = int(cost.get(ResourcesEnum.Type.WOOD, 0))
	var stone_cost: int = int(cost.get(ResourcesEnum.Type.STONE, 0))
	var iron_cost: int = int(cost.get(ResourcesEnum.Type.IRON, 0))
	_set_cost_value("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/Resources/Gold", gold_cost)
	_set_cost_value("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/Resources/Wood", wood_cost)
	_set_cost_value("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/Resources/Stone", stone_cost)
	_set_cost_value("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/Resources/Iron", iron_cost)
	_update_castle_construction_time_resource()

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

func _update_castle_construction_time_resource() -> void:
	var gold_container: HBoxContainer = get_node("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/Resources/Gold")
	var wood_container: HBoxContainer = get_node("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/Resources/Wood")
	var stone_container: HBoxContainer = get_node("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/Resources/Stone")
	var iron_container: HBoxContainer = get_node("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/Resources/Iron")
	var time_container: HBoxContainer = get_node("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/Resources/Time")
	var time_value: Label = get_node("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/Resources/Time/Value")
	var is_under_construction: bool = current_region.is_castle_under_construction()
	if is_under_construction:
		gold_container.visible = false
		wood_container.visible = false
		stone_container.visible = false
		iron_container.visible = false
		time_container.visible = true
		var turns_left: int = current_region.get_castle_build_turns_remaining()
		time_value.text = str(turns_left)
		return
	time_container.visible = false

func _update_raise_army_section() -> void:
	"""Update raise army label and cost"""
	var owner_id: int = current_region.get_region_owner()
	var roman_number: String = game_manager.get_army_manager().get_next_army_roman_numeral_for_player(owner_id)
	var next_army_label: Label = get_node("RegionPanel/Body/Region/Actions/RaiseArmy/Info/Army/NextArmyName")
	next_army_label.text = tr("Army %s") % roman_number

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
	if current_region.get_castle_type() == CastleTypeEnum.Type.NONE:
		recruits_value.text = str(current_region.get_available_recruits())
		recruits_max.text = str(current_region.get_max_recruits())
	else:
		var owner_id: int = current_region.get_region_owner()
		var pooled_available: int = region_manager.get_available_recruits_total_from_region_and_neighbors(current_region.get_region_id(), owner_id)
		var pooled_max: int = region_manager.get_max_recruits_total_from_region_and_neighbors(current_region.get_region_id(), owner_id)
		recruits_value.text = str(pooled_available)
		recruits_max.text = str(pooled_max)
	_recruit_button.disabled = false

func _update_defenders_section() -> void:
	"""Update garrison unit composition values"""
	var garrison_comp: ArmyComposition = current_region.get_garrison()
	var wounded_comp: ArmyComposition = current_region.get_wounded_garrison()
	if _is_current_region_intel_mode():
		garrison_comp = _get_enemy_garrison_intel_composition()
		wounded_comp = _get_enemy_garrison_intel_wounded_composition()
		if garrison_comp == null:
			var garrison_info_root: Node = get_node("RegionPanel/Body/Region/DefendersSection/GarrisonInfo")
			_set_unknown_unit_values(garrison_info_root)
			return
	for i in range(GARRISON_UNIT_NODE_NAMES.size()):
		var unit_node: Node = get_node("RegionPanel/Body/Region/DefendersSection/GarrisonInfo/" + GARRISON_UNIT_NODE_NAMES[i])
		var healthy: int = garrison_comp.get_soldier_count(GARRISON_UNIT_TYPES[i])
		var wounded: int = 0
		if wounded_comp != null:
			wounded = wounded_comp.get_soldier_count(GARRISON_UNIT_TYPES[i])
		_set_unit_value_with_wounded(unit_node, healthy, wounded)

func _set_cost_value(container_path: String, value: int) -> void:
	var container: HBoxContainer = get_node(container_path)
	container.visible = value > 0
	var value_label: Label = get_node(container_path + "/Value")
	value_label.text = str(value)

func _update_army_unit_values(composition: ArmyComposition, wounded_composition: ArmyComposition, info_root: Node) -> void:
	"""Update army unit composition values"""
	if composition == null or info_root == null:
		return

	for i in range(GARRISON_UNIT_NODE_NAMES.size()):
		var unit_node: Node = info_root.get_node(GARRISON_UNIT_NODE_NAMES[i])
		var healthy: int = composition.get_soldier_count(GARRISON_UNIT_TYPES[i])
		var wounded: int = 0
		if wounded_composition != null:
			wounded = wounded_composition.get_soldier_count(GARRISON_UNIT_TYPES[i])
		_set_unit_value_with_wounded(unit_node, healthy, wounded)

func _set_unit_value_with_wounded(unit_node: Node, healthy: int, wounded: int) -> void:
	var healthy_node: Control = unit_node.get_node("Healthy") as Control
	var wounded_node: HBoxContainer = unit_node.get_node("Wounded") as HBoxContainer
	var healthy_value: Label = healthy_node.get_node("Value") as Label
	var wounded_value: Label = wounded_node.get_node("Value") as Label
	var wounded_label: Label = wounded_node.get_node("Wounded") as Label
	if wounded > 0:
		healthy_node.visible = false
		wounded_node.visible = true
		wounded_value.text = str(healthy)
		wounded_value.add_theme_color_override("font_color", Color.WHITE)
		wounded_label.text = "+" + str(wounded)
		wounded_label.add_theme_color_override("font_color", Color.YELLOW)
		if wounded < 10:
			wounded_label.add_theme_font_size_override("font_size", 17)
		else:
			wounded_label.add_theme_font_size_override("font_size", 12)
	else:
		wounded_node.visible = false
		healthy_node.visible = true
		healthy_value.text = str(healthy)
		healthy_value.add_theme_color_override("font_color", Color.WHITE)

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
	income_value.text = _format_income_value(current_region.get_income())

	var food_value = get_node("RegionPanel/Body/Region/RegionResources/Food/Value") as Label
	food_value.text = _format_income_value(current_region.get_resource_amount(ResourcesEnum.Type.FOOD))
	var wood_value = get_node("RegionPanel/Body/Region/RegionResources/Wood/Value") as Label
	wood_value.text = _format_income_value(current_region.get_resource_amount(ResourcesEnum.Type.WOOD))
	var stone_value = get_node("RegionPanel/Body/Region/RegionResources/Stone/Value") as Label
	stone_value.text = _format_income_value(current_region.get_resource_amount(ResourcesEnum.Type.STONE))

	var iron_amount: int = current_region.get_resource_amount(ResourcesEnum.Type.IRON)
	var iron_container = get_node("RegionPanel/Body/Region/RegionResources/Iron") as HBoxContainer
	iron_container.visible = iron_amount > 0 and current_region.can_collect_resource(ResourcesEnum.Type.IRON)
	var iron_value = get_node("RegionPanel/Body/Region/RegionResources/Iron/Value") as Label
	iron_value.text = _format_income_value(iron_amount)

	var gold_amount: int = current_region.get_resource_amount(ResourcesEnum.Type.GOLD)
	var gold_container = get_node("RegionPanel/Body/Region/RegionResources/Gold") as HBoxContainer
	gold_container.visible = gold_amount > 0 and current_region.can_collect_resource(ResourcesEnum.Type.GOLD)
	var gold_value = get_node("RegionPanel/Body/Region/RegionResources/Gold/Value") as Label
	gold_value.text = _format_income_value(gold_amount)

func _format_income_value(value: int) -> String:
	if value == 0:
		return "0"
	return "+" + str(value)

func _update_construction_status() -> void:
	"""Update construction status label"""
	var build_button = get_node("RegionPanel/Body/Region/Actions/CastleLevel/ActionSection/BuildButton") as Button
	var current_castle_type: CastleTypeEnum.Type = current_region.get_castle_type()
	var next_castle_type: CastleTypeEnum.Type = CastleTypeEnum.get_next_level(current_castle_type)
	if current_region.is_castle_under_construction():
		build_button.text = tr("Building")
		build_button.disabled = true
	elif current_region.is_castle_under_repair():
		build_button.text = tr("Repairing")
		build_button.disabled = true
	elif current_region.has_castle_damage():
		build_button.text = tr("Repair")
		var can_repair: bool = _can_player_afford_repair() and current_region.has_castle()
		build_button.disabled = not can_repair
	elif current_castle_type == CastleTypeEnum.Type.NONE:
		build_button.text = tr("Build")
		build_button.disabled = not (_can_player_afford_any_castle() and current_region.can_build_castle())
	else:
		build_button.text = tr("Upgrade")
		if next_castle_type == CastleTypeEnum.Type.NONE:
			build_button.disabled = true
		else:
			build_button.disabled = not (_can_player_afford_castle(next_castle_type) and current_region.can_upgrade_castle())

func _update_mine_status() -> void:
	"""Update mine status label"""
	var mine_label = get_node("RegionPanel/Body/Region/Actions/Mine/Info/Search/SearchStatus") as Label
	mine_label.text = current_region.get_ore_search_status_string()
	var gold_cost: int = GameParameters.get_ore_search_cost()
	_set_cost_value("RegionPanel/Body/Region/Actions/Mine/ActionSection/Resources/Gold", gold_cost)
	var can_search_region: bool = GameParameters.can_search_for_ore_in_region(current_region.get_region_type())
	var has_searches_remaining: bool = current_region.get_ore_search_attempts_remaining() > 0
	_mine_action_section.visible = can_search_region and has_searches_remaining
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
	var current_player: Player = _get_current_turn_player()
	if not current_player.pay_cost(promotion_cost):
		return
	current_region.promote_region()
	current_region.mark_promoted_this_turn()
	sound_manager.play_promote_sound()
	var level_name: String = RegionLevelEnum.level_to_display_string(next_level)
	var promotion_message_template: String = tr("Region promoted to {level}\\n(level {level_number})")
	var promotion_message: String = promotion_message_template.format({
		"level": level_name,
		"level_number": int(next_level) + 1
	}).replace("\\n", "\n")
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
	var current_player: Player = _get_current_turn_player()
	if not region_manager.try_repair_castle(current_region, current_player):
		return
	message_modal.display_message(tr("Repair started"), tr("Repairs will finish in 1 turn."))
	_refresh_current_region()
	_request_player_status_refresh()

func _start_castle_construction(castle_type: CastleTypeEnum.Type) -> void:
	var construction_cost = GameParameters.get_castle_building_cost(castle_type)
	var current_player: Player = _get_current_turn_player()
	if not current_player.pay_cost(construction_cost):
		return
	current_region.start_castle_construction(castle_type)
	sound_manager.play_hammer_sound(3.0)
	var turns_left = current_region.get_castle_build_turns_remaining()
	var turn_word: String = tr("turn") if turns_left == 1 else tr("turns")
	message_modal.display_message(tr("Construction will be completed in %d %s.") % [turns_left, turn_word])
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
	var search_result: Dictionary = region_manager.perform_ore_search(current_region, _get_current_turn_player_id(), player_manager)
	if search_result.success:
		sound_manager.play_mining_sound()
	else:
		sound_manager.play_mining_sound(2.0)
	if search_result.success and search_result.has("ore_type"):
		var ore_type = search_result.ore_type
		var ore_type_string = ResourcesEnum.type_to_display_string(ore_type)
		var ore_amount = current_region.get_resource_amount(ore_type)
		var header = tr("%s Found!") % ore_type_string.capitalize()
		var message = tr("Ore size was estimated at %d units.") % ore_amount
		message_modal.display_message(header, message)
	elif not search_result.success:
		var header = tr("Ore Search")
		var remaining_attempts = current_region.get_ore_search_attempts_remaining()
		var message: String
		if remaining_attempts > 0:
			message = tr("No luck this turn.")
		else:
			message = tr("Ore searches exhausted.")
		message_modal.display_message(header, message)
	_refresh_current_region()
	_request_player_status_refresh()

func _on_raise_army_pressed() -> void:
	sound_manager.click_sound()
	if not _region_has_army_capacity():
		return
	if not _can_player_afford_raise_army():
		return
	var current_player: Player = _get_current_turn_player()
	var current_player_id: int = _get_current_turn_player_id()
	var raise_army_cost: int = GameParameters.get_raise_army_cost()
	if current_player.get_resource_amount(ResourcesEnum.Type.GOLD) < raise_army_cost:
		return
	current_player.remove_resources(ResourcesEnum.Type.GOLD, raise_army_cost)
	var new_army: Army = army_manager.create_raised_army(current_region, current_player_id)
	if new_army != null:
		sound_manager.play_horn_sound()
		current_region.mark_raise_army_used()
		var army_name: String = tr("Army %s") % new_army.number
		message_modal.display_message(tr("%s is being raised.") % army_name)
		_refresh_current_region()
		_request_player_status_refresh()
	else:
		current_player.add_resources(ResourcesEnum.Type.GOLD, raise_army_cost)

func _calculate_repair_cost() -> Dictionary:
	return current_region.get_castle_repair_cost()

func _get_current_turn_player_id() -> int:
	return game_manager.get_current_player_id()

func _get_current_turn_player() -> Player:
	return player_manager.get_player(_get_current_turn_player_id())

func _can_player_afford_repair() -> bool:
	var current_player: Player = _get_current_turn_player()
	var repair_cost: Dictionary = _calculate_repair_cost()
	return current_player.can_afford_cost(repair_cost)

func _can_player_afford_promotion(target_level: RegionLevelEnum.Level) -> bool:
	var promotion_cost: Dictionary = GameParameters.get_promotion_cost(target_level)
	var current_player: Player = _get_current_turn_player()
	var player_resources: Dictionary = {
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
	var food_cost: int = int(promotion_cost.get(ResourcesEnum.Type.FOOD, 0))
	return player_manager.meets_food_upgrade_safeguard(player_id, food_cost)

func _can_player_afford_castle(castle_type: CastleTypeEnum.Type) -> bool:
	var current_player: Player = _get_current_turn_player()
	var player_resources: Dictionary = {
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
	var current_player: Player = _get_current_turn_player()
	var search_cost: int = GameParameters.get_ore_search_cost()
	return current_player.get_resource_amount(ResourcesEnum.Type.GOLD) >= search_cost

func _can_player_afford_raise_army() -> bool:
	var current_player: Player = _get_current_turn_player()
	var raise_army_cost: int = GameParameters.get_raise_army_cost()
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

func set_spawn_event_armies_only_mode(enabled: bool) -> void:
	_spawn_event_armies_only_mode = enabled
	if enabled:
		_region_tab_label.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_set_active_tab(TabType.ARMIES)
		_update_army_display()
		return
	_region_tab_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

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
	if _spawn_event_armies_only_mode:
		return
	if _active_tab != TabType.REGION:
		_region_tab_label.add_theme_color_override("font_color", Color.WHITE)

func _on_region_tab_mouse_exited() -> void:
	if _spawn_event_armies_only_mode:
		return
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
		if _spawn_event_armies_only_mode:
			_region_tab_label.accept_event()
			get_viewport().set_input_as_handled()
			return
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
		if game_manager.tutorial_enabled:
			tutorial_manager.handle_ui_click("InfoModal/armies_tab")
			tutorial_manager.handle_ui_click("InfoModal/Armies")
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
		if _spawn_event_armies_only_mode:
			get_viewport().set_input_as_handled()
			return
		if ui_manager.is_recruitment_or_transfer_modal_visible():
			get_viewport().set_input_as_handled()
			return
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
		if _is_current_region_intel_mode():
			(_army_cards[index] as Control).accept_event()
			get_viewport().set_input_as_handled()
			return
		if army == null or not _is_army_selectable_for_current_player(army):
			(_army_cards[index] as Control).accept_event()
			get_viewport().set_input_as_handled()
			return
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
