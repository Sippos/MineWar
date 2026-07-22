extends Node

func _ready() -> void:
	var canvas_path := "res://tools/sprite_lab/terrain_interaction_canvas.gd"
	var canvas_source := FileAccess.get_file_as_string(canvas_path)
	canvas_source = canvas_source.replace("const CELL_SIZE := 48", "const CELL_SIZE := 40")
	var canvas_file := FileAccess.open(canvas_path, FileAccess.WRITE)
	if canvas_file == null:
		push_error("Could not patch terrain canvas layout")
		get_tree().quit(1)
		return
	canvas_file.store_string(canvas_source)
	canvas_file.close()
	print("PATCHED_TERRAIN_LAB_LAYOUT")
	get_tree().quit(0)
