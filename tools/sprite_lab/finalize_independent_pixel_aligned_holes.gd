extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")
const TIERS: Array[String] = ["easy", "medium", "hard"]
const S := 32
const PATCH := 14

func _replace_function(text: String, function_name: String, replacement: String) -> String:
	var start := text.find("func %s(" % function_name)
	if start < 0:
		push_error("Missing function: %s" % function_name)
		return ""
	var next := text.find("\nfunc ", start + 6)
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
	selected_inside_corner_textures = _build_vertex_hole_textures(mass_image, selected_border_image, selected_corner_image)
	unmineable_inside_corner_textures = _build_vertex_hole_textures(mass_image, unmineable_border_image, unmineable_corner_image)
	queue_redraw()
''')
	if text.is_empty(): return false
	text = _replace_function(text, "_build_authored_corner_textures", '''func _build_authored_corner_textures(source: Image) -> Array[ImageTexture]:
	return _build_vertex_hole_textures(mass_image, selected_border_image, source)
''')
	if text.is_empty(): return false
	text = _replace_function(text, "_build_vertex_hole_textures", '''func _build_vertex_hole_textures(mass: Image, top_border: Image, hole_source: Image) -> Array[ImageTexture]:
	# A 14x14 independently editable Hole Corner is composited around the real
	# 2x2-cell vertex. The masks remove only the straight endpoint sections;
	# their full border depth remains perfectly tangent to the curved endpoint.
	var size := LOGICAL_SIZE * 2
	var base := Image.create(size, size, false, Image.FORMAT_RGBA8)
	base.fill(Color.TRANSPARENT)
	var hole := hole_source.duplicate()
	hole.convert(Image.FORMAT_RGBA8)
	if hole.get_width() != LOGICAL_SIZE or hole.get_height() != LOGICAL_SIZE:
		hole.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)

	var top_endpoint := -1
	var left_endpoint := -1
	for x in range(CORNER_PATCH_SIZE):
		if hole.get_pixel(x, 0).a > 0.05:
			top_endpoint = x
	for y in range(CORNER_PATCH_SIZE):
		if hole.get_pixel(0, y).a > 0.05:
			left_endpoint = y
	var top_cut := maxi(0, top_endpoint - 1)
	var left_cut := maxi(0, left_endpoint - 1)
	var depth := CORNER_BUILDER.border_depth(top_border)

	# Top solid tile: cut only along the endpoint, but through full border depth.
	for y in range(depth):
		for x in range(top_cut):
			base.set_pixel(LOGICAL_SIZE + x, LOGICAL_SIZE - depth + y, mass.get_pixel(x, LOGICAL_SIZE - depth + y))
	# Left solid tile: same rule, transposed.
	for y in range(left_cut):
		for x in range(depth):
			base.set_pixel(LOGICAL_SIZE - depth + x, LOGICAL_SIZE + y, mass.get_pixel(LOGICAL_SIZE - depth + x, y))

	# Origin 31/31 places the top and left rim endpoints directly on the last
	# pixel row/column of the neighbouring straight borders.
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			var color := hole.get_pixel(x, y)
			if color.a > 0.05:
				base.set_pixel(LOGICAL_SIZE - 1 + x, LOGICAL_SIZE - 1 + y, color)

	var result: Array[ImageTexture] = []
	for frame in range(4):
		result.append(ImageTexture.create_from_image(_rotate_vertex_composite(base, frame)))
	return result
''')
	if text.is_empty(): return false
	return _write(PREVIEW_PATH, text)

func _patch_workbench() -> bool:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	text = _replace_function(text, "_load_images", '''func _load_images() -> void:
	mass_image = _load_png_or_svg_logical(RUNTIME_MASS_PATH, FALLBACK_MASS_PATH)
	border_images.clear()
	corner_images.clear()
	convex_images.clear()
	for tier in ["easy", "medium", "hard"]:
		border_images[tier] = _load_editable_border_stamp(tier, String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))
		convex_images[tier] = _load_convex_stamp(tier, border_images[tier])
		corner_images[tier] = _load_hole_corner_stamp(tier, convex_images[tier])
	border_images["unmineable"] = (border_images["easy"] as Image).duplicate()
	convex_images["unmineable"] = (convex_images["easy"] as Image).duplicate()
	corner_images["unmineable"] = (corner_images["easy"] as Image).duplicate()
''')
	if text.is_empty(): return false
	text = _replace_function(text, "_workspace_title", '''func _workspace_title() -> String:
	if current_mode == "mass":
		return "UNIVERSAL DARK MASS"
	if current_mode == "convex":
		return "%s EDGE JOINT • AUTHOR TOP-LEFT ONLY" % current_tier.to_upper()
	if current_mode == "corner":
		return "%s HOLE CORNER • EDIT TOP-LEFT ONLY" % current_tier.to_upper()
	return "%s BORDER • AUTHOR TOP ONLY" % current_tier.to_upper()
''')
	if text.is_empty(): return false
	text = _replace_function(text, "_refresh_workspace", '''func _refresh_workspace() -> void:
	var visual_tier := _visual_tier()
	var base: Image = null
	if current_mode == "border":
		base = mass_image
	elif current_mode == "corner":
		base = _make_cave_base()
	elif current_mode == "convex":
		base = _make_convex_base(visual_tier)
	canvas.call("set_read_only", false)
	canvas.call("set_workspace_images", _active_image(), base, _active_region(), _workspace_title())
	preview.call("set_material_images", mass_image, border_images[visual_tier], border_images["easy"], corner_images[visual_tier], corner_images["easy"], convex_images[visual_tier], convex_images["easy"])
	title_label.text = _workspace_title()
	if current_mode == "mass":
		instruction_label.text = "Paint the one dark full tile used under every rock type."
	elif current_mode == "convex":
		instruction_label.text = "Paint one TOP-LEFT EDGE JOINT for exposed solid corners. Hole Corner is now independent and will not change."
	elif current_mode == "corner":
		instruction_label.text = "Paint the independent TOP-LEFT HOLE CORNER. It began from the Edge Joint curve, but editing it no longer changes Edge Joint."
	else:
		instruction_label.text = "Paint only the CYAN TOP BAND. The game rotates it for all four straight edges."
	for mode_value: Variant in mode_buttons.keys():
		var mode := String(mode_value)
		var button: Button = mode_buttons[mode]
		button.modulate = Color.WHITE if mode == current_mode else Color(0.68, 0.68, 0.74, 1.0)
	tier_selector.disabled = current_mode == "mass"
	undo_button.disabled = undo_stack.is_empty()
	redo_button.disabled = redo_stack.is_empty()
	status_label.text = "%s  •  cave preview updates immediately" % _workspace_title()
''')
	if text.is_empty(): return false
	text = _replace_function(text, "_build_inside_corner_atlas", '''func _build_inside_corner_atlas(hole_source: Image, top_border: Image = null) -> Image:
	var border: Image = top_border if top_border != null else border_images["easy"] as Image
	var logical_size := LOGICAL_SIZE * 2
	var rendered_size := TILE_SIZE * 2
	var base := Image.create(logical_size, logical_size, false, Image.FORMAT_RGBA8)
	base.fill(Color.TRANSPARENT)
	var hole := hole_source.duplicate()
	hole.convert(Image.FORMAT_RGBA8)
	if hole.get_width() != LOGICAL_SIZE or hole.get_height() != LOGICAL_SIZE:
		hole.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)

	var top_endpoint := -1
	var left_endpoint := -1
	for x in range(CORNER_PATCH_SIZE):
		if hole.get_pixel(x, 0).a > 0.05:
			top_endpoint = x
	for y in range(CORNER_PATCH_SIZE):
		if hole.get_pixel(0, y).a > 0.05:
			left_endpoint = y
	var top_cut := maxi(0, top_endpoint - 1)
	var left_cut := maxi(0, left_endpoint - 1)
	var depth := CORNER_BUILDER.border_depth(border)

	for y in range(depth):
		for x in range(top_cut):
			base.set_pixel(LOGICAL_SIZE + x, LOGICAL_SIZE - depth + y, mass_image.get_pixel(x, LOGICAL_SIZE - depth + y))
	for y in range(left_cut):
		for x in range(depth):
			base.set_pixel(LOGICAL_SIZE - depth + x, LOGICAL_SIZE + y, mass_image.get_pixel(LOGICAL_SIZE - depth + x, y))
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			var color := hole.get_pixel(x, y)
			if color.a > 0.05:
				base.set_pixel(LOGICAL_SIZE - 1 + x, LOGICAL_SIZE - 1 + y, color)

	var atlas := Image.create(rendered_size * 2, rendered_size * 2, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for frame in range(4):
		var rendered := _rotate_vertex_composite(base, frame)
		rendered.resize(rendered_size, rendered_size, Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(rendered, Rect2i(Vector2i.ZERO, Vector2i(rendered_size, rendered_size)), Vector2i(frame % 2, frame / 2) * rendered_size)
	return atlas
''')
	if text.is_empty(): return false
	text = text.replace("var corner_atlas := _build_inside_corner_atlas(convex_images[source_tier], border_images[source_tier])", "var corner_atlas := _build_inside_corner_atlas(corner_images[source_tier], border_images[source_tier])")
	text = text.replace("Exported four border atlases plus four Edge-Joint-derived diagonal Hole Corner atlases.", "Exported four border atlases plus four independently editable pixel-aligned Hole Corner atlases.")
	text = text.replace("Each material has one straight BORDER and one authored 14x14 EDGE JOINT. HOLE CORNER is derived automatically from that exact curve and applied to the diagonal solid tile.", "Each material has one straight BORDER, one 14x14 EDGE JOINT, and one independent 14x14 HOLE CORNER. Their curves start matched but can be edited separately.")
	return _write(WORKBENCH_PATH, text)

func _load_image(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)
	image.resize(S, S, Image.INTERPOLATE_NEAREST)
	return image

func _regenerate_corner_sources() -> bool:
	var mass := _load_image(SOURCE_DIR + "/dark_mass_32.png")
	for tier in TIERS:
		var border := _load_image(SOURCE_DIR + "/%s_border_top_32.png" % tier)
		var edge := _load_image(SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % tier)
		var hole := BUILDER.make_hole_corner_top_left(mass, border, edge)
		var clean := Image.create(S, S, false, Image.FORMAT_RGBA8)
		clean.fill(Color.TRANSPARENT)
		for y in range(PATCH):
			for x in range(PATCH):
				clean.set_pixel(x, y, hole.get_pixel(x, y))
		# Match the two tangent endpoint pixels to the straight border's outer row.
		var outer := border.get_pixel(S / 2, 0)
		var top_endpoint := -1
		var left_endpoint := -1
		for x in range(PATCH):
			if clean.get_pixel(x, 0).a > 0.05:
				top_endpoint = x
		for y in range(PATCH):
			if clean.get_pixel(0, y).a > 0.05:
				left_endpoint = y
		if top_endpoint >= 0: clean.set_pixel(top_endpoint, 0, outer)
		if left_endpoint >= 0: clean.set_pixel(0, left_endpoint, outer)
		var result := clean.save_png(SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier)
		if result != OK:
			push_error("Could not save %s Hole Corner" % tier)
			return false
	var easy := _load_image(SOURCE_DIR + "/easy_hole_corner_top_left_32.png")
	return easy.save_png(SOURCE_DIR + "/unmineable_hole_corner_top_left_32.png") == OK

func _ready() -> void:
	if not _patch_preview() or not _patch_workbench() or not _regenerate_corner_sources():
		get_tree().quit(1)
		return
	print("Hole Corners are independent and use exact rectangular endpoint masks")
	get_tree().quit()
