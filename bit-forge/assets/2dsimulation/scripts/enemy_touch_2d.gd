extends CharacterBody2D

@export var speed: float = 90.0
@export var touch_distance: float = 14.0
@export var aggro_range: float = 220.0
@export var lose_range: float = 320.0
@export var demo_scene_to_reload: PackedScene = preload("res://assets/2dsimulation/sceanes/demo_test_sceanes.tscn")

var is_reloading_scene := false
var is_chasing := false


func _ready():
	if !is_in_group("enemies"):
		add_to_group("enemies")


func _physics_process(_delta):
	if is_reloading_scene:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var player = get_tree().get_first_node_in_group("player")
	if !(player is Node2D):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player = (player as Node2D).global_position - global_position
	var distance = to_player.length()

	if !is_chasing:
		if distance > aggro_range:
			velocity = Vector2.ZERO
			move_and_slide()
			return
		is_chasing = true
	elif distance > lose_range:
		is_chasing = false
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if distance <= touch_distance:
		is_reloading_scene = true
		velocity = Vector2.ZERO
		move_and_slide()
		call_deferred("reload_demo_scene")
		return

	var direction = to_player.normalized() if distance > 0.0 else Vector2.ZERO
	velocity = direction * speed
	move_and_slide()


func reload_demo_scene():
	if demo_scene_to_reload != null:
		get_tree().change_scene_to_packed(demo_scene_to_reload)
		return

	get_tree().reload_current_scene()
