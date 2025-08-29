extends VBoxContainer

@export var character : CharacterAttributes.Character;

var showing_dialogue : bool;

func _ready() -> void:
	$Label.hide();
	if GlobalVars.fortune_cookies == 0 or GlobalVars.character_fortunes.any(check_fortune):
		$Button.disabled = true;
		$Button2.grab_focus();
	else:
		$Button.grab_focus();

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
		show_dialogue(fortune.get_fortune_text());
	GlobalVars.fortune_cookies = max(0, GlobalVars.fortune_cookies - 1);

func chat():
	show_dialogue("Hello there!");

func end_interact():
	get_tree().call_group("player", "end_interact");
	queue_free();

func check_fortune(fortune : CharacterFortune) -> bool:
	return fortune.character == character;

func show_dialogue(dialogue : String):
	$Button.hide();
	$Button2.hide();
	$Button3.hide();
	$Label.text = dialogue;
	$Label.show();
	showing_dialogue = true;
