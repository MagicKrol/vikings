extends RefCounted

class_name RegionPoints

# Configuration for region points (default radii)
const DEFAULT_OUTER_RADIUS: float = 4.0
const DEFAULT_INNER_RADIUS: float = 2.0

static func create_region_point(center: Vector2, scale: float = 1.0, custom_inner_color: Color = Color.RED) -> Node2D:
	"""
	Creates a region point with a solid black outer circle and colored inner circle.
	"""
	var point_node := Node2D.new()
	point_node.position = center
	
	# Outer black circle
	var outer_circle: Circle2D = Circle2D.new()
	outer_circle.radius = DEFAULT_OUTER_RADIUS * scale
	outer_circle.color = Color.BLACK
	outer_circle.z_index = 150
	point_node.add_child(outer_circle)
	
	# Inner colored circle
	var inner_circle: Circle2D = Circle2D.new()
	inner_circle.radius = DEFAULT_INNER_RADIUS * scale
	inner_circle.color = custom_inner_color
	inner_circle.z_index = 151
	point_node.add_child(inner_circle)
	
	return point_node

static func create_region_points_for_centers(centers: Dictionary, scale: float = 1.0, inner_color: Color = Color.RED) -> Node2D:
	"""
	Creates region points for all centers in the provided dictionary.
	"""
	var points_container := Node2D.new()
	points_container.name = "RegionPoints"
	
	for region_id in centers.keys():
		var center: Vector2 = centers[region_id]
		var point_node := create_region_point(center, scale, inner_color)
		point_node.name = "region_point_" + str(region_id)
		points_container.add_child(point_node)
	
	return points_container

static func update_inner_color(point_node: Node2D, new_color: Color) -> void:
	"""
	Updates the inner circle color of an existing region point.
	"""
	if point_node.get_child_count() >= 2:
		var inner_circle := point_node.get_child(1)
		if inner_circle is Circle2D:
			(inner_circle as Circle2D).set_color(new_color)

static func update_all_inner_colors(points_container: Node2D, new_color: Color) -> void:
	"""
	Updates the inner circle color for all region points in a container.
	"""
	for child in points_container.get_children():
		if child is Node2D:
			update_inner_color(child, new_color)
