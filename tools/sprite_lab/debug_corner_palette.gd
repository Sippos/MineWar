extends Node

const PATHS := [
	"res://tools/sprite_lab/source/dome_material/easy_border_top_32.png",
	"res://tools/sprite_lab/source/dome_material/easy_hole_corner_top_left_32.png",
]

func _ready() -> void:
	for path in PATHS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		image.convert(Image.FORMAT_RGBA8)
		var counts: Dictionary = {}
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var c := image.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				var key := "%02x%02x%02x" % [roundi(c.r*255.0), roundi(c.g*255.0), roundi(c.b*255.0)]
				counts[key] = int(counts.get(key, 0)) + 1
		var entries: Array = []
		for key in counts.keys():
			entries.append([int(counts[key]), key])
		entries.sort_custom(func(a, b): return a[0] > b[0])
		print(path)
		for i in range(mini(12, entries.size())):
			print(entries[i])
	get_tree().quit()
