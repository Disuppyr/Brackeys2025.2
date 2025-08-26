extends Path2D
class_name ProjectileAttack

var elapsed_time;

func _ready() -> void:
	elapsed_time = 0;

func _physics_process(delta: float) -> void:
	elapsed_time += delta;
	$PathFollow2D.progress_ratio = max(elapsed_time / $PathFollow2D/GenericAttack.duration, 1.0);

func _on_child_removed() -> void:
	if $PathFollow2D.get_child_count() == 0:
		queue_free();
