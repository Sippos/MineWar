extends Node

const SINGLE_PLAYER_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")

var failures := 0

func _ready() -> void:
	await _run_test()
	if failures == 0:
		print("LINEWARS_BREACH_BALANCE_SMOKE_PASS")
		get_tree().quit(0)
	else:
		push_error("LINEWARS_BREACH_BALANCE_SMOKE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

func _run_test() -> void:
	var hub := SINGLE_PLAYER_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(6)
	var world := hub.get_node("Level") as Node2D
	var selector := hub.get_node("SinglePlayerWorldController")
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var hero := world.get_node("Player") as CharacterBody2D
	var base := world.get_node("Base")

	hero.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(0, -7)))
	selector.call("_activate_line_wars")
	await _wait_frames(8)
	var line_wars := world.get_node("ContinuousLineWarsController")
	var peon := world.get_node("BuilderPeon") as CharacterBody2D
	_expect(line_wars != null and peon != null, "LineWars balance test should activate the real controller and peon")
	if line_wars == null or peon == null:
		return

	var tunnel_exit: Vector2i = line_wars.get("tunnel_exit_cell")
	for step in range(1, 6):
		var previous_cell := tunnel_exit + Vector2i.UP * (step - 1)
		var target_cell := tunnel_exit + Vector2i.UP * step
		_force_solid(world, block_layer, target_cell)
		peon.global_position = block_layer.to_global(block_layer.map_to_local(previous_cell))
		peon.call("_process_surface_dig", Vector2.UP, 0.6)
		await _wait_frames(3)
	await _wait_frames(6)
	_expect(not bool(line_wars.get("opening_build_active")), "Balance test should reach normal hero play")

	# A useful peon order should report the added interception time, not only a cell coordinate.
	var route_before := int(line_wars.call("_tunnel_route_length"))
	var target_remote := tunnel_exit + Vector2i.UP * 7
	_force_solid(world, block_layer, tunnel_exit + Vector2i.UP * 6)
	_force_solid(world, block_layer, target_remote)
	line_wars.call("_issue_command", target_remote)
	await _wait_for_order(peon, 320)
	await _wait_frames(3)
	var route_after := int(line_wars.call("_tunnel_route_length"))
	var route_message := str(line_wars.get("command_message"))
	_expect(route_after > route_before, "The commissioned tunnel should extend the farthest invasion route")
	_expect(route_message.contains("about +") and route_message.contains("seconds"), "Tunnel completion should explain the added interception time")

	# Early leak values should allow between three and five mistakes before defeat.
	for wave in range(1, 6):
		var leak_damage := int(line_wars.call("_linewars_leak_damage", wave, false))
		var survivable_leaks := int(floor(99.0 / float(leak_damage)))
		_expect(survivable_leaks >= 3 and survivable_leaks <= 5, "Wave %d should allow 3-5 early leaks, got %d" % [wave, survivable_leaks])

	# Standing directly inside the blue gate should cause one readable surge hit and knockback.
	var mine_entry: Vector2i = line_wars.get("MINE_ENTRY_CELL") if line_wars.get("MINE_ENTRY_CELL") != null else Vector2i(0, 8)
	hero.global_position = block_layer.to_global(block_layer.map_to_local(mine_entry))
	hero.set("health", hero.get("max_health"))
	hero.set("invulnerability_timer", 0.0)
	var hero_health_before := int(hero.get("health"))
	var hero_position_before := hero.global_position
	var spawn_position := block_layer.to_global(block_layer.map_to_local(target_remote))
	line_wars.call("_spawn_enemy_at_endpoint", 1, false, 0, 1, spawn_position)
	await _wait_frames(4)
	var enemy := _find_world_enemy(world)
	_expect(enemy != null, "The balance test should spawn a real LineWars enemy")
	if enemy:
		enemy.global_position = block_layer.to_global(block_layer.map_to_local(tunnel_exit))
		line_wars.call("_process_layer_transfers")
		await _wait_frames(24)
		var eruption_damage := hero_health_before - int(hero.get("health"))
		_expect(eruption_damage >= 2 and eruption_damage <= 4, "The gate eruption should deal one small camping penalty")
		_expect(hero.global_position.distance_to(hero_position_before) >= 45.0, "The gate eruption should push the hero out of the portal center")

		# A survivor reaching the base should deal one discrete leak hit, then disappear.
		hero.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(0, 12)))
		var base_before := int(base.get("health"))
		enemy.global_position = base.global_position
		enemy.set("emergence_timer", 0.0)
		enemy.call("recalculate_path")
		await _wait_frames(90)
		_expect(int(base.get("health")) == base_before - 18, "A wave-one survivor should deal exactly one 18-damage leak")
		_expect(not is_instance_valid(enemy), "A LineWars survivor should disappear after its single base leak")

	hub.queue_free()
	await _wait_frames(4)

func _force_solid(world: Node, block_layer: TileMapLayer, cell: Vector2i) -> void:
	block_layer.set_cell(cell, 1, Vector2i.ZERO)
	if world.get("astar") != null and world.astar.is_in_bounds(cell.x, cell.y):
		world.astar.set_point_solid(cell, true)

func _find_world_enemy(world: Node) -> CharacterBody2D:
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(candidate) and world.is_ancestor_of(candidate):
			return candidate as CharacterBody2D
	return null

func _wait_for_order(peon: Node, max_frames: int) -> void:
	for _index in max_frames:
		if not bool(peon.call("is_order_active")):
			return
		await get_tree().process_frame

func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
