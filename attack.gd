extends Area2D
class_name Attack

enum AttackSource {
	BONNIE,
	JANE,
	PEARL,
	ROSE,
	ENEMY
}

@export var source : AttackSource;
@export var power : int;
@export var pierce : int;
@export var duration : float;
@export var sprite : Texture2D;

var pierced;

func _ready() -> void:
	$Sprite2D.texture = sprite;
	pierced = 0;
	$Timer.start(duration);

func hit():
	pierced += 1;
	if pierced >= pierce:
		if !$Timer.is_stopped():
			$Timer.stop();
			attack_end();

func attack_end():
	monitorable = false;
	$AnimationPlayer.play("fade");

func attack_free(animation : StringName):
	if animation == "fade":
		queue_free();
