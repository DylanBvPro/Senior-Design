extends CanvasLayer

@export var player_path: NodePath

var player: Node = null
@onready var mana_bar: TextureProgressBar = $TextureProgressBarMana


func _ready() -> void:
	_resolve_player_reference()
	_configure_mana_bars()
	_update_mana_bars()


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_resolve_player_reference()

	_update_mana_bars()


func _resolve_player_reference() -> void:
	player = null

	if player_path != NodePath(""):
		player = get_node_or_null(player_path)
		if player != null:
			return

	player = get_tree().get_first_node_in_group("player")


func _configure_mana_bars() -> void:
	if mana_bar == null:
		return

	mana_bar.min_value = 0.0
	mana_bar.max_value = 100.0


func _update_mana_bars() -> void:
	if player == null or not player.has_method("get_mana_percentage"):
		return

	var mana_percentage: Variant = player.call("get_mana_percentage")
	if not (typeof(mana_percentage) == TYPE_FLOAT or typeof(mana_percentage) == TYPE_INT):
		return

	if mana_bar != null:
		mana_bar.value = clamp(float(mana_percentage), 0.0, 100.0)
