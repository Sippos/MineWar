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
	preview = preview.replace(
		"result.set_pixel(world_x, world_y, Color.TRANSPARENT)",
		"result.set_pixel(world_x, world_y, CAVE_COLOR)"
	)
	var draw_replacement := '''func _draw() -> void:
	var full_rect := Rect2(Vector2.ZERO, Vector2(MAP_SIZE.x * CELL_SIZE, MAP_SIZE.y * CELL_SIZE))
	draw_rect(full_rect, CAVE_COLOR)

	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			var cell_type := _cell_type(cell)
			if cell_type == CellType.EMPTY:
				continue
			var mask := _exposure_mask(cell)
			var textures := _textures_for_cell(cell_type)
			if mask < textures.size() and textures[mask] != null:
				draw_texture_rect(textures[mask], _cell_rect(cell), false)
			else:
				draw_rect(_cell_rect(cell), Color.html("211e2dff"))

	# Hole Corners belong behind a downward front face. The extrusion texture
	# contains an opaque cave-colour ownership rectangle, so its transparent
	# curve cutouts cannot reveal these overlays as gray rims.
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var empty_cell := Vector2i(x, y)
			if not _is_solid(empty_cell):
				_draw_hole_corners(empty_cell, _cell_rect(empty_cell))

	if show_front_faces:
		_ensure_extrusion_texture()
		if extrusion_texture != null:
			draw_texture(extrusion_texture, Vector2.ZERO)

	if hovered_cell.x >= 0 and hovered_cell.y >= 0 and hovered_cell.x < MAP_SIZE.x and hovered_cell.y < MAP_SIZE.y:
		draw_rect(_cell_rect(hovered_cell).grow(-2.0), Color(1, 1, 1, 0.42), false, 1.5)
'''
	preview = _replace_function(preview, "_draw", draw_replacement)
	if not _write(PREVIEW_PATH, preview):
		get_tree().quit(1)
		return

	var runtime := FileAccess.get_file_as_string(RUNTIME_PATH)
	if not runtime.contains("const CAVE_OCCLUSION_COLOR"):
		runtime = runtime.replace(
			"const DEFAULT_DEPTH := 10",
			"const DEFAULT_DEPTH := 10\nconst CAVE_OCCLUSION_COLOR := Color(\"111725\")"
		)
	var runtime_replacement := '''func _build_extrusion_image(source_id: int, mask: int) -> Image:
	var atlas := atlas_images[source_id] as Image
	var front := front_images[source_id] as Image
	var atlas_position := Vector2i(mask % 4, mask / 4) * TILE_SIZE
	var tile := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	tile.fill(Color.TRANSPARENT)
	tile.blit_rect(atlas, Rect2i(atlas_position, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i.ZERO)
	var result := Image.create(TILE_SIZE, TILE_SIZE + depth, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)

	# The front face owns its complete projected rectangle. Mask cutouts are
	# opaque cave colour so lower-z Hole Corners/side rims cannot bleed through.
	for y in range(TILE_SIZE, TILE_SIZE + depth):
		for x in range(TILE_SIZE):
			result.set_pixel(x, y, CAVE_OCCLUSION_COLOR)

	# Preserve the exact locked shift/subtract mask and colour sampling.
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
	runtime = _replace_function(runtime, "_build_extrusion_image", runtime_replacement)
	if not _write(RUNTIME_PATH, runtime):
		get_tree().quit(1)
		return
	print("FRONT_MASK_CUTOUTS_OCCLUDE_OVERLAYS")
	get_tree().quit(0)
