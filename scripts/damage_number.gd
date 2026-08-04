extends Node2D

var amount : int = 0;
var is_heal : bool = false;

func _ready() -> void:
	var label := $Label as Label;
	label.text = ("+" if is_heal else "-") + str(amount);
	label.modulate = Color(0.45, 1.0, 0.45) if is_heal else Color(1.0, 0.35, 0.35);

	var move_tween = create_tween();
	move_tween.tween_property(self, "position", position + Vector2(0, -40), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT);
	move_tween.tween_callback(queue_free);

	var fade_tween = create_tween();
	fade_tween.tween_interval(0.3);
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.3);
