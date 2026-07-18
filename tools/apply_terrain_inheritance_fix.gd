extends Node

func _ready() -> void:
	_patch_first_line(
		"res://scripts/systems/world_generation/world_gem_visuals.gd",
		"extends \"res://scripts/systems/world_generation/world.gd\"",
		"extends \"res://scripts/systems/world_generation/world_terrain_runtime.gd\""
	)
	_patch_first_line(
		"res://scripts/systems/preparation/preparation_fast_world.gd",
		"extends \"res://scripts/systems/world_generation/world.gd\"",
		"extends \"res://scripts/systems/world_generation/world_terrain_runtime.gd\""
	)
	print("Applied terrain runtime inheritance to standard and continuous worlds.")
	get_tree().quit()

func _patch_first_line(path: String, old_line: String, new_line: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.begins_with(new_line):
		return
	if not text.begins_with(old_line):
		push_error("Unexpected first line in %s" % path)
		return
	text = new_line + text.substr(old_line.length())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return
	file.store_string(text)
	file.close()
