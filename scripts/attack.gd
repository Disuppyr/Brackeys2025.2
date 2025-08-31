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
@export var knockback : float;
@export var duration : float;
@export var sprite : Texture2D;

var pierced : int = 0;
var ending : bool = false;

func _ready() -> void:
	if has_node("Sprite2D") and $Sprite2D:
		$Sprite2D.texture = sprite;
	if has_node("AnimatedSprite2D") and $AnimatedSprite2D:
		$AnimatedSprite2D.play("default");
	$Timer.start(duration);

func hit():
	pierced += 1;
	if pierced >= pierce:
		if !$Timer.is_stopped():
			$Timer.stop();
			attack_end();

func attack_end():
	set_deferred("monitorable",false);
	ending = true;
	if has_node("AnimationPlayer") and $AnimationPlayer:
		$AnimationPlayer.play("fade");
	else:
		queue_free();

func attack_free(animation : StringName):
	if animation == "fade":
		queue_free();

func set_power(value : int):
	power = value;

func face_left():
	if has_node("Sprite2D") and $Sprite2D:
		$Sprite2D.flip_h = true;
