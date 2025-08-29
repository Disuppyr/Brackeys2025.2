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

@onready var sprite : AnimatedSprite2D = $Node2D/AnimatedSprite2D;  # Reference to the animated sprite node
@onready var animation_tree : AnimationTree = $AnimationTree;  # Reference to the animation tree

var player_state : PlayerState = PlayerState.MOVING;
var normalized_input : Vector2 = Vector2.ZERO;
var square_velocity : Vector2 = Vector2.ZERO;
var facing_left : bool = false;
var interactable : Object = null;
var interacting : Object = null;
var is_shooting : bool = false;  # Track if player is currently shooting
var shoot_frame_duration : float = 0.2;  # How long to show the shooting animation
var shoot_frame_timer : float = 0.0;  # Timer for shooting animation display

func _enter_tree() -> void:
	position = spawn_position;

func _process(_delta: float) -> void:
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

func _input(_event: InputEvent) -> void:
	pass

func _physics_process(delta: float) -> void:
	if player_state == PlayerState.MOVING:
		# Update shooting timer
		if is_shooting:
			shoot_frame_timer -= delta;
			if shoot_frame_timer <= 0.0:
				is_shooting = false;
		
		# Handle horizontal movement
		if normalized_input.length() > 0.0:
			square_velocity += normalized_input * walk_acceleration;
			if square_velocity.length() > max_walk_speed:
				square_velocity = square_velocity.normalized() * max_walk_speed;
		else:
			square_velocity *= slowdown_multiplier;
		
		# Set horizontal velocity and move
		velocity = Vector2(square_velocity.x, square_velocity.y * 0.5);
		if velocity.x > 0 && facing_left:
			facing_left = false;
		if velocity.x < 0 && !facing_left:
			facing_left = true;
		move_and_slide();
		
		# Update animations based on state
		_update_animations();
		
		# Update sprite flip
		if sprite:
			sprite.flip_h = facing_left;

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

func trigger_shoot_animation():
	"""Call this method when the player shoots to show shoot animation"""
	is_shooting = true;
	shoot_frame_timer = shoot_frame_duration;

func _update_animations():
	"""Update AnimationTree state machine based on current player state"""
	if not animation_tree:
		return
	
	var state_machine = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if not state_machine:
		return
	
	# Determine which animation to play based on state priority
	if is_shooting:
		state_machine.travel("Shoot")
	elif normalized_input.length() > 0.0:
		state_machine.travel("Run")
	else:
		state_machine.travel("Idle")
