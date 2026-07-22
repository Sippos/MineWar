extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _ready() -> void:
	var error := _patch_preview()
	if error != OK:
		push_error("Could not patch preview: %s" % error_string(error))
		get_tree().quit(1)
		return
	error = _patch_workbench_export()
	if error != OK:
		push_error("Could not patch export: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("Hole Corners now use exact 14x14 vertex patches with fully masked border endpoints")
	get_tree().quit()

func _replace_function(text: String, function_name: String, next_function_name: String, replacement: String) -> String:
	var start := text.find("func %s(" % function_name)
	var finish := text.find("func %s(" % next_function_name, start + 1)
	if start < 0 or finish < 0:
		return ""
	return text.substr(0, start) + replacement + "\n" + text.substr(finish)

func _write(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK

func _patch_preview() -> Error:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	if text.is_empty():
		return ERR_FILE_CANT_READ
	if not text.contains("const CORNER_PATCH_SIZE := 14"):
		text = text.replace("const TILE_SIZE := 64\n", "const TILE_SIZE := 64\nconst CORNER_PATCH_SIZE := 14\n")

	var texture_builder := "func _build_authored_corner_textures(top_left_corner: Image) -> Array[ImageTexture]:\n\tvar source_patch := Image.create(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE, false, Image.FORMAT_RGBA8)\n\tsource_patch.fill(Color.TRANSPARENT)\n\tfor y in range(CORNER_PATCH_SIZE):\n\t\tfor x in range(CORNER_PATCH_SIZE):\n\t\t\tsource_patch.set_pixel(x, y, top_left_corner.get_pixel(x, y))\n\tvar result: Array[ImageTexture] = []\n\tfor turn in range(4):\n\t\tvar corner := _rotate_corner_patch(source_patch, turn)\n\t\tresult.append(ImageTexture.create_from_image(corner))\n\treturn result\n\nfunc _rotate_corner_patch(source: Image, turns: int) -> Image:\n\tvar normalized := posmod(turns, 4)\n\tvar result := Image.create(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE, false, Image.FORMAT_RGBA8)\n\tresult.fill(Color.TRANSPARENT)\n\tfor y in range(CORNER_PATCH_SIZE):\n\t\tfor x in range(CORNER_PATCH_SIZE):\n\t\t\tvar destination := Vector2i(x, y)\n\t\t\tmatch normalized:\n\t\t\t\t1: destination = Vector2i(CORNER_PATCH_SIZE - 1 - y, x)\n\t\t\t\t2: destination = Vector2i(CORNER_PATCH_SIZE - 1 - x, CORNER_PATCH_SIZE - 1 - y)\n\t\t\t\t3: destination = Vector2i(y, CORNER_PATCH_SIZE - 1 - x)\n\t\t\tresult.set_pixelv(destination, source.get_pixel(x, y))\n\treturn result\n"
	text = _replace_function(text, "_build_authored_corner_textures", "_build_square_composite_textures", texture_builder)
	if text.is_empty():
		return ERR_INVALID_DATA

	var draw_function := "func _draw_hole_corners(empty_cell: Vector2i, rect: Rect2) -> void:\n\tvar rules := [\n\t\t[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],\n\t\t[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],\n\t\t[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],\n\t\t[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],\n\t]\n\tfor rule_value in rules:\n\t\tvar rule: Array = rule_value\n\t\tvar first: Vector2i = rule[0]\n\t\tvar second: Vector2i = rule[1]\n\t\tvar diagonal: Vector2i = rule[2]\n\t\tvar frame: int = rule[3]\n\t\tif not _is_solid(empty_cell + first) or not _is_solid(empty_cell + second) or not _is_solid(empty_cell + diagonal):\n\t\t\tcontinue\n\t\tvar owner_type := _cell_type(empty_cell + diagonal)\n\t\tvar textures := _inside_corner_textures_for(owner_type)\n\t\tif frame >= textures.size() or textures[frame] == null:\n\t\t\tcontinue\n\t\t_mask_hole_corner_border_ends(rect, frame, owner_type)\n\t\tvar patch_position := rect.position\n\t\tmatch frame:\n\t\t\t1: patch_position += Vector2(rect.size.x - CORNER_PATCH_SIZE, 0)\n\t\t\t2: patch_position += Vector2(rect.size.x - CORNER_PATCH_SIZE, rect.size.y - CORNER_PATCH_SIZE)\n\t\t\t3: patch_position += Vector2(0, rect.size.y - CORNER_PATCH_SIZE)\n\t\tdraw_texture_rect(textures[frame], Rect2(patch_position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE)), false)\n"
	text = _replace_function(text, "_draw_hole_corners", "_mask_hole_corner_border_ends", draw_function)
	if text.is_empty():
		return ERR_INVALID_DATA
	text = text.replace("var extent := rect.size.x * (10.0 / float(LOGICAL_SIZE))", "var extent := rect.size.x * (float(CORNER_PATCH_SIZE - 2) / float(LOGICAL_SIZE))")
	return _write(PREVIEW_PATH, text)

func _patch_workbench_export() -> Error:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	if text.is_empty():
		return ERR_FILE_CANT_READ
	var replacement := "func _build_inside_corner_atlas(top_left_corner: Image) -> Image:\n\tvar atlas := Image.create(TILE_SIZE * 2, TILE_SIZE * 2, false, Image.FORMAT_RGBA8)\n\tatlas.fill(Color.TRANSPARENT)\n\tvar source_patch := Image.create(14, 14, false, Image.FORMAT_RGBA8)\n\tsource_patch.fill(Color.TRANSPARENT)\n\tfor y in range(14):\n\t\tfor x in range(14):\n\t\t\tsource_patch.set_pixel(x, y, top_left_corner.get_pixel(x, y))\n\tfor frame in range(4):\n\t\tvar rotated_patch := _rotate_export_corner_patch(source_patch, frame)\n\t\tvar logical_tile := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)\n\t\tlogical_tile.fill(Color.TRANSPARENT)\n\t\tvar patch_position := Vector2i.ZERO\n\t\tmatch frame:\n\t\t\t1: patch_position = Vector2i(LOGICAL_SIZE - 14, 0)\n\t\t\t2: patch_position = Vector2i(LOGICAL_SIZE - 14, LOGICAL_SIZE - 14)\n\t\t\t3: patch_position = Vector2i(0, LOGICAL_SIZE - 14)\n\t\tlogical_tile.blit_rect(rotated_patch, Rect2i(Vector2i.ZERO, Vector2i(14, 14)), patch_position)\n\t\tlogical_tile.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)\n\t\tatlas.blit_rect(logical_tile, Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i(frame % 2, frame / 2) * TILE_SIZE)\n\treturn atlas\n\nfunc _rotate_export_corner_patch(source: Image, turns: int) -> Image:\n\tvar normalized := posmod(turns, 4)\n\tvar result := Image.create(14, 14, false, Image.FORMAT_RGBA8)\n\tresult.fill(Color.TRANSPARENT)\n\tfor y in range(14):\n\t\tfor x in range(14):\n\t\t\tvar destination := Vector2i(x, y)\n\t\t\tmatch normalized:\n\t\t\t\t1: destination = Vector2i(13 - y, x)\n\t\t\t\t2: destination = Vector2i(13 - x, 13 - y)\n\t\t\t\t3: destination = Vector2i(y, 13 - x)\n\t\t\tresult.set_pixelv(destination, source.get_pixel(x, y))\n\treturn result\n"
	text = _replace_function(text, "_build_inside_corner_atlas", "_find_brightest_color", replacement)
	if text.is_empty():
		return ERR_INVALID_DATA
	return _write(WORKBENCH_PATH, text)
