extends Node

const PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _replace_once(text: String, old: String, replacement: String, label: String) -> String:
	if not text.contains(old):
		push_error("Missing patch anchor: %s" % label)
		return ""
	return text.replace(old, replacement)

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		push_error("Could not read workbench")
		get_tree().quit(1)
		return

	text = _replace_once(text,
		"const PREVIEW_SCRIPT := preload(\"res://tools/sprite_lab/dome_material_preview.gd\")",
		"const PREVIEW_SCRIPT := preload(\"res://tools/sprite_lab/dome_material_preview_v2.gd\")",
		"preview v2")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"const RUNTIME_INSIDE_CORNER_PATHS := {\n\t\"unmineable\": RUNTIME_DIR + \"/Unmineable_Inside_Corners.png\",\n\t\"easy\": RUNTIME_DIR + \"/Easy_Inside_Corners.png\",\n\t\"medium\": RUNTIME_DIR + \"/Medium_Inside_Corners.png\",\n\t\"hard\": RUNTIME_DIR + \"/Hard_Inside_Corners.png\",\n}",
		"const RUNTIME_INSIDE_CORNER_PATHS := {\n\t\"unmineable\": RUNTIME_DIR + \"/Unmineable_Inside_Corners.png\",\n\t\"easy\": RUNTIME_DIR + \"/Easy_Inside_Corners.png\",\n\t\"medium\": RUNTIME_DIR + \"/Medium_Inside_Corners.png\",\n\t\"hard\": RUNTIME_DIR + \"/Hard_Inside_Corners.png\",\n}\nconst FRONT_SOURCE_PATHS := {\n\t\"unmineable\": \"res://assets/sprites/world/terrain/front_walls/Easy_Brick-Front.png\",\n\t\"easy\": \"res://assets/sprites/world/terrain/front_walls/Easy_Brick-Front.png\",\n\t\"medium\": \"res://assets/sprites/world/terrain/front_walls/Medium-Brick-Front.png\",\n\t\"hard\": \"res://assets/sprites/world/terrain/front_walls/Hard-Brick-Front.png\",\n}\nconst RUNTIME_FRONT_PATHS := {\n\t\"unmineable\": RUNTIME_DIR + \"/Unmineable_Front_Face.png\",\n\t\"easy\": RUNTIME_DIR + \"/Easy_Front_Face.png\",\n\t\"medium\": RUNTIME_DIR + \"/Medium_Front_Face.png\",\n\t\"hard\": RUNTIME_DIR + \"/Hard_Front_Face.png\",\n}",
		"front paths")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"var convex_images: Dictionary = {}",
		"var convex_images: Dictionary = {}\nvar front_images: Dictionary = {}",
		"front images var")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"\t_add_mode_button(controls, \"corner\", \"HOLE CORNER • editable opposite turn\")",
		"\t_add_mode_button(controls, \"corner\", \"HOLE CORNER • editable opposite turn\")\n\t_add_mode_button(controls, \"front\", \"FRONT FACE • downward wall\")",
		"front mode button")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"\tvar reset_button := Button.new()",
		"\tvar preview_brush := OptionButton.new()\n\tfor brush_name in [\"DIG / EMPTY\", \"PAINT EASY\", \"PAINT MEDIUM\", \"PAINT HARD\", \"PAINT UNMINEABLE\"]:\n\t\tpreview_brush.add_item(brush_name)\n\tpreview_brush.item_selected.connect(func(index: int) -> void: preview.call(\"set_preview_brush\", index))\n\tcontrols.add_child(preview_brush)\n\tvar reset_button := Button.new()",
		"preview brush")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"\tcorner_images.clear()\n\tconvex_images.clear()",
		"\tcorner_images.clear()\n\tconvex_images.clear()\n\tfront_images.clear()",
		"clear fronts")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"\t\tcorner_images[tier] = _load_hole_corner_stamp(tier, convex_images[tier])",
		"\t\tcorner_images[tier] = _load_hole_corner_stamp(tier, convex_images[tier])\n\t\tfront_images[tier] = _load_front_face_stamp(tier)",
		"load fronts")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"\tcorner_images[\"unmineable\"] = (corner_images[\"easy\"] as Image).duplicate()",
		"\tcorner_images[\"unmineable\"] = (corner_images[\"easy\"] as Image).duplicate()\n\tfront_images[\"unmineable\"] = (front_images[\"easy\"] as Image).duplicate()",
		"unmineable front")
	if text.is_empty(): get_tree().quit(1); return

	var load_front_func := '''
func _load_front_face_stamp(tier: String) -> Image:
	var editable_path := SOURCE_DIR + "/%s_front_face_32.png" % tier
	var path := editable_path if FileAccess.file_exists(editable_path) else String(FRONT_SOURCE_PATHS[tier])
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		image = Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
	else:
		image.convert(Image.FORMAT_RGBA8)
		image.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return image

'''
	text = _replace_once(text,
		"func _load_editable_border_stamp(tier: String, runtime_path: String, fallback_path: String) -> Image:",
		load_front_func + "func _load_editable_border_stamp(tier: String, runtime_path: String, fallback_path: String) -> Image:",
		"front loader func")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"\tif current_mode == \"corner\":\n\t\treturn corner_images[tier]",
		"\tif current_mode == \"corner\":\n\t\treturn corner_images[tier]\n\tif current_mode == \"front\":\n\t\treturn front_images[tier]",
		"active front")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"\tif current_mode == \"convex\":\n\t\treturn Rect2i(Vector2i.ZERO, Vector2i(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))",
		"\tif current_mode == \"convex\":\n\t\treturn Rect2i(Vector2i.ZERO, Vector2i(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))\n\tif current_mode == \"front\":\n\t\treturn Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))",
		"front region")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"\tif current_mode == \"corner\":\n\t\treturn \"%s HOLE CORNER • EDIT TOP-LEFT ONLY\" % current_tier.to_upper()",
		"\tif current_mode == \"corner\":\n\t\treturn \"%s HOLE CORNER • EDIT TOP-LEFT ONLY\" % current_tier.to_upper()\n\tif current_mode == \"front\":\n\t\treturn \"%s FRONT FACE • AUTHOR DOWNWARD WALL\" % current_tier.to_upper()",
		"front title")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"\telif current_mode == \"convex\":\n\t\tbase = _make_convex_base(visual_tier)",
		"\telif current_mode == \"convex\":\n\t\tbase = _make_convex_base(visual_tier)\n\telif current_mode == \"front\":\n\t\tbase = mass_image",
		"front base")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"\tpreview.call(\"set_material_images\", mass_image, border_images[visual_tier], border_images[\"easy\"], corner_images[visual_tier], corner_images[\"easy\"], convex_images[visual_tier], convex_images[\"easy\"])",
		"\tpreview.call(\"set_material_library\", mass_image, border_images, corner_images, convex_images, front_images)",
		"preview library")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"\telif current_mode == \"corner\":\n\t\tinstruction_label.text = \"Paint the independent TOP-LEFT HOLE CORNER. It began from the Edge Joint curve, but editing it no longer changes Edge Joint.\"",
		"\telif current_mode == \"corner\":\n\t\tinstruction_label.text = \"Paint the independent TOP-LEFT HOLE CORNER. It began from the Edge Joint curve, but editing it no longer changes Edge Joint.\"\n\telif current_mode == \"front\":\n\t\tinstruction_label.text = \"Paint the complete downward-facing FRONT FACE for this material. It appears below exposed blocks in the mixed-material preview.\"",
		"front instruction")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"\telif current_mode == \"convex\":\n\t\tconvex_images[tier] = image\n\telse:",
		"\telif current_mode == \"convex\":\n\t\tconvex_images[tier] = image\n\telif current_mode == \"front\":\n\t\tfront_images[tier] = image\n\telse:",
		"set front image")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"\t\tif result == OK:\n\t\t\tresult = (corner_images[source_tier] as Image).save_png(SOURCE_DIR + \"/%s_hole_corner_top_left_32.png\" % tier)",
		"\t\tif result == OK:\n\t\t\tresult = (corner_images[source_tier] as Image).save_png(SOURCE_DIR + \"/%s_hole_corner_top_left_32.png\" % tier)\n\t\tif result == OK:\n\t\t\tresult = (front_images[source_tier] as Image).save_png(SOURCE_DIR + \"/%s_front_face_32.png\" % tier)",
		"save fronts")
	if text.is_empty(): get_tree().quit(1); return

	text = _replace_once(text,
		"\t\tif result == OK:\n\t\t\tvar corner_atlas := _build_inside_corner_atlas(corner_images[source_tier], border_images[source_tier])\n\t\t\tresult = corner_atlas.save_png(String(RUNTIME_INSIDE_CORNER_PATHS[tier]))",
		"\t\tif result == OK:\n\t\t\tvar corner_atlas := _build_inside_corner_atlas(corner_images[source_tier], border_images[source_tier])\n\t\t\tresult = corner_atlas.save_png(String(RUNTIME_INSIDE_CORNER_PATHS[tier]))\n\t\tif result == OK:\n\t\t\tvar front_export := (front_images[source_tier] as Image).duplicate()\n\t\t\tfront_export.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)\n\t\t\tresult = front_export.save_png(String(RUNTIME_FRONT_PATHS[tier]))",
		"export fronts")
	if text.is_empty(): get_tree().quit(1); return

	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write workbench")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Upgraded Dome workbench with mixed materials and front-face authoring")
	get_tree().quit()
