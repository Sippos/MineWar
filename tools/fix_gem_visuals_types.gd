extends Node

const PATH := "res://scripts/systems/world_generation/world_gem_visuals.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(PATH)
	if source.is_empty():
		push_error("Could not read %s" % PATH)
		get_tree().quit(1)
		return
	source = source.replace("\t\tvar current := pending.pop_back()", "\t\tvar current: Vector2i = pending.pop_back()")
	source = source.replace("\t\t\tvar neighbor := current + direction", "\t\t\tvar neighbor: Vector2i = current + direction")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % PATH)
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("FIXED_GEM_VISUAL_TYPE_INFERENCE")
	get_tree().quit(0)
