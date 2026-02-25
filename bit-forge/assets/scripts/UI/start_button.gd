extends Button
# Path to the scene you want to load
@export var scene_to_load: String = "res://main.tscn"

func _ready():
	# Connect the pressed signal (if not connected in the editor)
	self.pressed.connect(_on_button_pressed)

func _on_button_pressed():
	get_tree().change_scene_to_file(scene_to_load)
