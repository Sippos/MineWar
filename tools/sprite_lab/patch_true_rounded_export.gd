extends Node

func _ready() -> void:
	var path := "res://tools/sprite_lab/dome_material_workbench.gd"
	var text := FileAccess.get_file_as_string(path)
	text = text.replace(
		"const PREVIEW_SCRIPT := preload(\"res://tools/sprite_lab/dome_material_preview.gd\")\n",
		"const PREVIEW_SCRIPT := preload(\"res://tools/sprite_lab/dome_material_preview.gd\")\nconst CORNER_BUILDER := preload(\"res://tools/sprite_lab/dome_corner_builder.gd\")\n"
	)
	text = _replace_function(text, "func _build_border_atlas(top_stamp: Image) -> Image:", "func _border_depth(top_border: Image) -> int:", "func _build_border_atlas(top_stamp: Image) -> Image:\n\t# The exported atlas now contains the universal mass and genuine transparent\n\t# quarter-circle cutouts. It is the exact same generator used by the preview.\n\treturn CORNER_BUILDER.build_composite_atlas(mass_image, top_stamp)\n\n")
	text = _replace_function(text, "func _build_inside_corner_atlas(top_border: Image) -> Image:", "func _find_brightest_color(image: Image) -> Color:", "func _build_inside_corner_atlas(top_border: Image) -> Image:\n\treturn CORNER_BUILDER.build_inside_corner_atlas(top_border)\n\n")
	text = text.replace(
		"Exported universal mass, four 16-mask border atlases and four inside-corner atlases.",
		"Exported four composite mass+border atlases with true rounded cutouts and four inside-corner atlases."
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not patch true rounded export")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("True rounded composite export installed")
	get_tree().quit()

func _replace_function(text: String, start_marker: String, end_marker: String, replacement: String) -> String:
	var start := text.find(start_marker)
	var end := text.find(end_marker, start + start_marker.length())
	if start < 0 or end < 0:
		push_error("Patch marker missing: %s" % start_marker)
		return text
	return text.substr(0, start) + replacement + text.substr(end)
