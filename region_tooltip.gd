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
	
	# Show the region name
	label.text = region.get_region_name()
	
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
