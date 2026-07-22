extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	text = text.replace(
		"\tselected_inside_corner_textures = _build_authored_corner_textures(selected_corner_image)\n\tunmineable_inside_corner_textures = _build_authored_corner_textures(unmineable_corner_image)",
		"\tselected_inside_corner_textures = _build_authored_corner_textures(selected_convex_image)\n\tunmineable_inside_corner_textures = _build_authored_corner_textures(unmineable_convex_image)"
	)

	var old_pass := "\tfor y in range(MAP_SIZE.y):\n\t\tfor x in range(MAP_SIZE.x):\n\t\t\tvar empty_cell := Vector2i(x, y)\n\t\t\tif not _is_solid(empty_cell):\n\t\t\t\t_draw_inside_corners(empty_cell, _cell_rect(empty_cell))"
	var new_pass := "\t# Empty-room corners reuse the same Edge Joint on the diagonal solid cell.\n\tfor y in range(MAP_SIZE.y):\n\t\tfor x in range(MAP_SIZE.x):\n\t\t\tvar solid_cell := Vector2i(x, y)\n\t\t\tif _is_solid(solid_cell):\n\t\t\t\t_draw_inside_corners(solid_cell, _cell_rect(solid_cell))"
	if not text.contains(old_pass):
		push_error("Could not find old empty-cell pass")
		get_tree().quit(1)
		return
	text = text.replace(old_pass, new_pass)

	var start := text.find("func _draw_inside_corners(")
	var finish := text.find("func _cell_from_position", start)
	if start < 0 or finish < 0:
		push_error("Could not locate old corner function block")
		get_tree().quit(1)
		return
	var replacement := "func _draw_inside_corners(solid_cell: Vector2i, rect: Rect2) -> void:\n\tvar corner_rules := [\n\t\t[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],\n\t\t[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],\n\t\t[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],\n\t\t[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],\n\t]\n\tfor rule_value in corner_rules:\n\t\tvar rule: Array = rule_value\n\t\tvar first: Vector2i = rule[0]\n\t\tvar second: Vector2i = rule[1]\n\t\tvar diagonal: Vector2i = rule[2]\n\t\tvar frame: int = rule[3]\n\t\t# The current block and both cardinal neighbours remain solid, but the\n\t\t# diagonal cell is empty. This is the rounded corner of a room/hole.\n\t\tif not _is_solid(solid_cell + first) or not _is_solid(solid_cell + second) or _is_solid(solid_cell + diagonal):\n\t\t\tcontinue\n\t\tvar joint_textures := _inside_corner_textures_for(_cell_type(solid_cell))\n\t\tif frame >= joint_textures.size() or joint_textures[frame] == null:\n\t\t\tcontinue\n\t\tvar cut_size := rect.size.x * (14.0 / 32.0)\n\t\tvar cut_position := rect.position\n\t\tmatch frame:\n\t\t\t1: cut_position += Vector2(rect.size.x - cut_size, 0)\n\t\t\t2: cut_position += Vector2(rect.size.x - cut_size, rect.size.y - cut_size)\n\t\t\t3: cut_position += Vector2(0, rect.size.y - cut_size)\n\t\tdraw_rect(Rect2(cut_position, Vector2(cut_size, cut_size)), CAVE_COLOR)\n\t\tdraw_texture_rect(joint_textures[frame], rect, false)\n\n"
	text = text.substr(0, start) + replacement + text.substr(finish)

	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write preview")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Preview now reuses Edge Joint for diagonal hole corners")
	get_tree().quit()
