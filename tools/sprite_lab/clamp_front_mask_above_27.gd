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
		'''\t\t\tfor distance in range(1, front_depth + 1):
\t\t\t\tvar local_y := CELL_SIZE + distance - 1
\t\t\t\tvar source_y := local_y - front_depth
\t\t\t\tif source_y < 0 or source_y >= CELL_SIZE:
\t\t\t\t\tcontinue''',
		'''\t\t\tvar mask_depth := mini(front_depth, 27)
\t\t\tvar mask_start_y := CELL_SIZE - mask_depth
\t\t\tfor distance in range(1, front_depth + 1):
\t\t\t\tvar local_y := CELL_SIZE + distance - 1
\t\t\t\tvar source_y := mask_start_y
\t\t\t\tif front_depth > 1 and mask_depth > 1:
\t\t\t\t\tsource_y += roundi(float(distance - 1) * float(mask_depth - 1) / float(front_depth - 1))
\t\t\t\tif source_y < 0 or source_y >= CELL_SIZE:
\t\t\t\t\tcontinue''',
		"preview mask depth mapping"
	)
	if not _write(PREVIEW_PATH, preview):
		get_tree().quit(1)
		return

	var runtime := FileAccess.get_file_as_string(RUNTIME_PATH)
	runtime = _replace_once(
		runtime,
		'''\tfor y in range(TILE_SIZE + depth):
\t\tfor x in range(TILE_SIZE):
\t\t\tvar shifted_y := y - depth
\t\t\tif shifted_y < 0 or shifted_y >= TILE_SIZE:''',
		'''\tvar mask_depth := mini(depth, 27)
\tvar mask_start_y := TILE_SIZE - mask_depth
\tfor y in range(TILE_SIZE + depth):
\t\tfor x in range(TILE_SIZE):
\t\t\tvar shifted_y := y - depth
\t\t\tif y >= TILE_SIZE:
\t\t\t\tvar distance := y - TILE_SIZE
\t\t\t\tshifted_y = mask_start_y
\t\t\t\tif depth > 1 and mask_depth > 1:
\t\t\t\t\tshifted_y += roundi(float(distance) * float(mask_depth - 1) / float(depth - 1))
\t\t\tif shifted_y < 0 or shifted_y >= TILE_SIZE:''',
		"runtime mask depth mapping"
	)
	if not _write(RUNTIME_PATH, runtime):
		get_tree().quit(1)
		return
	print("FRONT_MASK_DEPTHS_ABOVE_27_STRETCH_APPROVED_PROFILE")
	get_tree().quit(0)
