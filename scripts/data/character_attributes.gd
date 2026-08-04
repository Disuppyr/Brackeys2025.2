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

var current_energy : int = 0:
	set = _set_current_energy;

var incapacitated : bool = false;

## Reputation Actions state (reset each Camp Prep phase, see camp.gd)
var allied_with_player : bool = false;
var sitting_out : bool = false;
var conspired_this_phase : bool = false;
var boasted_this_phase : bool = false;

func _set_current_hp(value):
	super(value);
	changed.emit();

func _set_current_energy(value):
	current_energy = value;
	changed.emit();
