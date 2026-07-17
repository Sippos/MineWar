extends Node

func _ready() -> void:
	_patch_fast_world()
	_patch_hub_trigger()
	print("CONTINUOUS_LINEWARS_ROUTE_FIX_APPLIED")
	get_tree().quit(0)

func _patch_fast_world() -> void:
	var path := "res://scripts/systems/preparation/preparation_fast_world.gd"
	var source := FileAccess.get_file_as_string(path)
	source = source.replace("const WORLD_TOP := -32", "const WORLD_TOP := -48")
	source = source.replace(
		"func _on_generation_cell_dug(cell: Vector2i) -> void:\n\tif astar.is_in_bounds(cell.x, cell.y):\n\t\ton_cell_dug(cell)",
		"func _on_generation_cell_dug(cell: Vector2i) -> void:\n\t# TileMap terrain extends above the legacy A* region. Always carve the tile;\n\t# world.on_cell_dug already updates A* only when the cell is inside its bounds.\n\ton_cell_dug(cell)"
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)

func _patch_hub_trigger() -> void:
	var path := "res://scripts/systems/single_player_world_controller.gd"
	var source := FileAccess.get_file_as_string(path)
	source = source.replace("const LINE_WARS_ENTRY_Y := -22", "const LINE_WARS_ENTRY_Y := -23")
	source = source.replace(
		"if cell.y <= LINE_WARS_ENTRY_Y:\n\t\t_activate_line_wars()",
		"if cell.y <= LINE_WARS_ENTRY_Y and cell.x >= 2 and cell.x <= 4:\n\t\t_activate_line_wars()"
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
