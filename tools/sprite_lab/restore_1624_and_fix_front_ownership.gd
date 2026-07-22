extends Node

const SNAPSHOT_ROOT := "res://tools/sprite_lab/safestates/dome_workbench_2_5d_locked_2026-07-20_1624"
const PREVIEW_SNAPSHOT := SNAPSHOT_ROOT + "/tools/sprite_lab/dome_material_preview_v2.gd"
const RUNTIME_SNAPSHOT := SNAPSHOT_ROOT + "/scripts/systems/world_generation/dome_front_extrusion_renderer.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const RUNTIME_PATH := "res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd"

func _replace_function(text: String, function_name: String, replacement: String) -> String:
	var marker := "func %s(" % function_name
	var start := text.find(marker)
	if start < 0:
		push_error("Missing function in restored preview: " + function_name)
		return ""
	var next := text.find("\nfunc ", start + marker.length())
	if next < 0:
		next = text.length()
	return text.substr(0, start) + replacement.strip_edges(false, true) + "\n\n" + text.substr(next + 1)

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + path)
		return false
	file.store_string(text)
	file.close()
	return true

func _ready() -> void:
	var preview := FileAccess.get_file_as_string(PREVIEW_SNAPSHOT)
	var runtime := FileAccess.get_file_as_string(RUNTIME_SNAPSHOT)
	if preview.is_empty() or runtime.is_empty():
		push_error("Could not read the locked 16:24 safestate")
		get_tree().quit(1)
		return

	var build_replacement := '''func _cell_source_id(cell: Vector2i) -> int:
	return cell.y * MAP_SIZE.x + cell.x

func _write_owned_mask_image(image: Image, origin: Vector2i, owner_type: int, source_cell: Vector2i, width: int, height: int, solid: PackedByteArray, owners: PackedInt32Array, source_cells: PackedInt32Array) -> void:
	var source_id := _cell_source_id(source_cell)
	for image_y in range(image.get_height()):
		var world_y := origin.y + image_y
		if world_y < 0 or world_y >= height:
			continue
		for image_x in range(image.get_width()):
			var world_x := origin.x + image_x
			if world_x < 0 or world_x >= width:
				continue
			if image.get_pixel(image_x, image_y).a <= 0.05:
				continue
			var index := world_y * width + world_x
			solid[index] = 255
			owners[index] = owner_type
			source_cells[index] = source_id

func _build_silhouette_data() -> Dictionary:
	var width := MAP_SIZE.x * CELL_SIZE
	var height := MAP_SIZE.y * CELL_SIZE
	var pixel_count := width * height
	var solid := PackedByteArray()
	solid.resize(pixel_count)
	solid.fill(0)
	var owners := PackedInt32Array()
	owners.resize(pixel_count)
	owners.fill(CellType.EMPTY)
	var source_cells := PackedInt32Array()
	source_cells.resize(pixel_count)
	source_cells.fill(-1)

	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			var cell_type := _cell_type(cell)
			if cell_type == CellType.EMPTY:
				continue
			var images := _images_for_cell(cell_type)
			var mask := _exposure_mask(cell)
			if mask < images.size():
				_write_owned_mask_image(images[mask] as Image, cell * CELL_SIZE, cell_type, cell, width, height, solid, owners, source_cells)

	var rules := [
		[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],
		[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],
		[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],
		[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],
	]
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var empty_cell := Vector2i(x, y)
			if _is_solid(empty_cell):
				continue
			var rect := _cell_rect(empty_cell)
			for rule_value: Variant in rules:
				var rule: Array = rule_value
				var first: Vector2i = rule[0]
				var second: Vector2i = rule[1]
				var diagonal: Vector2i = rule[2]
				var frame: int = rule[3]
				if not _is_solid(empty_cell + first) or not _is_solid(empty_cell + second) or not _is_solid(empty_cell + diagonal):
					continue
				var source_cell := empty_cell + diagonal
				var owner_type := _cell_type(source_cell)
				var hole_images := _corner_images_for_cell(owner_type)
				if frame >= hole_images.size():
					continue
				var patch_rect := _hole_corner_patch_rect(rect, frame)
				_write_owned_mask_image(hole_images[frame] as Image, Vector2i(roundi(patch_rect.position.x), roundi(patch_rect.position.y)), owner_type, source_cell, width, height, solid, owners, source_cells)

	return {"width": width, "height": height, "solid": solid, "owners": owners, "source_cells": source_cells}
'''
	preview = _replace_function(preview, "_build_silhouette_data", build_replacement)
	if preview.is_empty():
		get_tree().quit(1)
		return

	var extrusion_replacement := '''func _rebuild_extrusion_texture() -> void:
	extrusion_dirty = false
	if not show_front_faces or mass_image == null:
		extrusion_texture = null
		return
	var data := _build_silhouette_data()
	var width: int = data["width"]
	var height: int = data["height"]
	var solid: PackedByteArray = data["solid"]
	var owners: PackedInt32Array = data["owners"]
	var source_cells: PackedInt32Array = data["source_cells"]
	var result := Image.create(width, height, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)

	# Exact locked 16:24 extrusion everywhere by default.
	for y in range(height):
		for x in range(width):
			var index := y * width + x
			if solid[index] != 0:
				continue
			var owner_type := CellType.EMPTY
			var distance := 0
			for step in range(1, front_depth + 1):
				var source_y := y - step
				if source_y < 0:
					break
				var source_index := source_y * width + x
				if solid[source_index] != 0:
					owner_type = owners[source_index]
					distance = step
					break
			if owner_type != CellType.EMPTY:
				result.set_pixel(x, y, _sample_front_color(owner_type, x, distance))

	# Surgical ownership correction: within a downward face, only that block's
	# own silhouette may create the projection. The original mask, curve, Hole
	# Corners and draw order remain unchanged.
	for cell_y in range(MAP_SIZE.y):
		for cell_x in range(MAP_SIZE.x):
			var cell := Vector2i(cell_x, cell_y)
			var owner_type := _cell_type(cell)
			if owner_type == CellType.EMPTY or _is_solid(cell + Vector2i.DOWN):
				continue
			var wanted_source := _cell_source_id(cell)
			var origin_x := cell_x * CELL_SIZE
			var face_y := (cell_y + 1) * CELL_SIZE
			for distance_index in range(front_depth):
				var world_y := face_y + distance_index
				if world_y < 0 or world_y >= height:
					break
				for local_x in range(CELL_SIZE):
					var world_x := origin_x + local_x
					if world_x < 0 or world_x >= width:
						continue
					result.set_pixel(world_x, world_y, Color.TRANSPARENT)
					var own_distance := 0
					for step in range(1, front_depth + 1):
						var source_y := world_y - step
						if source_y < 0:
							break
						var source_index := source_y * width + world_x
						if solid[source_index] != 0 and source_cells[source_index] == wanted_source:
							own_distance = step
							break
					if own_distance > 0:
						result.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, own_distance))
	extrusion_texture = ImageTexture.create_from_image(result)
'''
	preview = _replace_function(preview, "_rebuild_extrusion_texture", extrusion_replacement)
	if preview.is_empty():
		get_tree().quit(1)
		return

	if not _write(PREVIEW_PATH, preview) or not _write(RUNTIME_PATH, runtime):
		get_tree().quit(1)
		return
	print("RESTORED_1624_AND_FIXED_FRONT_SOURCE_OWNERSHIP")
	get_tree().quit(0)
