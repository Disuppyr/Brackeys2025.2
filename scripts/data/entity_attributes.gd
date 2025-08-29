extends Resource
class_name EntityAttributes

@export var max_hp : int = 10;
@export var attack : PackedScene;
@export var attack_power : int = 5;
@export var attack_cooldown : float = 1.0;
@export var defense_multiplier : float = 1.0;
@export var movement_speed : float = 300.0;
@export var energy_dropped : int = 5;

var current_hp : int:
	set = _set_current_hp;

func _set_current_hp(value):
	current_hp = value;
