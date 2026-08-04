extends VBoxContainer
class_name CharacterInteract

@export var character : CharacterAttributes.Character;

var showing_dialogue : bool;

func _ready() -> void:
	$Label.hide();
	if GlobalVars.fortune_cookies == 0 or GlobalVars.character_fortunes.any(check_fortune):
		$Button.disabled = true;
		$Button2.grab_focus();
	else:
		$Button.grab_focus();
	if GlobalVars.fortune_cookies == 0:
		$Fight.disabled = true;
	if GlobalVars.character_attributes[character].conspired_this_phase:
		$Conspire.disabled = true;
	if GlobalVars.character_attributes[character].stardom < GlobalVars.REPUTATION_TRANSFER_AMOUNT:
		$Defamation.disabled = true;
	if GlobalVars.character_attributes[GlobalVars.player_character].stardom < GlobalVars.REPUTATION_TRANSFER_AMOUNT:
		$Commendation.disabled = true;
	if GlobalVars.character_attributes[GlobalVars.player_character].boasted_this_phase:
		$Boast.disabled = true;

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		if showing_dialogue:
			showing_dialogue = false;
			end_interact();

func use_fortune_cookie():
	if GlobalVars.character_attributes[character].incapacitated:
		GlobalVars.character_attributes[character].incapacitated = false;
		show_dialogue("I'm feeling better!");
	else:
		var fortune = CharacterFortune.generate_fortune_any(character);
		GlobalVars.character_fortunes.append(fortune);
		show_dialogue("The cookie reads: \"" + fortune.get_fortune_text() + "\"");
	GlobalVars.fortune_cookies = max(0, GlobalVars.fortune_cookies - 1);
	get_tree().call_group("enemy", "update_cookie_ui");

## Conspire: align this ally with the player for the next Stage. Their kills grant
## Stardom to the player instead of themselves (see GlobalVars.award_stardom).
func conspire():
	if GlobalVars.character_attributes[character].conspired_this_phase:
		return;
	GlobalVars.character_attributes[character].allied_with_player = true;
	GlobalVars.character_attributes[character].conspired_this_phase = true;
	show_dialogue("Let's team up. Your cut becomes mine.");

## Persuade: toggle whether this ally deploys on the next Stage.
func persuade():
	var attributes = GlobalVars.character_attributes[character];
	attributes.sitting_out = !attributes.sitting_out;
	if attributes.sitting_out:
		show_dialogue("Maybe you should sit this one out.");
	else:
		show_dialogue("On second thought, I could use you out there.");

## Fight: spend a fortune cookie to preemptively incapacitate a rival.
func fight():
	if GlobalVars.fortune_cookies <= 0:
		return;
	GlobalVars.fortune_cookies = max(0, GlobalVars.fortune_cookies - 1);
	GlobalVars.character_attributes[character].incapacitated = true;
	get_tree().call_group("enemy", "update_cookie_ui");
	show_dialogue("You won't be getting in my way.");

## Defamation: steal Stardom from this ally.
func defamation():
	var target_attributes = GlobalVars.character_attributes[character];
	if target_attributes.stardom < GlobalVars.REPUTATION_TRANSFER_AMOUNT:
		return;
	target_attributes.stardom -= GlobalVars.REPUTATION_TRANSFER_AMOUNT;
	GlobalVars.character_attributes[GlobalVars.player_character].stardom += GlobalVars.REPUTATION_TRANSFER_AMOUNT;
	show_dialogue("Word's getting around about what you really did.");

## Commendation: give some of the player's own Stardom to this ally.
func commendation():
	var player_attributes = GlobalVars.character_attributes[GlobalVars.player_character];
	if player_attributes.stardom < GlobalVars.REPUTATION_TRANSFER_AMOUNT:
		return;
	player_attributes.stardom -= GlobalVars.REPUTATION_TRANSFER_AMOUNT;
	GlobalVars.character_attributes[character].stardom += GlobalVars.REPUTATION_TRANSFER_AMOUNT;
	show_dialogue("You deserve some credit for that.");

## Boast: the acting (player-controlled) character locks in a small Stardom claim.
## Available from any ally interaction since there's no standalone self-menu yet.
func boast():
	var player_attributes = GlobalVars.character_attributes[GlobalVars.player_character];
	if player_attributes.boasted_this_phase:
		return;
	player_attributes.stardom += GlobalVars.BOAST_AMOUNT;
	player_attributes.boasted_this_phase = true;
	show_dialogue("I did that. Remember it.");

func chat():
	match(character):
		CharacterAttributes.Character.BONNIE:
			show_dialogue("I'm lookin' to drive some cattle!");
		CharacterAttributes.Character.JANE:
			show_dialogue("That mayor is corrupt...");
		CharacterAttributes.Character.PEARL:
			show_dialogue("Are you ready, darling? I can't wait!");
		CharacterAttributes.Character.ROSE:
			show_dialogue("...");

func end_interact():
	get_tree().call_group("player", "end_interact");
	queue_free();

func check_fortune(fortune : CharacterFortune) -> bool:
	return fortune.character == character;

func show_dialogue(dialogue : String):
	for child in get_children():
		if child is Button:
			child.hide();
	$Label.text = dialogue;
	$Label.show();
	showing_dialogue = true;
