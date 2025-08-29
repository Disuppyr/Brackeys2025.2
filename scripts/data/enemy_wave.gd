extends Resource
class_name EnemyWave

enum SpawnLocation {
	LEFT,
	RIGHT,
	BOTH
}

@export var spawn_location : SpawnLocation = SpawnLocation.BOTH
@export var enemy_scene : PackedScene;
@export var enemy_count : int;
@export var spawn_interval : float;
@export var next_wave_delay : float;
