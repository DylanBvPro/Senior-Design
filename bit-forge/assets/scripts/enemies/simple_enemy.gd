class_name SimpleEnemy
extends "res://assets/scripts/enemies/basic_enemy.gd"

signal killed_by_player(enemy: Node)

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var state_chart: StateChart = $StateChart
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var enemy_info: EnemyInfo = $EnemyInfo
@onready var progress_bar: ProgressBar = $SubViewport/ProgressBar

var target: CharacterBody3D
var player_in_detection: bool = false
var time_since_last_attack: float = 0.0
var damage_applied_this_attack: bool = false
var current_health: float = 0.0
var is_dead: bool = false
var stun_time_remaining: float = 0.0
var knockback_velocity: Vector3 = Vector3.ZERO
var invulnerability_time_remaining: float = 0.0

const HIT_STUN_DURATION: float = 0.5
const HIT_IFRAME_DURATION: float = 1.0
const HIT_KNOCKBACK_SPEED: float = 10.4
const HIT_KNOCKBACK_DAMPING: float = 14.0
const ATTACK_HIT_TIME_RATIO: float = 0.30

func _ready() -> void:
	super._ready()
	current_health = enemy_info.max_health
	_update_health_bar()
	
	target = get_tree().get_first_node_in_group("player")
	#print("target", target)
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	
	if animation_player:
		animation_player.play(enemy_info.idle_animation)
	
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if invulnerability_time_remaining > 0.0:
		invulnerability_time_remaining = max(invulnerability_time_remaining - delta, 0.0)
	if stun_time_remaining > 0.0:
		stun_time_remaining = max(stun_time_remaining - delta, 0.0)
		nav_agent.velocity = Vector3.ZERO
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, HIT_KNOCKBACK_DAMPING * delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	time_since_last_attack += delta
	move_and_slide()
	
func on_triggered() -> void:
	if is_dead:
		return
	state_chart.send_event("toFollow")


func _on_idle_state_entered() -> void:
	if is_dead:
		return
	if stun_time_remaining > 0.0:
		return
	if animation_player:
		animation_player.play(enemy_info.idle_animation)


func _on_follow_state_entered() -> void:
	if is_dead:
		return
	if stun_time_remaining > 0.0:
		return
	if animation_player:
		var anim = animation_player.get_animation(enemy_info.follow_animation)
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
		animation_player.play(enemy_info.follow_animation)
	
func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
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
	if is_dead:
		return
	if invulnerability_time_remaining > 0.0:
		return
	if amount <= 0.0:
		return

	current_health = max(current_health - amount, 0.0)
	invulnerability_time_remaining = HIT_IFRAME_DURATION
	_update_health_bar()
	if current_health <= 0.0:
		if source and source.is_in_group("player"):
			emit_signal("killed_by_player", self)
		_on_died()
		return

	_apply_hit_reaction()


func apply_damage(amount: float, source: Node = null) -> void:
	take_damage(amount, source)
	
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if is_dead:
		return
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z

func _on_follow_state_physics_processing(delta: float) -> void:
	if is_dead:
		return
	if stun_time_remaining > 0.0:
		return
	if not target:
		return
	
	# Check if close enough to attack and player is in detection area
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target < enemy_info.attack_distance and player_in_detection and time_since_last_attack >= enemy_info.attack_cooldown:
		state_chart.send_event("toAttack")
		return
	
	nav_agent.target_position = target.global_position
	
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
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 5.0 * delta)
	else:
		nav_agent.velocity = Vector3.ZERO

func _on_attack_state_entered() -> void:
	if is_dead:
		return
	if stun_time_remaining > 0.0:
		return
	# Stop all movement immediately
	nav_agent.velocity = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	
	if animation_player:
		animation_player.play(enemy_info.attack_animation)
	time_since_last_attack = 0.0
	damage_applied_this_attack = false


func apply_attack_damage() -> void:
	# Call this method from an animation callback at the desired frame
	if is_dead:
		return
	damage_applied_this_attack = true
	if target and target in get_tree().get_nodes_in_group("player"):
		if target.has_method("take_damage"):
			target.take_damage(enemy_info.attack_damage, self)


func _on_attack_state_physics_processing(delta: float) -> void:
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
		if distance_to_target > enemy_info.attack_distance + 1.5:
			state_chart.send_event("toFollow")
			return
	
	# Apply damage near the actual impact frame for better hit-sync.
	if animation_player.is_playing() and not damage_applied_this_attack:
		var current_anim = animation_player.get_current_animation()
		if current_anim == enemy_info.attack_animation:
			var anim = animation_player.get_animation(current_anim)
			if anim == null:
				return
			var anim_length = anim.length
			var current_pos = animation_player.get_current_animation_position()
			var hit_time = anim_length * ATTACK_HIT_TIME_RATIO

			if current_pos >= hit_time:
				apply_attack_damage()
			return
	
	# Wait for attack animation to finish before deciding to follow or go idle
	if animation_player.is_playing():
		return
	
	if not target or not player_in_detection:
		state_chart.send_event("toIdle")
		return
	
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target > enemy_info.attack_distance + 1.0:
		state_chart.send_event("toFollow")


func _on_detection_area_body_entered(body: Node3D) -> void:
	if is_dead:
		return
	if body.is_in_group("player"):
		player_in_detection = true
		on_triggered()


func _on_detection_area_body_exited(body: Node3D) -> void:
	if is_dead:
		return
	if body.is_in_group("player"):
		player_in_detection = false
		state_chart.send_event("toIdle")


func _apply_hit_reaction() -> void:
	stun_time_remaining = HIT_STUN_DURATION
	nav_agent.velocity = Vector3.ZERO

	var knockback_dir := -global_basis.z
	if target:
		knockback_dir = global_position - target.global_position
		knockback_dir.y = 0.0
		if knockback_dir.length_squared() < 0.0001:
			knockback_dir = -global_basis.z

	knockback_dir.y = 0.0
	knockback_dir = knockback_dir.normalized()
	knockback_velocity = knockback_dir * HIT_KNOCKBACK_SPEED

	if animation_player and animation_player.has_animation(enemy_info.hit_animation):
		animation_player.play(enemy_info.hit_animation)


func _update_health_bar() -> void:
	if not progress_bar:
		return

	if progress_bar.has_method("set_health"):
		progress_bar.call("set_health", current_health, enemy_info.max_health)
		return

	progress_bar.max_value = max(enemy_info.max_health, 1.0)
	progress_bar.value = clamp(current_health, 0.0, progress_bar.max_value)
