extends Node

const BUILDER_PATH := "res://tools/sprite_lab/dome_corner_builder.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(BUILDER_PATH)
	var start := text.find("static func make_hole_corner_top_left(")
	var finish := text.find("static func make_cave_corner_top_left(", start)
	if start < 0 or finish < 0:
		push_error("Could not locate Hole Corner builder function")
		get_tree().quit(1)
		return
	var replacement := '''static func make_hole_corner_top_left(mass_image: Image, top_border: Image, edge_joint: Image = null) -> Image:
	## Build the opposite topology from the exact authored Edge Joint boundary.
	## The old color-difference heuristic preserved unrelated interior pixels,
	## producing the visible hook/stub where Hole Corners met straight borders.
	var joint: Image = edge_joint
	if joint == null or joint.is_empty():
		joint = make_edge_joint_top_left(mass_image, top_border)
	joint = joint.duplicate()
	joint.convert(Image.FORMAT_RGBA8)
	if joint.get_width() != LOGICAL_SIZE or joint.get_height() != LOGICAL_SIZE:
		joint.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)

	var mass: Image = mass_image.duplicate()
	mass.convert(Image.FORMAT_RGBA8)
	if mass.get_width() != LOGICAL_SIZE or mass.get_height() != LOGICAL_SIZE:
		mass.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)

	# Flood-fill only the transparent cave region connected to the authored
	# top-left origin. This is the side that becomes solid in the Hole Corner.
	var outside_lookup: Dictionary = {}
	var outside_points: Array[Vector2i] = []
	var pending: Array[Vector2i] = []
	if joint.get_pixel(0, 0).a <= 0.05:
		outside_lookup[Vector2i.ZERO] = true
		pending.append(Vector2i.ZERO)
	while not pending.is_empty():
		var point: Vector2i = pending.pop_front()
		outside_points.append(point)
		for direction_value: Variant in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var direction: Vector2i = direction_value as Vector2i
			var next_point: Vector2i = point + direction
			if next_point.x < 0 or next_point.y < 0 or next_point.x >= CORNER_EDIT_SIZE or next_point.y >= CORNER_EDIT_SIZE:
				continue
			if outside_lookup.has(next_point) or joint.get_pixelv(next_point).a > 0.05:
				continue
			outside_lookup[next_point] = true
			pending.append(next_point)

	var result: Image = Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for point: Vector2i in outside_points:
		result.set_pixelv(point, mass.get_pixelv(point))

	# Preserve one clean, continuous band of the authored Edge Joint pixels.
	# The distance is derived from the straight border depth, but intentionally
	# excludes deep interior decoration that caused disconnected protrusions.
	var band_thickness: float = maxf(3.5, float(border_depth(top_border)) * 0.42)
	for y in range(CORNER_EDIT_SIZE):
		for x in range(CORNER_EDIT_SIZE):
			var point := Vector2i(x, y)
			var source_color: Color = joint.get_pixelv(point)
			if source_color.a <= 0.05:
				continue
			var nearest_distance := 999.0
			for outside_point: Vector2i in outside_points:
				nearest_distance = minf(nearest_distance, Vector2(point).distance_to(Vector2(outside_point)))
			if nearest_distance <= band_thickness:
				result.set_pixelv(point, source_color)
	return result

'''
	text = text.substr(0, start) + replacement + text.substr(finish)
	var file := FileAccess.open(BUILDER_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write Hole Corner builder")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Hole Corner builder now uses a clean Edge Joint boundary band")
	get_tree().quit()
