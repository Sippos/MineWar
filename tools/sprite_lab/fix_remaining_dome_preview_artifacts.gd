extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _replace_once(text: String, old: String, replacement: String, label: String) -> String:
	if not text.contains(old):
		push_error("Missing patch anchor: " + label)
		return text
	return text.replace(old, replacement)

func _ready() -> void:
	var preview := FileAccess.get_file_as_string(PREVIEW_PATH)
	var old_draw_tail := '''	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var empty_cell := Vector2i(x, y)
			if not _is_solid(empty_cell):
				_draw_hole_corners(empty_cell, _cell_rect(empty_cell))

	if hovered_cell.x >= 0 and hovered_cell.y >= 0 and hovered_cell.x < MAP_SIZE.x and hovered_cell.y < MAP_SIZE.y:
'''
	var new_draw_tail := '''	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var empty_cell := Vector2i(x, y)
			if not _is_solid(empty_cell):
				_draw_hole_corners(empty_cell, _cell_rect(empty_cell))

	# Hole Corner patches intentionally extend past their vertex, but pixels below
	# a downward-facing block belong to the front wall. Clean only those face
	# rectangles, then redraw the extrusion there. This removes gray floor rims
	# without changing the approved Hole Corner image or its -3 px anchor.
	_draw_front_face_occlusion()

	if hovered_cell.x >= 0 and hovered_cell.y >= 0 and hovered_cell.x < MAP_SIZE.x and hovered_cell.y < MAP_SIZE.y:
'''
	preview = _replace_once(preview, old_draw_tail, new_draw_tail, "front occlusion call")

	var function_anchor := "func _draw_hole_corners(empty_cell: Vector2i, rect: Rect2) -> void:\n"
	var occlusion_function := '''func _draw_front_face_occlusion() -> void:
	if not show_front_faces or extrusion_texture == null:
		return
	var texture_size := extrusion_texture.get_size()
	for cell_y in range(MAP_SIZE.y):
		for cell_x in range(MAP_SIZE.x):
			var cell := Vector2i(cell_x, cell_y)
			if not _is_solid(cell) or _is_solid(cell + Vector2i.DOWN):
				continue
			var face_rect := Rect2(
				Vector2(cell_x * CELL_SIZE, (cell_y + 1) * CELL_SIZE),
				Vector2(CELL_SIZE, front_depth)
			)
			var clipped := face_rect.intersection(Rect2(Vector2.ZERO, texture_size))
			if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
				continue
			draw_rect(clipped, CAVE_COLOR)
			draw_texture_rect_region(extrusion_texture, clipped, clipped)

'''
	if not preview.contains("func _draw_front_face_occlusion() -> void:"):
		preview = preview.replace(function_anchor, occlusion_function + function_anchor)

	var old_depth := '''	var depth := float(CORNER_BUILDER.border_depth(owner_border))
	match frame:
'''
	var new_depth := '''	var depth := float(CORNER_BUILDER.border_depth(owner_border))
	# The locked Hole Corner patch overhangs the tile vertex by 3 px. Restore
	# straight-band coverage across that same overhang so no one-pixel seams remain.
	var coverage := minf(float(CORNER_PATCH_SIZE), depth + 3.0)
	match frame:
'''
	preview = _replace_once(preview, old_depth, new_depth, "corner band coverage")
	# Only inside this helper, replace the draw-band dimensions with coverage.
	var helper_start := preview.find("func _restore_hole_corner_border_bands(")
	var helper_end := preview.find("\nfunc ", helper_start + 5)
	if helper_start >= 0:
		if helper_end < 0:
			helper_end = preview.length()
		var helper := preview.substr(helper_start, helper_end - helper_start)
		helper = helper.replace("rect.position.y - depth", "rect.position.y - coverage")
		helper = helper.replace("rect.position.x - depth", "rect.position.x - coverage")
		helper = helper.replace("Vector2(patch_rect.size.x, depth)", "Vector2(patch_rect.size.x, coverage)")
		helper = helper.replace("Vector2(depth, patch_rect.size.y)", "Vector2(coverage, patch_rect.size.y)")
		helper = helper.replace("Vector2(LOGICAL_SIZE - int(depth), 0)", "Vector2(LOGICAL_SIZE - int(coverage), 0)")
		preview = preview.substr(0, helper_start) + helper + preview.substr(helper_end)
	FileAccess.open(PREVIEW_PATH, FileAccess.WRITE).store_string(preview)

	var workbench := FileAccess.get_file_as_string(WORKBENCH_PATH)
	var old_preview_call := '''	canvas.call("set_read_only", false)
	canvas.call("set_workspace_images", _active_image(), base, _active_region(), _workspace_title())
	preview.call("set_material_library", mass_image, border_images, corner_images, convex_images, front_images)
	title_label.text = _workspace_title()
'''
	var new_preview_call := '''	canvas.call("set_read_only", false)
	canvas.call("set_workspace_images", _active_image(), base, _active_region(), _workspace_title())

	# Keep authored Edge Joint and Hole Corner sources independent, but make the
	# live preview show a continuously matched set while the parent Border/Joint
	# is being painted. The source dictionaries are never overwritten here.
	var preview_joints := convex_images.duplicate()
	var preview_corners := corner_images.duplicate()
	if current_mode == "border":
		var live_joint := CORNER_BUILDER.make_edge_joint_top_left(mass_image, border_images[visual_tier])
		preview_joints[visual_tier] = live_joint
		preview_corners[visual_tier] = CORNER_BUILDER.make_hole_corner_top_left(mass_image, border_images[visual_tier], live_joint)
	elif current_mode == "convex":
		preview_corners[visual_tier] = CORNER_BUILDER.make_hole_corner_top_left(mass_image, border_images[visual_tier], convex_images[visual_tier])
	preview.call("set_material_library", mass_image, border_images, preview_corners, preview_joints, front_images)
	preview.queue_redraw()
	title_label.text = _workspace_title()
'''
	workbench = _replace_once(workbench, old_preview_call, new_preview_call, "live corner preview")
	FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE).store_string(workbench)

	print("FIXED_REMAINING_DOME_PREVIEW_ARTIFACTS")
	get_tree().quit(0)
