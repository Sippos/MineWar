extends TextureRect

const BACKGROUND_TEXTURE: Texture2D = preload("res://background.png")

func _ready() -> void:
	texture = BACKGROUND_TEXTURE
