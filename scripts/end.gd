extends Node2D

enum ResultType {
	WISH_GRANTED,
	DEFEAT,
	JAIL,
	STAGE_CLEAR
}

@onready var animation_tree : AnimationTree = $AnimationTree
@onready var outcome_label : Label = $OutcomeLabel
@onready var continue_button : Button = $ContinueButton

var result : ResultType

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	var winner = GlobalVars.check_stardom_winner()
	if winner == GlobalVars.player_character:
		result = ResultType.WISH_GRANTED
		animation_tree.set("parameters/conditions/win", true)
		continue_button.text = "Finish"
		outcome_label.text = "WISH GRANTED\n" + get_wish_text(winner)
	elif winner != -1:
		result = ResultType.DEFEAT
		animation_tree.set("parameters/conditions/lose", true)
		continue_button.text = "Finish"
		outcome_label.text = get_character_name(winner) + " got their wish first.\nBetter luck next time."
	elif GlobalVars.stage_index >= GlobalVars.MAX_STAGES:
		result = ResultType.JAIL
		animation_tree.set("parameters/conditions/lose", true)
		continue_button.text = "Finish"
		outcome_label.text = "Nobody made their bounty in time.\nEveryone's in jail."
	else:
		result = ResultType.STAGE_CLEAR
		animation_tree.set("parameters/conditions/win", true)
		continue_button.text = "Back to Camp"
		outcome_label.text = "Stage clear."

func get_wish_text(character : CharacterAttributes.Character) -> String:
	match(character):
		CharacterAttributes.Character.BONNIE:
			return "Bonnie's family will never go hungry again.";
		CharacterAttributes.Character.PEARL:
			return "Pearl finally has one score to retire on.";
		CharacterAttributes.Character.ROSE:
			return "Rose finds peace, now that the revenge is done.";
		CharacterAttributes.Character.JANE:
			return "Jane restores justice to the town.";
		_:
			return "";

func get_character_name(character : CharacterAttributes.Character) -> String:
	match(character):
		CharacterAttributes.Character.BONNIE:
			return "Bonnie";
		CharacterAttributes.Character.PEARL:
			return "Pearl";
		CharacterAttributes.Character.ROSE:
			return "Rose";
		CharacterAttributes.Character.JANE:
			return "Jane";
		_:
			return "";

func _on_continue_pressed() -> void:
	if result == ResultType.STAGE_CLEAR:
		GlobalVars.advance_scene();
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn");
