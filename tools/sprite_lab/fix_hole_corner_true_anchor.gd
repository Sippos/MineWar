extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true

func _patch_preview() -> bool:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	if text.is_empty():
		push_error("Could not read preview")
		return false
	text = text.replace(
		"\tvar position := rect.position - Vector2.ONE\n\tmatch frame:\n\t\t1: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 1.0, rect.position.y - 1.0)\n\t\t2: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 1.0, rect.end.y - CORNER_PATCH_SIZE + 1.0)\n\t\t3: position = Vector2(rect.position.x - 1.0, rect.end.y - CORNER_PATCH_SIZE + 1.0)",
		"\t# The canonical 14x14 curve is anchored two logical pixels across the\n\t# terrain vertex. At vertex - 1, its axis endpoint overlaps the straight\n\t# border and creates the visible one-pixel T-shaped spur.\n\tvar position := rect.position - Vector2(2.0, 2.0)\n\tmatch frame:\n\t\t1: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 2.0, rect.position.y - 2.0)\n\t\t2: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 2.0, rect.end.y - CORNER_PATCH_SIZE + 2.0)\n\t\t3: position = Vector2(rect.position.x - 2.0, rect.end.y - CORNER_PATCH_SIZE + 2.0)"
	)
	return _write(PREVIEW_PATH, text)

func _patch_export() -> bool:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	if text.is_empty():
		push_error("Could not read workbench")
		return false
	text = text.replace(
		"\t\t\t\tbase.set_pixel(LOGICAL_SIZE + x, LOGICAL_SIZE + y, color)",
		"\t\t\t\tbase.set_pixel(LOGICAL_SIZE - 2 + x, LOGICAL_SIZE - 2 + y, color)"
	)
	return _write(WORKBENCH_PATH, text)

func _ready() -> void:
	if not _patch_preview() or not _patch_export():
		get_tree().quit(1)
		return
	print("Hole Corner anchor moved from vertex - 1 to the verified vertex - 2 position")
	get_tree().quit()
