extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true

func _insert_helper(text: String, anchor: String) -> String:
	if text.contains("func _rotate_vertex_composite("):
		return text
	var index := text.find(anchor)
	if index < 0:
		push_error("Missing helper anchor")
		return ""
	var helper := '''func _rotate_vertex_composite(source: Image, turns: int) -> Image:
	# Rotate around the terrain grid vertex at (32,32), not the even-sized
	# image centre at (31.5,31.5). Centre rotation causes alternating frames to
	# drift one logical pixel inward.
	var normalized := posmod(turns, 4)
	var size := source.get_width()
	var vertex := size / 2
	var result := Image.create(size, size, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(size):
		for x in range(size):
			var destination := Vector2i(x, y)
			var dx := x - vertex
			var dy := y - vertex
			match normalized:
				1: destination = Vector2i(vertex - dy, vertex + dx)
				2: destination = Vector2i(vertex - dx, vertex - dy)
				3: destination = Vector2i(vertex + dy, vertex - dx)
			if destination.x >= 0 and destination.y >= 0 and destination.x < size and destination.y < size:
				result.set_pixelv(destination, source.get_pixel(x, y))
	return result

'''
	return text.substr(0, index) + helper + text.substr(index)

func _patch_preview() -> bool:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	text = _insert_helper(text, "func _build_diagonal_hole_textures(")
	if text.is_empty(): return false
	text = text.replace("result.append(ImageTexture.create_from_image(CORNER_BUILDER.rotate_quarters(base, frame)))", "result.append(ImageTexture.create_from_image(_rotate_vertex_composite(base, frame)))")
	return _write(PREVIEW_PATH, text)

func _patch_workbench() -> bool:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	text = _insert_helper(text, "func _rotate_export_corner_patch(")
	if text.is_empty(): return false
	text = text.replace("var rendered := CORNER_BUILDER.rotate_quarters(base, frame)", "var rendered := _rotate_vertex_composite(base, frame)")
	return _write(WORKBENCH_PATH, text)

func _ready() -> void:
	if not _patch_preview() or not _patch_workbench():
		get_tree().quit(1)
		return
	print("Vertex composites now rotate around terrain vertex (32,32)")
	get_tree().quit()
