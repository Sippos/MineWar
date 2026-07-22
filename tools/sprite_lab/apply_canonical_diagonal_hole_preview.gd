extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const BACKUP_PATH := "res://tools/sprite_lab/diagnostics/dome_material_preview_before_canonical_holes.gd.bak"

func _replace_function(text: String, function_name: String, replacement: String) -> String:
	var start := text.find("func %s(" % function_name)
	if start < 0:
		push_error("Missing function %s" % function_name)
		return ""
	var next := text.find("\nfunc ", start + 1)
	if next < 0:
		next = text.length()
	return text.substr(0, start) + replacement.rstrip("\n") + "\n" + text.substr(next + 1)

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	if text.is_empty():
		push_error("Could not read preview")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/sprite_lab/diagnostics"))
	if not FileAccess.file_exists(BACKUP_PATH):
		var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		if backup != null:
			backup.store_string(text)
			backup.close()

	text = text.replace(
		"\tselected_inside_corner_textures = _build_vertex_hole_textures(mass_image, selected_border_image, selected_corner_image)\n\tunmineable_inside_corner_textures = _build_vertex_hole_textures(mass_image, unmineable_border_image, unmineable_corner_image)",
		"\t# Hole Corners are not a second independently positioned curve. They are\n\t# the exact authored Edge Joint, rotated onto the diagonal solid tile.\n\tselected_inside_corner_textures = _build_diagonal_hole_textures(selected_convex_image)\n\tunmineable_inside_corner_textures = _build_diagonal_hole_textures(unmineable_convex_image)"
	)

	var replacement := '''func _draw_hole_corners(empty_cell: Vector2i, _rect: Rect2) -> void:
	# A concave cave corner belongs to the DIAGONAL SOLID tile. Drawing the exact
	# Edge Joint there makes the curve and both straight-border endpoints share
	# one source image, one rotation mapping and one pixel anchor. No 2x2 vertex
	# composite, endpoint guessing or one-pixel overlap is involved.
	var rules := [
		[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],
		[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],
		[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],
		[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],
	]
	for rule_value: Variant in rules:
		var rule: Array = rule_value
		var first: Vector2i = rule[0]
		var second: Vector2i = rule[1]
		var diagonal: Vector2i = rule[2]
		var frame: int = rule[3]
		if not _is_solid(empty_cell + first) or not _is_solid(empty_cell + second) or not _is_solid(empty_cell + diagonal):
			continue
		var owner_type := _cell_type(empty_cell + diagonal)
		var textures := _inside_corner_textures_for(owner_type)
		if frame >= textures.size() or textures[frame] == null:
			continue
		draw_texture_rect(textures[frame], _cell_rect(empty_cell + diagonal), false)
'''
	text = _replace_function(text, "_draw_hole_corners", replacement)
	if text.is_empty():
		get_tree().quit(1)
		return
	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write preview")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Preview Hole Corners now reuse the exact Edge Joint on the diagonal solid tile")
	get_tree().quit()
