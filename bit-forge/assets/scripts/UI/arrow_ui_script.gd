extends CanvasLayer

@export var player_path: NodePath

var player: Node = null


func _ready() -> void:
	_resolve_player_reference()
	_configure_arrow_bars()
	_update_arrow_bars()


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_resolve_player_reference()

	_update_arrow_bars()


func _resolve_player_reference() -> void:
	player = null

	if player_path != NodePath(""):
		player = get_node_or_null(player_path)
		if player != null:
			return

	player = get_tree().get_first_node_in_group("player")


func _configure_arrow_bars() -> void:
	for bar in _get_arrow_bars_in_ui_order():
		bar.min_value = 0.0
		bar.max_value = 100.0


func _update_arrow_bars() -> void:
	if player == null or not player.has_method("get_arrow_charges"):
		return

	var arrow_charges: Variant = player.call("get_arrow_charges")
	if typeof(arrow_charges) != TYPE_ARRAY:
		return

	var bars := _get_arrow_bars_in_ui_order()
	for i in range(bars.size()):
		if i < arrow_charges.size():
			bars[i].value = clamp(float(arrow_charges[i]) * 100.0, 0.0, 100.0)


func _get_arrow_bars_in_ui_order() -> Array[TextureProgressBar]:
	var bars: Array[TextureProgressBar] = []
	for child in get_children():
		if child is TextureProgressBar and child.name.begins_with("TextureProgressBar"):
			bars.append(child)
	return bars
