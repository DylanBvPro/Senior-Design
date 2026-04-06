extends Node

@export var label_path: NodePath
@export var visible_duration_seconds: float = 5.0
@export var fade_in_seconds: float = 0.4
@export var fade_out_seconds: float = 0.5
@export var trigger_once: bool = false
@export var activate_script_target: bool = false
@export var script_target_path: NodePath
@export var script_target_method: StringName = "activate"
@export var debug_logs_enabled: bool = true

var _label: Label
var _is_playing: bool = false
var _has_triggered: bool = false
var _current_tween: Tween


func _ready() -> void:
	_label = _resolve_label()
	if _label == null:
		push_warning("text_load_without_col_script: Could not find a Label target.")
	else:
		_label.visible = false
		_set_label_alpha(0.0)


func activate() -> void:
	if trigger_once and _has_triggered:
		return

	if debug_logs_enabled:
		print("[text_load_without_col_script] activate called: ", name)

	_show_text_sequence()


func _show_text_sequence() -> void:
	if _is_playing:
		return

	_has_triggered = true
	_activate_script_target()

	if _label == null:
		return

	_is_playing = true

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


func _activate_script_target() -> void:
	if not activate_script_target:
		return

	if script_target_path == NodePath(""):
		if debug_logs_enabled:
			push_warning("text_load_without_col_script: Script target is enabled but no node path is assigned.")
		return

	var script_target := get_node_or_null(script_target_path)
	if script_target == null:
		if debug_logs_enabled:
			push_warning("text_load_without_col_script: Script target not found: %s" % script_target_path)
		return

	if script_target_method == StringName(""):
		if debug_logs_enabled:
			push_warning("text_load_without_col_script: Script target method is empty.")
		return

	if script_target.has_method(String(script_target_method)):
		script_target.call(String(script_target_method))
	elif debug_logs_enabled:
		push_warning("text_load_without_col_script: Target %s does not have method %s." % [script_target.name, script_target_method])


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
