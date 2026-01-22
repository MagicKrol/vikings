extends Node
class_name SoundManager

class Playlist:
	var tracks: Array[String] = []
	var shuffle_enabled: bool = false
	var repeat_enabled: bool = true
	var _order: Array[String] = []
	var _index: int = 0

	func _init(track_list: Array[String], shuffle: bool, repeat: bool = true) -> void:
		tracks = track_list.duplicate()
		shuffle_enabled = shuffle
		repeat_enabled = repeat
		_reset_order()

	func _reset_order() -> void:
		_order = tracks.duplicate()
		if shuffle_enabled:
			_order.shuffle()
		_index = 0

	func next_track_path() -> String:
		if _order.is_empty():
			return ""
		if _index >= _order.size():
			if not repeat_enabled:
				return ""
			_reset_order()
		var path := _order[_index]
		_index += 1
		return path

# Audio players for different sound effects
@onready var click_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var horn_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var battle_player: AudioStreamPlayer = AudioStreamPlayer.new()

# Playlists
const PLAYLIST_DEFS := {
	"tutorial": {
		"tracks": [
			"res://music/track2.mp3",
			"res://music/track1.mp3"
		],
		"shuffle": false,
		"repeat": true
	},
	"custom_map": {
		"tracks": [
			"res://music/track1.mp3",
			"res://music/track2.mp3",
			"res://music/track3.mp3",
			"res://music/track4.mp3",
			"res://music/track5.mp3",
			"res://music/track6.mp3",
			"res://music/track7.mp3"
		],
		"shuffle": true,
		"repeat": true
	}
}

# Audio stream resources
var main_menu_music: AudioStream
var game_music: AudioStream
var starting_horn: AudioStream
var retreat_horn: AudioStream
var battle_sound: AudioStream

# Music state
var music_enabled: bool = false
var sound_enabled: bool = false
var _current_playlist: Playlist = null
var _audio_cache: Dictionary = {}

func _ready():
	# Add the audio players to the scene tree
	add_child(click_player)
	add_child(music_player)
	add_child(horn_player)
	add_child(battle_player)
	click_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	horn_player.process_mode = Node.PROCESS_MODE_ALWAYS
	battle_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.finished.connect(_on_music_finished)
	battle_player.volume_db = linear_to_db(0.5)
	music_player.volume_db = linear_to_db(0.5)
	
	# Load the click sound
	var click_sound = load("res://sounds/click.wav") as AudioStream
	if click_sound:
		click_player.stream = click_sound
	else:
		DebugLogger.log("GameInit", "Error: Could not load click.wav")
	
	# Load the main menu music
	main_menu_music = load("res://music/main_menu.mp3") as AudioStream
	if not main_menu_music:
		DebugLogger.log("GameInit", "Error: Could not load main_menu.mp3")
	
	# Load the game music
	game_music = load("res://music/track1.mp3") as AudioStream
	if not game_music:
		DebugLogger.log("GameInit", "Error: Could not load track1.mp3")
	
	# Load the starting horn
	starting_horn = load("res://sounds/Starting_horn.mp3") as AudioStream
	if not starting_horn:
		DebugLogger.log("GameInit", "Error: Could not load Starting_horn.mp3")
	
	# Load the retreat horn
	retreat_horn = load("res://sounds/retreat_horn.mp3") as AudioStream
	if not retreat_horn:
		DebugLogger.log("GameInit", "Error: Could not load retreat_horn.mp3")
	
	# Load the battle sound
	battle_sound = load("res://sounds/battle.wav") as AudioStream
	if not battle_sound:
		DebugLogger.log("GameInit", "Error: Could not load battle.wav")

func _unhandled_input(event: InputEvent) -> void:
	"""Handle keyboard input for music toggle"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			toggle_music()

func click_sound() -> void:
	"""Play click sound effect"""
	if click_player and click_player.stream and sound_enabled:
		click_player.play()

func play_retreat_horn() -> void:
	if horn_player and retreat_horn and sound_enabled:
		horn_player.stream = retreat_horn
		horn_player.play(4.08)
		# Stop at 9.2s to keep playback within the desired slice
		var timer := get_tree().create_timer(5.12)
		timer.timeout.connect(func():
			if horn_player.stream == retreat_horn:
				horn_player.stop())

func play_battle_sound() -> void:
	if battle_sound and sound_enabled:
		battle_player.stream = battle_sound
		battle_player.volume_db = linear_to_db(0.5)
		battle_player.play()

func stop_battle_sound() -> void:
	battle_player.stop()

func fade_out_battle_sound(duration: float = 2.0) -> void:
	var tween := create_tween()
	tween.tween_property(battle_player, "volume_db", -80.0, duration)
	tween.finished.connect(func():
		battle_player.stop()
		battle_player.volume_db = linear_to_db(0.5))

func play_main_menu_music() -> void:
	"""Play main menu music"""
	if music_player and main_menu_music and music_enabled:
		music_player.stream = main_menu_music
		music_player.play()

func stop_main_menu_music() -> void:
	"""Stop main menu music"""
	pass
	#if music_player:
		#music_player.stop()

func play_game_start_sequence() -> void:
	"""Play starting horn, wait 3 seconds, then play game music"""
	DebugLogger.log("GameInit", "play_game_start_sequence called")
	DebugLogger.log("GameInit", "horn_player: " + str(horn_player))
	DebugLogger.log("GameInit", "starting_horn: " + str(starting_horn))
	
	if music_enabled and horn_player and starting_horn:
		DebugLogger.log("GameInit", "Playing starting horn...")
		horn_player.stream = starting_horn
		horn_player.play()
		
		# Wait 3 seconds then start game music
		DebugLogger.log("GameInit", "Waiting 3 seconds...")
		await get_tree().create_timer(3.0).timeout
		DebugLogger.log("GameInit", "Starting game music...")
		play_game_music()
	else:
		DebugLogger.log("GameInit", "Error: Missing horn_player or starting_horn audio")

func play_game_music() -> void:
	"""Play main game music"""
	DebugLogger.log("GameInit", "play_game_music called")
	DebugLogger.log("GameInit", "music_player: " + str(music_player))
	DebugLogger.log("GameInit", "game_music: " + str(game_music))
	
	if _current_playlist != null:
		_play_from_current_playlist()
		return
	if music_enabled:
		DebugLogger.log("GameInit", "Playing game music...")
		music_player.stream = game_music
		music_player.play()

func stop_all_music() -> void:
	"""Stop all music and horn sounds"""
	if music_player:
		music_player.stop()
	if horn_player:
		horn_player.stop()

func toggle_music() -> void:
	"""Toggle music on/off"""
	music_enabled = !music_enabled
	DebugLogger.log("GameInit", "Music " + ("enabled" if music_enabled else "disabled"))
	
	if not music_enabled:
		# Stop all music when disabled
		stop_all_music()
	else:
		# Resume appropriate music when enabled
		# Check if we're in main menu or game and restart appropriate music
		var main_scene = get_tree().current_scene
		if main_scene and main_scene.name == "MainMenu":
			play_main_menu_music()
		else:
			# Assume we're in game
			play_game_music()

func is_music_enabled() -> bool:
	"""Check if music is currently enabled"""
	return music_enabled

func set_music_enabled(enabled: bool) -> void:
	"""Set music enabled state programmatically"""
	if music_enabled != enabled:
		toggle_music()

func set_active_playlist(name: String) -> void:
	"""Set the current playlist using predefined definitions"""
	if not PLAYLIST_DEFS.has(name):
		DebugLogger.log("GameInit", "Warning: Playlist " + name + " not defined")
		return
	var definition: Dictionary = PLAYLIST_DEFS[name]
	var tracks: Array[String] = _build_track_list(definition.get("tracks", []))
	var shuffle: bool = bool(definition.get("shuffle", false))
	var repeat: bool = bool(definition.get("repeat", true))
	_current_playlist = Playlist.new(tracks, shuffle, repeat)

func clear_playlist() -> void:
	_current_playlist = null

func _on_music_finished() -> void:
	if _current_playlist != null and music_enabled:
		_play_from_current_playlist()

func _play_from_current_playlist() -> void:
	if _current_playlist == null:
		return
	var next_path := _current_playlist.next_track_path()
	if next_path == "":
		return
	var stream := _get_stream(next_path)
	if stream == null:
		DebugLogger.log("GameInit", "Error: Could not load stream at " + next_path)
		return
	music_player.stream = stream
	music_player.play()

func _get_stream(path: String) -> AudioStream:
	if _audio_cache.has(path):
		return _audio_cache[path] as AudioStream
	var stream = load(path) as AudioStream
	if stream != null:
		_audio_cache[path] = stream
	return stream

func _build_track_list(raw: Array) -> Array[String]:
	var list: Array[String] = []
	for item in raw:
		list.append(String(item))
	return list
