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
@export var Walk_Anim: String = "Walking_A"
@export var Run_Anim: String = "Running_C"
@export var Taunt_Anim: String = "Taunt"
@export var Attack_Anim: String = "Unarmed_Melee_Attack_Punch_A"
@export var Hit_Anim: String = "Hit_B"
@export var Death_Anim: String = "Death_C_Skeletons"
@export var damage_amount: float = 5.0
@export var attack_range: float = 2.0
@export var attack_anim_duration: float = 0.9
@export var attack_hit_time: float = 0.45

@export var idle_time_range: Vector2 = Vector2(2.5, 9.5)

# --------------------
# Node References
# --------------------
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player : AnimationPlayer = $"AnimationPlayer"
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
var _orig_collision_layer: int = 1
var _orig_collision_mask: int = 1

# --------------------
# Lifecycle
# --------------------

var current_hp: float = max_hp

func _ready() -> void:
	animation_tree.active = false
	_orig_collision_layer = collision_layer
	_orig_collision_mask = collision_mask

	# Save original collision layers so we can restore after ragdoll
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

	# Wait until the attack's hit frame, then try to deal damage
	await get_tree().create_timer(attack_hit_time).timeout
	_try_deal_damage()

	# Wait the remainder of the attack animation before allowing other actions
	var remaining: float = max(0.0, attack_anim_duration - attack_hit_time)
	await get_tree().create_timer(remaining).timeout
	is_attacking = false
	
func _try_deal_damage() -> void:
	var target = player_finder.player
	print("target: ", target)
	if target == null:
		print("test")
		return

	# Compare horizontal distance only
	var self_pos = Vector3(global_position.x, 0.0, global_position.z)
	var target_pos = Vector3(target.global_position.x, 0.0, target.global_position.z)
	var dist = self_pos.distance_to(target_pos)

	if dist <= attack_range:
		if target.has_method("apply_damage"):
			target.apply_damage(damage_amount)
			print("Skeleton attacked for: ", damage_amount)
		elif target.has_method("take_damage"):
			target.take_damage(damage_amount)
			print("Sk")
		else:
			print("Skeleton attack: target has no damage method")
func _return_to_roaming() -> void:
	is_attacking = false
	is_taunting = false
	is_wandering = true
	
	# Make sure the skeleton is not idling
	_is_in_idle = false
	
	# Switch animation to walking immediately
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
	print("Skeleton died!")

	# Stop all behavior
	is_wandering = false
	is_taunting = false
	is_attacking = false
	velocity = Vector3.ZERO

	# Play death animation first
	if animation_tree and state_machine:
		animation_player.stop()
		animation_player.play("Death_C_Skeletons")
		await get_tree().create_timer(1.0).timeout  # Wait for animation to start
		print("Played death animation")

	# Activate ragdoll after animation
	print("Attempting ragdoll")
	enable_ragdoll()
	print("Finished Attempting ragdoll")
	
	set_physics_process(false)
	set_process(false)
# --------------------
# Ragdoll Enable/Disable
# --------------------

func enable_ragdoll() -> void:
	# Stop animations and disable character movement
	if animation_tree:
		animation_tree.active = false

	collision_layer = 2
	collision_mask = 1


	if ragdoll == null:
		print("Ragdoll node is missing!")
		return

	var simulator: PhysicalBoneSimulator3D = null
	if ragdoll is PhysicalBoneSimulator3D:
		simulator = ragdoll
		print("TTTTTT")
	else:
		simulator = ragdoll.get_node_or_null("PhysicalBoneSimulator3D")

	if simulator != null:
		# Activate the simulator first
		simulator.active = true
		simulator.visible = true
		simulator.set_physics_process(true)

		# Apply current velocity to bones for a natural fall
		await get_tree().process_frame  # Wait a physics frame to ensure bones are ready
		for part in simulator.get_children():
			if part is PhysicalBone3D:
				part.linear_velocity = velocity
				part.angular_velocity = Vector3.ZERO
	else:
		# If no simulator, enable physical bones directly
		for part in ragdoll.get_children():
			if part is PhysicalBone3D:
				part.linear_velocity = velocity
				part.angular_velocity = Vector3.ZERO

func disable_ragdoll() -> void:
	# Turn off ragdoll physics
	if ragdoll == null:
		print("Ragdoll node is missing!")
		return

	var simulator: PhysicalBoneSimulator3D = null
	if ragdoll is PhysicalBoneSimulator3D:
		simulator = ragdoll
	else:
		simulator = ragdoll.get_node_or_null("PhysicalBoneSimulator3D")

	if simulator != null:
		simulator.active = false
		simulator.visible = false
		simulator.set_physics_process(false)
	else:
		for part in ragdoll.get_children():
			if part is PhysicalBone3D:
				part.linear_velocity = Vector3.ZERO
				part.angular_velocity = Vector3.ZERO

	# Restore animation and collision for reuse
	if animation_tree:
		animation_tree.active = true
	collision_layer = _orig_collision_layer
	collision_mask = _orig_collision_mask
	set_physics_process(true)
	set_process(true)
