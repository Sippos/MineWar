extends Node

const PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _replace_once(text: String, old_value: String, new_value: String, label: String) -> String:
	if not text.contains(old_value):
		push_error("Missing anchor: " + label)
		return text
	return text.replace(old_value, new_value)

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	var old_load := "\tfor tier in [\"easy\", \"medium\", \"hard\"]:\n\t\tborder_images[tier] = _load_editable_border_stamp(tier, String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))\n\t\tconvex_images[tier] = _load_convex_stamp(tier, border_images[tier])\n\t\tcorner_images[tier] = _load_hole_corner_stamp(tier, convex_images[tier])\n\t\tfront_images[tier] = _load_front_face_stamp(tier)\n\tborder_images[\"unmineable\"] = (border_images[\"easy\"] as Image).duplicate()\n\tconvex_images[\"unmineable\"] = (convex_images[\"easy\"] as Image).duplicate()\n\tcorner_images[\"unmineable\"] = (corner_images[\"easy\"] as Image).duplicate()\n\tfront_images[\"unmineable\"] = (front_images[\"easy\"] as Image).duplicate()"
	var new_load := "\tfor tier in TIERS:\n\t\tvar fallback_edge := String(FALLBACK_EDGE_PATHS.get(tier, FALLBACK_EDGE_PATHS[\"easy\"]))\n\t\tborder_images[tier] = _load_editable_border_stamp(tier, String(RUNTIME_BORDER_PATHS[tier]), fallback_edge)\n\t\tconvex_images[tier] = _load_convex_stamp(tier, border_images[tier])\n\t\tcorner_images[tier] = _load_hole_corner_stamp(tier, convex_images[tier])\n\t\tfront_images[tier] = _load_front_face_stamp(tier)"
	text = _replace_once(text, old_load, new_load, "independent loading")

	var old_front_loader := "func _load_front_face_stamp(tier: String) -> Image:\n\tvar editable_path := SOURCE_DIR + \"/%s_front_face_32.png\" % tier\n\tvar path := editable_path if FileAccess.file_exists(editable_path) else String(FRONT_SOURCE_PATHS[tier])\n\tvar image := Image.load_from_file(ProjectSettings.globalize_path(path))"
	var new_front_loader := "func _load_front_face_stamp(tier: String) -> Image:\n\tvar editable_path := SOURCE_DIR + \"/%s_front_face_32.png\" % tier\n\tvar runtime_path := String(RUNTIME_FRONT_PATHS[tier])\n\tvar path := editable_path\n\tif not FileAccess.file_exists(path):\n\t\tpath = runtime_path if FileAccess.file_exists(runtime_path) else String(FRONT_SOURCE_PATHS[tier])\n\tvar image := Image.load_from_file(ProjectSettings.globalize_path(path))"
	text = _replace_once(text, old_front_loader, new_front_loader, "front loader")

	text = _replace_once(
		text,
		"func _visual_tier() -> String:\n\treturn \"easy\" if current_tier == \"unmineable\" else current_tier",
		"func _visual_tier() -> String:\n\t# Every material, including Unmineable, owns independent authored artwork.\n\treturn current_tier",
		"active tier alias"
	)

	text = text.replace("\t\tvar source_tier := \"easy\" if tier == \"unmineable\" else tier\n", "")
	text = text.replace("border_images[source_tier]", "border_images[tier]")
	text = text.replace("convex_images[source_tier]", "convex_images[tier]")
	text = text.replace("corner_images[source_tier]", "corner_images[tier]")
	text = text.replace("front_images[source_tier]", "front_images[tier]")

	text = text.replace(
		"Saved one mass, four borders, four edge joints and four independent hole corners.",
		"Saved one mass plus four fully independent material sets: borders, edge joints, hole corners and front surfaces."
	)
	text = text.replace(
		"Exported four border atlases plus four independently editable pixel-aligned Hole Corner atlases.",
		"Exported four fully independent border, Hole Corner and front-surface material sets."
	)

	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write workbench")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Unmineable is now a fully independent material in load, edit, preview, save and export")
	get_tree().quit()
