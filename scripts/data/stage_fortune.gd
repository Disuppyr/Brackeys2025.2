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
