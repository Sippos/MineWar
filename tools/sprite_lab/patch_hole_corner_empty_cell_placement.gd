extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	var start := text.find("\t# Opposite Hole Corners are replacement patches on diagonal solid cells.")
	var finish := text.find("func _cell_from_position", start)
	if start < 0 or finish < 0:
		push_error("Could not locate the old solid-cell Hole Corner pass")
		get_tree().quit(1)
		return

	var replacement := "\t# Hole Corners belong to the corner of an EMPTY cell. The diagonal solid\\n\t# block chooses the material, while short masks remove the square endpoints\\n\t# of the two neighbouring straight borders.\\n\tfor y in range(MAP_SIZE.y):\\n\t\tfor x in range(MAP_SIZE.x):\\n\t\t\tvar empty_cell := Vector2i(x, y)\\n\t\t\tif not _is_solid(empty_cell):\\n\t\t\t\t_draw_hole_corners(empty_cell, _cell_rect(empty_cell))\\n\\n\tif hovered_cell.x >= 0 and hovered_cell.y >= 0 and hovered_cell.x < MAP_SIZE.x and hovered_cell.y < MAP_SIZE.y:\\n\t\tdraw_rect(_cell_rect(hovered_cell).grow(-2.0), Color(1, 1, 1, 0.42), false, 1.5)\\n\\nfunc _draw_hole_corners(empty_cell: Vector2i, rect: Rect2) -> void:\\n\tvar rules := [\\n\t\t[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],\\n\t\t[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],\\n\t\t[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],\\n\t\t[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],\\n\t]\\n\tfor rule_value in rules:\\n\t\tvar rule: Array = rule_value\\n\t\tvar first: Vector2i = rule[0]\\n\t\tvar second: Vector2i = rule[1]\\n\t\tvar diagonal: Vector2i = rule[2]\\n\t\tvar frame: int = rule[3]\\n\t\tif not _is_solid(empty_cell + first) or not _is_solid(empty_cell + second) or not _is_solid(empty_cell + diagonal):\\n\t\t\tcontinue\\n\t\tvar owner_type := _cell_type(empty_cell + diagonal)\\n\t\tvar textures := _inside_corner_textures_for(owner_type)\\n\t\tif frame >= textures.size() or textures[frame] == null:\\n\t\t\tcontinue\\n\t\t_mask_hole_corner_border_ends(rect, frame, owner_type)\\n\t\tdraw_texture_rect(textures[frame], rect, false)\\n\\nfunc _mask_hole_corner_border_ends(rect: Rect2, frame: int, owner_type: int) -> void:\\n\tvar border_image := unmineable_border_image if owner_type == CellType.UNMINEABLE else selected_border_image\\n\tvar logical_depth := CORNER_BUILDER.border_depth(border_image)\\n\tvar depth := maxf(1.0, rect.size.x * (float(logical_depth) / float(LOGICAL_SIZE)))\\n\tvar extent := rect.size.x * (14.0 / float(LOGICAL_SIZE))\\n\tmatch frame:\\n\t\t0:\\n\t\t\tdraw_rect(Rect2(Vector2(rect.position.x, rect.position.y - depth), Vector2(extent, depth + 1.0)), CAVE_COLOR)\\n\t\t\tdraw_rect(Rect2(Vector2(rect.position.x - depth, rect.position.y), Vector2(depth + 1.0, extent)), CAVE_COLOR)\\n\t\t1:\\n\t\t\tdraw_rect(Rect2(Vector2(rect.end.x - extent, rect.position.y - depth), Vector2(extent, depth + 1.0)), CAVE_COLOR)\\n\t\t\tdraw_rect(Rect2(Vector2(rect.end.x - 1.0, rect.position.y), Vector2(depth + 1.0, extent)), CAVE_COLOR)\\n\t\t2:\\n\t\t\tdraw_rect(Rect2(Vector2(rect.end.x - extent, rect.end.y - 1.0), Vector2(extent, depth + 1.0)), CAVE_COLOR)\\n\t\t\tdraw_rect(Rect2(Vector2(rect.end.x - 1.0, rect.end.y - extent), Vector2(depth + 1.0, extent)), CAVE_COLOR)\\n\t\t3:\\n\t\t\tdraw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 1.0), Vector2(extent, depth + 1.0)), CAVE_COLOR)\\n\t\t\tdraw_rect(Rect2(Vector2(rect.position.x - depth, rect.end.y - extent), Vector2(depth + 1.0, extent)), CAVE_COLOR)\\n\\n"
	replacement = replacement.replace("\\n", "\n")
	text = text.substr(0, start) + replacement + text.substr(finish)
	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write empty-cell Hole Corner placement")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Hole Corners now render at empty-cell vertices and mask straight border endpoints")
	get_tree().quit()
