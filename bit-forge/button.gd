extends Button
# Or extends TextureButton if that's what you're using

var original_color: Color

func _ready():
	# Store the original per-node modulate color
	original_color = self_modulate

func _on_mouse_entered():
	# Darken the rendered pixels by 30%
	self_modulate = original_color * Color(0.7, 0.7, 0.7, 1.0)

func _on_mouse_exited():
	# Restore how it was drawn before
	self_modulate = original_color
