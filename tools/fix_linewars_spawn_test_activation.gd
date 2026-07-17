extends Node

func _ready() -> void:
	var path := "res://tests/linewars_farthest_spawn_smoke_runner.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open farthest spawn test")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	file.close()
	source = source.replace("\thero.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(3, -4)))\n\tworld.call(\"on_cell_dug\", approach_cell)\n\tworld.call(\"on_cell_dug\", cap_cell)", "\thero.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(3, -4)))\n\tworld.call(\"on_cell_dug\", approach_cell)\n\thero.global_position = block_layer.to_global(block_layer.map_to_local(approach_cell))\n\tworld.call(\"on_cell_dug\", cap_cell)")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	print("LINEWARS_SPAWN_TEST_ACTIVATION_FIXED")
	get_tree().quit(0)
