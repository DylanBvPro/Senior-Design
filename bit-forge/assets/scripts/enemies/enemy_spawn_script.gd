extends Node3D

signal enemy_spawned(enemy: Node, enemy_name: String)

## The enemy scene to spawn
@export var enemy_scene: PackedScene

## Whether to spawn the enemy on ready
@export var spawn_on_ready: bool = true

## Parent node to add the spawned enemy to (defaults to parent of this node)
@export var spawn_parent: Node3D


func _ready() -> void:
	if spawn_on_ready:
		spawn_enemy()


## Spawns an enemy at this node's position
func spawn_enemy() -> Node:
	if not enemy_scene:
		push_error("enemy_spawn_script: No enemy_scene assigned!")
		return null
	
	var enemy = enemy_scene.instantiate()
	var enemy_name: String = enemy_scene.resource_path.get_file()
	
	# Get parent to add enemy to
	var parent = spawn_parent if spawn_parent else get_parent()
	if not parent:
		parent = get_tree().root
	
	parent.add_child(enemy)
	enemy.global_position = global_position
	enemy.global_rotation = global_rotation
	
	print("Enemy spawned: %s at position %s" % [enemy_name, global_position])
	enemy_spawned.emit(enemy, enemy_name)
	
	return enemy


## Activation method for control_3d_script and similar triggers
func activate() -> void:
	spawn_enemy()
