extends Node

const CELL_SIZE := 64
const DEFAULT_PLAYABLE_RECT := Rect2i(-20, -10, 40, 40)
const BORDER_THICKNESS := 2
const BOUNDARY_SOURCE_ID := 3
const CAMERA_SMOOTHING_SPEED := 9.0

func _ready() -> void:
	# The world builds generated tiles and its first AStar grid in the parent
	# _ready(). Defer so boundaries use the final world-specific playable rect.
	call_deferred("_setup_map_bounds")

func _setup_map_bounds() -> void:
	var world = get_parent()
	var block_layer: TileMapLayer = world.get_node_or_null("BlockLayer")
	if block_layer == null or block_layer.tile_set == null:
		return
	var playable_rect := _get_playable_rect(world)

	var boundary_layer = world.get_node_or_null("BoundaryLayer") as TileMapLayer
	if boundary_layer == null:
		boundary_layer = TileMapLayer.new()
		boundary_layer.name = "BoundaryLayer"
		boundary_layer.tile_set = block_layer.tile_set
		boundary_layer.y_sort_enabled = true
		world.add_child(boundary_layer)

	_build_unbreakable_ring(boundary_layer, playable_rect)
	_limit_player_camera(world, playable_rect)
	_trim_astar_to_playable_map(world, block_layer, playable_rect)

func _get_playable_rect(world: Node) -> Rect2i:
	if world.has_method("get_playable_map_rect"):
		var custom_rect: Variant = world.call("get_playable_map_rect")
		if custom_rect is Rect2i:
			return custom_rect
	return DEFAULT_PLAYABLE_RECT

func _build_unbreakable_ring(boundary_layer: TileMapLayer, playable_rect: Rect2i) -> void:
	boundary_layer.clear()
	var left := playable_rect.position.x
	var right_exclusive := playable_rect.end.x
	var top := playable_rect.position.y
	var bottom_exclusive := playable_rect.end.y

	for offset in range(BORDER_THICKNESS):
		var left_x := left - 1 - offset
		var right_x := right_exclusive + offset
		var top_y := top - 1 - offset
		var bottom_y := bottom_exclusive + offset

		for y in range(top - BORDER_THICKNESS, bottom_exclusive + BORDER_THICKNESS):
			boundary_layer.set_cell(Vector2i(left_x, y), BOUNDARY_SOURCE_ID, Vector2i.ZERO)
			boundary_layer.set_cell(Vector2i(right_x, y), BOUNDARY_SOURCE_ID, Vector2i.ZERO)

		for x in range(left - BORDER_THICKNESS, right_exclusive + BORDER_THICKNESS):
			boundary_layer.set_cell(Vector2i(x, top_y), BOUNDARY_SOURCE_ID, Vector2i.ZERO)
			boundary_layer.set_cell(Vector2i(x, bottom_y), BOUNDARY_SOURCE_ID, Vector2i.ZERO)

func _limit_player_camera(world: Node, playable_rect: Rect2i) -> void:
	var camera = world.get_node_or_null("Player/Camera2D") as Camera2D
	if camera == null:
		return

	camera.limit_left = (playable_rect.position.x - 1) * CELL_SIZE - CELL_SIZE / 2
	camera.limit_right = playable_rect.end.x * CELL_SIZE + CELL_SIZE / 2
	camera.limit_top = (playable_rect.position.y - 1) * CELL_SIZE - CELL_SIZE / 2
	camera.limit_bottom = playable_rect.end.y * CELL_SIZE + CELL_SIZE / 2
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = CAMERA_SMOOTHING_SPEED
	camera.limit_smoothed = true
	camera.reset_smoothing()

func _trim_astar_to_playable_map(world: Node, block_layer: TileMapLayer, playable_rect: Rect2i) -> void:
	var astar_grid = world.get("astar")
	if not astar_grid is AStarGrid2D:
		return

	astar_grid.region = playable_rect
	astar_grid.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()

	for x in range(playable_rect.position.x, playable_rect.end.x):
		for y in range(playable_rect.position.y, playable_rect.end.y):
			var cell := Vector2i(x, y)
			astar_grid.set_point_solid(cell, block_layer.get_cell_source_id(cell) != -1)

	if world.has_method("update_astar_weight"):
		for x in range(playable_rect.position.x, playable_rect.end.x):
			for y in range(playable_rect.position.y, playable_rect.end.y):
				world.call("update_astar_weight", Vector2i(x, y))
