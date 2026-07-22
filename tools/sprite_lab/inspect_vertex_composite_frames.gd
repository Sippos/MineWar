extends Node

const BUILDER = preload("res://tools/sprite_lab/dome_corner_builder.gd")
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const OUT_DIR := "res://tools/sprite_lab/diagnostics/vertex_frames"
const LOGICAL_SIZE := 32
const PATCH_SIZE := 14

func _load_image(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)
	image.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return image

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var mass: Image = _load_image(SOURCE_DIR + "/dark_mass_32.png")
	var border: Image = _load_image(SOURCE_DIR + "/easy_border_top_32.png")
	var edge: Image = _load_image(SOURCE_DIR + "/easy_edge_joint_top_left_32.png")
	var hole: Image = BUILDER.make_hole_corner_top_left(mass, border, edge)
	var size := LOGICAL_SIZE * 2
	var base := Image.create(size, size, false, Image.FORMAT_RGBA8)
	base.fill(Color.TRANSPARENT)
	var endpoint := PATCH_SIZE - 2
	for y in range(endpoint):
		for x in range(endpoint):
			base.set_pixel(LOGICAL_SIZE + x, LOGICAL_SIZE - endpoint + y, mass.get_pixel(x, LOGICAL_SIZE - endpoint + y))
			base.set_pixel(LOGICAL_SIZE - endpoint + x, LOGICAL_SIZE + y, mass.get_pixel(LOGICAL_SIZE - endpoint + x, y))
	for y in range(PATCH_SIZE):
		for x in range(PATCH_SIZE):
			var color := hole.get_pixel(x, y)
			if color.a > 0.05:
				base.set_pixel(LOGICAL_SIZE + x, LOGICAL_SIZE + y, color)
	for frame in range(4):
		var rotated: Image = BUILDER.rotate_quarters(base, frame)
		rotated.save_png(OUT_DIR + "/frame_%d.png" % frame)
		var min_x := size
		var min_y := size
		var max_x := -1
		var max_y := -1
		for y in range(size):
			for x in range(size):
				if rotated.get_pixel(x, y).a > 0.05:
					min_x = mini(min_x, x)
					min_y = mini(min_y, y)
					max_x = maxi(max_x, x)
					max_y = maxi(max_y, y)
		print("frame ", frame, " bounds=", Vector4i(min_x, min_y, max_x, max_y))
	get_tree().quit()
