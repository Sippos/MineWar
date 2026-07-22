extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const CANVAS_PATH := "res://tools/sprite_lab/dome_material_canvas.gd"
const RUNTIME_PATH := "res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd"
const BACKUP_ROOT := "res://tools/sprite_lab/safestates/hole_corner_overscan_before_2026-07-20"

var patch_failed := false

func _replace_once(text: String, old_value: String, new_value: String, label: String) -> String:
	if not text.contains(old_value):
		push_error("Missing patch anchor: " + label)
		patch_failed = true
		return text
	return text.replace(old_value, new_value)

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + path)
		patch_failed = true
		return false
	file.store_string(text)
	file.close()
	return true

func _backup(path: String) -> void:
	var relative := path.trim_prefix("res://")
	var target := BACKUP_ROOT + "/" + relative
	var directory := target.get_base_dir()
	var result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if result != OK and result != ERR_ALREADY_EXISTS:
		push_error("Could not create backup directory " + directory)
		patch_failed = true
		return
	_write(target, FileAccess.get_file_as_string(path))

func _patch_preview() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	text = _replace_once(
		text,
		"const CORNER_PATCH_SIZE := 14",
		"# Hole Corner artwork uses the complete logical cell as an overscan stamp.\n# The actual curve may stay small, but artists can paint beyond the old 14x14 box.\nconst CORNER_PATCH_SIZE := LOGICAL_SIZE",
		"preview Hole Corner overscan size"
	)

	var old_ownership := '''\t# Surgical ownership correction: within a downward face, only that block's
\t# own silhouette may create the projection. The original mask, curve, Hole
\t# Corners and draw order remain unchanged.
\tfor cell_y in range(MAP_SIZE.y):
\t\tfor cell_x in range(MAP_SIZE.x):
\t\t\tvar cell := Vector2i(cell_x, cell_y)
\t\t\tvar owner_type := _cell_type(cell)
\t\t\tif owner_type == CellType.EMPTY or _is_solid(cell + Vector2i.DOWN):
\t\t\t\tcontinue
\t\t\tvar wanted_source := _cell_source_id(cell)
\t\t\tvar origin_x := cell_x * CELL_SIZE
\t\t\tvar face_y := (cell_y + 1) * CELL_SIZE
\t\t\tfor distance_index in range(front_depth):
\t\t\t\tvar world_y := face_y + distance_index
\t\t\t\tif world_y < 0 or world_y >= height:
\t\t\t\t\tbreak
\t\t\t\tfor local_x in range(CELL_SIZE):
\t\t\t\t\tvar world_x := origin_x + local_x
\t\t\t\t\tif world_x < 0 or world_x >= width:
\t\t\t\t\t\tcontinue
\t\t\t\t\tresult.set_pixel(world_x, world_y, Color.TRANSPARENT)
\t\t\t\t\tvar own_distance := 0
\t\t\t\t\tfor step in range(1, front_depth + 1):
\t\t\t\t\t\tvar source_y := world_y - step
\t\t\t\t\t\tif source_y < 0:
\t\t\t\t\t\t\tbreak
\t\t\t\t\t\tvar source_index := source_y * width + world_x
\t\t\t\t\t\tif solid[source_index] != 0 and source_cells[source_index] == wanted_source:
\t\t\t\t\t\t\town_distance = step
\t\t\t\t\t\t\tbreak
\t\t\t\t\tif own_distance > 0:
\t\t\t\t\t\tresult.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, own_distance))
'''
	var new_ownership := '''\t# A downward-open block owns a COMPLETE cell-width front face. Rounded side
\t# silhouettes still generate depth in the first pass, but they may no longer
\t# bite notches out of the front wall at Hole Corners.
\tfor cell_y in range(MAP_SIZE.y):
\t\tfor cell_x in range(MAP_SIZE.x):
\t\t\tvar cell := Vector2i(cell_x, cell_y)
\t\t\tvar owner_type := _cell_type(cell)
\t\t\tif owner_type == CellType.EMPTY or _is_solid(cell + Vector2i.DOWN):
\t\t\t\tcontinue
\t\t\tvar origin_x := cell_x * CELL_SIZE
\t\t\tvar face_y := (cell_y + 1) * CELL_SIZE
\t\t\tfor distance in range(1, front_depth + 1):
\t\t\t\tvar world_y := face_y + distance - 1
\t\t\t\tif world_y < 0 or world_y >= height:
\t\t\t\t\tbreak
\t\t\t\tfor local_x in range(CELL_SIZE):
\t\t\t\t\tvar world_x := origin_x + local_x
\t\t\t\t\tif world_x < 0 or world_x >= width:
\t\t\t\t\t\tcontinue
\t\t\t\t\tresult.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, distance))
'''
	text = _replace_once(text, old_ownership, new_ownership, "preview full-width front ownership")
	text = _replace_once(
		text,
		"\t\t_restore_hole_corner_border_bands(rect, patch_rect, frame, owner_type)\n\t\tdraw_texture_rect(textures[frame], patch_rect, false)",
		"\t\t# Adjacent straight borders remain untouched. The Hole Corner is only an\n\t\t# overlay transition and no longer paints mass bands over its neighbours.\n\t\tdraw_texture_rect(textures[frame], patch_rect, false)",
		"preview non-destructive Hole Corner overlay"
	)
	text = _replace_once(
		text,
		"\t# APPROVED SAFE-STATE ANCHOR. Do not alter without explicit visual approval.",
		"\t# The full-cell stamp keeps the original 3 px vertex overscan anchor."
		,"preview Hole Corner anchor comment"
	)
	_write(PREVIEW_PATH, text)

func _patch_workbench() -> void:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	text = _replace_once(
		text,
		"const CORNER_PATCH_SIZE := 14\nconst HOLE_CORNER_ORIGIN := Vector2i(LOGICAL_SIZE - CORNER_PATCH_SIZE, LOGICAL_SIZE - CORNER_PATCH_SIZE)",
		"const EDGE_JOINT_SIZE := 14\nconst HOLE_CORNER_SIZE := LOGICAL_SIZE\nconst HOLE_CORNER_ORIGIN := Vector2i(LOGICAL_SIZE - HOLE_CORNER_SIZE, LOGICAL_SIZE - HOLE_CORNER_SIZE)",
		"workbench separate edge and Hole Corner sizes"
	)

	var old_loader := '''func _load_hole_corner_stamp(tier: String, edge_joint: Image) -> Image:
\tvar editable_path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
\tvar corner: Image
\tif FileAccess.file_exists(editable_path):
\t\tcorner = Image.load_from_file(ProjectSettings.globalize_path(editable_path))
\telse:
\t\tcorner = CORNER_BUILDER.make_hole_corner_top_left(mass_image, border_images[tier], edge_joint)
\tcorner.convert(Image.FORMAT_RGBA8)
\tcorner.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
\tvar clean := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
\tclean.fill(Color.TRANSPARENT)
\tfor y in range(CORNER_PATCH_SIZE):
\t\tfor x in range(CORNER_PATCH_SIZE):
\t\t\tclean.set_pixel(x, y, corner.get_pixel(x, y))
\treturn clean
'''
	var new_loader := '''func _load_hole_corner_stamp(tier: String, edge_joint: Image) -> Image:
\tvar editable_path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
\tvar corner: Image
\tif FileAccess.file_exists(editable_path):
\t\tcorner = Image.load_from_file(ProjectSettings.globalize_path(editable_path))
\telse:
\t\tcorner = CORNER_BUILDER.make_hole_corner_top_left(mass_image, border_images[tier], edge_joint)
\tcorner.convert(Image.FORMAT_RGBA8)
\tcorner.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
\t# Preserve the complete 32x32 authored stamp. Existing curves stay in the
\t# top-left vertex, while the remaining pixels provide editable overscan.
\treturn corner
'''
	text = _replace_once(text, old_loader, new_loader, "full-cell Hole Corner loader")
	text = _replace_once(
		text,
		"\tif current_mode == \"corner\":\n\t\treturn Rect2i(Vector2i.ZERO, Vector2i(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))\n\tif current_mode == \"convex\":\n\t\treturn Rect2i(Vector2i.ZERO, Vector2i(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))",
		"\tif current_mode == \"corner\":\n\t\treturn Rect2i(Vector2i.ZERO, Vector2i(HOLE_CORNER_SIZE, HOLE_CORNER_SIZE))\n\tif current_mode == \"convex\":\n\t\treturn Rect2i(Vector2i.ZERO, Vector2i(EDGE_JOINT_SIZE, EDGE_JOINT_SIZE))",
		"workbench Hole Corner editable region"
	)
	text = _replace_once(
		text,
		"\t\treturn \"%s HOLE CORNER • EDIT TOP-LEFT ONLY\" % current_tier.to_upper()",
		"\t\treturn \"%s HOLE CORNER • FULL 32x32 OVERSCAN\" % current_tier.to_upper()",
		"workbench Hole Corner title"
	)
	text = _replace_once(
		text,
		"\t\tinstruction_label.text = \"Paint the independent TOP-LEFT HOLE CORNER. It began from the Edge Joint curve, but editing it no longer changes Edge Joint.\"",
		"\t\tinstruction_label.text = \"Paint the independent TOP-LEFT HOLE CORNER on the full 32x32 overscan stamp. The curve keeps its vertex anchor, but you may draw beyond the old 14x14 box.\"",
		"workbench Hole Corner instructions"
	)
	text = _replace_once(text, "range(CORNER_PATCH_SIZE)", "range(HOLE_CORNER_SIZE)", "workbench Hole Corner atlas ranges")
	_write(WORKBENCH_PATH, text)

func _patch_canvas() -> void:
	var text := FileAccess.get_file_as_string(CANVAS_PATH)
	var old_footer := '''\tif _focus_region():
\t\tvar footer := "DERIVED PREVIEW • edit Edge Joint" if read_only else "FULL CANVAS IS EDITABLE • right-click erases"
\t\tdraw_string(ThemeDB.fallback_font, Vector2(8, BOARD_SIZE - 8), footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.html("9ff1ffff"))
'''
	var new_footer := '''\tvar footer := "DERIVED PREVIEW • edit Edge Joint" if read_only else "FULL CANVAS IS EDITABLE • right-click erases"
\tif workspace_label.contains("HOLE CORNER") and not read_only:
\t\tfooter = "FULL 32x32 OVERSCAN IS EDITABLE • right-click erases"
\tdraw_string(ThemeDB.fallback_font, Vector2(8, BOARD_SIZE - 8), footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.html("9ff1ffff"))
'''
	text = _replace_once(text, old_footer, new_footer, "canvas overscan footer")
	_write(CANVAS_PATH, text)

func _patch_runtime() -> void:
	var text := FileAccess.get_file_as_string(RUNTIME_PATH)
	var old_function := '''func _build_extrusion_image(source_id: int, mask: int) -> Image:
\tvar atlas := atlas_images[source_id] as Image
\tvar front := front_images[source_id] as Image
\tvar atlas_position := Vector2i(mask % 4, mask / 4) * TILE_SIZE
\tvar tile := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
\ttile.fill(Color.TRANSPARENT)
\ttile.blit_rect(atlas, Rect2i(atlas_position, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i.ZERO)
\tvar result := Image.create(TILE_SIZE, TILE_SIZE + depth, false, Image.FORMAT_RGBA8)
\tresult.fill(Color.TRANSPARENT)
\tfor y in range(TILE_SIZE + depth):
\t\tfor x in range(TILE_SIZE):
\t\t\tvar shifted_y := y - depth
\t\t\tif shifted_y < 0 or shifted_y >= TILE_SIZE:
\t\t\t\tcontinue
\t\t\tif tile.get_pixel(x, shifted_y).a <= 0.05:
\t\t\t\tcontinue
\t\t\tvar original_alpha := tile.get_pixel(x, y).a if y < TILE_SIZE else 0.0
\t\t\tif original_alpha > 0.05:
\t\t\t\tcontinue
\t\t\tvar sample_y := posmod(y - TILE_SIZE, TILE_SIZE)
\t\t\tvar color := front.get_pixel(x, sample_y)
\t\t\tvar depth_ratio := float(y - TILE_SIZE + 1) / float(maxi(depth, 1))
\t\t\tcolor = color.darkened(0.10 + depth_ratio * 0.18)
\t\t\tcolor.a = 1.0
\t\t\tresult.set_pixel(x, y, color)
\treturn result
'''
	var new_function := '''func _build_extrusion_image(source_id: int, mask: int) -> Image:
\tvar atlas := atlas_images[source_id] as Image
\tvar front := front_images[source_id] as Image
\tvar atlas_position := Vector2i(mask % 4, mask / 4) * TILE_SIZE
\tvar tile := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
\ttile.fill(Color.TRANSPARENT)
\ttile.blit_rect(atlas, Rect2i(atlas_position, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i.ZERO)
\tvar result := Image.create(TILE_SIZE, TILE_SIZE + depth, false, Image.FORMAT_RGBA8)
\tresult.fill(Color.TRANSPARENT)

\t# Keep rounded side/outer silhouette depth behind the main wall.
\tfor y in range(TILE_SIZE + depth):
\t\tfor x in range(TILE_SIZE):
\t\t\tvar shifted_y := y - depth
\t\t\tif shifted_y < 0 or shifted_y >= TILE_SIZE:
\t\t\t\tcontinue
\t\t\tif tile.get_pixel(x, shifted_y).a <= 0.05:
\t\t\t\tcontinue
\t\t\tvar original_alpha := tile.get_pixel(x, y).a if y < TILE_SIZE else 0.0
\t\t\tif original_alpha > 0.05:
\t\t\t\tcontinue
\t\t\tvar sample_y := clampi(y - TILE_SIZE, 0, TILE_SIZE - 1)
\t\t\tvar color := front.get_pixel(x, sample_y)
\t\t\tvar depth_ratio := float(maxi(y - TILE_SIZE + 1, 1)) / float(maxi(depth, 1))
\t\t\tcolor = color.darkened(0.10 + depth_ratio * 0.18)
\t\t\tcolor.a = 1.0
\t\t\tresult.set_pixel(x, y, color)

\t# The downward-facing wall is always the complete tile width. Drawing it last
\t# prevents rounded corner masks from cutting visible notches into the face.
\tfor distance in range(1, depth + 1):
\t\tvar y := TILE_SIZE + distance - 1
\t\tvar sample_y := clampi(roundi(float(distance - 1) * float(TILE_SIZE - 1) / float(maxi(depth - 1, 1))), 0, TILE_SIZE - 1)
\t\tvar depth_ratio := float(distance - 1) / float(maxi(depth - 1, 1))
\t\tfor x in range(TILE_SIZE):
\t\t\tvar color := front.get_pixel(x, sample_y)
\t\t\tcolor = color.darkened(0.10 + depth_ratio * 0.18)
\t\t\tcolor.a = 1.0
\t\t\tresult.set_pixel(x, y, color)
\treturn result
'''
	text = _replace_once(text, old_function, new_function, "runtime full-width front face")
	_write(RUNTIME_PATH, text)

func _ready() -> void:
	for path in [PREVIEW_PATH, WORKBENCH_PATH, CANVAS_PATH, RUNTIME_PATH]:
		_backup(path)
	if patch_failed:
		get_tree().quit(1)
		return
	_patch_preview()
	_patch_workbench()
	_patch_canvas()
	_patch_runtime()
	if patch_failed:
		get_tree().quit(1)
		return
	print("Hole Corner full-cell overscan and full-width front faces applied.")
	get_tree().quit()
