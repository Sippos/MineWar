extends Node

func _ready() -> void:
	_patch_surface_maze()
	_patch_minewars_label()
	print("MINEWARS_RUNTIME_FIX_OK")
	get_tree().quit()

func _write(path: String, source: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Could not write %s" % path)
	file.store_string(source)
	file.close()

func _patch_surface_maze() -> void:
	var path := "res://scripts/systems/surface_delay_maze_world.gd"
	var source := FileAccess.get_file_as_string(path)
	var old_text := "\tfor direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:\n\t\tvar neighbor := cell + direction\n"
	var new_text := "\tvar directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]\n\tfor direction: Vector2i in directions:\n\t\tvar neighbor: Vector2i = cell + direction\n"
	assert(source.contains(old_text), "Surface maze neighbor block not found")
	source = source.replace(old_text, new_text)
	_write(path, source)

func _patch_minewars_label() -> void:
	var path := "res://scripts/systems/world_generation/siege_mode_controller.gd"
	var source := FileAccess.get_file_as_string(path)
	assert(source.contains("\ttitle.text = \"MINEWARS: SIEGE\"\n"), "Public Siege label not found")
	source = source.replace("\ttitle.text = \"MINEWARS: SIEGE\"\n", "\ttitle.text = \"MINEWARS\"\n")
	_write(path, source)
