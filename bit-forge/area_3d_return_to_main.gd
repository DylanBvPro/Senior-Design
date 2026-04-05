extends Area3D

@export_file("*.tscn") var target_scene_path: String = ""
@export var target_scene: PackedScene
@export var triggering_group: StringName = "player"
@export var one_shot: bool = true
var _is_loading_scene: bool = false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if one_shot and _is_loading_scene:
		return
	if triggering_group != StringName() and not body.is_in_group(triggering_group):
		return

	_is_loading_scene = true
	await _play_loading_transition(body)

	# Prefer explicit file path; fall back to packed scene if provided.
	if target_scene_path != "":
		get_tree().call_deferred("change_scene_to_file", target_scene_path)
		return

	if target_scene != null:
		if target_scene.resource_path != "":
			get_tree().call_deferred("change_scene_to_file", target_scene.resource_path)
		else:
			get_tree().call_deferred("change_scene_to_packed", target_scene)
		return

	push_error("No valid target scene configured.")
	_is_loading_scene = false


func _play_loading_transition(body: Node) -> void:
	if body != null and body.has_method("play_scene_loading_transition"):
		await body.call("play_scene_loading_transition")
		return

	if triggering_group != StringName():
		var grouped_player := get_tree().get_first_node_in_group(triggering_group)
		if grouped_player != null and grouped_player.has_method("play_scene_loading_transition"):
			await grouped_player.call("play_scene_loading_transition")
			return

	# Fallback: tiny delay so transition does not hard-cut even if player script is missing.
	await get_tree().create_timer(0.1).timeout
