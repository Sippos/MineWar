extends Node

func _ready() -> void:
	var path := "res://tools/sprite_lab/dome_material_workbench.gd"
	var text := FileAccess.get_file_as_string(path)
	text = text.replace("\tvar directory_result := _ensure_output_dirs()", "\tvar directory_result: Error = _ensure_output_dirs()")
	text = text.replace("\tvar result := mass_image.save_png", "\tvar result: Error = mass_image.save_png")
	text = text.replace("\tvar result := mass_export.save_png", "\tvar result: Error = mass_export.save_png")
	text = text.replace("\tvar source_result := DirAccess.make_dir_recursive_absolute", "\tvar source_result: Error = DirAccess.make_dir_recursive_absolute")
	text = text.replace("\tvar runtime_result := DirAccess.make_dir_recursive_absolute", "\tvar runtime_result: Error = DirAccess.make_dir_recursive_absolute")
	text = text.replace("\tvar light := _find_brightest_color(top_stamp)", "\tvar light: Color = _find_brightest_color(top_stamp)")
	text = text.replace("\t\t\tvar value := color.r + color.g + color.b", "\t\t\tvar value: float = color.r + color.g + color.b")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not patch dome workbench types")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Patched dome workbench inferred types")
	get_tree().quit()
