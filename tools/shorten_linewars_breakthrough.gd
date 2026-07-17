extends Node

func _ready() -> void:
	_patch("res://scripts/systems/preparation/preparation_fast_world.gd", {
		"const WORLD_TOP := -48": "const WORLD_TOP := -33",
		"const SURFACE_ROOM_Y_MIN := -31": "const SURFACE_ROOM_Y_MIN := -14",
		"const SURFACE_ROOM_Y_MAX := -23": "const SURFACE_ROOM_Y_MAX := -7"
	})
	_patch("res://scripts/systems/single_player_world_controller.gd", {
		"const LINE_WARS_ENTRY_Y := -23": "const LINE_WARS_ENTRY_Y := -7"
	})
	_patch("res://scripts/systems/continuous_line_wars_controller.gd", {
		"const SURFACE_MIN_CELL := Vector2i(-10, -47)": "const SURFACE_MIN_CELL := Vector2i(-10, -32)",
		"const SURFACE_MAX_CELL := Vector2i(10, -22)": "const SURFACE_MAX_CELL := Vector2i(10, -6)"
	})
	print("LINEWARS_BREAKTHROUGH_SHORTENED")
	get_tree().quit(0)

func _patch(path: String, replacements: Dictionary) -> void:
	var source := FileAccess.get_file_as_string(path)
	for old_text in replacements:
		source = source.replace(old_text, replacements[old_text])
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
