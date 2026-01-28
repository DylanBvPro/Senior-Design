extends Node3D
class_name PlayerFinder

@export var detection_distance: float = 12.0
@export var pursue_distance: float = 1.8
@export var taunt_chance: float = 0.3

@onready var owner_body: CharacterBody3D = get_parent()
# Look for a NavigationAgent3D **on the owner itself**
@onready var nav_agent: NavigationAgent3D = owner_body.get_node_or_null("NavigationAgent3D")

var player: Node3D = null
var has_taunted: bool = false

func _ready() -> void:
	if nav_agent == null:
		push_error("PlayerFinder: NavigationAgent3D not found on owner!")
		return

	# Configure the NavigationAgent3D
	nav_agent.path_desired_distance = 0.4
	nav_agent.target_desired_distance = pursue_distance
	nav_agent.avoidance_enabled = true

# --------------------
# Main update function called by the enemy every frame
# Returns a dictionary with state, movement, and player position
# --------------------
func update_player_logic(_delta: float) -> Dictionary:
	player = _find_player()

	# --- No player detected ---
	if player == null:
		has_taunted = false
		return {
			"state": "NO_PLAYER",
			"move": Vector3.ZERO,
			"position": null
		}

	var distance = owner_body.global_position.distance_to(player.global_position)

	# --- Attack range ---
	if distance <= pursue_distance:
		return {
			"state": "ATTACK",
			"move": Vector3.ZERO,
			"position": player.global_position
		}

	# --- Taunt once per detection ---
	if not has_taunted and randf() < taunt_chance:
		has_taunted = true
		return {
			"state": "TAUNT",
			"move": Vector3.ZERO,
			"position": player.global_position
		}

	# --- Outside detection distance → idle/free roam ---
	if distance > detection_distance:
		has_taunted = false
		return {
			"state": "NO_PLAYER",
			"move": Vector3.ZERO,
			"position": null
		}

	# --- Chase player ---
	if nav_agent != null:
		# Update the target position each frame
		nav_agent.target_position = player.global_position

		if nav_agent.is_navigation_finished():
			# Player may be off mesh or unreachable
			return {
				"state": "CHASE",
				"move": Vector3.ZERO,
				"position": player.global_position
			}

		# Move toward next point in path
		var next_pos = nav_agent.get_next_path_position()
		var direction = next_pos - owner_body.global_position
		direction.y = 0.0

		if direction.length() < 0.01:
			direction = player.global_position - owner_body.global_position
			direction.y = 0.0

		return {
			"state": "CHASE",
			"move": direction.normalized(),
			"position": player.global_position
		}
	else:
		# Fallback if no nav agent exists
		return {
			"state": "CHASE",
			"move": (player.global_position - owner_body.global_position).normalized(),
			"position": player.global_position
		}

# --------------------
# Clears the current player target
# --------------------
func clear_target() -> void:
	player = null
	has_taunted = false
	if nav_agent != null:
		nav_agent.target_position = owner_body.global_position
		nav_agent.set_velocity(Vector3.ZERO)

# --------------------
# Internal: Find closest player within detection distance
# --------------------
func _find_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null

	var closest: Node3D = null
	var closest_dist := detection_distance

	for p in players:
		var d = owner_body.global_position.distance_to(p.global_position)
		if d <= closest_dist:
			closest_dist = d
			closest = p

	return closest
