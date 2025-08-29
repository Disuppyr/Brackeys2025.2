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

func get_fortune_text():
	match(type):
		CharacterFortuneType.LUCKY_CLOVER:
			return "A good luck charm will protect you from misfortune.";
		CharacterFortuneType.SKILLED:
			return "Earn your peers' respect by showing them your true self.";
		CharacterFortuneType.BAKING_SODA:
			return "Today is a good day to treat yourself to something nice.";
		CharacterFortuneType.BUBBLE:
			return "Don't let the opinions of others sway your values.";
		CharacterFortuneType.TRAINING_ARC:
			return "The road to success is walked one step at a time.";
		CharacterFortuneType.BLACK_CAT:
			return "Be wary of succumbing to disease or injury.";
		CharacterFortuneType.JAMMED:
			return "A dull knife is no knife at all.";
		CharacterFortuneType.JINXED:
			return "Prepare yourself for an unexpected setback.";
