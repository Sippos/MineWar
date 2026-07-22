extends Node

const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"

func _mask_line(image: Image, y: int) -> String:
	var line := ""
	for x in range(32):
		line += "#" if image.get_pixel(x, y).a > 0.05 else "."
	return line

func _ready() -> void:
	var edge := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/easy_edge_joint_top_left_32.png"))
	var hole := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/easy_hole_corner_top_left_32.png"))
	edge.convert(Image.FORMAT_RGBA8)
	hole.convert(Image.FORMAT_RGBA8)
	print("EDGE")
	for y in range(16):
		print("%02d %s" % [y, _mask_line(edge, y).substr(0, 16)])
	print("HOLE BR")
	for y in range(16, 32):
		print("%02d %s" % [y, _mask_line(hole, y).substr(16, 16)])
	print("EDGE COLORS")
	var colors := {}
	for y in range(16):
		for x in range(16):
			var c := edge.get_pixel(x, y)
			if c.a > 0.05:
				colors[c.to_html()] = int(colors.get(c.to_html(), 0)) + 1
	print(colors)
	print("HOLE COLORS")
	colors.clear()
	for y in range(16, 32):
		for x in range(16, 32):
			var c := hole.get_pixel(x, y)
			if c.a > 0.05:
				colors[c.to_html()] = int(colors.get(c.to_html(), 0)) + 1
	print(colors)
	get_tree().quit()
