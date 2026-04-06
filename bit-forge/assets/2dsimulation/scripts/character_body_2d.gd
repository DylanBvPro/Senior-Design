extends CharacterBody2D

@export var speed := 180.0
@export var exit_node_name := "Exit"
@export var exit_reach_distance := 12.0
@export var navigation_agent_path: NodePath = NodePath("NavigationAgent2D")
@export var enable_follow_camera := true

@onready var follow_camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
@onready var nav_agent: NavigationAgent2D = get_node_or_null(navigation_agent_path) as NavigationAgent2D

var goal_exit: Node2D = null
var is_reloading_scene := false
var last_navigation_target := Vector2.INF


func _ready() -> void:
	if !is_in_group("player"):
		add_to_group("player")
	setup_follow_camera()
	setup_navigation_agent()
	goal_exit = find_exit_node()
	update_navigation_target()


func _physics_process(_delta: float) -> void:

	if is_reloading_scene:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if goal_exit == null or !is_instance_valid(goal_exit):
		goal_exit = find_exit_node()
		update_navigation_target()

	if goal_exit == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var exit_position = get_node_position(goal_exit)
	if global_position.distance_to(exit_position) <= exit_reach_distance:
		is_reloading_scene = true
		call_deferred("reload_level")
		return

	update_navigation_target()

	var move_direction = Vector2.ZERO
	if nav_agent != null and !nav_agent.is_navigation_finished():
		var next_path_point = nav_agent.get_next_path_position()
		move_direction = (next_path_point - global_position).normalized()
	else:
		move_direction = (exit_position - global_position).normalized()

	if move_direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	velocity = move_direction * speed
	move_and_slide()


func _on_timer_timeout() -> void:
	goal_exit = find_exit_node()
	update_navigation_target()


func setup_navigation_agent() -> void:
	if nav_agent == null:
		nav_agent = NavigationAgent2D.new()
		nav_agent.name = "NavigationAgent2D"
		add_child(nav_agent)

	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = exit_reach_distance
	nav_agent.avoidance_enabled = false


func update_navigation_target() -> void:
	if nav_agent == null or goal_exit == null:
		return

	var target = get_node_position(goal_exit)
	if target == last_navigation_target:
		return

	nav_agent.target_position = target
	last_navigation_target = target


func get_node_position(node: Node) -> Vector2:
	if node is Node2D:
		return (node as Node2D).global_position
	return global_position


func find_exit_node() -> Node2D:
	var root = get_tree().current_scene
	if root == null:
		root = get_tree().root

	for node in root.find_children("*", "Node2D", true, false):
		if node.name == exit_node_name:
			return node as Node2D

	for node in root.find_children("*", "Node2D", true, false):
		if node.name.begins_with("Exit"):
			return node as Node2D

	return null


func reload_level() -> void:
	if !is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	tree.reload_current_scene()


func setup_follow_camera() -> void:
	if !enable_follow_camera:
		return

	# Only use a preconfigured child camera to avoid overriding scene camera setup.
	if follow_camera == null:
		return

	follow_camera.enabled = true
	follow_camera.make_current()
