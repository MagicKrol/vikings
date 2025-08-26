extends Control
class_name RegionTooltip

# Tooltip styling constants
const FRAME_COLOR = Color("#b7975e")
const BORDER_COLOR = Color.BLACK
const SHADOW_OFFSET = Vector2(2, 2)
const SHADOW_COLOR = Color(0, 0, 0, 0.3)
const BORDER_WIDTH = 2.0
const MOUSE_OFFSET = Vector2(50, 50)

# UI elements
@onready var background: ColorRect = $Background
@onready var label: Label = $Label
var current_region: Region = null

func _ready():
	# Set up the tooltip dimensions
	custom_minimum_size = Vector2(200, 50)
	size = Vector2(200, 50)
	
	# Start hidden and don't block input
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse events
	
	# Configure the existing background
	background.color = FRAME_COLOR
	
	# Configure the existing label
	label.text = ""

func _draw():
	# Draw black border
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)
	
	# Draw shadow
	var shadow_rect = Rect2(SHADOW_OFFSET, size)
	draw_rect(shadow_rect, SHADOW_COLOR)

func show_region_tooltip(region: Region, mouse_pos: Vector2):
	"""Show tooltip for the given region at mouse position"""
	if region == null:
		hide_tooltip()
		return
	
	current_region = region
	
	# Check if debug mode is active
	var debug_info = _get_debug_info(region)
	
	if debug_info != "":
		# Show region name + debug info
		label.text = region.get_region_name() + "\n" + debug_info
		# Much larger tooltip size for comprehensive debug info
		custom_minimum_size = Vector2(800, 400)
		size = Vector2(800, 400)
		# Use system default font for better readability in debug mode
		_set_debug_font()
	else:
		# Show just the region name
		label.text = region.get_region_name()
		# Reset tooltip size
		custom_minimum_size = Vector2(200, 50)
		size = Vector2(200, 50)
		# Reset to default font
		_reset_font()
	
	# Position at mouse with offset
	position = mouse_pos + MOUSE_OFFSET
	
	# Make sure tooltip stays on screen
	_clamp_to_screen()
	
	visible = true
	queue_redraw()

func hide_tooltip():
	"""Hide the tooltip"""
	visible = false
	current_region = null
	label.text = ""

func update_position(mouse_pos: Vector2):
	"""Update tooltip position when mouse moves"""
	if visible:
		position = mouse_pos + MOUSE_OFFSET
		_clamp_to_screen()

func _clamp_to_screen():
	"""Keep tooltip within screen bounds"""
	var screen_size = get_viewport().get_visible_rect().size
	
	# Adjust position if tooltip would go off-screen
	if position.x + size.x > screen_size.x:
		position.x = screen_size.x - size.x - 10
	if position.y + size.y > screen_size.y:
		position.y = screen_size.y - size.y - 10
	
	# Ensure it doesn't go negative
	position.x = max(10, position.x)
	position.y = max(10, position.y)

func _get_debug_info(region: Region) -> String:
	"""Get debug information for the region if debug mode is active"""
	# Try to find the AI debug visualizer in the scene tree
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager == null:
		return ""
	
	var ai_debug_visualizer = game_manager.get("_ai_debug_visualizer")
	if ai_debug_visualizer == null:
		return ""
	
	# Check if debug mode is active
	if not ai_debug_visualizer.is_debug_visible():
		return ""
	
	# Get comprehensive debug information
	var debug_info = _get_comprehensive_debug_info(region)
	return debug_info

func _get_cluster_data(region: Region) -> Dictionary:
	"""Calculate total population and resources for region + passable neighbors cluster"""
	var total_population = region.get_population()
	var total_wood = region.get_resource_amount(ResourcesEnum.Type.WOOD)
	var total_food = region.get_resource_amount(ResourcesEnum.Type.FOOD)
	var total_stone = region.get_resource_amount(ResourcesEnum.Type.STONE)
	var total_iron = region.get_resource_amount(ResourcesEnum.Type.IRON)
	var total_gold = region.get_resource_amount(ResourcesEnum.Type.GOLD)
	
	# Get region manager through game manager
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager != null:
		var region_manager = game_manager.get_region_manager()
		if region_manager != null:
			# Get neighbor regions
			var neighbor_ids = region_manager.get_neighbor_regions(region.get_region_id())
			var map_generator = get_node_or_null("/root/Main/Map")
			
			if map_generator != null:
				for neighbor_id in neighbor_ids:
					var neighbor = map_generator.get_region_container_by_id(neighbor_id) as Region
					if (neighbor != null and 
						neighbor.get_region_type() != RegionTypeEnum.Type.MOUNTAINS and
						neighbor.get_region_owner() == 0):  # Only include neutral neighbors
						# Add neighbor's population and resources to totals
						total_population += neighbor.get_population()
						total_wood += neighbor.get_resource_amount(ResourcesEnum.Type.WOOD)
						total_food += neighbor.get_resource_amount(ResourcesEnum.Type.FOOD)
						total_stone += neighbor.get_resource_amount(ResourcesEnum.Type.STONE)
						total_iron += neighbor.get_resource_amount(ResourcesEnum.Type.IRON)
						total_gold += neighbor.get_resource_amount(ResourcesEnum.Type.GOLD)
	
	return {
		"total_population": total_population,
		"total_wood": total_wood,
		"total_food": total_food,
		"total_stone": total_stone,
		"total_iron": total_iron,
		"total_gold": total_gold
	}

func _get_comprehensive_debug_info(region: Region) -> String:
	"""Get comprehensive debug information including all scoring factors"""
	var debug_lines = []
	
	# Get references to managers
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager == null:
		return "Game Manager not found"
	
	var ai_debug_visualizer = game_manager.get("_ai_debug_visualizer")
	if ai_debug_visualizer == null:
		return "AI Debug Visualizer not found"
	
	# Check which debug mode we're in
	var debug_mode = ai_debug_visualizer.get("debug_mode")
	
	if debug_mode == "army_target":
		return _get_army_target_debug_info(region, ai_debug_visualizer)
	else:
		return _get_castle_placement_debug_info(region, ai_debug_visualizer)

func _get_army_target_debug_info(region: Region, ai_debug_visualizer) -> String:
	"""Get army target scoring debug information"""
	var debug_lines = []
	
	# SECTION 1: Basic region information
	debug_lines.append("=== REGION " + str(region.get_region_id()) + " ARMY TARGET ===")
	var region_resources = []
	region_resources.append("P:" + str(region.get_population()))
	if region.get_resource_amount(ResourcesEnum.Type.WOOD) > 0:
		region_resources.append("W:" + str(region.get_resource_amount(ResourcesEnum.Type.WOOD)))
	if region.get_resource_amount(ResourcesEnum.Type.FOOD) > 0:
		region_resources.append("F:" + str(region.get_resource_amount(ResourcesEnum.Type.FOOD)))
	if region.get_resource_amount(ResourcesEnum.Type.STONE) > 0:
		region_resources.append("S:" + str(region.get_resource_amount(ResourcesEnum.Type.STONE)))
	if region.get_resource_amount(ResourcesEnum.Type.IRON) > 0:
		region_resources.append("I:" + str(region.get_resource_amount(ResourcesEnum.Type.IRON)))
	if region.get_resource_amount(ResourcesEnum.Type.GOLD) > 0:
		region_resources.append("G:" + str(region.get_resource_amount(ResourcesEnum.Type.GOLD)))
	region_resources.append("RL:" + str(region.get_region_level()))
	
	# Add ownership info
	var owner = region.get_region_owner()
	if owner == -1:
		region_resources.append("Owner: Neutral")
	elif owner == 0:
		region_resources.append("Owner: Unowned")
	else:
		region_resources.append("Owner: Player " + str(owner))
	
	debug_lines.append(", ".join(region_resources))
	
	# Get the target score from cache
	var target_score = ai_debug_visualizer.get_region_score(region.get_region_id())
	debug_lines.append("TARGET SCORE: " + str(int(target_score)))
	
	# SECTION 2: Get detailed scoring factors for army targeting
	debug_lines.append("")
	debug_lines.append("=== ARMY TARGET FACTORS ===")
	var detailed_scores = ai_debug_visualizer.get_detailed_scores(region.get_region_id())
	if not detailed_scores.is_empty():
		debug_lines.append("Population Score: " + str(int(detailed_scores.get("population_score", 0.0) * 100)) + "% (Weight: 30%)")
		debug_lines.append("Resource Score: " + str(int(detailed_scores.get("resource_score", 0.0) * 100)) + "% (Weight: 40%)")
		debug_lines.append("Level Score: " + str(int(detailed_scores.get("level_score", 0.0) * 100)) + "% (Weight: 20%)")
		debug_lines.append("Ownership Score: " + str(int(detailed_scores.get("ownership_score", 0.0) * 100)) + "% (Weight: 10%)")
		
		if detailed_scores.has("base_score") and detailed_scores.has("random_modifier"):
			debug_lines.append("Base Score: " + str(int(detailed_scores.base_score)))
			debug_lines.append("Random Modifier: +" + str(int(detailed_scores.random_modifier)))
	else:
		debug_lines.append("No army target scoring data available")
	
	return "\n".join(debug_lines)

func _get_castle_placement_debug_info(region: Region, ai_debug_visualizer) -> String:
	"""Get castle placement scoring debug information"""
	var debug_lines = []
	
	# Get cluster data
	var cluster_data = _get_cluster_data(region)
	
	# SECTION 1: Basic cluster information with region ID
	debug_lines.append("=== REGION " + str(region.get_region_id()) + " CLUSTER ===")
	var cluster_resources = []
	cluster_resources.append("P:" + str(cluster_data.total_population))
	if cluster_data.total_wood > 0:
		cluster_resources.append("W:" + str(cluster_data.total_wood))
	if cluster_data.total_food > 0:
		cluster_resources.append("F:" + str(cluster_data.total_food))
	if cluster_data.total_stone > 0:
		cluster_resources.append("S:" + str(cluster_data.total_stone))
	if cluster_data.total_iron > 0:
		cluster_resources.append("I:" + str(cluster_data.total_iron))
	if cluster_data.total_gold > 0:
		cluster_resources.append("G:" + str(cluster_data.total_gold))
	cluster_resources.append("RL:" + str(region.get_region_level()))
	debug_lines.append(", ".join(cluster_resources))
	
	# Get the cluster score from cache
	var cluster_score = ai_debug_visualizer.get_region_score(region.get_region_id())
	debug_lines.append("CLUSTER SCORE: " + str(int(cluster_score)))
	
	# SECTION 2: Get detailed scoring factors
	debug_lines.append("")
	debug_lines.append("=== SCORING FACTORS ===")
	var scoring_factors = _get_scoring_factors(region)
	if not scoring_factors.is_empty():
		debug_lines.append("Distance to Enemy: " + str(scoring_factors.distance))
		debug_lines.append("Cluster Size: " + str(scoring_factors.cluster_size) + " regions")
		debug_lines.append("Pop Score: " + str(int(scoring_factors.pop_score * 100)) + "%")
		debug_lines.append("Resource Score: " + str(int(scoring_factors.resource_score * 100)) + "%")
		debug_lines.append("Safety Score: " + str(int(scoring_factors.safety_score * 100)) + "%")
		debug_lines.append("Size Score: " + str(int(scoring_factors.size_score * 100)) + "%")
		debug_lines.append("Level Score: " + str(int(scoring_factors.level_score * 100)) + "%")
	
	# SECTION 3: Individual region data
	debug_lines.append("")
	debug_lines.append("=== INDIVIDUAL REGION ===")
	var individual_resources = []
	individual_resources.append("P:" + str(region.get_population()))
	if region.get_resource_amount(ResourcesEnum.Type.WOOD) > 0:
		individual_resources.append("W:" + str(region.get_resource_amount(ResourcesEnum.Type.WOOD)))
	if region.get_resource_amount(ResourcesEnum.Type.FOOD) > 0:
		individual_resources.append("F:" + str(region.get_resource_amount(ResourcesEnum.Type.FOOD)))
	if region.get_resource_amount(ResourcesEnum.Type.STONE) > 0:
		individual_resources.append("S:" + str(region.get_resource_amount(ResourcesEnum.Type.STONE)))
	if region.get_resource_amount(ResourcesEnum.Type.IRON) > 0:
		individual_resources.append("I:" + str(region.get_resource_amount(ResourcesEnum.Type.IRON)))
	if region.get_resource_amount(ResourcesEnum.Type.GOLD) > 0:
		individual_resources.append("G:" + str(region.get_resource_amount(ResourcesEnum.Type.GOLD)))
	
	debug_lines.append(", ".join(individual_resources))
	
	# Calculate individual region score
	var individual_score = _calculate_individual_score(region)
	debug_lines.append("INDIVIDUAL SCORE: " + str(int(individual_score)))
	
	return "\n".join(debug_lines)

func _get_scoring_factors(region: Region) -> Dictionary:
	"""Get detailed scoring factors directly from region storage"""
	# Get factors directly from the region - no calculation or manager lookup needed!
	var factors = region.get_ai_scoring_factors()
	
	# If no valid scores stored, return empty default
	if factors.is_empty():
		return {
			"distance": 0,
			"cluster_size": 1,
			"pop_score": 0.0,
			"resource_score": 0.0,
			"safety_score": 0.0,
			"size_score": 0.0,
			"level_score": 0.0
		}
	
	# Return stored factors directly from region
	return factors

func _calculate_individual_score(region: Region) -> float:
	"""Get individual region score directly from region storage"""
	# Get individual score directly from the region - no calculation needed!
	return region.get_ai_individual_score()

func _set_debug_font():
	"""Set a more readable system font for debug mode"""
	# Create a system font for better readability
	var system_font = SystemFont.new()
	system_font.font_names = ["Arial", "Helvetica", "Liberation Sans", "DejaVu Sans"]  # Fallback chain
	system_font.font_weight = 400  # Normal weight
	
	# Apply to label with doubled font size
	if label != null:
		label.add_theme_font_override("font", system_font)
		label.add_theme_font_size_override("font_size", 24)  # Doubled from 12 to 24

func _reset_font():
	"""Reset font to default theme font"""
	if label != null:
		# Clear all theme overrides at once to avoid null parameter errors
		label.remove_theme_font_override("font")
		label.remove_theme_font_size_override("font_size")
