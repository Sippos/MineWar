extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _patch(path: String) -> bool:
	var text := FileAccess.get_file_as_string(path)
	var old_endpoint := "var endpoint := CORNER_PATCH_SIZE - 2"
	var new_endpoint := "var endpoint := CORNER_PATCH_SIZE - 3 # Rim endpoints are at pixel 11, not 12."
	if not text.contains(old_endpoint):
		push_error("Missing endpoint declaration in %s" % path)
		return false
	text = text.replace(old_endpoint, new_endpoint)
	var old_draw := "base.set_pixel(LOGICAL_SIZE + x, LOGICAL_SIZE + y, color)"
	var new_draw := "base.set_pixel(LOGICAL_SIZE - 1 + x, LOGICAL_SIZE - 1 + y, color)"
	if not text.contains(old_draw):
		push_error("Missing hole draw origin in %s" % path)
		return false
	text = text.replace(old_draw, new_draw)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true

func _ready() -> void:
	if not _patch(PREVIEW_PATH) or not _patch(WORKBENCH_PATH):
		get_tree().quit(1)
		return
	print("Hole curve endpoints now align at the terrain boundary")
	get_tree().quit()
