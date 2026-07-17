extends "res://scripts/systems/preparation/preparation_world_controller.gd"

func _begin_mode(mode: GameMode.Mode, scene_path: String, transition_text: String) -> void:
	if _started:
		return
	_started = true
	GameMode.set_mode(mode)
	Global.apply_selected_loadout()
	Global.save_game()
	player.velocity = Vector2.ZERO
	status_label.text = transition_text
	await get_tree().create_timer(0.16).timeout

	if mode == GameMode.Mode.SIEGE:
		# MineWars begins inside this preparation overworld. The dual-front
		# controller keeps the builder peon on the surface and activates the hero
		# underground without reloading the scene.
		base.set_process(true)
		base.set_process_input(true)
		_enable_runtime_upgrade_menu()
		var choices := world.get_node_or_null("LoadoutChoices")
		if choices:
			choices.queue_free()
		if interface:
			interface.queue_free()
		world.begin_run_from_preparation()
		queue_free()
		return

	# Adventure and Line Wars continue to use their dedicated scenes.
	get_tree().change_scene_to_file(scene_path)
