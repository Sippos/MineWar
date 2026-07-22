extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const RUNTIME_PATH := "res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd"

func _replace_once(text: String, old_text: String, new_text: String, label: String) -> String:
	if not text.contains(old_text):
		push_error("Missing patch anchor: " + label)
		return text
	return text.replace(old_text, new_text)

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + path)
		return false
	file.store_string(text)
	file.close()
	return true

func _ready() -> void:
	var preview := FileAccess.get_file_as_string(PREVIEW_PATH)
	preview = _replace_once(
		preview,
		'''\t\t\t# Remove only the overlapping projection in the downward face area.
\t\t\tfor distance in range(1, front_depth + 1):
\t\t\t\tvar world_y := origin_y + CELL_SIZE + distance - 1
\t\t\t\tif world_y < 0 or world_y >= height:
\t\t\t\t\tbreak
\t\t\t\tfor local_x in range(CELL_SIZE):
\t\t\t\t\tvar world_x := origin_x + local_x
\t\t\t\t\tif world_x >= 0 and world_x < width:
\t\t\t\t\t\tresult.set_pixel(world_x, world_y, Color.TRANSPARENT)''',
		'''\t\t\t# The mask cutouts represent cave space. Paint them as opaque cave color
\t\t\t# before redrawing the face so borders and Hole Corners underneath cannot
\t\t\t# leak through as gray rims.
\t\t\tfor distance in range(1, front_depth + 1):
\t\t\t\tvar world_y := origin_y + CELL_SIZE + distance - 1
\t\t\t\tif world_y < 0 or world_y >= height:
\t\t\t\t\tbreak
\t\t\t\tfor local_x in range(CELL_SIZE):
\t\t\t\t\tvar world_x := origin_x + local_x
\t\t\t\t\tif world_x >= 0 and world_x < width:
\t\t\t\t\t\tresult.set_pixel(world_x, world_y, CAVE_COLOR)''',
		"preview cave occlusion"
	)
	if not _write(PREVIEW_PATH, preview):
		get_tree().quit(1)
		return

	var runtime := FileAccess.get_file_as_string(RUNTIME_PATH)
	runtime = _replace_once(
		runtime,
		'''\treturn result''',
		'''\t# Transparent parts of the side mask are cave space, not windows into
\t# lower border layers. Make them opaque cave color to prevent gray bleed.
\tvar cave_color := Color("111725")
\tfor y in range(TILE_SIZE, TILE_SIZE + depth):
\t\tfor x in range(TILE_SIZE):
\t\t\tif result.get_pixel(x, y).a <= 0.05:
\t\t\t\tresult.set_pixel(x, y, cave_color)
\treturn result''',
		"runtime cave occlusion"
	)
	if not _write(RUNTIME_PATH, runtime):
		get_tree().quit(1)
		return
	print("MASK_CUTOUTS_NOW_OCCLUDE_GRAY_OVERLAYS")
	get_tree().quit(0)
