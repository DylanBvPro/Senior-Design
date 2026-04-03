extends CanvasLayer

const WEAPON_SWORD := 1
const WEAPON_BOW := 2
const WEAPON_MAGIC := 3

@onready var sword_circle: Sprite2D = $Circlepng2
@onready var bow_circle: Sprite2D = $Circlepng
@onready var magic_circle: Sprite2D = $Circlepng3

var _player: Node = null
var _primary_slot_position: Vector2
var _primary_slot_scale: Vector2
var _bow_slot_position: Vector2
var _bow_slot_scale: Vector2
var _magic_slot_position: Vector2
var _magic_slot_scale: Vector2
var _secondary_large_slot_position: Vector2
var _secondary_large_slot_scale: Vector2
var _secondary_small_slot_position: Vector2
var _secondary_small_slot_scale: Vector2
var _last_weapon: int = WEAPON_SWORD


func _ready() -> void:
	if sword_circle == null or bow_circle == null or magic_circle == null:
		push_warning("Weapon UI missing Circlepng2, Circlepng, or Circlepng3 node.")
		return

	_primary_slot_position = sword_circle.position
	_primary_slot_scale = sword_circle.scale
	_bow_slot_position = bow_circle.position
	_bow_slot_scale = bow_circle.scale
	_magic_slot_position = magic_circle.position
	_magic_slot_scale = magic_circle.scale

	if _slot_weight(_bow_slot_scale) >= _slot_weight(_magic_slot_scale):
		_secondary_large_slot_position = _bow_slot_position
		_secondary_large_slot_scale = _bow_slot_scale
		_secondary_small_slot_position = _magic_slot_position
		_secondary_small_slot_scale = _magic_slot_scale
	else:
		_secondary_large_slot_position = _magic_slot_position
		_secondary_large_slot_scale = _magic_slot_scale
		_secondary_small_slot_position = _bow_slot_position
		_secondary_small_slot_scale = _bow_slot_scale

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

	var weapon := int(equipped_weapon)
	if weapon != WEAPON_SWORD and weapon != WEAPON_BOW and weapon != WEAPON_MAGIC:
		weapon = WEAPON_SWORD

	if not force and weapon == _last_weapon:
		return

	var next_weapon := _next_weapon_in_cycle(weapon)
	var remaining_weapon := _remaining_weapon(weapon, next_weapon)

	_set_circle_slot(_circle_for_weapon(weapon), _primary_slot_position, _primary_slot_scale)
	_set_circle_slot(_circle_for_weapon(next_weapon), _secondary_large_slot_position, _secondary_large_slot_scale)
	_set_circle_slot(_circle_for_weapon(remaining_weapon), _secondary_small_slot_position, _secondary_small_slot_scale)

	_last_weapon = weapon


func _set_circle_slot(circle: Sprite2D, slot_position: Vector2, slot_scale: Vector2) -> void:
	circle.position = slot_position
	circle.scale = slot_scale


func _slot_weight(slot_scale: Vector2) -> float:
	return absf(slot_scale.x * slot_scale.y)


func _next_weapon_in_cycle(weapon: int) -> int:
	if weapon == WEAPON_SWORD:
		return WEAPON_BOW
	if weapon == WEAPON_BOW:
		return WEAPON_MAGIC
	return WEAPON_SWORD


func _remaining_weapon(current_weapon: int, next_weapon: int) -> int:
	for weapon in [WEAPON_SWORD, WEAPON_BOW, WEAPON_MAGIC]:
		if weapon != current_weapon and weapon != next_weapon:
			return weapon
	return WEAPON_SWORD


func _circle_for_weapon(weapon: int) -> Sprite2D:
	if weapon == WEAPON_BOW:
		return bow_circle
	if weapon == WEAPON_MAGIC:
		return magic_circle
	return sword_circle
