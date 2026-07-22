extends Node

const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const BACKUP_DIR := SOURCE_DIR + "/backups/final_corner_palette_pass"
const TIERS: Array[String] = ["easy", "medium", "hard", "unmineable"]
const PALETTE_TARGET_TIERS: Array[String] = ["medium", "hard", "unmineable"]
const ART_KINDS: Array[String] = ["border_top_32", "edge_joint_top_left_32", "hole_corner_top_left_32"]
const LOGICAL_SIZE := 32
const PATCH_SIZE := 14

func _ready() -> void:
	var error := _ensure_directories()
	if error != OK:
		push_error("Could not create backup directory: %s" % error_string(error))
		get_tree().quit(1)
		return

	error = _backup_sources()
	if error != OK:
		push_error("Could not back up source art: %s" % error_string(error))
		get_tree().quit(1)
		return

	# The user confirmed the canonical Hole Corner still needs one additional
	# clockwise quarter-turn. Rotate only inside the authored 14x14 patch so the
	# sprite remains in the editor's canonical top-left source region.
	for tier in TIERS:
		var hole_path := _source_path(tier, "hole_corner_top_left_32")
		error = _rotate_patch_clockwise_in_file(hole_path)
		if error != OK:
			push_error("Could not rotate %s: %s" % [hole_path, error_string(error)])
			get_tree().quit(1)
			return

	# Build one shared palette from all three Easy authoring sources. Medium,
	# Hard and Unmineable retain their own pixel geometry but use these exact
	# colors, mapped by luminance.
	var easy_palette := _collect_easy_palette()
	if easy_palette.is_empty():
		push_error("Easy palette is empty")
		get_tree().quit(1)
		return

	for tier in PALETTE_TARGET_TIERS:
		for kind in ART_KINDS:
			var path := _source_path(tier, kind)
			error = _remap_file_to_palette(path, easy_palette)
			if error != OK:
				push_error("Could not normalize palette for %s: %s" % [path, error_string(error)])
				get_tree().quit(1)
				return

	print("Final Dome pass complete: Hole Corners rotated clockwise; all tiers share the Easy palette")
	get_tree().quit()

func _ensure_directories() -> Error:
	var result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP_DIR))
	if result == ERR_ALREADY_EXISTS:
		return OK
	return result

func _source_path(tier: String, kind: String) -> String:
	return SOURCE_DIR + "/%s_%s.png" % [tier, kind]

func _load_image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != LOGICAL_SIZE or image.get_height() != LOGICAL_SIZE:
		image.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return image

func _backup_sources() -> Error:
	for tier in TIERS:
		for kind in ART_KINDS:
			var source_path := _source_path(tier, kind)
			var image := _load_image(source_path)
			if image == null:
				return ERR_FILE_NOT_FOUND
			var backup_path := BACKUP_DIR + "/%s_%s.png" % [tier, kind]
			var result := image.save_png(backup_path)
			if result != OK:
				return result
	return OK

func _rotate_patch_clockwise_in_file(path: String) -> Error:
	var source := _load_image(path)
	if source == null:
		return ERR_FILE_NOT_FOUND
	var result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(PATCH_SIZE):
		for x in range(PATCH_SIZE):
			# 90 degrees clockwise inside the canonical authored patch.
			result.set_pixel(PATCH_SIZE - 1 - y, x, source.get_pixel(x, y))
	return result.save_png(path)

func _collect_easy_palette() -> Array[Color]:
	var palette_by_key: Dictionary = {}
	for kind in ART_KINDS:
		var image := _load_image(_source_path("easy", kind))
		if image == null:
			continue
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var color := image.get_pixel(x, y)
				if color.a <= 0.05:
					continue
				palette_by_key[_color_key(color)] = color
	var palette: Array[Color] = []
	for value: Variant in palette_by_key.values():
		palette.append(value as Color)
	palette.sort_custom(func(a: Color, b: Color) -> bool: return _luminance(a) < _luminance(b))
	return palette

func _remap_file_to_palette(path: String, palette: Array[Color]) -> Error:
	var image := _load_image(path)
	if image == null:
		return ERR_FILE_NOT_FOUND
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.05:
				continue
			var mapped := _nearest_palette_color(color, palette)
			mapped.a = color.a
			image.set_pixel(x, y, mapped)
	return image.save_png(path)

func _nearest_palette_color(source: Color, palette: Array[Color]) -> Color:
	var source_luma := _luminance(source)
	var best := palette[0]
	var best_distance := INF
	for candidate in palette:
		var distance := absf(_luminance(candidate) - source_luma)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722

func _color_key(color: Color) -> String:
	return "%02x%02x%02x%02x" % [
		clampi(roundi(color.r * 255.0), 0, 255),
		clampi(roundi(color.g * 255.0), 0, 255),
		clampi(roundi(color.b * 255.0), 0, 255),
		clampi(roundi(color.a * 255.0), 0, 255),
	]
