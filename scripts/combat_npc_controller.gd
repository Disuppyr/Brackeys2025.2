extends Area2D
class_name CombatNPC

enum EnemyState {
	IDLE,
	MOVING,
	ATTACKING,
	HURTING,
	DYING
}

@export var character : CharacterAttributes.Character;
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
	GlobalVars.character_attributes[character];
	if GlobalVars.has_fortune(character, CharacterFortune.CharacterFortuneType.JINXED):
		GlobalVars.character_attributes[character].current_hp = GlobalVars.character_attributes[character].max_hp / 2;
	assign_target();

func _process(delta: float) -> void:
	if state == EnemyState.IDLE:
		if cooldown > 0.0:
			cooldown = max(0.0, cooldown - delta);
		else:
			if assign_target() == null:
				assign_target();
			if target:
				if abs(target.position.x - position.x) <= follow_range and abs(target.position.y - position.y) <= 32.0:
					state = EnemyState.ATTACKING;
					cooldown = GlobalVars.character_attributes[character].attack_cooldown;
					if target.position.x > position.x and facing_left:
						facing_left = false;
						$Node2D/AnimatedSprite2D.flip_h = false;
					if target.position.x < position.x and !facing_left:
						facing_left = true;
						$Node2D/AnimatedSprite2D.flip_h = true;
					state_machine.travel("Shoot");
					#if !GlobalVars.has_fortune(character, CharacterFortune.CharacterFortuneType.JAMMED) or randf() < 0.8:
						#var attack_instance = GlobalVars.character_attributes[character].attack.instantiate();
						## TODO set attack power here
						#if facing_left:
							#attack_instance.position = Vector2(position.x - 48, position.y);
							#if attack_instance.has_method("face_left"):
								#attack_instance.face_left();
						#else:
							#attack_instance.position = Vector2(position.x + 48, position.y);
						#get_parent().add_child(attack_instance);
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
			else:
				cooldown = 0.5;

func _physics_process(delta: float) -> void:
	if state == EnemyState.MOVING:
		if move_position.x > position.x and facing_left:
			facing_left = false;
			$Node2D/AnimatedSprite2D.flip_h = false;
		if move_position.x < position.x and !facing_left:
			facing_left = true;
			$Node2D/AnimatedSprite2D.flip_h = true;
		if (move_position - position).length() < GlobalVars.character_attributes[character].movement_speed * delta:
			position = move_position;
			cooldown = 0.2;
			state = EnemyState.IDLE;
			state_machine.travel("Idle");
		else:
			var move_dir = (move_position - position).normalized();
			position += move_dir * GlobalVars.character_attributes[character].movement_speed * delta;
	if state == EnemyState.HURTING or state == EnemyState.DYING:
		var knockback_dir = Vector2.DOWN;
		if invulnerability == 0.0:
			if state == EnemyState.DYING:
				if position.y > 400:
					queue_free();
				else:
					knockback += 10;
					knockback_dir.y = max(0, knockback_dir.y + 1);
					knockback_dir = knockback_dir.normalized();
					position += knockback_dir * knockback * delta;
			else:
				y_offset = -40;
				cooldown = 0;
				state = EnemyState.IDLE;
		else:
			invulnerability = max(0.0, invulnerability - delta);
			y_offset = -40 - (50 * sin(PI * (0.8 - invulnerability) / 0.8));
		#$Node2D.position.y = y_offset;

func assign_target():
	var enemies = get_tree().get_nodes_in_group("enemy") as Array[Enemy];
	var enemy_targeted = null;
	if enemies.size() > 0:
		for enemy in enemies:
			if enemy.attributes.current_hp > 0:
				enemy_targeted = enemy;
				break;
	target = enemy_targeted

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("attack"):
		var attack_area = area as Attack;
		if attack_area:
			if attack_area.source == Attack.AttackSource.ENEMY and invulnerability == 0.0 and state != EnemyState.DYING:
				if GlobalVars.has_fortune(character, CharacterFortune.CharacterFortuneType.BUBBLE):
					GlobalVars.character_attributes[character].current_hp = max(0, GlobalVars.character_attributes[character].current_hp - (attack_area.power * 0.75));
				else:
					GlobalVars.character_attributes[character].current_hp = max(0, GlobalVars.character_attributes[character].current_hp - attack_area.power);
				attack_area.hit();
				if GlobalVars.character_attributes[character].current_hp == 0:
					state = EnemyState.DYING;
					knockback = attack_area.knockback * 10;
					state_machine.travel("Death");
					invulnerability = 0.8;
					$AnimationPlayer.play("hurt");
					GlobalVars.character_attributes[character].incapacitated = true;
				else:
					state = EnemyState.HURTING;
					knockback = attack_area.knockback;
					# TEMP
					#damage_source = (get_tree().get_first_node_in_group("player") as CombatPlayerController).position;
					invulnerability = 0.8;
					$AnimationPlayer.play("hurt");

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Shoot" and state == EnemyState.ATTACKING:
		state = EnemyState.IDLE;
