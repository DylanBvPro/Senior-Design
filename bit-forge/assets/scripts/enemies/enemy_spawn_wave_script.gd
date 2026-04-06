extends Node3D

signal enemy_spawned(enemy: Node, enemy_name: String)

const ENEMY_SPAWN_SCRIPT_NAME := "enemy_spawn_script.gd"

## Whether to spawn the enemy on ready.
## Kept for inspector compatibility, but spawning is activate-only.
@export var spawn_on_ready: bool = false


## Activates enemy spawn scripts below this node and returns the first spawned enemy.
func spawn_enemy() -> Node:
	var spawned_enemies := _activate_spawn_scripts()
	if spawned_enemies.is_empty():
		return null
	return spawned_enemies[0]


## Activation method for control_3d_script and similar triggers
func activate() -> void:
	_activated_spawn_scripts_report()


func _activated_spawn_scripts_report() -> void:
	var spawned_enemies := _activate_spawn_scripts()
	if spawned_enemies.is_empty():
		push_warning("enemy_spawn_wave_script: No enemy_spawn_script nodes found below this node.")


func _activate_spawn_scripts() -> Array[Node]:
	var spawned_enemies: Array[Node] = []
	for spawn_node in _find_descendant_spawn_scripts(self):
		var spawned_enemy := _activate_single_spawn_script(spawn_node)
		if spawned_enemy == null:
			continue

		var enemy_name := _get_enemy_name(spawned_enemy)
		print("Wave spawned: %s from %s" % [enemy_name, spawn_node.name])
		enemy_spawned.emit(spawned_enemy, enemy_name)
		spawned_enemies.append(spawned_enemy)

	return spawned_enemies


func _find_descendant_spawn_scripts(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in root.get_children():
		if _is_enemy_spawn_script_node(child):
			result.append(child)

		result.append_array(_find_descendant_spawn_scripts(child))

	return result


func _is_enemy_spawn_script_node(node: Node) -> bool:
	if node == null or node == self:
		return false

	var attached_script: Script = node.get_script() as Script
	if attached_script != null and String(attached_script.resource_path).ends_with(ENEMY_SPAWN_SCRIPT_NAME):
		return true

	return node.has_method("spawn_enemy")


func _activate_single_spawn_script(spawn_node: Node) -> Node:
	if spawn_node.has_method("spawn_enemy"):
		var result = spawn_node.call("spawn_enemy")
		if result is Node:
			return result

	if spawn_node.has_method("activate"):
		spawn_node.call("activate")

	return null


func _get_enemy_name(enemy: Node) -> String:
	if enemy == null:
		return "Unknown"

	if enemy.scene_file_path != "":
		return enemy.scene_file_path.get_file()

	return enemy.name
