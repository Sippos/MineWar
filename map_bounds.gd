extends Node

const CELL_SIZE := 64
const MAP_LEFT := -20
const MAP_RIGHT_EXCLUSIVE := 20
const MAP_TOP := -10
const MAP_BOTTOM_EXCLUSIVE := 30
const BORDER_THICKNESS := 2
const BOUNDARY_SOURCE_ID := 3
const CAMERA_SMOOTHING_SPEED := 9.0

func _ready() -> void:
	# The world builds its generated tiles and AStar grid in the parent _ready().
	# Defer so the boundary can be added after generation is complete.
	call_deferred("_setup_map_bounds")

func _setup_map_bounds() -> void:
	var world = get_parent()
	var block_layer: TileMapLayer = world.get_node_or_null("BlockLayer")
	if block_layer == null or block_layer.tile_set == null:
		return

	var boundary_layer = world.get_node_or_null("BoundaryLayer") as TileMapLayer
	if boundary_layer == null:
		boundary_layer = TileMapLayer.new()
		boundary_layer.name = "BoundaryLayer"
		boundary_layer.tile_set = block_layer.tile_set
		boundary_layer.y_sort_enabled = true
		world.add_child(boundary_layer)

	_build_unbreakable_ring(boundary_layer)
	_limit_player_camera(world)
	_trim_astar_to_playable_map(world, block_layer)

func _build_unbreakable_ring(boundary_layer: TileMapLayer) -> void:
	boundary_layer.clear()

	for offset in range(BORDER_THICKNESS):
		var left_x = MAP_LEFT - 1 - offset
		var right_x = MAP_RIGHT_EXCLUSIVE + offset
		var top_y = MAP_TOP - 1 - offset
		var bottom_y = MAP_BOTTOM_EXCLUSIVE + offset

		for y in range(MAP_TOP - BORDER_THICKNESS, MAP_BOTTOM_EXCLUSIVE + BORDER_THICKNESS):
			boundary_layer.set_cell(Vector2i(left_x, y), BOUNDARY_SOURCE_ID, Vector2i.ZERO)
			boundary_layer.set_cell(Vector2i(right_x, y), BOUNDARY_SOURCE_ID, Vector2i.ZERO)

		for x in range(MAP_LEFT - BORDER_THICKNESS, MAP_RIGHT_EXCLUSIVE + BORDER_THICKNESS):
			boundary_layer.set_cell(Vector2i(x, top_y), BOUNDARY_SOURCE_ID, Vector2i.ZERO)
			boundary_layer.set_cell(Vector2i(x, bottom_y), BOUNDARY_SOURCE_ID, Vector2i.ZERO)

func _limit_player_camera(world: Node) -> void:
	var camera = world.get_node_or_null("Player/Camera2D") as Camera2D
	if camera == null:
		return

	# Include the first indestructible row in view, but never reveal the empty
	# infinite canvas beyond the generated mine.
	camera.limit_left = (MAP_LEFT - 1) * CELL_SIZE - CELL_SIZE / 2
	camera.limit_right = MAP_RIGHT_EXCLUSIVE * CELL_SIZE + CELL_SIZE / 2
	camera.limit_top = (MAP_TOP - 1) * CELL_SIZE - CELL_SIZE / 2
	camera.limit_bottom = MAP_BOTTOM_EXCLUSIVE * CELL_SIZE + CELL_SIZE / 2

	# The previous hard-locked camera exposed every single physics correction.
	# Physics-timed smoothing preserves responsiveness while removing the
	# browser-game-like camera judder at direction changes and map limits.
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = CAMERA_SMOOTHING_SPEED
	camera.limit_smoothed = true
	camera.reset_smoothing()

func _trim_astar_to_playable_map(world: Node, block_layer: TileMapLayer) -> void:
	var astar_grid = world.get("astar")
	if not astar_grid is AStarGrid2D:
		return

	astar_grid.region = Rect2i(
		MAP_LEFT,
		MAP_TOP,
		MAP_RIGHT_EXCLUSIVE - MAP_LEFT,
		MAP_BOTTOM_EXCLUSIVE - MAP_TOP
	)
	astar_grid.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()

	for x in range(MAP_LEFT, MAP_RIGHT_EXCLUSIVE):
		for y in range(MAP_TOP, MAP_BOTTOM_EXCLUSIVE):
			var cell = Vector2i(x, y)
			astar_grid.set_point_solid(cell, block_layer.get_cell_source_id(cell) != -1)

	if world.has_method("update_astar_weight"):
		for x in range(MAP_LEFT, MAP_RIGHT_EXCLUSIVE):
			for y in range(MAP_TOP, MAP_BOTTOM_EXCLUSIVE):
				world.update_astar_weight(Vector2i(x, y))
