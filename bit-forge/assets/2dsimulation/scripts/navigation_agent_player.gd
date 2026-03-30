extends CharacterBody2D

@export var speed: float = 160.0
@export var demo_scene_to_reload: PackedScene = preload("res://assets/2dsimulation/sceanes/demo_test_sceanes.tscn")
@export var navigation_refresh_interval := 0.5
@export var waypoint_reach_distance := 10.0
@export var max_link_distance := 220.0
@export var point_merge_distance := 8.0
@export var avoid_enemy_radius := 180.0
@export var avoid_enemy_strength := 600.0
@export var emergency_enemy_distance := 45.0

@onready var camera: Camera2D = $Camera2D

var is_reloading_scene := false
var astar := AStar2D.new()
var path: PackedVector2Array = PackedVector2Array()
var current_path_index := 0
var refresh_timer := 0.0

func _ready():
	camera.enabled = true
	if !is_in_group("player"):
		add_to_group("player")

	call_deferred("refresh_navigation")

func _physics_process(delta):
	if is_reloading_scene:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	refresh_timer -= delta
	if refresh_timer <= 0.0:
		refresh_navigation()
		refresh_timer = navigation_refresh_interval

	if path.is_empty() or current_path_index >= path.size():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var target = path[current_path_index]
	var to_target = target - global_position

	if to_target.length() <= waypoint_reach_distance:
		current_path_index += 1
		if current_path_index >= path.size():
			velocity = Vector2.ZERO
			move_and_slide()
			return
		target = path[current_path_index]
		to_target = target - global_position

	var move_direction = to_target.normalized() if to_target.length() > 0.0 else Vector2.ZERO
	var avoidance = get_enemy_avoidance_vector()
	var final_direction = (move_direction + avoidance).normalized()

	if is_enemy_too_close():
		final_direction = avoidance.normalized() if avoidance != Vector2.ZERO else final_direction

	velocity = final_direction * speed
	move_and_slide()


func refresh_navigation():
	setup_exit_triggers()

	var exit_position = find_exit_position()
	if exit_position == null:
		path = PackedVector2Array()
		current_path_index = 0
		return

	build_astar_graph(exit_position)
	calculate_path(exit_position)


func find_exit_position() -> Variant:
	var root = get_tree().current_scene
	if root == null:
		root = get_tree().root

	for node in root.find_children("*", "StaticBody2D", true, false):
		if !node.name.begins_with("Exit"):
			continue

		return get_node_position(node)

	return null


func build_astar_graph(exit_position: Vector2):
	astar.clear()

	var points: Array[Vector2] = []
	try_add_point(points, global_position)
	try_add_point(points, exit_position)

	var root = get_tree().current_scene
	if root == null:
		root = get_tree().root

	for node in root.find_children("*", "StaticBody2D", true, false):
		if node.name.begins_with("Door") or node.name.begins_with("Exit"):
			try_add_point(points, get_node_position(node))

	for tile_map in root.find_children("*", "TileMap", true, false):
		if !(tile_map is TileMap):
			continue
		var used_rect: Rect2i = tile_map.get_used_rect()
		if used_rect.size == Vector2i.ZERO:
			continue
		var tile_size = Vector2i(16, 16)
		if tile_map.tile_set:
			tile_size = tile_map.tile_set.tile_size
		var local_center = Vector2((used_rect.position + used_rect.size / 2) * tile_size)
		try_add_point(points, tile_map.to_global(local_center))

	for i in range(points.size()):
		astar.add_point(i, points[i])

	for i in range(points.size()):
		for j in range(i + 1, points.size()):
			if points[i].distance_to(points[j]) > max_link_distance:
				continue
			if !is_segment_walkable(points[i], points[j]):
				continue
			astar.connect_points(i, j)


func calculate_path(exit_position: Vector2):
	if astar.get_point_count() < 2:
		path = PackedVector2Array([exit_position])
		current_path_index = 0
		return

	var start_id = astar.get_closest_point(global_position)
	var end_id = astar.get_closest_point(exit_position)
	if start_id == -1 or end_id == -1:
		path = PackedVector2Array([exit_position])
		current_path_index = 0
		return

	var new_path = astar.get_point_path(start_id, end_id)
	if new_path.is_empty():
		path = PackedVector2Array([exit_position])
		current_path_index = 0
		return

	path = new_path
	current_path_index = 0


func try_add_point(points: Array[Vector2], position: Vector2):
	for p in points:
		if p.distance_to(position) <= point_merge_distance:
			return
	points.append(position)


func is_segment_walkable(from_pos: Vector2, to_pos: Vector2) -> bool:
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.exclude = [self]
	var hit = space.intersect_ray(query)
	if hit.is_empty():
		return true

	var collider = hit.get("collider")
	if collider == null:
		return false

	if collider is StaticBody2D:
		if collider.name.begins_with("Door") or collider.name.begins_with("Exit"):
			return true

	return false


func get_node_position(node: Node) -> Vector2:
	var shape = find_collision_shape(node)
	if shape != null:
		return shape.global_position
	if node is Node2D:
		return (node as Node2D).global_position
	return global_position


func get_enemy_avoidance_vector() -> Vector2:
	var avoidance := Vector2.ZERO
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if !(enemy is Node2D):
			continue
		var offset = global_position - (enemy as Node2D).global_position
		var distance = offset.length()
		if distance <= 0.0 or distance > avoid_enemy_radius:
			continue
		var weight = (avoid_enemy_radius - distance) / avoid_enemy_radius
		avoidance += offset.normalized() * (avoid_enemy_strength * weight)

	return avoidance


func is_enemy_too_close() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if !(enemy is Node2D):
			continue
		if global_position.distance_to((enemy as Node2D).global_position) <= emergency_enemy_distance:
			return true

	return false


func setup_exit_triggers():
	var root = get_tree().current_scene
	if root == null:
		root = get_tree().root

	for node in root.find_children("*", "StaticBody2D", true, false):
		if !node.name.begins_with("Exit"):
			continue

		if node.get_node_or_null("PlayerExitTrigger") != null:
			continue

		var source_shape = find_collision_shape(node)
		if source_shape == null or source_shape.shape == null:
			continue

		var trigger = Area2D.new()
		trigger.name = "PlayerExitTrigger"
		trigger.collision_layer = 0
		trigger.collision_mask = 0x7fffffff
		trigger.monitoring = true
		trigger.monitorable = false

		var trigger_shape = CollisionShape2D.new()
		trigger_shape.shape = source_shape.shape.duplicate(true)
		trigger_shape.transform = source_shape.transform

		trigger.add_child(trigger_shape)
		node.add_child(trigger)
		trigger.body_entered.connect(_on_exit_trigger_body_entered)


func find_collision_shape(node: Node) -> CollisionShape2D:
	for child in node.get_children():
		if child is CollisionShape2D:
			return child
	return null


func _on_exit_trigger_body_entered(body: Node):
	if body != self:
		return

	if is_reloading_scene:
		return

	is_reloading_scene = true
	call_deferred("reload_demo_scene")


func reload_demo_scene():
	if demo_scene_to_reload != null:
		get_tree().change_scene_to_packed(demo_scene_to_reload)
		return

	get_tree().reload_current_scene()
