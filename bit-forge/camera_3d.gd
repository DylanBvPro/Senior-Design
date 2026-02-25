extends Camera3D

@export var rotation_speed: float = 0.05
@export var rotation_range_degrees: float = 80.0

var start_rotation := 0.0

func _ready():
	start_rotation = rotation.y

func _process(delta):
	var angle = sin(Time.get_ticks_msec() * 0.001 * rotation_speed)
	var half_range = deg_to_rad(rotation_range_degrees / 2.0)
	rotation.y = start_rotation + angle * half_range
