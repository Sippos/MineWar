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
	await _wait_frames(6)

	var world := hub.get_node("Level") as Node2D
	var selector := hub.get_node("SinglePlayerWorldController")
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var hero := world.get_node("Player") as CharacterBody2D

	_expect(selector != null, "The neutral Single Player controller should own the hub")
	_expect(world.get_node_or_null("ContinuousLineWarsController") == null, "LineWars should not run before the upper route is entered")

	# Keep the physical menu transition. Reaching the upper route creates the
	# persistent LineWars controller at the exact breakthrough position.
	hero.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(0, -7)))
	selector.call("_activate_line_wars")
	await _wait_frames(8)

	var line_wars := world.get_node_or_null("ContinuousLineWarsController")
	var peon := world.get_node_or_null("BuilderPeon") as CharacterBody2D
	_expect(line_wars != null, "Entering the upper route should create the continuous LineWars controller")
	_expect(peon != null, "LineWars should spawn the opening builder peon")
	_expect(line_wars != null and bool(line_wars.get("opening_build_active")), "LineWars should begin in the protected opening build phase")
	_expect(hero.process_mode == Node.PROCESS_MODE_DISABLED, "The opening build should temporarily park the hero")
	_expect(peon != null and bool(peon.get("controlled")), "The player should directly control the peon during the minimum tunnel build")

	if peon == null or line_wars == null:
		hub.queue_free()
		await _wait_frames(2)
		return

	var opening_timer_before := float(line_wars.get("invasion_timer"))
	await _wait_frames(20)
	_expect(is_equal_approx(float(line_wars.get("invasion_timer")), opening_timer_before), "The invasion clock must remain frozen during opening construction")
	_expect(_find_world_enemy(world) == null, "No enemy may spawn at the entrance before the safe route exists")

	var tunnel_exit: Vector2i = line_wars.get("tunnel_exit_cell")
	var minimum_length := int(line_wars.get("MINIMUM_OPENING_ROUTE_LENGTH")) if line_wars.get("MINIMUM_OPENING_ROUTE_LENGTH") != null else 6
	for step in range(1, minimum_length):
		var previous_cell := tunnel_exit + Vector2i.UP * (step - 1)
		var target_cell := tunnel_exit + Vector2i.UP * step
		_force_solid(world, block_layer, target_cell)
		peon.global_position = block_layer.to_global(block_layer.map_to_local(previous_cell))
		peon.call("_process_surface_dig", Vector2.UP, 0.6)
		await _wait_frames(3)

	await _wait_frames(6)
	_expect(not bool(line_wars.get("opening_build_active")), "Completing the minimum route should end the opening build")
	_expect(hero.process_mode == Node.PROCESS_MODE_INHERIT, "The completed opening route should restore hero control")
	_expect(not bool(peon.get("controlled")), "After the opening, the peon should return to commissioned macro orders")
	_expect(float(line_wars.get("invasion_timer")) > 26.0, "The first full warning clock should begin only after the route is safe")
	_expect(_find_world_enemy(world) == null, "Completing the route should not instantly spawn an enemy")

	# After the mandatory hand-built opening, future expansion uses one remote
	# order while the hero stays active below.
	var first_remote_dirt := tunnel_exit + Vector2i.UP * minimum_length
	var target_remote_dirt := tunnel_exit + Vector2i.UP * (minimum_length + 1)
	_force_solid(world, block_layer, first_remote_dirt)
	_force_solid(world, block_layer, target_remote_dirt)
	var order_started := bool(peon.call("issue_dig_order", target_remote_dirt))
	_expect(order_started, "A distant dirt tile should create one commissioned tunnel order after the opening")
	_expect(hero.process_mode == Node.PROCESS_MODE_INHERIT, "Remote peon work must not disable hero gameplay")
	await _wait_for_order(peon, 300)
	_expect(not bool(peon.call("is_order_active")), "The peon should complete later work without player steering")
	_expect(block_layer.get_cell_source_id(first_remote_dirt) == -1, "The commissioned route should excavate its first dirt cell")
	_expect(block_layer.get_cell_source_id(target_remote_dirt) == -1, "The commissioned route should reach the selected destination")

	# Command view is only a temporary targeting camera after the opening phase.
	line_wars.call("_begin_command_view", "DIG")
	await _wait_frames(2)
	_expect(bool(line_wars.get("command_view_active")), "The command button should open the peon targeting view")
	_expect(not bool(peon.get("controlled")), "Command view should not restore direct peon movement after the opening")
	line_wars.call("_exit_command_view")
	await _wait_frames(2)
	_expect(hero.process_mode == Node.PROCESS_MODE_INHERIT, "Leaving command view should immediately restore the hero")

	# Radar remains infrastructure: it costs predictable war gold and grants warning
	# information instead of passive combat damage.
	var world_hud := world.get_node("HUD")
	world_hud.set("total_gold", 10)
	line_wars.call("_issue_radar_order", target_remote_dirt)
	await _wait_for_order(peon, 180)
	await _wait_frames(3)
	var radar_cells: Array = line_wars.get("radar_cells")
	_expect(radar_cells.has(target_remote_dirt), "The completed infrastructure order should install a radar marker")
	_expect(int(world_hud.get("total_gold")) == 0, "Radar infrastructure should spend exactly ten war gold")

	# Enemies still travel in two readable layers: delay tunnel first, hero mine
	# second, and only survivors that cross the mine can damage the base.
	var spawn_position := block_layer.to_global(block_layer.map_to_local(target_remote_dirt))
	line_wars.call("_spawn_enemy_at_endpoint", 1, false, 0, 1, spawn_position)
	await _wait_frames(4)
	var enemy := _find_world_enemy(world)
	_expect(enemy != null, "The tunnel layer should be able to spawn a real enemy after opening construction")
	if enemy:
		line_wars.call("_begin_command_view", "DIG")
		await _wait_frames(2)
		_expect(bool(line_wars.get("command_view_active")), "The peon view should be open before the emergency breach check")
		enemy.global_position = block_layer.to_global(block_layer.map_to_local(tunnel_exit))
		line_wars.call("_process_layer_transfers")
		await _wait_frames(3)
		_expect(not bool(line_wars.get("command_view_active")), "A mine breach should immediately close the peon command view")
		_expect(hero.process_mode == Node.PROCESS_MODE_INHERIT, "A mine breach should immediately restore hero control")
		_expect(str(enemy.get_meta("linewars_layer", "")) == "mine", "A tunnel survivor should breach into the mine layer")
		_expect(Vector2i(enemy.get("target_base_cell")) == Vector2i(0, -1), "A breached enemy should retarget the actual base")

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
