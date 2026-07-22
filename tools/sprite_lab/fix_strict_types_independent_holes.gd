extends Node

const PATHS: Array[String] = [
	"res://tools/sprite_lab/dome_material_preview.gd",
	"res://tools/sprite_lab/dome_material_workbench.gd",
]

func _ready() -> void:
	for path in PATHS:
		var text := FileAccess.get_file_as_string(path)
		text = text.replace("\tvar base := Image.create(size, size, false, Image.FORMAT_RGBA8)", "\tvar base: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)")
		text = text.replace("\tvar hole := hole_source.duplicate()", "\tvar hole: Image = hole_source.duplicate()")
		text = text.replace("\t\t\tvar color := hole.get_pixel(x, y)", "\t\t\tvar color: Color = hole.get_pixel(x, y)")
		text = text.replace("\tvar atlas := Image.create(rendered_size * 2, rendered_size * 2, false, Image.FORMAT_RGBA8)", "\tvar atlas: Image = Image.create(rendered_size * 2, rendered_size * 2, false, Image.FORMAT_RGBA8)")
		text = text.replace("\t\tvar rendered := _rotate_vertex_composite(base, frame)", "\t\tvar rendered: Image = _rotate_vertex_composite(base, frame)")
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Could not write %s" % path)
			get_tree().quit(1)
			return
		file.store_string(text)
		file.close()
	print("Strict image/color types applied")
	get_tree().quit()
