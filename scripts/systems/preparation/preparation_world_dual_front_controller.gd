extends "res://scripts/systems/preparation/preparation_world_controller.gd"

const SEAMLESS_MINEWARS_GATE_Y := 104.0
const SEAMLESS_MINEWARS_GATE_HALF_WIDTH := 112.0
const SEAMLESS_LINE_WARS_TRIGGER_Y := -468.0
const SEAMLESS_LINE_WARS_HALF_WIDTH := 96.0
const SEAMLESS_LINE_WARS_DIG_START_Y := -220.0
const SEAMLESS_ADVENTURE_GATE_X := 338.0
const SEAMLESS_ADVENTURE_GATE_MIN_Y := -36.0
const SEAMLESS_ADVENTURE_GATE_MAX_Y := 108.0

var _last_line_wars_dig_row := 999999

func _process(delta: float) -> void:
	if _started or world == null or player == null:
		return
	_float_time += delta
	_animate_base_previews()
	_update_nearby_choice()
	_dig_line_wars_entrance()

	if player.position.y >= SEAMLESS_MINEWARS_GATE_Y and absf(player.position.x) <= SEAMLESS_MINEWARS_GATE_HALF_WIDTH:
		_begin_mode(GameMode.Mode.SIEGE, RUN_SCENE, "Descending into MineWars...")
	elif player.position.y <= SEAMLESS_LINE_WARS_TRIGGER_Y and absf(player.position.x) <= SEAMLESS_LINE_WARS_HALF_WIDTH:
		_begin_mode(GameMode.Mode.LINE_WARS, LINE_WARS_SCENE, "Breaking through to Line Wars...")
	elif player.position.x >= SEAMLESS_ADVENTURE_GATE_X and player.position.y >= SEAMLESS_ADVENTURE_GATE_MIN_Y and player.position.y <= SEAMLESS_ADVENTURE_GATE_MAX_Y:
		_begin_mode(GameMode.Mode.EXPLORATION, RUN_SCENE, "Setting out on an Adventure...")

func _carve_mode_routes() -> void:
	# MineWars already uses the existing lower entrance. Adventure remains an
	# open side corridor. The northern LineWars route deliberately stays solid:
	# the peon carves it live while walking upward, making the mode transition
	# part of the same physical movement instead of a menu-like scene jump.
	var previous_generation_flag := bool(world.world_generation_in_progress)
	world.world_generation_in_progress = true
	for x in range(5, 9):
		for y in range(-2, 2):
			world.on_cell_dug(Vector2i(x, y))
	world.world_generation_in_progress = previous_generation_flag

func _dig_line_wars_entrance() -> void:
	if player.position.y > SEAMLESS_LINE_WARS_DIG_START_Y:
		return
	if absf(player.position.x) > SEAMLESS_LINE_WARS_HALF_WIDTH:
		return

	var block_layer := world.get_node_or_null("BlockLayer") as TileMapLayer
	if block_layer == null:
		return

	# Dig slightly ahead of the moving peon so the rock visibly opens before the
	# sprite reaches it. Three cells wide gives enough room to steer without
	# turning this into a separate loading corridor.
	var ahead_position := player.global_position + Vector2(0.0, -38.0)
	var ahead_cell := block_layer.local_to_map(block_layer.to_local(ahead_position))
	if ahead_cell.y == _last_line_wars_dig_row:
		return
	_last_line_wars_dig_row = ahead_cell.y

	var dug_any := false
	for row_offset in range(-1, 1):
		for x in range(-1, 2):
			var cell := Vector2i(x, ahead_cell.y + row_offset)
			if block_layer.get_cell_source_id(cell) == -1:
				continue
			world.on_cell_dug(cell)
			dug_any = true

	if not dug_any:
		return
	status_label.text = "Digging upward into Line Wars..."
	if world.has_method("spawn_mining_feedback"):
		var feedback_cell := Vector2i(0, ahead_cell.y - 1)
		var feedback_position := block_layer.to_global(block_layer.map_to_local(feedback_cell))
		world.spawn_mining_feedback(feedback_position, false, false)

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
		# Line Wars keeps the dual-front controller. The peon remains exactly where
		# it broke through and continues north into the board above the overworld.
		world.begin_run_from_preparation()
		queue_free()
		return

	# MineWars and Adventure continue inside the world that is already loaded.
	# Releasing the temporary peon restores the real hero at the same gate
	# position and removes the expensive second scene generation.
	var dual_front := get_parent().get_node_or_null("DualFrontController")
	if dual_front and dual_front.has_method("release_to_standard_run"):
		dual_front.release_to_standard_run()

	# Adventure's own controller takes ownership on the next deferred scan and
	# disables the standard wave director. Keep world._process dormant during
	# that handoff so a normal wave cannot advance for one stray frame.
	if mode == GameMode.Mode.EXPLORATION:
		world.set_process(false)

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
