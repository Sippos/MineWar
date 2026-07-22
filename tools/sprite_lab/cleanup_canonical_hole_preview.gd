extends Node

const PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _function_range(text: String, function_name: String, from_index: int = 0) -> Vector2i:
	var start := text.find("func %s(" % function_name, from_index)
	if start < 0:
		return Vector2i(-1, -1)
	var next := text.find("\nfunc ", start + 1)
	if next < 0:
		next = text.length()
	return Vector2i(start, next)

func _replace_first_function(text: String, function_name: String, replacement: String) -> String:
	var range := _function_range(text, function_name)
	if range.x < 0:
		push_error("Missing function %s" % function_name)
		return ""
	return text.substr(0, range.x) + replacement + "\n" + text.substr(range.y + 1)

func _remove_duplicate_functions(text: String, function_name: String) -> String:
	var first := _function_range(text, function_name)
	if first.x < 0:
		return text
	while true:
		var duplicate := _function_range(text, function_name, first.y + 1)
		if duplicate.x < 0:
			return text
		text = text.substr(0, duplicate.x) + text.substr(duplicate.y + 1)
	return text

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		push_error("Could not read preview")
		get_tree().quit(1)
		return

	text = _remove_duplicate_functions(text, "_build_vertex_hole_textures")
	text = text.replace(
		"selected_composite_textures = CORNER_BUILDER.build_composite_textures(mass_image, selected_border_image, selected_convex_image)",
		"selected_composite_textures = _build_logical_composite_textures(mass_image, selected_border_image, selected_convex_image)"
	)
	text = text.replace(
		"unmineable_composite_textures = CORNER_BUILDER.build_composite_textures(mass_image, unmineable_border_image, unmineable_convex_image)",
		"unmineable_composite_textures = _build_logical_composite_textures(mass_image, unmineable_border_image, unmineable_convex_image)"
	)
	text = text.replace(
		"selected_inside_corner_textures = _build_vertex_hole_textures(mass_image, selected_border_image, selected_convex_image)",
		"selected_inside_corner_textures = _build_vertex_hole_textures(mass_image, selected_border_image, selected_corner_image)"
	)
	text = text.replace(
		"unmineable_inside_corner_textures = _build_vertex_hole_textures(mass_image, unmineable_border_image, unmineable_convex_image)",
		"unmineable_inside_corner_textures = _build_vertex_hole_textures(mass_image, unmineable_border_image, unmineable_corner_image)"
	)

	var build_holes := "\n".join([
		"func _build_vertex_hole_textures(_mass: Image, _top_border: Image, hole_source: Image) -> Array[ImageTexture]:",
		"\tvar source_patch := Image.create(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE, false, Image.FORMAT_RGBA8)",
		"\tsource_patch.fill(Color.TRANSPARENT)",
		"\tfor y in range(CORNER_PATCH_SIZE):",
		"\t\tfor x in range(CORNER_PATCH_SIZE):",
		"\t\t\tsource_patch.set_pixel(x, y, hole_source.get_pixel(x, y))",
		"\tvar result: Array[ImageTexture] = []",
		"\tfor frame in range(4):",
		"\t\tresult.append(ImageTexture.create_from_image(_rotate_corner_patch(source_patch, frame)))",
		"\treturn result",
	])
	text = _replace_first_function(text, "_build_vertex_hole_textures", build_holes)
	if text.is_empty():
		get_tree().quit(1)
		return

	var draw_holes := "\n".join([
		"func _draw_hole_corners(empty_cell: Vector2i, rect: Rect2) -> void:",
		"\tvar rules := [",
		"\t\t[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],",
		"\t\t[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],",
		"\t\t[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],",
		"\t\t[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],",
		"\t]",
		"\tfor rule_value: Variant in rules:",
		"\t\tvar rule: Array = rule_value",
		"\t\tvar first: Vector2i = rule[0]",
		"\t\tvar second: Vector2i = rule[1]",
		"\t\tvar diagonal: Vector2i = rule[2]",
		"\t\tvar frame: int = rule[3]",
		"\t\tif not _is_solid(empty_cell + first) or not _is_solid(empty_cell + second) or not _is_solid(empty_cell + diagonal):",
		"\t\t\tcontinue",
		"\t\tvar owner_type := _cell_type(empty_cell + diagonal)",
		"\t\tvar textures := _inside_corner_textures_for(owner_type)",
		"\t\tif frame >= textures.size() or textures[frame] == null:",
		"\t\t\tcontinue",
		"\t\tvar patch_rect := _hole_corner_patch_rect(rect, frame)",
		"\t\t_restore_hole_corner_border_bands(rect, patch_rect, frame)",
		"\t\tdraw_texture_rect(textures[frame], patch_rect, false)",
	])
	text = _replace_first_function(text, "_draw_hole_corners", draw_holes)
	if text.is_empty():
		get_tree().quit(1)
		return

	var patch_rect := "\n".join([
		"func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:",
		"\tvar position := rect.position - Vector2.ONE",
		"\tmatch frame:",
		"\t\t1: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 1.0, rect.position.y - 1.0)",
		"\t\t2: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 1.0, rect.end.y - CORNER_PATCH_SIZE + 1.0)",
		"\t\t3: position = Vector2(rect.position.x - 1.0, rect.end.y - CORNER_PATCH_SIZE + 1.0)",
		"\treturn Rect2(position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))",
	])
	text = _replace_first_function(text, "_hole_corner_patch_rect", patch_rect)
	if text.is_empty():
		get_tree().quit(1)
		return

	var restore_bands := "\n".join([
		"func _restore_hole_corner_border_bands(rect: Rect2, patch_rect: Rect2, frame: int) -> void:",
		"\tif mass_texture == null:",
		"\t\treturn",
		"\tvar depth := float(CORNER_BUILDER.border_depth(selected_border_image))",
		"\tmatch frame:",
		"\t\t0:",
		"\t\t\tdraw_texture_rect_region(mass_texture, Rect2(Vector2(patch_rect.position.x, rect.position.y - depth), Vector2(patch_rect.size.x, depth)), Rect2(Vector2.ZERO, Vector2(patch_rect.size.x, depth)))",
		"\t\t\tdraw_texture_rect_region(mass_texture, Rect2(Vector2(rect.position.x - depth, patch_rect.position.y), Vector2(depth, patch_rect.size.y)), Rect2(Vector2.ZERO, Vector2(depth, patch_rect.size.y)))",
		"\t\t1:",
		"\t\t\tdraw_texture_rect_region(mass_texture, Rect2(Vector2(patch_rect.position.x, rect.position.y - depth), Vector2(patch_rect.size.x, depth)), Rect2(Vector2.ZERO, Vector2(patch_rect.size.x, depth)))",
		"\t\t\tdraw_texture_rect_region(mass_texture, Rect2(Vector2(rect.end.x, patch_rect.position.y), Vector2(depth, patch_rect.size.y)), Rect2(Vector2(LOGICAL_SIZE - int(depth), 0), Vector2(depth, patch_rect.size.y)))",
		"\t\t2:",
		"\t\t\tdraw_texture_rect_region(mass_texture, Rect2(Vector2(patch_rect.position.x, rect.end.y), Vector2(patch_rect.size.x, depth)), Rect2(Vector2.ZERO, Vector2(patch_rect.size.x, depth)))",
		"\t\t\tdraw_texture_rect_region(mass_texture, Rect2(Vector2(rect.end.x, patch_rect.position.y), Vector2(depth, patch_rect.size.y)), Rect2(Vector2(LOGICAL_SIZE - int(depth), 0), Vector2(depth, patch_rect.size.y)))",
		"\t\t3:",
		"\t\t\tdraw_texture_rect_region(mass_texture, Rect2(Vector2(patch_rect.position.x, rect.end.y), Vector2(patch_rect.size.x, depth)), Rect2(Vector2.ZERO, Vector2(patch_rect.size.x, depth)))",
		"\t\t\tdraw_texture_rect_region(mass_texture, Rect2(Vector2(rect.position.x - depth, patch_rect.position.y), Vector2(depth, patch_rect.size.y)), Rect2(Vector2.ZERO, Vector2(depth, patch_rect.size.y)))",
	])
	if text.contains("func _restore_hole_corner_border_bands("):
		text = _replace_first_function(text, "_restore_hole_corner_border_bands", restore_bands)
	else:
		var anchor := text.find("func _border_depth_for(")
		if anchor < 0:
			push_error("Missing insertion anchor")
			get_tree().quit(1)
			return
		text = text.substr(0, anchor) + restore_bands + "\n" + text.substr(anchor)

	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write preview")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Cleaned and rebuilt canonical Hole Corner preview")
	get_tree().quit()
