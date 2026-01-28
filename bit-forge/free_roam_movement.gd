extends Node3D
class_name FreeRoamMovement

@export var roam_radius: float = 6.0
@export var move_speed: float = 2.0
@export var stop_chance: float = 0.25
@export var min_stop_time: float = 0.8
@export var max_stop_time: float = 2.5
@export var obstacle_avoid_distance: float = 1.2

var start_position: Vector3
var target_position: Vector3
var is_stopped: bool = false

var _stop_timer: float = 0.0

signal stopped
signal started_moving

@onready var owner_body: CharacterBody3D = get_parent()

func _ready() -> void:
	start_position = owner_body.global_position
	_pick_new_target()

func update_roaming(delta: float) -> Vector3:
	# Called every frame by the main enemy script
	if is_stopped:
		_stop_timer -= delta
		if _stop_timer <= 0.0:
			is_stopped = false
			_pick_new_target()
		return update_roaming(delta)

	var direction = target_position - owner_body.global_position
	direction.y = 0.0

	if direction.length() < 0.4:
		_decide_stop_or_move()
		return Vector3.ZERO

	direction = direction.normalized()

	if _is_path_blocked(direction):
		_pick_new_target()
		return Vector3.ZERO

	return direction * move_speed

# --------------------
# Internal Logic
# --------------------

func _decide_stop_or_move() -> void:
	if randf() < stop_chance:
		is_stopped = true
		_stop_timer = randf_range(min_stop_time, max_stop_time)
		emit_signal("stopped")
	else:
		_pick_new_target()
		emit_signal("started_moving")

func _pick_new_target() -> void:
	var offset = Vector3(
		randf_range(-roam_radius, roam_radius),
		0.0,
		randf_range(-roam_radius, roam_radius)
	)

	target_position = start_position + offset

func _is_path_blocked(direction: Vector3) -> bool:
	var space_state = owner_body.get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.create(
		owner_body.global_position,
		owner_body.global_position + direction * obstacle_avoid_distance
	)

	# Ignore self
	query.exclude = [owner_body]

	var result = space_state.intersect_ray(query)

	if result.is_empty():
		return false

	var collider = result.collider

	# DO NOT avoid players or other enemies
	if collider.is_in_group("Player"):
		return false
	if collider.is_in_group("Enemies"):
		return false

	return true
