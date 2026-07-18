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
	var selector := hub.get_node("SinglePlayerWorldController")
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var hero := world.get_node("Player") as CharacterBody2D

	_expect(block_layer.get_cell_source_id(Vector2i(-5, -10)) != -1, "LineWars should begin as solid rock instead of a pre-carved arena")
	_expect(block_layer.get_cell_source_id(Vector2i(0, -8)) != -1, "The centered menu shaft should meet solid rock immediately above its entry")

	# Enter through the same centered upper doorway used by the real menu flow.
	hero.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(0, -7)))
	selector.call("_activate_line_wars")
	await _wait_frames(8)

	var controller := world.get_node_or_null("ContinuousLineWarsController")
	var peon := world.get_node_or_null("BuilderPeon") as CharacterBody2D
	_expect(controller != null and peon != null, "Entering the upper shaft should begin the continuous excavation defence run")
	if controller == null or peon == null:
		hub.queue_free()
		return

	var tunnel_exit: Vector2i = controller.get("tunnel_exit_cell")
	_expect(tunnel_exit == Vector2i(0, -7), "The transfer gate should stay at the centered menu breakthrough")
	_expect(bool(controller.get("opening_build_active")), "The opening route should be protected from waves")

	# Carve the mandatory six-tile route first. This represents the direct peon
	# opening phase and prevents the first portal from appearing on the gate.
	for y in range(-8, -13, -1):
		world.call("on_cell_dug", Vector2i(0, y))
	await _wait_frames(8)
	_expect(not bool(controller.get("opening_build_active")), "A six-tile route should unlock normal LineWars play")
	_expect(controller.call("_tunnel_route_length") >= 6, "The safe opening route should have the required travel distance")

	# Add a deliberately longer side branch. The straight upper endpoint is five
	# steps from the transfer gate, while the right endpoint is six steps away.
	var branch_cells := [Vector2i(1, -10), Vector2i(2, -10), Vector2i(3, -10)]
	for cell_value in branch_cells:
		world.call("on_cell_dug", Vector2i(cell_value))
	await _wait_frames(3)

	var expected_endpoint := Vector2i(3, -10)
	var chosen_endpoint: Vector2i = controller.call("_find_farthest_tunnel_cell")
	_expect(chosen_endpoint == expected_endpoint, "The invasion portal should choose the farthest connected dead end")
	_expect(chosen_endpoint != tunnel_exit, "The completed minimum tunnel must prevent spawning at the transfer gate")
	_expect(world.astar.is_in_bounds(expected_endpoint.x, expected_endpoint.y), "The selected upper endpoint should remain inside enemy navigation")
	var route: Array[Vector2i] = world.astar.get_id_path(expected_endpoint, tunnel_exit)
	_expect(route.size() >= 7, "The selected portal should have a real delay route back to the transfer gate")

	controller.call("_begin_invasion", 1)
	_expect(Vector2i(controller.get("last_spawn_cell")) == expected_endpoint, "The announced first portal should lock to the farthest branch")
	await get_tree().create_timer(2.35).timeout
	await _wait_frames(3)
	var spawned_enemy := _find_world_enemy(world)
	_expect(spawned_enemy != null, "The first invasion should spawn after the endpoint warning")
	if spawned_enemy:
		var endpoint_world := block_layer.to_global(block_layer.map_to_local(expected_endpoint))
		_expect(spawned_enemy.global_position.distance_to(endpoint_world) < 96.0, "The enemy should emerge at the announced farthest endpoint")
		_expect(Vector2i(spawned_enemy.get("target_base_cell")) == tunnel_exit, "Tunnel-layer enemies should first target the transfer gate, not the base")
		var enemy_path: Array = spawned_enemy.get("path")
		_expect(enemy_path.size() > 1, "The spawned enemy should immediately receive the excavated delay route")

	hub.queue_free()
	await _wait_frames(3)

func _find_world_enemy(world: Node) -> CharacterBody2D:
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(candidate) and world.is_ancestor_of(candidate):
			return candidate as CharacterBody2D
	return null

func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
