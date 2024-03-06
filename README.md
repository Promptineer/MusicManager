# Music Manager

Music Manager is a powerful addon that allows you to easily manage and control music playback in your Godot projects. It provides a convenient way to play songs, playlists, loop music, crossfade between tracks, and more.

## Features

- Play individual songs or playlists
- Loop songs or entire playlists
- Crossfade between songs with adjustable crossfade time
- Pause, resume, and stop music playback
- Shuffle playlists
- Signals for convenient integration with your game logic
- Persistent music even when changing scenes
- No need for nodes, just use signals anywhere in your code!

## Installation

1. Clone or download the repository from [GitHub](https://github.com/Promptineer/MusicManager).
2. Copy the `addons/music_manager` directory into your Godot project's `addons` directory.
3. Enable the Music Manager addon in your Godot project by navigating to `Project > Project Settings > Plugins` and enabling the "Music Manager" plugin.

## Usage

The Music Manager addon is designed to be used primarily through signals. Once enabled, it acts as a singleton, allowing you to control music playback from anywhere in your project.

### Signals

- `play_song(song: MusicTrack, is_looping: bool, is_fading: bool, fade_time: float)`: Play a song. Set `is_looping` to loop the song, `is_fading` to enable crossfading, and `fade_time` to set the crossfade duration (between 0.25 and 4 seconds).
- `play_playlist(playlist: MusicPlaylist, is_looping: bool, is_shuffling: bool, is_fading: bool, fade_time: float)`: Play a playlist. Set `is_looping` to loop the playlist, `is_shuffling` to shuffle the playlist order, `is_fading` to enable crossfading, and `fade_time` to set the crossfade duration.
- `stop_music`: Stop all currently playing music.
- `pause_music`: Pause all currently playing music.
- `resume_music`: Resume paused music.

### Example Usage

```gdscript
# Play a song with crossfading
var song = MusicTrack.new("res://path/to/song.ogg")
MusicManager.play_song.emit(song, false, true, 1.0)

# Play a playlist, looping and shuffling
var playlist = MusicPlaylist.new([
   MusicTrack.new("res://path/to/song1.ogg"),
   MusicTrack.new("res://path/to/song2.ogg"),
   MusicTrack.new("res://path/to/song3.ogg")
])
MusicManager.play_playlist.emit(playlist, true, true, false, 0.0)

# Stop all music
MusicManager.stop_music.emit()
