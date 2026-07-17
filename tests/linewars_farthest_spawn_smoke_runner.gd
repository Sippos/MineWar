extends Node

const SINGLE_PLAYER_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")

var failures := 0

func _ready() -> void:
	await _run_test()
	if failures == 0:
		print("LINEWARS_FARTHEST_SPAWN_SMOKE_PASS")
		get_tree().quit(0)
	else:
		push_error("LINEWARS_FARTHEST_SPAWN_SMOKE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

func _run_test() -> void:
	var hub := SINGLE_PLAYER_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(6)

	var world := hub.get_node("Level") as Node2D
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var hero := world.get_node("Player") as CharacterBody2D
	var cap_cell := Vector2i(3, -6)
	var approach_cell := Vector2i(3, -5)

	_expect(block_layer.get_cell_source_id(Vector2i(-5, -10)) != -1, "LineWars should no longer begin in a pre-carved empty room")
	_expect(block_layer.get_cell_source_id(Vector2i(3, -7)) == -1, "Only the narrow entry pocket should be open above the cap")
	_expect(block_layer.get_cell_source_id(Vector2i(3, -9)) != -1, "The peon should face solid rock immediately above the entry pocket")

	hero.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(3, -4)))
	world.call("on_cell_dug", approach_cell)
	hero.global_position = block_layer.to_global(block_layer.map_to_local(approach_cell))
	world.call("on_cell_dug", cap_cell)
	await _wait_frames(6)

	var controller := world.get_node_or_null("ContinuousLineWarsController")
	var peon := world.get_node_or_null("BuilderPeon") as CharacterBody2D
	_expect(controller != null and peon != null, "Breaking the cap should begin the excavation defence run")
	if controller == null or peon == null:
		hub.queue_free()
		return

	# Use the peon's real digging once at the bottom, proving it does not rely on
	# a pre-open chamber. Build the rest directly to make the topology deterministic.
	peon.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(3, -8)))
	peon.call("_process_surface_dig", Vector2.UP, 0.6)
	await _wait_frames(2)
	_expect(block_layer.get_cell_source_id(Vector2i(3, -9)) == -1, "The peon should dig upward from the narrow entry")

	var carved_cells := [
		Vector2i(3, -10), Vector2i(3, -11),
		Vector2i(4, -11), Vector2i(5, -11),
		Vector2i(2, -10), Vector2i(1, -10)
	]
	for cell_value in carved_cells:
		var cell: Vector2i = cell_value
		world.call("on_cell_dug", cell)
	await _wait_frames(2)

	var expected_endpoint := Vector2i(5, -11)
	var chosen_endpoint: Vector2i = controller.call("_find_farthest_tunnel_cell")
	_expect(chosen_endpoint == expected_endpoint, "The invasion should choose the farthest connected tunnel dead end")
	_expect(world.astar.is_in_bounds(expected_endpoint.x, expected_endpoint.y), "Upper maze cells should be inside enemy navigation")
	var route: Array[Vector2i] = world.astar.get_id_path(expected_endpoint, Vector2i(0, -1))
	_expect(route.size() > 1, "The farthest spawn should have a valid route through the dug maze to the base")

	controller.call("_begin_invasion", 1)
	await get_tree().create_timer(2.35).timeout
	await _wait_frames(2)
	var spawned_enemy: Node2D = null
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(candidate) and world.is_ancestor_of(candidate):
			spawned_enemy = candidate as Node2D
			break
	_expect(spawned_enemy != null, "The first invasion should spawn after the endpoint warning")
	if spawned_enemy:
		var endpoint_world := block_layer.to_global(block_layer.map_to_local(expected_endpoint))
		_expect(spawned_enemy.global_position.distance_to(endpoint_world) < 96.0, "The enemy should emerge at the selected farthest endpoint")
		var enemy_path: Array = spawned_enemy.get("path")
		_expect(enemy_path.size() > 1, "The spawned enemy should immediately receive a path back to the base")

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
