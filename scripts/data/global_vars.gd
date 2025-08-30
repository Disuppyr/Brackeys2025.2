extends Node

var player_character : CharacterAttributes.Character = CharacterAttributes.Character.BONNIE;
var character_attributes : Array[CharacterAttributes] = [null, null, null, null];
var fortune_cookies : int = 1;
var stage_fortune : StageFortune = null;
var character_fortunes : Array[CharacterFortune] = [];
var KO_count : Array[int] = [0, 0, 0, 0];
var special_KO_count : Array[int] = [0, 0, 0, 0];
var last_KO : CharacterAttributes.Character = -1;
var current_scene = null;
var stage_index : int = 0;
var stage_level : bool = false;

func _ready():
	var root = get_tree().root
	# Using a negative index counts from the end, so this gets the last child node of `root`.
	current_scene = root.get_child(-1)

func _enter_tree() -> void:
	character_attributes[0] = load("res://data/bonnie_default.tres").duplicate();
	character_attributes[1] = load("res://data/jane_default.tres").duplicate();
	character_attributes[2] = load("res://data/pearl_default.tres").duplicate();
	character_attributes[3] = load("res://data/rose_default.tres").duplicate();

func has_fortune(character : CharacterAttributes.Character, type : CharacterFortune.CharacterFortuneType) -> bool:
	for fortune in character_fortunes:
		if character == fortune.character and type == fortune.type:
			return true;
	return false;

func get_targetable_characters() -> Array[int]:
	var returned = [] as Array[int];
	for attributes in character_attributes:
		if attributes.current_hp > 0:
			returned.add(attributes.character);
	if returned.size() == 0:
		returned.append(player_character);
	return returned;

func advance_scene():
	if stage_level:
		goto_scene("res://scenes/camp.tscn");
		stage_level = false;
	else:
		goto_scene("res://scenes/stage_" + str(stage_index) + ".tscn")
		stage_level = true;
		stage_index += 1;

func goto_scene(path):
	_deferred_goto_scene.call_deferred(path)

func _deferred_goto_scene(path):
	current_scene.free();
	var s = ResourceLoader.load(path);
	current_scene = s.instantiate();
	get_tree().root.add_child(current_scene);
	get_tree().current_scene = current_scene;

func get_character_node(character : CharacterAttributes.Character):
	match(character):
		CharacterAttributes.Character.BONNIE:
			return get_tree().get_first_node_in_group("bonnie");
		CharacterAttributes.Character.JANE:
			return get_tree().get_first_node_in_group("jane");
		CharacterAttributes.Character.PEARL:
			return get_tree().get_first_node_in_group("pearl");
		CharacterAttributes.Character.ROSE:
			return get_tree().get_first_node_in_group("rose");
