extends PlayerController
class_name CombatPlayerController

@export var auto_attack_cooldown : float = 0.35;
## How fast the dash burst moves, in pixels/sec.
@export var dash_speed : float = 700.0;
## How long the dash burst lasts, in seconds.
@export var dash_duration : float = 0.15;
## Cooldown before dash can be used again. Its own resource, separate from
## energy (which already gates Special/Heal).
@export var dash_cooldown_max : float = 1.2;

var targets : Array[Node2D] = [];
var current_auto_attack_cooldown : float = 1.0;
var knockback : float;
var invulnerability : float = 0.0;
var dash_timer : float = 0.0;
var dash_cooldown_timer : float = 0.0;
var dash_direction : Vector2 = Vector2.ZERO;
## Tracks a still-in-flight attack that must fully disappear before another
## can be fired (currently only Bonnie's lasso -- identified by having
## set_source_node(), see position_and_spawn_attack()). Every other
## character's attack never sets this, so it has no effect on them.
var active_single_instance_attack : Node = null;

func _ready() -> void:
	current_auto_attack_cooldown = 0.0;

func _physics_process(delta: float) -> void:
	super._physics_process(delta);
	if invulnerability > 0.0:
		invulnerability = max(0.0, invulnerability - delta);
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer = max(0.0, dash_cooldown_timer - delta);
	if dash_timer > 0.0:
		# Overrides this frame's normal movement with a straight burst in
		# dash_direction. No invincibility -- this is repositioning-only.
		dash_timer = max(0.0, dash_timer - delta);
		velocity = dash_direction * dash_speed;
		square_velocity = velocity;
		move_and_slide();
	if facing_left && $TargetingArea.rotation == 0:
		$TargetingArea.rotation = PI;
	if !facing_left && $TargetingArea.rotation != 0:
		$TargetingArea.rotation = 0;
	if current_auto_attack_cooldown > 0.0:
		current_auto_attack_cooldown = max(0.0, current_auto_attack_cooldown - delta);
	if player_state != PlayerState.DYING:
		if player_state == PlayerState.MOVING and dash_timer == 0.0 and dash_cooldown_timer == 0.0 and Input.is_action_just_pressed("dash"):
			var dir = normalized_input;
			if dir == Vector2.ZERO:
				dir = Vector2(-1.0 if facing_left else 1.0, 0.0);
			dash_direction = dir.normalized();
			dash_timer = dash_duration;
			dash_cooldown_timer = dash_cooldown_max;
		var single_instance_busy = active_single_instance_attack != null and is_instance_valid(active_single_instance_attack);
		if current_auto_attack_cooldown == 0.0 and not single_instance_busy and Input.is_action_pressed("attack"):
			var attack_instance = GlobalVars.character_attributes[GlobalVars.player_character].attack.instantiate();
			position_and_spawn_attack(attack_instance);
			current_auto_attack_cooldown = auto_attack_cooldown;
			trigger_shoot_animation();
		if Input.is_action_just_pressed("special"):
			try_use_special();
		if Input.is_action_just_pressed("heal"):
			try_self_heal();
		if Input.is_action_just_pressed("item"):
			GlobalVars.use_held_item();
	if player_state == PlayerState.DYING:
		var knockback_dir = Vector2.DOWN;
		if position.y > 400:
			queue_free();
		else:
			knockback += 10;
			knockback_dir.y = max(0, knockback_dir.y + 1);
			knockback_dir = knockback_dir.normalized();
			position += knockback_dir * knockback * delta;

func position_and_spawn_attack(attack_instance : Node2D) -> void:
	if facing_left:
		attack_instance.position = Vector2(position.x - 48, position.y);
		if attack_instance.has_method("face_left"):
			attack_instance.face_left();
	else:
		attack_instance.position = Vector2(position.x + 48, position.y);
	if attack_instance.has_method("set_source_node"):
		attack_instance.set_source_node(self);
		active_single_instance_attack = attack_instance;
	get_parent().add_child(attack_instance);

func try_use_special() -> void:
	var attributes = GlobalVars.character_attributes[GlobalVars.player_character];
	if attributes.special_attack == null or attributes.current_energy < attributes.special_cost:
		return;
	attributes.current_energy -= attributes.special_cost;
	var special_instance = attributes.special_attack.instantiate();
	position_and_spawn_attack(special_instance);
	trigger_shoot_animation();

func try_self_heal() -> void:
	var attributes = GlobalVars.character_attributes[GlobalVars.player_character];
	if attributes.current_energy < attributes.heal_cost or attributes.current_hp >= attributes.max_hp:
		return;
	attributes.current_energy -= attributes.heal_cost;
	attributes.current_hp = min(attributes.max_hp, attributes.current_hp + attributes.heal_amount);

func on_area_enter_attack(area: Area2D) -> void:
	if area.is_in_group("attack"):
		var attack_area = area as Attack;
		if attack_area:
			if attack_area.source == Attack.AttackSource.ENEMY and invulnerability == 0.0 and player_state != PlayerState.DYING:
				var damage_dealt = attack_area.power;
				if GlobalVars.has_fortune(GlobalVars.player_character, CharacterFortune.CharacterFortuneType.BUBBLE):
					damage_dealt = int(attack_area.power * 0.75);
				GlobalVars.character_attributes[GlobalVars.player_character].current_hp = max(0, GlobalVars.character_attributes[GlobalVars.player_character].current_hp - damage_dealt);
				attack_area.hit(damage_dealt);
				if GlobalVars.character_attributes[GlobalVars.player_character].current_hp == 0:
					player_state = PlayerState.DYING;
					knockback = attack_area.knockback * 10;
					#state_machine.travel("Death");
					invulnerability = 0.8;
					$Node2D/AnimatedSprite2D/AnimationPlayer.play("hurt");
					GlobalVars.character_attributes[GlobalVars.player_character].incapacitated = true;
				else:
					knockback = attack_area.knockback;
					# TEMP
					#damage_source = (get_tree().get_first_node_in_group("player") as CombatPlayerController).position;
					invulnerability = 0.8;
					$Node2D/AnimatedSprite2D/AnimationPlayer.play("hurt");

func _on_targeting_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		targets.append(area);

func _on_targeting_area_exited(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		if targets.has(area):
			targets.remove_at(targets.find(area));
