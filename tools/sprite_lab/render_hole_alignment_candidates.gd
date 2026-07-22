extends Node

const BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const OUT_DIR := "res://tools/sprite_lab/diagnostics/hole_candidates"
const S := 32
const PATCH := 14
const CAVE := Color(0.06666667, 0.09019608, 0.14509804, 1.0)

func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	img.resize(S, S, Image.INTERPOLATE_NEAREST)
	return img

func _solid_tile(mass: Image, border: Image, turn: int) -> Image:
	var tile := mass.duplicate()
	var rotated := BUILDER.rotate_quarters(border, turn)
	tile.blend_rect(rotated, Rect2i(Vector2i.ZERO, Vector2i(S, S)), Vector2i.ZERO)
	return tile

func _candidate(mass: Image, border: Image, edge: Image, endpoint: int, origin: int) -> Image:
	var canvas := Image.create(S * 2, S * 2, false, Image.FORMAT_RGBA8)
	canvas.fill(CAVE)
	canvas.blit_rect(mass, Rect2i(Vector2i.ZERO, Vector2i(S, S)), Vector2i.ZERO)
	canvas.blit_rect(_solid_tile(mass, border, 2), Rect2i(Vector2i.ZERO, Vector2i(S, S)), Vector2i(S, 0))
	canvas.blit_rect(_solid_tile(mass, border, 1), Rect2i(Vector2i.ZERO, Vector2i(S, S)), Vector2i(0, S))
	var hole := BUILDER.make_hole_corner_top_left(mass, border, edge)
	for y in range(endpoint):
		for x in range(endpoint):
			canvas.set_pixel(S + x, S - endpoint + y, mass.get_pixel(x, S - endpoint + y))
			canvas.set_pixel(S - endpoint + x, S + y, mass.get_pixel(S - endpoint + x, y))
	for y in range(PATCH):
		for x in range(PATCH):
			var color := hole.get_pixel(x, y)
			if color.a > 0.05:
				canvas.set_pixel(origin + x, origin + y, color)
	return canvas

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var mass := _load(SOURCE_DIR + "/dark_mass_32.png")
	var border := _load(SOURCE_DIR + "/easy_border_top_32.png")
	var edge := _load(SOURCE_DIR + "/easy_edge_joint_top_left_32.png")
	var montage := Image.create(192, 192, false, Image.FORMAT_RGBA8)
	montage.fill(Color.WHITE)
	var endpoints := [10, 11, 12]
	var origins := [30, 31, 32]
	for row in range(3):
		for col in range(3):
			var candidate := _candidate(mass, border, edge, endpoints[row], origins[col])
			candidate.save_png(OUT_DIR + "/endpoint_%d_origin_%d.png" % [endpoints[row], origins[col]])
			montage.blit_rect(candidate, Rect2i(Vector2i.ZERO, Vector2i(64,64)), Vector2i(col * 64, row * 64))
	montage.resize(1536, 1536, Image.INTERPOLATE_NEAREST)
	montage.save_png(OUT_DIR + "/montage_8x.png")
	print("Rows endpoint 10/11/12; columns origin 30/31/32")
	get_tree().quit()
