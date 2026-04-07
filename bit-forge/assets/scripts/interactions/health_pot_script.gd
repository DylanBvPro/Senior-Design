extends Area3D

@export var heal_amount: float = 5.0
@export var spin_speed_radians: float = 0.8
@export var bob_speed: float = 1.8
@export var bob_height: float = 0.06

var _base_position: Vector3
var _time_accumulator: float = 0.0
var _picked_up: bool = false
var _pickup_shape_owner_id: int = -1

@onready var _pickup_collision_shape: CollisionShape3D = $CollisionShape3D2


func _ready() -> void:
	_base_position = global_position
	_pickup_shape_owner_id = _find_shape_owner_for_node(_pickup_collision_shape)
	if not body_shape_entered.is_connected(_on_body_shape_entered):
		body_shape_entered.connect(_on_body_shape_entered)


func _physics_process(delta: float) -> void:
	if _picked_up:
		return

	_time_accumulator += delta
	rotate_y(spin_speed_radians * delta)

	var bob_offset := sin(_time_accumulator * bob_speed) * bob_height
	global_position = _base_position + Vector3(0.0, bob_offset, 0.0)


func _find_shape_owner_for_node(target_shape: CollisionShape3D) -> int:
	for owner_id in get_shape_owners():
		if shape_owner_get_owner(owner_id) == target_shape:
			return owner_id
	return -1


func _on_body_shape_entered(_body_rid: RID, body: Node, _body_shape_index: int, local_shape_index: int) -> void:
	if _picked_up:
		return
	if _pickup_shape_owner_id != -1:
		var local_owner_id := shape_find_owner(local_shape_index)
		if local_owner_id != _pickup_shape_owner_id:
			return
	if body == null or not is_instance_valid(body):
		return
	if not body.has_method("heal"):
		return

	_picked_up = true
	body.call("heal", heal_amount)
	queue_free()
