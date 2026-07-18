class_name GemIndicatorTextureFactory
extends RefCounted

static func load_svg_texture(path: String, scale: float = 1.0) -> Texture2D:
	var svg_text := FileAccess.get_file_as_string(path)
	if svg_text.is_empty():
		push_error("Buried-gem SVG is missing or empty: %s" % path)
		return null
	var image := Image.new()
	var error := image.load_svg_from_string(svg_text, scale)
	if error != OK:
		push_error("Could not rasterize buried-gem SVG %s (error %d)" % [path, error])
		return null
	return ImageTexture.create_from_image(image)
