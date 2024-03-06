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

1. Clone or download the repository. Or you can download an official release in the side-bar.
2. Copy the `addons/music_manager` directory into your Godot project's `addons` directory.
3. Enable the Music Manager addon in your Godot project by navigating to `Project > Project Settings > Plugins` and enabling the "Music Manager" plugin.

## Usage

The Music Manager addon is designed to be used primarily through signals. Once enabled, it acts as a singleton, allowing you to control music playback from anywhere in your project. Even when changing scenes.

### Signals

- `play_song(song: MusicTrack, is_looping: bool, is_fading: bool, fade_time: float)`: Play a song. Set `is_looping` to loop the song, `is_fading` to enable crossfading, and `fade_time` to set the crossfade duration (between 0.25 and 4 seconds).
- `play_playlist(playlist: MusicPlaylist, is_looping: bool, is_shuffling: bool, is_fading: bool, fade_time: float)`: Play a playlist. Set `is_looping` to loop the playlist, `is_shuffling` to shuffle the playlist order, `is_fading` to enable crossfading, and `fade_time` to set the crossfade duration.
- `stop_music`: Stop all currently playing music.
- `pause_music`: Pause all currently playing music.
- `resume_music`: Resume paused music.

### Example Usage
To create a song, simply create a new resource file that inherits MusicTrack.

![Create new resource file](https://i.imgur.com/EoaUCJL.png)

![Create new MusicTrack](https://i.imgur.com/DiV6t7K.png)

Add the audio file, name, etc. in the Inspector to your new MusicTrack resource.

![Edit MusicTrack](https://i.imgur.com/R5xcBsn.png)

To create a playlist, it is essentially the same as making a song. Instead you will create a resource file that inherits MusicPlaylist.

![Create new resource file](https://i.imgur.com/EoaUCJL.png)

![Create new MusicPlaylist](https://i.imgur.com/05gfpQu.png)

Add your MusicTrack files in the Inspector.

![Edit MusicPlaylist](https://i.imgur.com/0ex2bi2.png)

And now you can play your songs or playlists from any script in your project!

```gdscript
# Play a song with crossfading
var song = preload("res://new_track.res")
MusicManager.play_song.emit(song, false, true, 1.0)

# Play a playlist, looping and shuffling
var playlist = preload("res://new_playlist.res")
MusicManager.play_playlist.emit(playlist, true, true, false, 0.0)
```

I wouldn't recommend declaring the variables this way, I would recommend using an `@export var`. You can find the MusicPlayerExample in the examples directory that will show you much more use-cases of what the add-on can do.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

Note: Specific licenses apply to .ogg files in the free examples. See examples/assets/MusicPlayerExample/LICENSE for details
