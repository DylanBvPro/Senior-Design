extends Camera3D

@export var rotation_speed: float = 0.05
@export var rotation_range_degrees: float = 80.0
@export var capture_mouse_on_ready: bool = true
@export var mouse_sensitivity: float = 0.003
@export var max_pitch_degrees: float = 70.0

var start_rotation := 0.0
var mouse_yaw_offset: float = 0.0
var mouse_pitch: float = 0.0

func _ready():
	start_rotation = rotation.y
	if capture_mouse_on_ready:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_yaw_offset -= event.relative.x * mouse_sensitivity
		mouse_pitch -= event.relative.y * mouse_sensitivity
		mouse_pitch = clampf(mouse_pitch, deg_to_rad(-max_pitch_degrees), deg_to_rad(max_pitch_degrees))

func _process(_delta):
	var angle = sin(Time.get_ticks_msec() * 0.001 * rotation_speed)
	var half_range = deg_to_rad(rotation_range_degrees / 2.0)
	rotation.y = start_rotation + angle * half_range + mouse_yaw_offset
	rotation.x = mouse_pitch
