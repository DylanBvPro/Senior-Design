extends CharacterBody2D

@export var speed : float = 200.0

func _physics_process(_delta):

	var direction = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	if direction != Vector2.ZERO:
		direction = direction.normalized()

	velocity = direction * speed

	move_and_slide()
