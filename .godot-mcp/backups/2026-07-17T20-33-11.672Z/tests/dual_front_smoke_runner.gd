extends Node

const PREPARATION_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")

var failures := 0

func _ready() -> void:
	await _run_line_wars_handoff()
	await _run_mine_wars_handoff()
	await _run_adventure_handoff()
	if failures == 0:
		print("DUAL_FRONT_SMOKE_PASS")
		get_tree().quit(0)
	else:
		push_error("DUAL_FRONT_SMOKE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

func _run_line_wars_handoff() -> void:
	GameMode.set_mode(GameMode.Mode.SIEGE)
	var hub := PREPARATION_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(3)

	var world := hub.get_node("Level") as Node2D
	var dual := hub.get_node("DualFrontController")
	var preparation := hub.get_node("PreparationController")
	var hero := world.get_node("Player") as CharacterBody2D
	var peon := world.get_node_or_null("BuilderPeon") as CharacterBody2D
	var maze := world.get_node_or_null("SurfaceDelayMaze") as Node2D
	var block_layer := world.get_node("BlockLayer") as TileMapLayer

	_expect(peon != null, "Preparation should spawn the controllable builder peon")
	_expect(hero != null and not hero.visible, "The selected hero should wait hidden during preparation")
	_expect(world.get("current_wave_number") == null, "Preparation should stay outside MatchFlow until a mode is selected")

	# Verify that approaching the northern exit actually carves rock instead of
	# crossing a permanently pre-opened corridor.
	peon.global_position = Vector2(0, -350)
	hero.global_position = peon.global_position
	var dig_cell := block_layer.local_to_map(block_layer.to_local(hero.global_position + Vector2(0, -38)))
	preparation.call("_dig_line_wars_entrance")
	var shaft_open := true
	for row_offset in range(-1, 1):
		for x in range(-1, 2):
			shaft_open = shaft_open and block_layer.get_cell_source_id(Vector2i(x, dig_cell.y + row_offset)) == -1
	_expect(shaft_open, "Walking north should carve a three-cell LineWars shaft")

	# Reproduce the real gate input: Up remains held while the peon breaks through.
	# The board now exists physically above the shaft, so this same input should
	# continue through its lower portal rather than being cancelled or teleported.
	peon.global_position = Vector2(0, -468)
	hero.global_position = peon.global_position
	var breakthrough_position := peon.global_position
	Input.action_press("p1_up")
	await preparation.call("_begin_mode", GameMode.Mode.LINE_WARS, "", "Testing seamless LineWars handoff")
	await _wait_frames(3)

	var lower_portal := maze.to_global(Vector2(0, 180))
	_expect(bool(dual.get("run_started")), "LineWars should start without changing scenes")
	_expect(maze.visible, "The live surface maze should be visible when LineWars begins")
	_expect(lower_portal.y < breakthrough_position.y, "The LineWars board should sit physically above the overworld shaft")
	_expect(peon.global_position.distance_to(breakthrough_position) < 40.0, "LineWars should preserve the peon's breakthrough position instead of snapping to board center")
	await get_tree().create_timer(0.2).timeout
	_expect(peon.global_position.y < breakthrough_position.y - 8.0, "Held Up should carry the peon seamlessly through the lower portal")
	Input.action_release("p1_up")
	await _wait_frames(2)

	var x_before := peon.global_position.x
	Input.action_press("p1_left")
	await get_tree().create_timer(0.2).timeout
	Input.action_release("p1_left")
	_expect(peon.global_position.x < x_before - 2.0, "Builder movement should remain responsive after entering the board")

	dual.call("_toggle_front")
	await _wait_frames(1)
	_expect(int(dual.get("active_front")) == 1, "Switching should activate the underground hero")
	_expect(hero.visible and hero.process_mode == Node.PROCESS_MODE_INHERIT, "Hero gameplay should resume underground")
	_expect(not maze.visible, "The surface maze should hide while the hero camera is active")

	dual.call("_toggle_front")
	await _wait_frames(1)
	_expect(int(dual.get("active_front")) == 0, "Switching again should return to the surface builder")
	_expect(peon.visible and maze.visible and not hero.visible, "Returning to the surface should restore only the peon and maze")

	hub.queue_free()
	await _wait_frames(3)

func _run_mine_wars_handoff() -> void:
	GameMode.set_mode(GameMode.Mode.SIEGE)
	var hub := PREPARATION_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(3)

	var world := hub.get_node("Level") as Node2D
	var preparation := hub.get_node("PreparationController")
	var world_instance_id := world.get_instance_id()

	await preparation.call("_begin_mode", GameMode.Mode.SIEGE, "", "Testing MineWars handoff")
	await _wait_frames(6)

	_expect(is_instance_valid(world) and world.get_instance_id() == world_instance_id, "MineWars should reuse the already generated preparation world")
	_expect(not bool(world.get("preparation_active")), "MineWars should leave preparation state")
	_expect(world.get("current_wave_number") != null, "MineWars should activate the standard wave/result flow")
	_expect(world.get_node_or_null("BuilderPeon") == null, "MineWars should remove the temporary preparation peon")
	_expect(world.get_node_or_null("SurfaceDelayMaze") == null, "MineWars should remove the unused surface maze")
	_expect(hub.get_node_or_null("DualFrontController") == null, "MineWars should release the dual-front controller")
	_expect(world.get_node_or_null("SiegeModeController") != null, "MineWars should attach its siege controller in place")
	var hero := world.get_node("Player") as CharacterBody2D
	_expect(hero.visible and hero.process_mode == Node.PROCESS_MODE_INHERIT, "MineWars should return control to the real hero")

	hub.queue_free()
	await _wait_frames(3)

func _run_adventure_handoff() -> void:
	GameMode.set_mode(GameMode.Mode.SIEGE)
	var hub := PREPARATION_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(3)

	var world := hub.get_node("Level") as Node2D
	var preparation := hub.get_node("PreparationController")
	var world_instance_id := world.get_instance_id()

	await preparation.call("_begin_mode", GameMode.Mode.EXPLORATION, "", "Testing Adventure handoff")
	await _wait_frames(6)

	_expect(is_instance_valid(world) and world.get_instance_id() == world_instance_id, "Adventure should reuse the already generated preparation world")
	_expect(not bool(world.get("preparation_active")), "Adventure should leave preparation state")
	_expect(world.get("current_wave_number") == null, "Adventure should stay outside the standard wave/result flow")
	_expect(world.get_node_or_null("BuilderPeon") == null, "Adventure should remove the temporary preparation peon")
	_expect(hub.get_node_or_null("DualFrontController") == null, "Adventure should release the dual-front controller")
	_expect(world.get_node_or_null("ExplorationModeController") != null, "Adventure should attach its exploration controller in place")
	var hero := world.get_node("Player") as CharacterBody2D
	_expect(hero.visible and hero.process_mode == Node.PROCESS_MODE_INHERIT, "Adventure should return control to the real hero")

	hub.queue_free()
	await _wait_frames(3)

func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
