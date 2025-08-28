extends Resource
class_name EntityAttributes

@export var max_hp : int = 10;
@export var attack : PackedScene;
@export var attack_cooldown : float = 1.0;
@export var defense_multiplier : float = 1.0;
@export var movement_speed : float = 300.0;

var current_hp : int;
