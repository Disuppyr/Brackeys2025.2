extends Node2D

@onready var confirm_button : TextureButton = $Control/ConfirmButton

func _ready() -> void:
	# Connect the confirm button press signal to our function
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_button_pressed)

func _on_confirm_button_pressed() -> void:
	# Change to the camp scene
	get_tree().change_scene_to_file("res://scenes/camp.tscn")
