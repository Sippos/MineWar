extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/world/terrain/dome/Easy_Front_Face.png")
	var min_y = 999
	var max_y = -1
	for y in range(img.get_height()):
		var has_color = false
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0:
				has_color = true
				break
		if has_color:
			if min_y == 999: min_y = y
			max_y = y
	print("Min Y: ", min_y, " Max Y: ", max_y)
	quit()
