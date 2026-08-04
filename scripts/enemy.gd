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

signal on_death(position);

@export var attributes : EntityAttributes;
@export var behavior : EnemyBehavior = EnemyBehavior.TARGET_RANDOM;
@export var follow_range : float;

var state : EnemyState = EnemyState.IDLE;
var invulnerability : float = 0;
var y_offset : float = -32.0;
var knockback : float = 0.0;
var damage_source : Vector2 = Vector2.ZERO;
var attack_cooldown : float = 0.0;
var cooldown : float = 0.0;
var target_id : int;
var target : Node2D;
var move_position : Vector2;
var facing_left : bool = false;
var state_machine : AnimationNodeStateMachinePlayback;
var health_bar_fill : ColorRect;
var health_bar_full_width : float = 0.0;
var retarget_timer : float = 0.0;
var flee_timer : float = 0.0;

const FLEE_HP_THRESHOLD : float = 0.3;
const FLEE_DURATION : float = 2.5;

func _ready() -> void:
	state_machine = $AnimationTree["parameters/playback"];
	attributes.current_hp = attributes.max_hp;
	cooldown = 0.5;
	retarget_timer = randf_range(4.0, 7.0);
	health_bar_fill = get_node_or_null("HealthBarFill");
	if health_bar_fill:
		health_bar_full_width = health_bar_fill.size.x;
	update_health_bar();

func update_health_bar() -> void:
	if health_bar_fill:
		health_bar_fill.size.x = health_bar_full_width * clampf(float(attributes.current_hp) / float(attributes.max_hp), 0.0, 1.0);

func _process(delta: float) -> void:
	if flee_timer > 0.0:
		flee_timer = max(0.0, flee_timer - delta);
	retarget_timer = max(0.0, retarget_timer - delta);
	if state == EnemyState.IDLE:
		if cooldown > 0.0:
			cooldown = max(0.0, cooldown - delta);
		else:
			if target == null or !GlobalVars.get_targetable_characters().has(target_id) or retarget_timer == 0.0:
				assign_target();
				retarget_timer = randf_range(4.0, 7.0);
			if target:
				if flee_timer > 0.0:
					state = EnemyState.MOVING;
					state_machine.travel("Run");
					var away_dir = (position - target.position);
					if away_dir == Vector2.ZERO:
						away_dir = Vector2.RIGHT;
					move_position = position + away_dir.normalized() * follow_range * 0.5;
					_apply_separation();
				elif abs(target.position.x - position.x) <= follow_range and abs(target.position.y - position.y) <= 32.0:
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
					attack_cooldown = attributes.attack_cooldown;
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
					_apply_separation();
			else:
				cooldown = 0.5;

## Nudge move_position away from other nearby enemies so they stop stacking
## on the exact same spot. camp.tscn's root is (pre-existing, unrelated)
## also tagged into the "enemy" group, so this filters to actual Enemy nodes.
func _apply_separation() -> void:
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self or not other is Enemy:
			continue;
		var diff = position - other.position;
		var dist = diff.length();
		if dist > 0.0 and dist < 40.0:
			move_position += diff.normalized() * (40.0 - dist) * 0.5;

func _physics_process(delta: float) -> void:
	if state == EnemyState.ATTACKING:
		if attack_cooldown > 0:
			attack_cooldown = max(0.0, attack_cooldown - delta);
		else:
			state = EnemyState.IDLE;
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
	valid_targets.shuffle();
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
				if GlobalVars.character_attributes[v].stardom > GlobalVars.character_attributes[starriest].stardom:
					starriest = v;
			target_id = starriest;
	target = GlobalVars.get_character_node(target_id);

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("attack"):
		var attack_area = area as Attack;
		if attack_area:
			if attack_area.source != Attack.AttackSource.ENEMY and invulnerability == 0.0 and state != EnemyState.DYING:
				attributes.current_hp = max(0, attributes.current_hp - attack_area.power);
				attack_area.hit(attack_area.power);
				update_health_bar();
				if attributes.current_hp > 0 and float(attributes.current_hp) / float(attributes.max_hp) <= FLEE_HP_THRESHOLD:
					flee_timer = FLEE_DURATION;
				if state == EnemyState.ATTACKING:
					attack_cooldown = 0;
				if attributes.current_hp == 0:
					state = EnemyState.DYING;
					knockback = attack_area.knockback * 10;
					state_machine.travel("Death");
					invulnerability = 0.8;
					$AnimationPlayer.play("hurt");
					GlobalVars.character_attributes[attack_area.source].current_energy = min(GlobalVars.character_attributes[attack_area.source].max_energy, GlobalVars.character_attributes[attack_area.source].current_energy + attributes.energy_dropped);
					GlobalVars.KO_count[attack_area.source] += 1;
					GlobalVars.last_KO = attack_area.source;
					GlobalVars.award_stardom(attack_area.source, GlobalVars.STARDOM_PER_KO);
					on_death.emit(position);
				else:
					state = EnemyState.HURTING;
					knockback = attack_area.knockback;
					# TEMP
					if GlobalVars.get_character_node(attack_area.source) != null:
						damage_source = GlobalVars.get_character_node(attack_area.source).position;
					invulnerability = 0.8;
					$AnimationPlayer.play("hurt");


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Shoot" and state == EnemyState.ATTACKING:
		state = EnemyState.IDLE;
