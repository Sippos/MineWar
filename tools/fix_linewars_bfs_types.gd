extends Node

func _ready() -> void:
	var path := "res://scripts/systems/continuous_line_wars_controller.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open LineWars controller")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	file.close()
	source = source.replace("\t\tfor direction in CARDINAL_DIRECTIONS:\n\t\t\tvar neighbor := cell + direction", "\t\tfor direction_value in CARDINAL_DIRECTIONS:\n\t\t\tvar direction: Vector2i = direction_value\n\t\t\tvar neighbor: Vector2i = cell + direction")
	source = source.replace("\tfor direction in CARDINAL_DIRECTIONS:\n\t\tvar neighbor := cell + direction", "\tfor direction_value in CARDINAL_DIRECTIONS:\n\t\tvar direction: Vector2i = direction_value\n\t\tvar neighbor: Vector2i = cell + direction")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	print("LINEWARS_BFS_TYPES_FIXED")
	get_tree().quit(0)
