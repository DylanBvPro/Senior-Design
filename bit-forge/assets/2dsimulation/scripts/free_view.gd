extends Camera2D

@export var speed : float = 400.0

func _process(delta):

	var direction = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	if direction != Vector2.ZERO:
		direction = direction.normalized()

	position += direction * speed * delta
