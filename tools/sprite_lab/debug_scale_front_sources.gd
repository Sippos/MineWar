extends Node

func _ready() -> void:
	var paths := {
		"source": "res://tools/sprite_lab/source/dome_material/easy_front_face_32.png",
		"runtime": "res://assets/sprites/world/terrain/dome/Easy_Front_Face.png",
		"mask6": "res://tools/sprite_lab/debug_front_masks/mask_6_depth_32.png",
	}
	for key in paths:
		var image := Image.load_from_file(ProjectSettings.globalize_path(paths[key]))
		if image == null or image.is_empty():
			continue
		image.convert(Image.FORMAT_RGBA8)
		image.resize(image.get_width() * 8, image.get_height() * 8, Image.INTERPOLATE_NEAREST)
		image.save_png("res://tools/sprite_lab/debug_front_masks/scaled_%s.png" % key)
	get_tree().quit(0)
