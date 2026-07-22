extends Node

const BUILDER_PATH := "res://tools/sprite_lab/dome_corner_builder.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(BUILDER_PATH)
	var start := text.find("static func rotate_quarters(")
	var next := text.find("\nstatic func ", start + 8)
	if start < 0 or next < 0:
		push_error("Could not locate rotate_quarters")
		get_tree().quit(1)
		return
	var replacement := '''static func rotate_quarters(source: Image, turns: int) -> Image:
	var normalized_turns := posmod(turns, 4)
	var width := source.get_width()
	var height := source.get_height()
	if width != height:
		push_error("rotate_quarters expects a square image")
		return source.duplicate()
	var size := width
	var result: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(size):
		for x in range(size):
			var destination := Vector2i(x, y)
			match normalized_turns:
				1: destination = Vector2i(size - 1 - y, x)
				2: destination = Vector2i(size - 1 - x, size - 1 - y)
				3: destination = Vector2i(y, size - 1 - x)
			result.set_pixelv(destination, source.get_pixel(x, y))
	return result
'''
	text = text.substr(0, start) + replacement + text.substr(next + 1)
	var file := FileAccess.open(BUILDER_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write builder")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Quarter rotation now supports any square image size")
	get_tree().quit()
