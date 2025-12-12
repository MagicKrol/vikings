extends Node2D
class_name TutorialModal

var arrows: Dictionary = {}
var current_arrow: String = ""
var anchored_world: bool = false
var world_pos: Vector2 = Vector2.ZERO
var screen_pos: Vector2 = Vector2.ZERO
var camera: Camera2D
var world_arrow: Sprite2D
var blocks: Dictionary = {}
var current_block: String = ""

func _ready() -> void:
	_collect_arrows()
	_collect_blocks()
	hide_all_arrows()
	hide_all_blocks()
	if has_node("Blocks"):
		for child in get_node("Blocks").get_children():
			if child is Control:
				(child as Control).visible = false

func set_camera(cam: Camera2D) -> void:
	camera = cam

func set_world_arrow(arrow: Sprite2D) -> void:
	world_arrow = arrow
	if world_arrow != null:
		world_arrow.visible = false

func _collect_arrows() -> void:
	arrows.clear()
	var arrow_root: Node = self
	if has_node("Arrows"):
		arrow_root = get_node("Arrows")
	for child in arrow_root.get_children():
		if child is Sprite2D and child.name.begins_with("Arrow"):
			var s := child as Sprite2D
			s.visible = false
			arrows[child.name.replace("Arrow", "")] = s

func _collect_blocks() -> void:
	blocks.clear()
	if not has_node("Blocks"):
		return
	for child in get_node("Blocks").get_children():
		if child is Control:
			var c := child as Control
			c.visible = false
			var key := c.name
			var lower := key.to_lower()
			if lower.begins_with("block"):
				key = key.replace("Block", "")
				lower = key.to_lower()
			blocks[lower] = c
			blocks[key.to_lower()] = c

func hide_all_arrows() -> void:
	for arrow in arrows.values():
		arrow.visible = false
	if world_arrow != null:
		world_arrow.visible = false
	current_arrow = ""
	anchored_world = false
	visible = true

func hide_all_blocks() -> void:
	for block in blocks.values():
		block.visible = false
	current_block = ""

func show_arrow(step_id: String, screen_position: Vector2, anchored_to_world: bool = false, world_position: Vector2 = Vector2.ZERO, rotation: float = 0.0) -> void:
	hide_all_arrows()
	visible = true
	current_arrow = step_id
	anchored_world = anchored_to_world
	world_pos = world_position
	screen_pos = screen_position
	if anchored_world:
		if world_arrow == null:
			DebugLogger.log("Tutorial", "World arrow not set; cannot show anchored arrow")
			return
		world_arrow.rotation = rotation
		world_arrow.global_position = world_pos
		world_arrow.visible = true
		DebugLogger.log("Tutorial", "Showing world arrow pos=" + str(world_arrow.global_position))
		return
	if not arrows.has(step_id):
		DebugLogger.log("Tutorial", "Arrow step id not found: " + step_id)
		return
	var arrow: Sprite2D = arrows[step_id]
	arrow.visible = true
	DebugLogger.log("Tutorial", "Showing arrow " + step_id + " anchored_world=" + str(anchored_world))

func show_block(block_id: String) -> void:
	hide_all_blocks()
	if block_id == "":
		return
	var ids = block_id.split(",", false)
	for raw in ids:
		var trimmed := raw.strip_edges()
		if trimmed == "":
			continue
		var key := trimmed.to_lower()
		if key.begins_with("block"):
			key = key.substr(5, key.length()).strip_edges()
		if not blocks.has(key):
			DebugLogger.log("Tutorial", "Block id not found: " + trimmed)
			continue
		var block: Control = blocks[key]
		block.visible = true
		current_block = key

func _process(_delta: float) -> void:
	if current_arrow == "":
		return
	if anchored_world:
		if world_arrow != null:
			world_arrow.global_position = world_pos
		return
