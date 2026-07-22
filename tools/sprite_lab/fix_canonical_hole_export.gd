extends Node

const PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _replace_function(text: String, function_name: String, replacement: String) -> String:
	var start := text.find("func %s(" % function_name)
	if start < 0:
		push_error("Missing function %s" % function_name)
		return ""
	var next := text.find("\nfunc ", start + 1)
	if next < 0:
		next = text.length()
	return text.substr(0, start) + replacement + "\n" + text.substr(next + 1)

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	var replacement := "\n".join([
		"func _build_inside_corner_atlas(hole_source: Image, top_border: Image = null) -> Image:",
		"\tvar border: Image = top_border if top_border != null else border_images[\"easy\"] as Image",
		"\tvar logical_size := LOGICAL_SIZE * 2",
		"\tvar rendered_size := TILE_SIZE * 2",
		"\tvar base := Image.create(logical_size, logical_size, false, Image.FORMAT_RGBA8)",
		"\tbase.fill(Color.TRANSPARENT)",
		"\tvar hole := hole_source.duplicate()",
		"\thole.convert(Image.FORMAT_RGBA8)",
		"\tif hole.get_width() != LOGICAL_SIZE or hole.get_height() != LOGICAL_SIZE:",
		"\t\thole.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)",
		"\tvar depth := CORNER_BUILDER.border_depth(border)",
		"\tvar origin := LOGICAL_SIZE - 1",
		"\t# Restore the exact straight-border footprints with dirt mass, matching",
		"\t# the live preview before the authored Hole Corner patch is drawn.",
		"\tfor y in range(depth):",
		"\t\tfor x in range(CORNER_PATCH_SIZE):",
		"\t\t\tbase.set_pixel(origin + x, LOGICAL_SIZE - depth + y, mass_image.get_pixel(x, LOGICAL_SIZE - depth + y))",
		"\tfor y in range(CORNER_PATCH_SIZE):",
		"\t\tfor x in range(depth):",
		"\t\t\tbase.set_pixel(LOGICAL_SIZE - depth + x, origin + y, mass_image.get_pixel(LOGICAL_SIZE - depth + x, y))",
		"\tfor y in range(CORNER_PATCH_SIZE):",
		"\t\tfor x in range(CORNER_PATCH_SIZE):",
		"\t\t\tvar color: Color = hole.get_pixel(x, y)",
		"\t\t\tif color.a > 0.05:",
		"\t\t\t\tbase.set_pixel(origin + x, origin + y, color)",
		"\tvar atlas := Image.create(rendered_size * 2, rendered_size * 2, false, Image.FORMAT_RGBA8)",
		"\tatlas.fill(Color.TRANSPARENT)",
		"\tfor frame in range(4):",
		"\t\tvar rendered := _rotate_vertex_composite(base, frame)",
		"\t\trendered.resize(rendered_size, rendered_size, Image.INTERPOLATE_NEAREST)",
		"\t\tatlas.blit_rect(rendered, Rect2i(Vector2i.ZERO, Vector2i(rendered_size, rendered_size)), Vector2i(frame % 2, frame / 2) * rendered_size)",
		"\treturn atlas",
	])
	text = _replace_function(text, "_build_inside_corner_atlas", replacement)
	if text.is_empty():
		get_tree().quit(1)
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write workbench")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Hole Corner export now mirrors the canonical preview patch and anchor")
	get_tree().quit()
