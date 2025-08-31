extends ProjectileAttack

func _physics_process(delta: float) -> void:
	super._physics_process(delta);
	$TextureRect.size.x = 20 + $PathFollow2D.position.x;

func face_left():
	$TextureRect.position.y += -1;
