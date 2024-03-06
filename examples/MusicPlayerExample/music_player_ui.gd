extends CanvasLayer

# Do not set these variables manually in editor.
var is_playing_music: bool = false
var is_looping: bool = false
var is_shuffling: bool = false
var is_crossfading: bool = false
var is_manual_seeking: bool = false
var is_now_playing: bool = true
var is_playing_from_playlist: bool = false
var fade_time: float = 1.0
var bus: String

# Contains all songs. On runtime, combines songs and songs from playlists. Will avoid duplicates
var song_library:= MusicPlaylist.new()

# Variable to keep track of which music player is active in MusicManager
var current_player

# Variable to keep track of which song is actively being played
var current_song

# Variable to keep track of which playlist is actively being played from the Playlists tab
var current_playlist

# Songs and Playlists input variables. Add your music via the Inspector
@export var songs: Array[MusicTrack]
@export var playlists: Array[MusicPlaylist]

# All Songs tab variables
@onready var all_songs: ItemList = %AllSongsList

# Playlists tab variables
@onready var playlist_options: OptionButton = %PlaylistOptions
@onready var active_playlist: ItemList = %ActivePlaylist

# Bottom Panel/player UI control variables
@onready var play_pause_button: Button = %PlayPauseButton
@onready var previous_button: Button = %PreviousButton
@onready var next_button: Button = %NextButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var seek_slider: HSlider = %SeekSlider
@onready var seek_current: Label = %SeekCurrentLabel
@onready var seek_max: Label = %SeekMaxLabel
@onready var now_playing_label: RichTextLabel = %NowPlayingLabel
@onready var now_playing_anim: AnimationPlayer = now_playing_label.get_node("AnimationPlayer")

func _ready():
	MusicManager.song_changed.connect(_on_song_changed)
	MusicManager.all_music_finished.connect(_on_all_music_finished)
	
	# Set the bus for volume control functionality
	if MusicManager.bus:
		bus = MusicManager.bus
	else:
		bus = "Master"
		
	# Add songs to song library
	if not songs.is_empty():
		for song in songs:
			if is_instance_valid(song):
				song_library.tracks.append(song)
			
	# Add songs from playlists to song library if they have not already been added
	if not playlists.is_empty():
		for playlist in playlists:
			if is_instance_valid(playlist):
				playlist_options.add_item(playlist.name) # Add playlist to available playlist options
				for song in playlist.tracks:
					if not song in song_library.tracks:
						song_library.tracks.append(song)
						
	# Add songs to all_songs ItemList for visual representation
	var song_num = 0
	for song in song_library.tracks:
		song_num += 1
		if song.artist:
			all_songs.add_item(str(song_num) + ") " + song.name + " | " + song.artist + " | " + convert_length(song.track.get_length()))
		else:
			all_songs.add_item(str(song_num) + ") " + song.name + " | " + convert_length(song.track.get_length()))
		
	# Set the initial volume value for the bus
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus)))


func _process(_delta):
	# Manage seeking to sync up the current player with the seeking control values and vice versa
	if is_playing_music:
		seek_slider.editable = true
		seek_current.text = str(convert_length(current_player.get_playback_position()))
	
		if not is_manual_seeking:
			seek_slider.value = current_player.get_playback_position()
		else:
			current_player.seek(seek_slider.value)
	else:
		seek_slider.editable = false


# Trigger when the MusicManager has changed songs. Update the player UI with the new song
func _on_song_changed(new_song):
	current_song = new_song
	current_player = MusicManager.current_player
		
	seek_max.text = str(convert_length(new_song.track.get_length()))
	seek_slider.max_value = new_song.track.get_length()
	
	is_playing_music = true
	play_pause_button.text = "II"
	
	if play_pause_button.disabled:
		play_pause_button.disabled = false
		next_button.disabled = false
		previous_button.disabled = false
		play_pause_button.tooltip_text = "Pause"
	
	if is_now_playing:
		now_playing_label.text = "Now playing:\n" + new_song.name
		if new_song.artist != "":
			now_playing_label.text += " by " + new_song.artist
		now_playing_anim.play("SONG_CHANGED")
		await now_playing_anim.animation_finished
		now_playing_anim.play("PLAYING")
	else:
		now_playing_anim.play("RESET")


# Trigger when the MusicManager has run out of things to do and has no more music to play
func _on_all_music_finished():
	# When the user deselects the playlist they were playing from and the song has finished
	if is_playing_from_playlist and not current_playlist:
		current_song = null
		is_playing_music = false
		now_playing_anim.play("RESET")
		seek_max.text = "0:00"
		seek_current.text = "0:00"
		seek_slider.max_value = 100
		seek_slider.value = 0.0
		play_pause_button.text = "▷"
		play_pause_button.tooltip_text = "Play"
		play_pause_button.disabled = true
		next_button.disabled = true
		previous_button.disabled = true
		
	# Handle looping that is set after the song has already started playing
	elif is_looping:
		handle_looping()
		
	# Handle shuffling (this is not the same as playlist shuffling via MusicManager)
	elif is_shuffling:
		handle_shuffling()
		
	# Go to next song in the library/playlist chronologically
	else:
		_on_next_button_pressed()


# Convert raw seconds into a more readable format; 62 => 1:02
func convert_length(time_in_sec: float) -> String:
	@warning_ignore("integer_division")
	var minutes = int(time_in_sec) / 60
	time_in_sec -= minutes * 60
	var seconds = int(time_in_sec)
	
	# Round up to the nearest second
	if time_in_sec - seconds > 0:
		seconds += 1
		
	# Handle 60 seconds
	if seconds == 60:
		seconds = 0
		minutes += 1
		
	# Format seconds with leading zero
	var seconds_str = str(seconds)
	if seconds < 10:
		seconds_str = "0" + seconds_str
		
	return str(minutes) + ":" + seconds_str


# Handle looping that is set after the song has already started playing
func handle_looping():
	var song_idx = 0 # Index used to iteriate ItemLists: all_songs and active_playlist
	var song_num = 0 # The number applied to each item's text for the ItemLists: all_songs and active_playlist
	
	if not is_playing_from_playlist:
		song_idx = all_songs.get_selected_items()[0]
		for song in song_library.tracks:
			song_num += 1
			if song.artist:
				if all_songs.get_item_text(song_idx) == str(song_num) + ") " + song.name + " | " + song.artist + " | " + convert_length(song.track.get_length()):
					MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)
			else:
				if all_songs.get_item_text(song_idx) == str(song_num) + ") " + song.name + " | " + convert_length(song.track.get_length()):
					MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)
	else:
		if current_playlist:
			song_idx = active_playlist.get_selected_items()[0]
			for song in current_playlist.tracks:
				song_num += 1
				if song.artist:
					if active_playlist.get_item_text(song_idx) == str(song_num) + ") " + song.name + " | " + song.artist + " | " + convert_length(song.track.get_length()):
						MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)
				else:
					if active_playlist.get_item_text(song_idx) == str(song_num) + ") " + song.name + " | " + convert_length(song.track.get_length()):
						MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)


# Handle shuffling (this is not the same as playlist shuffling via MusicManager)
func handle_shuffling():
	var song_idx = 0
	var song_num = 0
	
	if not is_playing_from_playlist:
		song_idx = randi_range(0, all_songs.item_count-1)
		while song_idx == all_songs.get_selected_items()[0]:
			song_idx = randi_range(0, all_songs.item_count-1)
		all_songs.select(song_idx)
		for song in song_library.tracks:
			song_num += 1
			if song.artist:
				if all_songs.get_item_text(song_idx) == str(song_num) + ") " + song.name + " | " + song.artist + " | " + convert_length(song.track.get_length()):
					MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)
			else:
				if all_songs.get_item_text(song_idx) == str(song_num) + ") " + song.name + " | " + convert_length(song.track.get_length()):
					MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)
	else:
		if current_playlist:
			song_idx = randi_range(0, active_playlist.item_count-1)
			while song_idx == active_playlist.get_selected_items()[0]:
				song_idx = randi_range(0, active_playlist.item_count-1)
			active_playlist.select(song_idx)
			for song in current_playlist.tracks:
				song_num += 1
				if song.artist:
					if active_playlist.get_item_text(song_idx) == str(song_num) + ") " + song.name + " | " + song.artist + " | " + convert_length(song.track.get_length()):
						MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)
				else:
					if active_playlist.get_item_text(song_idx) == str(song_num) + ") " + song.name + " | " + convert_length(song.track.get_length()):
						MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)


func _on_play_pause_button_pressed():
	# Play/Resume music
	if not is_playing_music:
		MusicManager.resume_music.emit()
		is_playing_music = true
		play_pause_button.text = "II"
		play_pause_button.tooltip_text = "Pause"
			
	# Pause Music
	else:
		MusicManager.pause_music.emit()
		is_playing_music = false
		play_pause_button.text = "▷"
		play_pause_button.tooltip_text = "Play"


func _on_all_songs_list_item_selected(index):
	if is_playing_from_playlist:
		is_playing_from_playlist = false
		active_playlist.deselect_all()
		
	var song_num = 0
	for song in song_library.tracks:
		song_num += 1
		if song.artist:
			if all_songs.get_item_text(index) == str(song_num) + ") " + song.name + " | " + song.artist + " | " + convert_length(song.track.get_length()):
				MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)
		else:
			if all_songs.get_item_text(index) == str(song_num) + ") " + song.name + " | " + convert_length(song.track.get_length()):
				MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)


func _on_loop_song_button_toggled(toggled_on):
	if toggled_on:
		is_looping = true
		MusicManager.is_looping_song = true
	else:
		is_looping = false
		MusicManager.is_looping_song = false


func _on_next_button_pressed():
	if is_looping:
		handle_looping()
		
	elif is_shuffling:
		handle_shuffling()
		
	elif not is_playing_from_playlist:
		var next_song_idx = all_songs.get_selected_items()[0]+1
		
		if next_song_idx > all_songs.item_count-1:
			next_song_idx = 0
			
		all_songs.select(next_song_idx)
		var song_num = 0
		for song in song_library.tracks:
			song_num += 1
			if song.artist:
				if all_songs.get_item_text(next_song_idx) == str(song_num) + ") " + song.name + " | " + song.artist + " | " + convert_length(song.track.get_length()):
					MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)
			else:
				if all_songs.get_item_text(next_song_idx) == str(song_num) + ") " + song.name + " | " + convert_length(song.track.get_length()):
					MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)
	else:
		if current_playlist:
			var next_song_idx = active_playlist.get_selected_items()[0]+1
			
			if next_song_idx > active_playlist.item_count-1:
				next_song_idx = 0
				
			active_playlist.select(next_song_idx)
			var song_num = 0
			for song in current_playlist.tracks:
				song_num += 1
				if song.artist:
					if active_playlist.get_item_text(next_song_idx) == str(song_num) + ") " + song.name + " | " + song.artist + " | " + convert_length(song.track.get_length()):
						MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)
				else:
					if active_playlist.get_item_text(next_song_idx) == str(song_num) + ") " + song.name + " | " + convert_length(song.track.get_length()):
						MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)


func _on_previous_button_pressed():
	if is_looping:
		handle_looping()
		
	elif is_shuffling:
		handle_shuffling()
		
	elif not is_playing_from_playlist:
		var previous_song_idx = all_songs.get_selected_items()[0]-1
		
		if previous_song_idx < 0:
			previous_song_idx = all_songs.item_count-1
			
		all_songs.select(previous_song_idx)
		var song_num = 0
		for song in song_library.tracks:
			song_num += 1
			if song.artist:
				if all_songs.get_item_text(previous_song_idx) == str(song_num) + ") " + song.name + " | " + song.artist + " | " + convert_length(song.track.get_length()):
					MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)
			else:
				if all_songs.get_item_text(previous_song_idx) == str(song_num) + ") " + song.name + " | " + convert_length(song.track.get_length()):
					MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)
	else:
		if current_playlist:
			var previous_song_idx = active_playlist.get_selected_items()[0]-1
			
			if previous_song_idx < 0:
				previous_song_idx = active_playlist.item_count-1
				
			active_playlist.select(previous_song_idx)
			var song_num = 0
			for song in current_playlist.tracks:
				song_num += 1
				if song.artist:
					if active_playlist.get_item_text(previous_song_idx) == str(song_num) + ") " + song.name + " | " + song.artist + " | " + convert_length(song.track.get_length()):
						MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)
				else:
					if active_playlist.get_item_text(previous_song_idx) == str(song_num) + ") " + song.name + " | " + convert_length(song.track.get_length()):
						MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)


func _on_volume_slider_value_changed(value):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(value))


func _on_seek_slider_drag_started():
	is_manual_seeking = true


func _on_seek_slider_drag_ended(_value_changed):
	is_manual_seeking = false
	
	if is_crossfading:
		if is_playing_music:
			MusicManager.song_timer.start(current_song.track.get_length() - seek_slider.value - fade_time)
	else:
		if is_playing_music:
			MusicManager.song_timer.start(current_song.track.get_length() - seek_slider.value)


func _on_shuffle_button_toggled(toggled_on):
	if toggled_on:
		is_shuffling = true
	else:
		is_shuffling = false


func _on_crossfade_button_toggled(toggled_on):
	if toggled_on:
		is_crossfading = true
		MusicManager.is_crossfading = true
		if is_playing_music:
			MusicManager.song_timer.start(current_song.track.get_length() - seek_slider.value - fade_time)
	else:
		is_crossfading = false
		MusicManager.is_crossfading = false
		if is_playing_music:
			MusicManager.song_timer.start(current_song.track.get_length() - seek_slider.value)


func _on_fade_time_box_value_changed(value):
	fade_time = value
	MusicManager.crossfade_time = value
	
	if is_crossfading:
		if is_playing_music:
			MusicManager.song_timer.start(current_song.track.get_length() - seek_slider.value - fade_time)


func _on_now_playing_button_toggled(toggled_on):
	if toggled_on:
		is_now_playing = true
		if is_playing_music:
			now_playing_label.text = "Now playing:\n" + current_song.name
			if current_song.artist != "":
				now_playing_label.text += " by " + current_song.artist
			now_playing_anim.play("PLAYING")
	else:
		is_now_playing = false
		now_playing_anim.play("RESET")


func _on_active_playlist_item_selected(index):
	if not is_playing_from_playlist:
		is_playing_from_playlist = true
		all_songs.deselect_all()
		
	var song_num = 0
	for song in current_playlist.tracks:
		song_num += 1
		if song.artist:
			if active_playlist.get_item_text(index) == str(song_num) + ") " + song.name + " | " + song.artist + " | " + convert_length(song.track.get_length()):
				MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)
		else:
			if active_playlist.get_item_text(index) == str(song_num) + ") " + song.name + " | " + convert_length(song.track.get_length()):
				MusicManager.play_song.emit(song, is_looping, is_crossfading, fade_time)


func _on_playlist_options_item_selected(index):
	active_playlist.clear()
	if index == 0:
		current_playlist = null
	else:
		for playlist in playlists:
			if is_instance_valid(playlist):
				if playlist_options.get_item_text(index) == playlist.name:
					current_playlist = playlist
					var song_num = 0
					for song in playlist.tracks:
						song_num += 1
						if song.artist:
							active_playlist.add_item(str(song_num) + ") " + song.name + " | " + song.artist + " | " + convert_length(song.track.get_length()))
						else:
							active_playlist.add_item(str(song_num) + ") " + song.name + " | " + convert_length(song.track.get_length()))
