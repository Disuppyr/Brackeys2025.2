extends EntityAttributes
class_name CharacterAttributes

enum Character {
	BONNIE,
	JANE,
	PEARL,
	ROSE
}

@export var character : Character;
@export var stardom : int = 0;
@export var rapport : int = 0;
@export var max_energy : int = 50;
@export var special_attack : PackedScene;
@export var special_cost : int = 50;
@export var heal_amount : int = 10;
@export var heal_cost : int = 10;

var current_energy : int = 0;
