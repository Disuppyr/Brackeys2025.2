extends VBoxContainer

func _ready() -> void:
	$Button.grab_focus();

func end_interact():
	queue_free()
