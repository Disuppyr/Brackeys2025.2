extends Camera2D

var shake_strength : float = 0.0;
var shake_timer : float = 0.0;
var rng := RandomNumberGenerator.new();

func shake(amount : float, duration : float) -> void:
	shake_strength = max(shake_strength, amount);
	shake_timer = max(shake_timer, duration);

func _process(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer = max(0.0, shake_timer - delta);
		if shake_timer > 0.0:
			offset = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake_strength;
		else:
			shake_strength = 0.0;
			offset = Vector2.ZERO;
