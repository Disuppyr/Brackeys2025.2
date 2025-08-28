extends PlayerController
class_name CombatPlayerController

@export var auto_attack_cooldown : float = 1.0;
@export var attack : PackedScene;

var targets : Array[Node2D] = [];
var current_auto_attack_cooldown : float = 1.0;

func _ready() -> void:
	current_auto_attack_cooldown = 0.0;

func _physics_process(delta: float) -> void:
	super._physics_process(delta);
	if facing_left && $TargetingArea.rotation == 0:
		$TargetingArea.rotation = PI;
	if !facing_left && $TargetingArea.rotation != 0:
		$TargetingArea.rotation = 0;
	if current_auto_attack_cooldown > 0.0:
		current_auto_attack_cooldown = max(0.0, current_auto_attack_cooldown - delta);
	if current_auto_attack_cooldown == 0.0 and targets.size() > 0:
		var attack_instance = attack.instantiate();
		if facing_left:
			attack_instance.position = Vector2(position.x - 48, position.y);
			if attack_instance.has_method("face_left"):
				attack_instance.face_left();
		else:
			attack_instance.position = Vector2(position.x + 48, position.y);
		get_parent().add_child(attack_instance);
		current_auto_attack_cooldown = auto_attack_cooldown;
		# Trigger shooting animation
		trigger_shoot_animation();

func _on_targeting_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		targets.append(area);

func _on_targeting_area_exited(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		if targets.has(area):
			targets.remove_at(targets.find(area));
