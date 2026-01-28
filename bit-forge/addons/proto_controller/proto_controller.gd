# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!

extends CharacterBody3D

@export_group("Stats")
@export var max_hp: float = 100.0
@export var max_armor: float = 50.0
@export var current_hp: float = 20
var current_armor: float = 0

@export_group("Weapons")

# Weapon types
enum WeaponType { NONE, SWORD, BOW, MELEE }

# Weapon data
var equipped_weapon: WeaponType = WeaponType.NONE
var weapon_damage: float = 10.0
var weapon_fire_rate: float = 0.5  # seconds between shots
var weapon_last_shot_time: float = 0.0

@export_group("Sprint Stamina")

@export var max_sprint_time := 2.0          # seconds of sprint

@export var sprint_recharge_rate := 1.2     # seconds per second

@export var sprint_recharge_delay := 1.0    # delay before recharge starts

@export var sprint_tap_cost := 0.2  # Amount of sprint time consumed per click	


@export_group("Crouch")

@export var can_crouch: bool = true

@export var crouch_speed: float = 2.5        # speed while crouched

@export var crouch_height: float = 1.0       # new collider height

@export var crouch_camera_offset: float = -0.5  # move camera down

## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = false
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.005
## Normal speed.
@export var base_speed : float = 5.0
## Speed of jump.
@export var jump_velocity : float = 5.5
## How fast do we run?
@export var sprint_speed : float = 20.0
## How fast do we freefly?
@export var freefly_speed : float = 25.0

@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "ui_left"
## Name of Input Action to move Right.
@export var input_right : String = "ui_right"
## Name of Input Action to move Forward.
@export var input_forward : String = "ui_up"
## Name of Input Action to move Backward.
@export var input_back : String = "ui_down"
## Name of Input Action to Jump.
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"

@export var input_crouch: String = "crouch"

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false

var sprint_time := max_sprint_time
var sprint_recharge_timer := 0.0
var is_sprinting := false
var sprint_exhausted := false

var is_crouching: bool = false
var normal_collider_height: float
var normal_camera_height: Vector3

## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
@onready var sprint_bar: ProgressBar = $"Head/Camera3D/SprintUI/SprintBar"
@onready var weapon_anim: AnimationPlayer = $"AnimationPlayer"
@onready var health_bar: ProgressBar = $"Head/Camera3D/HealthUI/HpBar"
@onready var health_label: Label = $"Head/Camera3D/HealthUI/HpBar/HpLabel"
@onready var sword_hitbox: Area3D = $"Rig/Skeleton3D/handslot_r/1H_Sword/Sword HitBox"



func _ready() -> void:
	add_to_group("player")
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	sprint_time = max_sprint_time
	sword_hitbox.monitoring = false
	sword_hitbox.monitorable = true
	sword_hitbox.body_entered.connect(_on_sword_body_entered)

	
	normal_collider_height = collider.shape.height
	normal_camera_height = head.position
	
	# Initialize stats
	current_hp = current_hp
	current_armor = current_armor
	_update_health_bar()

func _on_sword_body_entered(body: Node):
	# Check if the body is an enemy and has an apply_damage function
	if body.has_method("apply_damage"):
		print("Hit enemy:", body.name)
		body.apply_damage(weapon_damage)
		
func _enable_sword_hitbox():
	if not sword_hitbox:
		return
	sword_hitbox.monitoring = true
	# Check immediately for overlapping bodies
	for body in sword_hitbox.get_overlapping_bodies():
		print("Hit:", body.name)
		if body.has_method("apply_damage"):
			body.apply_damage(weapon_damage)

func _disable_sword_hitbox():
	if not sword_hitbox:
		return
	sword_hitbox.monitoring = false

func _unhandled_input(event: InputEvent) -> void:
	# Mouse capturing
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	# Look around
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)
	
		# ATTACK (left click)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_attack()
			
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

func _physics_process(delta: float) -> void:
	# If freeflying, handle freefly and nothing else
	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
	
	# Apply gravity to velocity
	if has_gravity:
		if not is_on_floor():
			velocity += get_gravity() * delta

	# Apply jumping
	if can_jump:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity

	# Modify speed based on sprinting
	if can_sprint and Input.is_action_pressed(input_sprint) and sprint_recharged() and not is_crouching:
		
		if not sprint_exhausted:
			# Start sprinting
			is_sprinting = true
			move_speed = sprint_speed
			sprint_time -= delta
			sprint_time = max(sprint_time, 0.0)
				
		if sprint_time <= 0.0:
			sprint_exhausted = true
			is_sprinting = false
			move_speed = base_speed
			sprint_recharge_timer = sprint_recharge_delay
			
	else:
		is_sprinting = false
		move_speed = base_speed
	# Recharge sprint
	if not is_sprinting:
		if sprint_recharge_timer > 0.0:
			sprint_recharge_timer -= delta
		else:
			if sprint_exhausted or sprint_time < max_sprint_time:
				sprint_time += sprint_recharge_rate * delta
				sprint_time = min(sprint_time, max_sprint_time)
			# Reset exhaustion once fully recharged
				if sprint_exhausted and sprint_time >= max_sprint_time:
					sprint_exhausted = false

	# Apply desired movement to velocity
	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if move_dir:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
		velocity.y = 0
	
	# Use velocity to actually move
	move_and_slide()

	if sprint_bar:
		sprint_bar.value = (sprint_time / max_sprint_time) * 100.0
		
		# Handle crouch
	if can_crouch:
		if Input.is_action_pressed(input_crouch):
			if not is_crouching:
				is_crouching = true
				move_speed = crouch_speed
				is_sprinting = false  # stop sprinting
				collider.shape.height = crouch_height
				head.position = Vector3(head.position.x, normal_camera_height.y + crouch_camera_offset, head.position.z)

		else:
			if is_crouching:
				is_crouching = false
				move_speed = base_speed
				collider.shape.height = normal_collider_height
				head.position = normal_camera_height


# --------------------
# Health Functions
# --------------------
func apply_damage(amount: float) -> void:
	var final_damage = max(amount - current_armor, 0)
	current_hp = clamp(current_hp - final_damage, 0, max_hp)
	_update_health_bar()
	if current_hp <= 0:
		_die()

func heal(amount: float) -> void:
	current_hp = clamp(current_hp + amount, 0, max_hp)
	_update_health_bar()

func _update_health_bar() -> void:
	if health_bar:
		# Update the bar
		health_bar.value = current_hp
	if health_label:
		# Show as "current_hp / max_hp"
		health_label.text = str(current_hp) + " / " + str(max_hp)


func _die() -> void:
	print("Player has died!")
	# Optional: Reset player, respawn, or show game over screen
	# Example:
	# get_tree().reload_current_scene()
	# or queue_free()


## Rotate us to look around.
## Base of controller rotates around y (left/right). Head rotates around x (up/down).
## Modifies look_rotation based on rot_input, then resets basis and rotates by look_rotation.
func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)


func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false


func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true
			
			
func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

func sprint_recharged() -> bool:
	# If exhausted, must fully recharge
	if sprint_exhausted:
		return sprint_time >= max_sprint_time
	return sprint_recharge_timer <= 0.0

func can_attack() -> bool:
	return Time.get_ticks_msec() / 1000.0 - weapon_last_shot_time >= weapon_fire_rate
	
func _try_attack() -> void:
	if not can_attack():
		return

	weapon_last_shot_time = Time.get_ticks_msec() / 1000.0
	print("Player Swung Sword")
	
	if weapon_anim:
		weapon_anim.stop()
		weapon_anim.play("1H_Melee_Attack_Slice_Horizontal")

	# Enable hitbox briefly
	_enable_sword_hitbox()
	await get_tree().create_timer(0.1).timeout  # hit window duration
	_disable_sword_hitbox()

	# Optional: apply damage here later (raycast / melee hitbox)
	

## Checks if some Input Actions haven't been created.
## Disables functionality accordingly.
func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false
