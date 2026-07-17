extends "res://scripts/systems/world_generation/world.gd"

# The Single Player preparation hub already contains the mine that all three
# gates will use. Keep its initial generation lightweight so entering the hub
# does not synchronously create hundreds of invisible gem Sprite2D nodes.

const PREPARATION_GEM_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/stats/StatRessources.png")
const PREPARATION_GEM_TOP_SCALE := Vector2(0.58, 0.58)
const PREPARATION_GEM_FRONT_SCALE := Vector2(0.46, 0.46)
const PREPARATION_GEM_Z_INDEX := 2
const PREPARATION_TUTORIAL_GEM_CELL := Vector2i(0, 2)
const INPUT_REGISTRATION_META := "single_player_runtime_input_ready"

func _init() -> void:
	# MatchFlow recognizes a world by a non-null current_wave_number. Keep the
	# preparation hub out of match logic until the player actually picks a mode.
	current_wave_number = null

func begin_run_from_preparation() -> void:
	super.begin_run_from_preparation()
	# Standard MineWars uses the normal wave/result flow. Adventure and LineWars
	# have their own directors and intentionally stay invisible to MatchFlow.
	current_wave_number = 1 if GameMode.is_siege() else null

func _add_wasd_input() -> void:
	# world.gd normally appends the same keyboard and gamepad events every time a
	# Level is created. A player returning to Single Player would therefore build
	# an ever-growing InputMap. Register them once for this persistent hub.
	if bool(Global.get_meta(INPUT_REGISTRATION_META, false)):
		return
	Global.set_meta(INPUT_REGISTRATION_META, true)
	super._add_wasd_input()

func generate_initial_world() -> void:
	var width = 40
	var depth = 30

	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.1

	for x in range(-width / 2, width / 2):
		for y in range(-10, depth):
			var cell := Vector2i(x, y)
			var block_type = 1
			if y >= 0:
				var depth_factor = y / float(depth)
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
				# Store only gameplay data. Visuals are allocated later, and only if
				# mining actually exposes one of this block's faces.
				gem_blocks[cell] = {"top": null, "front": null}

	_ensure_tutorial_gem()

	for x in range(-width / 2, width / 2):
		for y in range(-10, depth):
			update_fog_mask(Vector2i(x, y))
			update_front_wall(Vector2i(x, y))

	for x in range(-width / 2, width / 2):
		for y in range(-10, depth):
			update_astar_weight(Vector2i(x, y))

	for x in range(-5, 6):
		for y in range(-4, 0):
			var cell := Vector2i(x, y)
			if astar.is_in_bounds(cell.x, cell.y):
				on_cell_dug(cell)

	for x in range(-2, 3):
		for y in range(0, 2):
			var cell := Vector2i(x, y)
			if astar.is_in_bounds(cell.x, cell.y):
				on_cell_dug(cell)
	_carve_surface_breach_corridors()

func _ensure_tutorial_gem() -> void:
	if is_vs_mode or gem_blocks.has(PREPARATION_TUTORIAL_GEM_CELL):
		return
	block_layer.set_cell(PREPARATION_TUTORIAL_GEM_CELL, 1, Vector2i(0, 0))
	if astar.is_in_bounds(PREPARATION_TUTORIAL_GEM_CELL.x, PREPARATION_TUTORIAL_GEM_CELL.y):
		astar.set_point_solid(PREPARATION_TUTORIAL_GEM_CELL, true)
	gem_blocks[PREPARATION_TUTORIAL_GEM_CELL] = {"top": null, "front": null}

func _normalize_gem_indicator_sprites() -> void:
	# Initial generation has no gem sprites to normalize. This pass creates only
	# the tiny number that border the starting clearing.
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
