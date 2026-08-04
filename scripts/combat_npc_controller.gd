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
## How fast the reactive dash burst moves, in pixels/sec.
@export var dash_speed : float = 650.0;
## How long the dash burst lasts, in seconds.
@export var dash_duration : float = 0.15;
## Cooldown before this ally can dash again.
@export var dash_cooldown_max : float = 1.5;
## How close an enemy attack needs to be before this ally reactively dashes away.
@export var dash_danger_radius : float = 70.0;

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
var dash_timer : float = 0.0;
var dash_cooldown_timer : float = 0.0;
var dash_direction : Vector2 = Vector2.ZERO;
## Same single-instance gating as combat_player_controller.gd -- only ever
## set for Bonnie's lasso (see _spawn_attack()), no effect on anyone else.
var active_single_instance_attack : Node = null;

func _ready() -> void:
	state_machine = $AnimationTree["parameters/playback"];
	GlobalVars.character_attributes[character];
	if GlobalVars.has_fortune(character, CharacterFortune.CharacterFortuneType.JINXED):
		GlobalVars.character_attributes[character].current_hp = GlobalVars.character_attributes[character].max_hp / 2;
	assign_target();

func _process(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer = max(0.0, dash_cooldown_timer - delta);
	if state != EnemyState.DYING and dash_timer == 0.0 and dash_cooldown_timer == 0.0:
		_try_reactive_dash();
	if state == EnemyState.IDLE:
		if cooldown > 0.0:
			cooldown = max(0.0, cooldown - delta);
		else:
			if assign_target() == null:
				assign_target();
			if target:
				if abs(abs(target.position.x - position.x) - follow_range) <= 40 and abs(target.position.y - position.y) <= 8.0:
					state = EnemyState.ATTACKING;
					cooldown = GlobalVars.character_attributes[character].attack_cooldown;
					if target.position.x > position.x and facing_left:
						facing_left = false;
						$Node2D/AnimatedSprite2D.flip_h = false;
					if target.position.x < position.x and !facing_left:
						facing_left = true;
						$Node2D/AnimatedSprite2D.flip_h = true;
					state_machine.travel("Shoot");
					_act(facing_left);
				else:
					state = EnemyState.MOVING;
					state_machine.travel("Run")
					if abs(abs(target.position.x - position.x) - follow_range) <= 40:
						move_position = Vector2(position.x, target.position.y);
					else:
						if target.position.x > 0:
							move_position = Vector2(target.position.x - (follow_range * randf_range(0.9, 1.0)), target.position.y);
						else:
							move_position = Vector2(target.position.x + (follow_range * randf_range(0.9, 1.0)), target.position.y);
					_apply_separation();
			else:
				cooldown = 0.5;

## Proximity heuristic, not trajectory prediction: if an enemy-sourced attack
## is close enough to be dangerous, dash straight away from it.
func _try_reactive_dash() -> void:
	for attack_node in get_tree().get_nodes_in_group("attack"):
		var attack_area = attack_node as Attack;
		if attack_area and attack_area.source == Attack.AttackSource.ENEMY:
			var diff = position - attack_area.position;
			var dist = diff.length();
			if dist > 0.0 and dist < dash_danger_radius:
				dash_direction = diff.normalized();
				dash_timer = dash_duration;
				dash_cooldown_timer = dash_cooldown_max;
				return;

func _physics_process(delta: float) -> void:
	if dash_timer > 0.0:
		dash_timer = max(0.0, dash_timer - delta);
		position += dash_direction * dash_speed * delta;
		return;
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

## Decide what this ally does on their attack tick: self-heal if low and able,
## use their special if charged, otherwise the basic attack (still respecting JAMMED).
func _act(facing_left_now : bool) -> void:
	var attrs = GlobalVars.character_attributes[character];
	var hp_fraction = float(attrs.current_hp) / float(attrs.max_hp);
	if hp_fraction <= 0.3 and attrs.current_energy >= attrs.heal_cost:
		attrs.current_energy -= attrs.heal_cost;
		attrs.current_hp = min(attrs.max_hp, attrs.current_hp + attrs.heal_amount);
		return;
	if attrs.special_attack != null and attrs.current_energy >= attrs.special_cost:
		attrs.current_energy -= attrs.special_cost;
		_spawn_attack(attrs.special_attack, facing_left_now);
		return;
	var single_instance_busy = active_single_instance_attack != null and is_instance_valid(active_single_instance_attack);
	if not single_instance_busy and (!GlobalVars.has_fortune(character, CharacterFortune.CharacterFortuneType.JAMMED) or randf() < 0.8):
		_spawn_attack(attrs.attack, facing_left_now);

func _spawn_attack(attack_scene : PackedScene, facing_left_now : bool) -> void:
	var attack_instance = attack_scene.instantiate();
	if facing_left_now:
		attack_instance.position = Vector2(position.x - 48, position.y);
		if attack_instance.has_method("face_left"):
			attack_instance.face_left();
	else:
		attack_instance.position = Vector2(position.x + 48, position.y);
	if attack_instance.has_method("set_source_node"):
		attack_instance.set_source_node(self);
		active_single_instance_attack = attack_instance;
	get_parent().add_child(attack_instance);

## Nudge move_position away from other nearby party members so allies stop
## stacking on the exact same spot. Party NPCs are grouped by character name
## (see GlobalVars.get_character_node), not a shared "party" group. Some
## Pearl attack scenes also (pre-existing, unrelated) tag non-character nodes
## like an AnimationPlayer into the "pearl" group, so this filters to actual
## character controllers rather than assuming every group member is one.
func _apply_separation() -> void:
	for group_name in ["bonnie", "jane", "pearl", "rose"]:
		for other in get_tree().get_nodes_in_group(group_name):
			if other == self or not (other is CombatNPC or other is CombatPlayerController):
				continue;
			var diff = position - other.position;
			var dist = diff.length();
			if dist > 0.0 and dist < 40.0:
				move_position += diff.normalized() * (40.0 - dist) * 0.5;

func assign_target():
	var enemies = get_tree().get_nodes_in_group("enemy") as Array[Enemy];
	enemies.shuffle();
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
				var damage_dealt = attack_area.power;
				if GlobalVars.has_fortune(character, CharacterFortune.CharacterFortuneType.BUBBLE):
					damage_dealt = int(attack_area.power * 0.75);
				GlobalVars.character_attributes[character].current_hp = max(0, GlobalVars.character_attributes[character].current_hp - damage_dealt);
				attack_area.hit(damage_dealt);
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
