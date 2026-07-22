extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _replace_function(text: String, function_name: String, replacement: String) -> String:
	var start := text.find("func %s(" % function_name)
	if start < 0:
		push_error("Missing function: %s" % function_name)
		return ""
	var next := text.find("\nfunc ", start + 1)
	if next < 0:
		next = text.length()
	return text.substr(0, start) + replacement + text.substr(next)

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	if text.is_empty():
		push_error("Could not read preview script")
		get_tree().quit(1)
		return

	if not text.contains("var mass_texture: ImageTexture"):
		text = text.replace("var mass_image: Image\n", "var mass_image: Image\nvar mass_texture: ImageTexture\n")
	text = text.replace("\tmass_image = new_mass_image.duplicate()\n", "\tmass_image = new_mass_image.duplicate()\n\tmass_texture = ImageTexture.create_from_image(mass_image)\n")

	text = _replace_function(text, "_build_vertex_hole_textures", '''func _build_vertex_hole_textures(_mass: Image, _top_border: Image, hole_source: Image) -> Array[ImageTexture]:
	# Hole Corners are native 14x14 vertex patches. The same authored boundary
	# is rotated in-place, so there is no 64x64/128x128 anchor ambiguity.
	var source_patch := Image.create(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE, false, Image.FORMAT_RGBA8)
	source_patch.fill(Color.TRANSPARENT)
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			source_patch.set_pixel(x, y, hole_source.get_pixel(x, y))
	var result: Array[ImageTexture] = []
	for frame in range(4):
		result.append(ImageTexture.create_from_image(_rotate_corner_patch(source_patch, frame)))
	return result
''')
	if text.is_empty():
		get_tree().quit(1)
		return

	text = _replace_function(text, "_draw_hole_corners", '''func _draw_hole_corners(empty_cell: Vector2i, rect: Rect2) -> void:
	var rules := [
		[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],
		[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],
		[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],
		[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],
	]
	for rule_value: Variant in rules:
		var rule: Array = rule_value
		var first: Vector2i = rule[0]
		var second: Vector2i = rule[1]
		var diagonal: Vector2i = rule[2]
		var frame: int = rule[3]
		if not _is_solid(empty_cell + first) or not _is_solid(empty_cell + second) or not _is_solid(empty_cell + diagonal):
			continue
		var owner_type := _cell_type(empty_cell + diagonal)
		var textures := _inside_corner_textures_for(owner_type)
		if frame >= textures.size() or textures[frame] == null:
			continue
		var patch_rect := _hole_corner_patch_rect(rect, frame)
		_mask_hole_corner_border_bands(rect, patch_rect, frame, owner_type)
		draw_texture_rect(textures[frame], patch_rect, false)
''')
	if text.is_empty():
		get_tree().quit(1)
		return

	text = _replace_function(text, "_hole_corner_patch_rect", '''func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:
	# The canonical patch starts exactly at the terrain vertex and stays inside
	# the empty cell. Its endpoints touch the neighbouring straight borders.
	var patch_position := rect.position
	match frame:
		1: patch_position = Vector2(rect.end.x - CORNER_PATCH_SIZE, rect.position.y)
		2: patch_position = rect.end - Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE)
		3: patch_position = Vector2(rect.position.x, rect.end.y - CORNER_PATCH_SIZE)
	return Rect2(patch_position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))
''')
	if text.is_empty():
		get_tree().quit(1)
		return

	text = _replace_function(text, "_mask_hole_corner_border_bands", '''func _mask_hole_corner_border_bands(rect: Rect2, _patch_rect: Rect2, frame: int, owner_type: int) -> void:
	# Remove only the square ends of the two straight borders, restoring the
	# original dirt mass underneath. Drawing cave colour here caused the black
	# notches that looked like a persistent one-pixel offset.
	if mass_texture == null:
		return
	var depth := float(_border_depth_for(owner_type))
	var cut := float(CORNER_PATCH_SIZE - 4)
	match frame:
		0:
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.position.x, rect.position.y - depth), Vector2(cut, depth)), Rect2(Vector2(0, LOGICAL_SIZE - int(depth)), Vector2(cut, depth)))
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.position.x - depth, rect.position.y), Vector2(depth, cut)), Rect2(Vector2(LOGICAL_SIZE - int(depth), 0), Vector2(depth, cut)))
		1:
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.end.x - cut, rect.position.y - depth), Vector2(cut, depth)), Rect2(Vector2(LOGICAL_SIZE - int(cut), LOGICAL_SIZE - int(depth)), Vector2(cut, depth)))
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.end.x, rect.position.y), Vector2(depth, cut)), Rect2(Vector2(0, 0), Vector2(depth, cut)))
		2:
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.end.x - cut, rect.end.y), Vector2(cut, depth)), Rect2(Vector2(LOGICAL_SIZE - int(cut), 0), Vector2(cut, depth)))
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.end.x, rect.end.y - cut), Vector2(depth, cut)), Rect2(Vector2(0, LOGICAL_SIZE - int(cut)), Vector2(depth, cut)))
		3:
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.position.x, rect.end.y), Vector2(cut, depth)), Rect2(Vector2(0, 0), Vector2(cut, depth)))
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.position.x - depth, rect.end.y - cut), Vector2(depth, cut)), Rect2(Vector2(LOGICAL_SIZE - int(depth), LOGICAL_SIZE - int(cut)), Vector2(depth, cut)))
''')
	if text.is_empty():
		get_tree().quit(1)
		return

	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write preview script")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Rebuilt Hole Corner preview around native 14x14 vertex patches")
	get_tree().quit()
