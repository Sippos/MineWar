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

	world_hud.set("total_gold", 420)
	world_hud.set("total_gems", 1)
	var queued_rat := bool(machine.call("_queue_reliable_send", "rat_raid"))
	_expect(queued_rat, "Rat Raid should send when 50 gold is available")
	_expect(int(world_hud.get("total_gold")) == 370, "Rat Raid should spend 50 gold")
	var dispatched: Array = machine.get("dispatched_sends")
	_expect(dispatched.size() == 1 and str((dispatched[0] as Dictionary).get("currency", "")) == "gold", "Reliable sends should emit a gold payload")

	var queued_trogg := bool(machine.call("_queue_reliable_send", "trogg_push"))
	_expect(queued_trogg, "Trogg Push should send when 120 gold is available")
	_expect(int(world_hud.get("total_gold")) == 250, "Trogg Push should spend 120 gold")

	machine.set("forced_gamble_outcome", "gold_bonus")
	var gamble: Dictionary = machine.call("_execute_gem_gamble")
	_expect(str(gamble.get("id", "")) == "gold_bonus", "Goblin Gamble should support deterministic playtest outcomes")
	_expect(int(world_hud.get("total_gems")) == 0, "Goblin Gamble should spend one gem")
	_expect(int(world_hud.get("total_gold")) == 350, "Gold-cache gamble should award 100 gold")

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
