extends Interactable

var state_machine : AnimationNodeStateMachinePlayback;

func _ready() -> void:
	state_machine = $AnimationTree["parameters/playback"];

func interact(_player : Node):
	state_machine.travel("collect");
	$Label.hide();
	monitorable = false;
	GlobalVars.pick_up_item(GlobalVars.ItemType.HARD_TACK);

func enter_range():
	$Label.show();

func exit_range():
	$Label.hide();

func free_hard_tack(anim_name : StringName):
	if anim_name == "collect":
		get_tree().call_group("player", "end_interact");
		queue_free();
