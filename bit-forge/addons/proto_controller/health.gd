extends ProgressBar   # Or CharacterBody3D if this is your player

# --------------------
# Stats
# --------------------
@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var armor: float = 0.0  # Reduces incoming damage

# --------------------
# Node Reference
# --------------------
@onready var health_bar: ProgressBar = $"HealthBar"  # Update path if your ProgressBar is elsewhere

# --------------------
# Lifecycle
# --------------------
func _ready() -> void:
	_update_health_bar()

# --------------------
# Public functions
# --------------------
func apply_damage(amount: float) -> void:
	# Reduce damage by armor (simple linear reduction)
	var final_damage = max(amount - armor, 0)
	current_health = clamp(current_health - final_damage, 0, max_health)
	_update_health_bar()
	
	if current_health <= 0:
		_die()

func heal(amount: float) -> void:
	current_health = clamp(current_health + amount, 0, max_health)
	_update_health_bar()

# --------------------
# Internal functions
# --------------------
func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = current_health / max_health * 100.0

func _die() -> void:
	print("%s died!" % name)
	queue_free()  # or your death logic
