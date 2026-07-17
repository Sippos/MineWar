extends "res://scripts/systems/world_generation/world.gd"

# Single Player owns one persistent generated world. The base room is the hub,
# MineWars and Adventure continue into the lower mine, and LineWars is a real
# chamber above the base reached with the normal hero digging interaction.

const PREPARATION_GEM_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/stats/StatRessources.png")
const PREPARATION_GEM_TOP_SCALE := Vector2(0.58, 0.58)
const PREPARATION_GEM_FRONT_SCALE := Vector2(0.46, 0.46)
const PREPARATION_GEM_Z_INDEX := 2
const PREPARATION_TUTORIAL_GEM_CELL := Vector2i(0, 2)
const INPUT_REGISTRATION_META := "single_player_runtime_input_ready"

const WORLD_WIDTH := 40
const WORLD_TOP := -33
const WORLD_DEPTH := 30
const SURFACE_ROOM_X_MIN := -10
const SURFACE_ROOM_X_MAX := 10
const SURFACE_ROOM_Y_MIN := -14
const SURFACE_ROOM_Y_MAX := -7
const ADVENTURE_ROOM_X_MIN := 11
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
			if y >= 0:
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
				gem_blocks[cell] = {"top": null, "front": null}

	_ensure_tutorial_gem()

	for x in range(-WORLD_WIDTH / 2, WORLD_WIDTH / 2):
		for y in range(WORLD_TOP, WORLD_DEPTH):
			update_fog_mask(Vector2i(x, y))
			update_front_wall(Vector2i(x, y))

	for x in range(-WORLD_WIDTH / 2, WORLD_WIDTH / 2):
		for y in range(WORLD_TOP, WORLD_DEPTH):
			update_astar_weight(Vector2i(x, y))

	# Original first-version base room: one compact clearing with solid rock in
	# every direction. The player chooses a mode by mining out of this room.
	for x in range(-5, 6):
		for y in range(-4, 0):
			_on_generation_cell_dug(Vector2i(x, y))

	# The LineWars chamber is already part of the same TileMap, but remains hidden
	# behind a long column of actual mine blocks until the hero digs upward.
	for x in range(SURFACE_ROOM_X_MIN, SURFACE_ROOM_X_MAX + 1):
		for y in range(SURFACE_ROOM_Y_MIN, SURFACE_ROOM_Y_MAX + 1):
			_on_generation_cell_dug(Vector2i(x, y))

	# Adventure has a buried side chamber. The player still has to mine through
	# the eastern wall before its controller activates.
	for x in range(ADVENTURE_ROOM_X_MIN, ADVENTURE_ROOM_X_MAX + 1):
		for y in range(ADVENTURE_ROOM_Y_MIN, ADVENTURE_ROOM_Y_MAX + 1):
			_on_generation_cell_dug(Vector2i(x, y))

func _on_generation_cell_dug(cell: Vector2i) -> void:
	# TileMap terrain extends above the legacy A* region. Always carve the tile;
	# world.on_cell_dug already updates A* only when the cell is inside its bounds.
	on_cell_dug(cell)

func is_dig_cell_protected(cell: Vector2i) -> bool:
	if bool(get_meta("single_player_hub_active", false)):
		# Three deliberate exits keep the base readable while every transition uses
		# the exact same hero digging code as the lower mine.
		var vertical_route := cell.x >= 2 and cell.x <= 4
		var adventure_route := cell.x >= 5 and cell.x <= ADVENTURE_ROOM_X_MAX and cell.y >= -4 and cell.y <= 3
		return not vertical_route and not adventure_route
	if GameMode.is_line_wars():
		# The hero may mine normally below, revisit the breakthrough shaft, and
		# explore the real upper chamber without destroying unrelated base supports.
		if cell.y >= 0:
			return false
		if cell.x >= 2 and cell.x <= 4:
			return false
		if cell.y <= -22:
			return false
		return true
	return super.is_dig_cell_protected(cell)

func get_protected_dig_message(_cell: Vector2i) -> String:
	if bool(get_meta("single_player_hub_active", false)):
		return "The base supports are protected. Dig through a marked route: up, down, or east."
	return super.get_protected_dig_message(_cell)

func _ensure_tutorial_gem() -> void:
	if is_vs_mode or gem_blocks.has(PREPARATION_TUTORIAL_GEM_CELL):
		return
	block_layer.set_cell(PREPARATION_TUTORIAL_GEM_CELL, 1, Vector2i(0, 0))
	if astar.is_in_bounds(PREPARATION_TUTORIAL_GEM_CELL.x, PREPARATION_TUTORIAL_GEM_CELL.y):
		astar.set_point_solid(PREPARATION_TUTORIAL_GEM_CELL, true)
	gem_blocks[PREPARATION_TUTORIAL_GEM_CELL] = {"top": null, "front": null}

func _normalize_gem_indicator_sprites() -> void:
	for raw_cell: Variant in gem_blocks.keys():
		_refresh_gem_indicator(Vector2i(raw_cell))

func _ensure_lazy_gem_sprites(cell: Vector2i) -> Dictionary:
	var sprites: Dictionary = gem_blocks.get(cell, {"top": null, "front": null})
	var top_sprite := sprites.get("top") as Sprite2D
	var front_sprite := sprites.get("front") as Sprite2D

	if not is_instance_valid(top_sprite):
		top_sprite = Sprite2D.new()
		top_sprite.name = "GemTop_%d_%d" % [cell.x, cell.y]
		top_sprite.texture = PREPARATION_GEM_TEXTURE
		top_sprite.region_enabled = false
		top_sprite.scale = PREPARATION_GEM_TOP_SCALE
		top_sprite.z_index = PREPARATION_GEM_Z_INDEX
		top_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		top_sprite.visible = false
		add_child(top_sprite)
		sprites["top"] = top_sprite

	if not is_instance_valid(front_sprite):
		front_sprite = Sprite2D.new()
		front_sprite.name = "GemFront_%d_%d" % [cell.x, cell.y]
		front_sprite.texture = PREPARATION_GEM_TEXTURE
		front_sprite.region_enabled = false
		front_sprite.offset = Vector2(0.0, -16.0)
		front_sprite.scale = PREPARATION_GEM_FRONT_SCALE
		front_sprite.z_index = PREPARATION_GEM_Z_INDEX
		front_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		front_sprite.visible = false
		add_child(front_sprite)
		sprites["front"] = front_sprite

	gem_blocks[cell] = sprites
	return sprites

func _refresh_gem_indicator(cell: Vector2i) -> void:
	if not gem_blocks.has(cell):
		return

	var solid := block_layer.get_cell_source_id(cell) != -1
	var top_open := solid and block_layer.get_cell_source_id(Vector2i(cell.x, cell.y - 1)) == -1
	var right_open := solid and block_layer.get_cell_source_id(Vector2i(cell.x + 1, cell.y)) == -1
	var bottom_open := solid and block_layer.get_cell_source_id(Vector2i(cell.x, cell.y + 1)) == -1
	var left_open := solid and block_layer.get_cell_source_id(Vector2i(cell.x - 1, cell.y)) == -1
	var show_front := bottom_open
	var show_top := solid and not show_front and (top_open or right_open or left_open)

	var sprites: Dictionary = gem_blocks[cell]
	var top_sprite := sprites.get("top") as Sprite2D
	var front_sprite := sprites.get("front") as Sprite2D
	if (show_top or show_front) and (not is_instance_valid(top_sprite) or not is_instance_valid(front_sprite)):
		sprites = _ensure_lazy_gem_sprites(cell)
		top_sprite = sprites.get("top") as Sprite2D
		front_sprite = sprites.get("front") as Sprite2D

	if is_instance_valid(top_sprite):
		top_sprite.visible = show_top
		if show_top:
			var indicator_offset := Vector2.ZERO
			if top_open:
				indicator_offset = Vector2(0.0, -18.0)
			elif left_open and not right_open:
				indicator_offset = Vector2(-18.0, 0.0)
			elif right_open and not left_open:
				indicator_offset = Vector2(18.0, 0.0)
			top_sprite.global_position = block_layer.to_global(block_layer.map_to_local(cell)) + indicator_offset

	if is_instance_valid(front_sprite):
		_position_front_gem_sprite(front_sprite, cell)
		front_sprite.visible = show_front
