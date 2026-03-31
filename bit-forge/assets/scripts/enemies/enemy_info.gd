class_name EnemyInfo
extends Node

@export var follow_speed: float = 3.0
@export var attack_distance: float = 2.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5
@export var max_health: float = 40.0

@export var idle_animation: StringName = "Unarmed_Idle"
@export var follow_animation: StringName = "Walking_D_Skeletons"
@export var attack_animation: StringName = "Unarmed_Melee_Attack_Punch_A"
@export var hit_animation: StringName = "Hit_B"
@export var death_animation: StringName = "Death_C_Skeletons"

@export var despawn_delay: float = 10.0
@export var sink_distance: float = 2.0
@export var sink_duration: float = 1.25
