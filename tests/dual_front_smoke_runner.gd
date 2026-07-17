extends Node

const PREPARATION_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")
const LINE_WARS_TRIGGER_POSITION := Vector2(0.0, -468.0)
const LINE_WARS_BOARD_TOP_LOCAL_Y := -180.0
const LINE_WARS_BOARD_BOTTOM_LOCAL_Y := 180.0

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

	_expect(peon != null, "Preparation should spawn the controllable builder peon")
	_expect(hero != null and not hero.visible, "The selected hero should wait hidden during preparation")
	_expect(world.get("current_wave_number") == null, "Preparation should stay outside MatchFlow until a mode is selected")

	# Reproduce the real seamless gate handoff. The peon reaches the end of the
	# freshly carved northern shaft while Up is still held, and that same movement
	# should carry it through the lower portal onto the board above.
	peon.global_position = LINE_WARS_TRIGGER_POSITION
	Input.action_press("p1_up")
	await preparation.call("_begin_mode", GameMode.Mode.LINE_WARS, "", "Testing LineWars handoff")
	await _wait_frames(3)

	var board_top_y := maze.to_global(Vector2(0.0, LINE_WARS_BOARD_TOP_LOCAL_Y)).y
	var board_bottom_y := maze.to_global(Vector2(0.0, LINE_WARS_BOARD_BOTTOM_LOCAL_Y)).y
	var handoff_y := peon.global_position.y
	_expect(bool(dual.get("run_started")), "LineWars should start without changing scenes")
	_expect(maze.visible, "The live surface maze should be visible when LineWars begins")
	_expect(absf(handoff_y - board_bottom_y) < 96.0, "The northern shaft should meet the lower edge of the LineWars board")

	await get_tree().create_timer(0.2).timeout
	var continued_y := peon.global_position.y
	_expect(continued_y < handoff_y - 5.0, "Held Up input should continue carrying the peon north onto the board")
	_expect(continued_y >= board_top_y - 1.0 and continued_y <= board_bottom_y + 80.0, "The peon should remain inside the board and its short entrance lip")
	Input.action_release("p1_up")
	await _wait_frames(2)

	var x_before_move := peon.global_position.x
	Input.action_press("p1_left")
	await get_tree().create_timer(0.2).timeout
	Input.action_release("p1_left")
	_expect(peon.global_position.x < x_before_move - 2.0, "Builder movement should remain responsive after the seamless handoff")

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
