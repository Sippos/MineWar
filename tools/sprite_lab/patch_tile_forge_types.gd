extends Node

func _ready() -> void:
	var path := "res://tools/sprite_lab/golden_source_editor.gd"
	var text := FileAccess.get_file_as_string(path)
	var old_block := "func _load_initial_image() -> Image:\n\tvar source := _load_source_json()\n\tif source != null:\n\t\treturn source\n\tvar production := _load_production_image()\n\tif production != null:\n\t\treturn production\n\treturn _make_dome_starter()"
	var new_block := "func _load_initial_image() -> Image:\n\tvar source := _load_source_json()\n\tif source != null:\n\t\treturn source\n\t# Start new authored work from the face-only contract. The old production\n\t# asset can still be imported explicitly for comparison or repair.\n\treturn _make_dome_starter()"
	if not text.contains(old_block):
		push_error("Could not find initial image block")
		get_tree().quit(1)
		return
	text = text.replace(old_block, new_block)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not patch tile forge initial source")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Tile forge now starts from the clean face-only source contract")
	get_tree().quit()
