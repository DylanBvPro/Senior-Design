class_name SimpleEnemy
extends "res://assets/scripts/enemies/basic_enemy.gd"

signal killed_by_player(enemy: Node)

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var state_chart: StateChart = $StateChart
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var enemy_info: EnemyInfo = $EnemyInfo
@onready var progress_bar: ProgressBar = $SubViewport/ProgressBar
@onready var ranged_template: Node3D = get_node_or_null("ranged")

@export_range(1.0, 500.0, 1.0) var activation_distance_meters: float = 50.0
@export_range(-1.0, 500.0, 1.0) var deactivation_distance_meters: float = -1.0
@export_range(1.0, 500.0, 1.0) var max_follow_navigation_distance_meters: float = 40.0
@export var navigation_path_check_interval: float = 0.5
@export var activity_check_interval: float = 0.2
@export var player_hit_iframe_duration: float = 0.12

var target: CharacterBody3D
var player_in_detection: bool = false
var time_since_last_attack: float = 0.0
var damage_applied_this_attack: bool = false
var current_health: float = 0.0
var is_dead: bool = false
var stun_time_remaining: float = 0.0
var knockback_velocity: Vector3 = Vector3.ZERO
var invulnerability_time_remaining: float = 0.0
var current_attack_animation: StringName = StringName("")
var is_ranged_backpedaling: bool = false
var last_nav_update_time: float = 0.0
var cached_attack_range: float = 0.0
var last_health_bar_update: float = 0.0
var runtime_active: bool = true
var activity_check_elapsed: float = 0.0
var navigation_path_check_elapsed: float = 0.0
var _was_stunned_last_frame: bool = false
var _hit_reaction_serial: int = 0

const ATTACK_HIT_TIME_RATIO: float = 0.30
const NAV_UPDATE_INTERVAL: float = 0.1  # Update pathfinding every 0.1 seconds instead of every frame
const HEALTH_BAR_UPDATE_INTERVAL: float = 0.05  # Only update health bar every 0.05 seconds

func _ready() -> void:
	super._ready()
	add_to_group("enemy")
	current_health = enemy_info.max_health
	_update_health_bar()
	_disable_hand_attachment_physics()
	
	target = get_tree().get_first_node_in_group("player")
	#print("target", target)
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	nav_agent.avoidance_enabled = false
	
	if animation_player:
		animation_player.play(enemy_info.idle_animation)

	set_process(true)
	_set_runtime_active(true)
	_update_runtime_activity(true)


func _process(delta: float) -> void:
	if is_dead:
		return
	activity_check_elapsed += delta
	if activity_check_elapsed < activity_check_interval:
		return
	_update_runtime_activity(false)


func _update_runtime_activity(force: bool) -> void:
	activity_check_elapsed = 0.0
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if target == null:
		_set_runtime_active(false)
		return

	var dist_sq: float = (target.global_position - global_position).length_squared()
	var activation_dist_sq: float = activation_distance_meters * activation_distance_meters
	var deactivate_dist: float = deactivation_distance_meters if deactivation_distance_meters > 0.0 else activation_distance_meters
	var deactivation_dist_sq: float = deactivate_dist * deactivate_dist

	var should_be_active: bool = runtime_active
	if runtime_active:
		# Enemy must de-render again when player leaves the deactivation range.
		should_be_active = dist_sq <= deactivation_dist_sq
	else:
		# Enemy reactivates only when player is back inside activation range.
		should_be_active = dist_sq <= activation_dist_sq

	if force or should_be_active != runtime_active:
		_set_runtime_active(should_be_active)


func _set_runtime_active(active: bool) -> void:
	runtime_active = active
	visible = active or is_dead
	set_physics_process(active or is_dead)
	if not active and not is_dead:
		nav_agent.velocity = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0
		if has_node("DetectionArea"):
			$DetectionArea.monitoring = false
		return

	if has_node("DetectionArea") and not is_dead:
		$DetectionArea.monitoring = true


func _disable_hand_attachment_physics(use_left: bool = true, use_right: bool = true) -> void:
	var hand_paths: Array[NodePath] = []
	
	if use_right:
		hand_paths.append(NodePath("Rig/Skeleton3D/RightHand"))
	if use_left:
		hand_paths.append(NodePath("Rig/Skeleton3D/LeftHand"))

	for hand_path in hand_paths:
		var hand_node := get_node_or_null(hand_path)
		if hand_node == null:
			continue
		
		for node in hand_node.get_children():
			_disable_physics_on_subtree(node)

func _disable_physics_on_subtree(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is CollisionShape3D:
		node.disabled = true
	if node is PhysicsBody3D:
		node.set("freeze", true)
	for child in node.get_children():
		_disable_physics_on_subtree(child)
	
func _physics_process(delta: float) -> void:
	if not runtime_active:
		return
	if is_dead:
		return
	if invulnerability_time_remaining > 0.0:
		invulnerability_time_remaining = max(invulnerability_time_remaining - delta, 0.0)
	if stun_time_remaining > 0.0:
		stun_time_remaining = max(stun_time_remaining - delta, 0.0)
		nav_agent.velocity = Vector3.ZERO
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, enemy_info.hit_knockback_damping * delta)
	elif _was_stunned_last_frame:
		_on_stun_ended()
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	time_since_last_attack += delta
	last_health_bar_update += delta
	move_and_slide()
	_was_stunned_last_frame = stun_time_remaining > 0.0
	
func on_triggered() -> void:
	if is_dead:
		return
	state_chart.send_event("toFollow")


func _on_idle_state_entered() -> void:
	if not runtime_active:
		return
	if is_dead:
		return
	if stun_time_remaining > 0.0:
		return
	is_ranged_backpedaling = false
	if animation_player:
		animation_player.play(enemy_info.idle_animation)


func _on_follow_state_entered() -> void:
	if not runtime_active:
		return
	if is_dead:
		return
	if stun_time_remaining > 0.0:
		return
	is_ranged_backpedaling = false
	if animation_player:
		var anim = animation_player.get_animation(enemy_info.follow_animation)
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
		animation_player.play(enemy_info.follow_animation)
	
func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	_set_runtime_active(true)
	is_ranged_backpedaling = false
	player_in_detection = false
	nav_agent.velocity = Vector3.ZERO
	velocity = Vector3.ZERO

	if has_node("DetectionArea"):
		$DetectionArea.monitoring = false
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true

	if animation_player:
		if animation_player.has_animation(enemy_info.death_animation):
			animation_player.play(enemy_info.death_animation)
		else:
			animation_player.stop()

	_run_death_despawn_sequence()


func _run_death_despawn_sequence() -> void:
	await get_tree().create_timer(enemy_info.despawn_delay).timeout
	if not is_inside_tree():
		return

	var tween := create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - enemy_info.sink_distance, enemy_info.sink_duration)
	await tween.finished
	queue_free()


func take_damage(amount: float, source: Node = null) -> void:
	if not runtime_active:
		return
	if is_dead:
		return
	if invulnerability_time_remaining > 0.0:
		return
	if amount <= 0.0:
		return

	var mitigated_damage: float = max(amount - enemy_info.armor, 0.0)
	if mitigated_damage <= 0.0:
		if source != null and source.is_in_group("player") and not _is_magic_source(source):
			_apply_hit_reaction()
		return

	current_health = max(current_health - mitigated_damage, 0.0)
	var iframe_duration := enemy_info.hit_iframe_duration
	if source != null and source.is_in_group("player") and player_hit_iframe_duration >= 0.0:
		iframe_duration = min(iframe_duration, player_hit_iframe_duration)
	invulnerability_time_remaining = iframe_duration
	_update_health_bar()
	if current_health <= 0.0:
		if source and source.is_in_group("player"):
			emit_signal("killed_by_player", self)
		_on_died()
		return

	if not _is_magic_source(source):
		_apply_hit_reaction()


func apply_damage(amount: float, source: Node = null) -> void:
	take_damage(amount, source)


func _is_magic_source(source: Node) -> bool:
	if source == null:
		return false
	if not source.is_in_group("player"):
		return false
	if source.has_method("is_magic_equipped"):
		return bool(source.call("is_magic_equipped"))
	return false
	
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not runtime_active:
		return
	if is_dead:
		return
	if is_ranged_backpedaling:
		return
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z

func _on_follow_state_physics_processing(delta: float) -> void:
	if not runtime_active:
		return
	if is_dead:
		return
	if stun_time_remaining > 0.0:
		return
	if not target:
		return
	
	# Check if close enough to attack and player is in detection area
	var distance_to_target = global_position.distance_to(target.global_position)
	var attack_range := _get_current_attack_range()
	if distance_to_target < attack_range and player_in_detection and time_since_last_attack >= enemy_info.attack_cooldown:
		state_chart.send_event("toAttack")
		return
	
	# Throttle navigation updates to reduce CPU load
	last_nav_update_time += delta
	navigation_path_check_elapsed += delta
	if last_nav_update_time >= NAV_UPDATE_INTERVAL:
		last_nav_update_time = 0.0
		nav_agent.target_position = target.global_position

		# Cheap first gate: if straight-line distance already exceeds follow range, stop.
		if distance_to_target > max_follow_navigation_distance_meters:
			nav_agent.velocity = Vector3.ZERO
			velocity.x = 0.0
			velocity.z = 0.0
			state_chart.send_event("toIdle")
			return

		# Expensive full-path distance check runs less frequently.
		if navigation_path_check_elapsed >= navigation_path_check_interval:
			navigation_path_check_elapsed = 0.0
			if _calculate_navigation_path_distance() > max_follow_navigation_distance_meters:
				nav_agent.velocity = Vector3.ZERO
				velocity.x = 0.0
				velocity.z = 0.0
				state_chart.send_event("toIdle")
				return
	
	if nav_agent.is_navigation_finished():
		nav_agent.velocity = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	
	# Apply velocity
	if direction.length() > 0.01:
		nav_agent.velocity = direction * enemy_info.follow_speed
		# When avoidance is disabled, velocity_computed may not drive movement.
		# Apply direct movement as a fallback to prevent run-in-place behavior.
		if not nav_agent.avoidance_enabled:
			velocity.x = nav_agent.velocity.x
			velocity.z = nav_agent.velocity.z
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 5.0 * delta)
	else:
		nav_agent.velocity = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0

func _on_attack_state_entered() -> void:
	if not runtime_active:
		return
	if is_dead:
		return
	if stun_time_remaining > 0.0:
		return
	is_ranged_backpedaling = enemy_info.attack_type == EnemyInfo.AttackType.RANGED
	# Stop all movement immediately
	nav_agent.velocity = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	
	current_attack_animation = _choose_attack_animation()
	if animation_player and current_attack_animation != StringName("") and enemy_info.attack_type == EnemyInfo.AttackType.MELEE:
		animation_player.play(current_attack_animation)
	time_since_last_attack = 0.0
	damage_applied_this_attack = false

	if enemy_info.attack_type == EnemyInfo.AttackType.RANGED:
		_enter_ranged_attack_placeholder()


func apply_attack_damage() -> void:
	# Call this method from an animation callback at the desired frame
	if not runtime_active:
		return
	if is_dead:
		return
	damage_applied_this_attack = true
	if target and target.is_in_group("player"):
		if target.has_method("take_damage"):
			target.take_damage(enemy_info.attack_damage, self)


func _on_attack_state_physics_processing(delta: float) -> void:
	if not runtime_active:
		return
	if is_dead:
		return
	if stun_time_remaining > 0.0:
		return
	# Keep movement stopped during attack
	nav_agent.velocity = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	
	# Check if player moved too far away - cancel attack if so
	if target:
		var distance_to_target = global_position.distance_to(target.global_position)
		if distance_to_target > _get_current_attack_range() + 1.5:
			state_chart.send_event("toFollow")
			return

	if enemy_info.attack_type == EnemyInfo.AttackType.RANGED:
		_update_ranged_attack_placeholder(delta)
		if time_since_last_attack < enemy_info.attack_cooldown:
			return
		if not target or not player_in_detection:
			state_chart.send_event("toIdle")
			return
		var ranged_distance_to_target := global_position.distance_to(target.global_position)
		if ranged_distance_to_target > _get_current_attack_range() + 1.0:
			state_chart.send_event("toFollow")
		else:
			state_chart.send_event("toAttack")
		return

	is_ranged_backpedaling = false
	
	# Skip animation checks if not playing to save performance
	if not animation_player.is_playing():
		if not target or not player_in_detection:
			state_chart.send_event("toIdle")
			return
		
		var distance_to_target = global_position.distance_to(target.global_position)
		if distance_to_target > _get_current_attack_range() + 1.0:
			state_chart.send_event("toFollow")
		return
	
	# Apply damage near the actual impact frame for better hit-sync (only if animation is playing)
	if not damage_applied_this_attack:
		var current_anim = animation_player.get_current_animation()
		if current_anim == current_attack_animation:
			var anim = animation_player.get_animation(current_anim)
			if anim != null:
				var anim_length = anim.length
				var current_pos = animation_player.get_current_animation_position()
				var hit_time = anim_length * ATTACK_HIT_TIME_RATIO
				if current_pos >= hit_time:
					apply_attack_damage()


func _on_detection_area_body_entered(body: Node3D) -> void:
	if not runtime_active:
		return
	if is_dead:
		return
	if body.is_in_group("player"):
		player_in_detection = true
		on_triggered()


func _on_detection_area_body_exited(body: Node3D) -> void:
	if not runtime_active:
		return
	if is_dead:
		return
	if body.is_in_group("player"):
		player_in_detection = false
		state_chart.send_event("toIdle")


func _apply_hit_reaction() -> void:
	_hit_reaction_serial += 1
	var this_hit_serial := _hit_reaction_serial
	stun_time_remaining = enemy_info.hit_stun_duration
	nav_agent.velocity = Vector3.ZERO

	var knockback_dir := -global_basis.z
	if target:
		knockback_dir = global_position - target.global_position
		knockback_dir.y = 0.0
		if knockback_dir.length_squared() < 0.0001:
			knockback_dir = -global_basis.z

	knockback_dir.y = 0.0
	knockback_dir = knockback_dir.normalized()
	knockback_velocity = knockback_dir * enemy_info.hit_knockback_speed

	if animation_player and animation_player.has_animation(enemy_info.hit_animation):
		animation_player.play(enemy_info.hit_animation)

	await get_tree().create_timer(max(enemy_info.hit_stun_duration, 0.01)).timeout
	if this_hit_serial != _hit_reaction_serial:
		return
	if is_dead or not runtime_active:
		return

	# Force recovery out of hit-pose even if state events were skipped.
	_on_stun_ended()


func _on_stun_ended() -> void:
	if is_dead:
		return

	if target != null and is_instance_valid(target):
		state_chart.send_event("toFollow")
		if animation_player and animation_player.has_animation(enemy_info.follow_animation):
			var follow_anim := animation_player.get_animation(enemy_info.follow_animation)
			if follow_anim:
				follow_anim.loop_mode = Animation.LOOP_LINEAR
			animation_player.play(enemy_info.follow_animation)
	else:
		state_chart.send_event("toIdle")
		if animation_player and animation_player.has_animation(enemy_info.idle_animation):
			animation_player.play(enemy_info.idle_animation)


func _update_health_bar() -> void:
	if not progress_bar:
		return
	
	# Throttle health bar updates to reduce UI refresh calls
	if last_health_bar_update < HEALTH_BAR_UPDATE_INTERVAL and current_health > 0.0:
		return

	last_health_bar_update = 0.0
	if progress_bar.has_method("set_health"):
		progress_bar.call("set_health", current_health, enemy_info.max_health)
		return

	progress_bar.max_value = max(enemy_info.max_health, 1.0)
	progress_bar.value = clamp(current_health, 0.0, progress_bar.max_value)


func _get_current_attack_range() -> float:
	if enemy_info.attack_type == EnemyInfo.AttackType.RANGED:
		return enemy_info.get_ranged_range()
	return enemy_info.get_melee_range()


func _choose_attack_animation() -> StringName:
	var attack_animations := enemy_info.get_attack_animations()
	if attack_animations.is_empty():
		return StringName("")
	if attack_animations.size() == 1:
		return attack_animations[0]
	return attack_animations[randi() % attack_animations.size()]


func _enter_ranged_attack_placeholder() -> void:
	if animation_player and animation_player.has_animation(enemy_info.ranged_backpedal_animation):
		var backpedal_anim := animation_player.get_animation(enemy_info.ranged_backpedal_animation)
		if backpedal_anim:
			backpedal_anim.loop_mode = Animation.LOOP_LINEAR
		animation_player.play(enemy_info.ranged_backpedal_animation)

	_spawn_ranged_projectile()
	damage_applied_this_attack = true


func _update_ranged_attack_placeholder(_delta: float) -> void:
	if not target:
		is_ranged_backpedaling = false
		velocity.x = 0.0
		velocity.z = 0.0
		return

	# Face the player while moving away (backpedal) at a reduced speed.
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		return

	var facing_dir := to_target.normalized()
	var retreat_dir := -facing_dir

	var target_rotation := atan2(facing_dir.x, facing_dir.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, 6.0 * _delta)

	nav_agent.velocity = Vector3.ZERO
	velocity.x = retreat_dir.x * enemy_info.ranged_retreat_speed
	velocity.z = retreat_dir.z * enemy_info.ranged_retreat_speed
	is_ranged_backpedaling = true


func _spawn_ranged_projectile() -> void:
	if ranged_template == null:
		return

	var projectile_instance: Node = ranged_template.duplicate()
	if projectile_instance == null:
		return
	if projectile_instance is not Node3D:
		projectile_instance.queue_free()
		return

	var projectile_node := projectile_instance as Node3D
	projectile_node.visible = true
	projectile_node.global_transform = ranged_template.global_transform

	var spawn_parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	spawn_parent.add_child(projectile_node)

	var launch_dir := -global_basis.z
	if target:
		launch_dir = target.global_position - projectile_node.global_position
	if launch_dir.length_squared() < 0.0001:
		launch_dir = -global_basis.z
	launch_dir = launch_dir.normalized()

	if projectile_node.has_method("launch"):
		projectile_node.call("launch", launch_dir, enemy_info.attack_damage, self, enemy_info.projectile_speed, enemy_info.projectile_max_distance)


func _calculate_navigation_path_distance() -> float:
	var path: PackedVector3Array = nav_agent.get_current_navigation_path()
	if path.size() < 2:
		return global_position.distance_to(target.global_position) if target != null else 0.0

	var total_distance: float = 0.0
	for i in range(1, path.size()):
		total_distance += path[i - 1].distance_to(path[i])
	return total_distance
