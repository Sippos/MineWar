extends Node

const TARGETS := [
	"res://tools/sprite_lab/dome_material_preview.gd",
	"res://tools/sprite_lab/dome_material_workbench.gd",
]

const REPLACEMENT := '''func _rotate_vertex_composite(source: Image, turns: int) -> Image:
	# The 2x2 composite's terrain vertex lies between pixels 31 and 32. Pixel
	# indices therefore rotate around (31.5, 31.5), using the normal size - 1
	# quarter-turn mapping. Rotating indices around integer 32 shifts the 90°,
	# 180° and 270° Hole Corner frames by one logical pixel.
	var normalized := posmod(turns, 4)
	var size := source.get_width()
	var result := Image.create(size, size, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(size):
		for x in range(size):
			var destination := Vector2i(x, y)
			match normalized:
				1: destination = Vector2i(size - 1 - y, x)
				2: destination = Vector2i(size - 1 - x, size - 1 - y)
				3: destination = Vector2i(y, size - 1 - x)
			result.set_pixelv(destination, source.get_pixel(x, y))
	return result
'''

func _replace_function(text: String, function_name: String) -> String:
	var start := text.find("func %s(" % function_name)
	if start < 0:
		push_error("Missing function %s" % function_name)
		return ""
	var next := text.find("\nfunc ", start + 1)
	if next < 0:
		next = text.length()
	return text.substr(0, start) + REPLACEMENT + text.substr(next + 1 if next < text.length() else next)

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true

func _ready() -> void:
	for path in TARGETS:
		var text := FileAccess.get_file_as_string(path)
		var patched := _replace_function(text, "_rotate_vertex_composite")
		if patched.is_empty() or not _write(path, patched):
			get_tree().quit(1)
			return
	print("Hole Corner vertex composites now rotate around the half-pixel grid vertex without one-pixel drift")
	get_tree().quit()
