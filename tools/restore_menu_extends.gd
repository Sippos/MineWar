extends Node

func _ready() -> void:
	_restore("res://scripts/ui/menus/controls/controls_menu.gd", "extends CanvasLayer")
	_restore("res://scripts/ui/menus/settings_menu.gd", "extends Control")
	print("MENU_EXTENDS_RESTORED")
	get_tree().quit()

func _restore(path: String, line: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if not text.begins_with("extends "):
		text = line + "\n\n" + text.lstrip("\n")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
