extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const WORLD_PATH := "res://scripts/systems/world_generation/world.gd"

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
	# Hole Corners are derived from the authored Edge Joint and painted over the
	# diagonal solid tile. They do not belong to the empty cell.
	selected_inside_corner_textures = _build_diagonal_hole_textures(selected_convex_image)
	unmineable_inside_corner_textures = _build_diagonal_hole_textures(unmineable_convex_image)
	queue_redraw()
''')
	if text.is_empty(): return false
	text = _replace_function(text, "_build_authored_corner_textures", '''func _build_authored_corner_textures(edge_joint_source: Image) -> Array[ImageTexture]:
	# Compatibility wrapper for older callers.
	return _build_diagonal_hole_textures(edge_joint_source)

func _build_diagonal_hole_textures(edge_joint_source: Image) -> Array[ImageTexture]:
	# Start with the exact Edge Joint source. Inside its authored 14x14 patch,
	# transparent pixels are the cave cutout; make them opaque cave colour so the
	# overlay can replace pixels from the diagonal solid tile beneath it.
	var replacement := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	replacement.fill(Color.TRANSPARENT)
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			var color := edge_joint_source.get_pixel(x, y)
			replacement.set_pixel(x, y, CAVE_COLOR if color.a <= 0.05 else color)

	var result: Array[ImageTexture] = []
	for frame in range(4):
		# Empty-cell TL/TR/BR/BL corners are owned by the diagonal solid tile's
		# BR/BL/TL/TR corner respectively: Edge Joint turns 2/3/0/1.
		var turn := posmod(frame + 2, 4)
		var overlay := CORNER_BUILDER.rotate_quarters(replacement, turn)
		result.append(ImageTexture.create_from_image(overlay))
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
		var diagonal_cell := empty_cell + diagonal
		var owner_type := _cell_type(diagonal_cell)
		var textures := _inside_corner_textures_for(owner_type)
		if frame >= textures.size() or textures[frame] == null:
			continue
		# Replace the square corner of the DIAGONAL SOLID TILE. The cave-coloured
		# part cuts it away; the retained Edge Joint pixels form the rounded rim.
		draw_texture_rect(textures[frame], _cell_rect(diagonal_cell), false)
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
		# Hole Corner is a derived preview of the same curve. No separate authored
		# geometry exists, so it can never drift away from the Edge Joint.
		corner_images[tier] = (convex_images[tier] as Image).duplicate()
	border_images["unmineable"] = (border_images["easy"] as Image).duplicate()
	convex_images["unmineable"] = (convex_images["easy"] as Image).duplicate()
	corner_images["unmineable"] = (convex_images["easy"] as Image).duplicate()
''')
	if text.is_empty(): return false
	text = _replace_function(text, "_refresh_workspace", '''func _refresh_workspace() -> void:
	var visual_tier := _visual_tier()
	var base: Image = null
	if current_mode == "border":
		base = mass_image
	elif current_mode == "corner":
		base = _make_convex_base(visual_tier)
	elif current_mode == "convex":
		base = _make_convex_base(visual_tier)
	canvas.call("set_read_only", current_mode == "corner")
	canvas.call("set_workspace_images", _active_image(), base, _active_region(), _workspace_title())
	preview.call("set_material_images", mass_image, border_images[visual_tier], border_images["easy"], corner_images[visual_tier], corner_images["easy"], convex_images[visual_tier], convex_images["easy"])
	title_label.text = _workspace_title()
	if current_mode == "mass":
		instruction_label.text = "Paint the one dark full tile used under every rock type."
	elif current_mode == "convex":
		instruction_label.text = "Paint one TOP-LEFT EDGE JOINT. This is the single authored curve used for exposed corners and derived Hole Corners."
	elif current_mode == "corner":
		instruction_label.text = "DERIVED PREVIEW: the Edge Joint is rotated onto the diagonal solid tile and its transparent side becomes cave colour. Edit EDGE JOINT to change this curve."
	else:
		instruction_label.text = "Paint only the CYAN TOP BAND. The game rotates it for all four straight edges."
	for mode_value: Variant in mode_buttons.keys():
		var mode := String(mode_value)
		var button: Button = mode_buttons[mode]
		button.modulate = Color.WHITE if mode == current_mode else Color(0.68, 0.68, 0.74, 1.0)
	tier_selector.disabled = current_mode == "mass"
	undo_button.disabled = undo_stack.is_empty() or current_mode == "corner"
	redo_button.disabled = redo_stack.is_empty() or current_mode == "corner"
	status_label.text = "%s  •  cave preview updates immediately" % _workspace_title()
''')
	if text.is_empty(): return false
	text = text.replace("%s HOLE CORNER • EDIT TOP-LEFT ONLY", "%s HOLE CORNER • DERIVED FROM EDGE JOINT")
	text = text.replace("Each material has one straight BORDER, one 14x14 EDGE JOINT, and one independent 14x14 HOLE CORNER. Both corner sprites share the same curve coordinates but have opposite solid/cave sides.", "Each material has one straight BORDER and one authored 14x14 EDGE JOINT. HOLE CORNER is derived automatically from that exact curve and applied to the diagonal solid tile.")
	text = _replace_function(text, "_build_inside_corner_atlas", '''func _build_inside_corner_atlas(edge_joint_source: Image, top_border: Image = null) -> Image:
	# Build a full-tile replacement overlay from the exact Edge Joint. Transparent
	# pixels in its 14x14 authored patch become opaque cave colour, allowing the
	# overlay to cut away the diagonal solid tile's square corner.
	var replacement := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	replacement.fill(Color.TRANSPARENT)
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			var color := edge_joint_source.get_pixel(x, y)
			replacement.set_pixel(x, y, Color.html("111725ff") if color.a <= 0.05 else color)

	var atlas := Image.create(TILE_SIZE * 2, TILE_SIZE * 2, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for frame in range(4):
		var turn := posmod(frame + 2, 4)
		var logical_tile := CORNER_BUILDER.rotate_quarters(replacement, turn)
		logical_tile.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(logical_tile, Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i(frame % 2, frame / 2) * TILE_SIZE)
	return atlas
''')
	if text.is_empty(): return false
	text = text.replace("var corner_atlas := _build_inside_corner_atlas(corner_images[source_tier])", "var corner_atlas := _build_inside_corner_atlas(convex_images[source_tier], border_images[source_tier])")
	text = text.replace("Exported four border atlases plus four independently editable Hole Corner atlases.", "Exported four border atlases plus four Edge-Joint-derived diagonal Hole Corner atlases.")
	return _write(WORKBENCH_PATH, text)

func _patch_world() -> bool:
	var text := FileAccess.get_file_as_string(WORLD_PATH)
	var old := '''		# The atlas frame is centered on the empty cell, then shifted two rendered
		# pixels outward so its native 14x14 patch overlaps both straight endpoints.
		var corner_offset := Vector2(-2.0, -2.0)
		match frame:
			1: corner_offset = Vector2(2.0, -2.0)
			2: corner_offset = Vector2(2.0, 2.0)
			3: corner_offset = Vector2(-2.0, 2.0)
		sprite.position = inside_corner_layer.to_local(block_layer.to_global(block_layer.map_to_local(cell))) + corner_offset
'''
	var replacement := '''		# Hole Corner frames are full-tile replacement overlays owned by the
		# diagonal solid block, not decorations inside the empty cell.
		var diagonal_cell := cell + diagonal
		sprite.position = inside_corner_layer.to_local(block_layer.to_global(block_layer.map_to_local(diagonal_cell)))
'''
	if not text.contains(old):
		push_error("Missing runtime corner placement block")
		return false
	text = text.replace(old, replacement)
	return _write(WORLD_PATH, text)

func _ready() -> void:
	if not _patch_preview() or not _patch_workbench() or not _patch_world():
		get_tree().quit(1)
		return
	print("Hole Corners now replace the diagonal solid tile using the Edge Joint curve")
	get_tree().quit()
