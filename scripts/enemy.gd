extends Area2D
class_name Enemy

enum EnemyBehavior {
	TARGET_RANDOM,
	TARGET_WEAKEST,
	TARGET_STARDOM,
	MIXED
}

enum EnemyState {
	IDLE,
	MOVING,
	ATTACKING,
	HURTING,
	DYING
}

signal on_death;

@export var attributes : EntityAttributes;
@export var behavior : EnemyBehavior = EnemyBehavior.TARGET_RANDOM;
@export var follow_range : float;

var state : EnemyState = EnemyState.IDLE;
var invulnerability : float = 0;
var y_offset : float = -32.0;
var knockback : float = 0.0;
var damage_source : Vector2 = Vector2.ZERO;
var cooldown : float = 0.0;
var target_id : int;
var target : Node2D;
var move_position : Vector2;
var facing_left : bool = false;
var state_machine : AnimationNodeStateMachinePlayback;

func _ready() -> void:
	state_machine = $AnimationTree["parameters/playback"];
	attributes.current_hp = attributes.max_hp;
	assign_target();

func _process(delta: float) -> void:
	if state == EnemyState.IDLE:
		if cooldown > 0.0:
			cooldown = max(0.0, cooldown - delta);
		else:
			if !GlobalVars.get_targetable_characters().has(target_id):
				assign_target();
			if abs(target.position.x - position.x) <= follow_range and abs(target.position.y - position.y) <= 32.0:
				state = EnemyState.ATTACKING;
				cooldown = attributes.attack_cooldown;
				if target.position.x > position.x and facing_left:
					facing_left = false;
					$Node2D/AnimatedSprite2D.flip_h = false;
				if target.position.x < position.x and !facing_left:
					facing_left = true;
					$Node2D/AnimatedSprite2D.flip_h = true;
				state_machine.travel("Shoot");
				var attack_instance = attributes.attack.instantiate();
				# TODO set attack power here
				if facing_left:
					attack_instance.position = Vector2(position.x - 48, position.y);
					if attack_instance.has_method("face_left"):
						attack_instance.face_left();
				else:
					attack_instance.position = Vector2(position.x + 48, position.y);
				get_parent().add_child(attack_instance);
			else:
				state = EnemyState.MOVING;
				state_machine.travel("Run")
				if abs(target.position.x - position.x) <= follow_range:
					move_position = Vector2(position.x, target.position.y);
				else:
					if position.x < target.position.x:
						move_position = Vector2(target.position.x - (follow_range * randf_range(0.6, 1.0)), target.position.y);
					else:
						move_position = Vector2(target.position.x + (follow_range * randf_range(0.6, 1.0)), target.position.y);

func _physics_process(delta: float) -> void:
	if state == EnemyState.MOVING:
		if move_position.x > position.x and facing_left:
			facing_left = false;
			$Node2D/AnimatedSprite2D.flip_h = false;
		if move_position.x < position.x and !facing_left:
			facing_left = true;
			$Node2D/AnimatedSprite2D.flip_h = true;
		if (move_position - position).length() < attributes.movement_speed * delta:
			position = move_position;
			cooldown = 0.2;
			state = EnemyState.IDLE;
			state_machine.travel("Idle");
		else:
			var move_dir = (move_position - position).normalized();
			position += move_dir * attributes.movement_speed * delta;
	if state == EnemyState.HURTING or state == EnemyState.DYING:
		var knockback_dir = (position - damage_source).normalized();
		if invulnerability == 0.0:
			if state == EnemyState.DYING:
				if position.y > 400:
					queue_free();
				else:
					knockback += 10;
					knockback_dir.y = max(0, knockback_dir.y + 1);
					knockback_dir = knockback_dir.normalized();
			else:
				y_offset = -40;
				cooldown = 0;
				state = EnemyState.IDLE;
		else:
			invulnerability = max(0.0, invulnerability - delta);
			y_offset = -40 - (50 * sin(PI * (0.8 - invulnerability) / 0.8));
		position += knockback_dir * knockback * delta;
		$Node2D.position.y = y_offset;

func assign_target():
	var target_pattern = behavior;
	if behavior == EnemyBehavior.MIXED:
		target_pattern = randi_range(0, 2);
	var valid_targets = GlobalVars.get_targetable_characters();
	match(target_pattern):
		EnemyBehavior.TARGET_RANDOM:
			target_id = valid_targets.pick_random();
		EnemyBehavior.TARGET_WEAKEST:
			var weakest = valid_targets[0];
			for v in valid_targets:
				if GlobalVars.character_attributes[v].current_hp < GlobalVars.character_attributes[weakest].current_hp:
					weakest = v;
			target_id = weakest
		EnemyBehavior.TARGET_STARDOM:
			var starriest = valid_targets[0];
			for v in valid_targets:
				if GlobalVars.character_attributes[v].stardom < GlobalVars.character_attributes[starriest].current_hp:
					starriest = v;
			target_id = starriest;
	target = GlobalVars.get_character_node(target_id);

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("attack"):
		var attack_area = area as Attack;
		if attack_area:
			if attack_area.source != Attack.AttackSource.ENEMY and invulnerability == 0.0 and state != EnemyState.DYING:
				attributes.current_hp = max(0, attributes.current_hp - attack_area.power);
				attack_area.hit();
				if attributes.current_hp == 0:
					state = EnemyState.DYING;
					knockback = attack_area.knockback * 10;
					state_machine.travel("Death");
					invulnerability = 0.8;
					$AnimationPlayer.play("hurt");
					on_death.emit(position);
				else:
					state = EnemyState.HURTING;
					knockback = attack_area.knockback;
					# TEMP
					damage_source = (get_tree().get_first_node_in_group("player") as CombatPlayerController).position;
					invulnerability = 0.8;
					$AnimationPlayer.play("hurt");


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Shoot" and state == EnemyState.ATTACKING:
		state = EnemyState.IDLE;
