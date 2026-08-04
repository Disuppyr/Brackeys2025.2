extends ProjectileAttack

## Must match the loop sprite's own position.y in bonnie_attack.tscn, so the
## rope's two ends actually line up with where the loop and Bonnie's hand are.
const ROPE_Y_OFFSET : float = -40.0;

## Whoever fired this (player or ally CombatNPC), so the rope's hand-end can
## keep tracking them even if they keep moving after the throw -- rather than
## staying pinned to wherever they were standing at the moment of firing.
var source_node : Node2D = null;

func set_source_node(node : Node2D) -> void:
	source_node = node;

func _physics_process(delta: float) -> void:
	super._physics_process(delta);
	var hand_point = Vector2(0.0, ROPE_Y_OFFSET);
	if source_node and is_instance_valid(source_node):
		# Offset must be added in world space BEFORE converting to local --
		# adding it after to_local() means it inherits this node's own
		# rotation, so it flips from "above" to "below" when face_left()
		# rotates the whole Path2D 180 degrees.
		hand_point = to_local(source_node.global_position + Vector2(0.0, ROPE_Y_OFFSET));
	# Same world-space-then-to_local() requirement as hand_point above --
	# PathFollow2D.position is already in Path2D's local space, so building
	# the loop-end point directly from it (rather than routing through
	# global_position) skips the Path2D's own rotation entirely, flipping
	# the offset from "above" to "below" whenever face_left() rotates the
	# whole Path2D 180 degrees. This was the actual cause of the lasso
	# reading as "drifting down" while facing left.
	var loop_point = to_local($PathFollow2D.global_position + Vector2(0.0, ROPE_Y_OFFSET));
	# Reassigns the whole array (rather than indexed assignment into the
	# Line2D's `points`) to avoid relying on engine-property index-mutation
	# semantics.
	$Rope.points = PackedVector2Array([
		hand_point,
		loop_point
	]);
