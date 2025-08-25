extends VBoxContainer

func _ready() -> void:
	$Button.grab_focus();

func end_interact():
	get_tree().call_group("player", "end_interact");
	queue_free();
