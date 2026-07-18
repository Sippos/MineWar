extends "res://scripts/systems/world_generation/world_terrain_runtime.gd"

# Single Player owns one persistent generated world. The preparation area is a
# deliberately composed hero hall: one rectangular room, three obvious exits,
# and the same mine continuing beyond those exits.

# Buried resources use tile-sized transparent decals. They read as crystals
# embedded in an exposed dirt face instead of a scaled-down loose gem/UI icon.
const GEM_TEXTURE_FACTORY = preload("res://scripts/systems/preparation/gem_indicator_texture_factory.gd")
const PREPARATION_GEM_ATLAS_PATH := "res://assets/sprites/world/terrain/gem_overlays/minewars_gem_overlay_atlas.png"
const PREPARATION_GEM_Z_INDEX := 5
const GEM_CELL_SIZE := 64
const GEM_TOP_REGIONS := [
	Rect2(0, 0, GEM_CELL_SIZE, GEM_CELL_SIZE),
	Rect2(GEM_CELL_SIZE, 0, GEM_CELL_SIZE, GEM_CELL_SIZE),
	Rect2(GEM_CELL_SIZE * 2, 0, GEM_CELL_SIZE, GEM_CELL_SIZE),
	Rect2(GEM_CELL_SIZE * 3, 0, GEM_CELL_SIZE, GEM_CELL_SIZE),
]
const GEM_FRONT_REGIONS := [
	Rect2(0, GEM_CELL_SIZE, GEM_CELL_SIZE, GEM_CELL_SIZE),
	Rect2(GEM_CELL_SIZE, GEM_CELL_SIZE, GEM_CELL_SIZE, GEM_CELL_SIZE),
	Rect2(GEM_CELL_SIZE * 2, GEM_CELL_SIZE, GEM_CELL_SIZE, GEM_CELL_SIZE),
	Rect2(GEM_CELL_SIZE * 3, GEM_CELL_SIZE, GEM_CELL_SIZE, GEM_CELL_SIZE),
]
const PREPARATION_TUTORIAL_GEM_CELL := Vector2i(0, 9)
const INPUT_REGISTRATION_META := "single_player_runtime_input_ready"

const WORLD_WIDTH := 40
const WORLD_TOP := -33
const WORLD_DEPTH := 30

# The expanded room is 15 × 9 tiles. A fresh save deliberately starts with a
# smaller 9 × 7 room so the first decision is only "take this hero into this
# bastion" and "descend into MineWars". The wider stronghold appears after the
# first completed MineWars run.
const HUB_ROOM_X_MIN := -7
const HUB_ROOM_X_MAX := 7
const HUB_ROOM_Y_MIN := -4
const HUB_ROOM_Y_MAX := 4
const COMPACT_HUB_ROOM_X_MIN := -4
const COMPACT_HUB_ROOM_X_MAX := 4
const COMPACT_HUB_ROOM_Y_MIN := -3
const COMPACT_HUB_ROOM_Y_MAX := 3

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

var preparation_gem_overlay_atlas: Texture2D

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

	var expanded_stronghold := bool(Global.first_level_beaten)
	var room_x_min := HUB_ROOM_X_MIN if expanded_stronghold else COMPACT_HUB_ROOM_X_MIN
	var room_x_max := HUB_ROOM_X_MAX if expanded_stronghold else COMPACT_HUB_ROOM_X_MAX
	var room_y_min := HUB_ROOM_Y_MIN if expanded_stronghold else COMPACT_HUB_ROOM_Y_MIN
	var room_y_max := HUB_ROOM_Y_MAX if expanded_stronghold else COMPACT_HUB_ROOM_Y_MAX

	# Main hero hall. Fresh saves get only the base-sized starter room.
	_carve_rect(room_x_min, room_x_max, room_y_min, room_y_max)

	# MineWars is the only doorway available on the first visit. Its lower route
	# starts directly at the compact room floor; expanded saves retain the older
	# three-cell doorway layout and the extra mode routes.
	if expanded_stronghold:
		_carve_rect(LINE_WARS_ROUTE_X_MIN, LINE_WARS_ROUTE_X_MAX, LINE_WARS_ROUTE_Y_MIN, LINE_WARS_ROUTE_Y_MAX)
		_carve_rect(MINE_WARS_ROUTE_X_MIN, MINE_WARS_ROUTE_X_MAX, MINE_WARS_ROUTE_Y_MIN, MINE_WARS_ROUTE_Y_MAX)
		_carve_rect(ADVENTURE_ROUTE_X_MIN, ADVENTURE_ROUTE_X_MAX, ADVENTURE_ROUTE_Y_MIN, ADVENTURE_ROUTE_Y_MAX)
		_carve_rect(ADVENTURE_ROOM_X_MIN, ADVENTURE_ROOM_X_MAX, ADVENTURE_ROOM_Y_MIN, ADVENTURE_ROOM_Y_MAX)
	else:
		_carve_rect(MINE_WARS_ROUTE_X_MIN, MINE_WARS_ROUTE_X_MAX, COMPACT_HUB_ROOM_Y_MAX, MINE_WARS_ROUTE_Y_MAX)

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
	if is_vs_mode or gem_blocks.has(PREPARATION_TUTORIAL_GEM_CELL):
		return
	block_layer.set_cell(PREPARATION_TUTORIAL_GEM_CELL, 1, Vector2i(0, 0))
	if astar.is_in_bounds(PREPARATION_TUTORIAL_GEM_CELL.x, PREPARATION_TUTORIAL_GEM_CELL.y):
		astar.set_point_solid(PREPARATION_TUTORIAL_GEM_CELL, true)
	gem_blocks[PREPARATION_TUTORIAL_GEM_CELL] = {"top": null, "front": null}

func _normalize_gem_indicator_sprites() -> void:
	for raw_cell: Variant in gem_blocks.keys():
		_refresh_gem_indicator(Vector2i(raw_cell))

func _ensure_gem_indicator_textures() -> bool:
	if preparation_gem_overlay_atlas == null:
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(PREPARATION_GEM_ATLAS_PATH))
		if image != null and not image.is_empty():
			preparation_gem_overlay_atlas = ImageTexture.create_from_image(image)
	return preparation_gem_overlay_atlas != null

func _gem_variant(cell: Vector2i) -> int:
	return absi(cell.x * 17 + cell.y * 31) & 1

func _gem_cluster_size(cell: Vector2i) -> int:
	var size := 1
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if gem_blocks.has(cell + direction):
			size += 1
	return size

func _apply_gem_regions(cell: Vector2i, top_sprite: Sprite2D, front_sprite: Sprite2D) -> void:
	var variant := _gem_variant(cell)
	var rich_cluster := _gem_cluster_size(cell) >= 3
	top_sprite.region_rect = GEM_TOP_REGIONS[variant]
	front_sprite.region_rect = GEM_FRONT_REGIONS[3 if rich_cluster else variant]

func _ensure_lazy_gem_sprites(cell: Vector2i) -> Dictionary:
	var sprites: Dictionary = gem_blocks.get(cell, {"top": null, "front": null})
	var top_sprite := sprites.get("top") as Sprite2D
	var front_sprite := sprites.get("front") as Sprite2D
	if not _ensure_gem_indicator_textures():
		return sprites

	if not is_instance_valid(top_sprite):
		top_sprite = Sprite2D.new()
		top_sprite.name = "GemTop_%d_%d" % [cell.x, cell.y]
		top_sprite.texture = preparation_gem_overlay_atlas
		top_sprite.region_enabled = true
		top_sprite.scale = Vector2.ONE
		top_sprite.z_index = PREPARATION_GEM_Z_INDEX
		top_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		top_sprite.visible = false
		add_child(top_sprite)
		sprites["top"] = top_sprite

	if not is_instance_valid(front_sprite):
		front_sprite = Sprite2D.new()
		front_sprite.name = "GemFront_%d_%d" % [cell.x, cell.y]
		front_sprite.texture = preparation_gem_overlay_atlas
		front_sprite.region_enabled = true
		front_sprite.offset = Vector2.ZERO
		front_sprite.scale = Vector2.ONE
		front_sprite.z_index = PREPARATION_GEM_Z_INDEX
		front_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		front_sprite.visible = false
		add_child(front_sprite)
		sprites["front"] = front_sprite

	_apply_gem_regions(cell, top_sprite, front_sprite)
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
	var variant := _gem_variant(cell)

	var sprites: Dictionary = gem_blocks[cell]
	var top_sprite := sprites.get("top") as Sprite2D
	var front_sprite := sprites.get("front") as Sprite2D
	if (show_top or show_front) and (not is_instance_valid(top_sprite) or not is_instance_valid(front_sprite)):
		sprites = _ensure_lazy_gem_sprites(cell)
		top_sprite = sprites.get("top") as Sprite2D
		front_sprite = sprites.get("front") as Sprite2D
	if is_instance_valid(top_sprite) and is_instance_valid(front_sprite):
		_apply_gem_regions(cell, top_sprite, front_sprite)

	if is_instance_valid(top_sprite):
		top_sprite.visible = show_top
		if show_top:
			top_sprite.global_position = block_layer.to_global(block_layer.map_to_local(cell))
			top_sprite.region_rect = GEM_TOP_REGIONS[variant if top_open else (2 if left_open and not right_open else 3)]

	if is_instance_valid(front_sprite):
		_position_front_gem_sprite(front_sprite, cell)
		front_sprite.visible = show_front
