extends Node3D

signal all_descendant_enemies_dead

@export var activation_target_paths: Array[NodePath] = []
@export var activation_method: StringName = "activate"
@export var monitor_interval_seconds: float = 0.25
@export var require_at_least_one_enemy: bool = true
@export var tracked_enemy_paths: Array[NodePath] = []

const MAX_TRACKED_ENEMIES: int = 4
const MAX_ACTIVATION_TARGETS: int = 8

var _monitor_elapsed: float = 0.0
var _has_seen_any_enemy: bool = false
var _has_activated: bool = false


func _ready() -> void:
	_sanitize_tracked_enemy_paths()
	_sanitize_activation_target_paths()
	_check_enemy_clear_state()


func _process(delta: float) -> void:
	if _has_activated:
		return

	_monitor_elapsed += delta
	if _monitor_elapsed < max(monitor_interval_seconds, 0.01):
		return

	_monitor_elapsed = 0.0
	_check_enemy_clear_state()


func _check_enemy_clear_state() -> void:
	var enemies := _get_tracked_enemies()
	if enemies.size() > 0:
		_has_seen_any_enemy = true

	for enemy in enemies:
		if not _is_enemy_dead(enemy):
			return

	if require_at_least_one_enemy and not _has_seen_any_enemy:
		return

	_activate_attached_script()


func _get_tracked_enemies() -> Array[Node]:
	if tracked_enemy_paths.is_empty():
		return _get_descendant_enemies()

	var result: Array[Node] = []
	for enemy_path in tracked_enemy_paths:
		if enemy_path == NodePath(""):
			continue

		var enemy_node := get_node_or_null(enemy_path)
		if enemy_node == null:
			continue
		if not enemy_node.is_in_group("enemy"):
			continue
		if result.has(enemy_node):
			continue

		result.append(enemy_node)

	return result


func _get_descendant_enemies() -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Node and is_ancestor_of(node):
			result.append(node)
	return result


func _sanitize_tracked_enemy_paths() -> void:
	if tracked_enemy_paths.size() <= MAX_TRACKED_ENEMIES:
		return

	tracked_enemy_paths = tracked_enemy_paths.slice(0, MAX_TRACKED_ENEMIES)
	push_warning("Only the first %d tracked enemies are used." % MAX_TRACKED_ENEMIES)


func _sanitize_activation_target_paths() -> void:
	if activation_target_paths.size() <= MAX_ACTIVATION_TARGETS:
		return

	activation_target_paths = activation_target_paths.slice(0, MAX_ACTIVATION_TARGETS)
	push_warning("Only the first %d activation targets are used." % MAX_ACTIVATION_TARGETS)


func _is_enemy_dead(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return true

	if enemy.is_queued_for_deletion():
		return true

	var dead_flag: Variant = enemy.get("is_dead")
	if typeof(dead_flag) == TYPE_BOOL and dead_flag:
		return true

	if enemy.has_method("is_dead"):
		return bool(enemy.call("is_dead"))

	return false


func _activate_attached_script() -> void:
	if _has_activated:
		return
	_has_activated = true

	emit_signal("all_descendant_enemies_dead")

	if activation_target_paths.is_empty():
		push_warning("No activation targets configured.")
		return

	for target_path in activation_target_paths:
		if target_path == NodePath(""):
			continue

		var target: Node = get_node_or_null(target_path)
		if target == null:
			push_warning("Activation target not found: %s" % target_path)
			continue

		if activation_method != StringName("") and target.has_method(String(activation_method)):
			target.call(String(activation_method))
		else:
			target.set_process(true)
			target.set_physics_process(true)
