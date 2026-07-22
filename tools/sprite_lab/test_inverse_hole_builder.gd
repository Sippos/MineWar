extends Node

const BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")
const DIR := "res://tools/sprite_lab/source/dome_material"
const OUT := "res://tools/sprite_lab/diagnostics/inverse_hole_test.png"
const N := 32
const S := 4

func load_img(name: String) -> Image:
	var im := Image.load_from_file(ProjectSettings.globalize_path(DIR + "/" + name))
	im.convert(Image.FORMAT_RGBA8)
	im.resize(N, N, Image.INTERPOLATE_NEAREST)
	return im

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/sprite_lab/diagnostics"))
	var mass := load_img("dark_mass_32.png")
	var border := load_img("easy_border_top_32.png")
	var joint := load_img("easy_edge_joint_top_left_32.png")
	var hole := BUILDER.make_hole_corner_top_left(mass, border, joint)
	var image := Image.create(N * 2, N * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.html("111725ff"))
	var tl := BUILDER.build_composite_tile(mass, border, 0, joint)
	var tr := BUILDER.build_composite_tile(mass, border, 4, joint)
	var bl := BUILDER.build_composite_tile(mass, border, 2, joint)
	image.blit_rect(tl, Rect2i(0,0,N,N), Vector2i(0,0))
	image.blit_rect(tr, Rect2i(0,0,N,N), Vector2i(N,0))
	image.blit_rect(bl, Rect2i(0,0,N,N), Vector2i(0,N))
	image.blend_rect(hole, Rect2i(0,0,14,14), Vector2i(N,N))
	image.resize(image.get_width()*S, image.get_height()*S, Image.INTERPOLATE_NEAREST)
	image.save_png(OUT)
	hole.save_png("res://tools/sprite_lab/diagnostics/generated_hole_source.png")
	print("Generated inverse hole builder test")
	get_tree().quit()
