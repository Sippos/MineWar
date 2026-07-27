extends Node

var _player: AudioStreamPlayer
var _main_menu_music: AudioStream = preload("res://Music/MainMenuMusic.ogg")
var _in_game_tracks: Array[AudioStream] = [
	preload("res://Music/BelowTheRock_1.ogg"),
	preload("res://Music/BelowTheRock_2.ogg"),
	preload("res://Music/BelowTheBedrock3.ogg")
]

var _is_playing_main_menu := false
var _is_playing_in_game := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)
	_player.finished.connect(_on_track_finished)
	
	if _main_menu_music is AudioStreamOggVorbis:
		_main_menu_music.loop = true
		
	for track in _in_game_tracks:
		if track is AudioStreamOggVorbis:
			track.loop = false
			
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_on_scene_changed")

func _on_scene_changed() -> void:
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return
		
	var path = current_scene.scene_file_path
	var is_main_menu = path.ends_with("menu.tscn") or path.ends_with("boot.tscn") or path.ends_with("launch_router.tscn")
	
	if is_main_menu:
		play_main_menu_music()
	else:
		play_in_game_music()

func play_main_menu_music() -> void:
	if _is_playing_main_menu and _player.playing:
		return
		
	_is_playing_main_menu = true
	_is_playing_in_game = false
	_player.stream = _main_menu_music
	_player.play()

func play_in_game_music() -> void:
	if _is_playing_in_game and _player.playing:
		return
		
	_is_playing_main_menu = false
	_is_playing_in_game = true
	_play_random_in_game_track()

func _play_random_in_game_track() -> void:
	if _in_game_tracks.is_empty():
		return
	
	var random_track = _in_game_tracks[randi() % _in_game_tracks.size()]
	
	if _in_game_tracks.size() > 1 and _player.stream == random_track:
		var curr_index = _in_game_tracks.find(random_track)
		var offset = (randi() % (_in_game_tracks.size() - 1)) + 1
		random_track = _in_game_tracks[(curr_index + offset) % _in_game_tracks.size()]
		
	_player.stream = random_track
	_player.play()

func _on_track_finished() -> void:
	if _is_playing_in_game:
		_play_random_in_game_track()
	elif _is_playing_main_menu:
		_player.play()
