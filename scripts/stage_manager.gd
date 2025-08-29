extends Node
class_name StageManager

signal on_spawn_next_wave;
signal on_stage_complete;

@export var enemy_waves : Array[EnemyWave];
@export var bgm : AudioStreamPlayer;
@export var spawn_pos_left : Vector2;
@export var spawn_pos_right : Vector2;
@export var explosion : PackedScene;
@export var item_drops : Array[PackedScene];
@export var item_rate : float = 0.05;

var current_wave : int = 0;
var no_wave_delay : bool = false;
var scale_multiplier : float = 1.0;
var do_explosions : bool = false;
var do_energy_boost : bool = false;
var do_power_boost : bool = false;

func _ready() -> void:
	on_spawn_next_wave.connect(await spawn_next_wave);
	apply_stage_fortune();

func _exit_tree() -> void:
	remove_stage_fortune();

func _process(delta: float) -> void:
	if no_wave_delay:
		if get_tree().get_node_count_in_group("enemy") == 0:
			no_wave_delay = false;
			on_spawn_next_wave.emit();

func spawn_next_wave():
	if current_wave < enemy_waves.size():
		for i in range(enemy_waves[current_wave].enemy_count):
			var spawned_enemy = enemy_waves[current_wave].enemy_scene.instantiate() as Enemy;
			spawned_enemy.scale *= scale_multiplier;
			#if scale_multiplier < 1.0: 
				#spawned_enemy.attributes.movement_speed = 450.0;
			#if scale_multiplier > 1.0:
				#spawned_enemy.attributes.movement_speed = 175.0;
			#if randf() <= item_rate:
				#spawned_enemy.on_death.connect(spawn_item();
			#if do_explosions:
				#spawned_enemy.on_death.connect(spawn_explosion());
			#if do_energy_boost:
				#spawned_enemy.attributes.energy_dropped *= 1.6;
			#if do_power_boost:
				#spawned_enemy.attributes.attack_power *= 1.6;
			if enemy_waves[current_wave].spawn_location == EnemyWave.SpawnLocation.LEFT or (enemy_waves[current_wave].spawn_location == EnemyWave.SpawnLocation.BOTH and randi_range(0, 1) == 0):
				spawned_enemy.position = Vector2(spawn_pos_left.x, spawn_pos_left.y + randi_range(-200, 200));
			else:
				spawned_enemy.position = Vector2(spawn_pos_right.x, spawn_pos_right.y + randi_range(-200, 200));
			add_child(spawned_enemy);
			if enemy_waves[current_wave].spawn_interval > 0:
				await get_tree().create_timer(enemy_waves[current_wave].spawn_interval).timeout;
		current_wave += 1;
		if enemy_waves[current_wave].next_wave_delay >= 0:
			get_tree().create_timer(enemy_waves[current_wave].next_wave_delay).timeout.connect(on_spawn_next_wave.emit);
		else:
			no_wave_delay = true;
	else:
		on_stage_complete.emit();

func apply_stage_fortune():
	if GlobalVars.stage_fortune != null:
		match(GlobalVars.stage_fortune.type):
			StageFortune.StageFortuneType.TINY_LAND:
				for wave in enemy_waves:
					if wave.enemy_count > 1:
						wave.enemy_count *= 2;
					if wave.spawn_interval > 0:
						wave.spawn_interval /= 2;
				scale_multiplier = 0.6;
			StageFortune.StageFortuneType.GIANT_LAND:
				for wave in enemy_waves:
					if wave.enemy_count > 1:
						wave.enemy_count /= 2;
					if wave.spawn_interval > 0:
						wave.spawn_interval *= 2;
				scale_multiplier = 1.6;
			StageFortune.StageFortuneType.CHICKEN_PARTY:
				item_rate = min(item_rate * 3, 1.0);
			StageFortune.StageFortuneType.CHAOTIC_RAVE:
				do_explosions = true;
			StageFortune.StageFortuneType.SKATE_PARK:
				for attributes in GlobalVars.character_attributes:
					attributes.movement_speed = 500.0;
			StageFortune.StageFortuneType.BISCUIT_RUSH:
				do_energy_boost = true;
			StageFortune.StageFortuneType.DARWINS_STAGE:
				do_power_boost = true;

func remove_stage_fortune():
	if GlobalVars.stage_fortune != null:
		if GlobalVars.stage_fortune.type == StageFortune.StageFortuneType.SKATE_PARK:
			for attributes in GlobalVars.character_attributes:
				attributes.movement_speed = 300.0;

func spawn_item(position : Vector2):
	if item_drops.size() > 0:
		var item = (item_drops.pick_random() as PackedScene).instantiate() as Node2D;
		item.position = position;
		add_child(item);

func spawn_explosion(position : Vector2):
	var new_explosion = explosion.instantiate() as Node2D;
	new_explosion.position = position;
	add_child(new_explosion);
