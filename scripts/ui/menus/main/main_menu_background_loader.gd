extends TextureRect

const BACKGROUND_PATH := "res://background.png"
const FALLBACK_TEXTURE: Texture2D = preload("res://MainMenuBackground.png")

func _ready() -> void:
	texture = _load_background_texture()

func _load_background_texture() -> Texture2D:
	if ResourceLoader.exists(BACKGROUND_PATH):
		var imported_texture := load(BACKGROUND_PATH) as Texture2D
		if imported_texture != null:
			return imported_texture

	var image := Image.load_from_file(BACKGROUND_PATH)
	if image != null and not image.is_empty():
		return ImageTexture.create_from_image(image)

	push_warning("Could not load main-menu background at %s; using fallback." % BACKGROUND_PATH)
	return FALLBACK_TEXTURE
