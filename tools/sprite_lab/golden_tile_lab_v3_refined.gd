extends "res://tools/sprite_lab/golden_tile_lab_v3.gd"

func _draw_blocky_mass(image: Image, seed: int, y_start: int, y_end: int, center_x: int, half_width: int, slope: int, color: Color) -> void:
	for y: int in range(y_start, y_end + 1):
		var local_y: int = y - y_start
		var segment: int = local_y / 3
		var center_shift: int = slope * local_y / 5
		var left_jitter: int = int(_hash(seed + 11, segment, 1) % 5) - 2
		var right_jitter: int = int(_hash(seed + 23, segment, 2) % 5) - 2
		var left: int = clampi(center_x + center_shift - half_width + left_jitter, 2, logical_size - 3)
		var right: int = clampi(center_x + center_shift + half_width + right_jitter, 2, logical_size - 3)
		if right < left:
			var swap: int = left
			left = right
			right = swap
		for x: int in range(left, right + 1):
			_set_pixel(image, x, y, color)

func _draw_short_seam(image: Image, seed: int, origin: Vector2i, length: int) -> void:
	var point: Vector2i = origin
	for index: int in range(length):
		_set_pixel(image, point.x, point.y, _color("easy_dark"))
		if index == length / 2:
			_set_pixel(image, point.x, point.y + 1, _color("deep_shadow"))
		point.x += 1
		if _hash(seed, index, 3) % 4 == 0:
			point.y += 1 if _hash(seed + 7, index, 5) % 2 == 0 else -1

func _make_golden_fill(variant: Dictionary, variant_index: int) -> Image:
	var image: Image = _new_image(logical_size, logical_size, _color("easy_mid"))
	var seed: int = int(golden_recipe.get("seed", 8301)) + variant_index * 173
	# Large angular masses replace v2/v3's circular patches.
	var dark_y: int = 3 + (variant_index % 2) * 7
	var light_y: int = 17 - (variant_index % 2) * 5
	_draw_blocky_mass(image, seed + 11, dark_y, mini(dark_y + 10, 28), 9 + variant_index * 3, 10, 1 if variant_index % 2 == 0 else -1, _color("easy_dark"))
	_draw_blocky_mass(image, seed + 23, light_y, mini(light_y + 11, 29), 23 - variant_index * 2, 10, -1 if variant_index % 2 == 0 else 1, _color("easy_light"))
	_draw_blocky_mass(image, seed + 31, 12, 20, 16, 8, 0, _color("easy_mid"))
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
	_draw_short_seam(image, seed + 51, Vector2i(5 + variant_index * 4, 9 + (variant_index % 2) * 13), 5 + variant_index % 3)
	return image

func _make_golden_front(state: int, seed: int) -> Image:
	var config_value: Variant = golden_recipe.get("front_walls", {})
	var config: Dictionary = config_value if config_value is Dictionary else {}
	var visible_depth: int = int(config.get("visible_depth", 16))
	var image: Image = _new_image(logical_size, logical_size, _color("transparent"))
	var seamless_profile: Array[int] = [0, 0, 1, 1, 0, -1, -1, 0]
	for y: int in range(visible_depth + 1):
		for x: int in range(logical_size):
			var color: Color = _color("easy_mid")
			if y < 3:
				color = _color("easy_light")
			elif y >= 11:
				color = _color("easy_dark")
			elif ((x / 6) + (y / 4) + state) % 4 == 0:
				color = _color("easy_light")
			image.set_pixel(x, y, color)
	for x: int in range(logical_size):
		_set_pixel(image, x, 0, _color("easy_highlight") if x % 7 == 2 else _color("easy_light"))
		_set_pixel(image, x, 1, _color("outline"))
		var profile_value: int = seamless_profile[x % seamless_profile.size()]
		var bottom_y: int = clampi(visible_depth + profile_value, 14, 18)
		for y: int in range(bottom_y + 1, logical_size):
			image.set_pixel(x, y, _color("transparent"))
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
	if _hash(seed + 211, state, 1) % 3 == 0:
		var shard_x: int = 7 + (_hash(seed + 223, state, 2) % 17)
		_overlay_stamp(image, "hanging_shard_a", Vector2i(shard_x, 14))
	return image
