extends Node2D
class_name Clouds

const CLOUD_COUNT: int = 40
const SCALE_MIN: float = 0.3
const SCALE_MAX: float = 0.6
const SPEED_MIN: float = 10.0
const SPEED_MAX: float = 30.0
const CLOUD_TEXTURE_COUNT: int = 5
const DESPAWN_X: float = 3050.0
const RESPAWN_X: float = -1000.0
const SHADOW_X_OFFSET: float = 50.0
const SHADOW_Y_BASE: float = 100.0
const SHADOW_Y_RANDOM: float = 100.0
const SHADOW_BLUR_RADIUS: float = 18.0
static var _global_clouds_enabled: bool = true

var _cloud_textures: Array[Texture2D] = []
var _shadow_material: ShaderMaterial
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _map_size: float = 1000.0

func _ready() -> void:
	_rng.randomize()
	var map_generator: MapGenerator = get_parent() as MapGenerator
	_map_size = 3000.0
	_load_cloud_textures()
	_setup_shadow_material()
	if _global_clouds_enabled:
		_spawn_clouds()
	set_clouds_enabled(_global_clouds_enabled)

func _process(delta: float) -> void:
	var respawn_count: int = 0
	for child in get_children():
		var cloud_pair := child as Node2D
		var speed: float = float(cloud_pair.get_meta("speed"))
		cloud_pair.position.x += speed * delta
		if cloud_pair.position.x >= DESPAWN_X:
			cloud_pair.queue_free()
			respawn_count += 1
	for i in range(respawn_count):
		_spawn_cloud_pair_at(RESPAWN_X, _rng.randf_range(-1000.0, _map_size))

func _spawn_clouds() -> void:
	for i in range(CLOUD_COUNT):
		_spawn_cloud_pair_at(_rng.randf_range(-1000.0, _map_size), _rng.randf_range(-1000.0, _map_size))

func _load_cloud_textures() -> void:
	for i in range(1, CLOUD_TEXTURE_COUNT + 1):
		var texture_path := "res://images/cloud" + str(i) + ".png"
		_cloud_textures.append(load(texture_path))

func _setup_shadow_material() -> void:
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = load("res://cloud_shadow_blur.gdshader") as Shader
	_shadow_material.set_shader_parameter("blur_radius", SHADOW_BLUR_RADIUS)

func _spawn_cloud_pair_at(x_pos: float, y_pos: float) -> void:
	var cloud_pair := Node2D.new()
	cloud_pair.position = Vector2(x_pos, y_pos)
	cloud_pair.z_index = 250
	cloud_pair.set_meta("speed", _rng.randf_range(SPEED_MIN, SPEED_MAX))

	var texture: Texture2D = _cloud_textures[_rng.randi_range(0, _cloud_textures.size() - 1)]
	var scale_value: float = _rng.randf_range(SCALE_MIN, SCALE_MAX)

	var shadow := Sprite2D.new()
	shadow.texture = texture
	shadow.material = _shadow_material
	shadow.scale = Vector2(scale_value, scale_value)
	shadow.position = Vector2(SHADOW_X_OFFSET, SHADOW_Y_BASE + _rng.randf_range(0.0, SHADOW_Y_RANDOM))
	shadow.modulate = Color(0, 0, 0, 0.2)
	shadow.z_index = -1
	cloud_pair.add_child(shadow)

	var cloud := Sprite2D.new()
	cloud.texture = texture
	cloud.scale = Vector2(scale_value, scale_value)
	cloud.z_index = 0
	cloud_pair.add_child(cloud)
	var cloud_modulate: Color = cloud.modulate
	cloud_modulate.a = 0.85
	cloud.modulate = cloud_modulate

	add_child(cloud_pair)

func set_clouds_enabled(enabled: bool) -> void:
	_global_clouds_enabled = enabled
	visible = enabled
	set_process(enabled)
	if enabled and get_child_count() == 0:
		_spawn_clouds()

static func set_global_clouds_enabled(enabled: bool) -> void:
	_global_clouds_enabled = enabled

static func is_global_clouds_enabled() -> bool:
	return _global_clouds_enabled
