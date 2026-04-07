extends CanvasLayer

@export var player_path: NodePath

var _player: Player = null
@onready var _defense_progress_bar: TextureProgressBar = $TextureProgressBar


func _ready() -> void:
	visible = false
	if _defense_progress_bar != null:
		_defense_progress_bar.min_value = 0.0
		_defense_progress_bar.max_value = 100.0
		_defense_progress_bar.value = 0.0
	_resolve_player_reference()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_resolve_player_reference()
		if _player == null:
			visible = false
			return

	var current_armor_value = _player.get("current_armor")
	var defense_bonus_multiplier_value = _player.get("defense_bonus_damage_multiplier")
	var defense_bonus_duration: float = 0.0
	var defense_bonus_remaining: float = 0.0
	if _player.has_method("get_defense_bonus_duration"):
		defense_bonus_duration = float(_player.call("get_defense_bonus_duration"))
	if _player.has_method("get_defense_bonus_time_remaining"):
		defense_bonus_remaining = float(_player.call("get_defense_bonus_time_remaining"))

	var has_armor_bonus := current_armor_value != null and float(current_armor_value) > 0.0
	var has_temp_defense_bonus := defense_bonus_multiplier_value != null and float(defense_bonus_multiplier_value) < 1.0 and defense_bonus_remaining > 0.0
	visible = has_armor_bonus or has_temp_defense_bonus

	if _defense_progress_bar != null:
		if has_temp_defense_bonus and defense_bonus_duration > 0.0:
			var progress_ratio := clampf(defense_bonus_remaining / defense_bonus_duration, 0.0, 1.0)
			_defense_progress_bar.value = progress_ratio * _defense_progress_bar.max_value
		else:
			_defense_progress_bar.value = 0.0


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
