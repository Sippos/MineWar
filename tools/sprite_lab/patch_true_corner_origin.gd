extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const WORLD_PATH := "res://scripts/systems/world_generation/world.gd"

func _ready() -> void:
	var error := _patch_preview()
	if error != OK:
		push_error("Could not patch preview corner origin: %s" % error_string(error))
		get_tree().quit(1)
		return
	error = _patch_runtime()
	if error != OK:
		push_error("Could not patch runtime corner origin: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("Hole Corner source pixel (0,0) now maps to the true cave vertex in preview and runtime")
	get_tree().quit()

func _patch_preview() -> Error:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	var start := text.find("func _hole_corner_patch_rect(")
	var finish := text.find("\nfunc _border_depth_for", start)
	if start < 0 or finish < 0:
		return ERR_DOES_NOT_EXIST
	var replacement := "func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:\n\t# Source pixel (0,0) is the exact cave vertex. No hidden overlap offset.\n\tvar patch_position := rect.position\n\tmatch frame:\n\t\t1:\n\t\t\tpatch_position = Vector2(rect.end.x - CORNER_PATCH_SIZE, rect.position.y)\n\t\t2:\n\t\t\tpatch_position = Vector2(rect.end.x - CORNER_PATCH_SIZE, rect.end.y - CORNER_PATCH_SIZE)\n\t\t3:\n\t\t\tpatch_position = Vector2(rect.position.x, rect.end.y - CORNER_PATCH_SIZE)\n\treturn Rect2(patch_position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))\n"
	text = text.substr(0, start) + replacement + text.substr(finish + 1)
	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK

func _patch_runtime() -> Error:
	var text := FileAccess.get_file_as_string(WORLD_PATH)
	var old := "\t\tvar corner_offset := Vector2.ZERO\n\t\tmatch frame:\n\t\t\t0: corner_offset = Vector2(-2, -2)\n\t\t\t1: corner_offset = Vector2(2, -2)\n\t\t\t2: corner_offset = Vector2(2, 2)\n\t\t\t3: corner_offset = Vector2(-2, 2)\n\t\tsprite.position = inside_corner_layer.to_local(block_layer.to_global(block_layer.map_to_local(cell))) + corner_offset"
	var new := "\t\t# Atlas frame origin matches the empty cell exactly; no hidden corner offset.\n\t\tsprite.position = inside_corner_layer.to_local(block_layer.to_global(block_layer.map_to_local(cell)))"
	if not text.contains(old):
		return ERR_DOES_NOT_EXIST
	text = text.replace(old, new)
	var file := FileAccess.open(WORLD_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK
