extends CanvasLayer

@export var player_path: NodePath

var _player: Player = null
@onready var _speed_progress_bar: TextureProgressBar = $TextureProgressBar


func _ready() -> void:
	visible = false
	if _speed_progress_bar != null:
		_speed_progress_bar.min_value = 0.0
		_speed_progress_bar.max_value = 100.0
		_speed_progress_bar.value = 0.0
	_resolve_player_reference()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_resolve_player_reference()
		if _player == null:
			visible = false
			return

	var temp_speed_multiplier_value = _player.get("temporary_speed_multiplier")
	var speed_bonus_duration: float = 0.0
	var speed_bonus_remaining: float = 0.0
	if _player.has_method("get_speed_bonus_duration"):
		speed_bonus_duration = float(_player.call("get_speed_bonus_duration"))
	if _player.has_method("get_speed_bonus_time_remaining"):
		speed_bonus_remaining = float(_player.call("get_speed_bonus_time_remaining"))

	if temp_speed_multiplier_value == null:
		visible = false
		if _speed_progress_bar != null:
			_speed_progress_bar.value = 0.0
		return

	var has_temp_speed_bonus := float(temp_speed_multiplier_value) > 1.0 and speed_bonus_remaining > 0.0
	visible = has_temp_speed_bonus

	if _speed_progress_bar != null:
		if has_temp_speed_bonus and speed_bonus_duration > 0.0:
			var progress_ratio := clampf(speed_bonus_remaining / speed_bonus_duration, 0.0, 1.0)
			_speed_progress_bar.value = progress_ratio * _speed_progress_bar.max_value
		else:
			_speed_progress_bar.value = 0.0


func _resolve_player_reference() -> void:
	_player = null

	if player_path != NodePath(""):
		var path_node := get_node_or_null(player_path)
		if path_node is Player:
			_player = path_node
			return

	var group_player := get_tree().get_first_node_in_group("player")
	if group_player is Player:
		_player = group_player
