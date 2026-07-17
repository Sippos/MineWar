extends Node

func _ready() -> void:
	var path := "res://scripts/systems/preparation/preparation_world_controller.gd"
	var source := FileAccess.get_file_as_string(path)
	assert(source.contains("\tplayer.movement_enabled = false\n"), "Hub transition line not found")
	source = source.replace("\tplayer.movement_enabled = false\n", "\tplayer.set_physics_process(false)\n")
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Could not write hub controller")
	file.store_string(source)
	file.close()
	print("HUB_TRANSITION_FIX_OK")
	get_tree().quit()
