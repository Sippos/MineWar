extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	var old_rules := "\tvar rules := [\n\t\t[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],\n\t\t[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],\n\t\t[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],\n\t\t[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],\n\t]"
	var new_rules := "\t# The canonical Hole Corner is the Edge Joint rotated 180 degrees, so