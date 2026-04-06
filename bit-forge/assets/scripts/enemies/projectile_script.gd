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
var _exclude_rids: Array[RID] = []
var intended_target: Node = null


func _ready() -> void:
	set_physics_process(false)


func launch(launch_direction: Vector3, projectile_damage: float, projectile_source: Node = null, override_speed: float = -1.0, override_max_distance: float = -1.0) -> void:
	direction = launch_direction
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
	_exclude_rids = _collect_exclude_rids(source)
	intended_target = _resolve_damage_target(get_meta("intended_target", null) as Node)
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
	query.exclude = _exclude_rids
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit["collider"]
		var hit_position: Vector3 = hit["position"]
		if collider != null and collider is Node:
			var hit_node := _resolve_damage_target(collider as Node)
			if _should_ignore_hit_target(hit_node):
				if hit.has("rid") and hit["rid"] is RID:
					_exclude_rids.append(hit["rid"] as RID)
				# Nudge forward so we don't repeatedly re-hit the same collider.
				global_position = hit_position + direction * 0.02
				return
			if hit_node != null:
				global_position = hit_position
				_apply_damage_to_target(hit_node)
			else:
				global_position = hit_position
		else:
			global_position = hit_position
		queue_free()
		return

	global_position = to_pos
	distance_traveled += travel.length()
	if distance_traveled >= max_distance:
		queue_free()


func _resolve_damage_target(node: Node) -> Node:
	var current := node
	while current != null:
		if current.has_method("take_damage") or current.has_method("apply_damage"):
			return current
		current = current.get_parent()
	return null


func _apply_damage_to_target(target: Node) -> void:
	if source != null and target == source:
		return

	if source != null and source.is_in_group("player"):
		if target.is_in_group("player"):
			return
		if target.has_method("take_damage"):
			target.call("take_damage", damage, source)
		elif target.has_method("apply_damage"):
			target.call("apply_damage", damage, source)

		if source.has_method("_on_projectile_hit_target"):
			var source_weapon_type: Variant = get_meta("source_weapon_type", -1)
			source.call("_on_projectile_hit_target", target, int(source_weapon_type))
		return

	if target.is_in_group("player"):
		if target.has_method("take_damage"):
			target.call("take_damage", damage, source)
		elif target.has_method("apply_damage"):
			target.call("apply_damage", damage, source)


func _should_ignore_hit_target(hit_node: Node) -> bool:
	if source == null or not source.is_in_group("player"):
		return false
	if intended_target == null:
		return false
	if hit_node == null:
		return false
	if hit_node == intended_target:
		return false

	# Keep world/geometry collisions blocking shots, only ignore wrong damageable targets.
	return hit_node.has_method("take_damage") or hit_node.has_method("apply_damage")


func _collect_exclude_rids(root: Node) -> Array[RID]:
	var rids: Array[RID] = []
	if root == null:
		return rids

	_collect_collision_rids_recursive(root, rids)
	return rids


func _collect_collision_rids_recursive(node: Node, rids: Array[RID]) -> void:
	if node is CollisionObject3D:
		rids.append((node as CollisionObject3D).get_rid())

	for child in node.get_children():
		_collect_collision_rids_recursive(child, rids)
