extends RigidBody3D

@export var open_angle_degrees: float = 160.0
@export var open_duration_seconds: float = 1.0
@export var open_axis: Vector3 = Vector3.UP

var _is_open: bool = false
var _is_animating: bool = false
var _closed_basis: Basis
var _open_basis: Basis


func _ready() -> void:
	# Door movement is animation-driven; freeze physics response while tweening transforms.
	freeze = true
	_closed_basis = basis
	var axis := open_axis
	if axis.length_squared() < 0.0001:
		axis = Vector3.UP
	_open_basis = _closed_basis * Basis(axis.normalized(), deg_to_rad(open_angle_degrees))


func activate() -> void:
	open()


func open() -> void:
	if _is_open or _is_animating:
		return

	_is_animating = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "basis", _open_basis, max(open_duration_seconds, 0.01))
	await tween.finished
	_is_animating = false
	_is_open = true
