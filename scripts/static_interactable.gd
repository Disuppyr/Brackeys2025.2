extends Interactable

@export var interact_menu : PackedScene;
var scene;

func interact(player : Node):
	var menu = interact_menu.instantiate();
	player.add_child(menu);
