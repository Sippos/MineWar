extends Node

func _ready() -> void:
	var image := Image.load_from_file("res://GemOverlay.png")
	var counts := {}
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var c := image.get_pixel(x, y)
			var key := "%02x%02x%02x" % [int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0))]
			counts[key] = int(counts.get(key, 0)) + 1
	var keys: Array = counts.keys()
	keys.sort_custom(func(a, b): return int(counts[b]) < int(counts[a]))
	for i in range(mini(20, keys.size())):
		var key: String = keys[i]
		print("GEM_COLOR ", key, " count=", counts[key])
	for point in [Vector2i(10, 10), Vector2i(40, 10), Vector2i(70, 10), Vector2i(100, 10), Vector2i(10, 40), Vector2i(40, 40), Vector2i(70, 40)]:
		print("GEM_SAMPLE ", point, " ", image.get_pixelv(point))
	get_tree().quit(0)
