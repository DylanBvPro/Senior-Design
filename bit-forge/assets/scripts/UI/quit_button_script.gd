extends Button

@export_file("*.tscn") var main_menu_scene_path: String = "res://main_menu_background.tscn"


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if main_menu_scene_path == "":
		return

	await _play_loading_transition()
	if has_node("/root/Messenger"):
		Messenger.call("clear_last_scene_before_death")
	get_tree().change_scene_to_file(main_menu_scene_path)


func _play_loading_transition() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("play_scene_loading_transition"):
		await player.call("play_scene_loading_transition")
		return

	# Fallback in scenes without the player loading UI.
	await get_tree().create_timer(1.0).timeout
