extends Node

func _ready() -> void:
	var path := "res://tools/sprite_lab/golden_source_editor.gd"
	var source := FileAccess.get_file_as_string(path)
	source = source.replace("\t\tfor direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:\n\t\t\tvar next := cell + direction", "\t\tvar directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]\n\t\tfor direction: Vector2i in directions:\n\t\t\tvar next: Vector2i = cell + direction")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	print("FIXED_GOLDEN_SOURCE_EDITOR_TYPES")
	get_tree().quit()
