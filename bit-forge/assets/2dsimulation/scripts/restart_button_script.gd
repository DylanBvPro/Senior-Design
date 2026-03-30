extends Button

@export var demo_scene_to_reload: PackedScene = preload("res://assets/2dsimulation/sceanes/demo_test_sceanes.tscn")


func _pressed() -> void:
	var tree = get_tree()
	if tree == null:
		return

	if demo_scene_to_reload != null and demo_scene_to_reload.can_instantiate():
		tree.change_scene_to_packed(demo_scene_to_reload)
		return

	tree.reload_current_scene()
