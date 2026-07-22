extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const RUNTIME_PATH := "res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd"

func _replace_once(text: String, old_value: String, new_value: String, label: String) -> String:
	if not text.contains(old_value):
		push_error("Missing patch anchor: " + label)
		return text
	return text.replace(old_value, new_value)

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + path)
		return false
	file.store_string(text)
	file.close()
	return true

func _ready() -> void:
	var preview := FileAccess.get_file_as_string(PREVIEW_PATH)
	var old_preview := '''func _rebuild_extrusion_texture() -> void:
	extrusion_dirty = false
	if not show_front_faces or mass_image == null:
		extrusion_texture = null
		return
	var data := _build_silhouette_data()
	var width: int = data["width"]
	var height: int = data["height"]
	var solid: PackedByteArray = data["solid"]
	var owners: PackedInt32Array = data["owners"]
	var result := Image.create(width, height, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
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
	extrusion_texture = ImageTexture.create_from_image(result)
'''
	var new_preview := '''func _rebuild_extrusion_texture() -> void:
	extrusion_dirty = false
	if not show_front_faces or mass_image == null:
		extrusion_texture = null
		return
	var data := _build_silhouette_data()
	var width: int = data["width"]
	var height: int = data["height"]
	var solid: PackedByteArray = data["solid"]
	var owners: PackedInt32Array = data["owners"]
	var result := Image.create(width, height, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)

	# Pass 1: preserve the rounded silhouette extrusion. This supplies depth on
	# exposed side walls and curved outer contours.
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

	# Pass 2: a downward-open block owns a COMPLETE cell-width front face.
	# The side-border curve may remain behind it, but may never shrink or notch
	# the face. Only actual solid topology blocks the overlay; decorative alpha
	# from neighbouring side rims does not.
	for cell_y in range(MAP_SIZE.y):
		for cell_x in range(MAP_SIZE.x):
			var cell := Vector2i(cell_x, cell_y)
			var owner_type := _cell_type(cell)
			if owner_type == CellType.EMPTY or _is_solid(cell + Vector2i.DOWN):
				continue
			var face_x := cell_x * CELL_SIZE
			var face_y := (cell_y + 1) * CELL_SIZE
			for distance in range(1, front_depth + 1):
				var world_y := face_y + distance - 1
				if world_y < 0 or world_y >= height:
					break
				for local_x in range(CELL_SIZE):
					var world_x := face_x + local_x
					if world_x < 0 or world_x >= width:
						continue
					var topology_cell := Vector2i(world_x / CELL_SIZE, world_y / CELL_SIZE)
					if _is_solid(topology_cell):
						continue
					result.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, distance))
	extrusion_texture = ImageTexture.create_from_image(result)
'''
	preview = _replace_once(preview, old_preview, new_preview, "preview extrusion")
	if not _write(PREVIEW_PATH, preview):
		get_tree().quit(1)
		return

	var runtime := FileAccess.get_file_as_string(RUNTIME_PATH)
	var old_runtime := '''func _build_extrusion_image(source_id: int, mask: int) -> Image:
	var atlas := atlas_images[source_id] as Image
	var front := front_images[source_id] as Image
	var atlas_position := Vector2i(mask % 4, mask / 4) * TILE_SIZE
	var tile := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	tile.fill(Color.TRANSPARENT)
	tile.blit_rect(atlas, Rect2i(atlas_position, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i.ZERO)
	var result := Image.create(TILE_SIZE, TILE_SIZE + depth, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(TILE_SIZE + depth):
		for x in range(TILE_SIZE):
			var shifted_y := y - depth
			if shifted_y < 0 or shifted_y >= TILE_SIZE:
				continue
			if tile.get_pixel(x, shifted_y).a <= 0.05:
				continue
			var original_alpha := tile.get_pixel(x, y).a if y < TILE_SIZE else 0.0
			if original_alpha > 0.05:
				continue
			var sample_y := posmod(y - TILE_SIZE, TILE_SIZE)
			var color := front.get_pixel(x, sample_y)
			var depth_ratio := float(y - TILE_SIZE + 1) / float(maxi(depth, 1))
			color = color.darkened(0.10 + depth_ratio * 0.18)
			color.a = 1.0
			result.set_pixel(x, y, color)
	return result
'''
	var new_runtime := '''func _build_extrusion_image(source_id: int, mask: int) -> Image:
	var atlas := atlas_images[source_id] as Image
	var front := front_images[source_id] as Image
	var atlas_position := Vector2i(mask % 4, mask / 4) * TILE_SIZE
	var tile := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	tile.fill(Color.TRANSPARENT)
	tile.blit_rect(atlas, Rect2i(atlas_position, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i.ZERO)
	var result := Image.create(TILE_SIZE, TILE_SIZE + depth, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)

	# Rounded side/outer silhouette depth remains behind the main face.
	for y in range(TILE_SIZE + depth):
		for x in range(TILE_SIZE):
			var shifted_y := y - depth
			if shifted_y < 0 or shifted_y >= TILE_SIZE:
				continue
			if tile.get_pixel(x, shifted_y).a <= 0.05:
				continue
			var original_alpha := tile.get_pixel(x, y).a if y < TILE_SIZE else 0.0
			if original_alpha > 0.05:
				continue
			var sample_y := clampi(y - TILE_SIZE, 0, TILE_SIZE - 1)
			var color := front.get_pixel(x, sample_y)
			var depth_ratio := float(maxi(y - TILE_SIZE + 1, 1)) / float(maxi(depth, 1))
			color = color.darkened(0.10 + depth_ratio * 0.18)
			color.a = 1.0
			result.set_pixel(x, y, color)

	# The downward face is always the complete tile width. It is drawn last so
	# a rounded left/right border cannot bite into or shrink the front surface.
	for distance in range(1, depth + 1):
		var y := TILE_SIZE + distance - 1
		var sample_y := clampi(roundi(float(distance - 1) * float(TILE_SIZE - 1) / float(maxi(depth - 1, 1))), 0, TILE_SIZE - 1)
		var depth_ratio := 0.0 if depth <= 1 else float(distance - 1) / float(depth - 1)
		for x in range(TILE_SIZE):
			var color := front.get_pixel(x, sample_y)
			color = color.darkened(0.10 + depth_ratio * 0.18)
			color.a = 1.0
			result.set_pixel(x, y, color)
	return result
'''
	runtime = _replace_once(runtime, old_runtime, new_runtime, "runtime extrusion")
	if not _write(RUNTIME_PATH, runtime):
		get_tree().quit(1)
		return
	print("Full-width front faces now override side-curve notches in preview and runtime")
	get_tree().quit(0)
