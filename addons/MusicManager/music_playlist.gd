class_name MusicPlaylist
extends Resource

## Name for the playlist
@export var name: String = ""

## Array that contains the song resource files for the playlist
@export var tracks: Array[MusicTrack]
