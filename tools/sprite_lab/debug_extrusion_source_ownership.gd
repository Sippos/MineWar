extends Node

const PREVIEW = preload("res://tools/sprite_lab/dome_material_preview_v2.gd")
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const CELL_SIZE := 32
const MAP_SIZE := Vector2i(12, 8)

func _load(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)
	image.resize(32, 32, Image.INTERPOLATE_NEAREST)
	return image

func _cell_id(cell: Vector2i) -> int:
	return cell.y * MAP_SIZE.x + cell.x

func _write(image: Image, origin: Vector2i, cell: Vector2i, width: int, height: int, solid: PackedByteArray, owners: PackedInt32Array) -> void:
	for iy in range(image.get_height()):
		var wy: int = origin.y + iy
		if wy < 0 or wy >= height:
			continue
		for ix in range(image.get_width()):
			var wx: int = origin.x + ix
			if wx < 0 or wx >= width or image.get_pixel(ix, iy).a <= 0.05:
				continue
			var index: int = wy * width + wx
			solid[index] = 255
			owners[index] = _cell_id(cell)

func _ready() -> void:
	var preview := PREVIEW.new() as Control
	add_child(preview)
	await get_tree().process_frame
	var mass := _load(SOURCE_DIR + "/dark_mass_32.png")
	var borders := {}
	var corners := {}
	var joints := {}
	var fronts := {}
	for tier in ["unmineable", "easy", "medium", "hard"]:
		borders[tier] = _load(SOURCE_DIR + "/%s_border_top_32.png" % tier)
		corners[tier] = _load(SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier)
		joints[tier] = _load(SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % tier)
		fronts[tier] = _load(SOURCE_DIR + "/%s_front_face_32.png" % tier)
	preview.call("set_material_library", mass, borders, corners, joints, fronts)
	preview.call("set_front_depth", 32)

	var width: int = MAP_SIZE.x * CELL_SIZE
	var height: int = MAP_SIZE.y * CELL_SIZE
	var solid := PackedByteArray()
	solid.resize(width * height)
	solid.fill(0)
	var source_cells := PackedInt32Array()
	source_cells.resize(width * height)
	source_cells.fill(-1)

	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			var cell_type := int(preview.call("_cell_type", cell))
			if cell_type == 0:
				continue
			var images := preview.call("_images_for_cell", cell_type) as Array
			var mask := int(preview.call("_exposure_mask", cell))
			if mask < images.size():
				_write(images[mask] as Image, cell * CELL_SIZE, cell, width, height, solid, source_cells)

	var rules := [
		[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],
		[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],
		[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],
		[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],
	]
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var empty_cell := Vector2i(x, y)
			if bool(preview.call("_is_solid", empty_cell)):
				continue
			var rect := Rect2(Vector2(empty_cell * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))
			for rule in rules:
				var first: Vector2i = rule[0]
				var second: Vector2i = rule[1]
				var diagonal: Vector2i = rule[2]
				var frame: int = rule[3]
				if not bool(preview.call("_is_solid", empty_cell + first)) or not bool(preview.call("_is_solid", empty_cell + second)) or not bool(preview.call("_is_solid", empty_cell + diagonal)):
					continue
				var owner_cell := empty_cell + diagonal
				var owner_type := int(preview.call("_cell_type", owner_cell))
				var hole_images := preview.call("_corner_images_for_cell", owner_type) as Array
				if frame >= hole_images.size():
					continue
				var patch_rect := preview.call("_hole_corner_patch_rect", rect, frame) as Rect2
				_write(hole_images[frame] as Image, Vector2i(roundi(patch_rect.position.x), roundi(patch_rect.position.y)), owner_cell, width, height, solid, source_cells)

	for face_cell in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)]:
		var counts := {}
		var own_count := 0
		var other_count := 0
		var none_count := 0
		var face_y: int = (face_cell.y + 1) * CELL_SIZE
		for distance in range(32):
			var wy: int = face_y + distance
			for lx in range(CELL_SIZE):
				var wx: int = face_cell.x * CELL_SIZE + lx
				var source_id := -1
				for step in range(1, 33):
					var sy: int = wy - step
					if sy < 0:
						break
					var idx: int = sy * width + wx
					if solid[idx] != 0:
						source_id = source_cells[idx]
						break
				if source_id == -1:
					none_count += 1
				else:
					counts[source_id] = int(counts.get(source_id, 0)) + 1
					if source_id == _cell_id(face_cell):
						own_count += 1
					else:
						other_count += 1
		print("FACE=", face_cell, " OWN=", own_count, " OTHER=", other_count, " NONE=", none_count, " COUNTS=", counts)
	get_tree().quit(0)
