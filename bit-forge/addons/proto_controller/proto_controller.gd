# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!

extends CharacterBody3D

class_name Player

signal sword_hit_landed(target: Node)

@export_group("Stats")
@export var max_hp: float = 1000.0
@export var max_armor: float = 50.0
@export var current_hp: float = 1000.0
var current_armor: float = 0

@export_group("Weapons")

# Weapon types
enum WeaponType { NONE, SWORD, BOW, MAGIC, MELEE }

# Weapon data
@export var sword_damage: float = 5.0
@export var sword_fire_rate: float = 0.5
@export var crossbow_damage: float = 2.5
@export var crossbow_fire_rate: float = 0.8
@export var crossbow_projectile_speed: float = 24.0
@export var crossbow_projectile_max_distance: float = 45.0
@export_flags_3d_physics var crossbow_projectile_collision_mask: int = 3
@export var crossbow_reload_animation: StringName = "1H_Ranged_Reload"
@export var crossbow_reload_fallback_duration: float = 0.7
@export var magic_damage: float = 4.0
@export var magic_fire_rate: float = 0.6
@export var magic_projectile_speed: float = 20.0
@export var magic_projectile_max_distance: float = 40.0
@export_flags_3d_physics var magic_projectile_collision_mask: int = 3

var equipped_weapon: WeaponType = WeaponType.SWORD
var weapon_damage: float = 5.0
var weapon_fire_rate: float = 0.5  # seconds between shots
var weapon_last_shot_time: float = 0.0
var is_crossbow_reloading: bool = false

@export_group("Dash")

@export var dash_duration := 0.18       # how long a dash lasts
@export var dash_cooldown := 1.0        # seconds before dash can be used again
@export var max_dash_charges := 3       # total dash charges

@export_group("Arrows")
@export var max_arrow_charges: int = 5
@export var arrow_recharge_cooldown: float = 1.0


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
@export var sprint_speed : float = 40.0
## How fast do we freefly?
@export var freefly_speed : float = 25.0
@export var damage_knockback_speed : float = 7.0
@export var damage_knockback_decay : float = 18.0

@export_group("Camera FX")
@export var camera_bob_moving_amount: float = 0.05
@export var camera_bob_idle_amount: float = 0.015
@export var camera_bob_moving_speed: float = 10.0
@export var camera_bob_idle_speed: float = 2.0
@export var damage_shake_duration: float = 0.15
@export var damage_shake_amount: float = 0.06
@export var camera_lean_max_degrees: float = 3.0
@export var camera_lean_response_speed: float = 8.0
@export var hit_flash_duration: float = 0.12
@export var hit_flash_max_alpha: float = 0.35
@export var hit_flash_color: Color = Color(1.0, 0.0, 0.0, 1.0)

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
## Name of Input Action to toggle between sword and crossbow.
@export var input_switch_weapon : String = "switch_weapon"

@export var input_crouch: String = "crouch"

@export_group("Mouse")
@export var capture_mouse_on_ready: bool = true
@export var enforce_weapon_visual_sync: bool = true

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false

var dash_time_left := 0.0
var is_dashing := false
var dash_direction := Vector3.ZERO
var dash_recharge_index := -1
var dash_charges: Array[float] = []
var arrow_recharge_index := -1
var arrow_charges: Array[float] = []
var combo_speed_multiplier: float = 1.0
var damage_knockback_velocity := Vector3.ZERO
var camera_bob_time: float = 0.0
var damage_shake_time_left: float = 0.0
var damage_shake_strength: float = 0.0
var hit_flash_time_left: float = 0.0
var camera_base_position: Vector3 = Vector3.ZERO
var camera_base_rotation: Vector3 = Vector3.ZERO
var camera_lean_current: float = 0.0

var is_crouching: bool = false
var normal_collider_height: float
var normal_camera_height: Vector3
var sword_model_default_transform: Transform3D
var crossbow_model_default_transform: Transform3D
var magic_model_default_transform: Transform3D


## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var camera_3d: Camera3D = $Head/Camera3D
@onready var collider: CollisionShape3D = $Collider
@onready var sprint_bar_root: CanvasLayer = $"Head/Camera3D/SprintUI"
@onready var arrow_bar_root: CanvasLayer = $"CanvasLayer"
@onready var weapon_anim: AnimationPlayer = $"AnimationPlayer"
@onready var health_bar: ProgressBar = $"Head/Camera3D/HealthUI/HpBar"
@onready var health_label: Label = $"Head/Camera3D/HealthUI/HpBar/HpLabel"
@onready var sword_model: Node3D = $"Rig/Skeleton3D/handslot_r/1H_Sword"
@onready var crossbow_model: Node3D = $"Rig/Skeleton3D/handslot_r/1H_Crossbow"
@onready var magic_model: Node3D = $"Rig/Skeleton3D/handslot_r/spellbook_open3"
@onready var sword_hitbox: Area3D = $"Rig/Skeleton3D/handslot_r/1H_Sword/Sword HitBox"
@onready var ranged_bow_template: Node3D = get_node_or_null("Head/rangedbow")
@onready var ranged_magic_template: Node3D = get_node_or_null("Head/rangedmagic")
@onready var interact:RayCast3D = $Head/Camera3D/RayCast3D

var focusedObject: Interactable
var hit_flash_rect: ColorRect = null

func _ready() -> void:
	add_to_group("player")
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	move_speed = base_speed * combo_speed_multiplier
	sword_hitbox.monitoring = true
	sword_hitbox.monitorable = true
	sword_hitbox.body_entered.connect(_on_sword_body_entered)
	if camera_3d:
		camera_base_position = camera_3d.position
		camera_base_rotation = camera_3d.rotation
	dash_charges = []
	for i in range(max_dash_charges):
		dash_charges.append(1.0)
	_configure_dash_bars()

	arrow_charges = []
	for i in range(max_arrow_charges):
		arrow_charges.append(1.0)
	_configure_arrow_bars()

	
	normal_collider_height = collider.shape.height
	normal_camera_height = head.position
	
	# Initialize stats
	current_hp = current_hp
	current_armor = current_armor
	_update_health_bar()
	if sword_model:
		sword_model_default_transform = sword_model.transform
	if crossbow_model:
		crossbow_model_default_transform = crossbow_model.transform
	if magic_model:
		magic_model_default_transform = magic_model.transform
	_apply_equipped_weapon_state()

	if weapon_anim:
		weapon_anim.animation_started.connect(_on_weapon_animation_changed)
		weapon_anim.animation_finished.connect(_on_weapon_animation_changed)
	call_deferred("_sync_equipped_weapon_visuals")
	_setup_hit_flash_overlay()

	if capture_mouse_on_ready:
		capture_mouse()

func _on_sword_body_entered(body: Node):
	var switch_target := _find_weapon_switch_target(body)
	if switch_target != null:
		_on_weapon_switch_hit(switch_target)
		return

	# Check if the body is an enemy and has an apply_damage function
	print("body: ", body)
	if body.has_method("apply_damage"):
		print("Hit enemy:", body.name)
		emit_signal("sword_hit_landed", body)
		body.apply_damage(weapon_damage, self)
	elif body.has_method("take_damage"):
		emit_signal("sword_hit_landed", body)
		body.take_damage(weapon_damage, self)
		
func _enable_sword_hitbox():
	if not sword_hitbox:
		print("Sword hitbox check: ", sword_hitbox)
		return
	sword_hitbox.monitoring = true
	# Check immediately for overlapping bodies
	print("Sword hitbox check: ", sword_hitbox)
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
		rotate_look(event.relative * 0.1)
	
		# ATTACK (left click)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_attack()

	if InputMap.has_action(input_switch_weapon) and Input.is_action_just_pressed(input_switch_weapon):
		toggle_weapon()
			
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()
func find_interactable_root(node: Node) -> Node:
	while node != null:
		if node.name == "chest_lid" and node.get_parent().name == "chest":
			return node.get_parent()  # return the chest root
		if node is Interactable:
			return node
		node = node.get_parent()
	return null
func find_interactable(node: Node) -> Interactable:
	while node != null:
		if node is Interactable:
			return node
		node = node.get_parent()
	return null

func _process(delta):
	if enforce_weapon_visual_sync:
		_sync_equipped_weapon_visuals()

	if equipped_weapon == WeaponType.MAGIC and mouse_captured and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_attack()

	_update_hit_flash_overlay(delta)

	_update_camera_effects(delta)

	if interact.is_colliding():
		var collider = interact.get_collider()
		var object = find_interactable(collider)

		if object != null:
			if focusedObject != object:
				if focusedObject != null:
					focusedObject.toggleOutline()

				focusedObject = object
				focusedObject.toggleOutline()
				Messenger.SHOW_INTERACT_MESSAGE.emit(focusedObject.getInteractMessage(self))
		else:
			_clear_focus()
	else:
		_clear_focus()

func _clear_focus():
	if focusedObject != null:
		focusedObject.toggleOutline()
		Messenger.CLEAR_INTERACT_MESSAGE.emit()
		focusedObject = null

		
func _physics_process(delta: float) -> void:
	_update_dash_recharge(delta)
	_update_arrow_recharge(delta)

	if is_dashing:
		dash_time_left -= delta
		if dash_time_left <= 0.0:
			is_dashing = false
	
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

	# Trigger dash on sprint input if at least one full charge is available.
	if can_sprint and Input.is_action_just_pressed(input_sprint) and not is_crouching:
		if _consume_dash_charge():
			is_dashing = true
			dash_time_left = dash_duration
			var dash_input := Input.get_vector(input_left, input_right, input_forward, input_back)
			dash_direction = (transform.basis * Vector3(dash_input.x, 0, dash_input.y)).normalized()
			if dash_direction == Vector3.ZERO:
				dash_direction = -transform.basis.z.normalized()

	# Apply desired movement to velocity
	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if is_dashing:
			var dash_speed := sprint_speed * combo_speed_multiplier
			velocity.x = dash_direction.x * dash_speed
			velocity.z = dash_direction.z * dash_speed
		elif move_dir:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
		velocity.y = 0

	if damage_knockback_velocity.length_squared() > 0.0001:
		velocity.x += damage_knockback_velocity.x
		velocity.z += damage_knockback_velocity.z
		damage_knockback_velocity = damage_knockback_velocity.move_toward(Vector3.ZERO, damage_knockback_decay * delta)
	else:
		damage_knockback_velocity = Vector3.ZERO
	
	# Use velocity to actually move
	move_and_slide()

	_update_dash_bars()
		
		# Handle crouch
	if can_crouch:
		if Input.is_action_pressed(input_crouch):
			if not is_crouching:
				is_crouching = true
				move_speed = crouch_speed
				is_dashing = false
				dash_time_left = 0.0
				collider.shape.height = crouch_height
				head.position = Vector3(head.position.x, normal_camera_height.y + crouch_camera_offset, head.position.z)

		else:
			if is_crouching:
				is_crouching = false
				move_speed = base_speed * combo_speed_multiplier
				collider.shape.height = normal_collider_height
				head.position = normal_camera_height


func set_combo_speed_multiplier(multiplier: float) -> void:
	combo_speed_multiplier = max(multiplier, 1.0)
	if is_crouching:
		move_speed = crouch_speed
	else:
		move_speed = base_speed * combo_speed_multiplier


func add_dash_charge(amount: int = 1) -> void:
	if amount <= 0 or dash_charges.is_empty():
		return

	for i in range(amount):
		var refill_index := _find_first_missing_dash_charge()
		if refill_index == -1:
			break

		dash_charges[refill_index] = 1.0
		if dash_recharge_index == refill_index:
			dash_recharge_index = -1

	_update_dash_bars()


func _find_first_missing_dash_charge() -> int:
	for i in range(dash_charges.size()):
		if dash_charges[i] < 1.0:
			return i
	return -1


func add_arrow_charge(amount: int = 1) -> void:
	if amount <= 0 or arrow_charges.is_empty():
		return

	for i in range(amount):
		var refill_index := _find_first_missing_arrow_charge()
		if refill_index == -1:
			break

		arrow_charges[refill_index] = 1.0
		if arrow_recharge_index == refill_index:
			arrow_recharge_index = -1

	_update_arrow_bars()


func _find_first_missing_arrow_charge() -> int:
	for i in range(arrow_charges.size()):
		if arrow_charges[i] < 1.0:
			return i
	return -1


func _configure_dash_bars() -> void:
	if not sprint_bar_root:
		return

	for bar in _get_dash_bars_in_ui_order():
		bar.min_value = 0.0
		bar.max_value = 100.0

	_update_dash_bars()


func _update_dash_bars() -> void:
	if not sprint_bar_root:
		return

	var bars := _get_dash_bars_in_ui_order()

	for i in range(bars.size()):
		if i < dash_charges.size():
			bars[i].value = clamp(dash_charges[i] * 100.0, 0.0, 100.0)


func _get_dash_bars_in_ui_order() -> Array[TextureProgressBar]:
	var bars: Array[TextureProgressBar] = []
	if not sprint_bar_root:
		return bars

	for child in sprint_bar_root.get_children():
		if child is TextureProgressBar and child.name.begins_with("TextureProgressBar"):
			bars.append(child)

	return bars


func _consume_dash_charge() -> bool:
	for i in range(dash_charges.size() - 1, -1, -1):
		if dash_charges[i] >= 1.0:
			# If a charge is currently recharging, cancel that progress.
			if dash_recharge_index >= 0 and dash_recharge_index < dash_charges.size() and dash_charges[dash_recharge_index] < 1.0:
				dash_charges[dash_recharge_index] = 0.0
			dash_recharge_index = -1

			dash_charges[i] = 0.0
			return true

	return false


func _update_dash_recharge(delta: float) -> void:
	if dash_charges.is_empty():
		return

	if dash_recharge_index == -1:
		dash_recharge_index = _find_next_recharge_index()

	if dash_recharge_index == -1:
		return

	if dash_cooldown <= 0.0:
		dash_charges[dash_recharge_index] = 1.0
		dash_recharge_index = -1
		return

	dash_charges[dash_recharge_index] = min(dash_charges[dash_recharge_index] + (delta / dash_cooldown), 1.0)
	if dash_charges[dash_recharge_index] >= 1.0:
		dash_recharge_index = -1


func _find_next_recharge_index() -> int:
	# Recharge one dash at a time, always starting from TextureProgressBar1.
	for i in range(dash_charges.size()):
		if dash_charges[i] < 1.0:
			return i
	return -1


func _configure_arrow_bars() -> void:
	if not arrow_bar_root:
		return

	for bar in _get_arrow_bars_in_ui_order():
		bar.min_value = 0.0
		bar.max_value = 100.0

	_update_arrow_bars()


func _update_arrow_bars() -> void:
	if not arrow_bar_root:
		return

	var bars := _get_arrow_bars_in_ui_order()

	for i in range(bars.size()):
		if i < arrow_charges.size():
			bars[i].value = clamp(arrow_charges[i] * 100.0, 0.0, 100.0)


func _get_arrow_bars_in_ui_order() -> Array[TextureProgressBar]:
	var bars: Array[TextureProgressBar] = []
	if not arrow_bar_root:
		return bars

	for child in arrow_bar_root.get_children():
		if child is TextureProgressBar and child.name.begins_with("TextureProgressBar"):
			bars.append(child)

	return bars


func _consume_arrow_charge() -> bool:
	for i in range(arrow_charges.size() - 1, -1, -1):
		if arrow_charges[i] >= 1.0:
			# If an arrow is currently recharging, cancel that progress.
			if arrow_recharge_index >= 0 and arrow_recharge_index < arrow_charges.size() and arrow_charges[arrow_recharge_index] < 1.0:
				arrow_charges[arrow_recharge_index] = 0.0
			arrow_recharge_index = -1

			arrow_charges[i] = 0.0
			_update_arrow_bars()
			return true

	return false


func _update_arrow_recharge(delta: float) -> void:
	if arrow_charges.is_empty():
		return

	if arrow_recharge_index == -1:
		arrow_recharge_index = _find_next_arrow_recharge_index()

	if arrow_recharge_index == -1:
		return

	if arrow_recharge_cooldown <= 0.0:
		arrow_charges[arrow_recharge_index] = 1.0
		arrow_recharge_index = -1
		_update_arrow_bars()
		return

	arrow_charges[arrow_recharge_index] = min(arrow_charges[arrow_recharge_index] + (delta / arrow_recharge_cooldown), 1.0)
	if arrow_charges[arrow_recharge_index] >= 1.0:
		arrow_recharge_index = -1

	_update_arrow_bars()


func _find_next_arrow_recharge_index() -> int:
	for i in range(arrow_charges.size()):
		if arrow_charges[i] < 1.0:
			return i
	return -1


func get_arrow_charges() -> Array[float]:
	return arrow_charges.duplicate()


# --------------------
# Health Functions
# --------------------
func apply_damage(amount: float, source: Node = null) -> void:
	var final_damage = max(amount - current_armor, 0)
	if final_damage > 0.0:
		_play_hurt_animation()
		_trigger_damage_camera_shake()
		_trigger_hit_flash()
		_apply_damage_knockback(source)
	current_hp = clamp(current_hp - final_damage, 0, max_hp)
	_update_health_bar()
	if current_hp <= 0:
		_die()

func take_damage(amount: float, source: Node = null) -> void:
	apply_damage(amount, source)

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


func _apply_damage_knockback(source: Node = null) -> void:
	var away_dir := Vector3.ZERO
	if source is Node3D:
		away_dir = global_position - source.global_position
	away_dir.y = 0.0
	if away_dir.length_squared() <= 0.0001:
		away_dir = transform.basis.z
	away_dir = away_dir.normalized()
	damage_knockback_velocity = away_dir * damage_knockback_speed


func _play_hurt_animation() -> void:
	if not weapon_anim:
		return

	if weapon_anim.has_animation("Hit_B"):
		weapon_anim.play("Hit_B")
	elif weapon_anim.has_animation("Hit_A"):
		weapon_anim.play("Hit_A")
	elif weapon_anim.has_animation("Block_Hit"):
		weapon_anim.play("Block_Hit")


func _trigger_damage_camera_shake() -> void:
	damage_shake_time_left = damage_shake_duration
	damage_shake_strength = damage_shake_amount


func _setup_hit_flash_overlay() -> void:
	if hit_flash_rect != null:
		return

	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 100
	add_child(flash_layer)

	hit_flash_rect = ColorRect.new()
	hit_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_flash_rect.visible = false
	flash_layer.add_child(hit_flash_rect)


func _trigger_hit_flash() -> void:
	hit_flash_time_left = max(hit_flash_duration, 0.01)
	if hit_flash_rect == null:
		_setup_hit_flash_overlay()


func _update_hit_flash_overlay(delta: float) -> void:
	if hit_flash_rect == null:
		return

	if hit_flash_time_left > 0.0:
		hit_flash_time_left = max(hit_flash_time_left - delta, 0.0)
		var fade: float = hit_flash_time_left / maxf(hit_flash_duration, 0.01)
		var flash: Color = hit_flash_color
		flash.a = clamp(hit_flash_max_alpha * fade, 0.0, 1.0)
		hit_flash_rect.color = flash
		hit_flash_rect.visible = true
	elif hit_flash_rect.visible:
		hit_flash_rect.visible = false


func _update_camera_effects(delta: float) -> void:
	if not camera_3d:
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var speed_reference := max(base_speed * combo_speed_multiplier, 0.001)
	var moving_factor := clamp(horizontal_speed / speed_reference, 0.0, 1.0)

	var bob_speed := lerp(camera_bob_idle_speed, camera_bob_moving_speed, moving_factor)
	var bob_amount := lerp(camera_bob_idle_amount, camera_bob_moving_amount, moving_factor)

	camera_bob_time += delta * bob_speed
	var bob_offset := Vector3(
		cos(camera_bob_time * 0.5) * bob_amount * 0.35,
		sin(camera_bob_time) * bob_amount,
		0.0
	)

	var shake_offset := Vector3.ZERO
	if damage_shake_time_left > 0.0:
		damage_shake_time_left = max(damage_shake_time_left - delta, 0.0)
		var tm := damage_shake_time_left / maxf(damage_shake_duration, 0.001)
		var strength := damage_shake_strength * tm
		shake_offset = Vector3(
			randf_range(-strength, strength),
			randf_range(-strength, strength),
			randf_range(-strength, strength) * 0.4
		)

	var local_horizontal_velocity := transform.basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	var lateral_speed := local_horizontal_velocity.x
	var lateral_ratio := clamp(lateral_speed / max(move_speed, 0.001), -1.0, 1.0)
	var lean_target := deg_to_rad(-float(camera_lean_max_degrees)) * float(lateral_ratio)
	camera_lean_current = lerp(camera_lean_current, lean_target, clamp(delta * camera_lean_response_speed, 0.0, 1.0))

	camera_3d.position = camera_base_position + bob_offset + shake_offset
	camera_3d.rotation = Vector3(camera_base_rotation.x, camera_base_rotation.y, camera_base_rotation.z + camera_lean_current)


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

func can_attack() -> bool:
	if equipped_weapon == WeaponType.BOW and is_crossbow_reloading:
		return false
	return Time.get_ticks_msec() / 1000.0 - weapon_last_shot_time >= weapon_fire_rate
	
func _try_attack() -> void:
	if not can_attack():
		return

	if equipped_weapon == WeaponType.BOW:
		if not _consume_arrow_charge():
			return

		weapon_last_shot_time = Time.get_ticks_msec() / 1000.0
		print("Player fired crossbow")
		_play_crossbow_attack_animation()
		_fire_crossbow_projectile()
		_start_crossbow_reload()
		return

	if equipped_weapon == WeaponType.MAGIC:
		weapon_last_shot_time = Time.get_ticks_msec() / 1000.0
		print("Player cast magic")
		_play_magic_attack_animation()
		_fire_magic_projectile()
		return

	weapon_last_shot_time = Time.get_ticks_msec() / 1000.0

	print("Player Swung Sword")
	_play_sword_attack_animation()

	# Enable hitbox briefly
	_enable_sword_hitbox()
	await get_tree().create_timer(0.18).timeout  # hit window duration
	_disable_sword_hitbox()

	# Optional: apply damage here later (raycast / melee hitbox)


func equip_sword() -> void:
	equipped_weapon = WeaponType.SWORD
	_apply_equipped_weapon_state()
	_on_weapon_switched()


func equip_crossbow() -> void:
	equipped_weapon = WeaponType.BOW
	_apply_equipped_weapon_state()
	_on_weapon_switched()


func toggle_weapon() -> void:
	if equipped_weapon == WeaponType.SWORD:
		equip_crossbow()
	elif equipped_weapon == WeaponType.BOW:
		equip_magic()
	else:
		equip_sword()


func _play_sword_attack_animation() -> void:
	if not weapon_anim:
		return

	weapon_anim.stop()
	if weapon_anim.has_animation("1H_Melee_Attack_Slice_Horizontal"):
		weapon_anim.play("1H_Melee_Attack_Slice_Horizontal")


func _play_crossbow_attack_animation() -> void:
	if not weapon_anim:
		return

	weapon_anim.stop()
	if weapon_anim.has_animation("1H_Ranged_Shoot"):
		weapon_anim.play("1H_Ranged_Shoot")
	elif weapon_anim.has_animation("1H_Ranged_Shooting"):
		weapon_anim.play("1H_Ranged_Shooting")


func _play_magic_attack_animation() -> void:
	if not weapon_anim:
		return

	weapon_anim.stop()
	if weapon_anim.has_animation("Spellcast_Shoot"):
		weapon_anim.play("Spellcast_Shoot")
	elif weapon_anim.has_animation("1H_Ranged_Shoot"):
		weapon_anim.play("1H_Ranged_Shoot")


func _start_crossbow_reload() -> void:
	if is_crossbow_reloading:
		return

	is_crossbow_reloading = true
	var reload_duration := max(crossbow_reload_fallback_duration, 0.01)

	if weapon_anim and weapon_anim.has_animation(crossbow_reload_animation):
		weapon_anim.play(crossbow_reload_animation)
		var reload_anim := weapon_anim.get_animation(crossbow_reload_animation)
		if reload_anim:
			reload_duration = max(reload_anim.length, 0.01)

	await get_tree().create_timer(reload_duration).timeout
	is_crossbow_reloading = false


func _fire_crossbow_projectile() -> void:
	if ranged_bow_template == null:
		push_warning("Missing ranged projectile template at Head/rangedbow.")
		return
	_spawn_projectile_from_template(ranged_bow_template, crossbow_damage, crossbow_projectile_speed, crossbow_projectile_max_distance, crossbow_projectile_collision_mask)


func _fire_magic_projectile() -> void:
	if ranged_magic_template == null:
		push_warning("Missing magic projectile template at Head/rangedmagic.")
		return

	_spawn_projectile_from_template(ranged_magic_template, magic_damage, magic_projectile_speed, magic_projectile_max_distance, magic_projectile_collision_mask)


func _spawn_projectile_from_template(template_node: Node3D, projectile_damage: float, projectile_speed: float, projectile_max_distance: float, projectile_collision_mask: int) -> void:
	var projectile_instance: Node = template_node.duplicate()
	if projectile_instance == null:
		return
	if projectile_instance is not Node3D:
		projectile_instance.queue_free()
		return

	var projectile_node := projectile_instance as Node3D
	projectile_node.visible = true
	projectile_node.global_transform = template_node.global_transform

	var spawn_parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	spawn_parent.add_child(projectile_node)

	if projectile_node.has_method("set"):
		projectile_node.set("collision_mask", projectile_collision_mask)

	var launch_dir := -camera_3d.global_basis.z
	if interact != null and interact.is_colliding():
		launch_dir = interact.get_collision_point() - projectile_node.global_position
	if launch_dir.length_squared() < 0.0001:
		launch_dir = -camera_3d.global_basis.z
	launch_dir = launch_dir.normalized()

	if projectile_node.has_method("launch"):
		projectile_node.call("launch", launch_dir, projectile_damage, self, projectile_speed, projectile_max_distance)


func _find_weapon_switch_target(node: Node) -> Node:
	var current := node
	while current != null:
		if current.is_in_group("weapon_switch"):
			return current
		current = current.get_parent()
	return null


func _on_weapon_switch_hit(switch_target: Node) -> void:
	equip_crossbow()

	if switch_target.has_method("on_player_weapon_hit"):
		switch_target.call("on_player_weapon_hit", self)
	elif switch_target.has_method("activate_switch"):
		switch_target.call("activate_switch", self)


func _apply_equipped_weapon_state() -> void:
	if equipped_weapon == WeaponType.BOW:
		weapon_damage = crossbow_damage
		weapon_fire_rate = crossbow_fire_rate
	elif equipped_weapon == WeaponType.MAGIC:
		weapon_damage = magic_damage
		weapon_fire_rate = magic_fire_rate
	else:
		# Default NONE/MELEE to sword visuals for now.
		equipped_weapon = WeaponType.SWORD
		weapon_damage = sword_damage
		weapon_fire_rate = sword_fire_rate

	_sync_equipped_weapon_visuals()
	_disable_sword_hitbox()


func equip_magic() -> void:
	equipped_weapon = WeaponType.MAGIC
	_apply_equipped_weapon_state()
	_on_weapon_switched()


func _sync_equipped_weapon_visuals() -> void:
	if sword_model:
		sword_model.visible = equipped_weapon == WeaponType.SWORD
		sword_model.transform = sword_model_default_transform
	if crossbow_model:
		crossbow_model.visible = equipped_weapon == WeaponType.BOW
		crossbow_model.transform = crossbow_model_default_transform
	if magic_model:
		magic_model.visible = equipped_weapon == WeaponType.MAGIC
		magic_model.transform = magic_model_default_transform


func _on_weapon_animation_changed(_anim_name: StringName) -> void:
	# Some animations key visibility tracks; force equipped visuals right after changes.
	call_deferred("_sync_equipped_weapon_visuals")


func _on_weapon_switched() -> void:
	if weapon_anim:
		# Stop whatever attack animation was active so old pose doesn't persist.
		weapon_anim.stop()
		_play_post_switch_idle_pose()

	# Enforce visuals at end-of-frame after AnimationPlayer updates.
	call_deferred("_sync_equipped_weapon_visuals")


func _play_post_switch_idle_pose() -> void:
	if not weapon_anim:
		return

	if equipped_weapon == WeaponType.BOW and weapon_anim.has_animation("1H_Ranged_Shoot"):
		weapon_anim.play("1H_Ranged_Shoot")
		weapon_anim.advance(0.0)
		return

	if equipped_weapon == WeaponType.MAGIC and weapon_anim.has_animation("Spellcast_Shoot"):
		weapon_anim.play("Spellcast_Shoot")
		weapon_anim.advance(0.0)
		return

	if equipped_weapon == WeaponType.SWORD and weapon_anim.has_animation("1H_Melee_Idle"):
		weapon_anim.play("1H_Melee_Idle")
		weapon_anim.advance(0.0)
		return

	if weapon_anim.has_animation("Idle"):
		weapon_anim.play("Idle")
		weapon_anim.advance(0.0)


func is_magic_equipped() -> bool:
	return equipped_weapon == WeaponType.MAGIC
	

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
