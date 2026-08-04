extends Attack

func hit(damage_amount : int = 0):
	pierced += 1;
	GlobalVars.hitstop();
	if damage_amount > 0:
		var dmg_instance = DamageNumberScene.instantiate();
		dmg_instance.global_position = global_position;
		dmg_instance.amount = damage_amount;
		get_tree().current_scene.add_child(dmg_instance);
	if source == AttackSource.ENEMY:
		var camera = get_viewport().get_camera_2d();
		if camera and camera.has_method("shake"):
			camera.shake(4.0, 0.15);
	if pierced >= pierce:
		set_deferred("monitorable",false);
	if !$Timer.is_stopped():
		$Timer.stop();
		attack_end();

func attack_end():
	ending = true;
	$AnimationPlayer.play("fade");
