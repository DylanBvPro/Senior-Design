extends Area3D

@export var scene_to_load: PackedScene = preload("res://starting_room.tscn")

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if scene_to_load:
			get_tree().change_scene_to_packed(scene_to_load)
		else:
			push_error("No scene assigned to load!")
