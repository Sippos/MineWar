extends Node

func _ready() -> void:
	var path := "res://global.gd"
	var source := FileAccess.get_file_as_string(path)
	source = source.replace("\tvar previous_heroes := unlocked_heroes.duplicate()", "\tvar previous_heroes: Array = unlocked_heroes.duplicate()")
	source = source.replace("\tvar previous_bases := unlocked_bases.duplicate()", "\tvar previous_bases: Array = unlocked_bases.duplicate()")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	print("MINEWARS_PROGRESSION_TYPES_FIXED")
	get_tree().quit(0)
