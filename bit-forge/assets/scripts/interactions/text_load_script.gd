extends CollisionShape3D

@export var label_path: NodePath
@export var visible_duration_seconds: float = 5.0
@export var fade_in_seconds: float = 0.4
@export var fade_out_seconds: float = 0.5
@export var trigger_once: bool = false
@export var debug_logs_enabled: bool = true

var _label: Label
var _is_playing: bool = false
var _has_triggered: bool = false
var _current_tween: Tween


func _ready() -> void:
	_label = _resolve_label()
	if _label == null:
		push_warning("text_load_script: Could not find a Label target.")
		return

	_label.visible = false
	_set_label_alpha(0.0)

	var trigger_area := _resolve_trigger_area()
	if trigger_area == null:
		push_warning("text_load_script: Parent must be an Area3D to detect player entry.")
		return

	trigger_area.body_entered.connect(_on_body_entered)
	if debug_logs_enabled:
		print("[text_load_script] Connected body_entered on: ", trigger_area.name)


func _on_body_entered(body: Node) -> void:
	if debug_logs_enabled and body != null:
		print("[text_load_script] body_entered: ", body.name)

	if body == null or not _is_player(body):
		return

	if debug_logs_enabled:
		print("[text_load_script] Player entered trigger: ", name)

	if trigger_once and _has_triggered:
		return

	_show_text_sequence()


func _show_text_sequence() -> void:
	if _label == null:
		return
	if _is_playing:
		return

	_is_playing = true
	_has_triggered = true

	if _current_tween and _current_tween.is_running():
		_current_tween.kill()

	_label.visible = true
	_set_label_alpha(0.0)

	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_SINE)
	_current_tween.set_ease(Tween.EASE_IN_OUT)
	_current_tween.tween_property(_label, "modulate:a", 1.0, max(fade_in_seconds, 0.01))
	_current_tween.tween_interval(max(visible_duration_seconds, 0.0))
	_current_tween.tween_property(_label, "modulate:a", 0.0, max(fade_out_seconds, 0.01))
	await _current_tween.finished

	_label.visible = false
	_is_playing = false


func _resolve_label() -> Label:
	if label_path != NodePath(""):
		var explicit_label := get_node_or_null(label_path)
		if explicit_label is Label:
			return explicit_label

	var parent_node := get_parent()
	if parent_node == null:
		return null

	var parent_index := get_index()
	var siblings := parent_node.get_children()
	for i in range(parent_index + 1, siblings.size()):
		var sibling := siblings[i]
		if sibling is CanvasLayer:
			var found := _find_first_label(sibling)
			if found != null:
				return found

	return null


func _find_first_label(node: Node) -> Label:
	if node is Label:
		return node

	for child in node.get_children():
		var found := _find_first_label(child)
		if found != null:
			return found

	return null


func _set_label_alpha(alpha: float) -> void:
	if _label == null:
		return

	var current_modulate := _label.modulate
	current_modulate.a = clampf(alpha, 0.0, 1.0)
	_label.modulate = current_modulate


func _resolve_trigger_area() -> Area3D:
	if get_parent() is Area3D:
		return get_parent() as Area3D

	var current := get_parent()
	while current != null:
		if current is Area3D:
			return current as Area3D
		current = current.get_parent()

	return null


func _is_player(body: Node) -> bool:
	if body.is_in_group("player"):
		return true

	return body.name.to_lower().contains("player")
