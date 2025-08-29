extends Area2D
## Interface for interactable nodes.
##
## Interactable nodes can be interacted with by [PlayerControllerTopdown2D] nodes.[br]
## Override the [method Interactable.interact] method to implement this interface.

class_name Interactable;

## Perform an action when interacted with by player
func interact(_player : Node):
	pass

func enter_range():
	pass

func exit_range():
	pass
