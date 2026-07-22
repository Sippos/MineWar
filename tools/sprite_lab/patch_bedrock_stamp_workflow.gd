extends Node

func _ready() -> void:
	var path := "res://tools/sprite_lab/dome_material_workbench.gd"
	var text := FileAccess.get_file_as_string(path)
	text = text.replace("\t_add_mode_button(controls, \"bedrock\", \"BEDROCK • unmineable tile\")", "\t_add_mode_button(controls, \"bedrock\", \"BEDROCK WALL • one straight stamp\")")
	text = text.replace("\texport_note.text = \"Export creates the universal 64×64 mass tile and automatically builds Easy, Medium and Hard 4×4 border atlases.\"", "\texport_note.text = \"Export creates the universal mass plus automatic Easy, Medium, Hard and Bedrock wall atlases from one straight stamp each.\"")
	text = text.replace("\tbedrock_image = _load_png_or_svg_logical(RUNTIME_BEDROCK_PATH, FALLBACK_BEDROCK_PATH)", "\tbedrock_image = _keep_top_band(_load_png_or_svg_logical(RUNTIME_BEDROCK_PATH, FALLBACK_BEDROCK_PATH))")
	text = text.replace("func _extract_top_stamp(atlas: Image) -> Image:", "func _keep_top_band(source: Image) -> Image:\n\tvar result := source.duplicate()\n\tfor y in range(11, LOGICAL_SIZE):\n\t\tfor x in range(LOGICAL_SIZE):\n\t\t\tresult.set_pixel(x, y, Color.TRANSPARENT)\n\treturn result\n\nfunc _extract_top_stamp(atlas: Image) -> Image:")
	text = text.replace("func _active_region() -> Rect2i:\n\treturn Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, 11)) if current_mode == \"border\" else Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))", "func _active_region() -> Rect2i:\n\treturn Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, 11)) if current_mode == \"border\" or current_mode == \"bedrock\" else Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))")
	text = text.replace("\t\t\"bedrock\":\n\t\t\treturn \"BEDROCK • UNMINEABLE FULL TILE\"", "\t\t\"bedrock\":\n\t\t\treturn \"BEDROCK WALL • AUTHOR ONE STRAIGHT STAMP\"")
	text = text.replace("\tvar base: Image = mass_image if current_mode == \"border\" else null", "\tvar base: Image = mass_image if current_mode == \"border\" or current_mode == \"bedrock\" else null")
	text = text.replace("\t\t\"bedrock\":\n\t\t\tinstruction_label.text = \"Paint the full-color boundary tile. This is collision-only bedrock and can never be mined.\"", "\t\t\"bedrock\":\n\t\t\tinstruction_label.text = \"Paint one straight CYAN TOP BAND. The hub and map boundary rotate and join this unmineable wall automatically.\"")
	text = text.replace("\tresult = bedrock_image.save_png(SOURCE_DIR + \"/bedrock_32.png\") if result == OK else result", "\tresult = bedrock_image.save_png(SOURCE_DIR + \"/bedrock_border_top_32.png\") if result == OK else result")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not patch bedrock stamp workflow")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Bedrock is now authored as one straight wall stamp")
	get_tree().quit()
