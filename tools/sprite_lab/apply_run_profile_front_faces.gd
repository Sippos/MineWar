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
	var preview_replacement := '''func _front_profile_limit(pixel_x: int, total_width: int, depth_value: int) -> int:
	# One continuous bowed lower contour across the complete exposed run.
	# The first rows remain full width; the sides finish earlier while the
	# centre reaches the requested depth.
	if total_width <= 1 or depth_value <= 1:
		return maxi(depth_value, 1)
	var t := clampf(float(pixel_x) / float(total_width - 1), 0.0, 1.0)
	var edge_distance := absf(t * 2.0 - 1.0)
	var curve_height := clampi(roundi(float(depth_value) * 0.45), 2, maxi(depth_value - 1, 2))
	var lift := roundi(float(curve_height) * pow(edge_distance, 1.65))
	return maxi(1, depth_value - lift)

func _rebuild_extrusion_texture() -> void:
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

	# Background pass keeps rounded side-wall depth and the outer cave contour.
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

	# Replace each contiguous downward-facing run with one continuous profile.
	# This keeps the top complete, but bows the entire lower edge instead of
	# merely cutting the two corner pixels.
	for cell_y in range(MAP_SIZE.y):
		var cell_x := 0
		while cell_x < MAP_SIZE.x:
			var candidate := Vector2i(cell_x, cell_y)
			if not _is_solid(candidate) or _is_solid(candidate + Vector2i.DOWN):
				cell_x += 1
				continue
			var run_start := cell_x
			while cell_x < MAP_SIZE.x:
				var run_cell := Vector2i(cell_x, cell_y)
				if not _is_solid(run_cell) or _is_solid(run_cell + Vector2i.DOWN):
					break
				cell_x += 1
			var run_end := cell_x
			var run_width := (run_end - run_start) * CELL_SIZE
			var face_x := run_start * CELL_SIZE
			var face_y := (cell_y + 1) * CELL_SIZE

			# Clear the old rectangular/side-derived face only inside this run.
			for distance in range(1, front_depth + 1):
				var world_y := face_y + distance - 1
				if world_y < 0 or world_y >= height:
					break
				for run_x in range(run_width):
					var world_x := face_x + run_x
					if world_x < 0 or world_x >= width:
						continue
					var topology_cell := Vector2i(world_x / CELL_SIZE, world_y / CELL_SIZE)
					if not _is_solid(topology_cell):
						result.set_pixel(world_x, world_y, Color.TRANSPARENT)

			# Draw the run-wide curved profile. Material ownership still follows
			# the individual block above each horizontal pixel.
			for run_x in range(run_width):
				var world_x := face_x + run_x
				if world_x < 0 or world_x >= width:
					continue
				var owner_cell_x := run_start + int(run_x / CELL_SIZE)
				var owner_type := _cell_type(Vector2i(owner_cell_x, cell_y))
				var profile_depth := _front_profile_limit(run_x, run_width, front_depth)
				for distance in range(1, profile_depth + 1):
					var world_y := face_y + distance - 1
					if world_y < 0 or world_y >= height:
						break
					var topology_cell := Vector2i(world_x / CELL_SIZE, world_y / CELL_SIZE)
					if _is_solid(topology_cell):
						continue
					result.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, distance))
	extrusion_texture = ImageTexture.create_from_image(result)
'''
	preview = _replace_function(preview, "_rebuild_extrusion_texture", preview_replacement)
	if not _write(PREVIEW_PATH, preview):
		get_tree().quit(1)
		return

	var runtime := FileAccess.get_file_as_string(RUNTIME_PATH)
	var refresh_replacement := '''func _is_bottom_open(cell: Vector2i) -> bool:
	return _is_solid(cell) and not _is_solid(cell + Vector2i.DOWN)

func _front_run_bounds(cell: Vector2i) -> Vector2i:
	var left := cell.x
	var right := cell.x
	while _is_bottom_open(Vector2i(left - 1, cell.y)):
		left -= 1
	while _is_bottom_open(Vector2i(right + 1, cell.y)):
		right += 1
	return Vector2i(left, right)

func _front_profile_limit(pixel_x: int, total_width: int, depth_value: int) -> int:
	if total_width <= 1 or depth_value <= 1:
		return maxi(depth_value, 1)
	var t := clampf(float(pixel_x) / float(total_width - 1), 0.0, 1.0)
	var edge_distance := absf(t * 2.0 - 1.0)
	var curve_height := clampi(roundi(float(depth_value) * 0.45), 2, maxi(depth_value - 1, 2))
	var lift := roundi(float(curve_height) * pow(edge_distance, 1.65))
	return maxi(1, depth_value - lift)

func refresh_around(cell: Vector2i) -> void:
	if block_layer == null:
		return
	# A changed block can alter the continuous profile of its whole horizontal
	# run, so refresh the affected rows rather than only the nearest 3x3 cells.
	var rect := block_layer.get_used_rect().grow(1)
	for row_y in range(cell.y - 1, cell.y + 2):
		for x in range(rect.position.x, rect.end.x):
			_refresh_cell(Vector2i(x, row_y))
'''
	runtime = _replace_function(runtime, "refresh_around", refresh_replacement)
	var refresh_cell_replacement := '''func _refresh_cell(cell: Vector2i) -> void:
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
	var bounds := _front_run_bounds(cell)
	var run_index := cell.x - bounds.x
	var run_cells := bounds.y - bounds.x + 1
	var image := _build_extrusion_image(source_id, _exposure_mask(cell), run_index, run_cells)
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
	runtime = _replace_function(runtime, "_refresh_cell", refresh_cell_replacement)
	var build_replacement := '''func _build_extrusion_image(source_id: int, mask: int, run_index: int = 0, run_cells: int = 1) -> Image:
	var atlas := atlas_images[source_id] as Image
	var front := front_images[source_id] as Image
	var atlas_position := Vector2i(mask % 4, mask / 4) * TILE_SIZE
	var tile := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	tile.fill(Color.TRANSPARENT)
	tile.blit_rect(atlas, Rect2i(atlas_position, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i.ZERO)
	var result := Image.create(TILE_SIZE, TILE_SIZE + depth, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)

	# Preserve rounded side-wall projection behind the main face.
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

	# Clear that background inside the downward face, then redraw this tile's
	# section of the run-wide bowed profile.
	for distance in range(1, depth + 1):
		var y := TILE_SIZE + distance - 1
		for x in range(TILE_SIZE):
			result.set_pixel(x, y, Color.TRANSPARENT)

	var total_width := maxi(run_cells, 1) * TILE_SIZE
	for x in range(TILE_SIZE):
		var run_x := run_index * TILE_SIZE + x
		var profile_depth := _front_profile_limit(run_x, total_width, depth)
		for distance in range(1, profile_depth + 1):
			var y := TILE_SIZE + distance - 1
			var sample_y := clampi(roundi(float(distance - 1) * float(TILE_SIZE - 1) / float(maxi(depth - 1, 1))), 0, TILE_SIZE - 1)
			var depth_ratio := 0.0 if depth <= 1 else float(distance - 1) / float(depth - 1)
			var color := front.get_pixel(x, sample_y)
			color = color.darkened(0.10 + depth_ratio * 0.18)
			color.a = 1.0
			result.set_pixel(x, y, color)
	return result
'''
	runtime = _replace_function(runtime, "_build_extrusion_image", build_replacement)
	if not _write(RUNTIME_PATH, runtime):
		get_tree().quit(1)
		return
	print("Continuous run-wide bowed front masks installed in preview and runtime")
	get_tree().quit(0)
