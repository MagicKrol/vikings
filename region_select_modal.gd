extends Control
class_name RegionSelectModal

# Styling constants (same as other modals)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# UI elements
@onready var button_container: VBoxContainer = $ButtonContainer

# Current region
var current_region: Region = null

# Sound manager reference
var sound_manager: SoundManager = null
# UI manager reference for modal mode
var ui_manager: UIManager = null
# References to other modals
var select_modal: SelectModal = null
var info_modal: InfoModal = null
var recruitment_modal: RecruitmentModal = null
var call_to_arms_modal: CallToArmsModal = null
var select_tooltip_modal: SelectTooltipModal = null
var message_modal: MessageModal = null
# Army manager reference for army creation
var army_manager: ArmyManager = null
# Player manager reference for resource management
var player_manager: PlayerManagerNode = null
# Region manager reference for ore search
var region_manager: RegionManager = null
# Game manager reference for current player
var game_manager: GameManager = null

func _ready():
	# Get sound manager reference
	sound_manager = get_node("../../SoundManager") as SoundManager
	
	# Get UI manager reference
	ui_manager = get_node("../UIManager") as UIManager
	
	# Get reference to SelectModal
	select_modal = get_node("../SelectModal") as SelectModal
	
	# Get reference to InfoModal
	info_modal = get_node("../InfoModal") as InfoModal
	
	# Get reference to RecruitmentModal
	recruitment_modal = get_node("../RecruitmentModal") as RecruitmentModal
	
	# Get reference to CallToArmsModal
	call_to_arms_modal = get_node("../CallToArmsModal") as CallToArmsModal
	
	# Get reference to SelectTooltipModal
	select_tooltip_modal = get_node("../SelectTooltipModal") as SelectTooltipModal
	
	# Get reference to MessageModal
	message_modal = get_node("../MessageModal") as MessageModal
	
	# Get army manager reference from ClickManager
	var click_manager = get_node("../../ClickManager")
	if click_manager and click_manager.has_method("get_army_manager"):
		army_manager = click_manager.get_army_manager()
	
	# Get player manager reference
	player_manager = get_node("../../PlayerManager") as PlayerManagerNode
	
	# Get region manager reference from GameManager
	game_manager = get_node("../../GameManager") as GameManager
	if game_manager != null:
		region_manager = game_manager.get_region_manager()
	
	# Initially hidden
	visible = false

func show_region_actions(region: Region) -> void:
	"""Show the region action modal"""
	if region == null:
		hide_modal()
		return
	
	current_region = region
	_create_action_buttons()
	visible = true
	
	# Set modal mode active
	if ui_manager:
		ui_manager.set_modal_active(true)
	
	# Always show the region info in InfoModal
	if info_modal != null and current_region != null:
		info_modal.show_region_info(current_region, false)  # Don't manage modal mode

func hide_modal() -> void:
	"""Hide the modal and clear content"""
	# Hide the InfoModal first
	if info_modal != null and info_modal.visible:
		info_modal.hide_modal(false)  # Don't manage modal mode
	
	current_region = null
	_clear_buttons()
	visible = false
	
	# Set modal mode inactive
	if ui_manager:
		ui_manager.set_modal_active(false)

func _create_action_buttons() -> void:
	"""Create action buttons for the region"""
	_clear_buttons()
	
	# Promote Region button (moved to top, only show if region can be promoted)
	if current_region != null and current_region.get_region_level() < RegionLevelEnum.Level.L5:
		var promote_button = Button.new()
		promote_button.text = "Promote Region"
		promote_button.custom_minimum_size = Vector2(260, 40)
		
		# Check if player can afford promotion
		var next_level = current_region.get_region_level() + 1
		var can_afford = _can_player_afford_promotion(next_level)
		
		if can_afford:
			promote_button.add_theme_color_override("font_color", Color.WHITE)
		else:
			# Gray out button if player can't afford it
			promote_button.add_theme_color_override("font_color", Color.GRAY)
			promote_button.disabled = true
		
		promote_button.pressed.connect(_on_promote_region_pressed)
		promote_button.mouse_entered.connect(_on_promote_tooltip_hovered)
		promote_button.mouse_exited.connect(_on_tooltip_unhovered)
		button_container.add_child(promote_button)
	
	# Recruit Soldiers button
	var recruit_button = Button.new()
	recruit_button.text = "Recruit Soldiers"
	recruit_button.custom_minimum_size = Vector2(260, 40)
	recruit_button.add_theme_color_override("font_color", Color.WHITE)
	recruit_button.pressed.connect(_on_recruit_soldiers_pressed)
	recruit_button.mouse_entered.connect(_on_tooltip_hovered.bind("recruit_soldiers_garrison"))
	recruit_button.mouse_exited.connect(_on_tooltip_unhovered)
	button_container.add_child(recruit_button)
	
	# Build Castle button - dynamic based on current castle state
	if current_region != null:
		var build_castle_button = Button.new()
		build_castle_button.custom_minimum_size = Vector2(260, 40)
		
		# Determine button text and functionality based on castle state
		var castle_type = current_region.get_castle_type()
		var under_construction = current_region.is_castle_under_construction()
		
		if under_construction:
			# Castle under construction
			var turns_remaining = current_region.get_castle_build_turns_remaining()
			var castle_being_built = current_region.get_castle_under_construction()
			build_castle_button.text = "Building " + CastleTypeEnum.type_to_string(castle_being_built) + " (" + str(turns_remaining) + " turns)"
			build_castle_button.add_theme_color_override("font_color", Color.GRAY)
			build_castle_button.disabled = true
			build_castle_button.mouse_entered.connect(_on_castle_tooltip_hovered.bind("castle_construction"))
		elif castle_type == CastleTypeEnum.Type.NONE:
			# No castle - show build options
			build_castle_button.text = "Build Outpost"
			# Check if player can afford any castle type
			var can_afford_any = _can_player_afford_any_castle()
			if can_afford_any and current_region.can_build_castle():
				build_castle_button.add_theme_color_override("font_color", Color.WHITE)
			else:
				build_castle_button.add_theme_color_override("font_color", Color.GRAY)
				build_castle_button.disabled = true
			build_castle_button.pressed.connect(_on_build_castle_pressed)
			build_castle_button.mouse_entered.connect(_on_castle_tooltip_hovered.bind("build_castle"))
		else:
			# Has castle - show upgrade option
			var next_castle_type = CastleTypeEnum.get_next_level(castle_type)
			if next_castle_type != CastleTypeEnum.Type.NONE:
				build_castle_button.text = "Upgrade to " + CastleTypeEnum.type_to_string(next_castle_type)
				# Check if player can afford upgrade
				var can_afford_upgrade = _can_player_afford_castle(next_castle_type)
				if can_afford_upgrade and current_region.can_upgrade_castle():
					build_castle_button.add_theme_color_override("font_color", Color.WHITE)
				else:
					build_castle_button.add_theme_color_override("font_color", Color.GRAY)
					build_castle_button.disabled = true
				build_castle_button.pressed.connect(_on_upgrade_castle_pressed)
				build_castle_button.mouse_entered.connect(_on_castle_tooltip_hovered.bind("upgrade_castle"))
			else:
				# Already at max level
				build_castle_button.text = "Castle at Maximum Level"
				build_castle_button.add_theme_color_override("font_color", Color.GRAY)
				build_castle_button.disabled = true
				build_castle_button.mouse_entered.connect(_on_castle_tooltip_hovered.bind("castle_max_level"))
		
		build_castle_button.mouse_exited.connect(_on_tooltip_unhovered)
		button_container.add_child(build_castle_button)
	
	
	# Call To Arms button - only available if region has a castle
	var call_arms_button = Button.new()
	call_arms_button.text = "Call To Arms"
	call_arms_button.custom_minimum_size = Vector2(260, 40)
	
	# Check if region has any level of castle
	if current_region != null and current_region.get_castle_type() != CastleTypeEnum.Type.NONE:
		call_arms_button.add_theme_color_override("font_color", Color.WHITE)
		call_arms_button.pressed.connect(_on_call_to_arms_pressed)
	else:
		# Gray out button if no castle
		call_arms_button.add_theme_color_override("font_color", Color.GRAY)
		call_arms_button.disabled = true
	
	call_arms_button.mouse_entered.connect(_on_call_to_arms_tooltip_hovered)
	call_arms_button.mouse_exited.connect(_on_tooltip_unhovered)
	button_container.add_child(call_arms_button)
	
	# Ore Search button - only show if region can have ores
	if current_region != null and GameParameters.can_search_for_ore_in_region(current_region.get_region_type()):
		var ore_search_button = Button.new()
		ore_search_button.text = "Ore Search"
		ore_search_button.custom_minimum_size = Vector2(260, 40)
		
		# Check if ore search is available
		var can_search = current_region.can_search_for_ore()
		var can_afford = _can_player_afford_ore_search()
		
		if can_search and can_afford:
			ore_search_button.add_theme_color_override("font_color", Color.WHITE)
			ore_search_button.pressed.connect(_on_ore_search_pressed)
		else:
			# Gray out button if cannot search or afford
			ore_search_button.add_theme_color_override("font_color", Color.GRAY)
			ore_search_button.disabled = true
		
		ore_search_button.mouse_entered.connect(_on_ore_search_tooltip_hovered)
		ore_search_button.mouse_exited.connect(_on_tooltip_unhovered)
		button_container.add_child(ore_search_button)
	
	# Back button (only show if there are armies in the region)
	var armies_in_region: Array[Army] = []
	if current_region != null:
		for child in current_region.get_children():
			if child is Army:
				armies_in_region.append(child as Army)
	
	if not armies_in_region.is_empty():
		var back_button = Button.new()
		back_button.text = "Back"
		back_button.custom_minimum_size = Vector2(260, 40)
		back_button.add_theme_color_override("font_color", Color.WHITE)
		back_button.pressed.connect(_on_back_pressed)
		back_button.mouse_entered.connect(_on_tooltip_hovered.bind("back"))
		back_button.mouse_exited.connect(_on_tooltip_unhovered)
		button_container.add_child(back_button)
	
	# Raise Army button (moved to bottom) - requires Keep or higher castle level and gold cost
	var raise_army_button = Button.new()
	raise_army_button.text = "Raise Army"
	raise_army_button.custom_minimum_size = Vector2(260, 40)
	
	# Check if region has Keep or higher castle level
	var castle_type = current_region.get_castle_type() if current_region != null else CastleTypeEnum.Type.NONE
	var has_keep_or_higher = castle_type != CastleTypeEnum.Type.NONE and castle_type != CastleTypeEnum.Type.OUTPOST
	var can_afford = _can_player_afford_raise_army()
	
	# Check if region already has an army for the current player
	var current_player_id = game_manager.get_current_player() if game_manager != null else 1
	var has_army_already = _region_has_army_for_player(current_player_id)
	
	if has_keep_or_higher and can_afford and not has_army_already:
		raise_army_button.add_theme_color_override("font_color", Color.WHITE)
		raise_army_button.pressed.connect(_on_raise_army_pressed)
	else:
		# Gray out button if no Keep or higher, insufficient gold, or army already exists
		raise_army_button.add_theme_color_override("font_color", Color.GRAY)
		raise_army_button.disabled = true
		
		# Update button text to show why it's disabled
		if has_army_already:
			raise_army_button.text = "Army Already Raised"
	
	raise_army_button.mouse_entered.connect(_on_raise_army_tooltip_hovered)
	raise_army_button.mouse_exited.connect(_on_tooltip_unhovered)
	button_container.add_child(raise_army_button)

func _draw():
	# Draw shadow first (behind everything)
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)
	
	# Draw black border
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)

func _clear_buttons() -> void:
	"""Remove all buttons from container"""
	for child in button_container.get_children():
		child.queue_free()

func _on_raise_army_pressed() -> void:
	"""Handle Raise Army button - create new army with 0 movement and 0 soldiers"""
	DebugLogger.log("UISystem", "Raise Army button pressed!")
	
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Debug: Check references
	DebugLogger.log("UISystem", "army_manager: " + str(army_manager))
	DebugLogger.log("UISystem", "current_region: " + str(current_region))
	if current_region:
		DebugLogger.log("UISystem", "current_region name: " + current_region.get_region_name())
	
	# Check if player can afford the raise army cost
	if player_manager == null:
		DebugLogger.log("UISystem", "Error: Player manager not found")
		return
	
	var current_player = player_manager.get_player(game_manager.get_current_player())
	if current_player == null:
		DebugLogger.log("UISystem", "Error: Current player not found")
		return
	
	var raise_army_cost = GameParameters.get_raise_army_cost()
	if current_player.get_resource_amount(ResourcesEnum.Type.GOLD) < raise_army_cost:
		DebugLogger.log("UISystem", "Cannot afford to raise army - insufficient gold")
		return
	
	# Create a new raised army in the current region
	if army_manager != null and current_region != null:
		DebugLogger.log("UISystem", "Attempting to create raised army...")
		
		# Deduct the cost first
		current_player.remove_resources(ResourcesEnum.Type.GOLD, raise_army_cost)
		DebugLogger.log("UISystem", "Player spent " + str(raise_army_cost) + " gold to raise army")
		
		# Use current player ID from GameManager
		var new_army = army_manager.create_raised_army(current_region, game_manager.get_current_player())
		
		if new_army != null:
			DebugLogger.log("UISystem", "Successfully raised new army in region: " + current_region.get_region_name())
			
			# Show success message modal
			if message_modal != null:
				var header = "Army Raised"
				var army_name = new_army.name if new_army.name else "New Army"
				var message = army_name + " has been raised in " + current_region.get_region_name() + " and will be ready next turn."
				message_modal.display_message(header, message)
			
			# Update InfoModal if it's showing region info to reflect the change
			if info_modal != null and info_modal.visible:
				info_modal.show_region_info(current_region, false)  # Don't manage modal mode
			
			# Refresh the buttons to disable raise army button
			_create_action_buttons()
		else:
			# Failed to create army, refund the gold
			current_player.add_resources(ResourcesEnum.Type.GOLD, raise_army_cost)
			DebugLogger.log("UISystem", "Failed to raise army - region may already have an army (refunded gold)")
	else:
		DebugLogger.log("UISystem", "Cannot raise army - missing army_manager or current_region")
		if army_manager == null:
			DebugLogger.log("UISystem", "- army_manager is null")
		if current_region == null:
			DebugLogger.log("UISystem", "- current_region is null")

func _on_recruit_soldiers_pressed() -> void:
	"""Handle Recruit Soldiers button - open recruitment modal for region garrison"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Store region reference before hiding modal
	var region_to_recruit = current_region
	
	# Hide this modal
	hide_modal()
	
	# Show recruitment modal for region garrison
	if recruitment_modal != null and region_to_recruit != null and is_instance_valid(recruitment_modal) and is_instance_valid(region_to_recruit):
		recruitment_modal.show_region_recruitment(region_to_recruit)

func _on_build_castle_pressed() -> void:
	"""Handle Build Castle button - build first castle (Outpost)"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	if current_region == null:
		DebugLogger.log("UISystem", "Error: No current region")
		return
	
	DebugLogger.log("UISystem", "Build Castle clicked for region: " + current_region.get_region_name())
	
	# Check if castle can be built
	if not current_region.can_build_castle():
		DebugLogger.log("UISystem", "Cannot build castle in this region")
		return
	
	# Build the first castle type (Outpost)
	var castle_type_to_build = CastleTypeEnum.Type.OUTPOST
	_start_castle_construction(castle_type_to_build)

func _on_upgrade_castle_pressed() -> void:
	"""Handle Castle Upgrade button - upgrade to next castle level"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	if current_region == null:
		DebugLogger.log("UISystem", "Error: No current region")
		return
	
	DebugLogger.log("UISystem", "Upgrade Castle clicked for region: " + current_region.get_region_name())
	
	# Check if castle can be upgraded
	if not current_region.can_upgrade_castle():
		DebugLogger.log("UISystem", "Cannot upgrade castle in this region")
		return
	
	# Get next castle level
	var current_castle_type = current_region.get_castle_type()
	var next_castle_type = CastleTypeEnum.get_next_level(current_castle_type)
	
	if next_castle_type == CastleTypeEnum.Type.NONE:
		DebugLogger.log("UISystem", "Castle already at maximum level")
		return
	
	_start_castle_construction(next_castle_type)

func _start_castle_construction(castle_type: CastleTypeEnum.Type) -> void:
	"""Start construction of specified castle type"""
	# Get construction cost
	var construction_cost = GameParameters.get_castle_building_cost(castle_type)
	if construction_cost.is_empty():
		DebugLogger.log("UISystem", "Error: No construction cost defined for castle type " + str(castle_type))
		return
	
	DebugLogger.log("UISystem", "Construction cost: " + str(construction_cost))
	
	# Check if player can afford the construction
	if player_manager == null:
		DebugLogger.log("UISystem", "Error: Player manager not found")
		return
	
	# Get current player (assuming player 1 for now)
	var current_player = player_manager.get_player(1)
	if current_player == null:
		DebugLogger.log("UISystem", "Error: Current player not found")
		return
	
	# Get player resources as dictionary
	var player_resources = {
		ResourcesEnum.Type.GOLD: current_player.get_resource_amount(ResourcesEnum.Type.GOLD),
		ResourcesEnum.Type.FOOD: current_player.get_resource_amount(ResourcesEnum.Type.FOOD),
		ResourcesEnum.Type.WOOD: current_player.get_resource_amount(ResourcesEnum.Type.WOOD),
		ResourcesEnum.Type.IRON: current_player.get_resource_amount(ResourcesEnum.Type.IRON),
		ResourcesEnum.Type.STONE: current_player.get_resource_amount(ResourcesEnum.Type.STONE)
	}
	
	# Check if player can afford construction
	if not GameParameters.can_afford_castle(castle_type, player_resources):
		DebugLogger.log("UISystem", "Cannot afford castle construction - insufficient resources")
		return
	
	# Deduct resources from player
	if not current_player.pay_cost(construction_cost):
		DebugLogger.log("UISystem", "Error: Failed to pay construction cost")
		return
	
	# Start castle construction
	current_region.start_castle_construction(castle_type)
	DebugLogger.log("UISystem", "Successfully started construction of " + CastleTypeEnum.type_to_string(castle_type) + " in " + current_region.get_region_name())
	
	# Update InfoModal to reflect the change
	if info_modal != null and info_modal.visible:
		info_modal.show_region_info(current_region, false)  # Refresh display
	
	# Refresh the buttons to show new state
	_create_action_buttons()

func _on_promote_region_pressed() -> void:
	"""Handle Promote Region button - upgrade region level"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	if current_region == null:
		DebugLogger.log("UISystem", "Error: No current region")
		return
	
	DebugLogger.log("UISystem", "Promote Region clicked for region: " + current_region.get_region_name())
	
	# Get current region level
	var current_level = current_region.get_region_level()
	DebugLogger.log("UISystem", "Current level: " + str(current_level))
	
	# Check if region is already at maximum level
	if current_level >= RegionLevelEnum.Level.L5:
		DebugLogger.log("UISystem", "Region is already at maximum level (L5)")
		return
	
	# Calculate next level
	var next_level = current_level + 1
	DebugLogger.log("UISystem", "Attempting to promote to level: " + str(next_level))
	
	# Get promotion cost
	var promotion_cost = GameParameters.get_promotion_cost(next_level)
	if promotion_cost.is_empty():
		DebugLogger.log("UISystem", "Error: No promotion cost defined for level " + str(next_level))
		return
	
	DebugLogger.log("UISystem", "Promotion cost: " + str(promotion_cost))
	
	# Check if player can afford the promotion
	if player_manager == null:
		DebugLogger.log("UISystem", "Error: Player manager not found")
		return
	
	# Get current player (assuming player 1 for now - can be made dynamic)
	var current_player = player_manager.get_player(1)
	if current_player == null:
		DebugLogger.log("UISystem", "Error: Current player not found")
		return
	
	# Get player resources as dictionary
	var player_resources = {
		ResourcesEnum.Type.GOLD: current_player.get_resource_amount(ResourcesEnum.Type.GOLD),
		ResourcesEnum.Type.FOOD: current_player.get_resource_amount(ResourcesEnum.Type.FOOD),
		ResourcesEnum.Type.WOOD: current_player.get_resource_amount(ResourcesEnum.Type.WOOD),
		ResourcesEnum.Type.IRON: current_player.get_resource_amount(ResourcesEnum.Type.IRON),
		ResourcesEnum.Type.STONE: current_player.get_resource_amount(ResourcesEnum.Type.STONE)
	}
	
	# Check if player can afford promotion
	if not GameParameters.can_afford_promotion(next_level, player_resources):
		DebugLogger.log("UISystem", "Cannot afford promotion - insufficient resources")
		return
	
	# Deduct resources from player using the proper Player method
	if not current_player.pay_cost(promotion_cost):
		DebugLogger.log("UISystem", "Error: Failed to pay promotion cost")
		return
	
	# Promote the region
	current_region.set_region_level(next_level)
	
	# Regenerate resources with level bonuses
	if region_manager != null:
		region_manager.generate_region_resources(current_region)
	
	# Update InfoModal to reflect the change
	if info_modal != null and info_modal.visible:
		info_modal.show_region_info(current_region, false)  # Refresh display

func _on_call_to_arms_pressed() -> void:
	"""Handle Call To Arms button - open call to arms modal"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Store region reference before hiding modal
	var region_for_call_to_arms = current_region
	
	# Hide this modal
	hide_modal()
	
	# Show call to arms modal
	if call_to_arms_modal != null and region_for_call_to_arms != null and is_instance_valid(call_to_arms_modal) and is_instance_valid(region_for_call_to_arms):
		call_to_arms_modal.show_call_to_arms(region_for_call_to_arms)

func _on_back_pressed() -> void:
	"""Handle Back button - return to SelectModal"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	# Store region data before hiding modal
	var region_to_show = current_region
	var armies_in_region: Array[Army] = []
	
	if region_to_show != null:
		# Get armies in the region by searching through the region container's children
		for child in region_to_show.get_children():
			if child is Army:
				armies_in_region.append(child as Army)
	
	# Hide this modal
	hide_modal()
	
	# Show SelectModal for the current region
	if select_modal != null and region_to_show != null and is_instance_valid(select_modal) and is_instance_valid(region_to_show):
		select_modal.show_selection(region_to_show, armies_in_region)

func _on_tooltip_hovered(tooltip_key: String) -> void:
	"""Handle button hover - show tooltip"""
	if select_tooltip_modal != null:
		select_tooltip_modal.show_tooltip(tooltip_key)

func _on_promote_tooltip_hovered() -> void:
	"""Handle promote region button hover - show tooltip with cost information"""
	if select_tooltip_modal != null and current_region != null:
		var context_data = {"current_region": current_region}
		select_tooltip_modal.show_tooltip("promote_region", context_data)

func _on_castle_tooltip_hovered(tooltip_key: String) -> void:
	"""Handle castle button hover - show tooltip with context"""
	if select_tooltip_modal != null and current_region != null:
		var context_data = {"current_region": current_region}
		select_tooltip_modal.show_tooltip(tooltip_key, context_data)

func _on_call_to_arms_tooltip_hovered() -> void:
	"""Handle call to arms button hover - show tooltip with context"""
	if select_tooltip_modal != null and current_region != null:
		var context_data = {"current_region": current_region}
		select_tooltip_modal.show_tooltip("call_to_arms", context_data)

func _on_raise_army_tooltip_hovered() -> void:
	"""Handle raise army button hover - show tooltip with context"""
	if select_tooltip_modal != null and current_region != null:
		var context_data = {"current_region": current_region}
		select_tooltip_modal.show_tooltip("raise_army", context_data)

func _on_tooltip_unhovered() -> void:
	"""Handle button unhover - hide tooltip"""
	if select_tooltip_modal != null:
		select_tooltip_modal.hide_tooltip()

func _can_player_afford_promotion(target_level: RegionLevelEnum.Level) -> bool:
	"""Check if current player can afford to promote region to target level"""
	if player_manager == null:
		return false
	
	# Get current player (assuming player 1 for now)
	var current_player = player_manager.get_player(1)
	if current_player == null:
		return false
	
	# Get player resources as dictionary
	var player_resources = {
		ResourcesEnum.Type.GOLD: current_player.get_resource_amount(ResourcesEnum.Type.GOLD),
		ResourcesEnum.Type.FOOD: current_player.get_resource_amount(ResourcesEnum.Type.FOOD),
		ResourcesEnum.Type.WOOD: current_player.get_resource_amount(ResourcesEnum.Type.WOOD),
		ResourcesEnum.Type.IRON: current_player.get_resource_amount(ResourcesEnum.Type.IRON),
		ResourcesEnum.Type.STONE: current_player.get_resource_amount(ResourcesEnum.Type.STONE)
	}
	
	return GameParameters.can_afford_promotion(target_level, player_resources)

func _can_player_afford_castle(castle_type: CastleTypeEnum.Type) -> bool:
	"""Check if current player can afford to build specified castle type"""
	if player_manager == null:
		return false
	
	# Get current player (assuming player 1 for now)
	var current_player = player_manager.get_player(1)
	if current_player == null:
		return false
	
	# Get player resources as dictionary
	var player_resources = {
		ResourcesEnum.Type.GOLD: current_player.get_resource_amount(ResourcesEnum.Type.GOLD),
		ResourcesEnum.Type.FOOD: current_player.get_resource_amount(ResourcesEnum.Type.FOOD),
		ResourcesEnum.Type.WOOD: current_player.get_resource_amount(ResourcesEnum.Type.WOOD),
		ResourcesEnum.Type.IRON: current_player.get_resource_amount(ResourcesEnum.Type.IRON),
		ResourcesEnum.Type.STONE: current_player.get_resource_amount(ResourcesEnum.Type.STONE)
	}
	
	return GameParameters.can_afford_castle(castle_type, player_resources)

func _can_player_afford_any_castle() -> bool:
	"""Check if current player can afford to build any castle type"""
	# Check if player can afford the cheapest castle (Outpost)
	return _can_player_afford_castle(CastleTypeEnum.Type.OUTPOST)

func _can_player_afford_ore_search() -> bool:
	"""Check if current player can afford ore search"""
	if player_manager == null:
		return false
	
	# Get current player (assuming player 1 for now)
	var current_player = player_manager.get_player(1)
	if current_player == null:
		return false
	
	var search_cost = GameParameters.get_ore_search_cost()
	return current_player.get_resource_amount(ResourcesEnum.Type.GOLD) >= search_cost

func _can_player_afford_raise_army() -> bool:
	"""Check if current player can afford to raise army"""
	if player_manager == null:
		return false
	
	# Get current player (assuming player 1 for now)
	var current_player = player_manager.get_player(1)
	if current_player == null:
		return false
	
	var raise_army_cost = GameParameters.get_raise_army_cost()
	return current_player.get_resource_amount(ResourcesEnum.Type.GOLD) >= raise_army_cost

func _on_ore_search_pressed() -> void:
	"""Handle Ore Search button - search for ores in the region"""
	# Play click sound
	if sound_manager:
		sound_manager.click_sound()
	
	if current_region == null:
		DebugLogger.log("UISystem", "Error: No current region")
		return
	
	if region_manager == null:
		DebugLogger.log("UISystem", "Error: No region manager")
		return
	
	if player_manager == null:
		DebugLogger.log("UISystem", "Error: No player manager")
		return
	
	DebugLogger.log("UISystem", "Ore Search clicked for region: " + current_region.get_region_name())
	
	# Perform ore search
	var search_result = region_manager.perform_ore_search(current_region, 1, player_manager)
	
	if search_result.success:
		DebugLogger.log("UISystem", "Ore search successful: " + search_result.message)
		
		# Show success message modal
		if message_modal != null and search_result.has("ore_type"):
			var ore_type = search_result.ore_type
			var ore_type_string = ResourcesEnum.type_to_string(ore_type)
			var ore_amount = current_region.get_resource_amount(ore_type)
			var header = ore_type_string.capitalize() + " Found!"
			var message = "Ore size was estimated to " + str(ore_amount) + " units."
			message_modal.display_message(header, message)
	else:
		DebugLogger.log("UISystem", "Ore search failed: " + search_result.message)
		
		# Show failure message modal
		if message_modal != null:
			var header = "Ore Search"
			var remaining_attempts = current_region.get_ore_search_attempts_remaining()
			var message: String
			
			if remaining_attempts > 0:
				message = "No luck this time. " + str(remaining_attempts) + " search attempts remaining."
			else:
				message = "Ore searches exhausted. This region contains no accessible ore deposits."
			
			message_modal.display_message(header, message)
	
	# Update InfoModal to reflect any changes
	if info_modal != null and info_modal.visible:
		info_modal.show_region_info(current_region, false)  # Refresh display
	
	# Refresh the buttons to show updated state
	_create_action_buttons()

func _on_ore_search_tooltip_hovered() -> void:
	"""Handle ore search button hover - show tooltip with context"""
	if select_tooltip_modal != null and current_region != null:
		var context_data = {"current_region": current_region}
		select_tooltip_modal.show_tooltip("ore_search", context_data)

func _region_has_army_for_player(player_id: int) -> bool:
	"""Check if the current region already has an army for the specified player"""
	if current_region == null:
		return false
	
	# Check for armies in the region's children
	for child in current_region.get_children():
		if child is Army:
			var army = child as Army
			if army.get_player_id() == player_id:
				return true
	
	return false
