extends Interactable

@export var interact_menu : PackedScene;
var scene;

func _ready() -> void:
	if $AnimationPlayer:
		$AnimationPlayer.play("idle")

func interact(player : Node):
	var menu = interact_menu.instantiate();
	menu.position.y = -200;
	add_child(menu);

func enter_range():
	$Label.show();

func exit_range():
	$Label.hide();
