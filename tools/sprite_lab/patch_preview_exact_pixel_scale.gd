extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	var old := "const CELL_SIZE := 34"
	var new := "const CELL_SIZE := 32"
	if not text.contains(old):
		push_error("Could not find preview cell-size constant")
		get_tree().quit(1)
		return
	text = text.replace(old, new)
	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write preview script")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Live cave preview now uses exact 32x32 pixel scaling")
	get_tree().quit()
