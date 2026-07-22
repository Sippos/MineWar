extends Node

func _ready() -> void:
	var path := "res://tools/sprite_lab/terrain_interaction_canvas.gd"
	var source := FileAccess.get_file_as_string(path)
	source = source.replace("\t\tfor direction in [Vector2i.RIGHT, Vector2i.DOWN]:\n\t\t\tvar neighbor := cell + direction", "\t\tfor direction_value: Variant in [Vector2i.RIGHT, Vector2i.DOWN]:\n\t\t\tvar direction: Vector2i = direction_value\n\t\t\tvar neighbor: Vector2i = cell + direction")
	source = source.replace("\tvar parsed := JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))", "\tvar parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not patch terrain interaction canvas")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("PATCHED_TERRAIN_LAB_TYPES")
	get_tree().quit(0)
