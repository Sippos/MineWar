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
	var preview_replacement := '''func _bottom_profile(tile: Image) -> PackedInt32Array:
	var profile := PackedInt32Array()
	profile.resize(CELL_SIZE)
	profile.fill(-1)
	for x in range(CELL_SIZE):
		for y in range(CELL_SIZE - 1, -1, -1):
			if tile.get_pixel(x, y).a > 0.05:
				profile[x] = y
				break
	return profile

func _rebuild_extrusion_texture() -> void:
	extrusion_dirty = false
	if not show_front_faces or mass_image == null:
		extrusion_texture = null
		return
	var width := MAP_SIZE.x * CELL_SIZE
	var height := MAP_SIZE.y * CELL_SIZE
	var result := Image.create(width, height, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)

	# Each downward-open tile owns one front wall. For every horizontal pixel,
	# find the tile's actual lower terrain boundary and translate that boundary
	# downward by exactly front_depth. This gives constant wall thickness and an
	# identical upper/lower contour without modifying any terrain mask asset.
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
			var profile := _bottom_profile(tile)
			var origin_x := cell_x * CELL_SIZE
			var origin_y := cell_y * CELL_SIZE
			for local_x in range(CELL_SIZE):
				var boundary_y := profile[local_x]
				if boundary_y < 0:
					continue
				var world_x := origin_x + local_x
				if world_x < 0 or world_x >= width:
					continue
				for distance in range(1, front_depth + 1):
					var world_y := origin_y + boundary_y + distance
					if world_y < 0 or world_y >= height:
						break
					result.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, distance))
	extrusion_texture = ImageTexture.create_from_image(result)
'''
	preview = _replace_function(preview, "_rebuild_extrusion_texture", preview_replacement)
	if not _write(PREVIEW_PATH, preview):
		get_tree().quit(1)
		return

	var runtime := FileAccess.get_file_as_string(RUNTIME_PATH)
	var runtime_replacement := '''func _bottom_profile(tile: Image) -> PackedInt32Array:
	var profile := PackedInt32Array()
	profile.resize(TILE_SIZE)
	profile.fill(-1)
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE - 1, -1, -1):
			if tile.get_pixel(x, y).a > 0.05:
				profile[x] = y
				break
	return profile

func _build_extrusion_image(source_id: int, mask: int) -> Image:
	var atlas := atlas_images[source_id] as Image
	var front := front_images[source_id] as Image
	var atlas_position := Vector2i(mask % 4, mask / 4) * TILE_SIZE
	var tile := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	tile.fill(Color.TRANSPARENT)
	tile.blit_rect(atlas, Rect2i(atlas_position, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i.ZERO)
	var result := Image.create(TILE_SIZE, TILE_SIZE + depth, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var profile := _bottom_profile(tile)

	# Translate the tile's exact lower boundary downward. The lower edge is the
	# same contour as the upper edge, merely shifted by depth pixels.
	for x in range(TILE_SIZE):
		var boundary_y := profile[x]
		if boundary_y < 0:
			continue
		for distance in range(1, depth + 1):
			var y := boundary_y + distance
			if y < 0 or y >= result.get_height():
				break
			var sample_y := clampi(roundi(float(distance - 1) * float(TILE_SIZE - 1) / float(maxi(depth - 1, 1))), 0, TILE_SIZE - 1)
			var color := front.get_pixel(x, sample_y)
			var depth_ratio := 0.0 if depth <= 1 else float(distance - 1) / float(depth - 1)
			color = color.darkened(0.10 + depth_ratio * 0.18)
			color.a = 1.0
			result.set_pixel(x, y, color)
	return result
'''
	runtime = _replace_function(runtime, "_build_extrusion_image", runtime_replacement)
	if not _write(RUNTIME_PATH, runtime):
		get_tree().quit(1)
		return
	print("TRANSLATED_FRONT_CONTOURS_APPLIED")
	get_tree().quit(0)
