extends Node

const SINGLE_PLAYER_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")

var failures := 0

func _ready() -> void:
	await _run_smoke_test()
	if failures == 0:
		print("CONTINUOUS_LINEWARS_SMOKE_PASS")
		get_tree().quit(0)
	else:
		push_error("CONTINUOUS_LINEWARS_SMOKE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

func _run_smoke_test() -> void:
	var hub := SINGLE_PLAYER_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(5)

	var world := hub.get_node("Level") as Node2D
	var selector := hub.get_node("SinglePlayerWorldController")
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var hero := world.get_node("Player") as CharacterBody2D
	var cap_cell := Vector2i(3, -6)
	var approach_cell := Vector2i(3, -5)

	_expect(selector != null, "The neutral Single Player controller should own the hub")
	_expect(block_layer.get_cell_source_id(cap_cell) != -1, "The LineWars breakthrough should begin as a real solid cap")

	# Reproduce the final hero dig. The controller should switch on this exact cap
	# removal rather than waiting for an invisible coordinate farther north.
	hero.global_position = block_layer.to_global(block_layer.map_to_local(approach_cell))
	world.call("on_cell_dug", cap_cell)
	await _wait_frames(5)

	var line_wars := world.get_node_or_null("ContinuousLineWarsController")
	var peon := world.get_node_or_null("BuilderPeon") as CharacterBody2D
	_expect(line_wars != null, "Breaking the upper cap should activate continuous LineWars immediately")
	_expect(peon != null, "LineWars activation should spawn the peon in the same world")
	_expect(peon != null and bool(peon.get("controlled")), "The breakthrough should switch control directly to the peon")
	_expect(hero.process_mode == Node.PROCESS_MODE_DISABLED, "The hero should remain in place while peon control is active")

	if peon == null or line_wars == null:
		hub.queue_free()
		await _wait_frames(2)
		return

	# Dig one level above the open chamber, then use that new tunnel to dig
	# sideways. This verifies that the maze can grow vertically instead of being
	# restricted to a flat pre-drawn board.
	var upward_target := Vector2i(3, -15)
	block_layer.set_cell(upward_target, 1, Vector2i.ZERO)
	peon.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(3, -14)))
	peon.call("_process_surface_dig", Vector2.UP, 0.6)
	await _wait_frames(2)
	_expect(block_layer.get_cell_source_id(upward_target) == -1, "The peon should dig upward into a higher maze level")

	var sideways_target := Vector2i(4, -15)
	block_layer.set_cell(sideways_target, 1, Vector2i.ZERO)
	peon.global_position = block_layer.to_global(block_layer.map_to_local(upward_target))
	peon.call("_process_surface_dig", Vector2.RIGHT, 0.6)
	await _wait_frames(2)
	_expect(block_layer.get_cell_source_id(sideways_target) == -1, "The peon should dig sideways from the higher maze level")

	var hero_position := hero.global_position
	var peon_position := peon.global_position
	line_wars.call("_toggle_front")
	await _wait_frames(2)
	_expect(hero.process_mode == Node.PROCESS_MODE_INHERIT, "Switching should restore hero control in the same map")
	_expect(not bool(peon.get("controlled")), "Switching to the hero should release peon input")
	var positions_preserved := hero.global_position.distance_to(hero_position) < 0.5 and peon.global_position.distance_to(peon_position) < 0.5
	_expect(positions_preserved, "Switching should preserve both physical positions")

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
