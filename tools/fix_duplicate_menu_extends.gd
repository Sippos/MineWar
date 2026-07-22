extends Node

func _ready() -> void:
	_fix("res://scripts/ui/menus/controls/controls_menu.gd")
	_fix("res://scripts/ui/menus/settings_menu.gd")
	print("DUPLICATE_EXTENDS_FIXED")
	get_tree().quit()

func _fix(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.begins_with("const MENU_FONT"):
		var extends_pos := text.find("extends ")
		if extends_pos > 0:
			var line_end := text.find("\n", extends_pos)
			text = text.substr(extends_pos, line_end - extends_pos + 1) + text.substr(line_end + 1)
			var const_line_end := text.find("\n")
			text = text.substr(const_line_end + 1)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
