extends Node

func _ready() -> void:
	_patch("res://scripts/systems/single_player_world_controller.gd", {
		"player.position = Vector2(0, -32)": "player.position = Vector2(192, -32)"
	})
	_patch("res://scripts/systems/preparation/preparation_fast_world.gd", {
		"var vertical_route := absi(cell.x) <= 2": "var vertical_route := cell.x >= 2 and cell.x <= 4",
		"if absi(cell.x) <= 2:": "if cell.x >= 2 and cell.x <= 4:"
	})
	_patch("res://scenes/world/preparation/single_player_mode_signs.tscn", {
		"position = Vector2(-125, -330)": "position = Vector2(67, -330)",
		"position = Vector2(-125, 28)": "position = Vector2(67, 28)"
	})
	print("SINGLE_PLAYER_VERTICAL_ROUTE_SHIFTED")
	get_tree().quit(0)

func _patch(path: String, replacements: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read %s" % path)
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	file.close()
	for old_text in replacements:
		if not source.contains(old_text):
			push_error("Missing patch target in %s: %s" % [path, old_text])
			get_tree().quit(1)
			return
		source = source.replace(old_text, replacements[old_text])
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
