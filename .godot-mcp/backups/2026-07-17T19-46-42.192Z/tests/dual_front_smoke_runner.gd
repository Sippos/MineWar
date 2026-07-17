extends Node

const PREPARATION_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")

var failures := 0

func _ready() -> void:
	await _run_dual_front_smoke()
	if failures == 0:
		print("DUAL_FRONT_SMOKE_PASS")
		get_tree().quit(0)
	else:
		push_error("DUAL_FRONT_SMOKE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

func _run_dual_front_smoke() -> void:
	var hub := PREPARATION_SCENE.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var world := hub.get_node("Level") as Node2D
	var dual := hub.get_node("DualFrontController")
	var preparation := hub.get_node("PreparationController")
	var hero := world.get_node("Player") as CharacterBody2D
	var peon := world.get_node_or_null("BuilderPeon") as CharacterBody2D
	var maze := world.get_node_or_null("SurfaceDelayMaze") as Node2D

	_expect(peon != null, "Preparation overworld should spawn the controllable builder peon")
	_expect(hero != null and not hero.visible, "The selected hero should wait hidden underground during preparation")
	_expect(peon != null and bool(peon.get("controlled")), "Single Player preparation should begin under peon control")
	_expect(not bool(dual.get("run_started")), "The dual-front run should wait for the MineWars start gate")
	_expect(not world.is_processing(), "The old random-wave process should be disabled for dual-front mode")

	peon.position = Vector2(0, 112)
	await get_tree().create_timer(0.35).timeout
	await get_tree().process_frame

	_expect(bool(dual.get("run_started")), "Walking through the MineWars gate should start the run without changing scenes")
	_expect(preparation == null or not is_instance_valid(preparation) or preparation.is_queued_for_deletion(), "The preparation controller should leave after starting in place")
	_expect(maze != null and maze.visible, "The live surface maze should appear when the run begins")
	_expect(int(dual.get("active_front")) == 0, "The run should begin as the builder peon")
	_expect(hero.visible and hero.position == Vector2(0, 96), "The hero should wait at the first underground dig position")

	dual.call("_toggle_front")
	await get_tree().process_frame
	_expect(int(dual.get("active_front")) == 1, "Switching should activate the underground hero")
	_expect(not bool(peon.get("controlled")), "The peon should remain in place when the hero is controlled")
	_expect(hero.process_mode == Node.PROCESS_MODE_INHERIT, "Hero gameplay should resume after switching underground")

	var peon_position_before := peon.position
	var hero_position_before := hero.position
	dual.call("_toggle_front")
	await get_tree().process_frame
	_expect(int(dual.get("active_front")) == 0, "Switching again should return to the surface peon")
	_expect(peon.position == peon_position_before and hero.position == hero_position_before, "Both avatars should preserve their separate positions")

	maze.set_process(false)
	var roster: Array[String] = ["Rat", "Spider", "Orc"]
	maze.call("spawn_invasion", roster)
	_expect(int(maze.call("get_enemy_count")) == 3, "An invasion should enter the maze instead of spawning beside the base")
	for _step in 160:
		maze.call("_process", 0.2)
		if (dual.get("portal_queue") as Array).size() > 0:
			break
	_expect((dual.get("portal_queue") as Array).size() > 0, "Maze survivors should enter the breach portal queue")

	var queued_before_release := (dual.get("portal_queue") as Array).size()
	dual.call("_process_portal_queue", 9.0)
	await get_tree().process_frame
	var arena_enemies := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if world.is_ancestor_of(enemy):
			arena_enemies += 1
	_expect((dual.get("portal_queue") as Array).is_empty(), "The breach portal should empty after its warning charge")
	_expect(arena_enemies >= queued_before_release, "Queued survivors should emerge as real combat enemies beside the base")

	hub.queue_free()
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
