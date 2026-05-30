extends Control
class_name SplashScreen

const FADE_IN_DURATION_SECONDS: float = 1.0
const HOLD_AFTER_FADE_SECONDS: float = 1.0
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu.tscn"

@onready var background: TextureRect = get_node("Background") as TextureRect

func _ready() -> void:
	var start_color: Color = background.modulate
	start_color.a = 0.0
	background.modulate = start_color
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(background, "modulate:a", 1.0, FADE_IN_DURATION_SECONDS)
	await fade_tween.finished
	await get_tree().create_timer(HOLD_AFTER_FADE_SECONDS).timeout
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
