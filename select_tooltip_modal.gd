extends Control
class_name SelectTooltipModal

# UI elements - references to static nodes from scene
@onready var tooltip_label: Label = $MarginContainer/CostContainer/TooltipLabel
@onready var values_section: VBoxContainer = $MarginContainer/CostContainer/ValuesSection

# Cost display nodes
@onready var time_icon: TextureRect = $MarginContainer/CostContainer/ValuesSection/Images/TimeIcon
@onready var food_icon: TextureRect = $MarginContainer/CostContainer/ValuesSection/Images/FoodIcon
@onready var wood_icon: TextureRect = $MarginContainer/CostContainer/ValuesSection/Images/WoodIcon
@onready var stone_icon: TextureRect = $MarginContainer/CostContainer/ValuesSection/Images/StoneIcon
@onready var iron_icon: TextureRect = $MarginContainer/CostContainer/ValuesSection/Images/IronIcon
@onready var gold_icon: TextureRect = $MarginContainer/CostContainer/ValuesSection/Images/GoldIcon

@onready var time_value: Label = $MarginContainer/CostContainer/ValuesSection/Values/TimeValue
@onready var food_value: Label = $MarginContainer/CostContainer/ValuesSection/Values/FoodValue
@onready var wood_value: Label = $MarginContainer/CostContainer/ValuesSection/Values/WoodValue
@onready var stone_value: Label = $MarginContainer/CostContainer/ValuesSection/Values/StoneValue
@onready var iron_value: Label = $MarginContainer/CostContainer/ValuesSection/Values/IronValue
@onready var gold_value: Label = $MarginContainer/CostContainer/ValuesSection/Values/GoldValue

# Tooltip text definitions for each button type
const TOOLTIP_TEXTS = {
	# Select Modal tooltips
	"region": "View and manage region. Build structures, recruit soldiers, and upgrade the region level.",
	
	# Army Select Modal tooltips  
	"move_army": "Move this army to an adjacent region. Costs movement points based on terrain type.",
	"make_camp": "Rest the army to restore efficiency. Costs 1 movement point and restores 10 vigor.",
	"transfer_soldiers": "Transfer soldiers between this army and the region garrison, or other armies in the region.",
	"recruit_soldiers": "Recruit new soldiers for this army using regional population and resources.",
	"back": "Return to the previous selection menu.",
	
	# Region Select Modal tooltips
	"raise_army": "Create new army in this region.",
	"recruit_soldiers_garrison": "Recruit soldiers to region's garison.",
	"build_castle": "Construct military outpost to improve local defenses, raise armies and recruit units.",
	"upgrade_castle": "Upgrade the existing castle to the next level for improved defenses and capabilities.",
	"castle_construction": "Castle construction is in progress. Wait for completion before building or upgrading.",
	"castle_max_level": "This castle is already at the maximum level and cannot be upgraded further.",
	"promote_region": "Promote region to the next administrative level, increase growth and production.",
	"call_to_arms": "Gather recruits from neighboring regions.",
	"ore_search": "Search for Gold or Iron ores in this region.",
	
	# Generic army tooltip (for army buttons in SelectModal)
	"army": "Select this army to view available actions: movement, recruitment, transfers."
}

func _ready():
	# Initially hidden
	visible = false

func _display_cost(cost: Dictionary, build_time: int = 0) -> void:
	"""Display cost values in the dedicated value fields"""
	# Hide all icons and values first
	time_icon.visible = false
	time_value.visible = false
	food_icon.visible = false
	food_value.visible = false
	wood_icon.visible = false
	wood_value.visible = false
	stone_icon.visible = false
	stone_value.visible = false
	iron_icon.visible = false
	iron_value.visible = false
	gold_icon.visible = false
	gold_value.visible = false
	
	# Show build time if provided
	if build_time > 0:
		time_icon.visible = true
		time_value.visible = true
		time_value.text = str(build_time)
	
	# Show resource costs
	for resource_type in cost:
		var amount = cost[resource_type]
		if amount > 0:
			match resource_type:
				ResourcesEnum.Type.FOOD:
					food_icon.visible = true
					food_value.visible = true
					food_value.text = str(amount)
				ResourcesEnum.Type.WOOD:
					wood_icon.visible = true
					wood_value.visible = true
					wood_value.text = str(amount)
				ResourcesEnum.Type.STONE:
					stone_icon.visible = true
					stone_value.visible = true
					stone_value.text = str(amount)
				ResourcesEnum.Type.IRON:
					iron_icon.visible = true
					iron_value.visible = true
					iron_value.text = str(amount)
				ResourcesEnum.Type.GOLD:
					gold_icon.visible = true
					gold_value.visible = true
					gold_value.text = str(amount)
	
	# Show values section if there's any cost
	values_section.visible = (cost.size() > 0 or build_time > 0)

func _hide_cost_display() -> void:
	"""Hide the cost display section"""
	values_section.visible = false

func show_tooltip(tooltip_key: String, context_data: Dictionary = {}) -> void:
	"""Show the tooltip with the specified text"""
	var key = String(tooltip_key).to_lower()
	var tooltip_text = TOOLTIP_TEXTS.get(key, "No information available.")
	
	# Hide cost display by default
	_hide_cost_display()
	
	# Add dynamic cost information for promote_region tooltip
	if tooltip_key == "promote_region" and context_data.has("current_region"):
		var current_region = context_data["current_region"]
		if current_region != null:
			var current_level = current_region.get_region_level()
			if current_level < RegionLevelEnum.Level.L5:
				var next_level = current_level + 1
				var cost = GameParameters.get_promotion_cost(next_level)
				if not cost.is_empty():
					_display_cost(cost)
			else:
				tooltip_text += "\n\nRegion is already at maximum level."
	
	# Add dynamic cost information for castle-related tooltips
	if (tooltip_key == "build_castle" or tooltip_key == "upgrade_castle") and context_data.has("current_region"):
		var current_region = context_data["current_region"]
		if current_region != null:
			var castle_type_to_build: CastleTypeEnum.Type
			
			if tooltip_key == "build_castle":
				# Building first castle (Outpost)
				castle_type_to_build = CastleTypeEnum.Type.OUTPOST
			elif tooltip_key == "upgrade_castle":
				# Upgrading existing castle
				var current_castle_type = current_region.get_castle_type()
				castle_type_to_build = CastleTypeEnum.get_next_level(current_castle_type)
			
			if castle_type_to_build != CastleTypeEnum.Type.NONE:
				var cost = GameParameters.get_castle_building_cost(castle_type_to_build)
				
				if not cost.is_empty():
					_display_cost(cost)
	
	# Add construction status for castle_construction tooltip
	if tooltip_key == "castle_construction" and context_data.has("current_region"):
		var current_region = context_data["current_region"]
		if current_region != null and current_region.is_castle_under_construction():
			var castle_being_built = current_region.get_castle_under_construction()
			tooltip_text += "\n\nBuilding: " + CastleTypeEnum.type_to_string(castle_being_built)
	
	# Add current castle info for castle_max_level tooltip
	if tooltip_key == "castle_max_level" and context_data.has("current_region"):
		var current_region = context_data["current_region"]
		if current_region != null:
			var current_castle_type = current_region.get_castle_type()
			tooltip_text += "\n\nCurrent Castle: " + CastleTypeEnum.type_to_string(current_castle_type)
	
	# Add requirement info for call_to_arms tooltip
	if tooltip_key == "call_to_arms" and context_data.has("current_region"):
		var current_region = context_data["current_region"]
		if current_region != null and current_region.get_castle_type() == CastleTypeEnum.Type.NONE:
			tooltip_text += "\nRequires Outpost"
	
	# Add requirement info for raise_army tooltip
	if tooltip_key == "raise_army" and context_data.has("current_region"):
		var current_region = context_data["current_region"]
		if current_region != null:
			var castle_type = current_region.get_castle_type()
			var has_keep_or_higher = castle_type >= CastleTypeEnum.Type.KEEP
			
			# Display raise army cost
			var raise_army_cost = GameParameters.get_raise_army_cost()
			var cost_dict = {ResourcesEnum.Type.GOLD: raise_army_cost}
			_display_cost(cost_dict)
			
			if not has_keep_or_higher:
				tooltip_text += "\n\nRequires Keep"
	
	# Add detailed info for ore_search tooltip
	if tooltip_key == "ore_search" and context_data.has("current_region"):
		var current_region = context_data["current_region"]
		if current_region != null:
			var search_cost = GameParameters.get_ore_search_cost()
			var discovery_chance = int(GameParameters.get_ore_discovery_chance() * 100)
			
			# Display gold cost using the cost display system
			var cost_dict = {ResourcesEnum.Type.GOLD: search_cost}
			_display_cost(cost_dict)
			
			tooltip_text += "\n\nSuccess Chance: " + str(discovery_chance) + "%"
			
			# Show search status
			if GameParameters.can_search_for_ore_in_region(current_region.get_region_type()):
				var attempts_remaining = current_region.get_ore_search_attempts_remaining()
				if attempts_remaining > 0:
					tooltip_text += "\nAttempts Remaining: " + str(attempts_remaining)
					if current_region.ore_search_used_this_turn:
						tooltip_text += " (used this turn)"
				else:
					tooltip_text += "\nNo search attempts remaining"
				
				# Show discovered ores
				var discovered_ores = current_region.get_discovered_ores()
				if not discovered_ores.is_empty():
					tooltip_text += "\n\nDiscovered Ores:"
					for ore_type in discovered_ores:
						tooltip_text += "\n• " + ResourcesEnum.type_to_string(ore_type)
			else:
				tooltip_text += "\n\nThis region type cannot contain ores"
	
	tooltip_label.text = tooltip_text
	visible = true

func hide_tooltip() -> void:
	"""Hide the tooltip"""
	visible = false
