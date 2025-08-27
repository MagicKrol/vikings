extends Control
class_name SelectTooltipModal

# Styling constants (same as other modals)
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(4, 4)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 4.0

# UI elements - references to static nodes from scene
@onready var tooltip_label: Label = $MarginContainer/TooltipLabel

# Tooltip text definitions for each button type
const TOOLTIP_TEXTS = {
	# Select Modal tooltips
	"region": "View and manage this region. Build structures, recruit garrison soldiers, and upgrade the region level.",
	
	# Army Select Modal tooltips  
	"move_army": "Move this army to an adjacent region. Costs movement points based on terrain type.",
	"make_camp": "Rest the army to restore efficiency. Costs 1 movement point and restores 10 efficiency.",
	"transfer_soldiers": "Transfer soldiers between this army and the region garrison, or other armies in the region.",
	"recruit_soldiers": "Recruit new soldiers for this army using regional population and resources.",
	"back": "Return to the previous selection menu.",
	
	# Region Select Modal tooltips
	"raise_army": "Create a new empty army in this region. The army starts with 0 soldiers and 0 movement points.",
	"recruit_soldiers_garrison": "Recruit soldiers directly into the region's garrison using population and resources.",
	"build_castle": "Construct a castle in this region to increase its defensive capabilities and unlock upgrades.",
	"upgrade_castle": "Upgrade the existing castle to the next level for improved defenses and capabilities.",
	"castle_construction": "Castle construction is in progress. Wait for completion before building or upgrading.",
	"castle_max_level": "This castle is already at the maximum level (Stronghold) and cannot be upgraded further.",
	"promote_region": "Upgrade this region to the next administrative level, unlocking better recruitment tiers.",
	"call_to_arms": "Gather recruits from neighboring regions to boost this region's recruitment capacity.",
	"ore_search": "Search for Gold or Iron ores in this region. Each region has limited search attempts and costs 5 Gold per search.",
	
	# Generic army tooltip (for army buttons in SelectModal)
	"army": "Select this army to view available actions: movement, recruitment, transfers, and more."
}

func _ready():
	# Initially hidden
	visible = false

func show_tooltip(tooltip_key: String, context_data: Dictionary = {}) -> void:
	"""Show the tooltip with the specified text"""
	var tooltip_text = TOOLTIP_TEXTS.get(tooltip_key, "No information available.")
	
	# Add dynamic cost information for promote_region tooltip
	if tooltip_key == "promote_region" and context_data.has("current_region"):
		var current_region = context_data["current_region"]
		if current_region != null:
			var current_level = current_region.get_region_level()
			if current_level < RegionLevelEnum.Level.L5:
				var next_level = current_level + 1
				var cost = GameParameters.get_promotion_cost(next_level)
				if not cost.is_empty():
					tooltip_text += "\n\nCost to promote to " + RegionLevelEnum.level_to_string(next_level) + ":"
					for resource_type in cost:
						var resource_name = ResourcesEnum.type_to_string(resource_type)
						var amount = cost[resource_type]
						tooltip_text += "\n• " + str(amount) + " " + resource_name
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
				tooltip_text += "\n\nBuilds: " + CastleTypeEnum.type_to_string(castle_type_to_build)
			elif tooltip_key == "upgrade_castle":
				# Upgrading existing castle
				var current_castle_type = current_region.get_castle_type()
				castle_type_to_build = CastleTypeEnum.get_next_level(current_castle_type)
				if castle_type_to_build != CastleTypeEnum.Type.NONE:
					tooltip_text += "\n\nUpgrades to: " + CastleTypeEnum.type_to_string(castle_type_to_build)
			
			if castle_type_to_build != CastleTypeEnum.Type.NONE:
				var cost = GameParameters.get_castle_building_cost(castle_type_to_build)
				var build_time = GameParameters.get_castle_build_time(castle_type_to_build)
				
				if not cost.is_empty():
					tooltip_text += "\n\nCost:"
					for resource_type in cost:
						var resource_name = ResourcesEnum.type_to_string(resource_type)
						var amount = cost[resource_type]
						tooltip_text += "\n• " + str(amount) + " " + resource_name
					
				tooltip_text += "\n\nBuild Time: " + str(build_time) + " turn" + ("s" if build_time != 1 else "")
	
	# Add construction status for castle_construction tooltip
	if tooltip_key == "castle_construction" and context_data.has("current_region"):
		var current_region = context_data["current_region"]
		if current_region != null and current_region.is_castle_under_construction():
			var castle_being_built = current_region.get_castle_under_construction()
			var turns_remaining = current_region.get_castle_build_turns_remaining()
			tooltip_text += "\n\nBuilding: " + CastleTypeEnum.type_to_string(castle_being_built)
			tooltip_text += "\nTurns Remaining: " + str(turns_remaining)
	
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
			tooltip_text += "\n\nRequires Outpost"
	
	# Add requirement info for raise_army tooltip
	if tooltip_key == "raise_army" and context_data.has("current_region"):
		var current_region = context_data["current_region"]
		if current_region != null:
			var castle_type = current_region.get_castle_type()
			var has_keep_or_higher = castle_type != CastleTypeEnum.Type.NONE and castle_type != CastleTypeEnum.Type.OUTPOST
			if not has_keep_or_higher:
				tooltip_text += "\n\nRequires Keep"
	
	# Add detailed info for ore_search tooltip
	if tooltip_key == "ore_search" and context_data.has("current_region"):
		var current_region = context_data["current_region"]
		if current_region != null:
			var search_cost = GameParameters.get_ore_search_cost()
			var discovery_chance = int(GameParameters.get_ore_discovery_chance() * 100)
			
			tooltip_text += "\n\nCost: " + str(search_cost) + " Gold"
			tooltip_text += "\nSuccess Chance: " + str(discovery_chance) + "%"
			
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

func _draw():
	# Draw shadow first (behind everything)
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)
	
	# Draw background fill
	var bg_rect = Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, FRAME_COLOR)
	
	# Draw black border on top
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)
