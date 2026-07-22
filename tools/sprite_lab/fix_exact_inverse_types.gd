extends Node

const PATH := "res://tools/sprite_lab/dome_corner_builder.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		push_error("Could not read corner builder")
		get_tree().quit(1)
		return
	text = text.replace("\tvar joint := edge_joint", "\tvar joint: Image = edge_joint")
	text = text.replace("\tvar mass := mass_image.duplicate()", "\tvar mass: Image = mass_image.duplicate()")
	text = text.replace("\tvar result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)\n\tresult.fill(Color.TRANSPARENT)\n\tvar depth := border_depth(top_border)\n\tvar solid_points", "\tvar result: Image = Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)\n\tresult.fill(Color.TRANSPARENT)\n\tvar depth: int = border_depth(top_border)\n\tvar solid_points")
	text = text.replace("\t\t\tvar color := mass.get_pixel(x, y)", "\t\t\tvar color: Color = mass.get_pixel(x, y)")
	text = text.replace("\t\t\tvar nearest_distance := INF", "\t\t\tvar nearest_distance: float = INF")
	text = text.replace("\t\t\t\tvar distance := Vector2(Vector2i(x, y) - solid_point).length()", "\t\t\t\tvar distance: float = Vector2(Vector2i(x, y) - solid_point).length()")
	text = text.replace("\t\t\t\tvar palette_row := clampi(floori(nearest_distance) - 1, 0, depth - 1)", "\t\t\t\tvar palette_row: int = clampi(floori(nearest_distance) - 1, 0, depth - 1)")
	text = text.replace("\t\t\t\tvar rim_color := average_border_row(top_border, palette_row)", "\t\t\t\tvar rim_color: Color = average_border_row(top_border, palette_row)")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write corner builder")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Exact inverse corner typing fixed")
	get_tree().quit()
