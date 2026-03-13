extends Node2D

@export var rooms_folder := "res://assets/2dsimulation/sceanes/random_rooms/"
@export var max_rooms := 25
@export_range(1, 10, 1) var dungeon_complexity := 5
@export var debug_generation := true
@export var door_connection_gap := 16.0
@export var enforce_closed_paths := true
@export var max_room_repeats_in_a_row := 3

var room_scenes : Array = []
var terminal_room_scenes : Array = []
var connector_room_scenes : Array = []
var placed_rooms : Array = []
var open_connections : Array = []
var beginning_room: Node2D = null
var ending_room: Node2D = null
var dead_end_rooms: Array = []
var last_scene_key = ""
var consecutive_scene_count := 0

func _ready():
	load_rooms()
	generate_dungeon()


func load_rooms():
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


func generate_dungeon():
	generate_dungeon_dynamic(max_rooms)


func generate_dungeon_dynamic(total_rooms: int, complexity_override: int = -1):
	var complexity = dungeon_complexity
	if complexity_override > 0:
		complexity = complexity_override
	complexity = clampi(complexity, 1, 10)

	if room_scenes.is_empty():
		return

	if terminal_room_scenes.is_empty():
		push_error("Need at least one 1-door room for beginning/end.")
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
		generate_layout_once(total_rooms, complexity)

		if placed_rooms.size() >= min_required_rooms:
			reached_target = true
			debug_log("Reached complexity target on attempt " + str(attempt + 1))
			break

		if attempt < max_attempts - 1:
			debug_log("Retrying generation: placed " + str(placed_rooms.size()) + " rooms.")

	if !reached_target:
		debug_log(
			"Did not reach complexity target."
			+ " placed=" + str(placed_rooms.size())
			+ " target=" + str(min_required_rooms)
		)


func generate_layout_once(total_rooms: int, complexity: int):

	# Place beginning room (must be 1-door)
	var first_room_scene = terminal_room_scenes.pick_random()
	var first_room = first_room_scene.instantiate()
	add_child(first_room)
	placed_rooms.append(first_room)
	beginning_room = first_room
	register_placed_scene(first_room_scene)
	debug_log("Placed first room: " + first_room.name)

	open_connections += get_connections(first_room)
	debug_log("First room doors found: " + str(open_connections.size()))

	var wants_ending = total_rooms > 1
	var complexity_t = float(complexity - 1) / 9.0
	var remaining_slots = maxi(total_rooms - 1, 0)
	var max_dead_ends = maxi(remaining_slots - int(wants_ending), 0)
	var dead_end_ratio = lerpf(0.45, 0.10, complexity_t)
	var dead_end_target = clampi(int(round(remaining_slots * dead_end_ratio)), 0, max_dead_ends)
	var connector_target = maxi(remaining_slots - dead_end_target - int(wants_ending), 0)

	debug_log(
		"Targets | connectors=" + str(connector_target)
		+ " dead_ends=" + str(dead_end_target)
		+ " ending=" + str(wants_ending)
	)

	# Generate middle connector rooms (2+ doors preferred)
	for i in range(connector_target):
		var connector_pool = connector_room_scenes
		if connector_pool.is_empty():
			connector_pool = room_scenes

		var placement_result = try_place_room(connector_pool)
		if placement_result["placed"]:
			debug_log("Placed connector room at step " + str(i + 1))
		else:
			debug_log("Failed connector placement at step " + str(i + 1))
			break

	# Generate branch dead-ends (1-door, not start/end)
	for i in range(dead_end_target):
		var dead_end_result = try_place_room(terminal_room_scenes, 1)
		if dead_end_result["placed"]:
			dead_end_rooms.append(dead_end_result["room"])
			debug_log("Placed dead-end room #" + str(dead_end_rooms.size()))
		else:
			debug_log("Failed dead-end placement at step " + str(i + 1))
			break

	# Place ending room (must be 1-door)
	if wants_ending:
		if !try_place_terminal_room(true):
			debug_log("Could not place ending room with current layout.")

	if enforce_closed_paths:
		close_remaining_paths(wants_ending)

	debug_log("Generation complete. Total rooms placed: " + str(placed_rooms.size()))
	debug_log("Roles | beginning=1 ending=" + str(ending_room != null) + " dead_ends=" + str(dead_end_rooms.size()))


func debug_log(message):
	if debug_generation:
		print("[RoomGen] " + message)


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


func count_scene_doors(scene):
	var room = scene.instantiate()
	var count = get_connections(room).size()
	room.free()
	return count


func try_place_room(scene_pool: Array, required_door_count: int = -1) -> Dictionary:
	if scene_pool.is_empty():
		return {"placed": false}

	if open_connections.is_empty():
		return {"placed": false}

	var shuffled_connections = open_connections.duplicate()
	shuffled_connections.shuffle()

	var shuffled_room_scenes = scene_pool.duplicate()
	shuffled_room_scenes.shuffle()

	for attach_point in shuffled_connections:
		var attach_room = get_room_for_connection(attach_point)
		if attach_room == null:
			continue

		for room_scene in shuffled_room_scenes:
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
				if !are_doors_compatible(attach_room, attach_point, new_room, new_door):
					continue

				var attach_side = get_door_side(attach_room, attach_point)
				var offset = get_connection_position(attach_point) - get_connection_position(new_door)
				offset += get_side_offset(attach_side) * door_connection_gap
				new_room.position += offset

				if is_room_area_free(new_room):
					placed_rooms.append(new_room)
					register_placed_scene(room_scene)
					open_connections.erase(attach_point)
					new_connections.erase(new_door)
					open_connections += new_connections
					debug_log(
						"Placed room #" + str(placed_rooms.size())
						+ " using " + attach_point.name
						+ " -> " + new_door.name
						+ ", remaining open doors: " + str(open_connections.size())
					)
					return {
						"placed": true,
						"room": new_room,
						"attach_point": attach_point,
						"new_door": new_door
					}

				new_room.position -= offset

			new_room.queue_free()

	return {"placed": false}


func get_scene_key(scene) -> String:
	if scene == null:
		return ""

	if scene.resource_path != "":
		return scene.resource_path

	return str(scene.get_instance_id())


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
	var result = try_place_room(terminal_room_scenes, 1)
	if !result["placed"]:
		return false

	var room = result["room"]
	if mark_as_ending and ending_room == null:
		ending_room = room
		debug_log("Placed ending room: " + ending_room.name)
	else:
		dead_end_rooms.append(room)
		debug_log("Placed dead-end room #" + str(dead_end_rooms.size()))

	return true


func close_remaining_paths(wants_ending: bool):
	if open_connections.is_empty():
		return

	var safety = 0
	while !open_connections.is_empty() and safety < 500:
		safety += 1

		var needs_ending = wants_ending and ending_room == null
		if !try_place_terminal_room(needs_ending):
			debug_log("Stopped path closure: could not cap remaining open connection.")
			break

	if !open_connections.is_empty():
		debug_log("Warning: open connections still remain after closure pass: " + str(open_connections.size()))



func get_connections(room):
	var connections = []
	for node in room.find_children("*", "StaticBody2D", true, false):
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
