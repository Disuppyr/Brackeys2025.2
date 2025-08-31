extends PlayerController
class_name CombatPlayerController

@export var auto_attack_cooldown : float = 1.0;
@export var attack : PackedScene;

var targets : Array[Node2D] = [];
var current_auto_attack_cooldown : float = 1.0;
var knockback : float;
var invulnerability : float = 0.0;

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
	if player_state == PlayerState.DYING:
		var knockback_dir = Vector2.DOWN;
		if position.y > 400:
			queue_free();
		else:
			knockback += 10;
			knockback_dir.y = max(0, knockback_dir.y + 1);
			knockback_dir = knockback_dir.normalized();
			position += knockback_dir * knockback * delta;

func on_area_enter_attack(area: Area2D) -> void:
	if area.is_in_group("attack"):
		var attack_area = area as Attack;
		if attack_area:
			if attack_area.source == Attack.AttackSource.ENEMY and invulnerability == 0.0 and player_state != PlayerState.DYING:
				if GlobalVars.has_fortune(GlobalVars.player_character, CharacterFortune.CharacterFortuneType.BUBBLE):
					GlobalVars.character_attributes[GlobalVars.player_character].current_hp = max(0, GlobalVars.character_attributes[GlobalVars.player_character].current_hp - (attack_area.power * 0.75));
				else:
					GlobalVars.character_attributes[GlobalVars.player_character].current_hp = max(0, GlobalVars.character_attributes[GlobalVars.player_character].current_hp - attack_area.power);
				attack_area.hit();
				if GlobalVars.character_attributes[GlobalVars.player_character].current_hp == 0:
					player_state = PlayerState.DYING;
					knockback = attack_area.knockback * 10;
					#state_machine.travel("Death");
					invulnerability = 0.8;
					$AnimationPlayer.play("hurt");
					GlobalVars.character_attributes[GlobalVars.player_character].incapacitated = true;
				else:
					knockback = attack_area.knockback;
					# TEMP
					#damage_source = (get_tree().get_first_node_in_group("player") as CombatPlayerController).position;
					invulnerability = 0.8;
					$AnimationPlayer.play("hurt");

func _on_targeting_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		targets.append(area);

func _on_targeting_area_exited(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		if targets.has(area):
			targets.remove_at(targets.find(area));
