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

func _ready() -> void:
	var preview := FileAccess.get_file_as_string(PREVIEW_PATH)
	if preview.is_empty():
		push_error("Could not read preview")
		get_tree().quit(1)
		return
	preview = preview.replace("var position := rect.position - Vector2.ONE", "var position := rect.position - Vector2(3.0, 3.0)")
	preview = preview.replace("rect.end.x - CORNER_PATCH_SIZE + 1.0, rect.position.y - 1.0", "rect.end.x - CORNER_PATCH_SIZE + 3.0, rect.position.y - 3.0")
	preview = preview.replace("rect.end.x - CORNER_PATCH_SIZE + 1.0, rect.end.y - CORNER_PATCH_SIZE + 1.0", "rect.end.x - CORNER_PATCH_SIZE + 3.0, rect.end.y - CORNER_PATCH_SIZE + 3.0")
	preview = preview.replace("rect.position.x - 1.0, rect.end.y - CORNER_PATCH_SIZE + 1.0", "rect.position.x - 3.0, rect.end.y - CORNER_PATCH_SIZE + 3.0")
	preview = preview.replace("# Final canonical anchor: one logical pixel across the terrain vertex.\n\t# Endpoint ownership is handled separately, so this closes the last visible\n\t# one-pixel gap without reintroducing the former T-shaped tangent spur.", "# Canonical patch sits three logical pixels outward from the terrain vertex.\n\t# This is the opposite one-pixel correction from the previous close vertex-2 anchor.")
	if not _write(PREVIEW_PATH, preview):
		get_tree().quit(1)
		return

	var workbench := FileAccess.get_file_as_string(WORKBENCH_PATH)
	if workbench.is_empty():
		push_error("Could not read workbench")
		get_tree().quit(1)
		return
	workbench = workbench.replace("var origin := LOGICAL_SIZE - 1", "var origin := LOGICAL_SIZE - 3")
	if not _write(WORKBENCH_PATH, workbench):
		get_tree().quit(1)
		return
	print("Hole Corner anchor moved one pixel in the opposite direction to vertex - 3")
	get_tree().quit()
