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
	source = source.replace("\tvar route := world.astar.get_id_path(expected_endpoint, Vector2i(0, -1))", "\tvar route: Array[Vector2i] = world.astar.get_id_path(expected_endpoint, Vector2i(0, -1))")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	print("LINEWARS_SPAWN_TEST_TYPES_FIXED")
	get_tree().quit(0)
