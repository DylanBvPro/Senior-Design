extends CanvasLayer

const WEAPON_SWORD := 1
const WEAPON_BOW := 2

@onready var primary_circle: Sprite2D = $Circlepng2
@onready var secondary_circle: Sprite2D = $Circlepng

var _player: Node = null
var _primary_slot_position: Vector2
var _primary_slot_scale: Vector2
var _secondary_slot_position: Vector2
var _secondary_slot_scale: Vector2
var _last_is_bow_equipped: bool = false


func _ready() -> void:
	if primary_circle == null or secondary_circle == null:
		push_warning("Weapon UI missing Circlepng2 or Circlepng node.")
		return

	_primary_slot_position = primary_circle.position
	_primary_slot_scale = primary_circle.scale
	_secondary_slot_position = secondary_circle.position
	_secondary_slot_scale = secondary_circle.scale

	_player = get_parent()
	_apply_layout_from_weapon(true)


func _process(_delta: float) -> void:
	_apply_layout_from_weapon(false)


func _apply_layout_from_weapon(force: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var equipped_weapon: Variant = _player.get("equipped_weapon")
	if typeof(equipped_weapon) != TYPE_INT:
		return

	var is_bow_equipped := int(equipped_weapon) == WEAPON_BOW
	if not force and is_bow_equipped == _last_is_bow_equipped:
		return

	if is_bow_equipped:
		secondary_circle.position = _primary_slot_position
		secondary_circle.scale = _primary_slot_scale
		primary_circle.position = _secondary_slot_position
		primary_circle.scale = _secondary_slot_scale
	else:
		primary_circle.position = _primary_slot_position
		primary_circle.scale = _primary_slot_scale
		secondary_circle.position = _secondary_slot_position
		secondary_circle.scale = _secondary_slot_scale

	_last_is_bow_equipped = is_bow_equipped
