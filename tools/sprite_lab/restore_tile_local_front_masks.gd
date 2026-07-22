extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const RUNTIME_PATH := "res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd"

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
	var preview_helper := '''func _front_mask_source_y(distance: int, depth_value: int, image_size: int) -> int:
	if depth_value <= 1:
		return image_size - 1
	return clampi(roundi(float(distance - 1) * float(image_size - 1) / float(depth_value - 1)), 0, image_size - 1)
'''
	preview = _replace_function(preview, "_front_profile_limit", preview_helper)
	var preview_rebuild := '''func _rebuild_extrusion_texture() -> void:
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

	# General rounded extrusion remains as a background for vertical cave walls.
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

	# Every downward-facing block then owns its own face rectangle. Clear any
	# neighbouring side-wall projection first, and redraw only through THIS
	# block's composite alpha mask sampled from top to bottom. This restores the
	# original warped left/right edges without allowing adjacent side tiles to
	# bite into the face.
	for cell_y in range(MAP_SIZE.y):
		for cell_x in range(MAP_SIZE.x):
			var cell := Vector2i(cell_x, cell_y)
			var owner_type := _cell_type(cell)
			if owner_type == CellType.EMPTY or _is_solid(cell + Vector2i.DOWN):
				continue
			var images := _images_for_cell(owner_type)
			var mask := _exposure_mask(cell)
			if mask >= images.size():
				continue
			var face_mask := images[mask] as Image
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
					if not _is_solid(topology_cell):
						result.set_pixel(world_x, world_y, Color.TRANSPARENT)

			for distance in range(1, front_depth + 1):
				var world_y := face_y + distance - 1
				if world_y < 0 or world_y >= height:
					break
				var mask_y := _front_mask_source_y(distance, front_depth, CELL_SIZE)
				for local_x in range(CELL_SIZE):
					if face_mask.get_pixel(local_x, mask_y).a <= 0.05:
						continue
					var world_x := face_x + local_x
					if world_x < 0 or world_x >= width:
						continue
					var topology_cell := Vector2i(world_x / CELL_SIZE, world_y / CELL_SIZE)
					if _is_solid(topology_cell):
						continue
					result.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, distance))
	extrusion_texture = ImageTexture.create_from_image(result)
'''
	preview = _replace_function(preview, "_rebuild_extrusion_texture", preview_rebuild)
	if not _write(PREVIEW_PATH, preview):
		get_tree().quit(1)
		return

	var runtime := FileAccess.get_file_as_string(RUNTIME_PATH)
	var runtime_helper := '''func _front_mask_source_y(distance: int, depth_value: int) -> int:
	if depth_value <= 1:
		return TILE_SIZE - 1
	return clampi(roundi(float(distance - 1) * float(TILE_SIZE - 1) / float(depth_value - 1)), 0, TILE_SIZE - 1)
'''
	runtime = _replace_function(runtime, "_front_profile_limit", runtime_helper)
	var refresh_around := '''func refresh_around(cell: Vector2i) -> void:
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			_refresh_cell(cell + Vector2i(ox, oy))
'''
	runtime = _replace_function(runtime, "refresh_around", refresh_around)
	var refresh_cell := '''func _refresh_cell(cell: Vector2i) -> void:
	if block_layer == null:
		return
	var raw_source_id := block_layer.get_cell_source_id(cell)
	if raw_source_id == -1 or not _is_bottom_open(cell):
		_remove_cell(cell)
		return
	var source_id := _canonical_source_id(raw_source_id)
	if not atlas_images.has(source_id) or not front_images.has(source_id):
		_remove_cell(cell)
		return
	var image := _build_extrusion_image(source_id, _exposure_mask(cell))
	if image == null or image.is_empty():
		_remove_cell(cell)
		return
	var key := _sprite_key(cell)
	var sprite := sprites.get(key) as Sprite2D
	if not is_instance_valid(sprite):
		sprite = Sprite2D.new()
		sprite.name = "FrontExtrusion_%d_%d" % [cell.x, cell.y]
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		sprites[key] = sprite
	sprite.texture = ImageTexture.create_from_image(image)
	var center_local := block_layer.map_to_local(cell)
	var top_left_global := block_layer.to_global(center_local - Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5))
	sprite.position = to_local(top_left_global)
	sprite.visible = true
'''
	runtime = _replace_function(runtime, "_refresh_cell", refresh_cell)
	var build_image := '''func _build_extrusion_image(source_id: int, mask: int, _run_index: int = 0, _run_cells: int = 1) -> Image:
	var atlas := atlas_images[source_id] as Image
	var front := front_images[source_id] as Image
	var atlas_position := Vector2i(mask % 4, mask / 4) * TILE_SIZE
	var tile := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	tile.fill(Color.TRANSPARENT)
	tile.blit_rect(atlas, Rect2i(atlas_position, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i.ZERO)
	var result := Image.create(TILE_SIZE, TILE_SIZE + depth, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)

	# Keep the tile-local rounded projection above/behind the face.
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

	# Clear the complete face area, then redraw it through this tile's own alpha
	# mask sampled from top to bottom. Neighbouring side tiles never participate.
	for distance in range(1, depth + 1):
		var y := TILE_SIZE + distance - 1
		for x in range(TILE_SIZE):
			result.set_pixel(x, y, Color.TRANSPARENT)

	for distance in range(1, depth + 1):
		var y := TILE_SIZE + distance - 1
		var mask_y := _front_mask_source_y(distance, depth)
		var sample_y := mask_y
		var depth_ratio := 0.0 if depth <= 1 else float(distance - 1) / float(depth - 1)
		for x in range(TILE_SIZE):
			if tile.get_pixel(x, mask_y).a <= 0.05:
				continue
			var color := front.get_pixel(x, sample_y)
			color = color.darkened(0.10 + depth_ratio * 0.18)
			color.a = 1.0
			result.set_pixel(x, y, color)
	return result
'''
	runtime = _replace_function(runtime, "_build_extrusion_image", build_image)
	if not _write(RUNTIME_PATH, runtime):
		get_tree().quit(1)
		return
	print("Restored tile-local left/right front masks without side-tile overlap")
	get_tree().quit(0)
