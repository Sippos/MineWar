extends "res://tools/sprite_lab/golden_tile_lab_v2.gd"

const V3_RECIPE_PATH := "res://tools/sprite_lab/recipes/golden_tile_v3.json"
const V3_STAMP_PATH := "res://tools/sprite_lab/stamps/easy_clods_v3.json"
const V3_OUTPUT_DIR := "res://assets/sprites/world/terrain/generated_sprite_lab/golden_v3"
const V2_OUTPUT_DIR := "res://assets/sprites/world/terrain/generated_sprite_lab/golden_v2"

func _ready() -> void:
	if not _load_golden_configuration():
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(V3_OUTPUT_DIR))

	var fills: Array[Image] = _build_golden_fill_variants()
	var edges: Array[Image] = _build_golden_edge_masks()
	var fronts: Array[Image] = _build_golden_front_walls()
	var damage: Array[Image] = _build_golden_damage_overlays()
	var golden_tiles: Array[Image] = _build_golden_tiles(fills, edges, fronts, damage)
	var stamp_tiles: Array[Image] = _build_stamp_tiles()

	var saved: bool = true
	saved = _save_golden_atlas("easy_fill_v3_atlas.png", fills, 4) and saved
	saved = _save_golden_atlas("easy_edges_v3_atlas.png", edges, 4) and saved
	saved = _save_golden_atlas("easy_fronts_v3_atlas.png", fronts, 4) and saved
	saved = _save_golden_atlas("damage_v3_atlas.png", damage, 4) and saved
	saved = _save_golden_atlas("golden_tiles_v3_atlas.png", golden_tiles, 5) and saved
	saved = _save_golden_atlas("stamp_library_v3.png", stamp_tiles, 5) and saved

	var golden_board: Image = _pack_with_gap(golden_tiles, 5, 8, _color("preview_background"))
	var repetition_board: Image = _build_repetition_board(fills)
	var excavation_board: Image = _build_excavation_board(fills, edges, fronts, 18, 10)
	var lighting_board: Image = _build_lighting_board(fills, edges, fronts)
	var scale_board: Image = _build_scale_board(golden_tiles)
	var comparison_board: Image = _build_v2_v3_comparison(repetition_board, excavation_board)
	saved = _save_golden_image("preview_golden_tiles_v3.png", golden_board) and saved
	saved = _save_golden_image("preview_repetition_v3.png", repetition_board) and saved
	saved = _save_golden_image("preview_excavation_v3.png", excavation_board) and saved
	saved = _save_golden_image("preview_lighting_v3.png", lighting_board) and saved
	saved = _save_golden_image("preview_scale_v3.png", scale_board) and saved
	saved = _save_golden_image("preview_compare_v2_v3.png", comparison_board) and saved

	var report: Dictionary = _validate_golden_outputs(fills, edges, fronts, damage, golden_tiles)
	report["version"] = 3
	report["files_saved"] = saved
	report["design_changes"] = [
		"fewer isolated pebbles",
		"larger packed-earth masses",
		"thinner chipped exposure silhouettes",
		"shallower wall lip with transparent cave depth",
		"damage follows structural seams"
	]
	_write_golden_json("validation_report_v3.json", report)
	_write_golden_json("golden_tile_manifest_v3.json", _golden_manifest())
	var passed: bool = saved and bool(report.get("passed", false))
	print("GOLDEN_TILE_LAB_V3_", "PASS" if passed else "FAIL", " output=", V3_OUTPUT_DIR)
	get_tree().quit(0 if passed else 1)

func _load_golden_configuration() -> bool:
	style = _load_json(STYLE_PATH)
	golden_recipe = _load_json(V3_RECIPE_PATH)
	stamp_document = _load_json(V3_STAMP_PATH)
	stamp_cache.clear()
	if style.is_empty() or golden_recipe.is_empty() or stamp_document.is_empty():
		push_error("Golden Tile Lab v3 configuration is missing or invalid.")
		return false
	var raw_palette: Variant = style.get("palette", {})
	if not raw_palette is Dictionary:
		push_error("Golden Tile Lab v3 palette is invalid.")
		return false
	palette = raw_palette
	logical_size = int(style.get("logical_size", 32))
	export_scale = int(style.get("export_scale", 2))
	tile_size = int(style.get("tile_size", logical_size * export_scale))
	var legend_value: Variant = stamp_document.get("legend", {})
	var definitions_value: Variant = stamp_document.get("stamps", {})
	if not legend_value is Dictionary or not definitions_value is Dictionary:
		push_error("Golden Tile Lab v3 stamp document is invalid.")
		return false
	stamp_legend = legend_value
	stamp_definitions = definitions_value
	return logical_size == 32 and tile_size == logical_size * export_scale

func _make_golden_fill(variant: Dictionary, variant_index: int) -> Image:
	var image: Image = _new_image(logical_size, logical_size, _color("easy_mid"))
	var seed: int = int(golden_recipe.get("seed", 8301)) + variant_index * 173
	# Broad low-frequency soil masses establish packed earth without pixel noise.
	var dark_center: Vector2i = Vector2i(7 + variant_index * 4, 9 + (variant_index % 2) * 12)
	var light_center: Vector2i = Vector2i(24 - variant_index * 3, 22 - (variant_index % 2) * 11)
	_draw_soil_patch(image, dark_center, 13, 9, _color("easy_dark"), seed + 11)
	_draw_soil_patch(image, light_center, 12, 8, _color("easy_light"), seed + 23)
	# A mid-colour bridge prevents the two masses from reading as circular stains.
	_draw_soil_patch(image, Vector2i(16, 16), 10, 6, _color("easy_mid"), seed + 31)
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
				bool(placement.get("flip_y", false)),
				int(placement.get("quarter_turns", 0))
			)
	# Only two micro-marks per tile; v2 used many isolated landmarks.
	for index: int in range(2):
		var mark_x: int = 4 + (_hash(seed + 71, index, 1) % 24)
		var mark_y: int = 4 + (_hash(seed + 83, index, 2) % 24)
		_set_pixel(image, mark_x, mark_y, _color("deep_shadow") if index == 0 else _color("easy_highlight"))
	return image

func _draw_exposed_side(image: Image, side: int, seed: int) -> void:
	var profile: Array[int] = _edge_profile(side, seed)
	for index: int in range(logical_size):
		var depth: int = profile[index]
		for layer: int in range(depth + 1):
			var color: Color = _color("deep_shadow")
			if layer == 0:
				color = _color("cave")
			elif layer == 1:
				color = _color("outline")
			elif layer == depth:
				color = _color("easy_light")
				if side == 0 or side == 3:
					color = _color("easy_highlight") if _hash(seed + 41, index, layer) % 5 == 0 else _color("easy_light")
			var point: Vector2i = Vector2i(index, layer)
			if side == 1:
				point = Vector2i(logical_size - 1 - layer, index)
			elif side == 2:
				point = Vector2i(index, logical_size - 1 - layer)
			elif side == 3:
				point = Vector2i(layer, index)
			_set_pixel(image, point.x, point.y, color)
	# One restrained chipped clod on only some masks/sides.
	if _hash(seed + 59, side, 3) % 3 == 0:
		var chunk_position: int = 7 + (_hash(seed + 61, side, 5) % 14)
		var stamp_id: String = "edge_chip_a" if _hash(seed + 67, side, 7) % 2 == 0 else "edge_chip_b"
		if side == 0:
			_overlay_stamp(image, stamp_id, Vector2i(chunk_position, 0))
		elif side == 1:
			_overlay_stamp(image, stamp_id, Vector2i(logical_size - 4, chunk_position), false, false, 1)
		elif side == 2:
			_overlay_stamp(image, stamp_id, Vector2i(chunk_position, logical_size - 4), false, false, 2)
		else:
			_overlay_stamp(image, stamp_id, Vector2i(0, chunk_position), false, false, 3)

func _make_golden_front(state: int, seed: int) -> Image:
	var config_value: Variant = golden_recipe.get("front_walls", {})
	var config: Dictionary = config_value if config_value is Dictionary else {}
	var visible_depth: int = int(config.get("visible_depth", 17))
	var image: Image = _new_image(logical_size, logical_size, _color("transparent"))
	# Compact earth cross-section.
	for y: int in range(visible_depth + 1):
		for x: int in range(logical_size):
			var band: int = y / 4
			var color: Color = _color("easy_mid")
			var roll: int = _hash(seed + band * 31, x / 4, y / 3) % 10
			if roll < 3:
				color = _color("easy_dark")
			elif roll > 7:
				color = _color("easy_light")
			image.set_pixel(x, y, color)
	_overlay_stamp(image, "wall_strata_a", Vector2i(0, 3))
	_overlay_stamp(image, "wall_strata_b", Vector2i(12, 9), true, false)
	_overlay_stamp(image, "ledge_clod", Vector2i(4, 0))
	_overlay_stamp(image, "ledge_clod", Vector2i(20, 0), true, false)
	# Irregular lower silhouette, with most of the lower half transparent.
	for x: int in range(logical_size):
		var bottom_y: int = visible_depth + (_hash(seed + 97, x / 4, 5) % 4) - 2
		bottom_y = clampi(bottom_y, 14, 20)
		for y: int in range(bottom_y + 1, logical_size):
			image.set_pixel(x, y, _color("transparent"))
		_set_pixel(image, x, bottom_y, _color("outline"))
		if bottom_y > 0:
			_set_pixel(image, x, bottom_y - 1, _color("deep_shadow"))
	var left_connected: bool = (state & 1) != 0
	var right_connected: bool = (state & 2) != 0
	if not left_connected:
		for y: int in range(8, logical_size):
			var cut_left: int = clampi((y - 6) / 4, 1, 5)
			for x: int in range(cut_left):
				image.set_pixel(x, y, _color("transparent"))
	if not right_connected:
		for y: int in range(8, logical_size):
			var cut_right: int = clampi((y - 6) / 4, 1, 5)
			for offset: int in range(cut_right):
				image.set_pixel(logical_size - 1 - offset, y, _color("transparent"))
	# Sparse hanging pieces break the silhouette without creating black teeth.
	if _hash(seed + 211, state, 1) % 2 == 0:
		var shard_x: int = 6 + (_hash(seed + 223, state, 2) % 18)
		_overlay_stamp(image, "hanging_shard_a", Vector2i(shard_x, 16))
	if _hash(seed + 227, state, 3) % 3 == 0:
		var second_x: int = 4 + (_hash(seed + 229, state, 4) % 22)
		_overlay_stamp(image, "hanging_shard_b", Vector2i(second_x, 15))
	return image

func _make_golden_damage(direction: int, stage: int, seed: int) -> Image:
	var image: Image = _new_image(logical_size, logical_size, _color("transparent"))
	var center_x: int = 13 + (_hash(seed, stage, direction) % 7)
	# The path bends around packed clods instead of slicing straight through them.
	var path: Array[Vector2i] = [
		Vector2i(center_x, 0),
		Vector2i(center_x - 2, 4),
		Vector2i(center_x + 3, 7),
		Vector2i(center_x + 1, 11),
		Vector2i(center_x - 4, 15),
		Vector2i(center_x - 1, 20),
		Vector2i(center_x + 4, 25),
		Vector2i(center_x, 30)
	]
	var segment_count: int = 2 + stage * 2
	for index: int in range(segment_count):
		var start: Vector2i = _rotate_from_top(path[index], direction)
		var finish: Vector2i = _rotate_from_top(path[index + 1], direction)
		_draw_line(image, start, finish, _color("crack_dark"), 1 if stage == 0 else 2)
		if stage == 0:
			var highlight_start: Vector2i = start + _rotate_from_top(Vector2i(-1, 0), direction)
			var highlight_finish: Vector2i = finish + _rotate_from_top(Vector2i(-1, 0), direction)
			_draw_line(image, highlight_start, highlight_finish, _color("crack_light"), 1)
	if stage >= 1:
		var branch_start: Vector2i = _rotate_from_top(path[3], direction)
		var branch_end: Vector2i = _rotate_from_top(Vector2i(center_x + 9, 13), direction)
		_draw_line(image, branch_start, branch_end, _color("crack_dark"), 1)
		_draw_disc(image, _rotate_from_top(path[5], direction), 1, _color("deep_shadow"))
	if stage >= 2:
		var second_start: Vector2i = _rotate_from_top(path[5], direction)
		var second_end: Vector2i = _rotate_from_top(Vector2i(center_x - 10, 23), direction)
		_draw_line(image, second_start, second_end, _color("crack_dark"), 2)
		_draw_disc(image, _rotate_from_top(path[6], direction), 3, _color("cave"))
		_draw_disc(image, _rotate_from_top(path[6], direction), 2, _color("deep_shadow"))
	return image

func _build_v2_v3_comparison(repetition_v3: Image, excavation_v3: Image) -> Image:
	var repetition_v2: Image = Image.load_from_file(ProjectSettings.globalize_path(V2_OUTPUT_DIR + "/preview_repetition_v2.png"))
	var excavation_v2: Image = Image.load_from_file(ProjectSettings.globalize_path(V2_OUTPUT_DIR + "/preview_excavation_v2.png"))
	if repetition_v2 == null or repetition_v2.is_empty():
		repetition_v2 = repetition_v3
	if excavation_v2 == null or excavation_v2.is_empty():
		excavation_v2 = excavation_v3
	var gap: int = 12
	var column_width: int = maxi(repetition_v2.get_width(), excavation_v2.get_width())
	column_width = maxi(column_width, maxi(repetition_v3.get_width(), excavation_v3.get_width()))
	var top_height: int = maxi(repetition_v2.get_height(), repetition_v3.get_height())
	var bottom_height: int = maxi(excavation_v2.get_height(), excavation_v3.get_height())
	var board: Image = _new_image(column_width * 2 + gap * 3, top_height + bottom_height + gap * 3, _color("preview_grid"))
	board.blit_rect(repetition_v2, Rect2i(Vector2i.ZERO, repetition_v2.get_size()), Vector2i(gap, gap))
	board.blit_rect(repetition_v3, Rect2i(Vector2i.ZERO, repetition_v3.get_size()), Vector2i(column_width + gap * 2, gap))
	board.blit_rect(excavation_v2, Rect2i(Vector2i.ZERO, excavation_v2.get_size()), Vector2i(gap, top_height + gap * 2))
	board.blit_rect(excavation_v3, Rect2i(Vector2i.ZERO, excavation_v3.get_size()), Vector2i(column_width + gap * 2, top_height + gap * 2))
	return board

func _golden_manifest() -> Dictionary:
	var ids: Array[String] = []
	var definitions_value: Variant = golden_recipe.get("golden_tiles", [])
	if definitions_value is Array:
		var definitions: Array = definitions_value
		for definition_value: Variant in definitions:
			if definition_value is Dictionary:
				var definition: Dictionary = definition_value
				ids.append(String(definition.get("id", "unnamed")))
	return {
		"version": 3,
		"atlas": "golden_tiles_v3_atlas.png",
		"columns": 5,
		"frame_size": [tile_size, tile_size],
		"frames": ids,
		"mask_bit_order": {"top": 1, "right": 2, "bottom": 4, "left": 8},
		"review_status": "refined_candidate_not_yet_live"
	}

func _save_golden_image(filename: String, image: Image) -> bool:
	var path: String = V3_OUTPUT_DIR.path_join(filename)
	var save_error: Error = image.save_png(path)
	if save_error != OK:
		push_error("Golden Tile Lab v3 could not save %s: %s" % [path, error_string(save_error)])
		return false
	return true

func _write_golden_json(filename: String, document: Dictionary) -> void:
	var path: String = V3_OUTPUT_DIR.path_join(filename)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Golden Tile Lab v3 could not write %s" % path)
		return
	file.store_string(JSON.stringify(document, "  "))
	file.close()
