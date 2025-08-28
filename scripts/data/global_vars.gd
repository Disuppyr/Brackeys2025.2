extends Node

var player_character : CharacterAttributes.Character = CharacterAttributes.Character.BONNIE;
var character_attributes : Array[CharacterAttributes] = [null, null, null, null];
var fortune_cookies : int = 0;
var stage_fortune : StageFortune = null;
var character_fortunes : Array[CharacterFortune] = [];

func has_fortune(character : CharacterAttributes.Character, type : CharacterFortune.CharacterFortuneType) -> bool:
	for fortune in character_fortunes:
		if character == fortune.character and type == fortune.type:
			return true;
	return false;
