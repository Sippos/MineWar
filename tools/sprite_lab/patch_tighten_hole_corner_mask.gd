extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	var old := "\tvar border_image := unmineable_border_image if owner_type == CellType.UNMINEABLE else selected_border_image\n\tvar logical_depth := CORNER_BUILDER.border_depth(border_image)\n\tvar depth := maxf(1.0, rect.size.x * (float(logical_depth) / float(LOGICAL_SIZE)))\n\tvar extent := rect.size.x * (14.0 / float(LOGICAL_SIZE))"
	var replacement := "\t# Erase only the bright rim endpoints. Clearing the complete rock-band depth\n\t# creates dark square bites because the corner sprite lives inside the empty cell.\n\tvar depth := maxf(1.0, rect.size.x * (2.0 / float(LOGICAL_SIZE)))\n\tvar extent := rect.size.x * (10.0 / float(LOGICAL_SIZE))"
	if not text.contains(old):
		push_error("Could not locate the Hole Corner endpoint mask sizing")
		get_tree().quit(1)
		return
	text = text.replace(old, replacement)
	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write tightened Hole Corner mask")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Hole Corner mask now clears only the bright rim endpoints")
	get_tree().quit()
