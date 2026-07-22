extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _replace_function(text: String, function_name: String, replacement: String) -> String:
	var start := text.find("func %s(" % function_name)
	if start < 0:
		push_error("Missing function %s" % function_name)
		return ""
	var next := text.find("\nfunc ", start + 1)
	if next < 0:
		next = text.length()
	return text.substr(0, start) + replacement + text.substr(next)

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	text = _replace_function(text, "_build_vertex_hole_textures", '''func _build_vertex_hole_textures(_mass: Image, _top_border: Image, hole_source: Image) -> Array[ImageTexture]:
	# Hole Corners are small vertex patches, not four-cell replacement images.
	# The canonical 14x14 source is rotated in-place, preserving one exact pixel
	# grid and eliminating all 64/128-pixel centre-anchor ambiguity.
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
	text = _replace_function(text, "_draw_hole_corners", '''func _draw_hole_corners(empty_cell: Vector2i, rect: Rect2) -> void:
	var rules := [
		[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],
		[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],
		[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],
		[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],
	]
	for rule_value in rules:
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
	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write preview")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Hole Corners now render as exact 14x14 vertex patches")
	get_tree().quit()
