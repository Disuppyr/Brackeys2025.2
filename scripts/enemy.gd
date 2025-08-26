extends Area2D
class_name Enemy

enum EnemyState {
	IDLE,
	HURTING
}

var state : EnemyState = EnemyState.IDLE;
var invulnerability : float = 0;
var y_offset : float = -32.0;
var knockback : float = 0.0;
var damage_source : Vector2 = Vector2.ZERO;

func _physics_process(delta: float) -> void:
	if state == EnemyState.HURTING:
		if invulnerability == 0.0:
			y_offset = -32.0;
			state = EnemyState.IDLE;
		else:
			invulnerability = max(0.0, invulnerability - delta);
			y_offset = -32 - (50 * sin(PI * (0.8 - invulnerability) / 0.8));
		var knockback_dir = (position - damage_source).normalized();
		position += knockback_dir * knockback * delta;
		$Sprite2D.position.y = y_offset;

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("attack"):
		var attack_area = area as Attack;
		if attack_area:
			if attack_area.source != Attack.AttackSource.ENEMY and state == EnemyState.IDLE:
				state = EnemyState.HURTING;
				attack_area.hit();
				knockback = attack_area.knockback;
				# TEMP
				damage_source = (get_tree().get_first_node_in_group("player") as CombatPlayerController).position;
				invulnerability = 0.8;
				$AnimationPlayer.play("hurt");
