extends Node

func _ready() -> void:
	var path := "res://tools/sprite_lab/dome_material_workbench.gd"
	var text := FileAccess.get_file_as_string(path)
	var old := "\tpreview.call(\"set_material_images\", mass_image, border_images[current_tier], border_images[\"unmineable\"])"
	var new := "\tvar inner_border: Image = border_images[\"easy\"] if current_tier == \"unmineable\" else border_images[current_tier]\n\tpreview.call(\"set_material_images\", mass_image, inner_border, border_images[\"unmineable\"])"
	if not text.contains(old):
		push_error("Could not find preview material call")
		get_tree().quit(1)
		return
	text = text.replace(old, new)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not patch unmineable preview")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Separated unmineable outer ring from inner mineable preview")
	get_tree().quit()
