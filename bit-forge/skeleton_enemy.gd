extends CharacterBody3D

# --------------------
# Tuning Variables (plug & chug)
# --------------------

@export var move_speed: float = 3.0
@export var chase_speed: float = 6.0
@export var max_hp := 20.0

@export var detection_distance: float = 12.0
@export var pursue_distance: float = 1.8
@export var taunt_chance: float = 0.3

# Animation state names (AnimationTree)
@export var Spawn_Anim: String = "Spawn_Ground_Skeletons"
@export var Idle_Anim: String = "Idle_B"
@export var Walk_Anim: String = "Walking_A"
@export var Run_Anim: String = "Running_C"
@export var Taunt_Anim: String = "Taunt"
@export var Attack_Anim: String = "Unarmed_Melee_Attack_Punch_A"

@export var idle_time_range: Vector2 = Vector2(2.5, 9.5)

# --------------------
# Node References
# --------------------
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var state_machine: AnimationNodeStateMachinePlayback = \
	animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback

@onready var free_roam: FreeRoamMovement = $FreeRoam
@onready var player_finder: PlayerFinder = $PlayerFinder
@onready var nav_region: NavigationRegion3D = $"../../NavigationRegion3D"
@onready var ragdoll: Node = $Rig/Skeleton3D/Ragdoll  # Assuming the skeleton's ragdoll parts are a child node of the skeleton

# --------------------
# Internal State
# --------------------

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_wandering: bool = false
var is_taunting: bool = false
var is_attacking: bool = false
var _is_in_idle: bool = false
var _idle_timer: Timer = null

# --------------------
# Lifecycle
# --------------------

var current_hp := max_hp

func _ready() -> void:
	animation_tree.active = true

	# Initially disable ragdoll physics
	disable_ragdoll()

	# Forward tuning vars to PlayerFinder
	player_finder.detection_distance = detection_distance
	player_finder.pursue_distance = pursue_distance
	player_finder.taunt_chance = taunt_chance
	
	# Connect FreeRoam signals (stops and starts)
	free_roam.connect("stopped", Callable(self, "_idle"))
	free_roam.connect("started_moving", Callable(self, "_start_wandering"))

	_play_spawn_animation()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# If attacking, block all other movement
	if not is_attacking:
		var result = player_finder.update_player_logic(delta)
		
		match result.state:
			"NO_PLAYER":
				# Interrupt idle if needed
				if _is_in_idle and _idle_timer:
					_idle_timer.stop()
					_is_in_idle = false

				# Stop running immediately
				if state_machine.get_current_node() == Run_Anim:
					state_machine.travel(Idle_Anim, true)  # true = reset instantly

				# Start roaming logic
				is_wandering = true
				_handle_roaming(delta)

			"TAUNT":
				_handle_taunt()

			"CHASE":
				_handle_chase(player_finder.player.global_position)

			"ATTACK":
				_handle_attack()
	else:
		# Zero horizontal movement while attacking
		velocity.x = 0
		velocity.z = 0

	move_and_slide()

# --------------------
# Animation / State Flow
# --------------------

func _play_spawn_animation() -> void:
	state_machine.travel(Spawn_Anim)
	await get_tree().create_timer(1.8).timeout
	_idle()

func _idle() -> void:
	if _is_in_idle:
		return
	_is_in_idle = true
	
	is_wandering = false
	is_taunting = false
	is_attacking = false

	velocity.x = 0.0
	velocity.z = 0.0

	state_machine.travel(Idle_Anim)

	var idle_time := randf_range(idle_time_range.x, idle_time_range.y)
	await get_tree().create_timer(idle_time).timeout
	
	_is_in_idle = false
	is_wandering = true
	state_machine.travel(Walk_Anim)

# --------------------
# Behavior Handlers
# --------------------

func _handle_roaming(delta: float) -> void:
	if _is_in_idle or not is_wandering:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var dir := free_roam.update_roaming(delta)

	if dir.length() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0


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

	await get_tree().create_timer(0.9).timeout
	is_attacking = false
	
func _return_to_roaming() -> void:
	is_attacking = false
	is_taunting = false
	is_wandering = true
	
	# Make sure the skeleton is not idling
	_is_in_idle = false
	
	# Switch animation to walking immediately
	state_machine.travel(Idle_Anim)

# --------------------
# HP / Death Logic
# --------------------

func apply_damage(amount: float) -> void:
	current_hp -= amount
	print("Enemy hit! HP:", current_hp)

	if current_hp <= 0:
		_die()

func _die() -> void:
	print("Skeleton died!")

	# Disable further movement or actions
	is_wandering = false
	is_taunting = false
	is_attacking = false

	# Enable ragdoll or physics simulation here
	enable_ragdoll()

	# Optionally, play a death animation here
	state_machine.travel("Die_Anim")  # You can create a "Die_Anim" if you have one

# --------------------
# Ragdoll Enable/Disable
# --------------------

func enable_ragdoll() -> void:
	# Ensure ragdoll is enabled only upon death
	if ragdoll is PhysicalBoneSimulator3D:
		ragdoll.set_physics_process(true)  # Enable physics processing for ragdoll parts
		ragdoll.active = true  # Activate ragdoll simulator (this is necessary for it to work)
		ragdoll.visible = true  # Make ragdoll visible
	
	# Apply initial forces if necessary (e.g., gravity)
	for part in ragdoll.get_children():
		if part is PhysicalBone3D:
			part.linear_velocity = Vector3.ZERO  # Stop any prior velocity from affecting the bones
			part.angular_velocity = Vector3.ZERO  # Stop angular movement immediately

			# Optionally, apply a small impulse for natural motion (optional)
			# part.apply_impulse(Vector3.ZERO, Vector3(0, -5, 0))  # Example to gently move them down

func disable_ragdoll() -> void:
	# Disable ragdoll physics before activation on death
	if ragdoll != null and ragdoll is PhysicalBoneSimulator3D:
		ragdoll.set_physics_process(false)
		ragdoll.active = false  # Deactivate ragdoll simulator to stop physics processing
		ragdoll.visible = false  # Hide ragdoll
	else:
		print("Ragdoll node is not assigned or invalid!")
