extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _required_replace(text: String, old: String, replacement: String, label: String) -> String:
	if not text.contains(old):
		push_error("Missing editable-hole-corner patch target: %s" % label)
		return ""
	return text.replace(old, replacement)

func _ready() -> void:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)

	text = _required_replace(
		text,
		"\t_add_mode_button(controls, \"convex\", \"EDGE JOINT • exposed block turn\")\n",
		"\t_add_mode_button(controls, \"convex\", \"EDGE JOINT • exposed block turn\")\n\t_add_mode_button(controls, \"corner\", \"HOLE CORNER • opposite turn\")\n",
		"hole corner mode button"
	)
	if text.is_empty(): return _fail()

	text = _required_replace(
		text,
		"\ttier_note.text = \"Each material has one straight border and one EDGE JOINT. The Hole Corner is generated automatically from the same joint rotated 180 degrees.\"",
		"\ttier_note.text = \"Each material has one straight border, one EDGE JOINT and one editable HOLE CORNER. New Hole Corners start as the Edge Joint rotated 180 degrees.\"",
		"tier note"
	)
	if text.is_empty(): return _fail()

	var old_load := "func _load_images() -> void:\n\tmass_image = _load_png_or_svg_logical(RUNTIME_MASS_PATH, FALLBACK_MASS_PATH)\n\tborder_images.clear()\n\tcorner_images.clear()\n\tconvex_images.clear()\n\tfor tier in [\"easy\", \"medium\", \"hard\"]:\n\t\tborder_images[tier] = _load_top_stamp(String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))\n\t\tconvex_images[tier] = _load_convex_stamp(tier, border_images[tier])\n\tborder_images[\"unmineable\"] = (border_images[\"easy\"] as Image).duplicate()\n\tconvex_images[\"unmineable\"] = (convex_images[\"easy\"] as Image).duplicate()\n\t_sync_derived_hole_corners()\n\nfunc _sync_derived_hole_corners() -> void:\n\tcorner_images.clear()\n\tfor tier in TIERS:\n\t\t# Hole Corner is exactly the authored Edge Joint in the opposite orientation.\n\t\tcorner_images[tier] = CORNER_BUILDER.rotate_quarters(convex_images[tier], 2)"
	var new_load := "func _load_images() -> void:\n\tmass_image = _load_png_or_svg_logical(RUNTIME_MASS_PATH, FALLBACK_MASS_PATH)\n\tborder_images.clear()\n\tcorner_images.clear()\n\tconvex_images.clear()\n\tfor tier in [\"easy\", \"medium\", \"hard\"]:\n\t\tborder_images[tier] = _load_top_stamp(String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))\n\t\tconvex_images[tier] = _load_convex_stamp(tier, border_images[tier])\n\t\tcorner_images[tier] = _load_hole_corner_stamp(tier, convex_images[tier])\n\tborder_images[\"unmineable\"] = (border_images[\"easy\"] as Image).duplicate()\n\tconvex_images[\"unmineable\"] = (convex_images[\"easy\"] as Image).duplicate()\n\tcorner_images[\"unmineable\"] = _load_hole_corner_stamp(\"unmineable\", convex_images[\"unmineable\"])\n\nfunc _load_hole_corner_stamp(tier: String, edge_joint: Image) -> Image:\n\tvar editable_path := SOURCE_DIR + \"/%s_hole_corner_top_left_32.png\" % tier\n\tvar corner: Image\n\tif FileAccess.file_exists(editable_path):\n\t\tcorner = Image.load_from_file(ProjectSettings.globalize_path(editable_path))\n\telse:\n\t\t# First-time starter only: use the exact Edge Joint in the opposite orientation.\n\t\tcorner = CORNER_BUILDER.rotate_quarters(edge_joint, 2)\n\tcorner.convert(Image.FORMAT_RGBA8)\n\tcorner.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)\n\treturn corner"
	text = _required_replace(text, old_load, new_load, "independent hole corner loading")
	if text.is_empty(): return _fail()

	text = _required_replace(
		text,
		"func _refresh_workspace() -> void:\n\t_sync_derived_hole_corners()\n",
		"func _refresh_workspace() -> void:\n",
		"stop resyncing edited corners"
	)
	if text.is_empty(): return _fail()

	text = _required_replace(
		text,
		"\t\tif result == OK:\n\t\t\tresult = (convex_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_edge_joint_top_left_32.png\" % tier)\n\tstatus_label.text = \"Saved one mass, four borders and four edge joints. Hole Corners are derived automatically.\" if result == OK else \"Could not save sources: %s\" % error_string(result)",
		"\t\tif result == OK:\n\t\t\tresult = (convex_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_edge_joint_top_left_32.png\" % tier)\n\t\tif result == OK:\n\t\t\tresult = (corner_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_hole_corner_top_left_32.png\" % tier)\n\tstatus_label.text = \"Saved one mass, four borders, four edge joints and four editable hole corners.\" if result == OK else \"Could not save sources: %s\" % error_string(result)",
		"save independent hole corner sources"
	)
	if text.is_empty(): return _fail()

	text = text.replace(
		"Exported four border atlases plus Hole Corner atlases derived from the Edge Joints.",
		"Exported four border atlases plus four authored Hole Corner atlases."
	)

	var file := FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write editable Hole Corner workbench")
		return _fail()
	file.store_string(text)
	file.close()
	print("Editable Hole Corner workspace restored; starter is Edge Joint rotated 180 degrees")
	get_tree().quit()

func _fail() -> void:
	get_tree().quit(1)
