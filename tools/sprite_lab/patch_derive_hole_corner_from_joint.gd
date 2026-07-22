extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _replace_required(text: String, old: String, replacement: String, label: String) -> String:
	if not text.contains(old):
		push_error("Missing derive-hole-corner patch target: %s" % label)
		return ""
	return text.replace(old, replacement)

func _ready() -> void:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)

	text = _replace_required(
		text,
		"\t_add_mode_button(controls, \"corner\", \"HOLE CORNER • opposite diagonal cutout\")\n",
		"",
		"remove separate Hole Corner button"
	)
	if text.is_empty(): return _fail()

	text = text.replace(
		"Each material has a straight border, an EDGE JOINT for two exposed sides, and a separate opposite HOLE CORNER for an empty diagonal.",
		"Each material has one straight border and one EDGE JOINT. The Hole Corner is generated automatically from the same joint rotated 180 degrees."
	)

	var old_load := "func _load_images() -> void:\n\tmass_image = _load_png_or_svg_logical(RUNTIME_MASS_PATH, FALLBACK_MASS_PATH)\n\tborder_images.clear()\n\tcorner_images.clear()\n\tconvex_images.clear()\n\tfor tier in [\"easy\", \"medium\", \"hard\"]:\n\t\tborder_images[tier] = _load_top_stamp(String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))\n\tborder_images[\"unmineable\"] = (border_images[\"easy\"] as Image).duplicate()\n\tfor tier in [\"easy\", \"medium\", \"hard\"]:\n\t\tcorner_images[tier] = _load_corner_stamp(tier, String(RUNTIME_INSIDE_CORNER_PATHS[tier]), border_images[tier])\n\t\tconvex_images[tier] = _load_convex_stamp(tier, border_images[tier])\n\t# Unmineable is visually the Easy family by default for border and both turns.\n\tcorner_images[\"unmineable\"] = (corner_images[\"easy\"] as Image).duplicate()\n\tconvex_images[\"unmineable\"] = (convex_images[\"easy\"] as Image).duplicate()\n"
	var new_load := "func _load_images() -> void:\n\tmass_image = _load_png_or_svg_logical(RUNTIME_MASS_PATH, FALLBACK_MASS_PATH)\n\tborder_images.clear()\n\tcorner_images.clear()\n\tconvex_images.clear()\n\tfor tier in [\"easy\", \"medium\", \"hard\"]:\n\t\tborder_images[tier] = _load_top_stamp(String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))\n\t\tconvex_images[tier] = _load_convex_stamp(tier, border_images[tier])\n\tborder_images[\"unmineable\"] = (border_images[\"easy\"] as Image).duplicate()\n\tconvex_images[\"unmineable\"] = (convex_images[\"easy\"] as Image).duplicate()\n\t_sync_derived_hole_corners()\n\nfunc _sync_derived_hole_corners() -> void:\n\tcorner_images.clear()\n\tfor tier in TIERS:\n\t\t# Hole Corner is exactly the authored Edge Joint in the opposite orientation.\n\t\tcorner_images[tier] = CORNER_BUILDER.rotate_quarters(convex_images[tier], 2)\n"
	text = _replace_required(text, old_load, new_load, "image loading and derived corners")
	if text.is_empty(): return _fail()

	text = _replace_required(
		text,
		"func _refresh_workspace() -> void:\n\tvar base: Image = null",
		"func _refresh_workspace() -> void:\n\t_sync_derived_hole_corners()\n\tvar base: Image = null",
		"live derived-corner sync"
	)
	if text.is_empty(): return _fail()

	text = text.replace(
		"\tvar inner_tier := \"easy\" if current_tier == \"unmineable\" else current_tier\n\tpreview.call(\"set_material_images\", mass_image, border_images[inner_tier], border_images[\"unmineable\"], corner_images[inner_tier], corner_images[\"unmineable\"], convex_images[inner_tier], convex_images[\"unmineable\"])",
		"\tpreview.call(\"set_material_images\", mass_image, border_images[current_tier], border_images[\"unmineable\"], corner_images[current_tier], corner_images[\"unmineable\"], convex_images[current_tier], convex_images[\"unmineable\"])"
	)

	var old_save := "\tfor tier in TIERS:\n\t\tif result == OK:\n\t\t\tresult = (border_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_border_top_32.png\" % tier)\n\t\tif result == OK:\n\t\t\tresult = (corner_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_hole_corner_top_left_32.png\" % tier)\n\t\tif result == OK:\n\t\t\tresult = (convex_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_edge_joint_top_left_32.png\" % tier)\n\tstatus_label.text = \"Saved one mass, four borders, four edge joints and four editable cave corners.\" if result == OK else \"Could not save sources: %s\" % error_string(result)"
	var new_save := "\tfor tier in TIERS:\n\t\tif result == OK:\n\t\t\tresult = (border_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_border_top_32.png\" % tier)\n\t\tif result == OK:\n\t\t\tresult = (convex_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_edge_joint_top_left_32.png\" % tier)\n\tstatus_label.text = \"Saved one mass, four borders and four edge joints. Hole Corners are derived automatically.\" if result == OK else \"Could not save sources: %s\" % error_string(result)"
	text = _replace_required(text, old_save, new_save, "save only authored sources")
	if text.is_empty(): return _fail()

	text = text.replace(
		"Exported four straight-border atlases with authored convex cutouts plus four authored concave-corner atlases.",
		"Exported four border atlases plus Hole Corner atlases derived from the Edge Joints."
	)

	var file := FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write workbench")
		return _fail()
	file.store_string(text)
	file.close()
	print("Hole Corners now derive from Edge Joints rotated 180 degrees")
	get_tree().quit()

func _fail() -> void:
	get_tree().quit(1)
