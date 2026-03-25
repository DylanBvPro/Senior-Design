extends Node2D

@export var rooms_folder := "res://assets/2dsimulation/sceanes/random_rooms/"
@export var start_rooms_folder := "res://assets/2dsimulation/sceanes/start_room/"
@export var end_rooms_folder := "res://assets/2dsimulation/sceanes/end_room/"
@export var deadend_rooms_folder := "res://assets/2dsimulation/sceanes/deadend_rooms/"
@export var player_scene: PackedScene = preload("res://assets/2dsimulation/characters/player_placeholder.tscn")
@export var demo_scene_to_reload: PackedScene = preload("res://assets/2dsimulation/sceanes/demo_test_sceanes.tscn")
@export var max_rooms := 3
@export_range(1, 10, 1) var dungeon_complexity := 5
@export var debug_generation := true
@export var door_connection_gap := 16.0
@export var enforce_closed_paths := true
@export var max_room_repeats_in_a_row := 3
@export var generation_timeout_seconds := 10.0

var main_rooms_count := 0
var room_scenes : Array = []
var terminal_room_scenes : Array = []
var connector_room_scenes : Array = []
var start_room_scenes : Array = []
var end_room_scenes : Array = []
var deadend_room_scenes : Array = []
var placed_rooms : Array = []
var open_connections : Array = []
var beginning_room: Node2D = null
var ending_room: Node2D = null
var dead_end_rooms: Array = []
var last_scene_key = ""
var consecutive_scene_count := 0
var generation_deadline_ms: int = 0
var generation_timed_out := false
var random_rooms_placed_count := 0
var is_regenerating_layout := false
var spawned_player: Node = null

func _ready():
	load_rooms()
	generate_dungeon()


func load_rooms():
	room_scenes.clear()
	terminal_room_scenes.clear()
	connector_room_scenes.clear()
	start_room_scenes.clear()
	end_room_scenes.clear()
	deadend_room_scenes.clear()

	var dir = DirAccess.open(rooms_folder)
	if dir == null:
		push_error("Room folder not found")
		return

	dir.list_dir_begin()

	var file = dir.get_next()
	while file != "":
		if file.ends_with(".tscn"):
			var scene = load(rooms_folder + file)
			room_scenes.append(scene)

			var door_count = count_scene_doors(scene)
			if door_count == 1:
				terminal_room_scenes.append(scene)
			elif door_count > 1:
				connector_room_scenes.append(scene)
		file = dir.get_next()

	dir.list_dir_end()

	start_room_scenes = load_scenes_from_folder(start_rooms_folder)
	end_room_scenes = load_scenes_from_folder(end_rooms_folder)
	deadend_room_scenes = load_scenes_from_folder(deadend_rooms_folder)

	if start_room_scenes.is_empty():
		push_error("Start room folder has no scenes: " + start_rooms_folder)

	if end_room_scenes.is_empty():
		push_error("End room folder has no scenes: " + end_rooms_folder)

	if deadend_room_scenes.is_empty():
		push_error("Dead-end room folder has no scenes: " + deadend_rooms_folder)


func load_scenes_from_folder(folder_path: String) -> Array:
	var scenes: Array = []
	var dir = DirAccess.open(folder_path)
	if dir == null:
		push_error("Room folder not found: " + folder_path)
		return scenes

	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".tscn"):
			var scene = load(folder_path + file)
			scenes.append(scene)
		file = dir.get_next()
	dir.list_dir_end()

	return scenes


func generate_dungeon():
	generate_dungeon_dynamic(max_rooms)


func generate_dungeon_dynamic(total_rooms: int, complexity_override: int = -1):
	var complexity = dungeon_complexity
	if complexity_override > 0:
		complexity = complexity_override
	complexity = clampi(complexity, 1, 10)

	if room_scenes.is_empty():
		return

	if start_room_scenes.is_empty():
		push_error("Need at least one start room scene.")
		return

	if end_room_scenes.is_empty():
		push_error("Need at least one end room scene.")
		return

	if deadend_room_scenes.is_empty():
		push_error("Need at least one dead-end room scene.")
		return

	if total_rooms <= 0:
		debug_log("Skipped generation: total_rooms <= 0")
		return

	var complexity_t = float(complexity - 1) / 9.0
	var target_fill = lerpf(0.35, 0.95, complexity_t)
	var min_required_rooms = maxi(2, int(round(total_rooms * target_fill)))
	var max_attempts = int(round(lerpf(2.0, 10.0, complexity_t)))

	debug_log(
		"Complexity=" + str(complexity)
		+ " target_min_rooms=" + str(min_required_rooms)
		+ " attempts=" + str(max_attempts)
	)

	var reached_target = false
	for attempt in range(max_attempts):
		clear_generated_rooms()
		generation_timed_out = false
		generation_deadline_ms = Time.get_ticks_msec() + int(generation_timeout_seconds * 1000.0)
		generate_layout_once(total_rooms, complexity)

		if generation_timed_out:
			clear_generated_rooms()
			if attempt < max_attempts - 1:
				debug_log("Generation timed out after " + str(generation_timeout_seconds) + "s. Restarting attempt.")
				continue
			else:
				debug_log("Generation timed out on final attempt.")
				break

		var has_required_terminals = has_required_terminal_rooms(total_rooms)
		var random_count = get_random_room_count()

		if has_required_terminals and random_count >= min_required_rooms:
			reached_target = true
			spawn_or_move_player_to_starting_room()
			setup_exit_triggers()
			debug_log("Reached complexity target on attempt " + str(attempt + 1))
			break

		if attempt < max_attempts - 1:
			if !has_required_terminals:
				debug_log("Retrying generation: missing required beginning/ending room.")
			else:
				debug_log("Retrying generation: placed " + str(random_count) + " random rooms.")

	if !reached_target:
		var random_count = get_random_room_count()
		debug_log(
			"Did not reach complexity target."
			+ " random_count=" + str(random_count)
			+ " placed_total=" + str(placed_rooms.size())
			+ " target=" + str(min_required_rooms)
		)

	generation_deadline_ms = 0


func setup_exit_triggers():
	var trigger_count := 0
	for room in placed_rooms:
		if !is_instance_valid(room):
			continue

		for node in room.find_children("*", "StaticBody2D", true, false):
			if !node.name.begins_with("Exit"):
				continue

			if node.get_node_or_null("RoomGenExitTrigger") != null:
				continue

			var source_shape = find_collision_shape(node)
			if source_shape == null or source_shape.shape == null:
				continue

			var trigger = Area2D.new()
			trigger.name = "RoomGenExitTrigger"
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
			trigger_count += 1

	debug_log("Registered exit triggers: " + str(trigger_count))


func spawn_or_move_player_to_starting_room():
	if beginning_room == null:
		return

	var spawn_position = beginning_room.global_position
	var room_rect = get_room_rect(beginning_room)
	if room_rect.size != Vector2.ZERO:
		spawn_position = room_rect.get_center()

	var player_body = get_tree().get_first_node_in_group("player")
	if player_body is Node2D:
		(player_body as Node2D).global_position = spawn_position
		spawned_player = player_body
		debug_log("Moved existing player to start room.")
		return

	if player_scene == null:
		debug_log("Player scene is not set; skipping spawn.")
		return

	var player_instance = player_scene.instantiate()
	add_child(player_instance)
	spawned_player = player_instance

	var player_node_2d: Node2D = null
	if player_instance is Node2D:
		player_node_2d = player_instance

	var player_body_node = find_character_body(player_instance)
	if player_body_node != null:
		if !player_body_node.is_in_group("player"):
			player_body_node.add_to_group("player")
		if player_body_node is Node2D:
			(player_body_node as Node2D).global_position = spawn_position
			player_node_2d = player_body_node

	if player_node_2d != null:
		player_node_2d.global_position = spawn_position

	debug_log("Spawned player in starting room.")


func find_character_body(root: Node) -> CharacterBody2D:
	if root is CharacterBody2D:
		return root

	for child in root.find_children("*", "CharacterBody2D", true, false):
		if child is CharacterBody2D:
			return child

	return null


func find_collision_shape(node: Node) -> CollisionShape2D:
	for child in node.get_children():
		if child is CollisionShape2D:
			return child
	return null


func _on_exit_trigger_body_entered(body: Node):
	if body == null:
		return

	if !is_player_body(body):
		return

	if is_regenerating_layout:
		return

	is_regenerating_layout = true
	debug_log("Player reached Exit. Regenerating layout.")
	call_deferred("_regenerate_layout_from_exit")


func _regenerate_layout_from_exit():
	if demo_scene_to_reload != null:
		get_tree().change_scene_to_packed(demo_scene_to_reload)
		return

	debug_log("Demo scene is not set; falling back to in-place regeneration.")
	clear_generated_rooms()
	generate_dungeon()
	is_regenerating_layout = false


func is_player_body(body: Node) -> bool:
	return body.is_in_group("player") or body.is_in_group("Player")


func has_required_terminal_rooms(total_rooms: int) -> bool:
	if beginning_room == null:
		return false

	if total_rooms > 1 and ending_room == null:
		return false

	return true


func get_counted_room_count() -> int:
	return maxi(placed_rooms.size() - dead_end_rooms.size(), 0)


func get_random_room_count() -> int:
	return random_rooms_placed_count


func generate_layout_once(total_rooms: int, complexity: int):
	if has_generation_timed_out():
		return

	main_rooms_count = 1
	# Place beginning room (must be 1-door)
	var first_room_scene = start_room_scenes.pick_random()
	var first_room = first_room_scene.instantiate()
	add_child(first_room)
	placed_rooms.append(first_room)
	beginning_room = first_room
	register_placed_scene(first_room_scene)
	debug_log("Placed first room: " + get_scene_label(first_room_scene))

	open_connections += get_connections(first_room)
	debug_log("First room doors found: " + str(open_connections.size()))

	var wants_ending = total_rooms > 1
	var complexity_t = float(complexity - 1) / 9.0
	var remaining_slots = maxi(total_rooms, 0)
	var max_dead_ends = maxi(remaining_slots, 0)
	var dead_end_ratio = lerpf(0.45, 0.10, complexity_t)
	var dead_end_target = clampi(int(round(remaining_slots * dead_end_ratio)), 0, max_dead_ends)
	var connector_target = remaining_slots

	debug_log(
		"Targets | connectors=" + str(connector_target)
		+ " dead_ends=" + str(dead_end_target)
		+ " ending=" + str(wants_ending)
	)

	# Generate middle connector rooms (2+ doors preferred)
	while get_random_room_count() < connector_target:
		if has_generation_timed_out():
			return

		var connector_pool = connector_room_scenes
		if connector_pool.is_empty():
			connector_pool = room_scenes

		var placement_result = try_place_room(connector_pool)
		if placement_result["placed"]:
			debug_log(
				"Placed connector room at step " + str(get_random_room_count())
				+ ": " + placement_result["scene_label"]
			)
			main_rooms_count += 1
		else:
			break

	# Generate branch dead-ends (1-door, not start/end)
	for i in range(dead_end_target):
		if has_generation_timed_out():
			return

		if wants_ending and ending_room == null and open_connections.size() <= 1:
			debug_log("Stopping dead-end placement to keep one open door for ending room.")
			break

		var dead_end_result = try_place_room(deadend_room_scenes, 1, false)
		if dead_end_result["placed"]:
			dead_end_rooms.append(dead_end_result["room"])
			debug_log(
				"Placed dead-end room #" + str(dead_end_rooms.size())
				+ ": " + dead_end_result["scene_label"]
			)
		else:
			debug_log("Failed dead-end placement at step " + str(i + 1) + ", trying end_room fallback.")
			var end_fallback_result = try_place_room(end_room_scenes, 1, false)
			if end_fallback_result["placed"]:
				if ending_room == null:
					ending_room = end_fallback_result["room"]
					debug_log("Placed ending room as dead-end fallback: " + end_fallback_result["scene_label"])
				else:
					dead_end_rooms.append(end_fallback_result["room"])
					debug_log(
						"Placed end_room as dead-end fallback #" + str(dead_end_rooms.size())
						+ ": " + end_fallback_result["scene_label"]
					)
			else:
				break

	# Place ending room (must be 1-door)
	if wants_ending:
		if has_generation_timed_out():
			return

		if open_connections.is_empty():
			debug_log("No open door available for ending room.")
			return

		if !has_potential_ending_match():
			debug_log("No obvious end_room side match found; attempting force placement anyway.")

		if !force_place_ending_room():
			debug_log("ERROR: Failed to force ending room placement.")
	if enforce_closed_paths:
		if has_generation_timed_out():
			return

		close_remaining_paths(wants_ending)

	debug_log(
		"Generation complete. Random rooms=" + str(get_random_room_count())
		+ " counted rooms=" + str(get_counted_room_count())
		+ " total placed=" + str(placed_rooms.size())
	)
	debug_log("Roles | beginning=1 ending=" + str(ending_room != null) + " dead_ends=" + str(dead_end_rooms.size()))


func debug_log(message):
	if debug_generation:
		print("[RoomGen] " + message)

func force_place_ending_room() -> bool:
	if ending_room != null:
		return true

	var safety := 0
	var stalled_iterations := 0
	var previous_open_count := open_connections.size()

	while safety < 200:
		if has_generation_timed_out():
			return false

		safety += 1

		# Try normal placement first
		if try_place_terminal_room(true):
			return true

		# If it fails, expand layout slightly with a connector
		var connector_pool = connector_room_scenes
		if connector_pool.is_empty():
			connector_pool = room_scenes

		var expanded = try_place_room(connector_pool)
		if !expanded["placed"]:
			break

		if open_connections.size() > previous_open_count:
			stalled_iterations += 1
		else:
			stalled_iterations = 0

		previous_open_count = open_connections.size()
		if stalled_iterations >= 12:
			break

	return false

func clear_generated_rooms():
	for room in placed_rooms:
		if is_instance_valid(room):
			room.queue_free()

	placed_rooms.clear()
	open_connections.clear()
	dead_end_rooms.clear()
	beginning_room = null
	ending_room = null
	last_scene_key = ""
	consecutive_scene_count = 0
	main_rooms_count = 0
	random_rooms_placed_count = 0


func count_scene_doors(scene):
	var room = scene.instantiate()
	var count = get_connections(room).size()
	room.free()
	return count


func try_place_room(scene_pool: Array, required_door_count: int = -1, keep_new_open_doors: bool = true) -> Dictionary:
	if has_generation_timed_out():
		return {"placed": false}

	if scene_pool.is_empty():
		return {"placed": false}

	if open_connections.is_empty():
		return {"placed": false}

	var shuffled_connections = open_connections.duplicate()
	shuffled_connections.shuffle()

	var shuffled_room_scenes = scene_pool.duplicate()
	shuffled_room_scenes.shuffle()

	for attach_point in shuffled_connections:
		if has_generation_timed_out():
			return {"placed": false}

		var attach_room = get_room_for_connection(attach_point)
		if attach_room == null:
			continue

		for room_scene in shuffled_room_scenes:
			if has_generation_timed_out():
				return {"placed": false}

			if room_scenes.has(room_scene) and get_random_room_count() >= max_rooms:
				continue

			if would_exceed_repeat_limit(room_scene):
				continue

			var new_room = room_scene.instantiate()
			add_child(new_room)

			var new_connections = get_connections(new_room)
			if required_door_count >= 0 and new_connections.size() != required_door_count:
				new_room.queue_free()
				continue

			if new_connections.is_empty():
				new_room.queue_free()
				continue

			var shuffled_new_connections = new_connections.duplicate()
			shuffled_new_connections.shuffle()

			for new_door in shuffled_new_connections:
				if has_generation_timed_out():
					new_room.queue_free()
					return {"placed": false}

				if !are_doors_compatible(attach_room, attach_point, new_room, new_door):
					continue

				var attach_side = get_door_side(attach_room, attach_point)
				var offset = get_connection_position(attach_point) - get_connection_position(new_door)
				offset += get_side_offset(attach_side) * door_connection_gap
				new_room.position += offset

				if is_room_area_free(new_room):
					placed_rooms.append(new_room)
					register_placed_scene(room_scene)
					if room_scenes.has(room_scene):
						random_rooms_placed_count += 1
					set_connection_passable(attach_point)
					set_connection_passable(new_door)
					open_connections.erase(attach_point)
					new_connections.erase(new_door)
					if keep_new_open_doors:
						open_connections += new_connections
					debug_log(
						"Placed room #" + str(placed_rooms.size())
						+ " [" + get_scene_label(room_scene) + "]"
						+ " using " + attach_point.name
						+ " -> " + new_door.name
						+ ", remaining open doors: " + str(open_connections.size())
					)
					return {
						"placed": true,
						"room": new_room,
						"scene_label": get_scene_label(room_scene),
						"attach_point": attach_point,
						"new_door": new_door
					}

				new_room.position -= offset

			new_room.queue_free()

	return {"placed": false}


func set_connection_passable(connection: Node):
	if connection == null:
		return

	if connection is CollisionObject2D:
		connection.collision_layer = 0
		connection.collision_mask = 0

	for shape in connection.find_children("*", "CollisionShape2D", true, false):
		if shape is CollisionShape2D:
			shape.disabled = true


func get_scene_key(scene) -> String:
	if scene == null:
		return ""

	if scene.resource_path != "":
		return scene.resource_path

	return str(scene.get_instance_id())


func get_scene_label(scene) -> String:
	if scene == null:
		return "unknown_scene"

	if scene.resource_path != "":
		return scene.resource_path.get_file().trim_suffix(".tscn")

	return "scene_" + str(scene.get_instance_id())


func would_exceed_repeat_limit(scene) -> bool:
	if max_room_repeats_in_a_row <= 0:
		return false

	var key = get_scene_key(scene)
	if key == "":
		return false

	return key == last_scene_key and consecutive_scene_count >= max_room_repeats_in_a_row


func register_placed_scene(scene):
	var key = get_scene_key(scene)
	if key == "":
		return

	if key == last_scene_key:
		consecutive_scene_count += 1
	else:
		last_scene_key = key
		consecutive_scene_count = 1


func try_place_terminal_room(mark_as_ending: bool = false) -> bool:
	var terminal_pool = end_room_scenes if mark_as_ending else deadend_room_scenes
	var result = try_place_room(terminal_pool, 1, mark_as_ending)
	if !result["placed"]:
		return false

	var room = result["room"]
	if mark_as_ending and ending_room == null:
		ending_room = room
		main_rooms_count += 1
		debug_log("Placed ending room: " + result["scene_label"])
	else:
		dead_end_rooms.append(room)
		debug_log(
			"Placed dead-end room #" + str(dead_end_rooms.size())
			+ ": " + result["scene_label"]
		)

	return true


func close_remaining_paths(wants_ending: bool):
	if wants_ending and ending_room == null:
		return

	if open_connections.is_empty():
		return

	var safety := 0
	var stalled_iterations := 0
	var previous_open_count := open_connections.size()

	while !open_connections.is_empty() and safety < 1000:
		if has_generation_timed_out():
			return

		safety += 1

		var needs_ending = wants_ending and ending_room == null
		var placed_any := false

		# Try to place proper terminal room first
		if try_place_terminal_room(needs_ending):
			placed_any = true

		# If that fails, FORCE a dead-end room
		if !placed_any:
			var dead_end_result = try_place_room(deadend_room_scenes, 1, false)
			if dead_end_result["placed"]:
				dead_end_rooms.append(dead_end_result["room"])
				debug_log(
					"Placed dead-end room #" + str(dead_end_rooms.size())
					+ ": " + dead_end_result["scene_label"]
				)
				placed_any = true

		# If even that fails, expand with a connector and try again
		if !placed_any:
			var connector_pool = connector_room_scenes
			if connector_pool.is_empty():
				connector_pool = room_scenes
			if try_place_room(connector_pool)["placed"]:
				placed_any = true

		var current_open_count = open_connections.size()
		if current_open_count < previous_open_count:
			stalled_iterations = 0
		else:
			stalled_iterations += 1

		previous_open_count = current_open_count

		if placed_any and stalled_iterations < 20:
			continue

		# Absolute fallback: remove the connection (fail-safe)
		var failed_connection = open_connections.pop_back()
		debug_log("Force-closing unreachable or stalled door: " + failed_connection.name)
		previous_open_count = open_connections.size()
		stalled_iterations = 0

	if !open_connections.is_empty():
		debug_log("WARNING: Some doors were force-closed.")


func has_potential_ending_match() -> bool:
	if open_connections.is_empty() or end_room_scenes.is_empty():
		return false

	for connection in open_connections:
		var room = get_room_for_connection(connection)
		if room == null:
			continue

		var attach_side = get_door_side(room, connection)
		var needed_side = get_opposite_side(attach_side)
		if needed_side == "":
			continue

		for end_scene in end_room_scenes:
			if scene_has_door_side(end_scene, needed_side):
				return true

	return false


func scene_has_door_side(scene, required_side: String) -> bool:
	if scene == null:
		return false

	var room = scene.instantiate()
	if room == null:
		return false

	var has_side = false
	for door in get_connections(room):
		if get_door_side(room, door) == required_side:
			has_side = true
			break

	room.free()
	return has_side


func get_opposite_side(side: String) -> String:
	if side == "left":
		return "right"
	if side == "right":
		return "left"
	if side == "top":
		return "bottom"
	if side == "bottom":
		return "top"
	return ""


func has_generation_timed_out() -> bool:
	if generation_deadline_ms <= 0:
		return false

	if Time.get_ticks_msec() <= generation_deadline_ms:
		return false

	if !generation_timed_out:
		generation_timed_out = true
		debug_log("Generation timeout reached.")

	return true


func get_connections(room):
	var connections = []
	for node in room.find_children("*", "StaticBody2D", true, false):
		if node.name.begins_with("Exit"):
			continue

		if node.name.begins_with("Door") or node.collision_layer == 2:
			connections.append(node)
	return connections


func get_room_for_connection(connection):
	for room in placed_rooms:
		if room == connection or room.is_ancestor_of(connection):
			return room
	return null


func get_connection_position(connection):
	var shape = connection.get_node_or_null("CollisionShape2D")
	if shape != null:
		return shape.global_position

	for child in connection.get_children():
		if child is CollisionShape2D:
			return child.global_position

	return connection.global_position


func are_doors_compatible(attach_room, attach_door, new_room, new_door):
	var attach_side = get_door_side(attach_room, attach_door)
	var new_side = get_door_side(new_room, new_door)

	if attach_side == "left" and new_side == "right":
		return true
	if attach_side == "right" and new_side == "left":
		return true
	if attach_side == "top" and new_side == "bottom":
		return true
	if attach_side == "bottom" and new_side == "top":
		return true

	return false


func get_door_side(room, door):
	var rect = get_room_rect(room)
	var door_pos = get_connection_position(door)

	var left_dist = abs(door_pos.x - rect.position.x)
	var right_dist = abs(door_pos.x - rect.end.x)
	var top_dist = abs(door_pos.y - rect.position.y)
	var bottom_dist = abs(door_pos.y - rect.end.y)

	var best_side = "left"
	var best_dist = left_dist

	if right_dist < best_dist:
		best_dist = right_dist
		best_side = "right"

	if top_dist < best_dist:
		best_dist = top_dist
		best_side = "top"

	if bottom_dist < best_dist:
		best_side = "bottom"

	return best_side


func get_side_offset(side):
	if side == "left":
		return Vector2.LEFT
	if side == "right":
		return Vector2.RIGHT
	if side == "top":
		return Vector2.UP
	if side == "bottom":
		return Vector2.DOWN
	return Vector2.ZERO


func get_room_rect(room):
	var has_rect = false
	var combined_rect = Rect2()

	for tile_map in room.find_children("*", "TileMap", true, false):
		var used_rect: Rect2i = tile_map.get_used_rect()
		if used_rect.size == Vector2i.ZERO:
			continue

		var tile_size: Vector2i = Vector2i(16, 16)
		if tile_map.tile_set:
			tile_size = tile_map.tile_set.tile_size

		var local_pos = Vector2(used_rect.position * tile_size)
		var local_size = Vector2(used_rect.size * tile_size)
		var room_rect = Rect2(tile_map.to_global(local_pos), local_size)

		if !has_rect:
			combined_rect = room_rect
			has_rect = true
		else:
			combined_rect = combined_rect.merge(room_rect)

	if !has_rect:
		return Rect2(room.global_position, Vector2.ZERO)

	return combined_rect


func is_room_area_free(room):
	var candidate_rect = get_room_rect(room)
	if candidate_rect.size == Vector2.ZERO:
		return true

	for existing_room in placed_rooms:
		var existing_rect = get_room_rect(existing_room)
		if existing_rect.size == Vector2.ZERO:
			continue

		if candidate_rect.intersects(existing_rect):
			return false

	return true


func find_closest_connection(target, connections):

	var closest = null
	var best_dist = INF

	for c in connections:
		var dist = target.global_position.distance_to(c.global_position)

		if dist < best_dist:
			best_dist = dist
			closest = c

	return closest
