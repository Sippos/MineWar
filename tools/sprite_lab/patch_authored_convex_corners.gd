extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")

func _ready() -> void:
	var ok := _patch_workbench() and _patch_preview() and _create_convex_sources()
	print("Authored convex-corner workspaces installed" if ok else "Authored convex-corner patch failed")
	get_tree().quit(0 if ok else 1)

func _replace_required(text: String, old: String, replacement: String, label: String) -> String:
	if not text.contains(old):
		push_error("Missing patch target: %s" % label)
		return ""
	return text.replace(old, replacement)

func _patch_workbench() -> bool:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	text = _replace_required(text,
		"var corner_images: Dictionary = {}\nvar current_mode := \"border\"",
		"var corner_images: Dictionary = {}\nvar convex_images: Dictionary = {}\nvar current_mode := \"border\"",
		"convex image state")
	if text.is_empty(): return false
	text = _replace_required(text,
		"\t_add_mode_button(controls, \"border\", \"BORDER • one top stamp\")\n\t_add_mode_button(controls, \"corner\", \"CONCAVE CORNER • one top-left stamp\")",
		"\t_add_mode_button(controls, \"border\", \"BORDER • one top stamp\")\n\t_add_mode_button(controls, \"convex\", \"CONVEX CORNER • one top-left cutout\")\n\t_add_mode_button(controls, \"corner\", \"CONCAVE CORNER • one top-left connector\")",
		"convex mode button")
	if text.is_empty(): return false
	text = text.replace(
		"Each material has one straight border and one authored concave corner. UNMINEABLE uses the same dark mass and differs only in gameplay/collision.",
		"Each material has one straight border, one outward CONVEX cutout and one inward CONCAVE connector. UNMINEABLE starts from the exact Easy artwork."
	)
	text = text.replace("Rounded light corners", "Use convex corner sprites")
	var old_load := "func _load_images() -> void:\n\tmass_image = _load_png_or_svg_logical(RUNTIME_MASS_PATH, FALLBACK_MASS_PATH)\n\tborder_images.clear()\n\tcorner_images.clear()\n\tfor tier in [\"easy\", \"medium\", \"hard\"]:\n\t\tborder_images[tier] = _load_top_stamp(String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))\n\t# Unmineable deliberately begins with the exact Easy-rock appearance. It is\n\t# a gameplay property, not a different full block material.\n\tborder_images[\"unmineable\"] = (border_images[\"easy\"] as Image).duplicate()\n\tfor tier in TIERS:\n\t\tcorner_images[tier] = _load_corner_stamp(tier, String(RUNTIME_INSIDE_CORNER_PATHS[tier]), border_images[tier])"
	var new_load := "func _load_images() -> void:\n\tmass_image = _load_png_or_svg_logical(RUNTIME_MASS_PATH, FALLBACK_MASS_PATH)\n\tborder_images.clear()\n\tcorner_images.clear()\n\tconvex_images.clear()\n\tfor tier in [\"easy\", \"medium\", \"hard\"]:\n\t\tborder_images[tier] = _load_top_stamp(String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))\n\tborder_images[\"unmineable\"] = (border_images[\"easy\"] as Image).duplicate()\n\tfor tier in [\"easy\", \"medium\", \"hard\"]:\n\t\tcorner_images[tier] = _load_corner_stamp(tier, String(RUNTIME_INSIDE_CORNER_PATHS[tier]), border_images[tier])\n\t\tconvex_images[tier] = _load_convex_stamp(tier, border_images[tier])\n\t# Unmineable is visually the Easy family by default for border and both turns.\n\tcorner_images[\"unmineable\"] = (corner_images[\"easy\"] as Image).duplicate()\n\tconvex_images[\"unmineable\"] = (convex_images[\"easy\"] as Image).duplicate()"
	text = _replace_required(text, old_load, new_load, "load convex sources")
	if text.is_empty(): return false
	var loader_anchor := "func _make_cave_base() -> Image:\n\tvar image := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)\n\timage.fill(Color.html(\"111725ff\"))\n\treturn image"
	var loader_replacement := "func _load_convex_stamp(tier: String, fallback_border: Image) -> Image:\n\tvar editable_path := SOURCE_DIR + \"/%s_convex_top_left_32.png\" % tier\n\tvar convex: Image\n\tif FileAccess.file_exists(editable_path):\n\t\tconvex = Image.load_from_file(ProjectSettings.globalize_path(editable_path))\n\telse:\n\t\tconvex = CORNER_BUILDER.make_convex_corner_top_left(mass_image, fallback_border)\n\tconvex.convert(Image.FORMAT_RGBA8)\n\tconvex.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)\n\treturn convex\n\nfunc _make_cave_base() -> Image:\n\tvar image := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)\n\timage.fill(Color.html(\"111725ff\"))\n\treturn image\n\nfunc _make_convex_base(tier: String) -> Image:\n\tvar image := CORNER_BUILDER.build_square_composite_tile(mass_image, border_images[tier], 1 | 8)\n\tfor y in range(14):\n\t\tfor x in range(14):\n\t\t\timage.set_pixel(x, y, Color.html(\"111725ff\"))\n\treturn image"
	text = _replace_required(text, loader_anchor, loader_replacement, "convex loader/base")
	if text.is_empty(): return false
	text = _replace_required(text,
		"\tif current_mode == \"corner\":\n\t\treturn corner_images[current_tier]\n\treturn border_images[current_tier]",
		"\tif current_mode == \"corner\":\n\t\treturn corner_images[current_tier]\n\tif current_mode == \"convex\":\n\t\treturn convex_images[current_tier]\n\treturn border_images[current_tier]",
		"active convex image")
	if text.is_empty(): return false
	text = _replace_required(text,
		"\tif current_mode == \"corner\":\n\t\treturn Rect2i(Vector2i.ZERO, Vector2i(14, 14))\n\treturn Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, 11))",
		"\tif current_mode == \"corner\" or current_mode == \"convex\":\n\t\treturn Rect2i(Vector2i.ZERO, Vector2i(14, 14))\n\treturn Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, 11))",
		"convex edit region")
	if text.is_empty(): return false
	text = _replace_required(text,
		"\tif current_mode == \"corner\":\n\t\treturn \"%s CONCAVE CORNER • AUTHOR TOP-LEFT ONLY\" % current_tier.to_upper()\n\treturn \"%s BORDER • AUTHOR TOP ONLY\" % current_tier.to_upper()",
		"\tif current_mode == \"convex\":\n\t\treturn \"%s CONVEX CORNER • AUTHOR TOP-LEFT ONLY\" % current_tier.to_upper()\n\tif current_mode == \"corner\":\n\t\treturn \"%s CONCAVE CORNER • AUTHOR TOP-LEFT ONLY\" % current_tier.to_upper()\n\treturn \"%s BORDER • AUTHOR TOP ONLY\" % current_tier.to_upper()",
		"convex workspace title")
	if text.is_empty(): return false
	var old_refresh := "\tif current_mode == \"border\":\n\t\tbase = mass_image\n\telif current_mode == \"corner\":\n\t\tbase = _make_cave_base()\n\tcanvas.call(\"set_workspace_images\", _active_image(), base, _active_region(), _workspace_title())\n\tvar inner_tier := \"easy\" if current_tier == \"unmineable\" else current_tier\n\tpreview.call(\"set_material_images\", mass_image, border_images[inner_tier], border_images[\"unmineable\"], corner_images[inner_tier], corner_images[\"unmineable\"])"
	var new_refresh := "\tif current_mode == \"border\":\n\t\tbase = mass_image\n\telif current_mode == \"corner\":\n\t\tbase = _make_cave_base()\n\telif current_mode == \"convex\":\n\t\tbase = _make_convex_base(current_tier)\n\tcanvas.call(\"set_workspace_images\", _active_image(), base, _active_region(), _workspace_title())\n\tvar inner_tier := \"easy\" if current_tier == \"unmineable\" else current_tier\n\tpreview.call(\"set_material_images\", mass_image, border_images[inner_tier], border_images[\"unmineable\"], corner_images[inner_tier], corner_images[\"unmineable\"], convex_images[inner_tier], convex_images[\"unmineable\"])"
	text = _replace_required(text, old_refresh, new_refresh, "preview convex inputs")
	if text.is_empty(): return false
	text = _replace_required(text,
		"\telif current_mode == \"corner\":\n\t\tinstruction_label.text = \"Paint one TOP-LEFT concave connector inside the cyan square. The game rotates it for the other three dirt-facing turns.\"\n\telse:\n\t\tinstruction_label.text = \"Paint only the CYAN TOP BAND. The game rotates it for all four straight edges and convex outer corners.\"",
		"\telif current_mode == \"convex\":\n\t\tinstruction_label.text = \"Paint the TOP-LEFT outward rounded cutout. Transparent pixels carve the cave; painted pixels contain the complete rock rim and mass for this corner.\"\n\telif current_mode == \"corner\":\n\t\tinstruction_label.text = \"Paint one TOP-LEFT inward concave connector. The game rotates it for the other three dirt-facing turns.\"\n\telse:\n\t\tinstruction_label.text = \"Paint only the CYAN TOP BAND. The game rotates it for all four straight edges.\"",
		"convex instructions")
	if text.is_empty(): return false
	text = _replace_required(text,
		"\telif current_mode == \"corner\":\n\t\tcorner_images[current_tier] = image\n\telse:\n\t\tborder_images[current_tier] = image",
		"\telif current_mode == \"corner\":\n\t\tcorner_images[current_tier] = image\n\telif current_mode == \"convex\":\n\t\tconvex_images[current_tier] = image\n\telse:\n\t\tborder_images[current_tier] = image",
		"set convex image")
	if text.is_empty(): return false
	text = _replace_required(text,
		"\t\tif result == OK:\n\t\t\tresult = (corner_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_corner_top_left_32.png\" % tier)\n\tstatus_label.text = \"Saved one mass, four borders and four authored concave corners.\" if result == OK else \"Could not save sources: %s\" % error_string(result)",
		"\t\tif result == OK:\n\t\t\tresult = (corner_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_corner_top_left_32.png\" % tier)\n\t\tif result == OK:\n\t\t\tresult = (convex_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_convex_top_left_32.png\" % tier)\n\tstatus_label.text = \"Saved one mass, four borders, four convex corners and four concave corners.\" if result == OK else \"Could not save sources: %s\" % error_string(result)",
		"save convex sources")
	if text.is_empty(): return false
	text = _replace_required(text,
		"\t\tvar atlas := _build_border_atlas(border_images[tier])",
		"\t\tvar atlas := _build_border_atlas(border_images[tier], convex_images[tier])",
		"export convex border atlas")
	if text.is_empty(): return false
	text = text.replace(
		"Exported four composite border atlases plus four authored concave-corner atlases.",
		"Exported four straight-border atlases with authored convex cutouts plus four authored concave-corner atlases."
	)
	text = _replace_required(text,
		"func _build_border_atlas(top_stamp: Image) -> Image:\n\t# The exported atlas now contains the universal mass and genuine transparent\n\t# quarter-circle cutouts. It is the exact same generator used by the preview.\n\treturn CORNER_BUILDER.build_composite_atlas(mass_image, top_stamp)",
		"func _build_border_atlas(top_stamp: Image, convex_top_left: Image) -> Image:\n\t# The authored convex replacement patch supplies the real alpha cutout and\n\t# rounded rim. It is rotated into all four outward corners automatically.\n\treturn CORNER_BUILDER.build_composite_atlas(mass_image, top_stamp, convex_top_left)",
		"authored convex atlas builder")
	if text.is_empty(): return false
	var file := FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write workbench")
		return false
	file.store_string(text)
	file.close()
	return true

func _patch_preview() -> bool:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	text = _replace_required(text,
		"var unmineable_corner_image: Image\nvar selected_composite_textures",
		"var unmineable_corner_image: Image\nvar selected_convex_image: Image\nvar unmineable_convex_image: Image\nvar selected_composite_textures",
		"preview convex state")
	if text.is_empty(): return false
	var old_signature := "func set_material_images(new_mass_image: Image, selected_top_border: Image, unmineable_top_border: Image, selected_top_left_corner: Image, unmineable_top_left_corner: Image) -> void:\n\tmass_image = new_mass_image.duplicate()\n\tselected_border_image = selected_top_border.duplicate()\n\tunmineable_border_image = unmineable_top_border.duplicate()\n\tselected_corner_image = selected_top_left_corner.duplicate()\n\tunmineable_corner_image = unmineable_top_left_corner.duplicate()\n\t_rebuild_material_textures()"
	var new_signature := "func set_material_images(new_mass_image: Image, selected_top_border: Image, unmineable_top_border: Image, selected_top_left_corner: Image, unmineable_top_left_corner: Image, selected_top_left_convex: Image, unmineable_top_left_convex: Image) -> void:\n\tmass_image = new_mass_image.duplicate()\n\tselected_border_image = selected_top_border.duplicate()\n\tunmineable_border_image = unmineable_top_border.duplicate()\n\tselected_corner_image = selected_top_left_corner.duplicate()\n\tunmineable_corner_image = unmineable_top_left_corner.duplicate()\n\tselected_convex_image = selected_top_left_convex.duplicate()\n\tunmineable_convex_image = unmineable_top_left_convex.duplicate()\n\t_rebuild_material_textures()"
	text = _replace_required(text, old_signature, new_signature, "preview convex signature")
	if text.is_empty(): return false
	text = _replace_required(text,
		"\t\tselected_composite_textures = CORNER_BUILDER.build_composite_textures(mass_image, selected_border_image)\n\t\tunmineable_composite_textures = CORNER_BUILDER.build_composite_textures(mass_image, unmineable_border_image)",
		"\t\tselected_composite_textures = CORNER_BUILDER.build_composite_textures(mass_image, selected_border_image, selected_convex_image)\n\t\tunmineable_composite_textures = CORNER_BUILDER.build_composite_textures(mass_image, unmineable_border_image, unmineable_convex_image)",
		"preview authored convex textures")
	if text.is_empty(): return false
	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write preview")
		return false
	file.store_string(text)
	file.close()
	return true

func _create_convex_sources() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOURCE_DIR))
	var generated: Dictionary = {}
	var mass_path := SOURCE_DIR + "/dark_mass_32.png"
	if not FileAccess.file_exists(mass_path):
		push_error("Missing dark mass source")
		return false
	var mass := Image.load_from_file(ProjectSettings.globalize_path(mass_path))
	mass.convert(Image.FORMAT_RGBA8)
	mass.resize(32, 32, Image.INTERPOLATE_NEAREST)
	for tier in ["easy", "medium", "hard"]:
		var border_path := SOURCE_DIR + "/%s_border_top_32.png" % tier
		if not FileAccess.file_exists(border_path):
			push_error("Missing border source for %s" % tier)
			return false
		var border := Image.load_from_file(ProjectSettings.globalize_path(border_path))
		border.convert(Image.FORMAT_RGBA8)
		border.resize(32, 32, Image.INTERPOLATE_NEAREST)
		var convex := BUILDER.make_convex_corner_top_left(mass, border)
		if convex.save_png(SOURCE_DIR + "/%s_convex_top_left_32.png" % tier) != OK:
			return false
		generated[tier] = convex
	var easy_convex := generated["easy"] as Image
	if easy_convex.save_png(SOURCE_DIR + "/unmineable_convex_top_left_32.png") != OK:
		return false
	# Keep the full unmineable family initialized from Easy as requested.
	for suffix in ["border_top_32.png", "corner_top_left_32.png"]:
		var easy_path := SOURCE_DIR + "/easy_%s" % suffix
		var unmineable_path := SOURCE_DIR + "/unmineable_%s" % suffix
		if FileAccess.file_exists(easy_path):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(easy_path), ProjectSettings.globalize_path(unmineable_path))
	return true
