extends Control
class_name RecruitmentModal

signal ten_archers_target_reached
signal one_archer_target_reached
signal recruit_all_target_reached

# UI elements - references to static nodes from scene
var recruitment_title_label: Label
var total_gold_label: Label
var total_wood_label: Label
var total_iron_label: Label
var available_recruits_label: Label
var continue_button: Button
var recruit_all_button: Button
var tutorial_manager: TutorialManager = null

const UNIT_SECTIONS := [
	{"path": "Recruitment/HBoxContainer/Body/Units/FirstRow/Peasants", "type": SoldierTypeEnum.Type.PEASANTS},
	{"path": "Recruitment/HBoxContainer/Body/Units/FirstRow/Spearmen", "type": SoldierTypeEnum.Type.SPEARMEN},
	{"path": "Recruitment/HBoxContainer/Body/Units/FirstRow/Archers", "type": SoldierTypeEnum.Type.ARCHERS},
	{"path": "Recruitment/HBoxContainer/Body/Units/SecondRow/Swordsmen", "type": SoldierTypeEnum.Type.SWORDSMEN},
	{"path": "Recruitment/HBoxContainer/Body/Units/SecondRow/Crossbowmen", "type": SoldierTypeEnum.Type.CROSSBOWMEN},
	{"path": "Recruitment/HBoxContainer/Body/Units/SecondRow/Horsemen", "type": SoldierTypeEnum.Type.HORSEMEN},
	{"path": "Recruitment/HBoxContainer/Body/Units/ThirdRow/Knights", "type": SoldierTypeEnum.Type.KNIGHTS},
	{"path": "Recruitment/HBoxContainer/Body/Units/ThirdRow/MountedKnights", "type": SoldierTypeEnum.Type.MOUNTED_KNIGHTS},
	{"path": "Recruitment/HBoxContainer/Body/Units/ThirdRow/RoyalGuard", "type": SoldierTypeEnum.Type.ROYAL_GUARD}
]

const BUTTON_MINUS_DARK: Texture2D = preload("res://images/button_minus_dark.png")
const BUTTON_MINUS_LIGHT: Texture2D = preload("res://images/button_minus_light.png")
const BUTTON_PLUS_DARK: Texture2D = preload("res://images/button_plus_dark.png")
const BUTTON_PLUS_LIGHT: Texture2D = preload("res://images/button_plus_light.png")
const BUTTON_MINUS_DISABLED_PATH: String = "res://images/button_minus_disabled.png"
const BUTTON_PLUS_DISABLED_PATH: String = "res://images/button_plus_disabled.png"

const ICON_GOLD = preload("res://images/icons/new_coin.png")
const ICON_WOOD = preload("res://images/icons/new_forest.png")
const ICON_IRON = preload("res://images/icons/new_iron.png")
const ABILITIES_TOOLTIP_OFFSET: Vector2 = Vector2(20, 30)
const ABILITIES_TOOLTIP_MAX_X: float = 1520.0
const HOLD_DELAY_SECONDS: float = 0.5
const HOLD_INTERVAL_SECONDS: float = 0.7
const HOLD_STEP: int = 10
const TUTORIAL_TARGET_TEN_ARCHERS: String = "RecruitmentModal/10archers"
const TUTORIAL_TARGET_ONE_ARCHER: String = "RecruitmentModal/1archers"
const TUTORIAL_TARGET_RECRUIT_ALL: String = "RecruitmentModal/recruit_all"
const TRAIT_KEY_BY_LABEL_NAME := {
	"LongSpears": "long_spears",
	"Ranged": "ranged",
	"Mobility": "mobility",
	"Flanker": "flanker",
	"Charge": "charge",
	"MultiAttack": "multi_attack",
	"ArmorPiercing": "armor_piercing",
	"SiegeLaborer": "siege_laborer",
	"BackRank": "back_rank",
	"Defender": "defender"
}
const TRAIT_DESCRIPTION_KEY_BY_TRAIT_KEY := {
	"long_spears": "trait_desc_long_spears",
	"ranged": "trait_desc_ranged",
	"mobility": "trait_desc_mobility",
	"flanker": "trait_desc_flanker",
	"charge": "trait_desc_charge",
	"multi_attack": "trait_desc_multi_attack",
	"armor_piercing": "trait_desc_armor_piercing",
	"siege_laborer": "trait_desc_siege_laborer",
	"back_rank": "trait_desc_back_rank",
	"defender": "trait_desc_defender"
}
const TRAIT_KEY_ALIASES := {
	"multi attack": "master-at-arms",
	"multiattack": "master-at-arms",
	"armor piercing": "armour piercing",
	"armorpiercing": "armour piercing",
	"armor-piercing": "armour piercing"
}

# Recruitment data
var target_army: Army = null
var target_region: Region = null
var recruitment_counts: Dictionary = {} # unit_type -> count to hire
var total_cost: Dictionary = {} # resource_type -> total cost

# Additional manager reference
var game_manager: GameManager = null
var region_manager: RegionManager = null
var player_manager: PlayerManagerNode = null

# Common references
var sound_manager: SoundManager = null
var ui_manager: UIManager = null
var info_modal: InfoModal = null
var move_modal: MoveModal = null
var select_tooltip_modal: SelectTooltipModal = null
var abilities_tooltip: SelectTooltipModalNoRes = null
var abilities_tooltip_label: Label = null
var _reopen_move_modal: bool = false
var _reopen_move_army: Army = null
var _trait_descriptions: Dictionary = {}
var _hold_active: bool = false
var _hold_unit_type: SoldierTypeEnum.Type = SoldierTypeEnum.Type.PEASANTS
var _hold_delta: int = 0
var _hold_elapsed: float = 0.0
var _hold_interval_elapsed: float = 0.0
var _hold_after_delay_started: bool = false
var _button_minus_disabled: Texture2D
var _button_plus_disabled: Texture2D

func _setup_references():
	sound_manager = get_node("../../SoundManager") as SoundManager
	ui_manager = get_node("../UIManager") as UIManager
	info_modal = get_node("../InfoModal") as InfoModal
	move_modal = get_node("../MoveModal") as MoveModal
	select_tooltip_modal = get_node("../SelectTooltipModal") as SelectTooltipModal
	abilities_tooltip = get_node("AbilitiesTooltip") as SelectTooltipModalNoRes
	if abilities_tooltip != null:
		abilities_tooltip_label = abilities_tooltip.get_node("TooltipLabel") as Label
	game_manager = get_node("../../GameManager") as GameManager
	region_manager = game_manager.get_region_manager()
	if game_manager:
		tutorial_manager = game_manager.get_tutorial_manager()

func _ready():
	_button_minus_disabled = _load_texture_from_png(BUTTON_MINUS_DISABLED_PATH)
	_button_plus_disabled = _load_texture_from_png(BUTTON_PLUS_DISABLED_PATH)
	# Setup base references but skip button_container setup
	_setup_references()
	visible = false
	
	# Get references to static UI elements from scene
	recruitment_title_label = get_node("Recruitment/HBoxContainer/Header/HeaderSection/RegionName")
	total_gold_label = get_node("Recruitment/HBoxContainer/TotalSection/HBoxContainer/TotalGold")
	total_wood_label = get_node("Recruitment/HBoxContainer/TotalSection/HBoxContainer/TotalWood")
	total_iron_label = get_node("Recruitment/HBoxContainer/TotalSection/HBoxContainer/TotalIron")
	available_recruits_label = get_node("Recruitment/HBoxContainer/AvailableRecruits/HBoxContainer/Value")
	continue_button = get_node("Recruitment/HBoxContainer/TotalSection/HBoxContainer/Buttons/Button")
	recruit_all_button = get_node("Recruitment/HBoxContainer/TotalSection/HBoxContainer/Buttons/RecruitAll")
	continue_button.name = "continue"
	
	# Connect button signal
	continue_button.pressed.connect(_on_continue_pressed)
	recruit_all_button.pressed.connect(_on_recruit_all_pressed)
	if tutorial_manager != null:
		continue_button.pressed.connect(func(): tutorial_manager.handle_ui_click("RecruitmentModal/" + continue_button.name))
		var ten_archers_cb: Callable = Callable(self, "_on_ten_archers_target_reached")
		if not ten_archers_target_reached.is_connected(ten_archers_cb):
			ten_archers_target_reached.connect(ten_archers_cb)
		var one_archer_cb: Callable = Callable(self, "_on_one_archer_target_reached")
		if not one_archer_target_reached.is_connected(one_archer_cb):
			one_archer_target_reached.connect(one_archer_cb)
		var recruit_all_cb: Callable = Callable(self, "_on_recruit_all_target_reached")
		if not recruit_all_target_reached.is_connected(recruit_all_cb):
			recruit_all_target_reached.connect(recruit_all_cb)
	
	# Connect unit adjustment buttons
	_connect_button_signals()
	_build_trait_descriptions()
	_connect_trait_tooltips()
	
	# Get additional manager reference
	player_manager = get_node("../../PlayerManager") as PlayerManagerNode
	set_process(true)

func _process(_delta: float) -> void:
	if abilities_tooltip != null and abilities_tooltip.visible:
		_update_abilities_tooltip_position(get_viewport().get_mouse_position())
	_process_hold(_delta)

func _connect_button_signals() -> void:
	for section_data in UNIT_SECTIONS:
		var section: Control = get_node(section_data.path)
		var button_minus: TextureRect = section.get_node("ButtonMinus")
		var button_plus: TextureRect = section.get_node("ButtonPlus")
		var recruit_button: Button = section.get_node("RecruitButton")
		button_minus.gui_input.connect(_on_adjust_button_input.bind(section_data.type, -1))
		button_plus.gui_input.connect(_on_adjust_button_input.bind(section_data.type, 1))
		button_minus.mouse_entered.connect(_on_adjust_button_hover.bind(button_minus, false))
		button_minus.mouse_exited.connect(_on_adjust_button_exit.bind(button_minus, false))
		button_plus.mouse_entered.connect(_on_adjust_button_hover.bind(button_plus, true))
		button_plus.mouse_exited.connect(_on_adjust_button_exit.bind(button_plus, true))
		recruit_button.pressed.connect(_on_recruit_button_pressed.bind(section_data.type))

func _build_trait_descriptions() -> void:
	_trait_descriptions.clear()
	for trait_key in TRAIT_DESCRIPTION_KEY_BY_TRAIT_KEY.keys():
		var desc_key: String = String(TRAIT_DESCRIPTION_KEY_BY_TRAIT_KEY[trait_key])
		_trait_descriptions[trait_key] = tr(desc_key)

func _connect_trait_tooltips() -> void:
	for section_data in UNIT_SECTIONS:
		var section: Control = get_node(section_data.path)
		var labels: Array = section.find_children("*", "Label", true, false)
		for label in labels:
			var key := _get_label_trait_key(label)
			if key == "":
				continue
			label.mouse_filter = Control.MOUSE_FILTER_STOP
			label.mouse_entered.connect(_on_trait_label_mouse_entered.bind(key))
			label.mouse_exited.connect(_on_trait_label_mouse_exited)

func _normalize_trait_key(text: String) -> String:
	var key := text.strip_edges().to_lower()
	key = key.replace("•", "")
	key = key.replace(":", "")
	key = key.replace("\n", " ")
	while key.find("  ") != -1:
		key = key.replace("  ", " ")
	return key.strip_edges()

func _get_label_trait_key(label: Label) -> String:
	if TRAIT_KEY_BY_LABEL_NAME.has(label.name):
		return String(TRAIT_KEY_BY_LABEL_NAME[label.name])
	var key := _normalize_trait_key(label.text)
	if key == "" or key == "none":
		return ""
	if _trait_descriptions.has(key):
		return key
	var name_key := _normalize_trait_key(label.name)
	if _trait_descriptions.has(name_key):
		return name_key
	if TRAIT_KEY_ALIASES.has(key):
		var alias_key: String = TRAIT_KEY_ALIASES[key]
		if _trait_descriptions.has(alias_key):
			return alias_key
	if TRAIT_KEY_ALIASES.has(name_key):
		var alias_name_key: String = TRAIT_KEY_ALIASES[name_key]
		if _trait_descriptions.has(alias_name_key):
			return alias_name_key
	return ""

func _on_trait_label_mouse_entered(trait_key: String) -> void:
	if abilities_tooltip_label == null or abilities_tooltip == null:
		return
	var desc: String = _trait_descriptions.get(trait_key, "")
	if desc == "":
		abilities_tooltip.hide_tooltip()
		return
	abilities_tooltip_label.text = desc
	_update_abilities_tooltip_position(get_viewport().get_mouse_position())
	abilities_tooltip.visible = true

func _on_trait_label_mouse_exited() -> void:
	if abilities_tooltip != null:
		abilities_tooltip.hide_tooltip()

func _update_abilities_tooltip_position(mouse_pos: Vector2) -> void:
	if abilities_tooltip == null:
		return
	var pos := mouse_pos + ABILITIES_TOOLTIP_OFFSET
	var screen_size = get_viewport().get_visible_rect().size
	if pos.x + abilities_tooltip.size.x > screen_size.x:
		pos.x = screen_size.x - abilities_tooltip.size.x - 10.0
	if pos.y + abilities_tooltip.size.y > screen_size.y:
		pos.y = screen_size.y - abilities_tooltip.size.y - 10.0
	pos.x = max(10.0, pos.x)
	pos.y = max(10.0, pos.y)
	pos.x = min(pos.x, ABILITIES_TOOLTIP_MAX_X)
	abilities_tooltip.global_position = pos

func _on_adjust_button_input(event: InputEvent, unit_type: SoldierTypeEnum.Type, delta: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var step: int = HOLD_STEP if event.shift_pressed else 1
			_adjust_recruitment(unit_type, delta * step)
			_start_hold(unit_type, delta)
		else:
			_stop_hold()

func _on_adjust_button_hover(button: TextureRect, is_plus: bool) -> void:
	if button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	_set_adjust_button_texture(button, is_plus, true, true)

func _on_adjust_button_exit(button: TextureRect, is_plus: bool) -> void:
	if button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		_set_adjust_button_texture(button, is_plus, false, false)
		return
	_set_adjust_button_texture(button, is_plus, false, true)

func _set_adjust_button_texture(button: TextureRect, is_plus: bool, is_hover: bool, enabled: bool) -> void:
	if not enabled:
		button.texture = _button_plus_disabled if is_plus else _button_minus_disabled
		return
	if is_plus:
		button.texture = BUTTON_PLUS_LIGHT if is_hover else BUTTON_PLUS_DARK
	else:
		button.texture = BUTTON_MINUS_LIGHT if is_hover else BUTTON_MINUS_DARK

func _is_mouse_over_control(control: Control) -> bool:
	return control.get_global_rect().has_point(control.get_viewport().get_mouse_position())

func _set_adjust_button_enabled(button: TextureRect, enabled: bool, is_plus: bool) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_set_adjust_button_texture(button, is_plus, _is_mouse_over_control(button), enabled)

func _load_texture_from_png(path: String) -> Texture2D:
	var image: Image = Image.load_from_file(path)
	return ImageTexture.create_from_image(image)

func _start_hold(unit_type: SoldierTypeEnum.Type, delta: int) -> void:
	_hold_active = true
	_hold_unit_type = unit_type
	_hold_delta = delta
	_hold_elapsed = 0.0
	_hold_interval_elapsed = 0.0
	_hold_after_delay_started = false

func _stop_hold() -> void:
	_hold_active = false
	_hold_elapsed = 0.0
	_hold_interval_elapsed = 0.0
	_hold_after_delay_started = false

func _process_hold(delta: float) -> void:
	if not _hold_active:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_stop_hold()
		return
	_hold_elapsed += delta
	if _hold_elapsed < HOLD_DELAY_SECONDS:
		return
	if not _hold_after_delay_started:
		_hold_after_delay_started = true
		_hold_interval_elapsed = 0.0
		_adjust_recruitment(_hold_unit_type, _hold_delta * HOLD_STEP)
		return
	_hold_interval_elapsed += delta
	while _hold_interval_elapsed >= HOLD_INTERVAL_SECONDS:
		_hold_interval_elapsed -= HOLD_INTERVAL_SECONDS
		_adjust_recruitment(_hold_unit_type, _hold_delta * HOLD_STEP)

func show_recruitment(army: Army, region: Region, reopen_move_modal: bool = false) -> void:
	"""Show the recruitment modal with army and region information"""
	if army == null or region == null:
		hide_modal()
		return
	ui_manager.remember_army_select(army, region)
	ui_manager.hide_region_tooltip()
	
	_reopen_move_modal = reopen_move_modal
	_reopen_move_army = army if reopen_move_modal else null
	target_army = army
	target_region = region
	
	# Reset recruitment state
	recruitment_counts.clear()
	total_cost.clear()
	
	# Update display
	_update_display()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)

func show_region_recruitment(region: Region) -> void:
	"""Show the recruitment modal for region garrison recruitment"""
	if region == null:
		hide_modal()
		return
	ui_manager.remember_region_select(region)
	ui_manager.hide_region_tooltip()
	
	_reopen_move_modal = false
	_reopen_move_army = null
	target_army = null  # No specific army, recruiting to garrison
	target_region = region
	
	# Reset recruitment state
	recruitment_counts.clear()
	total_cost.clear()
	
	# Update display
	_update_display()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)

func hide_modal() -> void:
	"""Hide the recruitment modal"""
	# If we have pending recruitment that wasn't finalized, refund the resources
	if not recruitment_counts.is_empty():
		for unit_type in recruitment_counts:
			var count = recruitment_counts[unit_type]
			_refund_unit_cost(unit_type, count)
	_stop_hold()
	if abilities_tooltip != null:
		abilities_tooltip.hide_tooltip()
	
	var reopen_move: bool = _reopen_move_modal
	var reopen_army: Army = _reopen_move_army
	var remembered_army: Army = target_army
	var remembered_region: Region = target_region
	_reopen_move_modal = false
	_reopen_move_army = null

	# Reset state
	target_army = null
	target_region = null
	recruitment_counts.clear()
	total_cost.clear()
	
	visible = false
	
	if ui_manager:
		ui_manager.set_modal_active(false)
		if remembered_army == null and remembered_region != null:
			ui_manager.clear_select_context()
			if info_modal:
				info_modal.show_region_info(remembered_region, false, false)
		else:
			ui_manager.restore_select_context()
	if reopen_move and move_modal != null and reopen_army != null:
		move_modal.show_move_modal(reopen_army)

func _update_display() -> void:
	"""Update the display with current recruitment information"""
	if target_region == null:
		hide_modal()
		return
	
	# Update title with castle level info
	recruitment_title_label.text = tr("Recruitment at %s") % target_region.get_region_name()
	_update_requirements()
	
	# Update recruitment rows using static elements
	_update_recruitment_display()
	
	# Update total row
	_update_total_row()

func _update_requirements() -> void:
	if target_region == null:
		return
	var castle_type: CastleTypeEnum.Type = target_region.get_castle_type()
	var outpost_node: Control = get_node("Requirements/Outpost")
	var keep_node: Control = get_node("Requirements/Keep")
	var castle_node: Control = get_node("Requirements/Castle")
	var stronghold_node: Control = get_node("Requirements/Stronghold")
	
	outpost_node.visible = castle_type == CastleTypeEnum.Type.NONE
	keep_node.visible = castle_type == CastleTypeEnum.Type.NONE or castle_type == CastleTypeEnum.Type.OUTPOST
	castle_node.visible = castle_type == CastleTypeEnum.Type.NONE or castle_type == CastleTypeEnum.Type.OUTPOST or castle_type == CastleTypeEnum.Type.KEEP
	stronghold_node.visible = castle_type == CastleTypeEnum.Type.NONE or castle_type == CastleTypeEnum.Type.OUTPOST or castle_type == CastleTypeEnum.Type.KEEP or castle_type == CastleTypeEnum.Type.CASTLE

func _update_recruitment_display() -> void:
	"""Update recruitment controls and cost display using static scene elements"""
	if target_region == null:
		return
	
	var castle_type = target_region.get_castle_type()
	for section_data in UNIT_SECTIONS:
		_update_unit_section(section_data.path, section_data.type, castle_type)

func _update_unit_section(section_path: String, unit_type: SoldierTypeEnum.Type, castle_type: CastleTypeEnum.Type) -> void:
	"""Update a static unit section with current values"""
	var is_available = GameParameters.can_recruit_unit_with_castle(unit_type, castle_type)
	var section: Control = get_node(section_path)
	
	var resource1_icon: TextureRect = section.get_node("Resource1")
	var resource2_icon: TextureRect = section.get_node("Resource2")
	var resource1_cost_label: Label = section.get_node("Resource1Cost")
	var resource2_cost_label: Label = section.get_node("Resource2Cost")
	var attack_value: Label = section.get_node("AttackValue")
	var defense_value: Label = section.get_node("DefenseValue")
	var count_label: Label = section.get_node("Count")
	var button_minus: TextureRect = section.get_node("ButtonMinus")
	var button_plus: TextureRect = section.get_node("ButtonPlus")
	var recruit_button: Button = section.get_node("RecruitButton")
	
	attack_value.text = str(GameParameters.get_unit_stat(unit_type, "attack"))
	defense_value.text = str(GameParameters.get_unit_stat(unit_type, "defense"))
	
	var count_to_hire: int = recruitment_counts.get(unit_type, 0) if is_available else 0
	count_label.text = str(count_to_hire)
	
	var gold_cost: int = GameParameters.get_unit_gold_cost(unit_type)
	var wood_cost: int = GameParameters.get_unit_wood_cost(unit_type)
	var iron_cost: int = GameParameters.get_unit_iron_cost(unit_type)
	
	resource2_icon.texture = ICON_GOLD
	resource2_cost_label.text = str(gold_cost)
	
	if iron_cost > 0:
		resource1_icon.texture = ICON_IRON
		resource1_cost_label.text = str(iron_cost)
		resource1_icon.visible = true
		resource1_cost_label.visible = true
	elif wood_cost > 0:
		resource1_icon.texture = ICON_WOOD
		resource1_cost_label.text = str(wood_cost)
		resource1_icon.visible = true
		resource1_cost_label.visible = true
	else:
		resource1_icon.visible = false
		resource1_cost_label.visible = false
	
	if not is_available:
		_set_adjust_button_enabled(button_minus, false, false)
		_set_adjust_button_enabled(button_plus, false, true)
		recruit_button.disabled = true
		count_label.text = "0"
		return
	
	var can_hire_one: bool = _can_hire_amount(unit_type, 1)
	_set_adjust_button_enabled(button_plus, can_hire_one, true)
	_set_adjust_button_enabled(button_minus, count_to_hire > 0, false)
	recruit_button.disabled = count_to_hire <= 0

func _update_total_row() -> void:
	"""Update the total row with army/garrison totals and recruitment totals"""
	var total_to_hire: int = 0
	for count in recruitment_counts.values():
		total_to_hire += count
	
	var available_recruits: int = _get_pooled_available_recruits()
	var remaining_recruits: int = max(0, available_recruits - total_to_hire)

	# Update labels
	var gold_total: int = total_cost.get(ResourcesEnum.Type.GOLD, 0)
	var wood_total: int = total_cost.get(ResourcesEnum.Type.WOOD, 0)
	var iron_total: int = total_cost.get(ResourcesEnum.Type.IRON, 0)
	total_gold_label.text = str(gold_total)
	total_wood_label.text = str(wood_total)
	total_iron_label.text = str(iron_total)
	_update_recruit_all_button_state(total_to_hire, gold_total)

	if available_recruits_label:
		available_recruits_label.text = str(remaining_recruits)

func _update_recruit_all_button_state(total_to_hire: int, gold_total: int) -> void:
	recruit_all_button.disabled = total_to_hire <= 0 or gold_total <= 0

func _adjust_recruitment(unit_type: SoldierTypeEnum.Type, delta: int) -> void:
	if target_region == null or delta == 0 or player_manager == null:
		return

	var castle_type = target_region.get_castle_type()
	if not GameParameters.can_recruit_unit_with_castle(unit_type, castle_type):
		return

	var current_count = recruitment_counts.get(unit_type, 0)
	if delta > 0:
		var free_recruits = _get_pooled_available_recruits() - _get_total_hired()
		if free_recruits <= 0:
			return
		var desired = min(delta, free_recruits)
		var unit_costs = _get_unit_costs(unit_type)
		var affordable = _max_affordable_units(unit_costs, desired)
		if affordable <= 0:
			return
		_deduct_unit_cost(unit_type, affordable)
		recruitment_counts[unit_type] = current_count + affordable
	elif delta < 0:
		if current_count <= 0:
			return
		var remove_amount = min(current_count, -delta)
		if remove_amount <= 0:
			return
		_refund_unit_cost(unit_type, remove_amount)
		var new_count = current_count - remove_amount
		if new_count > 0:
			recruitment_counts[unit_type] = new_count
		else:
			recruitment_counts.erase(unit_type)

	_update_costs()
	_update_recruitment_display()
	_update_total_row()
	var updated_count: int = int(recruitment_counts.get(unit_type, 0))
	_notify_tutorial_archer_target(unit_type, current_count, updated_count, delta)

func _notify_tutorial_archer_target(unit_type: SoldierTypeEnum.Type, previous_count: int, updated_count: int, delta: int) -> void:
	if unit_type != SoldierTypeEnum.Type.ARCHERS:
		return
	if delta > 0 and previous_count == 0 and updated_count >= 1:
		emit_signal("one_archer_target_reached")
	if updated_count == 10:
		emit_signal("ten_archers_target_reached")

func _on_ten_archers_target_reached() -> void:
	if tutorial_manager == null:
		return
	tutorial_manager.handle_ui_click(TUTORIAL_TARGET_TEN_ARCHERS)

func _on_one_archer_target_reached() -> void:
	tutorial_manager.handle_ui_click(TUTORIAL_TARGET_ONE_ARCHER)

func _on_recruit_all_target_reached() -> void:
	tutorial_manager.handle_ui_click(TUTORIAL_TARGET_RECRUIT_ALL)

func _get_unit_abilities_text(unit_type: SoldierTypeEnum.Type) -> String:
	var traits: Array = GameParameters.get_unit_traits(unit_type)
	var abilities: Array[String] = []
	if traits.has(UnitTraitEnum.Type.UNIT_TRAIT_3):
		abilities.append(tr("• Mobility"))
	if traits.has(UnitTraitEnum.Type.UNIT_TRAIT_8):
		abilities.append(tr("• Siege"))
	if traits.has(UnitTraitEnum.Type.UNIT_TRAIT_5):
		abilities.append(tr("• Charge"))
	return "\n".join(abilities)

func _max_affordable_units(unit_costs: Dictionary, desired: int) -> int:
	var result = desired
	for resource_type in unit_costs:
		var cost_per_unit = unit_costs[resource_type]
		if cost_per_unit <= 0:
			continue
		var available = player_manager.get_resource_amount(resource_type)
		var possible = int(available / cost_per_unit)
		if possible < result:
			result = possible
	if result < 0:
		return 0
	return result

func _get_total_hired() -> int:
	var total = 0
	for count in recruitment_counts.values():
		total += count
	return total

func _can_hire_amount(unit_type: SoldierTypeEnum.Type, amount: int) -> bool:
	if amount <= 0 or target_region == null or player_manager == null:
		return false
	var castle_type = target_region.get_castle_type()
	if not GameParameters.can_recruit_unit_with_castle(unit_type, castle_type):
		return false
	var free_recruits = _get_pooled_available_recruits() - _get_total_hired()
	if free_recruits < amount:
		return false
	var unit_costs = _get_unit_costs(unit_type)
	return _can_afford_cost_multiple(unit_costs, amount)

func _get_unit_costs(unit_type: SoldierTypeEnum.Type) -> Dictionary:
	"""Get the resource costs for a unit type from GameParameters"""
	var costs = {}
	
	# Get costs from GameParameters
	var gold_cost = GameParameters.get_unit_gold_cost(unit_type)
	var wood_cost = GameParameters.get_unit_wood_cost(unit_type)
	var iron_cost = GameParameters.get_unit_iron_cost(unit_type)
	
	# Only include costs that are greater than 0
	if gold_cost > 0:
		costs[ResourcesEnum.Type.GOLD] = gold_cost
	if wood_cost > 0:
		costs[ResourcesEnum.Type.WOOD] = wood_cost
	if iron_cost > 0:
		costs[ResourcesEnum.Type.IRON] = iron_cost
	
	return costs

func _can_afford_cost(unit_costs: Dictionary) -> bool:
	"""Check if player can afford the cost of one unit"""
	for resource_type in unit_costs:
		var cost = unit_costs[resource_type]
		if cost > 0:
			var available = player_manager.get_resource_amount(resource_type)
			if available < cost:
				return false
	return true

func _can_afford_cost_multiple(unit_costs: Dictionary, count: int) -> bool:
	"""Check if player can afford the cost of multiple units"""
	for resource_type in unit_costs:
		var total_cost = unit_costs[resource_type] * count
		if total_cost > 0:
			var available = player_manager.get_resource_amount(resource_type)
			if available < total_cost:
				return false
	return true

func _update_costs() -> void:
	"""Update total cost based on recruitment counts"""
	total_cost.clear()
	
	for unit_type in recruitment_counts:
		var count = recruitment_counts[unit_type]
		var unit_costs = _get_unit_costs(unit_type)
		
		for resource_type in unit_costs:
			var cost = unit_costs[resource_type] * count
			total_cost[resource_type] = total_cost.get(resource_type, 0) + cost
	
	# Update player status modal to show resource changes
	_update_player_status_modal()

func _on_recruit_button_pressed(unit_type: SoldierTypeEnum.Type) -> void:
	var count: int = recruitment_counts.get(unit_type, 0)
	if count <= 0:
		return
	sound_manager.play_recruit_sound()
	_apply_recruitment_for_unit(unit_type, count)
	if target_army != null:
		target_army.spend_movement_points(1)
		DebugLogger.log("UISystem", "Army " + str(target_army.number) + " spent 1 movement point for recruitment (remaining: " + str(target_army.get_movement_points()) + ")")
	recruitment_counts.erase(unit_type)
	_update_costs()
	_update_recruitment_display()
	_update_total_row()
	_update_player_status_modal()

func _on_recruit_all_pressed() -> void:
	if recruitment_counts.is_empty():
		return
	sound_manager.play_recruit_sound()
	emit_signal("recruit_all_target_reached")
	_apply_recruitment()
	if target_army != null:
		target_army.spend_movement_points(1)
		DebugLogger.log("UISystem", "Army " + str(target_army.number) + " spent 1 movement point for recruitment (remaining: " + str(target_army.get_movement_points()) + ")")
	recruitment_counts.clear()
	total_cost.clear()
	_update_recruitment_display()
	_update_total_row()
	_update_player_status_modal()
	hide_modal()

func _apply_recruitment_for_unit(unit_type: SoldierTypeEnum.Type, count: int) -> void:
	if target_army != null:
		target_army.add_soldiers(unit_type, count)
	else:
		target_region.garrison.add_soldiers(unit_type, count)
	game_manager.record_hired_units(_get_recruit_owner_id(), {unit_type: count})
	_deduct_recruits_from_pool(count)
	_refresh_info_modal_after_recruit()

func _refresh_info_modal_after_recruit() -> void:
	if not info_modal.visible:
		return
	if target_army != null:
		info_modal.show_army_info(target_army, false)
	else:
		info_modal.show_region_info(target_region, false, false)

func _on_continue_pressed() -> void:
	"""Handle Continue button press"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	hide_modal()

func _apply_recruitment() -> void:
	"""Apply the recruitment to the army/garrison and region"""
	# Add soldiers to army or garrison
	game_manager.record_hired_units(_get_recruit_owner_id(), recruitment_counts)
	for unit_type in recruitment_counts:
		var count = recruitment_counts[unit_type]
		if target_army != null:
			# Recruiting to specific army
			target_army.add_soldiers(unit_type, count)
		else:
			# Recruiting to region garrison
			target_region.garrison.add_soldiers(unit_type, count)
	
	# Remove recruits from region
	var total_recruited = 0
	for count in recruitment_counts.values():
		total_recruited += count
	
	_deduct_recruits_from_pool(total_recruited)
	_refresh_info_modal_after_recruit()
	
	# Resources have already been deducted in real-time, no need to deduct again

func _deduct_unit_cost(unit_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Immediately deduct resources for hiring units"""
	var unit_costs = _get_unit_costs(unit_type)
	for resource_type in unit_costs:
		var cost = unit_costs[resource_type] * count
		if cost > 0:
			player_manager.spend_resource(resource_type, cost)
	
	# Update player status modal to show the change
	_update_player_status_modal()

func _refund_unit_cost(unit_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Immediately refund resources for unhiring units"""
	var unit_costs = _get_unit_costs(unit_type)
	for resource_type in unit_costs:
		var refund = unit_costs[resource_type] * count
		if refund > 0:
			player_manager.add_resources_to_player(player_manager.current_player_id, resource_type, refund)
	
	# Update player status modal to show the change
	_update_player_status_modal()

func _update_player_status_modal() -> void:
	"""Update the player status modal to reflect current resource costs"""
	GlobalSignals.emit_signal("player_status_refresh_requested")

func _get_recruit_owner_id() -> int:
	if target_army != null:
		return target_army.get_player_id()
	return target_region.get_region_owner()

func _uses_neighbor_recruits() -> bool:
	return target_region.get_castle_type() != CastleTypeEnum.Type.NONE

func _get_pooled_available_recruits() -> int:
	if not _uses_neighbor_recruits():
		return target_region.get_available_recruits()
	var owner_id: int = _get_recruit_owner_id()
	return region_manager.get_available_recruits_total_from_region_and_neighbors(target_region.get_region_id(), owner_id)

func _deduct_recruits_from_pool(total_recruited: int) -> void:
	if not _uses_neighbor_recruits():
		target_region.hire_recruits(total_recruited)
		return
	var owner_id: int = _get_recruit_owner_id()
	region_manager.deduct_recruits_proportionally_from_region_and_neighbors(target_region.get_region_id(), owner_id, total_recruited)

func _apply_standard_theme(label: Label) -> void:
	"""Apply standard theme to a label"""
	label.theme = preload("res://themes/standard_text_theme.tres")
	label.add_theme_color_override("font_color", Color.WHITE)
