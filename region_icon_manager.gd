extends RefCounted

class_name RegionIconManager

const VARIANT_BASE_BY_BIOME := {
	"forest": "forest",
	"forest2": "forest",
	"hills": "hill",
	"hill": "hill",
	"hill_forest": "hill_forest",
	"hill forest": "hill_forest"
}
const VARIANT_COUNT := 3
const STANDARD_ICON_ALPHA := 0.85
const STANDARD_ICON_OFFSET_Y := -5.0
const MOUNTAIN_ICON_BASE_SCALE := 0.1
const MOUNTAIN_OFFSET_Y := -10.0
const MOUNTAIN_ICONS := [
	{
		"path": "res://images/icons/mountain_1.png",
		"size": Vector2(230.0, 260.0),
		"aspect_ratio": 230.0 / 260.0
	},
	{
		"path": "res://images/icons/mountain_2.png",
		"size": Vector2(245.0, 155.0),
		"aspect_ratio": 245.0 / 155.0
	},
	{
		"path": "res://images/icons/mountain_3.png",
		"size": Vector2(282.0, 155.0),
		"aspect_ratio": 282.0 / 155.0
	},
	{
		"path": "res://images/icons/mountain_4.png",
		"size": Vector2(260.0, 230.0),
		"aspect_ratio": 260.0 / 230.0
	}
]

static var _rng: RandomNumberGenerator = null

static func place_region_icon(parent_pg: Polygon2D, region_data: Dictionary, polygon_scale: float, map_size_setting: int) -> void:
	var biome_name := String(region_data.get("biome", ""))
	if biome_name == "":
		return
	var map_size_scale := Utils.get_map_size_icon_scale(map_size_setting)
	var biome_lower := biome_name.to_lower()
	if biome_lower == "mountains":
		_place_mountain_icon(parent_pg, region_data, polygon_scale, map_size_scale)
		return
	var icon_path := _resolve_icon_path(biome_name, biome_lower)
	if icon_path == "":
		return
	_place_standard_icon(parent_pg, region_data, icon_path, biome_lower, polygon_scale, map_size_scale)

static func _resolve_icon_path(biome_name: String, biome_lower: String) -> String:
	var normalized_key := biome_lower.replace(" ", "_")
	if VARIANT_BASE_BY_BIOME.has(normalized_key):
		return _pick_variant_path(VARIANT_BASE_BY_BIOME[normalized_key])
	return BiomeManager.get_icon_path_for_biome(biome_name)

static func _pick_variant_path(base_name: String) -> String:
	var rng := _get_rng()
	var variant_index := rng.randi_range(1, VARIANT_COUNT)
	return "res://images/icons/%s_%d.png" % [base_name, variant_index]

static func _place_standard_icon(parent_pg: Polygon2D, region_data: Dictionary, icon_path: String, biome_lower: String, polygon_scale: float, map_size_scale: float) -> void:
	var center_data = region_data.get("center", [500, 500])
	if center_data.size() != 2:
		return
	var center := Vector2(center_data[0], center_data[1])
	var icon := Sprite2D.new()
	icon.texture = load(icon_path)
	if icon.texture == null:
		return
	if biome_lower.find("hill") != -1:
		icon.position = center
	else:
		icon.position = center + Vector2(0, STANDARD_ICON_OFFSET_Y * map_size_scale)
	var icon_scale := _get_standard_icon_scale(biome_lower)
	var final_scale := icon_scale * polygon_scale * map_size_scale
	icon.scale = Vector2(final_scale, final_scale)
	icon.z_index = parent_pg.z_index + 10
	icon.modulate.a = STANDARD_ICON_ALPHA
	parent_pg.add_child(icon)

static func _get_standard_icon_scale(biome_lower: String) -> float:
	if biome_lower == "forest" or biome_lower == "forest2":
		return GameParameters.FOREST_ICON_SCALE
	return GameParameters.BIOME_ICON_SCALE

static func _place_mountain_icon(parent_pg: Polygon2D, region_data: Dictionary, polygon_scale: float, map_size_scale: float) -> void:
	var polygon := parent_pg.polygon
	if polygon.size() < 3:
		return
	var analysis := Utils.analyze_polygon_shape(polygon)
	var icon_info := _pick_mountain_variant(analysis)
	if icon_info.is_empty():
		return
	var center_data = region_data.get("center", [500, 500])
	if center_data.size() != 2:
		return
	var center := Vector2(center_data[0], center_data[1])
	var icon := Sprite2D.new()
	icon.texture = load(icon_info.get("path", ""))
	if icon.texture == null:
		return
	icon.position = center + Vector2(0, MOUNTAIN_OFFSET_Y * map_size_scale)
	var is_internal := _is_internal_mountain(region_data)
	var scale_factor := _compute_mountain_scale(analysis, icon_info, is_internal)
	icon.scale = Vector2(scale_factor, scale_factor)
	icon.z_index = parent_pg.z_index + 10
	icon.set_meta("mountain_icon", true)
	parent_pg.add_child(icon)

static func _is_internal_mountain(region_data: Dictionary) -> bool:
	return bool(region_data.get("internal_mountain", false))

static func _pick_mountain_variant(analysis: Dictionary) -> Dictionary:
	var region_ratio := float(analysis.get("aspect_ratio", 0.0))
	if region_ratio <= 0.0:
		return {}
	var closest_icon: Dictionary = {}
	var smallest_diff := INF
	for icon_data in MOUNTAIN_ICONS:
		var diff: float = abs(float(icon_data.get("aspect_ratio", 0.0)) - region_ratio)
		if diff < smallest_diff:
			smallest_diff = diff
			closest_icon = icon_data
	return closest_icon

static func _pick_random_mountain_icon() -> Dictionary:
	var rng := _get_rng()
	return MOUNTAIN_ICONS[rng.randi_range(0, MOUNTAIN_ICONS.size() - 1)]

static func _compute_mountain_scale(analysis: Dictionary, icon_info: Dictionary, internal_mountain: bool) -> float:
	var bounding_box: Rect2 = analysis.get("bounding_box", Rect2())
	var region_width := bounding_box.size.x
	var region_height := bounding_box.size.y
	var icon_size: Vector2 = icon_info.get("size", Vector2.ZERO)
	if region_width <= 0.0 or region_height <= 0.0:
		return MOUNTAIN_ICON_BASE_SCALE
	if icon_size.x <= 0.0 or icon_size.y <= 0.0:
		return MOUNTAIN_ICON_BASE_SCALE
	var use_width := icon_size.x >= icon_size.y
	var width_scale: float = region_width / icon_size.x
	var height_scale: float = region_height / icon_size.y
	var max_fit_scale: float = min(width_scale, height_scale)
	var scale_factor: float = width_scale if use_width else height_scale
	if internal_mountain:
		scale_factor *= 1.0
	if scale_factor > max_fit_scale:
		scale_factor = max_fit_scale
	return scale_factor

static func _get_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng
