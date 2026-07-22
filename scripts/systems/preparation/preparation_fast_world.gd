extends "res://scripts/systems/world_generation/world_terrain_runtime.gd"

# Single Player owns one persistent generated world. The preparation area is a
# deliberately composed hero hall: one rectangular room, three obvious exits,
# and the same mine continuing beyond those exits.


const PREPARATION_TUTORIAL_GEM_CELL := Vector2i(0, 9)
const INPUT_REGISTRATION_META := "single_player_runtime_input_ready"

const WORLD_WIDTH := 40
const WORLD_TOP := -33
const WORLD_DEPTH := 30

# The room is 15 × 9 tiles. At the hub camera zoom this fits as one readable
# overview while still leaving enough space for the five hero statues.
const HUB_ROOM_X_MIN := -7
const HUB_ROOM_X_MAX := 7
const HUB_ROOM_Y_MIN := -4
const HUB_ROOM_Y_MAX := 4

# Three-cell-wide doorways with short tunnels make every mode legible without
# relying on floating instructional text.
const LINE_WARS_ROUTE_X_MIN := -1
const LINE_WARS_ROUTE_X_MAX := 1
const LINE_WARS_ROUTE_Y_MIN := -7
const LINE_WARS_ROUTE_Y_MAX := -5
const MINE_WARS_ROUTE_X_MIN := -1
const MINE_WARS_ROUTE_X_MAX := 1
const MINE_WARS_ROUTE_Y_MIN := 5
const MINE_WARS_ROUTE_Y_MAX := 8
const ADVENTURE_ROUTE_X_MIN := 8
const ADVENTURE_ROUTE_X_MAX := 11
const ADVENTURE_ROUTE_Y_MIN := -1
const ADVENTURE_ROUTE_Y_MAX := 1

# Adventure keeps a buried side chamber beyond its short hall. The transition
# happens in the doorway, but the chamber remains part of the persistent mine.
const ADVENTURE_ROOM_X_MIN := 12
const ADVENTURE_ROOM_X_MAX := 18
const ADVENTURE_ROOM_Y_MIN := -4
const ADVENTURE_ROOM_Y_MAX := 3


func _init() -> void:
	# MatchFlow only recognizes committed MineWars runs. The neutral hub,
	# Adventure, and LineWars intentionally expose no wave number.
	current_wave_number = null

func begin_run_from_preparation() -> void:
	super.begin_run_from_preparation()
	current_wave_number = 1 if GameMode.is_siege() else null

func _begin_player_journey() -> void:
	# MineWars keeps the original onboarding/wave presentation. Adventure and
	# LineWars have their own controllers and should not flash the old wave intro.
	if GameMode.is_siege():
		super._begin_player_journey()

func _process(delta: float) -> void:
	if current_wave_number == null:
		return
	super._process(delta)

func _add_wasd_input() -> void:
	if bool(Global.get_meta(INPUT_REGISTRATION_META, false)):
		return
	Global.set_meta(INPUT_REGISTRATION_META, true)
	super._add_wasd_input()

func generate_initial_world() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.1

	for x in range(-WORLD_WIDTH / 2, WORLD_WIDTH / 2):
		for y in range(WORLD_TOP, WORLD_DEPTH):
			var cell := Vector2i(x, y)
			var block_type = 1
			if cell.x <= -20 or cell.x >= 19 or cell.y >= 29 or (cell.y <= 1 and cell.x != 0) or cell.y < 0:
				block_type = 16
			elif y >= 0:
				var depth_factor = y / float(WORLD_DEPTH)
				var n_val = noise.get_noise_2d(x, y)
				var score = depth_factor + n_val * 0.5
				if score > 0.8:
					block_type = 3
				elif score > 0.4:
					block_type = 2

			block_layer.set_cell(cell, block_type, Vector2i(0, 0))
			if astar.is_in_bounds(cell.x, cell.y):
				astar.set_point_solid(cell, true)

			if y >= 0 and randf() < 0.10:
				block_layer.set_cell(cell, BLOCK_GEM, Vector2i.ZERO)

	_ensure_tutorial_gem()

	for x in range(-WORLD_WIDTH / 2, WORLD_WIDTH / 2):
		for y in range(WORLD_TOP, WORLD_DEPTH):
			update_fog_mask(Vector2i(x, y))
			update_front_wall(Vector2i(x, y))
			update_inside_corners(Vector2i(x, y))

	for x in range(-WORLD_WIDTH / 2, WORLD_WIDTH / 2):
		for y in range(WORLD_TOP, WORLD_DEPTH):
			update_astar_weight(Vector2i(x, y))

	# Main hero hall.
	_carve_rect(HUB_ROOM_X_MIN, HUB_ROOM_X_MAX, HUB_ROOM_Y_MIN, HUB_ROOM_Y_MAX)

	# Short, centered entrances through the room walls.
	_carve_rect(LINE_WARS_ROUTE_X_MIN, LINE_WARS_ROUTE_X_MAX, LINE_WARS_ROUTE_Y_MIN, LINE_WARS_ROUTE_Y_MAX)
	_carve_rect(MINE_WARS_ROUTE_X_MIN, MINE_WARS_ROUTE_X_MAX, MINE_WARS_ROUTE_Y_MIN, MINE_WARS_ROUTE_Y_MAX)
	_carve_rect(ADVENTURE_ROUTE_X_MIN, ADVENTURE_ROUTE_X_MAX, ADVENTURE_ROUTE_Y_MIN, ADVENTURE_ROUTE_Y_MAX)

	# The Adventure chamber remains available after committing to the route.
	_carve_rect(ADVENTURE_ROOM_X_MIN, ADVENTURE_ROOM_X_MAX, ADVENTURE_ROOM_Y_MIN, ADVENTURE_ROOM_Y_MAX)

func _carve_rect(x_min: int, x_max: int, y_min: int, y_max: int) -> void:
	for x in range(x_min, x_max + 1):
		for y in range(y_min, y_max + 1):
			_on_generation_cell_dug(Vector2i(x, y))

func _on_generation_cell_dug(cell: Vector2i) -> void:
	# TileMap terrain extends above the legacy A* region. Always carve the tile;
	# world.on_cell_dug already updates A* only when the cell is inside its bounds.
	on_cell_dug(cell)

func is_dig_cell_protected(cell: Vector2i) -> bool:
	if bool(get_meta("single_player_hub_active", false)):
		# The hub is a composed menu room. Its three exits are already open, so the
		# surrounding walls stay intact until a mode is committed.
		return true
	if GameMode.is_line_wars():
		# The hero may mine normally below, revisit the entrance, and explore the
		# upper LineWars field without destroying unrelated base-room supports.
		if cell.y >= 5:
			return false
		if cell.x >= LINE_WARS_ROUTE_X_MIN and cell.x <= LINE_WARS_ROUTE_X_MAX:
			return false
		if cell.y <= -7:
			return false
		return true
	return super.is_dig_cell_protected(cell)

func get_protected_dig_message(_cell: Vector2i) -> String:
	if bool(get_meta("single_player_hub_active", false)):
		return "The Hero Hall walls are protected. Walk through the top, right, or bottom doorway."
	return super.get_protected_dig_message(_cell)

func _ensure_tutorial_gem() -> void:
	if is_vs_mode or block_layer.get_cell_source_id(PREPARATION_TUTORIAL_GEM_CELL) == BLOCK_GEM:
		return
	block_layer.set_cell(PREPARATION_TUTORIAL_GEM_CELL, BLOCK_GEM, Vector2i.ZERO)
	if astar.is_in_bounds(PREPARATION_TUTORIAL_GEM_CELL.x, PREPARATION_TUTORIAL_GEM_CELL.y):
		astar.set_point_solid(PREPARATION_TUTORIAL_GEM_CELL, true)
