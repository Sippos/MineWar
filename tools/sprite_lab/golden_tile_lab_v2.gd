extends "res://tools/sprite_lab/sprite_lab_builder.gd"

const GOLDEN_RECIPE_PATH := "res://tools/sprite_lab/recipes/golden_tile_v2.json"
const STAMP_PATH := "res://tools/sprite_lab/stamps/easy_clods_v2.json"
const GOLDEN_OUTPUT_DIR := "res://assets/sprites/world/terrain/generated_sprite_lab/golden_v2"

var golden_recipe: Dictionary = {}
var stamp_document: Dictionary = {}
var stamp_legend: Dictionary = {}
var stamp_definitions: Dictionary = {}
var stamp_cache: Dictionary = {}

func _ready() -> void:
	if not _load_golden_configuration():
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_OUTPUT_DIR))

	var fills: Array[Image] = _build_golden_fill_variants()
	var edges: Array[Image] = _build_golden_edge_masks()
	var fronts: Array[Image] = _build_golden_front_walls()
	var damage: Array[Image] = _build_golden_damage_overlays()
	var golden_tiles: Array[Image] = _build_golden_tiles(fills, edges, fronts, damage)
	var stamp_tiles: Array[Image] = _build_stamp_tiles()

	var saved: bool = true
	saved = _save_golden_atlas("easy_fill_v2_atlas.png", fills, 4) and saved
	saved = _save_golden_atlas("easy_edges_v2_atlas.png", edges, 4) and saved
	saved = _save_golden_atlas("easy_fronts_v2_atlas.png", fronts, 4) and saved
	saved = _save_golden_atlas("damage_v2_atlas.png", damage, 4) and saved
	saved = _save_golden_atlas("golden_tiles_v2_atlas.png", golden_tiles, 5) and saved
	saved = _save_golden_atlas("stamp_library_v2.png", stamp_tiles, 5) and saved

	var golden_board: Image = _pack_with_gap(golden_tiles, 5, 8, _color("preview_background"))
	var repetition_board: Image = _build_repetition_board(fills)
	var excavation_board: Image = _build_excavation_board(fills, edges, fronts, 18, 10)
	var lighting_board: Image = _build_lighting_board(fills, edges, fronts)
	var scale_board: Image = _build_scale_board(golden_tiles)
	saved = _save_golden_image("preview_golden_tiles_v2.png", golden_board) and saved
	saved = _save_golden_image("preview_repetition_v2.png", repetition_board) and saved
	saved = _save_golden_image("preview_excavation_v2.png", excavation_board) and saved
	saved = _save_golden_image("preview_lighting_v2.png", lighting_board) and saved
	saved = _save_golden_image("preview_scale_v2.png", scale_board) and saved

	var report: Dictionary = _validate_golden_outputs(fills, edges, fronts, damage, golden_tiles)
	report["files_saved"] = saved
	_write_golden_json("validation_report_v2.json", report)
	_write_golden_json("golden_tile_manifest.json", _golden_manifest())
	var passed: bool = saved and bool(report.get("passed", false))
	print("GOLDEN_TILE_LAB_V2_", "PASS" if passed else "FAIL", " output=", GOLDEN_OUTPUT_DIR)
	get_tree().quit(0 if passed else 1)

func _load_golden_configuration() -> bool:
	style = _load_json(STYLE_PATH)
	golden_recipe = _load_json(GOLDEN_RECIPE_PATH)
	stamp_document = _load_json(STAMP_PATH)
	if style.is_empty() or golden_recipe.is_empty() or stamp_document.is_empty():
		push_error("Golden Tile Lab v2 configuration is missing.")
		return false
	var raw_palette: Variant = style.get("palette", {})
	if not raw_palette is Dictionary:
		push_error("Golden Tile Lab palette is invalid.")
		return false
	palette = raw_palette
	logical_size = int(style.get("logical_size", 32))
	export_scale = int(style.get("export_scale", 2))
	tile_size = int(style.get("tile_size", logical_size * export_scale))
	var legend_value: Variant = stamp_document.get("legend", {})
	var definitions_value: Variant = stamp_document.get("stamps", {})
	if not legend_value is Dictionary or not definitions_value is Dictionary:
		push_error("Golden Tile stamp document is invalid.")
		return false
	stamp_legend = legend_value
	stamp_definitions = definitions_value
	return logical_size == 32 and tile_size == logical_size * export_scale

func _stamp_rows(stamp_id: String) -> Array:
	var definition_value: Variant = stamp_definitions.get(stamp_id, {})
	if not definition_value is Dictionary:
		return []
	var definition: Dictionary = definition_value
	var rows_value: Variant = definition.get("rows", [])
	return rows_value if rows_value is Array else []

func _base_stamp(stamp_id: String) -> Image:
	var cached_value: Variant = stamp_cache.get(stamp_id, null)
	if cached_value is Image:
		return cached_value
	var rows: Array = _stamp_rows(stamp_id)
	if rows.is_empty():
		return _new_image(1, 1, _color("transparent"))
	var width: int = 1
	for row_value: Variant in rows:
		width = maxi(width, String(row_value).length())
	var image: Image = _new_image(width, rows.size(), _color("transparent"))
	for y: int in range(rows.size()):
		var row: String = String(rows[y])
		for x: int in range(row.length()):
			var character: String = row.substr(x, 1)
			var color_name: String = String(stamp_legend.get(character, "transparent"))
			image.set_pixel(x, y, _color(color_name))
	stamp_cache[stamp_id] = image
	return image

func _transformed_stamp(stamp_id: String, flip_x: bool, flip_y: bool, quarter_turns: int = 0) -> Image:
	var base: Image = _base_stamp(stamp_id)
	var flipped: Image = _new_image(base.get_width(), base.get_height(), _color("transparent"))
	for y: int in range(base.get_height()):
		for x: int in range(base.get_width()):
			var source_x: int = base.get_width() - 1 - x if flip_x else x
			var source_y: int = base.get_height() - 1 - y if flip_y else y
			flipped.set_pixel(x, y, base.get_pixel(source_x, source_y))
	return _rotate_image_quarters(flipped, quarter_turns)

func _rotate_image_quarters(source: Image, quarter_turns: int) -> Image:
	var turns: int = posmod(quarter_turns, 4)
	if turns == 0:
		return source
	var current: Image = source
	for _turn: int in range(turns):
		var rotated: Image = _new_image(current.get_height(), current.get_width(), _color("transparent"))
		for y: int in range(current.get_height()):
			for x: int in range(current.get_width()):
				rotated.set_pixel(current.get_height() - 1 - y, x, current.get_pixel(x, y))
		current = rotated
	return current

func _overlay_stamp(destination: Image, stamp_id: String, position: Vector2i, flip_x: bool = false, flip_y: bool = false, quarter_turns: int = 0) -> void:
	var stamp: Image = _transformed_stamp(stamp_id, flip_x, flip_y, quarter_turns)
	_overlay(destination, stamp, position)

func _draw_soil_patch(image: Image, center: Vector2i, radius_x: int, radius_y: int, color: Color, seed: int) -> void:
	for y: int in range(center.y - radius_y, center.y + radius_y + 1):
		for x: int in range(center.x - radius_x, center.x + radius_x + 1):
			var normalized_x: float = float(x - center.x) / float(maxi(radius_x, 1))
			var normalized_y: float = float(y - center.y) / float(maxi(radius_y, 1))
			var jitter: float = float(_hash(seed, x / 2, y / 2) % 9) / 40.0
			if normalized_x * normalized_x + normalized_y * normalized_y + jitter <= 1.0:
				_set_pixel(image, x, y, color)

func _make_golden_fill(variant: Dictionary, variant_index: int) -> Image:
	var image: Image = _new_image(logical_size, logical_size, _color("easy_mid"))
	var seed: int = int(golden_recipe.get("seed", 7201)) + variant_index * 173
	_draw_soil_patch(image, Vector2i(7 + variant_index, 8), 10, 7, _color("easy_dark"), seed + 11)
	_draw_soil_patch(image, Vector2i(23 - variant_index, 20), 11, 9, _color("easy_light"), seed + 23)
	_draw_soil_patch(image, Vector2i(13, 28 - variant_index), 9, 5, _color("easy_dark"), seed + 37)
	var placements_value: Variant = variant.get("placements", [])
	if placements_value is Array:
		var placements: Array = placements_value
		for placement_value: Variant in placements:
			if not placement_value is Dictionary:
				continue
			var placement: Dictionary = placement_value
			_overlay_stamp(
				image,
				String(placement.get("stamp", "")),
				Vector2i(int(placement.get("x", 0)), int(placement.get("y", 0))),
				bool(placement.get("flip_x", false)),
				bool(placement.get("flip_y", false))
			)
	for index: int in range(4):
		var mark_x: int = 3 + (_hash(seed + 71, index, 1) % 26)
		var mark_y: int = 3 + (_hash(seed + 83, index, 2) % 26)
		_set_pixel(image, mark_x, mark_y, _color("easy_highlight") if index % 2 == 0 else _color("deep_shadow"))
		if index % 2 == 0:
			_set_pixel(image, mark_x + 1, mark_y, _color("easy_light"))
	return image

func _build_golden_fill_variants() -> Array[Image]:
	var result: Array[Image] = []
	var variants_value: Variant = golden_recipe.get("fill_variants", [])
	if not variants_value is Array:
		return result
	var variants: Array = variants_value
	for index: int in range(variants.size()):
		var variant_value: Variant = variants[index]
		if variant_value is Dictionary:
			result.append(_make_golden_fill(variant_value, index))
	return result

func _edge_profile(side: int, seed: int) -> Array[int]:
	var config_value: Variant = golden_recipe.get("edge_profiles", {})
	var config: Dictionary = config_value if config_value is Dictionary else {}
	var minimum_depth: int = int(config.get("minimum_depth", 2))
	var maximum_depth: int = int(config.get("maximum_depth", 5))
	var segment_length: int = maxi(2, int(config.get("segment_length", 4)))
	var anchor_count: int = ceili(float(logical_size) / float(segment_length)) + 1
	var anchors: Array[int] = []
	for anchor_index: int in range(anchor_count):
		anchors.append(minimum_depth + (_hash(seed + side * 997, anchor_index, side) % (maximum_depth - minimum_depth + 1)))
	var profile: Array[int] = []
	for pixel_index: int in range(logical_size):
		var segment_index: int = mini(pixel_index / segment_length, anchors.size() - 2)
		var local_index: int = pixel_index % segment_length
		var blend: float = float(local_index) / float(segment_length)
		var depth: int = roundi(lerpf(float(anchors[segment_index]), float(anchors[segment_index + 1]), blend))
		profile.append(clampi(depth, minimum_depth, maximum_depth))
	return profile

func _draw_exposed_side(image: Image, side: int, seed: int) -> void:
	var profile: Array[int] = _edge_profile(side, seed)
	for index: int in range(logical_size):
		var depth: int = profile[index]
		for layer: int in range(depth + 1):
			var color: Color = _color("deep_shadow")
			if layer == 0:
				color = _color("cave")
			elif layer == depth - 1:
				color = _color("outline")
			elif layer == depth:
				color = _color("easy_highlight") if _hash(seed + 41, index, layer) % 4 != 0 else _color("easy_light")
			var point: Vector2i = Vector2i(index, layer)
			if side == 1:
				point = Vector2i(logical_size - 1 - layer, index)
			elif side == 2:
				point = Vector2i(index, logical_size - 1 - layer)
			elif side == 3:
				point = Vector2i(layer, index)
			_set_pixel(image, point.x, point.y, color)
	var chunk_position: int = 5 + (_hash(seed + 59, side, 3) % 16)
	if side == 0:
		_overlay_stamp(image, "edge_chunk_a", Vector2i(chunk_position, 0))
	elif side == 1:
		_overlay_stamp(image, "edge_chunk_b", Vector2i(logical_size - 5, chunk_position), false, false, 1)
	elif side == 2:
		_overlay_stamp(image, "edge_chunk_a", Vector2i(chunk_position, logical_size - 5), false, false, 2)
	else:
		_overlay_stamp(image, "edge_chunk_b", Vector2i(0, chunk_position), false, false, 3)

func _make_golden_edge(mask: int, seed: int) -> Image:
	var image: Image = _new_image(logical_size, logical_size, _color("transparent"))
	if (mask & 1) != 0:
		_draw_exposed_side(image, 0, seed + 11)
	if (mask & 2) != 0:
		_draw_exposed_side(image, 1, seed + 23)
	if (mask & 4) != 0:
		_draw_exposed_side(image, 2, seed + 37)
	if (mask & 8) != 0:
		_draw_exposed_side(image, 3, seed + 53)
	return image

func _build_golden_edge_masks() -> Array[Image]:
	var result: Array[Image] = []
	var config_value: Variant = golden_recipe.get("edge_profiles", {})
	var config: Dictionary = config_value if config_value is Dictionary else {}
	var seed_base: int = int(config.get("seed_base", 8100))
	for mask: int in range(16):
		result.append(_make_golden_edge(mask, seed_base + mask * 109))
	return result

func _make_golden_front(state: int, seed: int) -> Image:
	var config_value: Variant = golden_recipe.get("front_walls", {})
	var config: Dictionary = config_value if config_value is Dictionary else {}
	var visible_depth: int = int(config.get("visible_depth", 20))
	var image: Image = _new_image(logical_size, logical_size, _color("transparent"))
	for y: int in range(visible_depth + 4):
		for x: int in range(logical_size):
			var color: Color = _color("easy_mid")
			var broad_roll: int = _hash(seed, x / 4, y / 3) % 10
			if broad_roll < 3:
				color = _color("easy_dark")
			elif broad_roll > 7:
				color = _color("easy_light")
			image.set_pixel(x, y, color)
	_overlay_stamp(image, "large_clod_a", Vector2i(-1, 2))
	_overlay_stamp(image, "large_clod_c", Vector2i(17, 3), true, false)
	_overlay_stamp(image, "medium_clod_b", Vector2i(9, 11))
	var bottom_profile: Array[int] = []
	for x: int in range(logical_size):
		var bottom_y: int = visible_depth + (_hash(seed + 97, x / 3, 5) % 5) - 2
		bottom_profile.append(clampi(bottom_y, 16, 24))
	for x: int in range(logical_size):
		var bottom_y_value: int = bottom_profile[x]
		for y: int in range(bottom_y_value + 1, logical_size):
			image.set_pixel(x, y, _color("transparent"))
		_set_pixel(image, x, bottom_y_value, _color("outline"))
		if bottom_y_value - 1 >= 0:
			_set_pixel(image, x, bottom_y_value - 1, _color("deep_shadow"))
		if bottom_y_value - 2 >= 0 and _hash(seed + 101, x, 9) % 3 != 0:
			_set_pixel(image, x, bottom_y_value - 2, _color("easy_dark"))
	for x: int in range(logical_size):
		_set_pixel(image, x, 0, _color("easy_highlight") if _hash(seed + 17, x, 0) % 5 != 0 else _color("easy_light"))
		_set_pixel(image, x, 1, _color("outline"))
	var left_connected: bool = (state & 1) != 0
	var right_connected: bool = (state & 2) != 0
	if not left_connected:
		for y: int in range(11, logical_size):
			var cut_left: int = clampi((y - 9) / 3, 1, 5)
			for x: int in range(cut_left):
				image.set_pixel(x, y, _color("transparent"))
	if not right_connected:
		for y: int in range(11, logical_size):
			var cut_right: int = clampi((y - 9) / 3, 1, 5)
			for offset: int in range(cut_right):
				image.set_pixel(logical_size - 1 - offset, y, _color("transparent"))
	var root_x: int = 6 + (_hash(seed + 211, state, 1) % 19)
	for root_step: int in range(5):
		var root_y: int = 19 + root_step
		var root_offset: int = root_step / 2
		_set_pixel(image, root_x + root_offset, root_y, _color("outline"))
	return image

func _build_golden_front_walls() -> Array[Image]:
	var result: Array[Image] = []
	var config_value: Variant = golden_recipe.get("front_walls", {})
	var config: Dictionary = config_value if config_value is Dictionary else {}
	var seed_base: int = int(config.get("seed_base", 9200))
	for state: int in range(4):
		result.append(_make_golden_front(state, seed_base + state * 149))
	return result

func _make_golden_damage(direction: int, stage: int, seed: int) -> Image:
	var image: Image = _new_image(logical_size, logical_size, _color("transparent"))
	var center_x: int = 14 + (_hash(seed, stage, direction) % 5)
	var path: Array[Vector2i] = [
		Vector2i(center_x, 0),
		Vector2i(center_x - 1, 4),
		Vector2i(center_x + 3, 8),
		Vector2i(center_x - 2, 13),
		Vector2i(center_x + 2, 18),
		Vector2i(center_x - 4, 24),
		Vector2i(center_x, 30)
	]
	var segment_count: int = 2 + stage * 2
	for index: int in range(segment_count):
		var start: Vector2i = _rotate_from_top(path[index], direction)
		var finish: Vector2i = _rotate_from_top(path[index + 1], direction)
		_draw_line(image, start, finish, _color("crack_dark"), 2 if stage >= 1 else 1)
		if stage == 0:
			_draw_line(image, start, finish, _color("crack_light"), 1)
	if stage >= 1:
		var branch_start: Vector2i = _rotate_from_top(path[2], direction)
		var branch_end: Vector2i = _rotate_from_top(Vector2i(center_x - 8, 11), direction)
		_draw_line(image, branch_start, branch_end, _color("crack_dark"), 1)
		_draw_disc(image, _rotate_from_top(Vector2i(center_x + 2, 18), direction), 1, _color("deep_shadow"))
	if stage >= 2:
		var second_start: Vector2i = _rotate_from_top(path[4], direction)
		var second_end: Vector2i = _rotate_from_top(Vector2i(center_x + 10, 22), direction)
		_draw_line(image, second_start, second_end, _color("crack_dark"), 2)
		_draw_disc(image, _rotate_from_top(Vector2i(center_x, 24), direction), 3, _color("cave"))
		_draw_disc(image, _rotate_from_top(Vector2i(center_x, 24), direction), 2, _color("deep_shadow"))
		for chip_index: int in range(3):
			var chip_point: Vector2i = _rotate_from_top(Vector2i(center_x - 8 + chip_index * 7, 26 + chip_index), direction)
			_draw_disc(image, chip_point, 1, _color("outline"))
	return image

func _build_golden_damage_overlays() -> Array[Image]:
	var result: Array[Image] = []
	var config_value: Variant = golden_recipe.get("damage", {})
	var config: Dictionary = config_value if config_value is Dictionary else {}
	var stages: int = int(config.get("stages", 3))
	var directions: int = int(config.get("directions", 4))
	var seed_base: int = int(config.get("seed_base", 10400))
	for stage: int in range(stages):
		for direction: int in range(directions):
			result.append(_make_golden_damage(direction, stage, seed_base + stage * 101 + direction * 19))
	return result

func _composite_tile(fill: Image, edge: Image, damage_overlay: Image = null) -> Image:
	var result: Image = fill.duplicate()
	_overlay(result, edge)
	if damage_overlay != null:
		_overlay(result, damage_overlay)
	return result

func _build_golden_tiles(fills: Array[Image], edges: Array[Image], fronts: Array[Image], damage: Array[Image]) -> Array[Image]:
	var result: Array[Image] = []
	var definitions_value: Variant = golden_recipe.get("golden_tiles", [])
	if not definitions_value is Array:
		return result
	var definitions: Array = definitions_value
	for definition_value: Variant in definitions:
		if not definition_value is Dictionary:
			continue
		var definition: Dictionary = definition_value
		if definition.has("front_state"):
			result.append(fronts[clampi(int(definition.get("front_state", 0)), 0, fronts.size() - 1)].duplicate())
			continue
		var fill_index: int = posmod(int(definition.get("fill", 0)), fills.size())
		var mask: int = clampi(int(definition.get("mask", 0)), 0, 15)
		var tile: Image = _composite_tile(fills[fill_index], edges[mask])
		if definition.has("damage_direction") and definition.has("damage_stage"):
			var damage_direction: int = clampi(int(definition.get("damage_direction", 0)), 0, 3)
			var damage_stage: int = clampi(int(definition.get("damage_stage", 0)), 0, 2)
			_overlay(tile, damage[damage_stage * 4 + damage_direction])
		result.append(tile)
	return result

func _build_stamp_tiles() -> Array[Image]:
	var result: Array[Image] = []
	var stamp_ids: Array = stamp_definitions.keys()
	stamp_ids.sort()
	for stamp_id_value: Variant in stamp_ids:
		var stamp_id: String = String(stamp_id_value)
		var tile: Image = _new_image(logical_size, logical_size, _color("transparent"))
		var stamp: Image = _base_stamp(stamp_id)
		var position: Vector2i = Vector2i((logical_size - stamp.get_width()) / 2, (logical_size - stamp.get_height()) / 2)
		_overlay(tile, stamp, position)
		result.append(tile)
	return result

func _pack_with_gap(images: Array[Image], columns: int, gap: int, background: Color) -> Image:
	var rows: int = ceili(float(images.size()) / float(maxi(columns, 1)))
	var width: int = columns * tile_size + (columns + 1) * gap
	var height: int = rows * tile_size + (rows + 1) * gap
	var board: Image = _new_image(width, height, background)
	for index: int in range(images.size()):
		var scaled: Image = _scale_tile(images[index])
		var target: Vector2i = Vector2i(gap + (index % columns) * (tile_size + gap), gap + (index / columns) * (tile_size + gap))
		_overlay_scaled(board, scaled, target)
	return board

func _build_repetition_board(fills: Array[Image]) -> Image:
	var preview_value: Variant = golden_recipe.get("preview", {})
	var preview: Dictionary = preview_value if preview_value is Dictionary else {}
	var columns: int = int(preview.get("repetition_columns", 10))
	var rows: int = int(preview.get("repetition_rows", 8))
	var board: Image = _new_image(columns * tile_size, rows * tile_size, _color("preview_background"))
	for y: int in range(rows):
		for x: int in range(columns):
			var variant_index: int = _hash(12201, x, y) % fills.size()
			var scaled: Image = _scale_tile(fills[variant_index])
			board.blit_rect(scaled, Rect2i(Vector2i.ZERO, Vector2i(tile_size, tile_size)), Vector2i(x * tile_size, y * tile_size))
	return board

func _scenario_cells(width_cells: int, height_cells: int) -> Dictionary:
	var cells: Dictionary = {}
	for y: int in range(height_cells):
		for x: int in range(width_cells):
			cells[Vector2i(x, y)] = true
	for y: int in range(1, height_cells - 1):
		cells.erase(Vector2i(3, y))
	for y: int in range(2, 6):
		for x: int in range(6, 12):
			cells.erase(Vector2i(x, y))
	for x: int in range(3, width_cells - 2):
		cells.erase(Vector2i(x, 7))
	for step: int in range(4):
		cells.erase(Vector2i(12 + step, 3 + step))
	cells[Vector2i(8, 4)] = true
	cells[Vector2i(10, 5)] = true
	return cells

func _build_excavation_board(fills: Array[Image], edges: Array[Image], fronts: Array[Image], width_cells: int, height_cells: int) -> Image:
	var board: Image = _new_image(width_cells * tile_size, height_cells * tile_size, _color("preview_background"))
	var cells: Dictionary = _scenario_cells(width_cells, height_cells)
	for cell_value: Variant in cells.keys():
		var cell: Vector2i = cell_value
		var mask: int = _mask_for_cells(cells, cell)
		var fill_index: int = _hash(13101, cell.x, cell.y) % fills.size()
		var tile: Image = _composite_tile(fills[fill_index], edges[mask])
		var scaled: Image = _scale_tile(tile)
		board.blit_rect(scaled, Rect2i(Vector2i.ZERO, Vector2i(tile_size, tile_size)), cell * tile_size)
	for cell_value: Variant in cells.keys():
		var cell: Vector2i = cell_value
		var mask: int = _mask_for_cells(cells, cell)
		if (mask & 4) == 0 or cell.y + 1 >= height_cells:
			continue
		var left_cell: Vector2i = cell + Vector2i.LEFT
		var right_cell: Vector2i = cell + Vector2i.RIGHT
		var left_connected: bool = cells.has(left_cell) and (_mask_for_cells(cells, left_cell) & 4) != 0
		var right_connected: bool = cells.has(right_cell) and (_mask_for_cells(cells, right_cell) & 4) != 0
		var state: int = (1 if left_connected else 0) + (2 if right_connected else 0)
		var front_scaled: Image = _scale_tile(fronts[state])
		_overlay_scaled(board, front_scaled, Vector2i(cell.x * tile_size, (cell.y + 1) * tile_size))
	return board

func _modulate_image(source: Image, multiplier: Color) -> Image:
	var result: Image = source.duplicate()
	for y: int in range(result.get_height()):
		for x: int in range(result.get_width()):
			var color: Color = result.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			result.set_pixel(x, y, Color(color.r * multiplier.r, color.g * multiplier.g, color.b * multiplier.b, color.a))
	return result

func _apply_radial_light(source: Image, center: Vector2, radius: float) -> Image:
	var result: Image = _modulate_image(source, Color(0.42, 0.46, 0.58, 1.0))
	for y: int in range(result.get_height()):
		for x: int in range(result.get_width()):
			var distance: float = Vector2(float(x), float(y)).distance_to(center)
			var strength: float = clampf(1.0 - distance / radius, 0.0, 1.0)
			if strength <= 0.0:
				continue
			var base_color: Color = result.get_pixel(x, y)
			var source_color: Color = source.get_pixel(x, y)
			var warm_color: Color = Color(source_color.r * 1.08, source_color.g * 0.94, source_color.b * 0.78, source_color.a)
			result.set_pixel(x, y, base_color.lerp(warm_color, strength * 0.9))
	return result

func _build_lighting_board(fills: Array[Image], edges: Array[Image], fronts: Array[Image]) -> Image:
	var sample: Image = _build_excavation_board(fills, edges, fronts, 8, 5)
	var neutral: Image = sample
	var ambient: Image = _modulate_image(sample, Color(0.44, 0.47, 0.55, 1.0))
	var dark: Image = _modulate_image(sample, Color(0.22, 0.25, 0.34, 1.0))
	var lit: Image = _apply_radial_light(sample, Vector2(float(sample.get_width()) * 0.5, float(sample.get_height()) * 0.55), float(sample.get_width()) * 0.45)
	var gap: int = 8
	var board: Image = _new_image(sample.get_width() * 2 + gap * 3, sample.get_height() * 2 + gap * 3, _color("preview_grid"))
	board.blit_rect(neutral, Rect2i(Vector2i.ZERO, neutral.get_size()), Vector2i(gap, gap))
	board.blit_rect(ambient, Rect2i(Vector2i.ZERO, ambient.get_size()), Vector2i(sample.get_width() + gap * 2, gap))
	board.blit_rect(lit, Rect2i(Vector2i.ZERO, lit.get_size()), Vector2i(gap, sample.get_height() + gap * 2))
	board.blit_rect(dark, Rect2i(Vector2i.ZERO, dark.get_size()), Vector2i(sample.get_width() + gap * 2, sample.get_height() + gap * 2))
	return board

func _build_scale_board(golden_tiles: Array[Image]) -> Image:
	var source_logical: Image = golden_tiles[2]
	var native: Image = _scale_tile(source_logical)
	var medium: Image = native.duplicate()
	medium.resize(96, 96, Image.INTERPOLATE_NEAREST)
	var large: Image = native.duplicate()
	large.resize(128, 128, Image.INTERPOLATE_NEAREST)
	var gap: int = 24
	var board: Image = _new_image(64 + 96 + 128 + gap * 4, 176, _color("preview_background"))
	_overlay_scaled(board, native, Vector2i(gap, 56))
	_overlay_scaled(board, medium, Vector2i(gap * 2 + 64, 40))
	_overlay_scaled(board, large, Vector2i(gap * 3 + 64 + 96, 24))
	return board

func _image_signature(image: Image) -> int:
	var signature: int = 17
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			var packed: int = int(color.r8) + int(color.g8) * 257 + int(color.b8) * 65537 + int(color.a8) * 16777259
			signature = int((signature * 31 + packed) & 0x7fffffff)
	return signature

func _palette_violation_count(image: Image) -> int:
	var allowed: Dictionary = {}
	for color_value: Variant in palette.values():
		var allowed_color: Color = Color.html(String(color_value))
		allowed[allowed_color.to_html(true)] = true
	var violations: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			if not allowed.has(color.to_html(true)):
				violations += 1
	return violations

func _lower_transparency_ratio(image: Image, start_y: int) -> float:
	var transparent_count: int = 0
	var total_count: int = 0
	for y: int in range(start_y, image.get_height()):
		for x: int in range(image.get_width()):
			total_count += 1
			if image.get_pixel(x, y).a <= 0.0:
				transparent_count += 1
	return float(transparent_count) / float(maxi(total_count, 1))

func _validate_golden_outputs(fills: Array[Image], edges: Array[Image], fronts: Array[Image], damage: Array[Image], golden_tiles: Array[Image]) -> Dictionary:
	var failures: Array[String] = []
	if fills.size() != 4:
		failures.append("Expected four Golden Tile fill variants.")
	if edges.size() != 16:
		failures.append("Expected sixteen Golden Tile edge masks.")
	if fronts.size() != 4:
		failures.append("Expected four Golden Tile front-wall states.")
	if damage.size() != 12:
		failures.append("Expected twelve Golden Tile damage overlays.")
	if golden_tiles.size() != 10:
		failures.append("Expected ten Golden Tile references.")
	var signatures: Dictionary = {}
	var palette_violations: int = 0
	for fill: Image in fills:
		if _count_opaque(fill) != logical_size * logical_size:
			failures.append("A fill variant contains transparent pixels.")
		signatures[_image_signature(fill)] = true
		palette_violations += _palette_violation_count(fill)
	if signatures.size() != fills.size():
		failures.append("Fill variants are not visually unique.")
	if palette_violations > 0:
		failures.append("Generated fills contain colors outside the locked palette.")
	if edges.size() == 16:
		if _count_opaque(edges[0]) != 0:
			failures.append("Mask 0 must remain transparent.")
		for mask: int in range(1, 16):
			if (mask & 1) != 0 and not _side_has_pixels(edges[mask], 0):
				failures.append("Mask %d is missing its top face." % mask)
			if (mask & 2) != 0 and not _side_has_pixels(edges[mask], 1):
				failures.append("Mask %d is missing its right face." % mask)
			if (mask & 4) != 0 and not _side_has_pixels(edges[mask], 2):
				failures.append("Mask %d is missing its bottom face." % mask)
			if (mask & 8) != 0 and not _side_has_pixels(edges[mask], 3):
				failures.append("Mask %d is missing its left face." % mask)
	var front_transparency_sum: float = 0.0
	for front: Image in fronts:
		front_transparency_sum += _lower_transparency_ratio(front, 24)
	var average_front_transparency: float = front_transparency_sum / float(maxi(fronts.size(), 1))
	if average_front_transparency < 0.72:
		failures.append("Front walls are too opaque in the cave-facing lower section.")
	if damage.size() == 12:
		for direction: int in range(4):
			var stage_one: int = _count_opaque(damage[direction])
			var stage_two: int = _count_opaque(damage[4 + direction])
			var stage_three: int = _count_opaque(damage[8 + direction])
			if not (stage_one < stage_two and stage_two < stage_three):
				failures.append("Damage coverage is not increasing for direction %d." % direction)
	return {
		"version": 2,
		"passed": failures.is_empty(),
		"failures": failures,
		"generated": {
			"fill_variants": fills.size(),
			"edge_masks": edges.size(),
			"front_wall_states": fronts.size(),
			"directional_damage_frames": damage.size(),
			"golden_reference_tiles": golden_tiles.size(),
			"stamp_count": stamp_definitions.size()
		},
		"aesthetic_metrics": {
			"unique_fill_signatures": signatures.size(),
			"palette_violations": palette_violations,
			"average_front_lower_transparency": snappedf(average_front_transparency, 0.001)
		},
		"tile_size": tile_size,
		"logical_size": logical_size,
		"nearest_neighbor_scale": export_scale
	}

func _golden_manifest() -> Dictionary:
	var ids: Array[String] = []
	var definitions_value: Variant = golden_recipe.get("golden_tiles", [])
	if definitions_value is Array:
		var definitions: Array = definitions_value
		for definition_value: Variant in definitions:
			if definition_value is Dictionary:
				ids.append(String(definition_value.get("id", "unnamed")))
	return {
		"version": 2,
		"atlas": "golden_tiles_v2_atlas.png",
		"columns": 5,
		"frame_size": [tile_size, tile_size],
		"frames": ids,
		"mask_bit_order": {"top": 1, "right": 2, "bottom": 4, "left": 8},
		"review_status": "candidate_not_yet_approved"
	}

func _save_golden_atlas(filename: String, images: Array[Image], columns: int) -> bool:
	return _save_golden_image(filename, _pack_atlas(images, columns))

func _save_golden_image(filename: String, image: Image) -> bool:
	var path: String = GOLDEN_OUTPUT_DIR.path_join(filename)
	var save_error: Error = image.save_png(path)
	if save_error != OK:
		push_error("Golden Tile Lab could not save %s: %s" % [path, error_string(save_error)])
		return false
	return true

func _write_golden_json(filename: String, document: Dictionary) -> void:
	var path: String = GOLDEN_OUTPUT_DIR.path_join(filename)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Golden Tile Lab could not write %s" % path)
		return
	file.store_string(JSON.stringify(document, "  "))
	file.close()
