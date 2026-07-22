extends Node

const BUILDER = preload("res://tools/sprite_lab/dome_corner_builder.gd")
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const CANVAS_PATH := "res://tools/sprite_lab/dome_material_canvas.gd"
const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const TIERS: Array[String] = ["easy", "medium", "hard"]

func _ready() -> void:
	var error := _regenerate_sources()
	if error != OK:
		push_error("Could not regenerate inverse Hole Corners: %s" % error_string(error))
		get_tree().quit(1)
		return
	error = _patch_read_only_canvas()
	if error != OK:
		push_error("Could not patch read-only Hole Corner canvas: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("Verified exact inverse Hole Corners and locked derived preview")
	get_tree().quit()

func _regenerate_sources() -> Error:
	var mass := _load_image(SOURCE_DIR + "/dark_mass_32.png")
	if mass == null:
		return ERR_FILE_NOT_FOUND
	var easy_corner: Image = null
	for tier in TIERS:
		var border := _load_image(SOURCE_DIR + "/%s_border_top_32.png" % tier)
		var joint := _load_image(SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % tier)
		if border == null or joint == null:
			return ERR_FILE_NOT_FOUND
		var corner: Image = BUILDER.make_hole_corner_top_left(mass, border, joint)
		if not _is_exact_inverse(joint, corner):
			return ERR_INVALID_DATA
		var result := corner.save_png(SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier)
		if result != OK:
			return result
		if tier == "easy":
			easy_corner = corner.duplicate()
	if easy_corner == null:
		return ERR_INVALID_DATA
	return easy_corner.save_png(SOURCE_DIR + "/unmineable_hole_corner_top_left_32.png")

func _load_image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != 32 or image.get_height() != 32:
		image.resize(32, 32, Image.INTERPOLATE_NEAREST)
	return image

func _is_exact_inverse(joint: Image, corner: Image) -> bool:
	for y in range(14):
		for x in range(14):
			var joint_solid := joint.get_pixel(x, y).a > 0.05
			var corner_solid := corner.get_pixel(x, y).a > 0.05
			if joint_solid == corner_solid:
				return false
	return true

func _patch_read_only_canvas() -> Error:
	var canvas := FileAccess.get_file_as_string(CANVAS_PATH)
	var workbench := FileAccess.get_file_as_string(WORKBENCH_PATH)
	if canvas.is_empty() or workbench.is_empty():
		return ERR_FILE_CANT_READ

	if not canvas.contains("var read_only: bool = false"):
		canvas = canvas.replace(
			"var workspace_label: String = \"\"",
			"var workspace_label: String = \"\"\nvar read_only: bool = false"
		)
		canvas = canvas.replace(
			"func set_grid_visible(value: bool) -> void:",
			"func set_read_only(value: bool) -> void:\n\tread_only = value\n\tqueue_redraw()\n\nfunc set_grid_visible(value: bool) -> void:"
		)
		canvas = canvas.replace(
			"\tif _focus_region():\n\t\tdraw_string(ThemeDB.fallback_font, Vector2(8, BOARD_SIZE - 8), \"FULL CANVAS IS EDITABLE • right-click erases\", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.html(\"9ff1ffff\"))",
			"\tif _focus_region():\n\t\tvar footer := \"DERIVED PREVIEW • edit Edge Joint\" if read_only else \"FULL CANVAS IS EDITABLE • right-click erases\"\n\t\tdraw_string(ThemeDB.fallback_font, Vector2(8, BOARD_SIZE - 8), footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.html(\"9ff1ffff\"))"
		)
		canvas = canvas.replace(
			"func _gui_input(event: InputEvent) -> void:\n\tif event is InputEventMouseMotion:",
			"func _gui_input(event: InputEvent) -> void:\n\tif read_only:\n\t\taccept_event()\n\t\treturn\n\tif event is InputEventMouseMotion:"
		)

	if not workbench.contains("canvas.call(\"set_read_only\""):
		workbench = workbench.replace(
			"\tcanvas.call(\"set_workspace_images\", _active_image(), base, _active_region(), _workspace_title())",
			"\tcanvas.call(\"set_read_only\", current_mode == \"corner\")\n\tcanvas.call(\"set_workspace_images\", _active_image(), base, _active_region(), _workspace_title())"
		)
		workbench = workbench.replace(
			"HOLE CORNER • one sprite, rotated 4 ways",
			"HOLE CORNER • derived inverse of Edge Joint"
		)
		workbench = workbench.replace(
			"Each material has one straight border, one EDGE JOINT and one HOLE CORNER source. Paint the Hole Corner once; preview and export rotate that same sprite into all four directions automatically.",
			"Each material has one straight border and one EDGE JOINT. HOLE CORNER is generated automatically as the exact solid/cave inverse of that Edge Joint and rotated four ways."
		)

	var canvas_file := FileAccess.open(CANVAS_PATH, FileAccess.WRITE)
	if canvas_file == null:
		return FileAccess.get_open_error()
	canvas_file.store_string(canvas)
	canvas_file.close()
	var workbench_file := FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE)
	if workbench_file == null:
		return FileAccess.get_open_error()
	workbench_file.store_string(workbench)
	workbench_file.close()
	return OK
