extends RefCounted
class_name VisualManager

# ============================================================================
# VISUAL MANAGER
# ============================================================================
# 
# Purpose: Centralized visual creation and update system
# 
# Core Responsibilities:
# - Castle visual creation and placement on map
# - Army visual creation and positioning  
# - Map visual updates and coordination
# - Visual scaling and positioning calculations
# 
# Required Functions:
# - place_castle_visual(): Create castle sprites on regions based on castle type
# - update_castle_visual(): Update castle visual when castle type changes
# - remove_castle_visual(): Remove castle visual from region
# - place_army_visual(): Create army visuals via ArmyManager
# - update_region_visuals(): Coordinate map visual updates
# 
# Integration Points:
# - MapGenerator: Access to map scale and positioning data
# - RegionManager: Visual update coordination
# - ArmyManager: Army visual creation delegation
# - Region: Visual placement on region containers
# ============================================================================

# Manager references
var _map_generator: MapGenerator
var _region_manager: RegionManager
var _army_manager: ArmyManager

func _init(map_generator: MapGenerator, region_manager: RegionManager, army_manager: ArmyManager):
	_map_generator = map_generator
	_region_manager = region_manager
	_army_manager = army_manager

func place_castle_visual(region_container: Node) -> void:
	"""Place a castle visual sprite on the specified region using the region's castle type"""
	# Get the region to determine castle type
	var region = region_container as Region
	if region == null:
		DebugLogger.log("UISystem", "Error: region_container is not a Region")
		return
	
	# Get castle type from region
	var castle_type = region.get_castle_type()
	if castle_type == CastleTypeEnum.Type.NONE:
		DebugLogger.log("UISystem", "Warning: Trying to place visual for no castle in " + region.get_region_name())
		return
	
	# Remove any existing castle immediately
	var existing_castle = region_container.get_node_or_null("Castle")
	if existing_castle != null:
		region_container.remove_child(existing_castle)
		existing_castle.queue_free()
		DebugLogger.log("UISystem", "Removed existing castle visual from " + region.get_region_name())
	
	# Get the appropriate icon path for this castle type
	var icon_path = CastleTypeEnum.get_icon_path(castle_type)
	if icon_path.is_empty():
		DebugLogger.log("UISystem", "Error: No icon path for castle type " + str(castle_type))
		return
	
	# Create castle sprite
	var castle := Sprite2D.new()
	castle.name = "Castle"
	castle.texture = load(icon_path)
	if castle.texture == null:
		DebugLogger.log("UISystem", "Error: Could not load castle texture from " + icon_path)
		return
	
	# Scale castle appropriately - 20% smaller than biome icons
	var castle_scale := 0.12  # 0.15 * 0.8 = 0.12 (20% smaller)
	var map_size_scale := 1.0
	if _map_generator != null:
		# Apply both polygon scale and map size scale
		map_size_scale = Utils.get_map_size_icon_scale(_map_generator.map_size)
		castle_scale = castle_scale * _map_generator.polygon_scale * map_size_scale
	
	# Position castle at region center (moved left and up by 5px, scaled)
	var polygon := region_container.get_node_or_null("Polygon") as Polygon2D
	if polygon != null:
		var center_meta = polygon.get_meta("center")
		if center_meta != null:
			var center := center_meta as Vector2
			castle.position = center + Vector2(-5 * map_size_scale, -5 * map_size_scale)  # Scaled offset
	
	castle.scale = Vector2(castle_scale, castle_scale)
	
	# Set z-index to appear above other elements
	castle.z_index = 100
	
	# Add castle to region container
	region_container.add_child(castle)
	
	DebugLogger.log("UISystem", "Placed " + CastleTypeEnum.type_to_string(castle_type) + " visual in " + region.get_region_name())

func place_army_visual(region_container: Node, player_id: int) -> void:
	"""Place an army visual in the specified region using ArmyManager"""
	if _army_manager != null:
		_army_manager.create_army(region_container, player_id)
	else:
		DebugLogger.log("UISystem", "Error: ArmyManager not available")

func update_region_visuals() -> void:
	"""Update the visual appearance of regions based on ownership"""
	if _region_manager != null:
		_region_manager.update_region_visuals()
	else:
		DebugLogger.log("UISystem", "Error: RegionManager not available")

func update_castle_visual(region_container: Node) -> void:
	"""Update castle visual when castle type changes (e.g., upgrade completion)"""
	# Simply replace the castle visual with the new one
	place_castle_visual(region_container)

func remove_castle_visual(region_container: Node) -> void:
	"""Remove castle visual from region"""
	var existing_castle = region_container.get_node_or_null("Castle")
	if existing_castle != null:
		region_container.remove_child(existing_castle)
		existing_castle.queue_free()
		DebugLogger.log("UISystem", "Removed castle visual from region")