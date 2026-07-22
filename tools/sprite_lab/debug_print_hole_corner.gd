extends Node

const SOURCE := "res://tools/sprite_lab/source/dome_material/easy_hole_corner_top_left_32.png"

func _ready() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if image == null or image.is_empty():
		push_error("Could not load Hole Corner")
		get_tree().quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	for y in range(14):
		var row := ""
		for x in range(14):
			var c := image.get_pixel(x, y)
			if c.a < 0.05:
				row += "."
			elif c.r + c.g + c.b > 1.7:
				row += "#"
			else:
				row += "+"
		print("%02d %s" % [y, row])
	get_tree().quit()
