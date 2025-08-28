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
## Hop physics settings
@export var hop_force : float = 150.0;  # Initial upward force for hop
@export var hop_gravity : float = 1000.0;  # Gravity strength for hop
@export var hop_cooldown : float = 0.1;  # Time between hops
@export var hop_rotation_speed : float = 20.0;  # Rotation speed during hop (degrees per second)
## Squash and stretch settings
@export var squash_stretch_speed : float = 8.0;  # Speed of the squash/stretch oscillation
@export var squash_stretch_amount : float = 0.2;  # How much to squash/stretch (0.2 = 20%)

@onready var sprite : AnimatedSprite2D = $Node2D/AnimatedSprite2D;  # Reference to the animated sprite node

var player_state : PlayerState = PlayerState.MOVING;
var normalized_input : Vector2 = Vector2.ZERO;
var square_velocity : Vector2 = Vector2.ZERO;
var facing_left : bool = false;
var interactable : Object = null;
var interacting : Object = null;
var hop_velocity_y : float = 0.0;  # Current vertical velocity for hopping
var hop_cooldown_timer : float = 0.0;  # Timer for hop cooldown
var is_on_ground : bool = true;  # Track if player is on ground
var sprite_y_offset : float = 0.0;  # Vertical offset for sprite during hop
var sprite_rotation : float = 0.0;  # Current rotation of sprite
var rotation_direction : float = 1.0;  # Direction of rotation (1.0 for clockwise, -1.0 for counter-clockwise)
var squash_stretch_time : float = 0.0;  # Timer for squash/stretch animation
var is_shooting : bool = false;  # Track if player is currently shooting
var shoot_frame_duration : float = 0.2;  # How long to show the shooting frame
var shoot_frame_timer : float = 0.0;  # Timer for shooting frame display

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
		# Update timers
		hop_cooldown_timer -= delta;
		squash_stretch_time += delta;
		
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
			
			# Trigger hop if on ground and cooldown is over
			if is_on_ground and hop_cooldown_timer <= 0.0:
				hop_velocity_y = -hop_force;  # Negative for upward movement
				is_on_ground = false;
				hop_cooldown_timer = hop_cooldown;
				# Alternate rotation direction for each hop
				rotation_direction *= -1.0;
		else:
			square_velocity *= slowdown_multiplier;
		
		# Apply gravity to hop velocity and update sprite offset
		if not is_on_ground:
			hop_velocity_y += hop_gravity * delta;
			sprite_y_offset += hop_velocity_y * delta;
			
			# Apply rotation during hop using the alternating direction
			sprite_rotation += deg_to_rad(hop_rotation_speed) * rotation_direction * delta;
			
			# Check if sprite should land back on ground
			if sprite_y_offset >= 40.0:
				sprite_y_offset = 40.0;
				hop_velocity_y = 0.0;
				is_on_ground = true;
				sprite_rotation = 0.0;  # Reset rotation when landing
		else:
			# Smoothly return rotation to 0 when on ground
			if abs(sprite_rotation) > 0.01:
				sprite_rotation = lerp(sprite_rotation, 0.0, 10.0 * delta);
			else:
				sprite_rotation = 0.0;
		
		# Set horizontal velocity and move (only the character body, not sprite)
		velocity = Vector2(square_velocity.x, square_velocity.y * 0.5);
		if velocity.x > 0 && facing_left:
			facing_left = false;
		if velocity.x < 0 && !facing_left:
			facing_left = true;
		move_and_slide();
		
		# Update sprite position, rotation, horizontal flip, frame, and squash/stretch
		if sprite:
			sprite.position.y = sprite_y_offset;
			sprite.rotation = sprite_rotation;
			sprite.flip_h = facing_left;
			
			# Set frame based on current state (shooting takes priority)
			if is_shooting:
				sprite.frame = 3;  # Shooting frame
				# Reset scale to normal when shooting
				sprite.scale.y = sprite.scale.x;
			elif normalized_input.length() > 0.0:
				sprite.frame = 1;  # Moving frame
				# Reset scale to normal when moving
				sprite.scale.y = sprite.scale.x;
			else:
				sprite.frame = 0;  # Idle frame
				# Apply squash and stretch oscillation only when idle
				var squash_stretch_factor = 1.0 + sin(squash_stretch_time * squash_stretch_speed) * squash_stretch_amount;
				sprite.scale.y = sprite.scale.x * squash_stretch_factor;

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
	"""Call this method when the player shoots to show frame 3"""
	is_shooting = true;
	shoot_frame_timer = shoot_frame_duration;
