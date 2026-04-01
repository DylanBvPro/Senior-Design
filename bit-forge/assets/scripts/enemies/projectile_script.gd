class_name EnemyProjectile
extends Node3D

@export var speed: float = 12.0
@export var max_distance: float = 40.0
@export var collision_mask: int = 1

var direction: Vector3 = Vector3.ZERO
var damage: float = 0.0
var source: Node = null
var distance_traveled: float = 0.0
var launched: bool = false


func _ready() -> void:
	set_physics_process(false)


func launch(launch_direction: Vector3, projectile_damage: float, projectile_source: Node = null, override_speed: float = -1.0, override_max_distance: float = -1.0) -> void:
	direction = launch_direction
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = -global_basis.z
	direction = direction.normalized()

	damage = projectile_damage
	source = projectile_source
	if override_speed > 0.0:
		speed = override_speed
	if override_max_distance > 0.0:
		max_distance = override_max_distance

	distance_traveled = 0.0
	launched = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not launched:
		return

	var travel: Vector3 = direction * speed * delta
	var from_pos: Vector3 = global_position
	var to_pos: Vector3 = from_pos + travel

	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]
		var collider: Object = hit["collider"]
		if collider != null and collider is Node:
			var hit_node := collider as Node
			if hit_node.is_in_group("player") and hit_node.has_method("take_damage"):
				hit_node.call("take_damage", damage, source)
		queue_free()
		return

	global_position = to_pos
	distance_traveled += travel.length()
	if distance_traveled >= max_distance:
		queue_free()
