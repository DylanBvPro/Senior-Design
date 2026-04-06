extends TextureProgressBar

@export var player_path: NodePath
@export_file("*.tscn") var death_scene_path: String = "res://assets/sceanes/death_sceane.tscn"

var _player: Node = null
var _hp_label: Label = null
var _sent_to_graveyard: bool = false


func _ready() -> void:
	_player = _resolve_player()
	_hp_label = _resolve_label_below()
	_sync_from_player()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _resolve_player()
	_sync_from_player()


func _resolve_player() -> Node:
	if player_path != NodePath(""):
		return get_node_or_null(player_path)

	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null

	return players[0]


func _sync_from_player() -> void:
	if _player == null:
		return
	if _hp_label == null or not is_instance_valid(_hp_label):
		_hp_label = _resolve_label_below()

	var current_hp = _player.get("current_hp")
	var max_hp = _player.get("max_hp")
	if current_hp == null or max_hp == null:
		return

	var max_hp_float: float = max(float(max_hp), 1.0)
	var current_hp_float: float = clamp(float(current_hp), 0.0, max_hp_float)

	max_value = max_hp_float
	value = current_hp_float

	if current_hp_float <= 0.0 and not _sent_to_graveyard:
		_sent_to_graveyard = true
		_capture_last_scene_before_death()
		call_deferred("_go_to_death_scene")

	if _hp_label != null:
		_hp_label.text = "%d / %d" % [int(round(current_hp_float)), int(round(max_hp_float))]


func _resolve_label_below() -> Label:
	# In this scene, the hp label is usually a child of the health bar.
	var direct_child := get_node_or_null("Label")
	if direct_child is Label:
		return direct_child as Label

	for child in get_children():
		if child is Label:
			return child as Label

	var parent_node := get_parent()
	if parent_node == null:
		return null

	var start_index: int = get_index() + 1
	var children: Array = parent_node.get_children()

	for i in range(start_index, children.size()):
		var sibling: Node = children[i]
		if sibling is Label:
			return sibling as Label
		for nested in sibling.get_children():
			if nested is Label:
				return nested as Label

	return null


func _capture_last_scene_before_death() -> void:
	if not has_node("/root/Messenger"):
		return

	var scene := get_tree().current_scene
	if scene == null:
		return

	var scene_path := scene.scene_file_path
	if scene_path == "" or scene_path == death_scene_path:
		return

	Messenger.call("set_last_scene_before_death", scene_path)


func _go_to_death_scene() -> void:
	if death_scene_path == "":
		return

	if _player != null and is_instance_valid(_player) and _player.has_method("play_scene_loading_transition"):
		await _player.call("play_scene_loading_transition")

	get_tree().change_scene_to_file(death_scene_path)
