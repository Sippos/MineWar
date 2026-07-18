extends Node

func _ready() -> void:
	var path := "res://scenes/world/mine/level.tscn"
	var text := FileAccess.get_file_as_string(path)
	var old := "path=\"res://scripts/systems/world_generation/world.gd\" id=\"1_world\""
	var replacement := "path=\"res://scripts/systems/world_generation/world_gem_visuals.gd\" id=\"1_world\""
	if text.contains(replacement):
		print("level.tscn already uses world_gem_visuals.gd")
		get_tree().quit(0)
		return
	if not text.contains(old):
		push_error("Expected world script reference was not found in level.tscn")
		get_tree().quit(1)
		return
	text = text.replace(old, replacement)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open level.tscn for writing")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Updated level.tscn to use world_gem_visuals.gd")
	get_tree().quit(0)
