extends Node

func _ready() -> void:
	_patch_global_shaman_texture()
	_patch_surface_delay_maze_types()
	print("CI_FATAL_ERRORS_FIXED")
	get_tree().quit()

func _write(path: String, source: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Could not write %s" % path)
	file.store_string(source)
	file.close()

func _patch_global_shaman_texture() -> void:
	var path := "res://global.gd"
	var source := FileAccess.get_file_as_string(path)
	var old_path := "res://character_sprites/shaman_attack_spritesheet_25d.png"
	var new_path := "res://character_sprites/shaman_attack_spritesheet_25d_review.png"
	assert(source.contains(old_path), "Missing Shaman texture reference not found")
	source = source.replace(old_path, new_path)
	_write(path, source)

func _patch_surface_delay_maze_types() -> void:
	var path := "res://scripts/systems/surface_delay_maze.gd"
	var source := FileAccess.get_file_as_string(path)
	var old_text := "\tfor direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:\n\t\tvar neighbor := cell + direction\n"
	var new_text := "\tvar directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]\n\tfor direction: Vector2i in directions:\n\t\tvar neighbor: Vector2i = cell + direction\n"
	assert(source.contains(old_text), "Surface-delay neighbor block not found")
	source = source.replace(old_text, new_text)
	_write(path, source)
