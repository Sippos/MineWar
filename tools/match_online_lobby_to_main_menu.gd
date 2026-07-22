extends Node

const SCENE_PATH := "res://online_lobby.tscn"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(SCENE_PATH)
	if source.is_empty():
		push_error("Missing online lobby scene")
		get_tree().quit(1)
		return

	# Match the main menu button language: compact centered controls.
	source = source.replace("custom_minimum_size = Vector2(680, 500)", "custom_minimum_size = Vector2(520, 410)")
	source = source.replace("theme_override_constants/separation = 14", "theme_override_constants/separation = 10")
	source = source.replace("custom_minimum_size = Vector2(460, 54)", "custom_minimum_size = Vector2(252, 48)")
	source = source.replace("custom_minimum_size = Vector2(460, 56)", "custom_minimum_size = Vector2(252, 52)")
	source = source.replace("custom_minimum_size = Vector2(460, 52)", "custom_minimum_size = Vector2(252, 48)")
	source = source.replace("text = \"Private room connection • WebRTC peer-to-peer\"", "text = \"PRIVATE STRONGHOLD CONNECTION\"")

	var file := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	print("ONLINE_LOBBY_MAIN_MENU_STYLE_FIXED")
	get_tree().quit()
