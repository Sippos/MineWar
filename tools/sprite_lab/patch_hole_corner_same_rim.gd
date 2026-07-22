extends Node

const BUILDER_PATH := "res://tools/sprite_lab/dome_corner_builder.gd"
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const TIERS: Array[String] = ["easy", "medium", "hard"]

func _ready() -> void:
	var text := FileAccess.get_file_as_string(BUILDER_PATH)
	var start := text.find("static func make_hole_corner_top_left(")
	var finish := text.find("\nstatic func make_cave_corner_top_left", start)
	if start < 0 or finish < 0:
		push_error("Could not locate Hole Corner builder")
		get_tree().quit(1)
		return

	var replacement := '''static func make_hole_corner_top_left(mass_image: Image, top_border: Image, edge_joint: Image = null) -> Image:
	## Opposite topology of Edge Joint, but with the EXACT SAME authored rim.
	## Only the two regions swap: the top-left cave region becomes rock, while
	## the deep down-right rock interior becomes transparent cave.
	var joint: Image = edge_joint
	if joint == null or joint.is_empty():
		joint = make_edge_joint_top_left(mass_image, top_border)
	joint = joint.duplicate()
	joint.convert(Image.FORMAT_RGBA8)
	if joint.get_width() != LOGICAL_SIZE or joint.get_height() != LOGICAL_SIZE:
		joint.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)

	var mass := mass_image.duplicate()
	mass.convert(Image.FORMAT_RGBA8)
	if mass.get_width() != LOGICAL_SIZE or mass.get_height() != LOGICAL_SIZE:
		mass.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)

	# Find only the transparent region connected to the authored top-left origin.
	# Other transparent islands are ignored, preventing stray floating pixels.
	var outside: Dictionary = {}
	var pending: Array[Vector2i] = []
	if joint.get_pixel(0, 0).a <= 0.05:
		pending.append(Vector2i.ZERO)
		outside[Vector2i.ZERO] = true
	while not pending.is_empty():
		var point: Vector2i = pending.pop_front()
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = point + direction
			if next.x < 0 or next.y < 0 or next.x >= CORNER_EDIT_SIZE or next.y >= CORNER_EDIT_SIZE:
				continue
			if outside.has(next) or joint.get_pixelv(next).a > 0.05:
				continue
			outside[next] = true
			pending.append(next)

	var result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)

	# The formerly empty top-left side is now the solid dark mass.
	for point_value: Variant in outside.keys():
		var point := point_value as Vector2i
		result.set_pixelv(point, mass.get_pixelv(point))

	# Preserve the exact authored Edge Joint rim pixels at identical coordinates.
	# Interior pixels matching the normal mass are omitted so they become cave.
	for y in range(CORNER_EDIT_SIZE):
		for x in range(CORNER_EDIT_SIZE):
			var point := Vector2i(x, y)
			var joint_color := joint.get_pixelv(point)
			if joint_color.a <= 0.05:
				continue
			var mass_color := mass.get_pixelv(point)
			var color_delta := absf(joint_color.r - mass_color.r) + absf(joint_color.g - mass_color.g) + absf(joint_color.b - mass_color.b)
			var touches_outside := false
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if outside.has(point + Vector2i(ox, oy)):
						touches_outside = true
			if touches_outside or color_delta > 0.035:
				result.set_pixelv(point, joint_color)
	return result
'''

	text = text.substr(0, start) + replacement + text.substr(finish)
	var file := FileAccess.open(BUILDER_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write builder")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()

	# Rebuild all current editable Hole Corner sources from their matching Edge Joint.
	var builder = load(BUILDER_PATH)
	var mass := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/dark_mass_32.png"))
	if mass == null or mass.is_empty():
		push_error("Could not load dark mass")
		get_tree().quit(1)
		return
	mass.convert(Image.FORMAT_RGBA8)
	for tier in TIERS:
		var border := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/%s_border_top_32.png" % tier))
		var edge := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % tier))
		if border == null or edge == null or border.is_empty() or edge.is_empty():
			push_error("Missing source art for %s" % tier)
			get_tree().quit(1)
			return
		border.convert(Image.FORMAT_RGBA8)
		edge.convert(Image.FORMAT_RGBA8)
		var hole: Image = builder.make_hole_corner_top_left(mass, border, edge)
		var result := hole.save_png(SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier)
		if result != OK:
			push_error("Could not save %s Hole Corner" % tier)
			get_tree().quit(1)
			return
	# Unmineable mirrors Easy visually.
	var easy_hole := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/easy_hole_corner_top_left_32.png"))
	if easy_hole != null and not easy_hole.is_empty():
		easy_hole.save_png(SOURCE_DIR + "/unmineable_hole_corner_top_left_32.png")
	print("Hole Corner rebuilt with the exact Edge Joint rim and opposite rock/cave regions")
	get_tree().quit()
