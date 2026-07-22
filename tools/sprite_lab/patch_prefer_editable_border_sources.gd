extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	var old_block := "\tfor tier in [\"easy\", \"medium\", \"hard\"]:\n\t\tborder_images[tier] = _load_top_stamp(String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))\n\t\tconvex_images[tier] = _load_convex_stamp(tier, border_images[tier])\n\t\tcorner_images[tier] = _load_hole_corner_stamp(tier, convex_images[tier])\n\tborder_images[\"unmineable\"] = (border_images[\"easy\"] as Image).duplicate()\n\tconvex_images[\"unmineable\"] = (convex_images[\"easy\"] as Image).duplicate()\n\tcorner_images[\"unmineable\"] = _load_hole_corner_stamp(\"unmineable\", convex_images[\"unmineable\"])"
	var new_block := "\tfor tier in [\"easy\", \"medium\", \"hard\"]:\n\t\tborder_images[tier] = _load_editable_border_stamp(tier, String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))\n\t\tconvex_images[tier] = _load_convex_stamp(tier, border_images[tier])\n\t\tcorner_images[tier] = _load_hole_corner_stamp(tier, convex_images[tier])\n\tborder_images[\"unmineable\"] = _load_editable_border_stamp(\"unmineable\", String(RUNTIME_BORDER_PATHS[\"unmineable\"]), FALLBACK_UNMINEABLE_PATH)\n\tconvex_images[\"unmineable\"] = _load_convex_stamp(\"unmineable\", border_images[\"unmineable\"])\n\tcorner_images[\"unmineable\"] = _load_hole_corner_stamp(\"unmineable\", convex_images[\"unmineable\"])"
	if not text.contains(old_block):
		push_error("Could not find workbench load block")
		get_tree().quit(1)
		return
	text = text.replace(old_block, new_block)

	var marker := "func _load_hole_corner_stamp(tier: String, edge_joint: Image) -> Image:\n"
	if not text.contains(marker):
		push_error("Could not find helper insertion point")
		get_tree().quit(1)
		return
	var helper := "func _load_editable_border_stamp(tier: String, runtime_path: String, fallback_path: String) -> Image:\n\tvar editable_path := SOURCE_DIR + \"/%s_border_top_32.png\" % tier\n\tif FileAccess.file_exists(editable_path):\n\t\tvar image := Image.load_from_file(ProjectSettings.globalize_path(editable_path))\n\t\tif image != null and not image.is_empty():\n\t\t\timage.convert(Image.FORMAT_RGBA8)\n\t\t\timage.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)\n\t\t\tfor y in range(11, LOGICAL_SIZE):\n\t\t\t\tfor x in range(LOGICAL_SIZE):\n\t\t\t\t\timage.set_pixel(x, y, Color.TRANSPARENT)\n\t\t\treturn image\n\treturn _load_top_stamp(runtime_path, fallback_path)\n\n"
	text = text.replace(marker, helper + marker)

	var file := FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write workbench")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Workbench now loads editable border sources before runtime atlases")
	get_tree().quit()
