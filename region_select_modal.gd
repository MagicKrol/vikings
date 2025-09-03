extends ActionModalBase
class_name RegionSelectModal

# Current region
var current_region: Region = null

# Additional references specific to region actions
var select_modal: GeneralSelectModal = null
var recruitment_modal: RecruitmentModal = null
var call_to_arms_modal: CallToArmsModal = null
var message_modal: MessageModal = null
var army_manager: ArmyManager = null
var player_manager: PlayerManagerNode = null
var region_manager: RegionManager = null
var game_manager: GameManager = null

func _ready():
	super._ready()
	_setup_region_references()

func _setup_region_references():
	select_modal = get_node("../GeneralSelectModal") as GeneralSelectModal
	recruitment_modal = get_node("../RecruitmentModal") as RecruitmentModal
	call_to_arms_modal = get_node("../CallToArmsModal") as CallToArmsModal
	message_modal = get_node("../MessageModal") as MessageModal
	
	var click_manager = get_node("../../ClickManager")
	if click_manager and click_manager.has_method("get_army_manager"):
		army_manager = click_manager.get_army_manager()
	
	player_manager = get_node("../../PlayerManager") as PlayerManagerNode
	game_manager = get_node("../../GameManager") as GameManager
	if game_manager != null:
		region_manager = game_manager.get_region_manager()

func show_region_actions(region: Region) -> void:
	if region == null:
		hide_modal()
		return
	
	current_region = region
	_create_action_buttons()
	visible = true
	
	if ui_manager:
		ui_manager.set_modal_active(true)
	
	if info_modal != null and current_region != null:
		info_modal.show_region_info(current_region, false)

func hide_modal() -> void:
	super.hide_modal()
	current_region = null

func _create_action_buttons() -> void:
	_clear_buttons()
	
	var font: Font = load("res://fonts/Cinzel.ttf")
	var buttons_to_add: Array[Dictionary] = []
	
	# Header button
	buttons_to_add.append({
		"text": "Select Action",
		"enabled": true,
		"is_header": true
	})
	
	# Promote Region button (only if can be promoted)
	if current_region != null and current_region.get_region_level() < RegionLevelEnum.Level.L5:
		var can_afford = _can_player_afford_promotion(current_region.get_region_level() + 1)
		buttons_to_add.append({
			"text": "Promote Region",
			"enabled": can_afford,
			"action": "_on_promote_region_pressed",
			"tooltip": "_on_promote_tooltip_hovered"
		})
	
	# Recruit Soldiers button
	buttons_to_add.append({
		"text": "Recruit Soldiers",
		"enabled": true,
		"action": "_on_recruit_soldiers_pressed",
		"tooltip": "_on_tooltip_hovered.bind('recruit_soldiers_garrison')"
	})
	
	# Build Castle button
	if current_region != null:
		var castle_data = _get_castle_button_data()
		buttons_to_add.append(castle_data)
	
	# Call To Arms button
	var has_castle = current_region != null and current_region.get_castle_type() != CastleTypeEnum.Type.NONE
	buttons_to_add.append({
		"text": "Call To Arms",
		"enabled": has_castle,
		"action": "_on_call_to_arms_pressed",
		"tooltip": "_on_call_to_arms_tooltip_hovered"
	})
	
	# Ore Search button (only for hills/forest hills)
	if current_region != null and GameParameters.can_search_for_ore_in_region(current_region.get_region_type()):
		var can_search = current_region.can_search_for_ore()
		var can_afford = _can_player_afford_ore_search()
		buttons_to_add.append({
			"text": "Ore Search",
			"enabled": can_search and can_afford,
			"action": "_on_ore_search_pressed",
			"tooltip": "_on_ore_search_tooltip_hovered"
		})
	
	
	# Raise Army button
	var castle_type = current_region.get_castle_type() if current_region != null else CastleTypeEnum.Type.NONE
	var has_keep_or_higher = castle_type != CastleTypeEnum.Type.NONE and castle_type != CastleTypeEnum.Type.OUTPOST
	var can_afford_army = _can_player_afford_raise_army()
	var current_player_id = game_manager.get_current_player() if game_manager != null else 1
	var has_army_already = _region_has_army_for_player(current_player_id)
	var army_text = "Raise Army" if has_army_already else "Raise Army"
	
	buttons_to_add.append({
		"text": army_text,
		"enabled": has_keep_or_higher and can_afford_army and not has_army_already,
		"action": "_on_raise_army_pressed",
		"tooltip": "_on_raise_army_tooltip_hovered"
	})
	
	# Back button (only if armies in region)
	var armies_in_region: Array[Army] = []
	if current_region != null:
		for child in current_region.get_children():
			if child is Army:
				armies_in_region.append(child as Army)
	
	if not armies_in_region.is_empty():
		buttons_to_add.append({
			"text": "Back",
			"enabled": true,
			"action": "_on_back_pressed",
			"tooltip": "_on_tooltip_hovered.bind('back')"
		})
	
	_resize_modal(buttons_to_add.size())
	
	# Create buttons
	for i in buttons_to_add.size():
		var button_data = buttons_to_add[i]
		var is_first = i == 0
		var is_last = i == buttons_to_add.size() - 1
		
		var button: Button
		
		# Check if it's a header button
		if button_data.has("is_header") and button_data.is_header:
			button = _make_button(button_data.text, is_first, is_last, font)
			button.disabled = true
		# Check if it's a disabled action button
		elif not button_data.enabled:
			button = _make_disabled_action_button(button_data.text, is_first, is_last, font)
		# Regular enabled button
		else:
			button = _make_button(button_data.text, is_first, is_last, font)
			if button_data.has("action"):
				button.pressed.connect(Callable(self, button_data.action))
		
		if button_data.has("tooltip"):
			if button_data.tooltip is String:
				button.mouse_entered.connect(_on_tooltip_hovered.bind(button_data.tooltip))
			else:
				button.mouse_entered.connect(button_data.tooltip)
			button.mouse_exited.connect(_on_tooltip_unhovered)
		
		button_container.add_child(button)
		
		if not is_last:
			_add_separator()

func _get_castle_button_data() -> Dictionary:
	var castle_type = current_region.get_castle_type()
	var under_construction = current_region.is_castle_under_construction()
	
	if under_construction:
		var turns_remaining = current_region.get_castle_build_turns_remaining()
		var castle_being_built = current_region.get_castle_under_construction()
		return {
			"text": "Building " + CastleTypeEnum.type_to_string(castle_being_built) + " (" + str(turns_remaining) + " turns)",
			"enabled": false,
			"tooltip": "_on_castle_tooltip_hovered.bind('castle_construction')"
		}
	elif castle_type == CastleTypeEnum.Type.NONE:
		var can_afford = _can_player_afford_any_castle()
		return {
			"text": "Build Outpost",
			"enabled": can_afford and current_region.can_build_castle(),
			"action": "_on_build_castle_pressed",
			"tooltip": "_on_castle_tooltip_hovered.bind('build_castle')"
		}
	else:
		var next_castle_type = CastleTypeEnum.get_next_level(castle_type)
		if next_castle_type != CastleTypeEnum.Type.NONE:
			var can_afford = _can_player_afford_castle(next_castle_type)
			return {
				"text": "Upgrade to " + CastleTypeEnum.type_to_string(next_castle_type),
				"enabled": can_afford and current_region.can_upgrade_castle(),
				"action": "_on_upgrade_castle_pressed",
				"tooltip": "_on_castle_tooltip_hovered.bind('upgrade_castle')"
			}
		else:
			return {
				"text": "Castle at Maximum Level",
				"enabled": false,
				"tooltip": "_on_castle_tooltip_hovered.bind('castle_max_level')"
			}

func _on_promote_region_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	if current_region == null:
		DebugLogger.log("UISystem", "Error: No current region")
		return
	
	var current_level = current_region.get_region_level()
	if current_level >= RegionLevelEnum.Level.L5:
		return
	
	var next_level = current_level + 1
	var promotion_cost = GameParameters.get_promotion_cost(next_level)
	if promotion_cost.is_empty():
		return
	
	if player_manager == null:
		return
	
	var current_player = player_manager.get_player(1)
	if current_player == null or not current_player.pay_cost(promotion_cost):
		return
	
	current_region.set_region_level(next_level)
	
	if region_manager != null:
		region_manager.generate_region_resources(current_region)
	
	if info_modal != null and info_modal.visible:
		info_modal.show_region_info(current_region, false)

func _on_recruit_soldiers_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	var region_to_recruit = current_region
	hide_modal()
	
	if recruitment_modal != null and region_to_recruit != null and is_instance_valid(recruitment_modal) and is_instance_valid(region_to_recruit):
		recruitment_modal.show_region_recruitment(region_to_recruit)

func _on_build_castle_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	if current_region == null or not current_region.can_build_castle():
		return
	
	_start_castle_construction(CastleTypeEnum.Type.OUTPOST)

func _on_upgrade_castle_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	if current_region == null or not current_region.can_upgrade_castle():
		return
	
	var current_castle_type = current_region.get_castle_type()
	var next_castle_type = CastleTypeEnum.get_next_level(current_castle_type)
	
	if next_castle_type != CastleTypeEnum.Type.NONE:
		_start_castle_construction(next_castle_type)

func _start_castle_construction(castle_type: CastleTypeEnum.Type) -> void:
	var construction_cost = GameParameters.get_castle_building_cost(castle_type)
	if construction_cost.is_empty() or player_manager == null:
		return
	
	var current_player = player_manager.get_player(1)
	if current_player == null or not current_player.pay_cost(construction_cost):
		return
	
	current_region.start_castle_construction(castle_type)
	
	if info_modal != null and info_modal.visible:
		info_modal.show_region_info(current_region, false)
	
	_create_action_buttons()

func _on_call_to_arms_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	var region_for_call_to_arms = current_region
	hide_modal()
	
	if call_to_arms_modal != null and region_for_call_to_arms != null and is_instance_valid(call_to_arms_modal) and is_instance_valid(region_for_call_to_arms):
		call_to_arms_modal.show_call_to_arms(region_for_call_to_arms)

func _on_ore_search_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	if current_region == null or region_manager == null or player_manager == null:
		return
	
	var search_result = region_manager.perform_ore_search(current_region, 1, player_manager)
	
	if search_result.success and message_modal != null and search_result.has("ore_type"):
		var ore_type = search_result.ore_type
		var ore_type_string = ResourcesEnum.type_to_string(ore_type)
		var ore_amount = current_region.get_resource_amount(ore_type)
		var header = ore_type_string.capitalize() + " Found!"
		var message = "Ore size was estimated to " + str(ore_amount) + " units."
		message_modal.display_message(header, message)
	elif not search_result.success and message_modal != null:
		var header = "Ore Search"
		var remaining_attempts = current_region.get_ore_search_attempts_remaining()
		var message: String
		
		if remaining_attempts > 0:
			message = "No luck this time. " + str(remaining_attempts) + " search attempts remaining."
		else:
			message = "Ore searches exhausted. This region contains no accessible ore deposits."
		
		message_modal.display_message(header, message)
	
	if info_modal != null and info_modal.visible:
		info_modal.show_region_info(current_region, false)
	
	_create_action_buttons()

func _on_raise_army_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	if player_manager == null or current_region == null or army_manager == null:
		return
	
	var current_player = player_manager.get_player(game_manager.get_current_player())
	if current_player == null:
		return
	
	var raise_army_cost = GameParameters.get_raise_army_cost()
	if current_player.get_resource_amount(ResourcesEnum.Type.GOLD) < raise_army_cost:
		return
	
	current_player.remove_resources(ResourcesEnum.Type.GOLD, raise_army_cost)
	var new_army = army_manager.create_raised_army(current_region, game_manager.get_current_player())
	
	if new_army != null:
		if message_modal != null:
			var header = "Army Raised"
			var army_name = new_army.name if new_army.name else "New Army"
			var message = army_name + " has been raised in " + current_region.get_region_name() + " and will be ready next turn."
			message_modal.display_message(header, message)
		
		if info_modal != null and info_modal.visible:
			info_modal.show_region_info(current_region, false)
		
		_create_action_buttons()
	else:
		current_player.add_resources(ResourcesEnum.Type.GOLD, raise_army_cost)

func _on_back_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	var region_to_show = current_region
	var armies_in_region: Array[Army] = []
	
	if region_to_show != null:
		for child in region_to_show.get_children():
			if child is Army:
				armies_in_region.append(child as Army)
	
	hide_modal()
	
	if select_modal != null and region_to_show != null and is_instance_valid(select_modal) and is_instance_valid(region_to_show):
		select_modal.show_selection(region_to_show, armies_in_region)

func _on_promote_tooltip_hovered() -> void:
	if select_tooltip_modal != null and current_region != null:
		var context_data = {"current_region": current_region}
		select_tooltip_modal.show_tooltip("promote_region", context_data)

func _on_castle_tooltip_hovered(tooltip_key: String) -> void:
	if select_tooltip_modal != null and current_region != null:
		var context_data = {"current_region": current_region}
		select_tooltip_modal.show_tooltip(tooltip_key, context_data)

func _on_call_to_arms_tooltip_hovered() -> void:
	if select_tooltip_modal != null and current_region != null:
		var context_data = {"current_region": current_region}
		select_tooltip_modal.show_tooltip("call_to_arms", context_data)

func _on_raise_army_tooltip_hovered() -> void:
	if select_tooltip_modal != null and current_region != null:
		var context_data = {"current_region": current_region}
		select_tooltip_modal.show_tooltip("raise_army", context_data)

func _on_ore_search_tooltip_hovered() -> void:
	if select_tooltip_modal != null and current_region != null:
		var context_data = {"current_region": current_region}
		select_tooltip_modal.show_tooltip("ore_search", context_data)

func _can_player_afford_promotion(target_level: RegionLevelEnum.Level) -> bool:
	if player_manager == null:
		return false
	
	var current_player = player_manager.get_player(1)
	if current_player == null:
		return false
	
	var player_resources = {
		ResourcesEnum.Type.GOLD: current_player.get_resource_amount(ResourcesEnum.Type.GOLD),
		ResourcesEnum.Type.FOOD: current_player.get_resource_amount(ResourcesEnum.Type.FOOD),
		ResourcesEnum.Type.WOOD: current_player.get_resource_amount(ResourcesEnum.Type.WOOD),
		ResourcesEnum.Type.IRON: current_player.get_resource_amount(ResourcesEnum.Type.IRON),
		ResourcesEnum.Type.STONE: current_player.get_resource_amount(ResourcesEnum.Type.STONE)
	}
	
	return GameParameters.can_afford_promotion(target_level, player_resources)

func _can_player_afford_castle(castle_type: CastleTypeEnum.Type) -> bool:
	if player_manager == null:
		return false
	
	var current_player = player_manager.get_player(1)
	if current_player == null:
		return false
	
	var player_resources = {
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
	if player_manager == null:
		return false
	
	var current_player = player_manager.get_player(1)
	if current_player == null:
		return false
	
	var search_cost = GameParameters.get_ore_search_cost()
	return current_player.get_resource_amount(ResourcesEnum.Type.GOLD) >= search_cost

func _can_player_afford_raise_army() -> bool:
	if player_manager == null:
		return false
	
	var current_player = player_manager.get_player(1)
	if current_player == null:
		return false
	
	var raise_army_cost = GameParameters.get_raise_army_cost()
	return current_player.get_resource_amount(ResourcesEnum.Type.GOLD) >= raise_army_cost

func _region_has_army_for_player(player_id: int) -> bool:
	if current_region == null:
		return false
	
	for child in current_region.get_children():
		if child is Army:
			var army = child as Army
			if army.get_player_id() == player_id:
				return true
	
	return false
