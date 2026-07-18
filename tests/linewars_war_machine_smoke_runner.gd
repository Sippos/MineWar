extends Node

const SINGLE_PLAYER_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")

var failures := 0

func _ready() -> void:
	await _run_test()
	if failures == 0:
		print("LINEWARS_WAR_MACHINE_SMOKE_PASS")
		get_tree().quit(0)
	else:
		push_error("LINEWARS_WAR_MACHINE_SMOKE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

func _run_test() -> void:
	var hub := SINGLE_PLAYER_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(6)
	var world := hub.get_node("Level") as Node2D
	var selector := hub.get_node("SinglePlayerWorldController")
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var hero := world.get_node("Player") as CharacterBody2D
	var world_hud := world.get_node("HUD") as CanvasLayer

	hero.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(0, -7)))
	selector.call("_activate_line_wars")
	await _wait_frames(8)
	var line_wars := world.get_node_or_null("ContinuousLineWarsController")
	var machine := line_wars.get_node_or_null("WarMachineController") if line_wars else null
	_expect(line_wars != null and machine != null, "LineWars should create the Goblin War Machine controller")
	if machine == null:
		return

	var machine_cell := Vector2i(3, 10)
	_expect(not bool(machine.get("machine_revealed")), "The War Machine should remain hidden while its mine block is solid")
	if world.has_method("on_cell_dug"):
		world.call("on_cell_dug", machine_cell)
	else:
		block_layer.erase_cell(machine_cell)
	await _wait_frames(4)
	_expect(bool(machine.get("machine_revealed")), "Digging the machine cell should uncover the War Machine")
	var machine_root := machine.get("machine_root") as Node2D
	_expect(machine_root != null and machine_root.visible, "The uncovered War Machine should become visible in the mine")

	world_hud.set("total_gems", 4)
	var queued_rat := bool(machine.call("_queue_send", "RAT RAID", 5, "RAT", 1))
	_expect(queued_rat, "Rat Raid should queue when one gem is available")
	_expect(int(world_hud.get("total_gems")) == 3, "Rat Raid should spend one gem")
	var queue: Array = machine.get("send_queue")
	_expect(queue.size() == 1 and str((queue[0] as Dictionary).get("enemy_type", "")) == "RAT", "Rat Raid should create a reusable RAT send payload")

	var queued_trogg := bool(machine.call("_queue_send", "TROGG PUSH", 2, "TROGG", 2))
	_expect(queued_trogg, "Trogg Push should queue when two gems are available")
	_expect(int(world_hud.get("total_gems")) == 1, "Trogg Push should spend two gems")
	queue = machine.get("send_queue")
	_expect(queue.size() == 2 and str((queue[1] as Dictionary).get("enemy_type", "")) == "TROGG", "Trogg Push should create a reusable TROGG send payload")

	machine.call("_dispatch_next")
	var dispatched: Array = machine.get("dispatched_sends")
	queue = machine.get("send_queue")
	_expect(dispatched.size() == 1 and queue.size() == 1, "Dispatch should move exactly one payload from queue to sent history")

	machine.call("_toggle_auto_pressure")
	_expect(bool(machine.get("auto_pressure")), "Auto Pressure should toggle on without immediately spending a gem")
	machine.call("_dispatch_next")
	await _wait_frames(2)
	queue = machine.get("send_queue")
	_expect(queue.size() == 1, "Auto Pressure should queue one Rat Raid when the queue becomes empty")
	_expect(int(world_hud.get("total_gems")) == 0, "Auto Pressure should spend the final available gem")

	machine.call("_open_menu")
	_expect(bool(machine.get("menu_open")) and get_tree().paused, "Opening the War Machine should pause combat behind the large mobile menu")
	machine.call("_close_menu")
	_expect(not bool(machine.get("menu_open")) and not get_tree().paused, "Closing the War Machine should immediately resume the mine")

	hub.queue_free()
	await _wait_frames(4)

func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
