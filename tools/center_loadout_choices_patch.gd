extends Node

func _ready() -> void:
	var path := "res://scripts/ui/menus/loadout_selection_menu.gd"
	var source := FileAccess.get_file_as_string(path)
	var old_text := "\tbase_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n"
	var new_text := "\tbase_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER\n"
	if source.contains(new_text):
		print("CENTER_LOADOUT_CHOICES_ALREADY_APPLIED")
		get_tree().quit(0)
		return
	if source.is_empty() or not source.contains(old_text):
		push_error("Loadout choice alignment target missing")
		get_tree().quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source.replace(old_text, new_text))
	file.close()
	print("CENTER_LOADOUT_CHOICES_OK")
	get_tree().quit(0)
