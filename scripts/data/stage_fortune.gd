extends Resource
class_name StageFortune

enum StageFortuneType {
	TINY_LAND,
	GIANT_LAND,
	BOUNTY_FRENZY,
	CHICKEN_PARTY,
	CHAOTIC_RAVE,
	SKATE_PARK,
	BISCUIT_RUSH,
	DARWINS_STAGE
}

var type : StageFortuneType;

static func generate_fortune():
	var new_fortune = StageFortune.new();
	new_fortune.type = randi_range(0, 7);
	return new_fortune;

func get_fortune_text() -> String:
	match(type):
		StageFortuneType.TINY_LAND:
			return "Small efforts will add up to something greater.";
		StageFortuneType.GIANT_LAND:
			return "A big change will soon come into your life.";
		StageFortuneType.BOUNTY_FRENZY:
			return "Fame and fortune awaits those who see things through to the end.";
		StageFortuneType.CHICKEN_PARTY:
			return "You will be blessed with an abundance of treasure.";
		StageFortuneType.CHAOTIC_RAVE:
			return "There is danger in getting too close to your foes.";
		StageFortuneType.SKATE_PARK:
			return "Life will come at you fast.";
		StageFortuneType.BISCUIT_RUSH:
			return "The time for you to realize your full potential grows closer.";
		StageFortuneType.DARWINS_STAGE:
			return "A harrowing trial lies in your future.";
		_:
			return "The future is uncertain.";
