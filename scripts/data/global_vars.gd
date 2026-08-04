extends Node

enum ItemType {
	NONE,
	HARD_TACK
}

signal held_item_changed;

const STARDOM_TARGET : int = 100;
const STARDOM_PER_KO : int = 1;
const STARDOM_STAGE_CLEAR_BONUS : int = 10;
const REPUTATION_TRANSFER_AMOUNT : int = 10;
const BOAST_AMOUNT : int = 2;
## Safety valve until Phase 5 adds real branching mission content: how many
## Stages can be played before the run ends in the "Everyone in Jail" ending
## if nobody has reached STARDOM_TARGET yet.
const MAX_STAGES : int = 5;

var player_character : CharacterAttributes.Character = CharacterAttributes.Character.BONNIE;
var character_attributes : Array[CharacterAttributes] = [null, null, null, null];
## Defaults to the rest of the roster (matching selected_character_scene's
## Bonnie default) so opening a Stage scene directly in the editor -- skipping
## character_select.gd, which normally overwrites this -- still spawns a full
## party instead of silently spawning zero allies.
var unselected_character_scenes : Array[String] = [
	"res://nodes/entities/player_characters/pearl.tscn",
	"res://nodes/entities/player_characters/rose.tscn",
	"res://nodes/entities/player_characters/jane.tscn"
]
var fortune_cookies : int = 3;
var stage_fortune : StageFortune = null;
var character_fortunes : Array[CharacterFortune] = [];
var KO_count : Array[int] = [0, 0, 0, 0];
var special_KO_count : Array[int] = [0, 0, 0, 0];
var last_KO : CharacterAttributes.Character = -1;
var current_scene = null;
var stage_index : int = 0;
var stage_level : bool = false;
var selected_character_scene : String = "res://nodes/entities/player_characters/bonnie.tscn"  # Default to Bonnie
var held_item : ItemType = ItemType.NONE:
	set(value):
		held_item = value;
		held_item_changed.emit();

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

## Very brief global time freeze for hit impact -- overlapping calls just
## extend the perceived freeze slightly, which is fine at this magnitude.
func hitstop(duration : float = 0.04, scale : float = 0.05) -> void:
	Engine.time_scale = scale;
	get_tree().create_timer(duration, true, false, true).timeout.connect(_end_hitstop);

func _end_hitstop() -> void:
	Engine.time_scale = 1.0;

func award_stardom(character : CharacterAttributes.Character, amount : int) -> void:
	var recipient = character;
	if character_attributes[character].allied_with_player and character != player_character:
		recipient = player_character;
	character_attributes[recipient].stardom += amount;

func check_stardom_winner() -> int:
	for attributes in character_attributes:
		if attributes.stardom >= STARDOM_TARGET:
			return attributes.character;
	return -1;

## Pick up an item into the single held-item slot. Replaces whatever was
## already held (no stacking/multiple slots yet).
func pick_up_item(type : ItemType) -> void:
	held_item = type;

## Consume whatever's in the held-item slot and apply its effect.
func use_held_item() -> void:
	match held_item:
		ItemType.HARD_TACK:
			for attributes in character_attributes:
				if !attributes.incapacitated:
					attributes.current_hp = min(attributes.max_hp, attributes.current_hp + 20);
	held_item = ItemType.NONE;

func get_held_item_name() -> String:
	match held_item:
		ItemType.HARD_TACK:
			return "Holy Hard Tack";
		_:
			return "";

func get_targetable_characters() -> Array[int]:
	var returned = [] as Array[int];
	for attributes in character_attributes:
		if attributes.current_hp > 0:
			returned.append(attributes.character);
	if returned.size() == 0:
		returned.append(player_character);
	return returned;

## Which Stage scene the drawn StageFortune sends you to. Foretelling now
## genuinely picks the target: loot-flavored fortunes point at the Train
## heist, danger-flavored fortunes point at the County Jail, and the rest
## default to the Desert. Train/County Jail are placeholder-art scaffolds
## (see docs/IMPLEMENTATION_PLAN.md Phase 5) but fully playable.
const STAGE_SCENE_BY_FORTUNE : Dictionary = {
	StageFortune.StageFortuneType.TINY_LAND: "res://scenes/level1.tscn",
	StageFortune.StageFortuneType.GIANT_LAND: "res://scenes/level1.tscn",
	StageFortune.StageFortuneType.BOUNTY_FRENZY: "res://scenes/train_stage.tscn",
	StageFortune.StageFortuneType.CHICKEN_PARTY: "res://scenes/train_stage.tscn",
	StageFortune.StageFortuneType.CHAOTIC_RAVE: "res://scenes/county_jail_stage.tscn",
	StageFortune.StageFortuneType.SKATE_PARK: "res://scenes/level1.tscn",
	StageFortune.StageFortuneType.BISCUIT_RUSH: "res://scenes/level1.tscn",
	StageFortune.StageFortuneType.DARWINS_STAGE: "res://scenes/county_jail_stage.tscn",
}
const DEFAULT_STAGE_SCENE : String = "res://scenes/level1.tscn";

func get_next_stage_scene() -> String:
	if stage_fortune != null and STAGE_SCENE_BY_FORTUNE.has(stage_fortune.type):
		return STAGE_SCENE_BY_FORTUNE[stage_fortune.type];
	return DEFAULT_STAGE_SCENE;

func advance_scene():
	if stage_level:
		goto_scene("res://scenes/camp.tscn");
		stage_level = false;
	else:
		goto_scene(get_next_stage_scene())
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
	return null;
