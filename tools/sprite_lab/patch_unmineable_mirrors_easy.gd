extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	if text.is_empty():
		push_error("Could not read Dome Material Workbench")
		get_tree().quit(1)
		return

	var replacements := [
		[
			"\tborder_images[\"unmineable\"] = _load_editable_border_stamp(\"unmineable\", String(RUNTIME_BORDER_PATHS[\"unmineable\"]), FALLBACK_UNMINEABLE_PATH)\n\tconvex_images[\"unmineable\"] = _load_convex_stamp(\"unmineable\", border_images[\"unmineable\"])\n\tcorner_images[\"unmineable\"] = _load_hole_corner_stamp(\"unmineable\", convex_images[\"unmineable\"])",
			"\t# Unmineable is a gameplay property, not a separate visual material.\n\t# It permanently mirrors the Easy art so it can never drift or load stale pixels.\n\tborder_images[\"unmineable\"] = (border_images[\"easy\"] as Image).duplicate()\n\tconvex_images[\"unmineable\"] = (convex_images[\"easy\"] as Image).duplicate()\n\tcorner_images[\"unmineable\"] = (corner_images[\"easy\"] as Image).duplicate()"
		],
		[
			"func _active_image() -> Image:\n\tif current_mode == \"mass\":\n\t\treturn mass_image\n\tif current_mode == \"corner\":\n\t\treturn corner_images[current_tier]\n\tif current_mode == \"convex\":\n\t\treturn convex_images[current_tier]\n\treturn border_images[current_tier]",
			"func _visual_tier() -> String:\n\treturn \"easy\" if current_tier == \"unmineable\" else current_tier\n\nfunc _active_image() -> Image:\n\tif current_mode == \"mass\":\n\t\treturn mass_image\n\tvar tier := _visual_tier()\n\tif current_mode == \"corner\":\n\t\treturn corner_images[tier]\n\tif current_mode == \"convex\":\n\t\treturn convex_images[tier]\n\treturn border_images[tier]"
		],
		[
			"func _refresh_workspace() -> void:\n\tvar base: Image = null\n\tif current_mode == \"border\":\n\t\tbase = mass_image\n\telif current_mode == \"corner\":\n\t\tbase = _make_cave_base()\n\telif current_mode == \"convex\":\n\t\tbase = _make_convex_base(current_tier)\n\tcanvas.call(\"set_workspace_images\", _active_image(), base, _active_region(), _workspace_title())\n\tpreview.call(\"set_material_images\", mass_image, border_images[current_tier], border_images[\"unmineable\"], corner_images[current_tier], corner_images[\"unmineable\"], convex_images[current_tier], convex_images[\"unmineable\"])",
			"func _refresh_workspace() -> void:\n\tvar visual_tier := _visual_tier()\n\tvar base: Image = null\n\tif current_mode == \"border\":\n\t\tbase = mass_image\n\telif current_mode == \"corner\":\n\t\tbase = _make_cave_base()\n\telif current_mode == \"convex\":\n\t\tbase = _make_convex_base(visual_tier)\n\tcanvas.call(\"set_workspace_images\", _active_image(), base, _active_region(), _workspace_title())\n\tpreview.call(\"set_material_images\", mass_image, border_images[visual_tier], border_images[\"easy\"], corner_images[visual_tier], corner_images[\"easy\"], convex_images[visual_tier], convex_images[\"easy\"])"
		],
		[
			"func _set_active_image(image: Image) -> void:\n\tif current_mode == \"mass\":\n\t\tmass_image = image\n\telif current_mode == \"corner\":\n\t\tcorner_images[current_tier] = image\n\telif current_mode == \"convex\":\n\t\tconvex_images[current_tier] = image\n\telse:\n\t\tborder_images[current_tier] = image",
			"func _set_active_image(image: Image) -> void:\n\tif current_mode == \"mass\":\n\t\tmass_image = image\n\t\treturn\n\tvar tier := _visual_tier()\n\tif current_mode == \"corner\":\n\t\tcorner_images[tier] = image\n\telif current_mode == \"convex\":\n\t\tconvex_images[tier] = image\n\telse:\n\t\tborder_images[tier] = image"
		],
		[
			"\tfor tier in TIERS:\n\t\tif result == OK:\n\t\t\tresult = (border_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_border_top_32.png\" % tier)\n\t\tif result == OK:\n\t\t\tresult = (convex_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_edge_joint_top_left_32.png\" % tier)\n\t\tif result == OK:\n\t\t\tresult = (corner_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_hole_corner_top_left_32.png\" % tier)",
			"\tfor tier in TIERS:\n\t\tvar source_tier := \"easy\" if tier == \"unmineable\" else tier\n\t\tif result == OK:\n\t\t\tresult = (border_images[source_tier] as Image).save_png(SOURCE_DIR + \"/%s_border_top_32.png\" % tier)\n\t\tif result == OK:\n\t\t\tresult = (convex_images[source_tier] as Image).save_png(SOURCE_DIR + \"/%s_edge_joint_top_left_32.png\" % tier)\n\t\tif result == OK:\n\t\t\tresult = (corner_images[source_tier] as Image).save_png(SOURCE_DIR + \"/%s_hole_corner_top_left_32.png\" % tier)"
		],
		[
			"\tfor tier in TIERS:\n\t\tif result != OK:\n\t\t\tbreak\n\t\tvar atlas := _build_border_atlas(border_images[tier], convex_images[tier])\n\t\tresult = atlas.save_png(String(RUNTIME_BORDER_PATHS[tier]))\n\t\tif result == OK:\n\t\t\tvar corner_atlas := _build_inside_corner_atlas(corner_images[tier])\n\t\t\tresult = corner_atlas.save_png(String(RUNTIME_INSIDE_CORNER_PATHS[tier]))",
			"\tfor tier in TIERS:\n\t\tif result != OK:\n\t\t\tbreak\n\t\tvar source_tier := \"easy\" if tier == \"unmineable\" else tier\n\t\tvar atlas := _build_border_atlas(border_images[source_tier], convex_images[source_tier])\n\t\tresult = atlas.save_png(String(RUNTIME_BORDER_PATHS[tier]))\n\t\tif result == OK:\n\t\t\tvar corner_atlas := _build_inside_corner_atlas(corner_images[source_tier])\n\t\t\tresult = corner_atlas.save_png(String(RUNTIME_INSIDE_CORNER_PATHS[tier]))"
		]
	]

	for pair in replacements:
		var old_text: String = pair[0]
		var new_text: String = pair[1]
		if not text.contains(old_text):
			push_error("Could not find expected workbench block for Unmineable mirror patch")
			get_tree().quit(1)
			return
		text = text.replace(old_text, new_text)

	var file := FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write Dome Material Workbench")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Unmineable now permanently mirrors Easy art in editor, preview, save and export")
	get_tree().quit()
