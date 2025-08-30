extends Node2D

@onready var confirm_button : TextureButton = $Control/ConfirmButton
@onready var box_container : HBoxContainer = $BoxContainer

# Character scene paths
var character_scenes = [
	"res://nodes/entities/player_characters/bonnie.tscn",
	"res://nodes/entities/player_characters/pearl.tscn", 
	"res://nodes/entities/player_characters/rose.tscn",
	"res://nodes/entities/player_characters/jane.tscn"
]

var selected_character_index : int = 0

func _ready() -> void:
	# Connect the confirm button press signal to our function
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_button_pressed)
	
	# Connect focus signals for character selection buttons
	_setup_character_buttons()

func _setup_character_buttons() -> void:
	if not box_container:
		return
	
	for i in range(box_container.get_child_count()):
		var button = box_container.get_child(i) as TextureButton
		if button:
			# Connect focus signal to track selected character
			button.focus_entered.connect(_on_character_button_focused.bind(i))
			# Set first button as initially focused
			if i == 0:
				button.grab_focus()

func _on_character_button_focused(character_index: int) -> void:
	selected_character_index = character_index
	print("Selected character: ", character_index)

func _on_confirm_button_pressed() -> void:
	# Store the selected character globally
	GlobalVars.selected_character_scene = character_scenes[selected_character_index]
	print("Confirmed character selection: ", character_scenes[selected_character_index])
	# Change to the camp scene
	get_tree().change_scene_to_file("res://scenes/camp.tscn")
