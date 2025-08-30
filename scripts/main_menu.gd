extends Node2D

@onready var play_button : TextureButton = $Control/HBoxContainer/Play
@onready var quit_button : TextureButton = $Control/HBoxContainer/Quit

func _ready() -> void:
	# Connect the button press signals to our functions
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)

func _on_play_button_pressed() -> void:
	# Change to the character select scene
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")

func _on_quit_button_pressed() -> void:
	# Quit the game
	get_tree().quit()
