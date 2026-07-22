extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _replace_function(text: String, function_name: String, replacement: String) -> String:
	var start := text.find("func %s(" % function_name)
	if start < 0:
		push_error("Missing function %s" % function_name)
		return ""
	var next := text.find("\nfunc ", start + 1)
	if next < 0:
		next = text.length()
	return text.substr(0, start) + replacement + text.substr(next + 1)

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true

func _ready() -> void:
	var preview := FileAccess.get_file_as_string(PREVIEW_PATH)
	preview = preview.replace("base.set_pixel(LOGICAL_SIZE - 1 + x, LOGICAL_SIZE - 1 + y, color)", "base.set_pixel(LOGICAL_SIZE - 2 + x, LOGICAL_SIZE - 2 + y, color)")
	var draw_replacement := '''func _draw_hole_corners(empty_cell: Vector2i, rect: Rect2) -> void:
	var rules := [
		[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],
		[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],
		[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],
		[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],
	]
	for rule_value in rules:
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
		var vertex := rect.position
		match frame:
			1: vertex = Vector2(rect.end.x, rect.position.y)
			2: vertex = rect.end
			3: vertex = Vector2(rect.position.x, rect.end.y)
		var overlay_rect := Rect2(vertex - Vector2(CELL_SIZE, CELL_SIZE), Vector2(CELL_SIZE * 2, CELL_SIZE * 2))
		draw_texture_rect(textures[frame], overlay_rect, false)
'''
	preview = _replace_function(preview, "_draw_hole_corners", draw_replacement)
	if preview.is_empty() or not _write(PREVIEW_PATH, preview):
		get_tree().quit(1)
		return

	var workbench := FileAccess.get_file_as_string(WORKBENCH_PATH)
	workbench = workbench.replace("base.set_pixel(LOGICAL_SIZE - 1 + x, LOGICAL_SIZE - 1 + y, color)", "base.set_pixel(LOGICAL_SIZE - 2 + x, LOGICAL_SIZE - 2 + y, color)")
	if not _write(WORKBENCH_PATH, workbench):
		get_tree().quit(1)
		return
	print("Hole Corner canonical anchor moved one logical pixel outward in preview and export")
	get_tree().quit()
