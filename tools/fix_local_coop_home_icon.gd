extends Node

const TARGET := "res://local_coop_mode.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(TARGET)
	if source.is_empty():
		push_error("Could not read local_coop_mode.gd")
		get_tree().quit(1)
		return

	source = source.replace('const HOME_ICON := preload("res://assets/sprites/ui/common/icon_home.svg")\n', "")
	source = source.replace("\texit_button.icon = HOME_ICON\n", "\texit_button.icon = _make_home_icon()\n")

	var marker := "func _panel_style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:\n"
	if not source.contains("func _make_home_icon() -> Texture2D:"):
		var icon_function := '''func _make_home_icon() -> Texture2D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var outline := Color(0.24, 0.09, 0.025, 1.0)
	var gold := Color(1.0, 0.78, 0.28, 1.0)
	var warm := Color(0.52, 0.22, 0.07, 1.0)
	for y in range(3, 16):
		var half_width := y - 2
		for x in range(16 - half_width, 17 + half_width):
			if x >= 0 and x < 32:
				image.set_pixel(x, y, outline if x == 16 - half_width or x == 16 + half_width else gold)
	for y in range(14, 29):
		for x in range(6, 27):
			var edge := x <= 7 or x >= 25 or y >= 27
			image.set_pixel(x, y, outline if edge else warm)
	for y in range(20, 29):
		for x in range(13, 20):
			image.set_pixel(x, y, outline if x == 13 or x == 19 or y == 20 else Color(0.12, 0.055, 0.025, 1.0))
	var texture := ImageTexture.create_from_image(image)
	return texture

'''
		source = source.replace(marker, icon_function + marker)

	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not write local_coop_mode.gd")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("LOCAL_COOP_HOME_ICON_FIXED")
	get_tree().quit()
