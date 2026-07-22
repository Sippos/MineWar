extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	var old := "\t\t_mask_hole_corner_border_bands(rect, patch_rect, frame, owner_type)\n\t\tdraw_texture_rect(textures[frame], patch_rect, false)"
	var new := "\t\t# The authored patch overlaps both straight-border endpoint pixels.\n\t\t# Draw it directly; destructive masks create square bites in solid rock.\n\t\tdraw_texture_rect(textures[frame], patch_rect, false)"
	if not text.contains(old):
		push_error("Could not find full-band mask call")
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
	print("Hole Corner preview now uses direct one-pixel overlap without destructive masks")
	get_tree().quit()
