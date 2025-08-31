extends Node2D

@onready var default_player : CharacterBody2D = $CharacterBody2D

func _ready() -> void:
	# Replace the default player with the selected character
	_spawn_selected_character()
	_spawn_unselected_npcs()

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

func _spawn_unselected_npcs() -> void:
	var character_to_npc = {
		"res://nodes/entities/player_characters/bonnie.tscn": "res://nodes/entities/npcs/camp/bonnie_npc.tscn",
		"res://nodes/entities/player_characters/pearl.tscn": "res://nodes/entities/npcs/camp/pearl_npc.tscn",
		"res://nodes/entities/player_characters/rose.tscn": "res://nodes/entities/npcs/camp/rose_npc.tscn",
		"res://nodes/entities/player_characters/jane.tscn": "res://nodes/entities/npcs/camp/jane_npc.tscn"
	}
	var selected = GlobalVars.selected_character_scene
	var unselected = []
	for char_path in character_to_npc.keys():
		if char_path != selected:
			unselected.append(char_path)
	# Find all spawn points (assumes nodes named NPCSpawn1, NPCSpawn2, ...)
	for i in range(unselected.size()):
		var spawn_node = get_node_or_null("NPCSpawn%d" % (i+1))
		if spawn_node:
			var npc_scene = load(character_to_npc[unselected[i]])
			if npc_scene:
				var npc_instance = npc_scene.instantiate()
				npc_instance.position = spawn_node.position
				if i > 0:
					npc_instance.flip();
				add_child(npc_instance)

func update_cookie_ui():
	if GlobalVars.fortune_cookies == 2:
		$Control/HSplitContainer/FortuneCookie3.hide();
	if GlobalVars.fortune_cookies == 1:
		$Control/HSplitContainer/FortuneCookie2.hide();
	if GlobalVars.fortune_cookies == 0:
		$Control/HSplitContainer/FortuneCookie1.hide();
