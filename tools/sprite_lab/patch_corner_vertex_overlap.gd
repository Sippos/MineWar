extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	var old_draw := "\t\tvar patch_position := rect.position\n\t\tmatch frame:\n\t\t\t1: patch_position += Vector2(rect.size.x - CORNER_PATCH_SIZE, 0)\n\t\t\t2: patch_position += Vector2(rect.size.x - CORNER_PATCH_SIZE, rect.size.y - CORNER_PATCH_SIZE)\n\t\t\t3: patch_position += Vector2(0, rect.size.y - CORNER_PATCH_SIZE)\n\t\tdraw_texture_rect(textures[frame], Rect2(patch_position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE)), false)"
	var new_draw := "\t\t# The straight border lives on the last pixel of the neighbouring solid\n\t\t# cells. Move the corner patch one logical pixel across the vertex so its\n\t\t# rim overlaps those endpoints instead of starting one pixel inside the cave.\n\t\tvar overlap := 1.0\n\t\tvar patch_position := rect.position - Vector2(overlap, overlap)\n\t\tmatch frame:\n\t\t\t1: patch_position = Vector2(rect.end.x - CORNER_PATCH_SIZE + overlap, rect.position.y - overlap)\n\t\t\t2: patch_position = Vector2(rect.end.x - CORNER_PATCH_SIZE + overlap, rect.end.y - CORNER_PATCH_SIZE + overlap)\n\t\t\t3: patch_position = Vector2(rect.position.x - overlap, rect.end.y - CORNER_PATCH_SIZE + overlap)\n\t\tdraw_texture_rect(textures[frame], Rect2(patch_position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE)), false)"
	if not text.contains(old_draw):
		push_error("Could not find Hole Corner draw block")
		get_tree().quit(1)
		return
	text = text.replace(old_draw, new_draw)
	var old_extent := "\tvar extent := rect.size.x * (float(CORNER_PATCH_SIZE - 2) / float(LOGICAL_SIZE))"
	var new_extent := "\t# The canonical source endpoint sits at local pixel 11. With the one-pixel\n\t# outward overlap, the underlying straight rim must be cleared for 11 pixels.\n\tvar extent := rect.size.x * (11.0 / float(LOGICAL_SIZE))"
	if not text.contains(old_extent):
		push_error("Could not find Hole Corner mask extent")
		get_tree().quit(1)
		return
	text = text.replace(old_extent, new_extent)
	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write preview script")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Hole Corner patches now overlap the shared cell vertex by one pixel")
	get_tree().quit()
