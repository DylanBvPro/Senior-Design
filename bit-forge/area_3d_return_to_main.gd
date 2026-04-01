extends Area3D

@export_file("*.tscn") var scene_path: String = "res://assets/sceanes/demo_floor_1.tscn"
@export var scene_to_load: PackedScene
var _is_loading_scene: bool = false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _is_loading_scene:
		return
	if body.is_in_group("player"):
		_is_loading_scene = true

		# Prefer explicit file path load; fall back to packed scene if provided.
		if scene_path != "":
			get_tree().call_deferred("change_scene_to_file", scene_path)
			return

		if scene_to_load != null:
			if scene_to_load.resource_path != "":
				get_tree().call_deferred("change_scene_to_file", scene_to_load.resource_path)
			else:
				get_tree().call_deferred("change_scene_to_packed", scene_to_load)
			return

		push_error("No valid scene configured to load.")
		_is_loading_scene = false
