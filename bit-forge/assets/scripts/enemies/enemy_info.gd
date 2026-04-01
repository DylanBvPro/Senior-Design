class_name EnemyInfo
extends Node

enum AttackType {
	MELEE,
	RANGED,
}

@export var follow_speed: float = 3.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5
@export var max_health: float = 40.0
@export var armor: float = 0.0

# Legacy field kept for existing scenes. New logic uses melee_range/ranged_range.
@export var attack_distance: float = 2.0
@export var melee_range: float = 2.0
@export var ranged_range: float = 8.0
@export var attack_type: AttackType = AttackType.MELEE
@export var ranged_retreat_speed: float = 1.5
@export var ranged_backpedal_animation: StringName = "Walking_Backwards"

@export var idle_animation: StringName = "Unarmed_Idle"
@export var follow_animation: StringName = "Walking_D_Skeletons"

# Legacy single attack animation support.
@export var attack_animation: StringName = "Unarmed_Melee_Attack_Punch_A"
@export var attack_animation_primary: StringName = "Unarmed_Melee_Attack_Punch_A"
@export var attack_animation_secondary: StringName = "Unarmed_Melee_Attack_Punch_B"
@export var hit_animation: StringName = "Hit_B"
@export var death_animation: StringName = "Death_C_Skeletons"

@export var hit_stun_duration: float = 0.5
@export var hit_iframe_duration: float = 1.0
@export var hit_knockback_speed: float = 10.4
@export var hit_knockback_damping: float = 14.0

@export var projectile_speed: float = 12.0
@export var projectile_max_distance: float = 40.0

@export var despawn_delay: float = 10.0
@export var sink_distance: float = 2.0
@export var sink_duration: float = 1.25


func get_melee_range() -> float:
	return melee_range if melee_range > 0.0 else attack_distance


func get_ranged_range() -> float:
	return ranged_range if ranged_range > 0.0 else attack_distance


func get_attack_animations() -> Array[StringName]:
	var animations: Array[StringName] = []
	if attack_animation_primary != StringName(""):
		animations.append(attack_animation_primary)
	if attack_animation_secondary != StringName(""):
		animations.append(attack_animation_secondary)
	if animations.is_empty() and attack_animation != StringName(""):
		animations.append(attack_animation)
	return animations
