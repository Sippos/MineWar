extends "res://tools/sprite_lab/golden_tile_lab_v3.gd"

func _periodic_distance_sq(a: Vector2i, b: Vector2i) -> int:
	var dx: int = absi(a.x - b.x)
	var dy: int = absi(a.y - b.y)
	dx = mini(dx, logical_size - dx)
	dy = mini(dy, logical_size - dy)
	return dx * dx + dy * dy

func _feature_centers(seed: int) -> Array[Vector2i]:
	var centers: Array[Vector2i] = []
	var skipped_index: int = int(_hash(seed + 3, 0, 0) % 9)
	var grid_index: int = 0
	for gy: int in range(3):
		for gx: int in range(3):
			if grid_index == skipped_index:
				grid_index += 1
				continue
			var jitter_x: int = int(_hash(seed + 17, gx, gy) % 7) - 3
			var jitter_y: int = int(_hash(seed + 31, gy, gx) % 7) - 3
			var x: int = posmod(5 + gx * 11 + jitter_x, logical_size)
			var y: int = posmod(5 + gy * 11 + jitter_y, logical_size)
			centers.append(Vector2i(x, y))
			grid_index += 1
	return centers

func _base_cell_color(seed: int, center_index: int, variant_index: int) -> Color:
	var shade_roll: int = int(_hash(seed + 101, center_index, variant_index) % 12)
	if shade_roll <= 2:
		return _color("easy_dark")
	if shade_roll >= 9:
		return _color("easy_light")
	return _color("easy_mid")

func _voronoi_fill(seed: int, variant_index: int) -> Image:
	var image: Image = _new_image(logical_size, logical_size, _color("easy_mid"))
	var centers: Array[Vector2i] = _feature_centers(seed)
	var nearest_indices: PackedInt32Array = PackedInt32Array()
	var edge_deltas: PackedInt32Array = PackedInt32Array()
	nearest_indices.resize(logical_size * logical_size)
	edge_deltas.resize(logical_size * logical_size)
	for y: int in range(logical_size):
		for x: int in range(logical_size):
			var nearest_distance: int = 1_000_000
			var second_distance: int = 1_000_000
			var nearest_index: int = 0
			var point: Vector2i = Vector2i(x, y)
			for center_index: int in range(centers.size()):
				var distance: int = _periodic_distance_sq(point, centers[center_index])
				if distance < nearest_distance:
					second_distance = nearest_distance
					nearest_distance = distance
					nearest_index = center_index
				elif distance < second_distance:
					second_distance = distance
			var flat_index: int = y * logical_size + x
			nearest_indices[flat_index] = nearest_index
			edge_deltas[flat_index] = second_distance - nearest_distance
	for y: int in range(logical_size):
		for x: int in range(logical_size):
			var flat_index: int = y * logical_size + x
			var nearest_index: int = nearest_indices[flat_index]
			var delta: int = edge_deltas[flat_index]
			var color: Color = _base_cell_color(seed, nearest_index, variant_index)
			# Broken seams instead of a fully outlined stone mosaic.
			if delta <= 3:
				var seam_roll: int = int(_hash(seed + 151, x / 2, y / 2) % 7)
				if seam_roll <= 2:
					color = _color("deep_shadow")
				elif seam_roll == 3:
					color = _color("outline")
			else:
				var right_index: int = nearest_indices[y * logical_size + posmod(x + 1, logical_size)]
				var down_index: int = nearest_indices[posmod(y + 1, logical_size) * logical_size + x]
				if (right_index != nearest_index or down_index != nearest_index) and _hash(seed + 181, x, y) % 9 == 0:
					color = _color("easy_highlight")
				elif _hash(seed + 211, x, y) % 97 == 0:
					color = _color("deep_shadow")
			image.set_pixel(x, y, color)
	return image

func _make_golden_fill(_variant: Dictionary, variant_index: int) -> Image:
	var seed: int = int(golden_recipe.get("seed", 8301)) + variant_index * 257
	return _voronoi_fill(seed, variant_index)

func _make_golden_front(state: int, seed: int) -> Image:
	var config_value: Variant = golden_recipe.get("front_walls", {})
	var config: Dictionary = config_value if config_value is Dictionary else {}
	var visible_depth: int = int(config.get("visible_depth", 16))
	var source: Image = _voronoi_fill(seed + state * 113, state)
	var image: Image = _new_image(logical_size, logical_size, _color("transparent"))
	var seamless_profile: Array[int] = [0, 0, 1, 1, 0, -1, -1, 0]
	for x: int in range(logical_size):
		var bottom_y: int = clampi(visible_depth + seamless_profile[x % seamless_profile.size()], 14, 18)
		for y: int in range(bottom_y + 1):
			var color: Color = source.get_pixel(x, y)
			if y >= 9:
				if color == _color("easy_light") or color == _color("easy_highlight"):
					color = _color("easy_mid")
				elif color == _color("easy_mid"):
					color = _color("easy_dark")
				elif color == _color("easy_dark"):
					color = _color("deep_shadow")
			image.set_pixel(x, y, color)
		_set_pixel(image, x, 0, _color("easy_highlight") if x % 11 == 3 else _color("easy_light"))
		_set_pixel(image, x, 1, _color("outline"))
		_set_pixel(image, x, bottom_y, _color("outline"))
		if bottom_y > 1:
			_set_pixel(image, x, bottom_y - 1, _color("deep_shadow"))
	var left_connected: bool = (state & 1) != 0
	var right_connected: bool = (state & 2) != 0
	if not left_connected:
		for y: int in range(8, logical_size):
			var cut_left: int = clampi((y - 5) / 4, 1, 5)
			for x: int in range(cut_left):
				image.set_pixel(x, y, _color("transparent"))
	if not right_connected:
		for y: int in range(8, logical_size):
			var cut_right: int = clampi((y - 5) / 4, 1, 5)
			for offset: int in range(cut_right):
				image.set_pixel(logical_size - 1 - offset, y, _color("transparent"))
	if _hash(seed + 307, state, 1) % 5 == 0:
		var shard_x: int = 7 + (_hash(seed + 311, state, 2) % 17)
		_overlay_stamp(image, "hanging_shard_a", Vector2i(shard_x, 14))
	return image
