extends Node

func _ready() -> void:
	_patch_line_wars()
	_patch_adventure()
	print("MINEWARS_MODE_NAMES_OK")
	get_tree().quit()

func _write(path: String, source: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Could not write %s" % path)
	file.store_string(source)
	file.close()

func _replace_required(source: String, old_text: String, new_text: String, label: String) -> String:
	assert(source.contains(old_text), "Missing text for %s" % label)
	return source.replace(old_text, new_text)

func _patch_line_wars() -> void:
	var path := "res://maze_vs_prototype.tscn"
	var source := FileAccess.get_file_as_string(path)
	source = _replace_required(source, "text = \"MAZE BUILDER VS\"", "text = \"LINE WARS\"", "Line Wars title")
	source = _replace_required(source, "text = \"RETURN TO MODES\"", "text = \"RETURN TO OVERWORLD\"", "Line Wars return button")
	_write(path, source)

func _patch_adventure() -> void:
	var path := "res://scripts/systems/world_generation/exploration_mode_controller.gd"
	var source := FileAccess.get_file_as_string(path)
	source = _replace_required(source, "hud.show_notice(\"EXPLORATION: dig deeper, uncover artifacts, and survive the nests below.\", 5.5)", "hud.show_notice(\"ADVENTURE: dig deeper, uncover artifacts, and survive the nests below.\", 5.5)", "Adventure opening notice")
	source = _replace_required(source, "title.text = \"EXPLORATION MODE\"", "title.text = \"ADVENTURE\"", "Adventure title")
	_write(path, source)
