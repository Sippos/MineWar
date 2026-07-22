extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	var start := text.find("func _draw_hole_corners(")
	var finish := text.find("\nfunc _cell_from_position", start)
	if start < 0 or finish < 0:
		push_error("Could not find Hole Corner draw block")
		get_tree().quit(1)
		return

	var replacement := '''func _draw_hole_corners(empty_cell: Vector2i, rect: Rect2) -> void:
	var rules := [
		[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],
		[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],
		[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],
		[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],
	]
	for rule_value in rules:
		var rule: Array = rule_value
		var first: Vector2i = rule[0]
		var second: Vector2i = rule[1]
		var diagonal: Vector2i = rule[2]
		var frame: int = rule[3]
		if not _is_solid(empty_cell + first) or not _is_solid(empty_cell + second) or not _is_solid(empty_cell + diagonal):
			continue
		var owner_type := _cell_type(empty_cell + diagonal)
		var textures := _inside_corner_textures_for(owner_type)
		if frame >= textures.size() or textures[frame] == null:
			continue
		var patch_rect := _hole_corner_patch_rect(rect, frame)
		_mask_hole_corner_border_bands(rect, patch_rect, frame, owner_type)
		draw_texture_rect(textures[frame], patch_rect, false)

func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:
	# One-pixel overlap makes the corner share the exact endpoint pixel with the
	# neighbouring straight borders instead of starting one pixel inside the cave.
	var overlap := 1.0
	var patch_position := rect.position - Vector2(overlap, overlap)
	match frame:
		1:
			patch_position = Vector2(rect.end.x - CORNER_PATCH_SIZE + overlap, rect.position.y - overlap)
		2:
			patch_position = Vector2(rect.end.x - CORNER_PATCH_SIZE + overlap, rect.end.y - CORNER_PATCH_SIZE + overlap)
		3:
			patch_position = Vector2(rect.position.x - overlap, rect.end.y - CORNER_PATCH_SIZE + overlap)
	return Rect2(patch_position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))

func _border_depth_for(owner_type: int) -> int:
	var image: Image = unmineable_border_image if owner_type == CellType.UNMINEABLE else selected_border_image
	if image == null or image.is_empty():
		return 2
	var deepest := -1
	for y in range(mini(LOGICAL_SIZE, image.get_height())):
		for x in range(mini(LOGICAL_SIZE, image.get_width())):
			if image.get_pixel(x, y).a > 0.05:
				deepest = maxi(deepest, y)
	return clampi(deepest + 1, 1, CORNER_PATCH_SIZE)

func _mask_hole_corner_border_bands(rect: Rect2, patch_rect: Rect2, frame: int, owner_type: int) -> void:
	# The corner is a replacement, not a decoration. Clear the complete two
	# straight-border bands beneath its footprint, then draw the authored curve.
	# This prevents the old highlight/shading rows from showing through as grey
	# bars and guarantees one continuous border loop.
	var depth := float(_border_depth_for(owner_type))
	match frame:
		0:
			draw_rect(Rect2(Vector2(patch_rect.position.x, rect.position.y - depth), Vector2(patch_rect.size.x, depth + 1.0)), CAVE_COLOR)
			draw_rect(Rect2(Vector2(rect.position.x - depth, patch_rect.position.y), Vector2(depth + 1.0, patch_rect.size.y)), CAVE_COLOR)
		1:
			draw_rect(Rect2(Vector2(patch_rect.position.x, rect.position.y - depth), Vector2(patch_rect.size.x, depth + 1.0)), CAVE_COLOR)
			draw_rect(Rect2(Vector2(rect.end.x - 1.0, patch_rect.position.y), Vector2(depth + 1.0, patch_rect.size.y)), CAVE_COLOR)
		2:
			draw_rect(Rect2(Vector2(patch_rect.position.x, rect.end.y - 1.0), Vector2(patch_rect.size.x, depth + 1.0)), CAVE_COLOR)
			draw_rect(Rect2(Vector2(rect.end.x - 1.0, patch_rect.position.y), Vector2(depth + 1.0, patch_rect.size.y)), CAVE_COLOR)
		3:
			draw_rect(Rect2(Vector2(patch_rect.position.x, rect.end.y - 1.0), Vector2(patch_rect.size.x, depth + 1.0)), CAVE_COLOR)
			draw_rect(Rect2(Vector2(rect.position.x - depth, patch_rect.position.y), Vector2(depth + 1.0, patch_rect.size.y)), CAVE_COLOR)
'''

	text = text.substr(0, start) + replacement + text.substr(finish)
	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write preview script")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Hole Corners now replace the complete underlying border bands")
	get_tree().quit()
