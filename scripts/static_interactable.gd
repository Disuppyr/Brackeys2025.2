extends Interactable

@export var character : CharacterAttributes.Character;
@export var interact_menu : PackedScene;
var scene;

func _ready() -> void:
	if $AnimationPlayer:
		$AnimationPlayer.play("idle")

func interact(player : Node):
	var menu = interact_menu.instantiate();
	if menu as CharacterInteract:
		menu.character = character;
	menu.position.y = -240;
	add_child(menu);

func enter_range():
	$Label.show();

func exit_range():
	$Label.hide();

func flip():
	$StaticBody2D/Character.flip_h = true;
