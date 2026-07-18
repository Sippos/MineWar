extends Node

func _ready() -> void:
	var path := "res://global.gd"
	var source := FileAccess.get_file_as_string(path)
	var old_text := "\t\tvar victory_hero := current_hero\n"
	var new_text := "\t\tvar victory_hero: String = str(current_hero)\n"
	if source.count(old_text) != 1:
		push_error("Could not find victory_hero typing patch target")
		get_tree().quit(1)
		return
	source = source.replace(old_text, new_text)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write global.gd")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("STRONGHOLD_AMBIENCE_TYPES_FIXED")
	get_tree().quit(0)
