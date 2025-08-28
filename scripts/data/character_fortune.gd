extends Resource
class_name CharacterFortune

enum CharacterFortuneType {
	LUCKY_CLOVER,
	SKILLED,
	BAKING_SODA,
	BUBBLE,
	TRAINING_ARC,
	BLACK_CAT,
	JAMMED,
	JINXED
}

var character : CharacterAttributes.Character;
var type : CharacterFortuneType;

static func generate_fortune_any(char : CharacterAttributes.Character):
	var new_fortune = CharacterFortune.new();
	new_fortune.character = char;
	new_fortune.type = randi_range(0, 7);
	return new_fortune;
	
static func generate_fortune_good(char : CharacterAttributes.Character):
	var new_fortune = CharacterFortune.new();
	new_fortune.character = char;
	new_fortune.type = randi_range(0, 4);
	return new_fortune;
	
static func generate_fortune_bad(char : CharacterAttributes.Character):
	var new_fortune = CharacterFortune.new();
	new_fortune.character = char;
	new_fortune.type = randi_range(5, 7);
	return new_fortune;
