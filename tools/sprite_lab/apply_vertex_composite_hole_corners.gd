extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const WORLD_PATH := "res://scripts/systems/world_generation/world.gd"

func _replace_function(text: String, function_name: String, replacement: String) -> String:
	var start: int = text.find("func %s(" % function_name)
	if start < 0:
		push_error("Missing function: %s" % function_name)
		return ""
	var next: int = text.find("\nfunc ", start + 6)
	if next < 0:
		next = text.length()
	return text.substr(0, start) + replacement.strip_edges(false, true) + "\n" + text.substr(next + 1)

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true

func _patch_preview() -> bool:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	text = _replace_function(text, "_rebuild_material_textures", '''func _rebuild_material_textures() -> void:
	if mass_image == null or selected_border_image == null or unmineable_border_image == null:
		return
	if rounded_light_corners:
		selected_composite_textures = CORNER_BUILDER.build_composite_textures(mass_image, selected_border_image, selected_convex_image)
		unmineable_composite_textures = CORNER_BUILDER.build_composite_textures(mass_image, unmineable_border_image, unmineable_convex_image)
	else:
		selected_composite_textures = _build_square_composite_textures(mass_image, selected_border_image)
		unmineable_composite_textures = _build_square_composite_textures(mass_image, unmineable_border_image)
	selected_inside_corner_textures = _build_vertex_hole_textures(mass_image, selected_border_image, selected_convex_image)
	unmineable_inside_corner_textures = _build_vertex_hole_textures(mass_image, unmineable_border_image, unmineable_convex_image)
	queue_redraw()
''')
	if text.is_empty(): return false

	text = _replace_function(text, "_build_authored_corner_textures", '''func _build_authored_corner_textures(source: Image) -> Array[ImageTexture]:
	return _build_vertex_hole_textures(mass_image, selected_border_image, source)

func _build_vertex_hole_textures(mass: Image, top_border: Image, edge_joint: Image) -> Array[ImageTexture]:
	# Frame 0 is the top-left corner of an empty cell. It spans the surrounding
	# 2x2 cells: diagonal solid / top solid / left solid / empty cave.
	var size := LOGICAL_SIZE * 2
	var base := Image.create(size, size, false, Image.FORMAT_RGBA8)
	base.fill(Color.TRANSPARENT)
	var hole := CORNER_BUILDER.make_hole_corner_top_left(mass, top_border, edge_joint)
	var endpoint := CORNER_PATCH_SIZE - 2

	# Restore dark mass over the square endpoints of the top and left borders.
	# This removes the straight L without cutting holes in the solid tiles.
	for y in range(endpoint):
		for x in range(endpoint):
			base.set_pixel(LOGICAL_SIZE + x, LOGICAL_SIZE - endpoint + y, mass.get_pixel(x, LOGICAL_SIZE - endpoint + y))
			base.set_pixel(LOGICAL_SIZE - endpoint + x, LOGICAL_SIZE + y, mass.get_pixel(LOGICAL_SIZE - endpoint + x, y))

	# Draw the inverse Edge Joint in the empty quadrant. Its top and left rim
	# endpoints overlap the restored border cutbacks by one logical pixel.
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			var color := hole.get_pixel(x, y)
			if color.a > 0.05:
				base.set_pixel(LOGICAL_SIZE + x, LOGICAL_SIZE + y, color)

	var result: Array[ImageTexture] = []
	for frame in range(4):
		result.append(ImageTexture.create_from_image(CORNER_BUILDER.rotate_quarters(base, frame)))
	return result
''')
	if text.is_empty(): return false

	text = _replace_function(text, "_draw_hole_corners", '''func _draw_hole_corners(empty_cell: Vector2i, rect: Rect2) -> void:
	var rules := [
		[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],
		[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],
		[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],
		[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],
	]
	for rule_value in rules:
		var rule: Array = rule_value
		var first: Vector2i = rule[0]
		var second: Vector2i = rule[1]
		var diagonal: Vector2i = rule[2]
		var frame: int = rule[3]
		if not _is_solid(empty_cell + first) or not _is_solid(empty_cell + second) or not _is_solid(empty_cell + diagonal):
			continue
		var owner_type := _cell_type(empty_cell + diagonal)
		var textures := _inside_corner_textures_for(owner_type)
		if frame >= textures.size() or textures[frame] == null:
			continue
		var vertex := rect.position
		match frame:
			1: vertex = Vector2(rect.end.x, rect.position.y)
			2: vertex = rect.end
			3: vertex = Vector2(rect.position.x, rect.end.y)
		var overlay_rect := Rect2(vertex - Vector2(CELL_SIZE, CELL_SIZE), Vector2(CELL_SIZE * 2, CELL_SIZE * 2))
		draw_texture_rect(textures[frame], overlay_rect, false)
''')
	if text.is_empty(): return false
	return _write(PREVIEW_PATH, text)

func _patch_workbench() -> bool:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	text = _replace_function(text, "_build_inside_corner_atlas", '''func _build_inside_corner_atlas(edge_joint_source: Image, top_border: Image = null) -> Image:
	var border := top_border if top_border != null else border_images["easy"] as Image
	var logical_size := LOGICAL_SIZE * 2
	var rendered_size := TILE_SIZE * 2
	var base := Image.create(logical_size, logical_size, false, Image.FORMAT_RGBA8)
	base.fill(Color.TRANSPARENT)
	var hole := CORNER_BUILDER.make_hole_corner_top_left(mass_image, border, edge_joint_source)
	var endpoint := CORNER_PATCH_SIZE - 2
	for y in range(endpoint):
		for x in range(endpoint):
			base.set_pixel(LOGICAL_SIZE + x, LOGICAL_SIZE - endpoint + y, mass_image.get_pixel(x, LOGICAL_SIZE - endpoint + y))
			base.set_pixel(LOGICAL_SIZE - endpoint + x, LOGICAL_SIZE + y, mass_image.get_pixel(LOGICAL_SIZE - endpoint + x, y))
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			var color := hole.get_pixel(x, y)
			if color.a > 0.05:
				base.set_pixel(LOGICAL_SIZE + x, LOGICAL_SIZE + y, color)

	var atlas := Image.create(rendered_size * 2, rendered_size * 2, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for frame in range(4):
		var rendered := CORNER_BUILDER.rotate_quarters(base, frame)
		rendered.resize(rendered_size, rendered_size, Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(rendered, Rect2i(Vector2i.ZERO, Vector2i(rendered_size, rendered_size)), Vector2i(frame % 2, frame / 2) * rendered_size)
	return atlas
''')
	if text.is_empty(): return false
	text = text.replace("var corner_atlas := _build_inside_corner_atlas(convex_images[source_tier], border_images[source_tier])", "var corner_atlas := _build_inside_corner_atlas(convex_images[source_tier], border_images[source_tier])")
	text = text.replace("%s HOLE CORNER • DERIVED FROM EDGE JOINT", "%s HOLE CORNER • DERIVED VERTEX COMPOSITE")
	text = text.replace("DERIVED PREVIEW: the Edge Joint is rotated onto the diagonal solid tile and its transparent side becomes cave colour. Edit EDGE JOINT to change this curve.", "DERIVED PREVIEW: the Edge Joint curve is combined with two dark-mass endpoint masks around the real grid vertex. Edit EDGE JOINT to change the curve.")
	return _write(WORKBENCH_PATH, text)

func _patch_world() -> bool:
	var text := FileAccess.get_file_as_string(WORLD_PATH)
	text = text.replace("const INSIDE_CORNER_FRAME_SIZE := 64", "const INSIDE_CORNER_FRAME_SIZE := 128")
	var old := '''		# Hole Corner frames are full-tile replacement overlays owned by the
		# diagonal solid block, not decorations inside the empty cell.
		var diagonal_cell := cell + diagonal
		sprite.position = inside_corner_layer.to_local(block_layer.to_global(block_layer.map_to_local(diagonal_cell)))
'''
	var replacement := '''		# The 128x128 frame spans the four cells around the real grid vertex. It
		# restores the two border endpoints and draws the derived inverse curve.
		var vertex_offset := Vector2(-32.0, -32.0)
		match frame:
			1: vertex_offset = Vector2(32.0, -32.0)
			2: vertex_offset = Vector2(32.0, 32.0)
			3: vertex_offset = Vector2(-32.0, 32.0)
		var empty_center := block_layer.map_to_local(cell)
		sprite.position = inside_corner_layer.to_local(block_layer.to_global(empty_center + vertex_offset))
'''
	if not text.contains(old):
		push_error("Missing diagonal runtime placement")
		return false
	text = text.replace(old, replacement)
	return _write(WORLD_PATH, text)

func _ready() -> void:
	if not _patch_preview() or not _patch_workbench() or not _patch_world():
		get_tree().quit(1)
		return
	print("Hole Corners now use a derived 2x2 vertex composite")
	get_tree().quit()
