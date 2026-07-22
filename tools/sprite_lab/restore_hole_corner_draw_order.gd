extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	var old_block := '''	# Hole Corners belong behind a downward front face. The extrusion texture
	# contains an opaque cave-colour ownership rectangle, so its transparent
	# curve cutouts cannot reveal these overlays as gray rims.
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var empty_cell := Vector2i(x, y)
			if not _is_solid(empty_cell):
				_draw_hole_c