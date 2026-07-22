extends Node

const BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const OUT_DIR := "res://tools/sprite_lab/diagnostics/hole_alignment"
const LOGICAL := 32
const PATCH := 14
const SCALE := 4

func _load_image(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		push_error("Could not load %s" % path)
		return Image.new()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(LOGICAL, LOGICAL, Image.INTERPOLATE_NEAREST)
	return image

func _extract_patch(source: Image) -> Image:
	var patch := Image.create(PATCH, PATCH, false, Image.FORMAT_RGBA8)
	patch.fill(Color.TRANSPARENT)
	patch.blit_rect(source, Rect2i(0, 0, PATCH, PATCH), Vector2i.ZERO)
	return patch

func _rotate(source: Image, turns: int) -> Image:
	var result := Image.create(PATCH, PATCH, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(PATCH):
		for x in range(PATCH):
			var p := Vector2i(x, y)
			match posmod(turns, 4):
				1: p = Vector2i(PATCH - 1 - y, x)
				2: p = Vector2i(PATCH - 1 - x, PATCH - 1 - y)
				3: p = Vector2i(y, PATCH - 1 - x)
			result.set_pixelv(p, source.get_pixel(x, y))
	return result

func _make_base(mass: Image, border: Image, joint: Image) -> Image:
	# 2x2 cells around one vertex: TL solid, TR solid with DOWN exposure,
	# BL solid with RIGHT exposure, BR empty cave.
	var image := Image.create(LOGICAL * 2, LOGICAL * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.html("111725ff"))
	var tl := BUILDER.build_composite_tile(mass, border, 0, joint)
	var tr := BUILDER.build_composite_tile(mass, border, 4, joint)
	var bl := BUILDER.build_composite_tile(mass, border, 2, joint)
	image.blit_rect(tl, Rect2i(0, 0, LOGICAL, LOGICAL), Vector2i(0, 0))
	image.blit_rect(tr, Rect2i(0, 0, LOGICAL, LOGICAL), Vector2i(LOGICAL, 0))
	image.blit_rect(bl, Rect2i(0, 0, LOGICAL, LOGICAL), Vector2i(0, LOGICAL))
	return image

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var mass := _load_image(SOURCE_DIR + "/dark_mass_32.png")
	var border := _load_image(SOURCE_DIR + "/easy_border_top_32.png")
	var joint := _load_image(SOURCE_DIR + "/easy_edge_joint_top_left_32.png")
	if mass.is_empty() or border.is_empty() or joint.is_empty():
		get_tree().quit(1)
		return
	var patch := _extract_patch(joint)
	for turn in range(4):
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				var candidate := _make_base(mass, border, joint)
				var rotated := _rotate(patch, turn)
				candidate.blend_rect(rotated, Rect2i(0, 0, PATCH, PATCH), Vector2i(LOGICAL + ox, LOGICAL + oy))
				candidate.resize(candidate.get_width() * SCALE, candidate.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
				candidate.save_png(OUT_DIR + "/turn_%d_offset_%+d_%+d.png" % [turn, ox, oy])
	print("Generated hole alignment diagnostics")
	get_tree().quit()
