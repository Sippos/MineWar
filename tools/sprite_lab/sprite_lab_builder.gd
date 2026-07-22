extends Node

const STYLE_PATH := "res://tools/sprite_lab/style_spec.json"
const RECIPE_PATH := "res://tools/sprite_lab/recipes/easy_foundation.json"
const OUTPUT_DIR := "res://assets/sprites/world/terrain/generated_sprite_lab"

var style: Dictionary = {}
var recipe: Dictionary = {}
var palette: Dictionary = {}
var logical_size: int = 32
var export_scale: int = 2
var tile_size: int = 64

func _ready() -> void:
	if not _load_configuration():
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var fills: Array[Image] = _build_fill_variants()
	var edges: Array[Image] = _build_edge_masks()
	var fronts: Array[Image] = _build_front_walls()
	var damage: Array[Image] = _build_damage_overlays()
	var front_damage: Array[Image] = _build_front_damage_overlays()

	var save_ok: bool = true
	save_ok = _save_atlas("easy_fill_atlas.png", fills, 4) and save_ok
	save_ok = _save_atlas("easy_edge_atlas.png", edges, 4) and save_ok
	save_ok = _save_atlas("easy_front_wall_atlas.png", fronts, 4) and save_ok
	save_ok = _save_atlas("damage_directional_atlas.png", damage, 4) and save_ok
	save_ok = _save_atlas("front_damage_atlas.png", front_damage, 3) and save_ok

	var mask_preview: Image = _build_mask_preview(fills, edges)
	var damage_preview: Image = _build_damage_preview(fills, damage)
	var scenario_preview: Image = _build_scenario_preview(fills, edges, fronts)
	save_ok = _save_image("preview_mask_board.png", mask_preview) and save_ok
	save_ok = _save_image("preview_damage_board.png", damage_preview) and save_ok
	save_ok = _save_image("preview_dig_scenarios.png", scenario_preview) and save_ok

	var report: Dictionary = _validate_outputs(fills, edges, fronts, damage, front_damage)
	report["files_saved"] = save_ok
	_write_report(report)
	var passed: bool = save_ok and bool(report.get("passed", false))
	print("SPRITE_LAB_BUILD_", "PASS" if passed else "FAIL", " output=", OUTPUT_DIR)
	get_tree().quit(0 if passed else 1)

func _load_configuration() -> bool:
	style = _load_json(STYLE_PATH)
	recipe = _load_json(RECIPE_PATH)
	if style.is_empty() or recipe.is_empty():
		push_error("Sprite Lab configuration could not be loaded.")
		return false
	var raw_palette: Variant = style.get("palette", {})
	if not raw_palette is Dictionary:
		push_error("Sprite Lab palette is invalid.")
		return false
	palette = raw_palette
	logical_size = int(style.get("logical_size", 32))
	export_scale = int(style.get("export_scale", 2))
	tile_size = int(style.get("tile_size", logical_size * export_scale))
	return logical_size > 0 and export_scale > 0 and tile_size == logical_size * export_scale

func _load_json(path: String) -> Dictionary:
	var source: String = FileAccess.get_file_as_string(path)
	if source.is_empty():
		push_error("Missing JSON file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		push_error("Invalid JSON object: %s" % path)
		return {}
	return parsed

func _color(name: String) -> Color:
	return Color.html(String(palette.get(name, "ff00ffff")))

func _new_image(width: int, height: int, fill_color: Color) -> Image:
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(fill_color)
	return image

func _set_pixel(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)

func _hash(seed: int, x: int, y: int) -> int:
	var value: int = seed * 92837111 + x * 689287499 + y * 283923481
	value = value ^ (value >> 13)
	value = value * 1274126177
	value = value ^ (value >> 16)
	return absi(value)

func _range_from_hash(seed: int, index: int, minimum: int, maximum: int) -> int:
	if maximum <= minimum:
		return minimum
	return minimum + (_hash(seed, index, index * 7 + 3) % (maximum - minimum + 1))

func _draw_rock_blob(image: Image, center: Vector2i, radius_x: int, radius_y: int, seed: int) -> void:
	var outline: Color = _color("outline")
	var dark: Color = _color("easy_dark")
	var mid: Color = _color("easy_light")
	var light: Color = _color("easy_highlight")
	for y: int in range(center.y - radius_y - 1, center.y + radius_y + 2):
		for x: int in range(center.x - radius_x - 1, center.x + radius_x + 2):
			var dx: float = float(x - center.x) / float(maxi(radius_x, 1))
			var dy: float = float(y - center.y) / float(maxi(radius_y, 1))
			var jitter: float = float(_hash(seed, x, y) % 17) / 100.0
			var distance: float = dx * dx + dy * dy + jitter
			if distance <= 1.18:
				var color: Color = outline
				if distance <= 0.78:
					color = mid
					if x <= center.x and y <= center.y and _hash(seed + 5, x, y) % 4 == 0:
						color = light
					elif x >= center.x and y >= center.y and _hash(seed + 9, x, y) % 3 == 0:
						color = dark
				_set_pixel(image, x, y, color)

func _make_fill_variant(seed: int, rock_count: int, mottle_strength: int) -> Image:
	var image: Image = _new_image(logical_size, logical_size, _color("easy_mid"))
	var dark: Color = _color("easy_dark")
	var light: Color = _color("easy_light")
	for y: int in range(logical_size):
		for x: int in range(logical_size):
			var roll: int = _hash(seed, x, y) % 100
			if roll < mottle_strength / 3:
				image.set_pixel(x, y, dark)
			elif roll < mottle_strength:
				image.set_pixel(x, y, light)
	for index: int in range(rock_count):
		var x_pos: int = _range_from_hash(seed + 17, index * 4, 3, logical_size - 4)
		var y_pos: int = _range_from_hash(seed + 23, index * 4 + 1, 3, logical_size - 4)
		var radius_x: int = _range_from_hash(seed + 31, index * 4 + 2, 1, 3)
		var radius_y: int = _range_from_hash(seed + 47, index * 4 + 3, 1, 3)
		_draw_rock_blob(image, Vector2i(x_pos, y_pos), radius_x, radius_y, seed + index * 101)
	return image

func _build_fill_variants() -> Array[Image]:
	var result: Array[Image] = []
	var variants_value: Variant = recipe.get("fill_variants", [])
	if not variants_value is Array:
		return result
	var variants: Array = variants_value
	for raw_variant: Variant in variants:
		if not raw_variant is Dictionary:
			continue
		var variant: Dictionary = raw_variant
		result.append(_make_fill_variant(
			int(variant.get("seed", 1000)),
			int(variant.get("rock_count", 8)),
			int(variant.get("mottle_strength", 20))
		))
	return result

func _draw_top_edge(image: Image, seed: int) -> void:
	var outline: Color = _color("outline")
	var shadow: Color = _color("deep_shadow")
	var highlight: Color = _color("easy_highlight")
	var mid: Color = _color("easy_light")
	for x: int in range(logical_size):
		var depth: int = 2 + (_hash(seed, x, 0) % 3)
		for y: int in range(depth):
			_set_pixel(image, x, y, outline if y == 0 else shadow)
		_set_pixel(image, x, depth, highlight if _hash(seed + 1, x, depth) % 3 != 0 else mid)
		if _hash(seed + 2, x, 4) % 11 == 0:
			_set_pixel(image, x, depth + 1, mid)

func _draw_bottom_edge(image: Image, seed: int) -> void:
	var outline: Color = _color("outline")
	var shadow: Color = _color("deep_shadow")
	var highlight: Color = _color("easy_light")
	for x: int in range(logical_size):
		var depth: int = 2 + (_hash(seed, x, 1) % 3)
		for offset: int in range(depth):
			_set_pixel(image, x, logical_size - 1 - offset, outline if offset == 0 else shadow)
		_set_pixel(image, x, logical_size - 1 - depth, highlight)

func _draw_left_edge(image: Image, seed: int) -> void:
	var outline: Color = _color("outline")
	var shadow: Color = _color("deep_shadow")
	var highlight: Color = _color("easy_highlight")
	var mid: Color = _color("easy_light")
	for y: int in range(logical_size):
		var depth: int = 2 + (_hash(seed, 2, y) % 3)
		for x: int in range(depth):
			_set_pixel(image, x, y, outline if x == 0 else shadow)
		_set_pixel(image, depth, y, highlight if _hash(seed + 1, depth, y) % 3 != 0 else mid)

func _draw_right_edge(image: Image, seed: int) -> void:
	var outline: Color = _color("outline")
	var shadow: Color = _color("deep_shadow")
	var highlight: Color = _color("easy_light")
	for y: int in range(logical_size):
		var depth: int = 2 + (_hash(seed, 3, y) % 3)
		for offset: int in range(depth):
			_set_pixel(image, logical_size - 1 - offset, y, outline if offset == 0 else shadow)
		_set_pixel(image, logical_size - 1 - depth, y, highlight)

func _make_edge_mask(mask: int, seed: int) -> Image:
	var image: Image = _new_image(logical_size, logical_size, _color("transparent"))
	if (mask & 1) != 0:
		_draw_top_edge(image, seed + 11)
	if (mask & 2) != 0:
		_draw_right_edge(image, seed + 23)
	if (mask & 4) != 0:
		_draw_bottom_edge(image, seed + 37)
	if (mask & 8) != 0:
		_draw_left_edge(image, seed + 53)
	return image

func _build_edge_masks() -> Array[Image]:
	var result: Array[Image] = []
	var edge_config_value: Variant = recipe.get("edge_masks", {})
	var edge_config: Dictionary = edge_config_value if edge_config_value is Dictionary else {}
	var count: int = int(edge_config.get("count", 16))
	var seed_base: int = int(edge_config.get("seed_base", 2100))
	for mask: int in range(count):
		result.append(_make_edge_mask(mask, seed_base + mask * 97))
	return result

func _make_front_wall(state: int, seed: int) -> Image:
	var image: Image = _new_image(logical_size, logical_size, _color("transparent"))
	var mid: Color = _color("easy_mid")
	var dark: Color = _color("easy_dark")
	var light: Color = _color("easy_light")
	var highlight: Color = _color("easy_highlight")
	var shadow: Color = _color("deep_shadow")
	var cave: Color = _color("cave")
	for y: int in range(17):
		for x: int in range(logical_size):
			var color: Color = mid
			var roll: int = _hash(seed, x, y) % 100
			if roll < 20:
				color = dark
			elif roll < 38:
				color = light
			image.set_pixel(x, y, color)
	for x: int in range(logical_size):
		_set_pixel(image, x, 0, highlight if _hash(seed + 4, x, 0) % 4 != 0 else light)
		_set_pixel(image, x, 15, shadow)
		_set_pixel(image, x, 16, shadow)
		var hanging_bottom: int = 19 + (_hash(seed + 8, x, 6) % 7)
		for y: int in range(17, hanging_bottom + 1):
			_set_pixel(image, x, y, shadow if y < 20 else cave)
	if state == 0:
		for y: int in range(18, logical_size):
			for x: int in range(3):
				_set_pixel(image, x, y, _color("transparent"))
				_set_pixel(image, logical_size - 1 - x, y, _color("transparent"))
	elif state == 1:
		for y: int in range(18, logical_size):
			for x: int in range(3):
				_set_pixel(image, logical_size - 1 - x, y, _color("transparent"))
	elif state == 2:
		for y: int in range(18, logical_size):
			for x: int in range(3):
				_set_pixel(image, x, y, _color("transparent"))
	return image

func _build_front_walls() -> Array[Image]:
	var result: Array[Image] = []
	var config_value: Variant = recipe.get("front_walls", {})
	var config: Dictionary = config_value if config_value is Dictionary else {}
	var seed_base: int = int(config.get("seed_base", 3200))
	for state: int in range(4):
		result.append(_make_front_wall(state, seed_base + state * 131))
	return result

func _draw_disc(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y: int in range(center.y - radius, center.y + radius + 1):
		for x: int in range(center.x - radius, center.x + radius + 1):
			var dx: int = x - center.x
			var dy: int = y - center.y
			if dx * dx + dy * dy <= radius * radius:
				_set_pixel(image, x, y, color)

func _draw_line(image: Image, from_point: Vector2i, to_point: Vector2i, color: Color, width: int = 1) -> void:
	var x0: int = from_point.x
	var y0: int = from_point.y
	var x1: int = to_point.x
	var y1: int = to_point.y
	var dx: int = absi(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -absi(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var error: int = dx + dy
	while true:
		_draw_disc(image, Vector2i(x0, y0), maxi(width - 1, 0), color)
		if x0 == x1 and y0 == y1:
			break
		var doubled: int = 2 * error
		if doubled >= dy:
			error += dy
			x0 += sx
		if doubled <= dx:
			error += dx
			y0 += sy

func _rotate_from_top(point: Vector2i, direction: int) -> Vector2i:
	if direction == 1:
		return Vector2i(logical_size - 1 - point.y, point.x)
	if direction == 2:
		return Vector2i(logical_size - 1 - point.x, logical_size - 1 - point.y)
	if direction == 3:
		return Vector2i(point.y, logical_size - 1 - point.x)
	return point

func _make_damage_overlay(direction: int, stage: int, seed: int) -> Image:
	var image: Image = _new_image(logical_size, logical_size, _color("transparent"))
	var dark: Color = _color("crack_dark")
	var light: Color = _color("crack_light")
	var center_x: int = 15 + (_hash(seed, stage, direction) % 4) - 2
	var points: Array[Vector2i] = [
		Vector2i(center_x, 0),
		Vector2i(center_x - 2, 6),
		Vector2i(center_x + 2, 11),
		Vector2i(center_x - 1, 17),
		Vector2i(center_x + 3, 24),
		Vector2i(16, 30)
	]
	var segment_count: int = stage + 2
	for index: int in range(segment_count):
		var start: Vector2i = _rotate_from_top(points[index], direction)
		var finish: Vector2i = _rotate_from_top(points[index + 1], direction)
		_draw_line(image, start, finish, dark, 2 if stage >= 2 else 1)
		_draw_line(image, start, finish, light, 1)
	if stage >= 1:
		var branch_a: Vector2i = _rotate_from_top(points[2], direction)
		var branch_b: Vector2i = _rotate_from_top(Vector2i(center_x - 8, 14), direction)
		_draw_line(image, branch_a, branch_b, dark, 1)
	if stage >= 2:
		var branch_c: Vector2i = _rotate_from_top(points[3], direction)
		var branch_d: Vector2i = _rotate_from_top(Vector2i(center_x + 10, 20), direction)
		_draw_line(image, branch_c, branch_d, dark, 1)
		_draw_disc(image, _rotate_from_top(Vector2i(center_x + 3, 24), direction), 2, dark)
	return image

func _build_damage_overlays() -> Array[Image]:
	var result: Array[Image] = []
	var config_value: Variant = recipe.get("damage", {})
	var config: Dictionary = config_value if config_value is Dictionary else {}
	var stages: int = int(config.get("stages", 3))
	var seed_base: int = int(config.get("seed_base", 4300))
	for stage: int in range(stages):
		for direction: int in range(4):
			result.append(_make_damage_overlay(direction, stage, seed_base + stage * 100 + direction * 17))
	return result

func _make_front_damage(stage: int, seed: int) -> Image:
	var image: Image = _new_image(logical_size, logical_size, _color("transparent"))
	var dark: Color = _color("crack_dark")
	var light: Color = _color("crack_light")
	var x_pos: int = 15 + (_hash(seed, stage, 1) % 5) - 2
	var points: Array[Vector2i] = [Vector2i(x_pos, 0), Vector2i(x_pos - 2, 5), Vector2i(x_pos + 2, 10), Vector2i(x_pos - 1, 16)]
	var segment_count: int = stage + 1
	for index: int in range(segment_count):
		_draw_line(image, points[index], points[index + 1], dark, 2 if stage >= 2 else 1)
		_draw_line(image, points[index], points[index + 1], light, 1)
	if stage >= 1:
		_draw_line(image, points[2], Vector2i(x_pos - 8, 13), dark, 1)
	if stage >= 2:
		_draw_line(image, points[2], Vector2i(x_pos + 9, 15), dark, 1)
		_draw_disc(image, points[3], 2, dark)
	return image

func _build_front_damage_overlays() -> Array[Image]:
	var result: Array[Image] = []
	var config_value: Variant = recipe.get("front_damage", {})
	var config: Dictionary = config_value if config_value is Dictionary else {}
	var stages: int = int(config.get("stages", 3))
	var seed_base: int = int(config.get("seed_base", 5200))
	for stage: int in range(stages):
		result.append(_make_front_damage(stage, seed_base + stage * 71))
	return result

func _overlay(destination: Image, source: Image, offset: Vector2i = Vector2i.ZERO) -> void:
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var source_color: Color = source.get_pixel(x, y)
			if source_color.a > 0.0:
				_set_pixel(destination, x + offset.x, y + offset.y, source_color)

func _scale_tile(logical: Image) -> Image:
	var scaled: Image = logical.duplicate()
	scaled.resize(tile_size, tile_size, Image.INTERPOLATE_NEAREST)
	return scaled

func _pack_atlas(images: Array[Image], columns: int) -> Image:
	var rows: int = ceili(float(images.size()) / float(maxi(columns, 1)))
	var atlas: Image = _new_image(columns * tile_size, rows * tile_size, _color("transparent"))
	for index: int in range(images.size()):
		var scaled: Image = _scale_tile(images[index])
		var target: Vector2i = Vector2i((index % columns) * tile_size, (index / columns) * tile_size)
		atlas.blit_rect(scaled, Rect2i(Vector2i.ZERO, Vector2i(tile_size, tile_size)), target)
	return atlas

func _save_atlas(filename: String, images: Array[Image], columns: int) -> bool:
	return _save_image(filename, _pack_atlas(images, columns))

func _save_image(filename: String, image: Image) -> bool:
	var path: String = OUTPUT_DIR.path_join(filename)
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		return false
	return true

func _build_mask_preview(fills: Array[Image], edges: Array[Image]) -> Image:
	var tiles: Array[Image] = []
	for mask: int in range(16):
		var tile: Image = fills[mask % fills.size()].duplicate()
		_overlay(tile, edges[mask])
		tiles.append(tile)
	return _pack_atlas(tiles, 4)

func _build_damage_preview(fills: Array[Image], damage: Array[Image]) -> Image:
	var tiles: Array[Image] = []
	for index: int in range(damage.size()):
		var tile: Image = fills[index % fills.size()].duplicate()
		_overlay(tile, damage[index])
		tiles.append(tile)
	return _pack_atlas(tiles, 4)

func _cell_is_solid(cells: Dictionary, cell: Vector2i) -> bool:
	return cells.has(cell)

func _mask_for_cells(cells: Dictionary, cell: Vector2i) -> int:
	var mask: int = 0
	if not _cell_is_solid(cells, cell + Vector2i.UP):
		mask |= 1
	if not _cell_is_solid(cells, cell + Vector2i.RIGHT):
		mask |= 2
	if not _cell_is_solid(cells, cell + Vector2i.DOWN):
		mask |= 4
	if not _cell_is_solid(cells, cell + Vector2i.LEFT):
		mask |= 8
	return mask

func _build_scenario_preview(fills: Array[Image], edges: Array[Image], fronts: Array[Image]) -> Image:
	var width_cells: int = 12
	var height_cells: int = 8
	var board: Image = _new_image(width_cells * tile_size, height_cells * tile_size, _color("preview_background"))
	var cells: Dictionary = {}
	for y: int in range(1, height_cells - 1):
		for x: int in range(1, width_cells - 1):
			if not ((x >= 4 and x <= 7 and y >= 2 and y <= 4) or (x == 2 and y >= 3) or (y == 6 and x >= 7)):
				cells[Vector2i(x, y)] = true
	for raw_cell: Variant in cells.keys():
		var cell: Vector2i = raw_cell
		var mask: int = _mask_for_cells(cells, cell)
		var logical: Image = fills[_hash(7000, cell.x, cell.y) % fills.size()].duplicate()
		_overlay(logical, edges[mask])
		var scaled: Image = _scale_tile(logical)
		board.blit_rect(scaled, Rect2i(Vector2i.ZERO, Vector2i(tile_size, tile_size)), cell * tile_size)
		if (mask & 4) != 0 and cell.y + 1 < height_cells:
			var left_connected: bool = cells.has(cell + Vector2i.LEFT) and (_mask_for_cells(cells, cell + Vector2i.LEFT) & 4) != 0
			var right_connected: bool = cells.has(cell + Vector2i.RIGHT) and (_mask_for_cells(cells, cell + Vector2i.RIGHT) & 4) != 0
			var state: int = (1 if left_connected else 0) + (2 if right_connected else 0)
			var front_scaled: Image = _scale_tile(fronts[state])
			_overlay_scaled(board, front_scaled, Vector2i(cell.x * tile_size, (cell.y + 1) * tile_size))
	return board

func _overlay_scaled(destination: Image, source: Image, offset: Vector2i) -> void:
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var source_color: Color = source.get_pixel(x, y)
			if source_color.a > 0.0:
				_set_pixel(destination, offset.x + x, offset.y + y, source_color)

func _count_opaque(image: Image) -> int:
	var count: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.0:
				count += 1
	return count

func _side_has_pixels(image: Image, side: int) -> bool:
	for index: int in range(logical_size):
		var point: Vector2i = Vector2i(index, 0)
		if side == 1:
			point = Vector2i(logical_size - 1, index)
		elif side == 2:
			point = Vector2i(index, logical_size - 1)
		elif side == 3:
			point = Vector2i(0, index)
		if image.get_pixel(point.x, point.y).a > 0.0:
			return true
	return false

func _validate_outputs(fills: Array[Image], edges: Array[Image], fronts: Array[Image], damage: Array[Image], front_damage: Array[Image]) -> Dictionary:
	var failures: Array[String] = []
	if fills.size() != 4:
		failures.append("Expected four fill variants.")
	if edges.size() != 16:
		failures.append("Expected sixteen edge masks.")
	if fronts.size() != 4:
		failures.append("Expected four front-wall states.")
	if damage.size() != 12:
		failures.append("Expected twelve directional damage overlays.")
	if front_damage.size() != 3:
		failures.append("Expected three front damage overlays.")
	if edges.size() >= 16:
		if _count_opaque(edges[0]) != 0:
			failures.append("Mask 0 must be transparent.")
		for mask: int in range(1, 16):
			if (mask & 1) != 0 and not _side_has_pixels(edges[mask], 0):
				failures.append("Mask %d is missing top-edge pixels." % mask)
			if (mask & 2) != 0 and not _side_has_pixels(edges[mask], 1):
				failures.append("Mask %d is missing right-edge pixels." % mask)
			if (mask & 4) != 0 and not _side_has_pixels(edges[mask], 2):
				failures.append("Mask %d is missing bottom-edge pixels." % mask)
			if (mask & 8) != 0 and not _side_has_pixels(edges[mask], 3):
				failures.append("Mask %d is missing left-edge pixels." % mask)
	if damage.size() == 12:
		for direction: int in range(4):
			var stage_one: int = _count_opaque(damage[direction])
			var stage_two: int = _count_opaque(damage[4 + direction])
			var stage_three: int = _count_opaque(damage[8 + direction])
			if not (stage_one < stage_two and stage_two < stage_three):
				failures.append("Damage coverage is not increasing for direction %d." % direction)
	return {
		"version": 1,
		"passed": failures.is_empty(),
		"failures": failures,
		"generated": {
			"fill_variants": fills.size(),
			"edge_masks": edges.size(),
			"front_wall_states": fronts.size(),
			"directional_damage_frames": damage.size(),
			"front_damage_frames": front_damage.size()
		},
		"tile_size": tile_size,
		"logical_size": logical_size,
		"nearest_neighbor_scale": export_scale
	}

func _write_report(report: Dictionary) -> void:
	var path: String = OUTPUT_DIR.path_join("validation_report.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write Sprite Lab validation report.")
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
