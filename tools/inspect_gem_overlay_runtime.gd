extends Node

func _ready() -> void:
	var image := Image.load_from_file("res://GemOverlay.png")
	if image == null or image.is_empty():
		push_error("GEM_OVERLAY_INSPECT_LOAD_FAILED")
		get_tree().quit(1)
		return
	print("GEM_OVERLAY_SIZE ", image.get_width(), "x", image.get_height())
	print("GEM_OVERLAY_FORMAT ", image.get_format())
	print("GEM_OVERLAY_ALPHA ", image.detect_alpha())
	print("GEM_OVERLAY_USED_RECT ", image.get_used_rect())
	for point in [Vector2i(0, 0), Vector2i(image.get_width() - 1, 0), Vector2i(0, image.get_height() - 1), Vector2i(image.get_width() - 1, image.get_height() - 1)]:
		print("GEM_OVERLAY_CORNER ", point, " alpha=", image.get_pixelv(point).a)
	get_tree().quit(0)
