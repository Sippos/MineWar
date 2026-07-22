extends Node

const PATHS := [
	"res://tools/sprite_lab/source/dome_material/easy_border_top_32.png",
	"res://tools/sprite_lab/source/dome_material/easy_hole_corner_top_left_32.png",
	"res://tools/sprite_lab/source/dome_material/easy_edge_joint_top_left_32.png",
]

func _ready() -> void:
	for path in PATHS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		image.convert(Image.FORMAT_RGBA8)
		var alpha_values: Dictionary = {}
		var brightest := Color.TRANSPARENT
		var brightest_value := -1.0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var color := image.get_pixel(x, y)
				if color.a <= 0.0:
					continue
				var alpha_key := snappedf(color.a, 0.01)
				alpha_values[alpha_key] = int(alpha_values.get(alpha_key, 0)) + 1
				var value := color.r + color.g + color.b
				if value > brightest_value:
					brightest_value = value
					brightest = color
		print(path)
		print("alphas=", alpha_values)
		print("brightest=", brightest)
	get_tree().quit()
