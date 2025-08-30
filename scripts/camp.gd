extends Node2D

@onready var default_player : CharacterBody2D = $CharacterBody2D

func _ready() -> void:
	# Replace the default player with the selected character
	_spawn_selected_character()

func _spawn_selected_character() -> void:
	if not default_player:
		print("Error: Default player not found")
		return
	
	# Get the selected character scene path from global vars
	var character_scene_path = GlobalVars.selected_character_scene
	
	# Load the selected character scene
	var character_scene = load(character_scene_path)
	if not character_scene:
		print("Error: Could not load character scene: ", character_scene_path)
		return
	
	# Store the position and other properties of the default player
	var player_position = default_player.position
	var player_parent = default_player.get_parent()
	
	# Remove the default player
	default_player.queue_free()
	
	# Instance the selected character
	var new_player = character_scene.instantiate()
	
	# Set the position to match the original player
	new_player.position = player_position
	
	# Add the new player to the scene
	player_parent.add_child(new_player)
	
	print("Spawned character: ", character_scene_path)
