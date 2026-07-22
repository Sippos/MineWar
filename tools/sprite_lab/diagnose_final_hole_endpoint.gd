extends Node

const BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const OUT_DIR := "res://tools/sprite_lab/diagnostics/final_hole_endpoint"
const LOGICAL_SIZE := 32
const PATCH := 14

func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	img.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return img

func _hex(c: Color) -> String:
	return c.to_html(true)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var mass := _load(SOURCE_DIR + "/dark_mass_32.png")
	var border := _load(SOURCE_DIR + "/easy_border_top_32.png")
	var edge := _load(SOURCE_DIR + "/easy_edge_joint_top_left_32.png")
	var hole := BUILDER.make_hole_corner_top_left(mass, border, edge)
	var base := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	base.fill(Color.TRANSPARENT)
	var endpoint := PATCH - 3
	for y in range(endpoint):
		for x in range(endpoint):
			base.set_pixel(LOGICAL_SIZE + x, LOGICAL_SIZE - endpoint + y, mass.get_pixel(x, LOGICAL_SIZE - endpoint + y))
			base.set_pixel(LOGICAL_SIZE - endpoint + x, LOGICAL_SIZE + y, mass.get_pixel(LOGICAL_SIZE - endpoint + x, y))
	for y in range(PATCH):
		for x in range(PATCH):
			var color := hole.get_pixel(x, y)
			if color.a > 0.05:
				base.set_pixel(LOGICAL_SIZE - 1 + x, LOGICAL_SIZE - 1 + y, color)
	base.save_png(OUT_DIR + "/frame0_logical.png")
	var enlarged := base.duplicate()
	enlarged.resize(512, 512, Image.INTERPOLATE_NEAREST)
	enlarged.save_png(OUT_DIR + "/frame0_8x.png")
	print("HOLE nontransparent around top/left endpoints:")
	for y in range(PATCH):
		var row := ""
		for x in range(PATCH):
			var c := hole.get_pixel(x, y)
			row += "#" if c.a > 0.05 else "."
		print("%02d %s" % [y, row])
	print("CENTER 25..46 alpha/color:")
	for y in range(25, 47):
		var row := ""
		for x in range(25, 47):
			var c := base.get_pixel(x, y)
			if c.a <= 0.05:
				row += "."
			elif c.r + c.g + c.b > 1.75:
				row += "B"
			else:
				row += "m"
		print("%02d %s" % [y, row])
	print("Saved endpoint diagnostic")
	get_tree().quit()
