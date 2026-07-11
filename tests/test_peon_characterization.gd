@tool
extends McpTestSuite

const PEON_SCRIPT := preload("res://peon.gd")
const COORDINATOR_SCRIPT := preload("res://peon_coordinator.gd")
const INVALID_CELL := Vector2i(999999, 999999)

class FakeWorld:
	extends Node2D
	var astar: AStarGrid2D

class FakeBase:
	extends Node2D
	signal gems_deposited(amount)

class FakeGem:
	extends Node2D
	var tethered_to = null

func suite_name() -> String:
	return "peon_characterization"

func _make_world(open_cells: Array[Vector2i]) -> Dictionary:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return {}

	var world := FakeWorld.new()
	world.name = "_McpTestPeonWorld"
	scene_root.add_child(world)
	track(world)

	var base := FakeBase.new()
	base.name = "Base"
	world.add_child(base)

	var block_layer := TileMapLayer.new()
	block_layer.name = "BlockLayer"
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 64)
	block_layer.tile_set = tile_set
	world.add_child(block_layer)

	var astar := AStarGrid2D.new()
	astar.region = Rect2i(-5, -5, 11, 11)
	astar.cell_size = Vector2(64, 64)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for x in range(-5, 6):
		for y in range(-5, 6):
			astar.set_point_solid(Vector2i(x, y), true)
	for cell in open_cells:
		astar.set_point_solid(cell, false)
	world.astar = astar

	base.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i.ZERO))
	return {"world": world, "base": base, "block_layer": block_layer}

func _add_peon(world: Node, cell: Vector2i) -> Node:
	var peon := PEON_SCRIPT.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.hframes = 8
	sprite.vframes = 8
	peon.add_child(sprite)
	world.add_child(peon)
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	peon.global_position = block_layer.to_global(block_layer.map_to_local(cell))
	peon.last_walkable_cell = cell
	return peon

func _add_gem(world: Node, cell: Vector2i) -> Node:
	var gem := FakeGem.new()
	gem.name = "Gem"
	gem.add_to_group("gems")
	world.add_child(gem)
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	gem.global_position = block_layer.to_global(block_layer.map_to_local(cell))
	return gem

func test_reachable_gem_path_uses_only_open_cells() -> void:
	var setup_data := _make_world([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])
	assert_false(setup_data.is_empty(), "An edited scene is required")
	if setup_data.is_empty():
		return
	var world: Node = setup_data.world
	var peon := _add_peon(world, Vector2i(0, 0))
	var gem := _add_gem(world, Vector2i(3, 0))

	assert_true(peon._try_target_reachable_gem(), "Reachable gem should be selected")
	assert_eq(peon.target_gem, gem)
	assert_gt(peon.astar_path.size(), 1)
	for cell in peon.astar_path:
		assert_false(world.astar.is_point_solid(cell), "Path must not include solid cells")
		assert_eq(setup_data.block_layer.get_cell_source_id(cell), -1, "Path must stay on dug cells")

func test_unreachable_gem_is_ignored() -> void:
	var setup_data := _make_world([Vector2i(0, 0), Vector2i(3, 0)])
	assert_false(setup_data.is_empty(), "An edited scene is required")
	if setup_data.is_empty():
		return
	var peon := _add_peon(setup_data.world, Vector2i(0, 0))
	_add_gem(setup_data.world, Vector2i(3, 0))

	assert_false(peon._try_target_reachable_gem())
	assert_eq(peon.target_gem, null)
	assert_eq(peon.astar_path.size(), 0)

func test_pickup_returns_to_base_and_deposits_once() -> void:
	var setup_data := _make_world([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	assert_false(setup_data.is_empty(), "An edited scene is required")
	if setup_data.is_empty():
		return
	var peon := _add_peon(setup_data.world, Vector2i(0, 0))
	var gem := _add_gem(setup_data.world, Vector2i(2, 0))
	var deposits := [0]
	setup_data.base.gems_deposited.connect(func(amount): deposits[0] += int(amount))

	assert_true(peon._try_target_reachable_gem())
	peon.state = "MOVE_TO_GEM"
	peon.global_position = gem.global_position
	peon._physics_process(0.016)
	assert_eq(peon.state, "RETURN_TO_BASE")
	assert_eq(peon.target_gem, null)
	assert_true(gem.is_queued_for_deletion())

	peon.global_position = setup_data.base.global_position
	peon._physics_process(0.016)
	assert_eq(deposits[0], 1, "A carried gem should deposit exactly once")
	peon._physics_process(0.016)
	assert_eq(deposits[0], 1, "Deposit must not repeat after the state changes")

func test_coordinator_releases_duplicate_target() -> void:
	var setup_data := _make_world([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	assert_false(setup_data.is_empty(), "An edited scene is required")
	if setup_data.is_empty():
		return
	var world: Node = setup_data.world
	var gem := _add_gem(world, Vector2i(2, 0))
	var first := _add_peon(world, Vector2i(0, 0))
	var second := _add_peon(world, Vector2i(1, 0))
	for peon in [first, second]:
		peon.state = "MOVE_TO_GEM"
		peon.target_gem = gem
		peon.astar_path = [Vector2i(0, 0), Vector2i(1, 0)]

	var coordinator := COORDINATOR_SCRIPT.new()
	world.add_child(coordinator)
	coordinator._reconcile_peons(world)
	var retained := int(first.target_gem == gem) + int(second.target_gem == gem)
	assert_eq(retained, 1, "Exactly one Peon should retain a duplicate assignment")
	var released := second if first.target_gem == gem else first
	assert_eq(released.state, "IDLE")
	assert_eq(released.astar_path.size(), 0)

func test_invalid_target_recovers_to_idle() -> void:
	var setup_data := _make_world([Vector2i(0, 0), Vector2i(1, 0)])
	assert_false(setup_data.is_empty(), "An edited scene is required")
	if setup_data.is_empty():
		return
	var peon := _add_peon(setup_data.world, Vector2i(0, 0))
	var gem := _add_gem(setup_data.world, Vector2i(1, 0))
	peon.state = "MOVE_TO_GEM"
	peon.target_gem = gem
	peon.astar_path = [Vector2i(0, 0), Vector2i(1, 0)]
	setup_data.world.remove_child(gem)
	gem.free()

	peon._physics_process(0.016)
	assert_eq(peon.state, "IDLE")
	assert_eq(peon.target_gem, null)
	assert_eq(peon.astar_path.size(), 0)
	assert_eq(peon.velocity, Vector2.ZERO)

func test_cached_path_stops_before_newly_solid_next_cell() -> void:
	var setup_data := _make_world([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	assert_false(setup_data.is_empty(), "An edited scene is required")
	if setup_data.is_empty():
		return
	var peon := _add_peon(setup_data.world, Vector2i(0, 0))
	peon.state = "MOVE_TO_GEM"
	peon.astar_path = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	peon.path_index = 1
	var start_position: Vector2 = peon.global_position
	setup_data.world.astar.set_point_solid(Vector2i(1, 0), true)

	peon.move_along_path(0.016)

	assert_eq(peon.global_position, start_position, "Peon must not advance toward a newly solid path cell")
	assert_eq(peon.velocity, Vector2.ZERO, "Peon must stop when its next path cell becomes solid")
	assert_eq(peon.astar_path.size(), 0, "Invalid cached path should be cancelled for rebuilding")
