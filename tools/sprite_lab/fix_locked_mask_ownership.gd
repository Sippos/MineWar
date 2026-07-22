extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"

func _replace_function(text: String, function_name: String, replacement: String) -> String:
	var marker := "func %s(" % function_name
	var start := text.find(marker)
	if start < 0:
		push_error("Missing function: " + function_name)
		return text
	var next := text.find("\nfunc ", start + marker.length())
	if next < 0:
		next = text.length()
	return text.substr(0, start) + replacement.strip_edges(false, true) + "\n\n" + text.substr(next + 1)

func _write(path: String, content: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	file.close()
	return OK

func _ready() -> void:
	var preview := FileAccess.get_file_as_string(PREVIEW_PATH)
	var replacement := '''func _rebuild_extrusion_texture() -> void:
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

	# Preserve the exact locked 16:24 silhouette extrusion. This remains the
	# background projection for the rounded cave outline and side walls.
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

	# Ownership correction only: a downward-facing block redraws its face from
	# ITS OWN composite atlas frame. First clear the global side-wall projection
	# inside this cell-width face, then apply the same shift/subtract mask used
	# by the locked runtime renderer. The mask shape itself is unchanged.
	for cell_y in range(MAP_SIZE.y):
		for cell_x in range(MAP_SIZE.x):
			var cell := Vector2i(cell_x, cell_y)
			var owner_type := _cell_type(cell)
			if owner_type == CellType.EMPTY or _is_solid(cell + Vector2i.DOWN):
				continue
			var images := _images_for_cell(owner_type)
			var mask := _exposure_mask(cell)
			if mask < 0 or mask >= images.size():
				continue
			var tile := images[mask] as Image
			if tile == null or tile.is_empty():
				continue
			var origin_x := cell_x * CELL_SIZE
			var origin_y := cell_y * CELL_SIZE

			# Remove only the overlapping projection in the downward face area.
			for distance in range(1, front_depth + 1):
				var world_y := origin_y + CELL_SIZE + distance - 1
				if world_y < 0 or world_y >= height:
					break
				for local_x in range(CELL_SIZE):
					var world_x := origin_x + local_x
					if world_x >= 0 and world_x < width:
						result.set_pixel(world_x, world_y, Color.TRANSPARENT)

			# Repaint the face from this tile's exact locked alpha mask.
			for distance in range(1, front_depth + 1):
				var local_y := CELL_SIZE + distance - 1
				var source_y := local_y - front_depth
				if source_y < 0 or source_y >= CELL_SIZE:
					continue
				var world_y := origin_y + local_y
				if world_y < 0 or world_y >= height:
					continue
				for local_x in range(CELL_SIZE):
					if tile.get_pixel(local_x, source_y).a <= 0.05:
						continue
					var world_x := origin_x + local_x
					if world_x < 0 or world_x >= width:
						continue
					result.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, distance))
	extrusion_texture = ImageTexture.create_from_image(result)
'''
	preview = _replace_function(preview, "_rebuild_extrusion_texture", replacement)
	var result := _write(PREVIEW_PATH, preview)
	if result != OK:
		push_error("Could not patch preview: %s" % error_string(result))
		get_tree().quit(1)
		return
	print("LOCKED_MASK_OWNERSHIP_FIXED")
	get_tree().quit(0)
