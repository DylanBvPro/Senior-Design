extends TextureProgressBar

@export var player_path: NodePath

var _player: Node = null


func _ready() -> void:
	_player = _resolve_player()
	_configure_texture_fill()
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

	var current_hp = _player.get("current_hp")
	var max_hp = _player.get("max_hp")
	if current_hp == null or max_hp == null:
		return

	max_value = max(float(max_hp), 1.0)
	value = clamp(float(current_hp), 0.0, max_value)


func _configure_texture_fill() -> void:
	# Keep fill driven by texture_progress instead of ProgressBar style overrides.
	if has_theme_stylebox_override("fill"):
		remove_theme_stylebox_override("fill")
	tint_progress = Color(1, 1, 1, 1)
