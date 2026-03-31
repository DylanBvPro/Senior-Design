extends Label

@export var combo_timeout_seconds: float = 10.0
@export var speed_bonus_per_stack: float = 0.10
@export var player_path: NodePath

var combo_count: int = 0
var combo_time_remaining: float = 0.0
var player: Player


func _ready() -> void:
	text = "0x"
	_resolve_player_reference()
	_connect_existing_enemy_signals()
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	_apply_player_combo_bonus()


func _process(delta: float) -> void:
	if combo_count <= 0:
		return

	combo_time_remaining = max(combo_time_remaining - delta, 0.0)
	if combo_time_remaining <= 0.0:
		_reset_combo()


func _on_enemy_killed_by_player(_enemy: Node) -> void:
	combo_count += 1
	text = str(combo_count) + "x"
	combo_time_remaining = combo_timeout_seconds

	if player and player.has_method("add_dash_charge"):
		player.call("add_dash_charge", 1)

	_apply_player_combo_bonus()


func _reset_combo() -> void:
	combo_count = 0
	combo_time_remaining = 0.0
	text = "0x"
	_apply_player_combo_bonus()


func _apply_player_combo_bonus() -> void:
	if not player:
		_resolve_player_reference()

	if not player:
		return

	var multiplier := 1.0 + (float(combo_count) * speed_bonus_per_stack)
	if player.has_method("set_combo_speed_multiplier"):
		player.call("set_combo_speed_multiplier", multiplier)


func _resolve_player_reference() -> void:
	player = null

	if player_path != NodePath(""):
		var path_node := get_node_or_null(player_path)
		if path_node is Player:
			player = path_node
			return

	var group_player := get_tree().get_first_node_in_group("player")
	if group_player is Player:
		player = group_player


func _connect_existing_enemy_signals() -> void:
	_connect_signals_recursive(get_tree().root)


func _connect_signals_recursive(node: Node) -> void:
	if not node:
		return

	_connect_enemy_signal(node)
	for child in node.get_children():
		_connect_signals_recursive(child)


func _on_tree_node_added(node: Node) -> void:
	_connect_enemy_signal(node)


func _connect_enemy_signal(node: Node) -> void:
	if not node or not node.has_signal("killed_by_player"):
		return

	var callback := Callable(self, "_on_enemy_killed_by_player")
	if not node.is_connected("killed_by_player", callback):
		node.connect("killed_by_player", callback)
