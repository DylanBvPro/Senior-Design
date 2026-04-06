extends Node

signal SHOW_INTERACT_MESSAGE(message:String)
signal CLEAR_INTERACT_MESSAGE

var last_scene_before_death_path: String = ""


func set_last_scene_before_death(path: String) -> void:
	if path == "":
		return
	last_scene_before_death_path = path


func get_last_scene_before_death(default_path: String = "") -> String:
	if last_scene_before_death_path != "":
		return last_scene_before_death_path
	return default_path


func clear_last_scene_before_death() -> void:
	last_scene_before_death_path = ""
