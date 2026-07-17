extends Node

func _ready() -> void:
	var path := "res://scripts/systems/single_player_world_controller.gd"
	var source := FileAccess.get_file_as_string(path)
	source = source.replace("const LINE_WARS_ENTRY_Y := -7", "const LINE_WARS_ENTRY_Y := -5")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	print("LINEWARS_ACTIVATION_LIP_FIXED")
	get_tree().quit(0)
