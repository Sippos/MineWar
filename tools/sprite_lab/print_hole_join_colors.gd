extends Node

const BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")
const DIR := "res://tools/sprite_lab/source/dome_material"
const S := 32

func _load(name: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + "/" + name))
	img.convert(Image.FORMAT_RGBA8)
	img.resize(S, S, Image.INTERPOLATE_NEAREST)
	return img

func _tag(c: Color) -> String:
	if c.a <= 0.05:
		return "----"
	return c.to_html(false).substr(0, 6)

func _ready() -> void:
	var mass := _load("dark_mass_32.png")
	var border := _load("easy_border_top_32.png")
	var edge := _load("easy_edge_joint_top_left_32.png")
	var hole := BUILDER.make_hole_corner_top_left(mass, border, edge)
	var bottom := BUILDER.rotate_quarters(border, 2)
	var right := BUILDER.rotate_quarters(border, 1)
	print("HOLE TOP y0:")
	for x in range(14):
		print("x=%02d %s lum=%.3f" % [x, _tag(hole.get_pixel(x,0)), hole.get_pixel(x,0).r + hole.get_pixel(x,0).g + hole.get_pixel(x,0).b])
	print("HOLE LEFT x0:")
	for y in range(14):
		print("y=%02d %s lum=%.3f" % [y, _tag(hole.get_pixel(0,y)), hole.get_pixel(0,y).r + hole.get_pixel(0,y).g + hole.get_pixel(0,y).b])
	print("BOTTOM BORDER rows at x16:")
	for y in range(20,32):
		print("y=%02d %s lum=%.3f" % [y, _tag(bottom.get_pixel(16,y)), bottom.get_pixel(16,y).r + bottom.get_pixel(16,y).g + bottom.get_pixel(16,y).b])
	print("RIGHT BORDER cols at y16:")
	for x in range(20,32):
		print("x=%02d %s lum=%.3f" % [x, _tag(right.get_pixel(x,16)), right.get_pixel(x,16).r + right.get_pixel(x,16).g + right.get_pixel(x,16).b])
	get_tree().quit()
