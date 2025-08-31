extends VBoxContainer

var showing_dialogue : bool;
var do_scene_transition : bool;

func _ready() -> void:
	$Label.hide();
	if GlobalVars.fortune_cookies == 0 or GlobalVars.stage_fortune != null:
		$Button.disabled = true;
		$Button2.grab_focus();
	else:
		$Button.grab_focus();

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		if showing_dialogue:
			if do_scene_transition:
				get_tree().change_scene_to_file("res://scenes/level1.tscn")
			else:
				showing_dialogue = false;
				end_interact();

func use_fortune_cookie():
	var fortune = StageFortune.generate_fortune();
	GlobalVars.stage_fortune = fortune;
	show_dialogue("The cookie reads: \"" + fortune.get_fortune_text() + "\"");
	GlobalVars.fortune_cookies = max(0, GlobalVars.fortune_cookies - 1);
	get_tree().call_group("enemy", "update_cookie_ui");

func chat():
	show_dialogue("There's something odd about these foreign biscuits...");

func start_mission():
	do_scene_transition = true;
	show_dialogue("Good luck!");
	

func end_interact():
	if do_scene_transition:
		get_tree().change_scene_to_file("res://scenes/level1.tscn")
	else:
		get_tree().call_group("player", "end_interact")
		queue_free()

func show_dialogue(dialogue : String):
	$Button.hide();
	$Button2.hide();
	$Button3.hide();
	$Button4.hide();
	$Label.text = dialogue;
	$Label.show();
	showing_dialogue = true;
