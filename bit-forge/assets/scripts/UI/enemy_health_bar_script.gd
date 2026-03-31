extends ProgressBar

@export var bar_color: Color = Color(0.95, 0.15, 0.15, 1.0)

var fill_stylebox: StyleBoxFlat

func _ready() -> void:
	fill_stylebox = get("theme_override_styles/fill") as StyleBoxFlat
	if fill_stylebox == null:
		fill_stylebox = StyleBoxFlat.new()
		add_theme_stylebox_override("fill", fill_stylebox)
	fill_stylebox.bg_color = bar_color
	visible = false


func set_health(current_health: float, max_health: float) -> void:
	max_value = max(max_health, 1.0)
	value = clamp(current_health, 0.0, max_value)
	_refresh_visibility()
	
func _on_value_changed(_value: float) -> void:
	if fill_stylebox:
		fill_stylebox.bg_color = bar_color
	_refresh_visibility()


func _refresh_visibility() -> void:
	visible = max_value > 0.0 and value < max_value
