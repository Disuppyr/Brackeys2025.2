extends CharacterBody2D
class_name PlayerController

enum PlayerState {
	MOVING,
	INTERACTING
}

## Acceleration while in walking movement mode.
@export var walk_acceleration : float = 60.0;
## Max movement speed while in walking movement mode.
@export var max_walk_speed : float = 300.0;
## Slowdown multiplier for both movement modes when no directional input is being held.[br][code]0.0[/code] stops movement immediately, while [code]1.0[/code] enables frictionless movement.
@export_range(0, 1.0) var slowdown_multiplier : float = 0.7;
## Spawn position for the player.
@export var spawn_position : Vector2 = Vector2.ZERO;

var player_state : PlayerState = PlayerState.MOVING;
var normalized_input : Vector2 = Vector2.ZERO;
var square_velocity : Vector2 = Vector2.ZERO;
var look_pos : Vector2 = Vector2.ZERO;
var interactable : Object = null;
var interacting : Object = null;

func _enter_tree() -> void:
	position = spawn_position;

func _process(delta: float) -> void:
	var move_input = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"));
	if move_input.length() > 1.0:
		move_input = move_input.normalized();
	normalized_input = move_input;
		
	if Input.get_action_strength("interact") > 0 and player_state == PlayerState.MOVING:
		var temp_interactable = interactable as Interactable;
		if temp_interactable:
			interacting = interactable
			interactable = null;
			temp_interactable.interact(self);
			player_state = PlayerState.INTERACTING;
			velocity = Vector2.ZERO;

func _input(event: InputEvent) -> void:
	pass

func _physics_process(delta: float) -> void:
	if player_state == PlayerState.MOVING:
		if normalized_input.length() > 0.0:
			square_velocity += normalized_input * walk_acceleration;
			if square_velocity.length() > max_walk_speed:
				square_velocity = square_velocity.normalized() * max_walk_speed;
		else:
			square_velocity *= slowdown_multiplier;
		velocity = Vector2(square_velocity.x, square_velocity.y * 0.5);
		move_and_slide();

func _on_area_2D_entered(area: Area2D) -> void:
	if area as Interactable != null:
		interactable = area;

func _on_area_2d_exited(area: Area2D) -> void:
	if area == interactable:
		interactable = null;

func end_interact():
	player_state = PlayerState.MOVING;
	interactable = interacting;
	interacting = null;
