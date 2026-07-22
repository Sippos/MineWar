extends Node

const BUILDER_PATH := "res://tools/sprite_lab/dome_corner_builder.gd"
const WORLD_PATH := "res://scripts/systems/world_generation/world.gd"
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const BACKUP_DIR := SOURCE_DIR + "/backups/hole_corner_cutout_geometry"
const TIERS: Array[String] = ["easy", "medium", "hard", "unmineable"]
const LOGICAL_SIZE := 32
const PATCH_SIZE := 14

func _ready() -> void:
	var result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP_DIR))
	if result != OK and result != ERR_ALREADY_EXISTS:
		_fail("Could not create backup folder: %s" % error_string(result))
		return

	if not _patch_builder():
		return
	if not _regenerate_sources():
		return
	if not _patch_runtime_offset():
		return

	print("Hole Corner rebuilt as opaque outer rock + transparent inner cave cutout")
	get_tree().quit()

func _patch_builder() -> bool:
	var text := FileAccess.get_file_as_string(BUILDER_PATH)
	var start := text.find("static func make_hole_corner_top_left(")
	var finish := text.find("\nstatic func", start + 1)
	if start < 0 or finish < 0:
		_fail("Could not locate make_hole_corner_top_left in builder")
		return false

	var replacement := """static func make_hole_corner_top_left(mass_image: Image, top_border: Image) -> Image:
	## Rounded top-left corner of EMPTY cave space.
	## The cave interior (down-right) stays transparent. The outside/top-left
	## wedge is opaque rock, with the same layered palette as the straight border.
	var result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var depth := border_depth(top_border)
	var radius := clampi(depth, 8, CORNER_EDIT_SIZE - 3)
	var center := Vector2(float(radius) + 0.5, float(radius) + 0.5)
	var maximum_outward := maxf(1.0, float(radius) * (sqrt(2.0) - 1.0))

	for y in range(CORNER_EDIT_SIZE):
		for x in range(CORNER_EDIT_SIZE):
			# Pixels beyond the two arc endpoints belong to the open cave and must
			# remain transparent so straight wall sections can continue cleanly.
			if x > radius or y > radius:
				continue
			var sample := Vector2(float(x) + 0.5, float(y) + 0.5)
			var distance := sample.distance_to(center)
			if distance < float(radius):
				# Inner quarter-circle: actual cave space.
				continue
			var outward := distance - float(radius)
			var palette_t := clampf(outward / maximum_outward, 0.0, 1.0)
			var source_row := clampi(roundi(palette_t * float(depth - 1)), 0, depth - 1)
			var color := average_border_row(top_border, source_row)
			if color.a <= 0.05:
				color = mass_image.get_pixel(clampi(x, 0, mass_image.get_width() - 1), clampi(y, 0, mass_image.get_height() - 1))
			result.set_pixel(x, y, color)
	return result
"""
	text = text.substr(0, start) + replacement + text.substr(finish)
	return _write_text(BUILDER_PATH, text)

func _regenerate_sources() -> bool:
	var mass := _load_image(SOURCE_DIR + "/dark_mass_32.png")
	if mass == null:
		_fail("Could not load dark mass source")
		return false

	for tier in TIERS:
		var border := _load_image(SOURCE_DIR + "/%s_border_top_32.png" % tier)
		if border == null:
			_fail("Could not load border source for %s" % tier)
			return false
		var output_path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
		if FileAccess.file_exists(output_path):
			var old := _load_image(output_path)
			if old != null:
				old.save_png(BACKUP_DIR + "/%s_hole_corner_top_left_32.png" % tier)
		var corner := _make_hole_corner(mass, border)
		var save_result := corner.save_png(output_path)
		if save_result != OK:
			_fail("Could not save Hole Corner for %s: %s" % [tier, error_string(save_result)])
			return false
	return true

func _make_hole_corner(mass: Image, border: Image) -> Image:
	var result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var depth := _border_depth(border)
	var radius := clampi(depth, 8, PATCH_SIZE - 3)
	var center := Vector2(float(radius) + 0.5, float(radius) + 0.5)
	var maximum_outward := maxf(1.0, float(radius) * (sqrt(2.0) - 1.0))
	for y in range(PATCH_SIZE):
		for x in range(PATCH_SIZE):
			if x > radius or y > radius:
				continue
			var sample := Vector2(float(x) + 0.5, float(y) + 0.5)
			var distance := sample.distance_to(center)
			if distance < float(radius):
				continue
			var palette_t := clampf((distance - float(radius)) / maximum_outward, 0.0, 1.0)
			var row := clampi(roundi(palette_t * float(depth - 1)), 0, depth - 1)
			var color := _average_border_row(border, row)
			if color.a <= 0.05:
				color = mass.get_pixel(x, y)
			result.set_pixel(x, y, color)
	return result

func _border_depth(border: Image) -> int:
	var deepest := -1
	for y in range(LOGICAL_SIZE):
		for x in range(LOGICAL_SIZE):
			if border.get_pixel(x, y).a > 0.05:
				deepest = maxi(deepest, y)
	return clampi(deepest + 1, 3, PATCH_SIZE)

func _average_border_row(border: Image, row: int) -> Color:
	var total := Color(0, 0, 0, 0)
	var count := 0
	for x in range(LOGICAL_SIZE):
		var color := border.get_pixel(x, clampi(row, 0, LOGICAL_SIZE - 1))
		if color.a > 0.05:
			total += color
			count += 1
	return total / float(count) if count > 0 else Color.TRANSPARENT

func _patch_runtime_offset() -> bool:
	var text := FileAccess.get_file_as_string(WORLD_PATH)
	var old := "\t\tsprite.position = inside_corner_layer.to_local(block_layer.to_global(block_layer.map_to_local(cell)))"
	if not text.contains(old):
		# Already patched or runtime code changed; do not fail the editor fix.
		return true
	var new := """		var corner_offset := Vector2.ZERO
		match frame:
			0: corner_offset = Vector2(-2, -2)
			1: corner_offset = Vector2(2, -2)
			2: corner_offset = Vector2(2, 2)
			3: corner_offset = Vector2(-2, 2)
		sprite.position = inside_corner_layer.to_local(block_layer.to_global(block_layer.map_to_local(cell))) + corner_offset"""
	text = text.replace(old, new)
	return _write_text(WORLD_PATH, text)

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

func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
