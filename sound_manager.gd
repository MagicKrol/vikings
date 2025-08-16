extends Node
class_name SoundManager

# Audio players for different sound effects
@onready var click_player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready():
	# Add the audio player to the scene tree
	add_child(click_player)
	
	# Load the click sound
	var click_sound = load("res://sounds/click.wav") as AudioStream
	if click_sound:
		click_player.stream = click_sound
	else:
		print("[SoundManager] Error: Could not load click.wav")

func click_sound() -> void:
	"""Play click sound effect"""
	if click_player and click_player.stream:
		click_player.play()