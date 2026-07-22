extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _ready() -> void:
	var ok := _patch_workbench() and _patch_preview()
	print("Edge Joint now handles both solid corners and rounded hole corners" if ok else "Edge-joint hole patch failed")
	get_tree().quit(0 if ok else 1)

func _replace_required(text: String, old: String, replacement: String, label: String) -> String:
	if not text.contains(old):
		push_error("Missing patch target: %s" % label)
		return ""
	return text.replace(old, replacement)

func _patch_workbench() -> bool:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	text = text.replace(
		"subtitle.text = \"NORMAL TILING: one dark mass + straight borders + edge joints + concave connectors\"",
		"subtitle.text = \"NORMAL TILING: one dark mass + straight borders + one edge joint reused for every rounded turn\""
	)
	text = _replace_required(
		text,
		"\t_add_mode_button(controls, \"corner\", \"CAVE CORNER • empty-hole turn\")\n",
		"",
		"remove redundant Cave Corner workspace"
	)
	if text.is_empty(): return false
	text = text.replace(
		"Each material has a straight border, a solid-cell EDGE JOINT, and a CAVE CORNER inside empty space where two bright lines curve together.",
		"Each material has one straight border and one EDGE JOINT. The same joint is rotated for isolated blocks, pillars, room corners and tunnel turns."
	)
	var file := FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write workbench")
		return false
	file.store_string(text)
	file.close()
	return true

func _patch_preview() -> bool:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	text = _replace_required(
		text,
		"\tselected_inside_corner_textures = _build_authored_corner_textures(selected_corner_image)\n\tunmineable_inside_corner_textures = _build_authored_corner_textures(unmineable_corner_image)",
		"\t# The same authored Edge Joint is also used for diagonal empty-hole turns.\n\tselected_inside_corner_textures = _build_authored_corner_textures(selected_convex_image)\n\tunmineable_inside_corner_textures = _build_authored_corner_textures(unmineable_convex_image)",
		"reuse edge joint textures"
	)
	if text.is_empty(): return false

	var old_draw_pass := "\t# Concave dirt-facing turns belong to the empty tunnel cell and are generated\n\t# separately from the same one-border source.\n\tfor y in range(MAP_SIZE.y):\n\t\tfor x in range(MAP_SIZE.x):\n\t\t\tvar empty_cell := Vector2i(x, y)\n\t\t\tif not _is_solid(empty_cell):\n\t\t\t\t_draw_inside_corners(empty_cell, _cell_rect(empty_cell))"
	var new_draw_pass := "\t# Rounded corners of empty rooms belong to the DIAGONAL SOLID cell.\n\t# Reusing the Edge Joint here produces the exact inverse silhouette of an\n\t# isolated rounded block instead of layering a second incompatible curve.\n\tfor y in range(MAP_SIZE.y):\n\t\tfor x in range(MAP_SIZE.x):\n\t\t\tvar solid_cell := Vector2i(x, y)\n\t\t\tif _is_solid(solid_cell):\n\t\t\t\t_draw_inside_corners(solid_cell, _cell_rect(solid_cell))"
	text = _replace_required(text, old_draw_pass, new_draw_pass, "diagonal corner draw pass")
	if text.is_empty(): return false

	var old_function := "func _draw_inside_corners(empty_cell: Vector2i, rect: Rect2) -> void:\n\tvar corner_rules := [\n\t\t[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],\n\t\t[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],\n\t\t[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],\n\t\t[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],\n\t]\n\tfor rule_value in corner_rules:\n\t\tvar rule: Array = rule_value\n\t\tvar first: Vector2i = rule[0]\n\t\tvar second: Vector2i = rule[1]\n\t\tvar diagonal: Vector2i = rule[2]\n\t\tvar frame: int = rule[3]\n\t\tif not _is_solid(empty_cell + first) or not _is_solid(empty_cell + second) or not _is_solid(empty_cell + diagonal):\n\t\t\tcontinue\n\t\tvar owner_type := _cell_type(empty_cell + diagonal)\n\t\tvar corner_textures := _inside_corner_textures_for(owner_type)\n\t\tif frame < corner_textures.size() and corner_textures[frame] != null:\n\t\t\tdraw_texture_rect(corner_textures[frame], rect, false)"
	var new_function := "func _draw_inside_corners(solid_cell: Vector2i, rect: Rect2) -> void:\n\t# For a top-left cutout, the current cell, its top neighbour and its left\n\t# neighbour are solid while only the diagonal top-left cell is empty.\n\tvar corner_rules := [\n\t\t[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],\n\t\t[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],\n\t\t[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],\n\t\t[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],\n\t]\n\tfor rule_value in corner_rules:\n\t\tvar rule: Array = rule_value\n\t\tvar first: Vector2i = rule[0]\n\t\tvar second: Vector2i = rule[1]\n\t\tvar diagonal: Vector2i = rule[2]\n\t\tvar frame: int = rule[3]\n\t\tif not _is_solid(solid_cell + first) or not _is_solid(solid_cell + second) or _is_solid(solid_cell + diagonal):\n\t\t\tcontinue\n\t\tvar joint_textures := _inside_corner_textures_for(_cell_type(solid_cell))\n\t\tif frame >= joint_textures.size() or joint_textures[frame] == null:\n\t\t\tcontinue\n\t\t# Clear only the authored 14x14 corner area back to cave space, then\n\t\t# replace it with the rotated Edge Joint patch.\n\t\tvar cut_size := rect.size.x * (14.0 / 32.0)\n\t\tvar cut_position := rect.position\n\t\tmatch frame:\n\t\t\t1: cut_position += Vector2(rect.size.x - cut_size, 0)\n\t\t\t2: cut_position += Vector2(rect.size.x - cut_size, rect.size.y - cut_size)\n\t\t\t3: cut_position += Vector2(0, rect.size.y - cut_size)\n\t\tdraw_rect(Rect2(cut_position, Vector2(cut_size, cut_size)), Color.html(\"111725ff\"))\n\t\tdraw_texture_rect(joint_textures[frame], rect, false)"
	text = _replace_required(text, old_function, new_function, "replace empty-cell corner overlay")
	if text.is_empty(): return false

	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write preview")
		return false
	file.store_string(text)
	file.close()
	return true
