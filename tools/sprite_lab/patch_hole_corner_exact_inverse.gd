extends Node

const BUILDER_PATH := "res://tools/sprite_lab/dome_corner_builder.gd"
const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _ready() -> void:
	var error := _patch_builder()
	if error != OK:
		push_error("Could not patch corner builder: %s" % error_string(error))
		get_tree().quit(1)
		return
	error = _patch_workbench()
	if error != OK:
		push_error("Could not patch workbench: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("Hole Corner now derives as the exact solid/cave inverse of Edge Joint")
	get_tree().quit()

func _patch_builder() -> Error:
	var text := FileAccess.get_file_as_string(BUILDER_PATH)
	if text.is_empty():
		return ERR_FILE_CANT_READ

	var old_start := text.find("static func make_hole_corner_top_left(")
	var old_end := text.find("\nstatic func ", old_start + 1)
	if old_start < 0:
		return ERR_DOES_NOT_EXIST
	if old_end < 0:
		old_end = text.length()

	var replacement := '''static func make_hole_corner_top_left(mass_image: Image, top_border: Image, edge_joint: Image = null) -> Image:
	## Exact inverse of the authored Edge Joint. The Edge Joint alpha silhouette is
	## the single source of truth: solid joint pixels become transparent cave, and
	## transparent joint pixels become rock. Border shading is reconstructed from
	## the same material palette by distance to the identical curve.
	var joint := edge_joint
	if joint == null or joint.is_empty():
		joint = make_edge_joint_top_left(mass_image, top_border)
	joint = joint.duplicate()
	joint.convert(Image.FORMAT_RGBA8)
	if joint.get_width() != LOGICAL_SIZE or joint.get_height() != LOGICAL_SIZE:
		joint.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)

	var mass := mass_image.duplicate()
	mass.convert(Image.FORMAT_RGBA8)
	if mass.get_width() != LOGICAL_SIZE or mass.get_height() != LOGICAL_SIZE:
		mass.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)

	var result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var depth := border_depth(top_border)
	var solid_points: Array[Vector2i] = []
	for y in range(CORNER_EDIT_SIZE):
		for x in range(CORNER_EDIT_SIZE):
			if joint.get_pixel(x, y).a > 0.05:
				solid_points.append(Vector2i(x, y))

	for y in range(CORNER_EDIT_SIZE):
		for x in range(CORNER_EDIT_SIZE):
			# Exact alpha inversion: the original joint's rock becomes cave.
			if joint.get_pixel(x, y).a > 0.05:
				continue
			var color := mass.get_pixel(x, y)
			var nearest_distance := INF
			for solid_point in solid_points:
				var distance := Vector2(Vector2i(x, y) - solid_point).length()
				if distance < nearest_distance:
					nearest_distance = distance
			if nearest_distance <= float(depth):
				var palette_row := clampi(floori(nearest_distance) - 1, 0, depth - 1)
				var rim_color := average_border_row(top_border, palette_row)
				if rim_color.a > 0.05:
					color = rim_color
			result.set_pixel(x, y, color)
	return result
'''
	text = text.substr(0, old_start) + replacement + text.substr(old_end)
	return _write_text(BUILDER_PATH, text)

func _patch_workbench() -> Error:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	if text.is_empty():
		return ERR_FILE_CANT_READ

	var old_load := '''\tfor tier in ["easy", "medium", "hard"]:
\t\tborder_images[tier] = _load_editable_border_stamp(tier, String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))
\t\tconvex_images[tier] = _load_convex_stamp(tier, border_images[tier])
\t\tcorner_images[tier] = _load_hole_corner_stamp(tier, convex_images[tier])
\t# Unmineable is a gameplay property, not a separate visual material.
\t# It permanently mirrors the Easy art so it can never drift or load stale pixels.
\tborder_images["unmineable"] = (border_images["easy"] as Image).duplicate()
\tconvex_images["unmineable"] = (convex_images["easy"] as Image).duplicate()
\tcorner_images["unmineable"] = (corner_images["easy"] as Image).duplicate()
'''
	var new_load := '''\tfor tier in ["easy", "medium", "hard"]:
\t\tborder_images[tier] = _load_editable_border_stamp(tier, String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))
\t\tconvex_images[tier] = _load_convex_stamp(tier, border_images[tier])
\t_sync_derived_hole_corners()
'''
	if not text.contains(old_load):
		return ERR_INVALID_DATA
	text = text.replace(old_load, new_load)

	var insert_before := "func _load_editable_border_stamp("
	var insert_at := text.find(insert_before)
	if insert_at < 0:
		return ERR_DOES_NOT_EXIST
	var sync_function := '''func _sync_derived_hole_corners() -> void:
	# Hole Corner has no independent artwork. It is always the exact inverse of
	# Edge Joint, so geometry, palette and edits can never drift apart.
	for tier in ["easy", "medium", "hard"]:
		corner_images[tier] = CORNER_BUILDER.make_hole_corner_top_left(
			mass_image,
			border_images[tier],
			convex_images[tier]
		)
	border_images["unmineable"] = (border_images["easy"] as Image).duplicate()
	convex_images["unmineable"] = (convex_images["easy"] as Image).duplicate()
	corner_images["unmineable"] = (corner_images["easy"] as Image).duplicate()

'''
	text = text.substr(0, insert_at) + sync_function + text.substr(insert_at)

	text = text.replace(
		"func _refresh_workspace() -> void:\n\tvar visual_tier := _visual_tier()",
		"func _refresh_workspace() -> void:\n\t_sync_derived_hole_corners()\n\tvar visual_tier := _visual_tier()"
	)
	text = text.replace(
		"\telif current_mode == \"corner\":\n\t\tinstruction_label.text = \"Paint this single HOLE CORNER source. The live cave and exported atlas rotate it automatically for top-left, top-right, bottom-right and bottom-left.\"",
		"\telif current_mode == \"corner\":\n\t\tinstruction_label.text = \"DERIVED PREVIEW: this is the exact solid/cave inverse of Edge Joint. Edit EDGE JOINT; Hole Corner updates automatically and rotates four ways.\""
	)
	text = text.replace(
		"\tif current_mode == \"corner\":\n\t\treturn \"%s HOLE CORNER • ONE SOURCE, AUTO-ROTATED 4 WAYS\" % current_tier.to_upper()",
		"\tif current_mode == \"corner\":\n\t\treturn \"%s HOLE CORNER • EXACT INVERSE OF EDGE JOINT\" % current_tier.to_upper()"
	)

	text = text.replace(
		"func _stroke_started(cell: Vector2i, mouse_button: int) -> void:\n\tif not _active_region().has_point(cell):",
		"func _stroke_started(cell: Vector2i, mouse_button: int) -> void:\n\tif current_mode == \"corner\":\n\t\tstatus_label.text = \"Hole Corner is derived. Edit EDGE JOINT to change both matching curves.\"\n\t\treturn\n\tif not _active_region().has_point(cell):"
	)
	text = text.replace(
		"func _apply_brush(cell: Vector2i, mouse_button: int) -> void:\n\tvar erase :=",
		"func _apply_brush(cell: Vector2i, mouse_button: int) -> void:\n\tif current_mode == \"corner\":\n\t\treturn\n\tvar erase :="
	)
	text = text.replace(
		"\tif current_mode == \"corner\":\n\t\tcorner_images[tier] = image\n\telif current_mode == \"convex\":",
		"\tif current_mode == \"corner\":\n\t\treturn\n\telif current_mode == \"convex\":"
	)
	text = text.replace(
		"func _save_sources() -> void:\n\tvar directory_result",
		"func _save_sources() -> void:\n\t_sync_derived_hole_corners()\n\tvar directory_result"
	)
	text = text.replace(
		"func _export_runtime_assets() -> void:\n\tvar directory_result",
		"func _export_runtime_assets() -> void:\n\t_sync_derived_hole_corners()\n\tvar directory_result"
	)
	text = text.replace(
		"Saved one mass, four borders, four edge joints and four editable hole corners.",
		"Saved one mass, four borders, four edge joints and four derived inverse hole corners."
	)
	text = text.replace(
		"Exported four border atlases plus four authored Hole Corner atlases.",
		"Exported four border atlases plus four Edge-Joint-derived Hole Corner atlases."
	)

	return _write_text(WORKBENCH_PATH, text)

func _write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK
