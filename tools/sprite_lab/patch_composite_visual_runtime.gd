extends Node

func _ready() -> void:
	var path := "res://scripts/systems/world_generation/world.gd"
	var text := FileAccess.get_file_as_string(path)
	text = text.replace(
		"\tif block_layer.get_cell_source_id(cell) == -1:\n\t\tfog_layer.erase_cell(cell)\n\t\t_refresh_inside_corners_around(cell)\n\t\treturn",
		"\tif block_layer.get_cell_source_id(cell) == -1:\n\t\tfog_layer.erase_cell(cell)\n\t\tedge_layer.erase_cell(cell)\n\t\t_refresh_inside_corners_around(cell)\n\t\treturn"
	)
	var old_visual := "\tif index != 0:\n\t\tvar block_type = block_layer.get_cell_source_id(cell)\n\t\tvar edge_source = 4 # Easy\n\t\tif block_type == 2: edge_source = 5\n\t\telif block_type == 3: edge_source = 6\n\t\tedge_layer.set_cell(cell, edge_source, Vector2i(atlas_x, atlas_y))\n\telse:\n\t\tedge_layer.erase_cell(cell)"
	var new_visual := "\t# EdgeLayer now contains the complete visible cell, including the universal\n\t# mass for mask 0 and true transparent rounded cutouts for corner masks.\n\tvar block_type = block_layer.get_cell_source_id(cell)\n\tvar edge_source = 4 # Easy\n\tif block_type == 2: edge_source = 5\n\telif block_type == 3: edge_source = 6\n\tedge_layer.set_cell(cell, edge_source, Vector2i(atlas_x, atlas_y))"
	if not text.contains(old_visual):
		push_error("Could not find old edge-layer branch")
		get_tree().quit(1)
		return
	text = text.replace(old_visual, new_visual)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not patch composite visual runtime")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Composite rounded visual runtime installed")
	get_tree().quit()
