extends Node

const SCENE_PATH := "res://online_lobby.tscn"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(SCENE_PATH)
	text = text.replace("custom_minimum_size = Vector2(680, 500)", "custom_minimum_size = Vector2(620, 430)")
	text = text.replace("content_margin_left = 46.0\ncontent_margin_top = 38.0\ncontent_margin_right = 46.0\ncontent_margin_bottom = 38.0", "content_margin_left = 34.0\ncontent_margin_top = 26.0\ncontent_margin_right = 34.0\ncontent_margin_bottom = 26.0")
	text = text.replace("theme_override_constants/separation = 14", "theme_override_constants/separation = 8")
	text = text.replace("custom_minimum_size = Vector2(0, 54)", "custom_minimum_size = Vector2(0, 42)")
	text = text.replace("theme_override_font_sizes/font_size = 30", "theme_override_font_sizes/font_size = 26")
	text = text.replace("custom_minimum_size = Vector2(0, 62)", "custom_minimum_size = Vector2(0, 46)")
	text = text.replace("custom_minimum_size = Vector2(460, 54)", "custom_minimum_size = Vector2(430, 44)")
	text = text.replace("custom_minimum_size = Vector2(460, 56)", "custom_minimum_size = Vector2(430, 46)")
	text = text.replace("custom_minimum_size = Vector2(460, 52)", "custom_minimum_size = Vector2(430, 44)")
	text = text.replace("The host's base and hero shrines become the lobby • WebRTC peer-to-peer", "Private room connection • WebRTC peer-to-peer")
	FileAccess.open(SCENE_PATH, FileAccess.WRITE).store_string(text)
	print("ONLINE_LOBBY_LAYOUT_FIXED")
	get_tree().quit()
