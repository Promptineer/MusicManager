@tool
class_name MusicManagerPlugin
extends EditorPlugin


func _enter_tree():
	add_autoload_singleton("MusicManager", "music_manager.tscn")


func _exit_tree():
	remove_autoload_singleton("MusicManager")
