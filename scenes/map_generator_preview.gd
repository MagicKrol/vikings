extends Node2D

const PREVIEW_SEED_MIN: int = 0
const PREVIEW_SEED_MAX: int = 2147483647
const MAPGEN_GENERATOR: Script = preload("res://mapgen/mapgen_generator.gd")

var _seed: int = 187
var _biome_seed: int = MapgenConfig.NOISE_SEED
var _size: String = "S"
var _generated_map_data: Dictionary = {}

@onready var map_renderer: MapGenerator = get_node("MapRenderer") as MapGenerator
@onready var seed_input: LineEdit = get_node("UI/Controls/Margin/Parameters/SeedRow/SeedInput") as LineEdit
@onready var random_seed_button: Button = get_node("UI/Controls/Margin/Parameters/SeedRow/RandomSeedButton") as Button
@onready var biome_seed_input: LineEdit = get_node("UI/Controls/Margin/Parameters/BiomeSeedRow/BiomeSeedInput") as LineEdit
@onready var random_biome_seed_button: Button = get_node("UI/Controls/Margin/Parameters/BiomeSeedRow/RandomBiomeSeedButton") as Button
@onready var size_xs_button: Button = get_node("UI/Controls/Margin/Parameters/SizeRow/XS") as Button
@onready var size_s_button: Button = get_node("UI/Controls/Margin/Parameters/SizeRow/S") as Button
@onready var size_m_button: Button = get_node("UI/Controls/Margin/Parameters/SizeRow/M") as Button
@onready var size_l_button: Button = get_node("UI/Controls/Margin/Parameters/SizeRow/L") as Button
@onready var forests_slider: HSlider = get_node("UI/Controls/Margin/Parameters/ForestsSlider") as HSlider
@onready var hills_slider: HSlider = get_node("UI/Controls/Margin/Parameters/HillsSlider") as HSlider
@onready var mountains_slider: HSlider = get_node("UI/Controls/Margin/Parameters/MountainsSlider") as HSlider
@onready var sea_level_slider: HSlider = get_node("UI/Controls/Margin/Parameters/SeaLevelSlider") as HSlider
@onready var forests_value: Label = get_node("UI/Controls/Margin/Parameters/ForestsHeader/Value") as Label
@onready var hills_value: Label = get_node("UI/Controls/Margin/Parameters/HillsHeader/Value") as Label
@onready var mountains_value: Label = get_node("UI/Controls/Margin/Parameters/MountainsHeader/Value") as Label
@onready var sea_level_value: Label = get_node("UI/Controls/Margin/Parameters/SeaLevelHeader/Value") as Label

func _ready() -> void:
	random_seed_button.pressed.connect(_on_random_seed_pressed)
	seed_input.text_submitted.connect(_on_map_seed_submitted)
	seed_input.focus_exited.connect(_on_map_seed_focus_exited)
	random_biome_seed_button.pressed.connect(_on_random_biome_seed_pressed)
	biome_seed_input.text_submitted.connect(_on_biome_seed_submitted)
	biome_seed_input.focus_exited.connect(_on_biome_seed_focus_exited)
	size_xs_button.pressed.connect(_on_size_pressed.bind("XS"))
	size_s_button.pressed.connect(_on_size_pressed.bind("S"))
	size_m_button.pressed.connect(_on_size_pressed.bind("M"))
	size_l_button.pressed.connect(_on_size_pressed.bind("L"))
	_connect_slider(forests_slider, forests_value)
	_connect_slider(hills_slider, hills_value)
	_connect_slider(mountains_slider, mountains_value)
	_connect_slider(sea_level_slider, sea_level_value)
	_generate_preview()

func _connect_slider(slider: HSlider, value_label: Label) -> void:
	slider.value_changed.connect(_on_slider_value_changed.bind(value_label))
	slider.drag_ended.connect(_on_slider_drag_ended)

func _on_random_seed_pressed() -> void:
	_seed = _random_seed()
	seed_input.text = str(_seed)
	_generate_preview()

func _on_random_biome_seed_pressed() -> void:
	_biome_seed = _random_seed()
	biome_seed_input.text = str(_biome_seed)
	_generate_preview()

func _random_seed() -> int:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.randomize()
	return random.randi_range(PREVIEW_SEED_MIN, PREVIEW_SEED_MAX)

func _on_map_seed_submitted(text: String) -> void:
	_apply_map_seed_text(text)

func _on_map_seed_focus_exited() -> void:
	_apply_map_seed_text(seed_input.text)

func _apply_map_seed_text(text: String) -> void:
	var entered_seed: int = _validated_seed(text, _seed)
	seed_input.text = str(entered_seed)
	if entered_seed == _seed:
		return
	_seed = entered_seed
	_generate_preview()

func _on_biome_seed_submitted(text: String) -> void:
	_apply_biome_seed_text(text)

func _on_biome_seed_focus_exited() -> void:
	_apply_biome_seed_text(biome_seed_input.text)

func _apply_biome_seed_text(text: String) -> void:
	var entered_seed: int = _validated_seed(text, _biome_seed)
	biome_seed_input.text = str(entered_seed)
	if entered_seed == _biome_seed:
		return
	_biome_seed = entered_seed
	_generate_preview()

func _validated_seed(text: String, current_seed: int) -> int:
	if not text.is_valid_int():
		return current_seed
	return clampi(int(text), PREVIEW_SEED_MIN, PREVIEW_SEED_MAX)

func _on_size_pressed(size: String) -> void:
	if size == _size:
		return
	_size = size
	_generate_preview()

func _on_slider_value_changed(value: float, value_label: Label) -> void:
	value_label.text = "%.2f" % value

func _on_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		_generate_preview()

func _generate_preview() -> void:
	var generated: Dictionary = MAPGEN_GENERATOR.generate(_seed, _build_parameters())
	_generated_map_data = MAPGEN_GENERATOR.build_export(generated)
	map_renderer.render_map_data(_generated_map_data)

func _build_parameters() -> Dictionary:
	return {
		"size": _size,
		"noise_seed": _biome_seed,
		"forests": forests_slider.value,
		"hills": hills_slider.value,
		"mountains": mountains_slider.value,
		"sea_level": sea_level_slider.value
	}

func get_generated_map_data() -> Dictionary:
	return _generated_map_data
