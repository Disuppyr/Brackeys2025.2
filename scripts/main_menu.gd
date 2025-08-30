extends Node2D

@onready var texture_button : TextureButton = $Control/TextureButton

func _ready() -> void:
	# Connect the button press signal to our function
	if texture_button:
		texture_button.pressed.connect(_on_texture_button_pressed)

func _on_texture_button_pressed() -> void:
	# Change to the character select scene
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")
