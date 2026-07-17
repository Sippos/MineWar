extends "res://scripts/systems/preparation/preparation_world_controller.gd"

func _begin_mode(mode: GameMode.Mode, _scene_path: String, transition_text: String) -> void:
	if _started:
		return
	_started = true
	GameMode.set_mode(mode)
	player.velocity = Vector2.ZERO
	status_label.text = transition_text

	# Keep the gate response immediate while still allowing the status text and
	# movement stop to render once. The generated mine is already alive behind
	# the preparation overworld, so no second world scene is needed.
	await get_tree().process_frame

	var choices := world.get_node_or_null("LoadoutChoices")
	if choices:
		choices.queue_free()
	if interface:
		interface.queue_free()

	base.set_process(true)
	base.set_process_input(true)
	_enable_runtime_upgrade_menu()

	if mode == GameMode.Mode.LINE_WARS:
		# Line Wars keeps the dual-front controller. It converts the preparation
		# peon into the surface builder and lets the hero remain in the mine.
		world.begin_run_from_preparation()
		queue_free()
		return

	# MineWars and Adventure continue inside the world that is already loaded.
	# Releasing the temporary peon restores the real hero at the same gate
	# position and removes the expensive second scene generation.
	var dual_front := get_parent().get_node_or_null("DualFrontController")
	if dual_front and dual_front.has_method("release_to_standard_run"):
		dual_front.release_to_standard_run()
	world.begin_run_from_preparation()
	_ping_mode_bootstraps()
	queue_free()

func _ping_mode_bootstraps() -> void:
	# The Siege and Exploration autoloads listen for node additions. This small
	# transient node makes them rescan after preparation_mode becomes false.
	var ping := Node.new()
	ping.name = "ModeBootstrapPing"
	world.add_child(ping)
	ping.queue_free()
