extends Button

@export_file("*.tscn") var fallback_scene_path: String = "res://graveyard.tscn"


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var target_scene_path := fallback_scene_path
	if has_node("/root/Messenger"):
		target_scene_path = Messenger.call("get_last_scene_before_death", fallback_scene_path)

	if target_scene_path == "":
		return

	await _play_loading_transition()
	get_tree().change_scene_to_file(target_scene_path)


func _play_loading_transition() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("play_scene_loading_transition"):
		await player.call("play_scene_loading_transition")
		return

	# Fallback in scenes without the player loading UI.
	await get_tree().create_timer(1.0).timeout
