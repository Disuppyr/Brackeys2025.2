extends Attack



func hit():
	pierced += 1;
	if pierced >= pierce:
		set_deferred("monitorable",false);
	if !$Timer.is_stopped():
		$Timer.stop();
		attack_end();

func attack_end():
	ending = true;
	$AnimationPlayer.play("fade");
