extends Control
class_name BattleModal

# UI elements
var army_label: Label
var army_composition_label: Label
var region_label: Label
var region_composition_label: Label
var ok_button: Button

# Battle data
var attacking_army: Army = null
var defending_region: Region = null

# Sound manager reference
var sound_manager: SoundManager = null

func _ready():
	# Get references to UI elements from the scene tree
	army_label = get_node_or_null("LeftSide/ArmyLabel") as Label
	army_composition_label = get_node_or_null("LeftSide/ArmyCompositionLabel") as Label
	region_label = get_node_or_null("RightSide/RegionLabel") as Label
	region_composition_label = get_node_or_null("RightSide/RegionCompositionLabel") as Label
	ok_button = get_node_or_null("OkButton") as Button
	
	# Get sound manager reference
	sound_manager = get_node_or_null("../../SoundManager") as SoundManager
	
	# Connect OK button
	if ok_button:
		ok_button.pressed.connect(_on_ok_pressed)
	
	# Initially hidden
	visible = false

func show_battle(army: Army, region: Region) -> void:
	"""Show the battle modal with army vs region information"""
	if army == null or region == null:
		hide_modal()
		return
	
	attacking_army = army
	defending_region = region
	_update_display()
	visible = true

func hide_modal() -> void:
	"""Hide the battle modal"""
	attacking_army = null
	defending_region = null
	visible = false

func _update_display() -> void:
	"""Update the display with current battle information"""
	if attacking_army == null or defending_region == null:
		hide_modal()
		return
	
	# Update army information (left side)
	var army_player_id = attacking_army.get_player_id()
	army_label.text = "Army " + str(army_player_id)
	
	var army_composition_text = attacking_army.get_army_composition_string()
	army_composition_label.text = army_composition_text
	
	# Update region information (right side)
	var region_id = defending_region.get_region_id()
	var region_name = defending_region.get_region_name()
	region_label.text = "Region " + str(region_id) + "\n(" + region_name + ")"
	
	var region_composition_text = defending_region.get_garrison_composition_string()
	region_composition_label.text = region_composition_text

func _on_ok_pressed() -> void:
	"""Handle OK button press"""
	# Play click sound for button press
	if sound_manager:
		sound_manager.click_sound()
	hide_modal()
