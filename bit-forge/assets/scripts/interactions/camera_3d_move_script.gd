extends Camera3D

@export var move_distance_meters: float = 5.0
@export var move_duration_seconds: float = 2.5
@export var pitch_up_degrees: float = 10.0
@export var ui_fade_in_seconds: float = 0.8
@export var auto_play_on_ready: bool = false

var _ui_items: Array[CanvasItem] = []
var _is_sequence_running: bool = false


func _ready() -> void:
	_collect_ui_descendants(self)
	_set_ui_alpha(0.0)

	if auto_play_on_ready:
		call_deferred("activate")


func activate() -> void:
	if _is_sequence_running:
		return

	_is_sequence_running = true
	await _move_forward_sequence()
	await _fade_in_ui_sequence()
	_enable_menu_mouse_input()
	_is_sequence_running = false


func _move_forward_sequence() -> void:
	var forward: Vector3 = -global_transform.basis.z.normalized()
	var target_position: Vector3 = global_position + forward * move_distance_meters
	var target_rotation: Vector3 = rotation_degrees
	target_rotation.x -= pitch_up_degrees

	var move_tween := create_tween()
	move_tween.set_parallel(true)
	move_tween.set_trans(Tween.TRANS_SINE)
	move_tween.set_ease(Tween.EASE_IN_OUT)
	move_tween.tween_property(self, "global_position", target_position, maxf(move_duration_seconds, 0.01))
	move_tween.tween_property(self, "rotation_degrees", target_rotation, maxf(move_duration_seconds, 0.01))
	await move_tween.finished


func _fade_in_ui_sequence() -> void:
	if _ui_items.is_empty():
		return

	var fade_tween := create_tween()
	fade_tween.set_parallel(true)
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_OUT)

	for item in _ui_items:
		if item == null or not is_instance_valid(item):
			continue
		item.visible = true
		fade_tween.tween_property(item, "modulate:a", 1.0, maxf(ui_fade_in_seconds, 0.01))

	await fade_tween.finished


func _collect_ui_descendants(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			_ui_items.append(child as CanvasItem)
		_collect_ui_descendants(child)


func _set_ui_alpha(alpha: float) -> void:
	for item in _ui_items:
		if item == null or not is_instance_valid(item):
			continue
		item.visible = true
		var c: Color = item.modulate
		c.a = clampf(alpha, 0.0, 1.0)
		item.modulate = c


func _enable_menu_mouse_input() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
