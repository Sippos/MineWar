extends Node

func _ready() -> void:
	var path := "res://scripts/systems/world_generation/siege_mode_controller.gd"
	var source := FileAccess.get_file_as_string(path)
	var bad := "\t\tlabel.add_theme_color_override(\"font_outline_color\", CBLACKabel.add_theme_constant_override(\"outline_size\", 3)"
	var good := "\t\tlabel.add_theme_color_override(\"font_outline_color\", Color.BLACK)\n\t\tlabel.add_theme_constant_override(\"outline_size\", 3)"
	if not source.contains(bad):
		push_error("Malformed marker line not found")
		get_tree().quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source.replace(bad, good))
	file.close()
	print("SIEGE_LINE_FIX_OK")
	get_tree().quit(0)
