extends Node

signal song_changed
signal all_music_finished

# Emit this signal to play any song -> MusicManager.play_song.emit(song, is_looping, etc.)
signal play_song(song: MusicTrack, is_looping: bool, is_fading: bool, fade_time: float)

# Emit this signal to play any playlist -> MusicManager.play_playlist.emit(playlist, is_looping, etc.)
signal play_playlist(playlist: MusicPlaylist, is_looping: bool, is_shuffling: bool, is_fading: bool, fade_time: float)

# Emit this signal to stop all currently playing music -> MusicManager.stop_music.emit()
signal stop_music

# Emit this signal to pause all currently playing music -> MusicManager.pause_music.emit()
signal pause_music

# Emit this signal to resume music paused on the current player -> MusicManager.resume_music.emit()
signal resume_music

# If set to true, crossfades between songs. This is set via play_song and play_playlist signals
var is_crossfading: bool = false

# If set to true, loops the current song. This is set via play_song signal
var is_looping_song: bool = false

# Persistent container for looping the entire current playlist which is set via play_playlist signal
var is_looping_playlist: bool = false

# Crossfade time (Must be between 0.25 - 4 seconds). This is set via signals
var crossfade_time: float = 1.0

# The index used to iterate through the current_playlist
var current_song_idx: int = 0

# The current song being played
var current_song: MusicTrack

# The playlist is set with the play_playlist signal, then it will automatically handle changing songs
var current_playlist: MusicPlaylist

# The active music player. Useful for utilizing seek() and get_playback_position() externally
var current_player: AudioStreamPlayer

@export_category("Settings")
## The bus for the music players. If left blank, defaults to Master.
@export var bus: String

# AudioStreamPlayers for playing the music
@onready var music_player: AudioStreamPlayer = $MusicPlayer1
@onready var music_player_2: AudioStreamPlayer = $MusicPlayer2

# Timer that keeps track when a song has finished playing
@onready var song_timer: Timer = $SongTimer

# AnimationPlayer for handling the crossfade effect between music players
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	play_song.connect(_on_play_song)
	play_playlist.connect(_on_play_playlist)
	stop_music.connect(_on_stop_music)
	pause_music.connect(_on_pause_music)
	resume_music.connect(_on_resume_music)
	
	if bus:
		music_player.bus = bus
		music_player_2.bus = bus


func _on_play_song(song: MusicTrack, is_looping: bool, is_fading: bool, fade_time: float) -> void:
	current_song = song
	is_looping_song = is_looping
	is_crossfading = is_fading
	crossfade_time = fade_time
	
	if is_crossfading:
		_change_with_crossfade(song)
	else:
		stop_music.emit()
		music_player.stream = song.track
		music_player.volume_db = 0.0
		music_player.play()
		current_player = music_player
		song_timer.start(song.track.get_length())
		song_changed.emit(song)


func _on_play_playlist(playlist: MusicPlaylist, is_looping: bool, is_shuffling: bool, is_fading: bool, fade_time: float) -> void:
	current_song_idx = 0
	is_crossfading = is_fading
	crossfade_time = fade_time
	current_playlist = playlist
	is_looping_playlist = is_looping
	
	if is_shuffling:
		current_playlist.tracks.shuffle()
		
	current_song = current_playlist.tracks[0]
	
	if is_crossfading:
		_change_with_crossfade(current_song)
	else:
		stop_music.emit()
		music_player.stream = current_song.track
		music_player.volume_db = 0.0
		music_player.play()
		current_player = music_player
		song_timer.start(current_song.track.get_length())


func _change_with_crossfade(song: MusicTrack) -> void:
	var speed_scale = 1.0 / crossfade_time
	speed_scale = clamp(speed_scale, 0.25, 4.0) 
	
	anim_player.speed_scale = speed_scale
		
	if music_player_2.playing:
		music_player.stream = song.track
		music_player.play()
		anim_player.play("FADE_TO_1")
		current_player = music_player
	else:
		music_player_2.stream = song.track
		music_player_2.play()
		anim_player.play("FADE_TO_2")
		current_player = music_player_2
		
	current_song = song
	song_timer.start(song.track.get_length() - crossfade_time)
	song_changed.emit(song)


func _on_stop_music() -> void:
	if music_player.playing:
		music_player.stop()
		
	if music_player_2.playing:
		music_player_2.stop()
		
	if not song_timer.is_stopped():
		song_timer.stop()
		
	current_song = null


func _on_pause_music() -> void:
	if music_player.playing:
		music_player.stream_paused = true
		song_timer.paused = true
		
	if music_player_2.playing:
		music_player_2.stream_paused = true
		song_timer.paused = true


func _on_resume_music() -> void:
	if not current_player.playing:
		current_player.stream_paused = false
		song_timer.paused = false


func _on_song_timer_timeout():
	# Loop the song that was previously playing
	if is_looping_song:
		if current_song:
			play_song.emit(current_song, is_looping_song, is_crossfading, crossfade_time)
		
	# Loop through the playlist after it has finished
	elif is_looping_playlist:
		current_song_idx += 1
		
		if current_song_idx > (len(current_playlist.tracks) -1):
			current_song_idx = 0
			
		var next_song = current_playlist.tracks[current_song_idx]
		
		if is_crossfading:
			_change_with_crossfade(next_song)
		else:
			stop_music.emit()
			music_player.stream = next_song.track
			music_player.volume_db = 0.0
			music_player.play()
			current_player = music_player
			song_timer.start(next_song.track.get_length())
			song_changed.emit(next_song)
		
	# Iterate through the playlist until it has finished
	elif not is_looping_playlist and current_playlist:
		current_song_idx += 1
		
		if current_song_idx > (len(current_playlist.tracks) -1):
			current_playlist = null
			current_song_idx = 0
		else:
			var next_song = current_playlist.tracks[current_song_idx]
			
			if is_crossfading:
				_change_with_crossfade(next_song)
			else:
				stop_music.emit()
				music_player.stream = next_song.track
				music_player.volume_db = 0.0
				music_player.play()
				current_player = music_player
				song_timer.start(next_song.track.get_length())
				song_changed.emit(next_song)
			
	# For when song/playlist has finished playing and there is nothing else to play
	else:
		current_song = null
		current_song_idx = 0
		all_music_finished.emit()
