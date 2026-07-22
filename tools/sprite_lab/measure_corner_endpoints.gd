extends Node

const BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")
const DIR := "res://tools/sprite_lab/source/dome_material"
const N := 32
const P := 14

func load_img(name: String) -> Image:
	var im := Image.load_from_file(ProjectSettings.globalize_path(DIR + "/" + name))
	im.convert(Image.FORMAT_RGBA8)
	im.resize(N, N, Image.INTERPOLATE_NEAREST)
	return im

func luminance(c: Color) -> float:
	return c.r + c.g + c.b

func brightest_color(im: Image) -> Color:
	var best := Color.TRANSPARENT
	var score := -1.0
	for y in range(im.get_height()):
		for x in range(im.get_width()):
			var c := im.get_pixel(x,y)
			if c.a > 0.05 and luminance(c) > score:
				score = luminance(c)
				best = c
	return best

func coords_with_color(im: Image, target: Color, rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if im.get_pixel(x,y).is_equal_approx(target):
				out.append(Vector2i(x,y))
	return out

func _ready() -> void:
	var border := load_img("easy_border_top_32.png")
	var joint := load_img("easy_edge_joint_top_left_32.png")
	var bright := brightest_color(border)
	var down := BUILDER.rotate_quarters(border, 2)
	var right := BUILDER.rotate_quarters(border, 1)
	print("BRIGHT=", bright.to_html())
	print("DOWN bottom-left bright: ", coords_with_color(down, bright, Rect2i(0, 18, 16, 14)))
	print("RIGHT top-right bright: ", coords_with_color(right, bright, Rect2i(18, 0, 14, 16)))
	print("JOINT patch bright: ", coords_with_color(joint, bright, Rect2i(0,0,P,P)))
	get_tree().quit()
