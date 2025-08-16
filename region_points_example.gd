extends Node2D

# Example script demonstrating how to use RegionPoints functionality
# This can be attached to any Node2D to test the region points

@export var test_centers: Array[Vector2] = [
	Vector2(100, 100),
	Vector2(200, 150),
	Vector2(300, 200),
	Vector2(150, 300)
]

@export var point_scale: float = 1.0
@export var inner_color: Color = Color.RED

var region_points_container: Node2D

func _ready() -> void:
	# Create test centers dictionary
	var centers_dict: Dictionary = {}
	for i in range(test_centers.size()):
		centers_dict[i] = test_centers[i]
	
	# Create region points using the dedicated script
	var RegionPoints := load("res://region_points.gd")
	if RegionPoints != null:
		region_points_container = RegionPoints.create_region_points_for_centers(
			centers_dict,
			point_scale,
			inner_color
		)
		add_child(region_points_container)
	

func _input(event: InputEvent) -> void:
	# Example: Change inner color with key presses
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				change_inner_color(Color.RED)
			KEY_2:
				change_inner_color(Color.GREEN)
			KEY_3:
				change_inner_color(Color.BLUE)
			KEY_4:
				change_inner_color(Color.YELLOW)
			KEY_5:
				change_inner_color(Color.CYAN)
			KEY_6:
				change_inner_color(Color.MAGENTA)

func change_inner_color(new_color: Color) -> void:
	"""
	Changes the inner color of all region points.
	"""
	if region_points_container:
		var RegionPoints := load("res://region_points.gd")
		if RegionPoints != null:
			RegionPoints.update_all_inner_colors(region_points_container, new_color)
			inner_color = new_color
	
