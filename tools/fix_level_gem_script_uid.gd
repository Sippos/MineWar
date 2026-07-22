extends Node

const LEVEL_PATH := "res://scenes/world/mine/level.tscn"
const WRONG := "[ext_resource type=\"Script\" uid=\"uid://bmhoamkntdku5\" path=\"res://scripts/systems/world_generation/world_gem_visuals.gd\" id=\"1_world\"]"
const RIGHT := "[ext_resource type=\"Script\" path=\"res://scripts/systems/world_generation/world_gem_visuals.gd\" id=\"1_world\"]"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(LEVEL_PATH)
	if source.is_empty():
		push_error("Could not read %s" % LEVEL_PATH)
		get_tree().quit(1)
		return
	if source.contains(WRONG):
		source = source.replace(WRONG, RIGHT)
		var file := FileAccess.open(LEVEL_PATH, FileAccess.WRITE)
		if file == null:
			push_error("Could not write %s" % LEVEL_PATH)
			get_tree().quit(1)
			return
		file.store_string(source)
		file.close()
		print("FIXED_LEVEL_GEM_SCRIPT_UID")
	elif source.contains(RIGHT):
		print("LEVEL_GEM_SCRIPT_UID_ALREADY_FIXED")
	else:
		push_error("Expected level script resource line was not found")
		get_tree().quit(1)
		return
	get_tree().quit(0)
