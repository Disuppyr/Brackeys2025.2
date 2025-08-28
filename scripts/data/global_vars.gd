extends Node

var player_character : CharacterAttributes.Character = CharacterAttributes.Character.BONNIE;
var character_attributes : Array[CharacterAttributes] = [null, null, null, null];
var fortune_cookies : int = 0;
var stage_fortune : StageFortune = null;
var character_fortunes : Array[CharacterFortune] = [];
var KO_count : Array[int] = [0, 0, 0, 0];

func has_fortune(character : CharacterAttributes.Character, type : CharacterFortune.CharacterFortuneType) -> bool:
	for fortune in character_fortunes:
		if character == fortune.character and type == fortune.type:
			return true;
	return false;

func get_targetable_characters() -> Array[int]:
	var returned = [];
	for attributes in character_attributes:
		if attributes.current_hp > 0:
			returned.add(attributes.character);
	if returned.size() == 0:
		returned.append(player_character);
	return returned;
