extends CharacterBody3D

# --------------------
# Tuning Variables (plug & chug)
# --------------------

@export var move_speed: float = 3.0
@export var chase_speed: float = 6.0
@export var max_hp: float = 20.0
@export var detection_distance: float = 12.0
@export var pursue_distance: float = 1.8
@export var taunt_chance: float = 0.3


# Animation state names (AnimationTree)
@export var Spawn_Anim: String = "Spawn_Ground_Skeletons"
@export var Idle_Anim: String = "Idle_B"
@export var Run_Anim: String = "Running_C"
@export var Taunt_Anim: String = "Taunt"
@export var Attack_Anim: String = "Unarmed_Melee_Attack_Punch_A"
@export var Hit_Anim: String = "Hit_B"
@export var Death_Anim: String = "Death_C_Skeletons"
@export var damage_amount: float = 5.0
@export var attack_range: float = 2.0
@export var attack_anim_duration: float = 0.9
@export var attack_hit_time: float = 0.45



# --------------------
# Node References
# --------------------
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player : AnimationPlayer = $"AnimationPlayer"
@onready var state_machine: AnimationNodeStateMachinePlayback = \
	animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback

@onready var player_finder: PlayerFinder = $PlayerFinder
@onready var nav_region: NavigationRegion3D = $"../../NavigationRegion3D"

# --------------------
# Internal State
# --------------------

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_taunting: bool = false
var is_attacking: bool = false
var is_spawning: bool = false
var _is_in_idle: bool = false

# --------------------
# Lifecycle
# --------------------

var current_hp: float = max_hp

func _ready() -> void:
	animation_tree.active = true

	# Forward tuning vars to PlayerFinder
	player_finder.detection_distance = detection_distance
	player_finder.pursue_distance = pursue_distance
	player_finder.taunt_chance = taunt_chance

	_play_spawn_animation()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Keep the skeleton stationary until spawn animation is complete
	if is_spawning:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# If no player detected, always idle
	if player_finder.player == null:
		_idle()
	elif not is_attacking:
		var result = player_finder.update_player_logic(delta)
		
		match result.state:
			"NO_PLAYER":
				_idle()

			"TAUNT":
				_handle_taunt()

			"CHASE":
				_handle_chase(player_finder.player.global_position)

			"ATTACK":
				_handle_attack()
	else:
		_track_player_while_attacking()
		# Zero horizontal movement while attacking
		velocity.x = 0
		velocity.z = 0

	move_and_slide()

# --------------------
# Animation / State Flow
# --------------------

func _play_spawn_animation() -> void:
	is_spawning = true
	state_machine.travel(Spawn_Anim)
	var spawn_duration := _get_animation_length(Spawn_Anim, 1.8)
	await get_tree().create_timer(spawn_duration).timeout
	is_spawning = false
	_idle()

func _get_animation_length(animation_name: String, fallback: float) -> float:
	if animation_player and animation_player.has_animation(animation_name):
		var anim := animation_player.get_animation(animation_name)
		if anim:
			return max(anim.length, 0.01)
	return fallback

func _idle() -> void:
	if _is_in_idle:
		return
	_is_in_idle = true
	
	is_taunting = false
	is_attacking = false

	velocity.x = 0.0
	velocity.z = 0.0

	state_machine.travel(Idle_Anim)
	_is_in_idle = false

# --------------------
# Behavior Handlers
# --------------------

func _handle_taunt() -> void:
	if is_taunting:
		return

	is_taunting = true
	velocity.x = 0.0
	velocity.z = 0.0

	state_machine.travel(Taunt_Anim)

	# After taunt, immediately pursue
	await get_tree().create_timer(1.2).timeout
	is_taunting = false

func _handle_chase(player_pos: Vector3) -> void:
	nav_agent.target_position = player_pos

	if not nav_agent.is_navigation_finished():
		var next_point := nav_agent.get_next_path_position()
		var dir := next_point - global_position
		dir.y = 0  # IMPORTANT: prevents tilt / weird angles

		if dir.length() > 0.01:
			dir = dir.normalized()
			velocity.x = dir.x * chase_speed
			velocity.z = dir.z * chase_speed
			look_at(global_position + dir, Vector3.UP)

			if state_machine.get_current_node() != Run_Anim:
				state_machine.travel(Run_Anim)
		else:
			velocity.x = 0
			velocity.z = 0
	else:
		velocity.x = 0
		velocity.z = 0
		state_machine.travel(Idle_Anim, true)

func _handle_attack() -> void:
	if is_attacking:
		return

	is_attacking = true
	velocity.x = 0.0
	velocity.z = 0.0
	state_machine.travel(Attack_Anim)
	await get_tree().process_frame

	if not _is_attack_animation_active():
		is_attacking = false
		return

	# Wait until the attack's hit frame, then try to deal damage
	await get_tree().create_timer(attack_hit_time).timeout
	if _is_attack_animation_active():
		_try_deal_damage()

	# Wait the remainder of the attack animation before allowing other actions
	var remaining: float = max(0.0, attack_anim_duration - attack_hit_time)
	await get_tree().create_timer(remaining).timeout
	is_attacking = false

func _track_player_while_attacking() -> void:
	var target := player_finder.player
	if target == null:
		return

	var dir := target.global_position - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		look_at(global_position + dir.normalized(), Vector3.UP)

func _is_attack_animation_active() -> bool:
	if state_machine == null:
		return false
	return state_machine.get_current_node() == Attack_Anim
	
func _try_deal_damage() -> void:
	if not _is_attack_animation_active():
		return

	var target = player_finder.player
	if target == null:
		return

	# Compare horizontal distance only
	var self_pos = Vector3(global_position.x, 0.0, global_position.z)
	var target_pos = Vector3(target.global_position.x, 0.0, target.global_position.z)
	var dist = self_pos.distance_to(target_pos)

	if dist <= attack_range:
		if target.has_method("apply_damage"):
			target.apply_damage(damage_amount, self)
		elif target.has_method("take_damage"):
			target.take_damage(damage_amount, self)
func _return_to_roaming() -> void:
	is_attacking = false
	is_taunting = false
	
	# Make sure the skeleton is not idling
	_is_in_idle = false
	
	# Switch animation to idle immediately
	state_machine.travel(Idle_Anim)

# # --------------------
# HP / Death Logic
# --------------------


func apply_damage(amount: float) -> void:
	current_hp -= amount
	print("Enemy hit! HP:", current_hp)
	
	# Play hit animation
	if animation_tree and state_machine:
		state_machine.travel(Hit_Anim, true)
	
	if current_hp <= 0.0:
		_die()

func take_damage(amount: float) -> void:
	# Alias for other scripts
	apply_damage(amount)

func _die() -> void:
	# Stop all behavior
	is_taunting = false
	is_attacking = false
	velocity = Vector3.ZERO

	# Play death animation first
	if animation_tree and state_machine:
		state_machine.travel(Death_Anim, true)

	var death_duration := _get_animation_length(Death_Anim, 1.6)
	await get_tree().create_timer(death_duration).timeout
	collision_layer = 0
	collision_mask = 0
	
	set_physics_process(false)
	set_process(false)
