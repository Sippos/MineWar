extends Node

const PREVIEW_SCRIPT := preload("res://tools/sprite_lab/dome_material_preview_v2.gd")
const SIZE := 32
const MAGENTA := Color(1.0, 0.0, 1.0, 1.0)
const CYAN := Color(0.0, 1.0, 1.0, 1.0)

func _image(fill_color: Color) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(fill_color)
	return image

func _count_color(image: Image, target: Color) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.is_equal_approx(target):
				count += 1
	return count

func _ready() -> void:
	var preview := PREVIEW_SCRIPT.new()
	var mass := _image(Color(0.08, 0.07, 0.12, 1.0))
	var blank := _image(Color.TRANSPARENT)
	var unmineable_border := blank.duplicate()
	unmineable_border.set_pixel(16, 2, MAGENTA)
	var unmineable_front := _image(CYAN)
	var easy_front := _image(Color(1.0, 0.0, 0.0, 1.0))
	var borders := {
		"unmineable": unmineable_border,
		"easy": blank.duplicate(),
		"medium": blank.duplicate(),
		"hard": blank.duplicate(),
	}
	var joints := {
		"unmineable": blank.duplicate(),
		"easy": blank.duplicate(),
		"medium": blank.duplicate(),
		"hard": blank.duplicate(),
	}
	var corners := {
		"unmineable": blank.duplicate(),
		"easy": blank.duplicate(),
		"medium": blank.duplicate(),
		"hard": blank.duplicate(),
	}
	var fronts := {
		"unmineable": unmineable_front,
		"easy": easy_front,
		"medium": easy_front.duplicate(),
		"hard": easy_front.duplicate(),
	}
	preview.call("set_material_library", mass, borders, corners, joints, fronts)
	var composites: Dictionary = preview.get("composite_textures")
	var unmineable_frames: Array = composites.get("unmineable", []) as Array
	var ok := true
	for mask in [1, 2, 4, 8]:
		if mask >= unmineable_frames.size():
			push_error("Missing Unmineable frame for mask %d" % mask)
			ok = false
			continue
		var texture := unmineable_frames[mask] as ImageTexture
		var count := _count_color(texture.get_image(), MAGENTA)
		if count <= 0:
			push_error("Unmineable edit did not rotate into mask %d" % mask)
			ok = false
	var loaded_fronts: Dictionary = preview.get("front_images")
	var loaded_unmineable := loaded_fronts.get("unmineable") as Image
	if loaded_unmineable == null or not loaded_unmineable.get_pixel(0, 0).is_equal_approx(CYAN):
		push_error("Unmineable front surface is still aliased to Easy")
		ok = false
	preview.free()
	if ok:
		print("PASS: Unmineable border refreshes top/right/bottom/left and owns its front surface")
		get_tree().quit()
	else:
		get_tree().quit(1)
