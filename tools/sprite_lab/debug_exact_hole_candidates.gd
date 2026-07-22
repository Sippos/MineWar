extends Node

const BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const OUT_DIR := "res://tools/sprite_lab/diagnostics/exact_hole_candidates"
const S := 32
const PATCH := 14
const CAVE := Color("111725")

func _load_image(name: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/" + name))
	image.convert(Image.FORMAT_RGBA8)
	image.resize(S, S, Image.INTERPOLATE_NEAREST)
	return image

func _solid_tile(mass: Image, border: Image, turn: int) -> Image:
	var tile := mass.duplicate()
	tile.blend_rect(BUILDER.rotate_quarters(border, turn), Rect2i(0, 0, S, S), Vector2i.ZERO)
	return tile

func _candidate(mass: Image, border: Image, hole: Image, cut: int, origin: int) -> Image:
	# Exact layout used by the live preview: TL solid, TR solid with DOWN border,
	# BL solid with RIGHT border, BR empty cave, then one transparent 64x64 overlay.
	var canvas := Image.create(S * 2, S * 2, false, Image.FORMAT_RGBA8)
	canvas.fill(CAVE)
	canvas.blit_rect(mass, Rect2i(0, 0, S, S), Vector2i.ZERO)
	canvas.blit_rect(_solid_tile(mass, border, 2), Rect2i(0, 0, S, S), Vector2i(S, 0))
	canvas.blit_rect(_solid_tile(mass, border, 1), Rect2i(0, 0, S, S), Vector2i(0, S))

	var depth := BUILDER.border_depth(border)
	var overlay := Image.create(S * 2, S * 2, false, Image.FORMAT_RGBA8)
	overlay.fill(Color.TRANSPARENT)
	for y in range(depth):
		for x in range(cut):
			overlay.set_pixel(S + x, S - depth + y, mass.get_pixel(x, S - depth + y))
	for y in range(cut):
		for x in range(depth):
			overlay.set_pixel(S - depth + x, S + y, mass.get_pixel(S - depth + x, y))
	for y in range(PATCH):
		for x in range(PATCH):
			var color := hole.get_pixel(x, y)
			if color.a > 0.05:
				overlay.set_pixel(origin + x, origin + y, color)
	canvas.blend_rect(overlay, Rect2i(0, 0, S * 2, S * 2), Vector2i.ZERO)
	return canvas

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var mass := _load_image("dark_mass_32.png")
	var border := _load_image("easy_border_top_32.png")
	var hole := _load_image("easy_hole_corner_top_left_32.png")
	var cuts := [10, 11, 12, 13, 14]
	var origins := [30, 31, 32]
	var montage := Image.create(64 * cuts.size(), 64 * origins.size(), false, Image.FORMAT_RGBA8)
	montage.fill(Color.WHITE)
	for row in range(origins.size()):
		for col in range(cuts.size()):
			var candidate := _candidate(mass, border, hole, cuts[col], origins[row])
			candidate.save_png(OUT_DIR + "/origin_%d_cut_%d.png" % [origins[row], cuts[col]])
			montage.blit_rect(candidate, Rect2i(0, 0, 64, 64), Vector2i(col * 64, row * 64))
	montage.resize(montage.get_width() * 6, montage.get_height() * 6, Image.INTERPOLATE_NEAREST)
	montage.save_png(OUT_DIR + "/montage_6x.png")
	print("Rows origins 30/31/32; columns cuts 10/11/12/13/14; depth=", BUILDER.border_depth(border))
	get_tree().quit()
