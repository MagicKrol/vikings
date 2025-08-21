extends Node
class_name SoundManager

# Audio players for different sound effects
@onready var click_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var horn_player: AudioStreamPlayer = AudioStreamPlayer.new()

# Audio stream resources
var main_menu_music: AudioStream
var game_music: AudioStream
var starting_horn: AudioStream

func _ready():
	# Add the audio players to the scene tree
	add_child(click_player)
	add_child(music_player)
	add_child(horn_player)
	
	# Load the click sound
	var click_sound = load("res://sounds/click.wav") as AudioStream
	if click_sound:
		click_player.stream = click_sound
	else:
		print("[SoundManager] Error: Could not load click.wav")
	
	# Load the main menu music
	main_menu_music = load("res://music/main_menu.mp3") as AudioStream
	if not main_menu_music:
		print("[SoundManager] Error: Could not load main_menu.mp3")
	
	# Load the game music
	game_music = load("res://music/track1.mp3") as AudioStream
	if not game_music:
		print("[SoundManager] Error: Could not load track1.mp3")
	
	# Load the starting horn
	starting_horn = load("res://sounds/Starting_horn.mp3") as AudioStream
	if not starting_horn:
		print("[SoundManager] Error: Could not load Starting_horn.mp3")

func click_sound() -> void:
	"""Play click sound effect"""
	if click_player and click_player.stream:
		click_player.play()

func play_main_menu_music() -> void:
	"""Play main menu music"""
	if music_player and main_menu_music:
		music_player.stream = main_menu_music
		music_player.play()

func stop_main_menu_music() -> void:
	"""Stop main menu music"""
	if music_player:
		music_player.stop()

func play_game_start_sequence() -> void:
	"""Play starting horn, wait 3 seconds, then play game music"""
	print("[SoundManager] play_game_start_sequence called")
	print("[SoundManager] horn_player: ", horn_player)
	print("[SoundManager] starting_horn: ", starting_horn)
	
	if horn_player and starting_horn:
		print("[SoundManager] Playing starting horn...")
		horn_player.stream = starting_horn
		horn_player.play()
		
		# Wait 3 seconds then start game music
		print("[SoundManager] Waiting 3 seconds...")
		await get_tree().create_timer(3.0).timeout
		print("[SoundManager] Starting game music...")
		play_game_music()
	else:
		print("[SoundManager] Error: Missing horn_player or starting_horn audio")

func play_game_music() -> void:
	"""Play main game music"""
	print("[SoundManager] play_game_music called")
	print("[SoundManager] music_player: ", music_player)
	print("[SoundManager] game_music: ", game_music)
	
	if music_player and game_music:
		print("[SoundManager] Playing game music...")
		music_player.stream = game_music
		music_player.play()
	else:
		print("[SoundManager] Error: Missing music_player or game_music audio")

func stop_all_music() -> void:
	"""Stop all music and horn sounds"""
	if music_player:
		music_player.stop()
	if horn_player:
		horn_player.stop()