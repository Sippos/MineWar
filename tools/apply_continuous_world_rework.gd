extends Node

func _ready() -> void:
	_patch_world()
	_patch_player()
	print("CONTINUOUS_WORLD_PATCH_APPLIED")
	get_tree().quit(0)

func _patch_world() -> void:
	var path := "res://scripts/systems/world_generation/world.gd"
	var source := FileAccess.get_file_as_string(path)
	var marker := "func notify_protected_dig(world_position: Vector2, message: String) -> void:\n"
	if not source.contains(marker):
		push_error("world.gd insertion marker missing")
		get_tree().quit(1)
		return
	if source.contains("func is_dig_cell_protected(cell: Vector2i) -> bool:"):
		return
	var methods := "func is_dig_cell_protected(cell: Vector2i) -> bool:\n\t# Protect the original base foundation during standard runs. Specialized\n\t# persistent-world subclasses can open deliberate routes through it.\n\treturn (cell.y <= 1 and cell.x != 0) or cell.y < 0\n\nfunc get_protected_dig_message(cell: Vector2i) -> String:\n\tif cell.y < 0:\n\t\treturn \"You cannot mine upward into the base floor. Continue deeper or return through the shaft.\"\n\treturn \"The surface supports are protected. Dig down through the central shaft.\"\n\n"
	source = source.replace(marker, methods + marker)
	_write(path, source)

func _patch_player() -> void:
	var path := "res://player.gd"
	var source := FileAccess.get_file_as_string(path)
	var old_guard := "\t\t\t\tif (cell.y <= 1 and cell.x != 0) or cell.y < 0:\n\t\t\t\t\t_show_protected_dig_feedback(cell)\n\t\t\t\t\t_stop_digging()\n\t\t\t\t\treturn\n"
	var new_guard := "\t\t\t\tvar world := get_parent()\n\t\t\t\tvar protected := false\n\t\t\t\tif world and world.has_method(\"is_dig_cell_protected\"):\n\t\t\t\t\tprotected = bool(world.call(\"is_dig_cell_protected\", cell))\n\t\t\t\telse:\n\t\t\t\t\tprotected = (cell.y <= 1 and cell.x != 0) or cell.y < 0\n\t\t\t\tif protected:\n\t\t\t\t\t_show_protected_dig_feedback(cell)\n\t\t\t\t\t_stop_digging()\n\t\t\t\t\treturn\n"
	if source.contains(old_guard):
		source = source.replace(old_guard, new_guard)
	elif not source.contains("world.has_method(\"is_dig_cell_protected\")"):
		push_error("player.gd protection block missing")
		get_tree().quit(1)
		return

	var old_messages := "\tvar message := \"The surface supports are protected. Dig down through the central shaft.\"\n\tif cell.y < 0:\n\t\tmessage = \"You cannot mine upward into the base floor. Continue deeper or return through the shaft.\"\n\tvar world_position := tile_map.to_global(tile_map.map_to_local(cell))\n\tvar world := get_parent()\n"
	var new_messages := "\tvar world := get_parent()\n\tvar message := \"The surface supports are protected. Dig down through the central shaft.\"\n\tif world and world.has_method(\"get_protected_dig_message\"):\n\t\tmessage = str(world.call(\"get_protected_dig_message\", cell))\n\telif cell.y < 0:\n\t\tmessage = \"You cannot mine upward into the base floor. Continue deeper or return through the shaft.\"\n\tvar world_position := tile_map.to_global(tile_map.map_to_local(cell))\n"
	if source.contains(old_messages):
		source = source.replace(old_messages, new_messages)
	_write(path, source)

func _write(path: String, source: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + path)
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
