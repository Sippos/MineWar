extends Node

const BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const OUT_DIR := "res://tools/sprite_lab/diagnostics/clean_hole_bands"
const S := 32
const P := 14
const CAVE := Color("111725")

func _load_image(name: String) -> Image:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/" + name))
	image.convert(Image.FORMAT_RGBA8)
	image.resize(S, S, Image.INTERPOLATE_NEAREST)
	return image

func _outside_points(joint: Image) -> Array[Vector2i]:
	var outside: Dictionary = {}
	var pending: Array[Vector2i] = []
	if joint.get_pixel(0, 0).a <= 0.05:
		outside[Vector2i.ZERO] = true
		pending.append(Vector2i.ZERO)
	while not pending.is_empty():
		var point: Vector2i = pending.pop_front()
		for direction_value: Variant in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var direction: Vector2i = direction_value as Vector2i
			var next_point: Vector2i = point + direction
			if next_point.x < 0 or next_point.y < 0 or next_point.x >= P or next_point.y >= P:
				continue
			if outside.has(next_point) or joint.get_pixelv(next_point).a > 0.05:
				continue
			outside[next_point] = true
			pending.append(next_point)
	var result: Array[Vector2i] = []
	for value: Variant in outside.keys():
		result.append(value as Vector2i)
	return result

func _make_hole(mass: Image, joint: Image, thickness: float) -> Image:
	var outside: Array[Vector2i] = _outside_points(joint)
	var result: Image = Image.create(S, S, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for point: Vector2i in outside:
		result.set_pixelv(point, mass.get_pixelv(point))
	for y in range(P):
		for x in range(P):
			var point := Vector2i(x, y)
			var source: Color = joint.get_pixelv(point)
			if source.a <= 0.05:
				continue
			var nearest := 999.0
			for outside_point: Vector2i in outside:
				nearest = minf(nearest, Vector2(point).distance_to(Vector2(outside_point)))
			if nearest <= thickness:
				result.set_pixelv(point, source)
	return result

func _solid_tile(mass: Image, border: Image, turn: int) -> Image:
	var tile: Image = mass.duplicate()
	tile.blend_rect(BUILDER.rotate_quarters(border, turn), Rect2i(0, 0, S, S), Vector2i.ZERO)
	return tile

func _compose(mass: Image, border: Image, hole: Image) -> Image:
	var canvas: Image = Image.create(S * 2, S * 2, false, Image.FORMAT_RGBA8)
	canvas.fill(CAVE)
	canvas.blit_rect(mass, Rect2i(0, 0, S, S), Vector2i.ZERO)
	canvas.blit_rect(_solid_tile(mass, border, 2), Rect2i(0, 0, S, S), Vector2i(S, 0))
	canvas.blit_rect(_solid_tile(mass, border, 1), Rect2i(0, 0, S, S), Vector2i(0, S))
	var overlay: Image = Image.create(S * 2, S * 2, false, Image.FORMAT_RGBA8)
	overlay.fill(Color.TRANSPARENT)
	var top_endpoint := -1
	var left_endpoint := -1
	for x in range(P):
		if hole.get_pixel(x, 0).a > 0.05:
			top_endpoint = x
	for y in range(P):
		if hole.get_pixel(0, y).a > 0.05:
			left_endpoint = y
	var top_cut := maxi(0, top_endpoint - 1)
	var left_cut := maxi(0, left_endpoint - 1)
	var depth: int = BUILDER.border_depth(border)
	for y in range(depth):
		for x in range(top_cut):
			overlay.set_pixel(S + x, S - depth + y, mass.get_pixel(x, S - depth + y))
	for y in range(left_cut):
		for x in range(depth):
			overlay.set_pixel(S - depth + x, S + y, mass.get_pixel(S - depth + x, y))
	for y in range(P):
		for x in range(P):
			var color: Color = hole.get_pixel(x, y)
			if color.a > 0.05:
				overlay.set_pixel(S - 1 + x, S - 1 + y, color)
	canvas.blend_rect(overlay, Rect2i(0, 0, S * 2, S * 2), Vector2i.ZERO)
	return canvas

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var mass: Image = _load_image("dark_mass_32.png")
	var border: Image = _load_image("easy_border_top_32.png")
	var joint: Image = _load_image("easy_edge_joint_top_left_32.png")
	var thicknesses: Array[float] = [2.5, 3.5, 4.5, 5.5, 6.5]
	var montage: Image = Image.create(64 * thicknesses.size(), 64, false, Image.FORMAT_RGBA8)
	montage.fill(Color.WHITE)
	for index in range(thicknesses.size()):
		var thickness: float = thicknesses[index]
		var hole: Image = _make_hole(mass, joint, thickness)
		hole.save_png(OUT_DIR + "/hole_%.1f.png" % thickness)
		var candidate: Image = _compose(mass, border, hole)
		candidate.save_png(OUT_DIR + "/composite_%.1f.png" % thickness)
		montage.blit_rect(candidate, Rect2i(0, 0, 64, 64), Vector2i(index * 64, 0))
	montage.resize(montage.get_width() * 8, montage.get_height() * 8, Image.INTERPOLATE_NEAREST)
	montage.save_png(OUT_DIR + "/montage_8x.png")
	print("Clean Hole Corner bands: 2.5 / 3.5 / 4.5 / 5.5 / 6.5")
	get_tree().quit()
