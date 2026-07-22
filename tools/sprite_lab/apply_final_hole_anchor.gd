extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	if text.is_empty():
		push_error("Could not read Dome material preview")
		get_tree().quit(1)
		return

	var old_block := '''func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:
	# The canonical 14x14 curve is anchored two logical pixels across the
	# terrain vertex. At vertex - 1, its axis endpoint overlaps the straight
	# border and creates the visible one-pixel T-shaped spur.
	var position := rect.position - Vector2(2.0, 2.0)
	match frame:
		1: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 2.0, rect.position.y - 2.0)
		2: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 2.0, rect.end.y - CORNER_PATCH_SIZE + 2.0)
		3: position = Vector2(rect.position.x - 2.0, rect.end.y - CORNER_PATCH_SIZE + 2.0)
	return Rect2(position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))
'''
	var new_block := '''func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:
	# Final canonical anchor: one logical pixel across the terrain vertex.
	# Endpoint ownership is handled separately, so this closes the last visible
	# one-pixel gap without reintroducing the former T-shaped tangent spur.
	var position := rect.position - Vector2.ONE
	match frame:
		1: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 1.0, rect.position.y - 1.0)
		2: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 1.0, rect.end.y - CORNER_PATCH_SIZE + 1.0)
		3: position = Vector2(rect.position.x - 1.0, rect.end.y - CORNER_PATCH_SIZE + 1.0)
	return Rect2(position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))
'''

	if not text.contains(old_block):
		push_error("Could not find current Hole Corner anchor block")
		get_tree().quit(1)
		return

	text = text.replace(old_block, new_block)
	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write Dome material preview")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Final Hole Corner anchor applied at vertex - 1; preview now matches export")
	get_tree().quit()
