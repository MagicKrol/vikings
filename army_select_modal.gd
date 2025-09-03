extends ActionModalBase
class_name ArmySelectModal

# Current army and region
var current_army: Army = null
var current_region: Region = null

# Additional references specific to army actions
var select_modal: GeneralSelectModal = null
var recruitment_modal: RecruitmentModal = null
var transfer_soldiers_modal: TransferSoldiersModal = null
var transfer_select_modal: TransferSelectModal = null
var army_manager: ArmyManager = null
var game_manager: GameManager = null

func _ready():
	super._ready()
	_setup_army_references()

func _setup_army_references():
	select_modal = get_node("../GeneralSelectModal") as GeneralSelectModal
	recruitment_modal = get_node("../RecruitmentModal") as RecruitmentModal
	transfer_soldiers_modal = get_node("../TransferSoldiersModal") as TransferSoldiersModal
	transfer_select_modal = get_node("../TransferSelectModal") as TransferSelectModal
	
	var click_manager = get_node("../../ClickManager")
	if click_manager and click_manager.has_method("get_army_manager"):
		army_manager = click_manager.get_army_manager()
	
	game_manager = get_node("../../GameManager") as GameManager

func show_army_actions(army: Army, region: Region) -> void:
	if army == null:
		hide_modal()
		return
	
	current_army = army
	current_region = region
	_create_action_buttons()
	visible = true
	
	if ui_manager:
		ui_manager.set_modal_active(true)
	
	if info_modal != null and current_army != null:
		info_modal.show_army_info(current_army, false)

func hide_modal() -> void:
	super.hide_modal()
	current_army = null
	current_region = null

func _create_action_buttons() -> void:
	_clear_buttons()
	
	var font: Font = load("res://fonts/Cinzel.ttf")
	var button_count = 6  # Header + Move, Camp, Transfer, Recruit, Back
	
	_resize_modal(button_count)
	
	# Header button
	var header_btn = _make_button("Select Action", true, false, font)
	header_btn.disabled = true
	button_container.add_child(header_btn)
	
	_add_separator()
	
	# Move Army button
	var move_button = _make_button("Move Army", false, false, font)
	move_button.pressed.connect(_on_move_army_pressed)
	move_button.mouse_entered.connect(_on_tooltip_hovered.bind("move_army"))
	move_button.mouse_exited.connect(_on_tooltip_unhovered)
	button_container.add_child(move_button)
	
	_add_separator()
	
	# Make Camp button
	var camp_button = _make_button("Make Camp", false, false, font)
	camp_button.pressed.connect(_on_make_camp_pressed)
	camp_button.mouse_entered.connect(_on_tooltip_hovered.bind("make_camp"))
	camp_button.mouse_exited.connect(_on_tooltip_unhovered)
	button_container.add_child(camp_button)
	
	_add_separator()
	
	# Transfer Soldiers button
	var transfer_button = _make_button("Transfer Soldiers", false, false, font)
	transfer_button.pressed.connect(_on_transfer_soldiers_pressed)
	transfer_button.mouse_entered.connect(_on_tooltip_hovered.bind("transfer_soldiers"))
	transfer_button.mouse_exited.connect(_on_tooltip_unhovered)
	button_container.add_child(transfer_button)
	
	_add_separator()
	
	# Recruit Soldiers button
	var recruit_button = _make_button("Recruit Soldiers", false, false, font)
	recruit_button.pressed.connect(_on_recruit_soldiers_pressed)
	recruit_button.mouse_entered.connect(_on_tooltip_hovered.bind("recruit_soldiers"))
	recruit_button.mouse_exited.connect(_on_tooltip_unhovered)
	button_container.add_child(recruit_button)
	
	_add_separator()
	
	# Back button
	var back_button = _make_button("Back", false, true, font)
	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_entered.connect(_on_tooltip_hovered.bind("back"))
	back_button.mouse_exited.connect(_on_tooltip_unhovered)
	button_container.add_child(back_button)

func _on_move_army_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	if army_manager != null and current_army != null and current_region != null and game_manager != null:
		var region_container = current_army.get_parent()
		if region_container != null:
			var current_player_id = game_manager.get_current_player_id()
			army_manager.select_army(current_army, region_container, current_player_id)
	
	current_army = null
	current_region = null
	_clear_buttons()
	visible = false
	
	if ui_manager:
		ui_manager.set_modal_active(false)

func _on_make_camp_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	if current_army and current_army.has_method("make_camp"):
		current_army.make_camp()
		
		if info_modal != null and info_modal.visible:
			info_modal.show_army_info(current_army, false)

func _on_transfer_soldiers_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	var army_to_transfer = current_army
	var region_to_transfer = current_region
	
	var other_armies: Array[Army] = []
	if region_to_transfer != null:
		for child in region_to_transfer.get_children():
			if child is Army and child != army_to_transfer:
				other_armies.append(child as Army)
	
	hide_modal()
	
	if other_armies.size() > 0:
		if transfer_select_modal != null and army_to_transfer != null and region_to_transfer != null:
			transfer_select_modal.show_transfer_selection(army_to_transfer, region_to_transfer, other_armies)
	else:
		if transfer_soldiers_modal != null and army_to_transfer != null and region_to_transfer != null:
			transfer_soldiers_modal.show_transfer_to_garrison(army_to_transfer, region_to_transfer)

func _on_recruit_soldiers_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	var army_to_recruit = current_army
	var region_to_recruit = current_region
	
	hide_modal()
	
	if recruitment_modal != null and army_to_recruit != null and region_to_recruit != null:
		recruitment_modal.show_recruitment(army_to_recruit, region_to_recruit)

func _on_back_pressed() -> void:
	if sound_manager:
		sound_manager.click_sound()
	
	var region_to_show = current_region
	var armies_in_region: Array[Army] = []
	
	if region_to_show != null:
		for child in region_to_show.get_children():
			if child is Army:
				armies_in_region.append(child as Army)
		
		if armies_in_region.is_empty() and current_army != null:
			armies_in_region = [current_army]
	
	hide_modal()
	
	if select_modal != null and region_to_show != null and is_instance_valid(select_modal) and is_instance_valid(region_to_show):
		select_modal.show_selection(region_to_show, armies_in_region)
